# models/inference.py

import os
import numpy as np
import xgboost as xgb

from models.inference_utils import ensure_features_soft, ensure_features_strict
from models.blending import (
    sanitize_prob,
    blend_poisson_and_xgb,
    apply_market_anchor,
    apply_draw_cap,
)
from models.poisson import build_poisson_probs_for_arrays
from config import DRAW_CAP_MAX, DRAW_CAP_MIN


def _get_X(df, feature_cols, priors=None):
    strict = os.getenv("STRICT_INFER", "0") == "1"
    if strict:
        X = ensure_features_strict(df.copy(), feature_cols)
        missing = []
    else:
        X, missing = ensure_features_soft(
            df.copy(),
            feature_cols,
            fatal_if_all_missing=True,
            priors=priors,
        )
    return X, missing


def _safe_logit(p):
    p = np.clip(p.astype(float), 1e-6, 1 - 1e-6)
    return np.log(p / (1 - p))


def _sigmoid(x):
    return 1.0 / (1.0 + np.exp(-x))


def _apply_logistic_calibration(p, league_ids, league_cals, global_cal):
    if (not league_cals) and (global_cal is None):
        return p

    logits = _safe_logit(p)
    if league_ids is not None and len(league_ids) == len(p):
        lids = np.asarray(league_ids, dtype=float)
    else:
        lids = np.full(len(p), np.nan, dtype=float)

    out = logits.copy()
    for i in range(len(out)):
        lid = lids[i]
        key = int(lid) if np.isfinite(lid) else None
        params = league_cals.get(key) if league_cals and key is not None else None
        if params is None:
            params = global_cal
        if params is None:
            continue
        coef, intercept = params
        out[i] = coef * logits[i] + intercept

    return sanitize_prob(_sigmoid(out))


def _apply_league_prob_bias(P, league_ids, bias_dict):
    if not bias_dict or league_ids is None or len(league_ids) != len(P):
        return sanitize_prob(P)

    lids = np.asarray(league_ids, dtype=float)
    out = P.copy()
    for i in range(len(out)):
        lid = lids[i]
        if not np.isfinite(lid):
            continue
        bias = bias_dict.get(int(lid))
        if bias is None:
            continue
        out[i] = out[i] + np.asarray(bias, dtype=float)
    return sanitize_prob(out)


def _apply_draw_calibration(P, league_ids, league_cals, global_cal):
    if (not league_cals) and (global_cal is None):
        return sanitize_prob(P)

    logits = _safe_logit(P[:, 1])
    if league_ids is not None and len(league_ids) == len(P):
        lids = np.asarray(league_ids, dtype=float)
    else:
        lids = np.full(len(P), np.nan, dtype=float)

    new_draw = P[:, 1].copy()
    for i in range(len(P)):
        lid = lids[i]
        params = None
        if np.isfinite(lid) and league_cals:
            params = league_cals.get(int(lid))
        if params is None:
            params = global_cal
        if params is None:
            continue
        coef, intercept = params
        new_draw[i] = _sigmoid(coef * logits[i] + intercept)

    old_draw = np.clip(P[:, 1], 1e-6, 1 - 1e-6)
    scale = np.clip((1.0 - new_draw) / (1.0 - old_draw), 0.0, 10.0)
    P[:, 0] = P[:, 0] * scale
    P[:, 2] = P[:, 2] * scale
    P[:, 1] = new_draw
    return sanitize_prob(P)


# =========================
# 1X2
# =========================
def _predict_outcomes_with_bundle(df, bundle):
    feature_cols = bundle["feature_cols"]
    xgb_model = bundle["xgb_model"]
    lr = bundle["logreg_calibrator"]
    pois = bundle["poisson"]

    alpha = float(bundle.get("mix_alpha", 0.0))
    tau_market = float(bundle.get("tau_market", 0.0))

    X, missing = _get_X(df, feature_cols, priors=bundle.get("feature_priors"))
    dmat = xgb.DMatrix(X, feature_names=feature_cols)

    # XGB
    best_iter = bundle.get("xgb_best_iter")
    if best_iter is not None:
        P_xgb = xgb_model.predict(dmat, iteration_range=(0, int(best_iter)))
    else:
        P_xgb = xgb_model.predict(dmat)
    P_xgb = sanitize_prob(P_xgb)

    # Poisson (log-lambda models)
    n_best_h = int(pois.get("n_best_home") or 0)
    n_best_a = int(pois.get("n_best_away") or 0)

    pred_h = pois["model_home"].predict(dmat, iteration_range=(0, n_best_h)) if n_best_h else pois["model_home"].predict(dmat)
    pred_a = pois["model_away"].predict(dmat, iteration_range=(0, n_best_a)) if n_best_a else pois["model_away"].predict(dmat)

    lam_home = np.clip(np.exp(pred_h), 1e-6, 5.0)
    lam_away = np.clip(np.exp(pred_a), 1e-6, 5.0)

    P_pois, _ = build_poisson_probs_for_arrays(lam_home, lam_away)

    # blend + calibrate
    P_mix = blend_poisson_and_xgb(P_poisson=P_pois, P_xgb=P_xgb, alpha=alpha)
    P_lr = sanitize_prob(lr.predict_proba(P_mix))

    # optional market anchor
    if tau_market > 0 and all(c in df.columns for c in ["p_home_norm", "p_draw_norm", "p_away_norm"]):
        Pm = np.stack(
            [
                df["p_away_norm"].astype(float).values,
                df["p_draw_norm"].astype(float).values,
                df["p_home_norm"].astype(float).values,
            ],
            axis=1,
        )
        P_lr = apply_market_anchor(P_lr, sanitize_prob(Pm), tau_market)

    # draw cap
    P_final = apply_draw_cap(P_lr, max_draw=DRAW_CAP_MAX, boost_small_draw=DRAW_CAP_MIN)

    league_bias = bundle.get("league_prob_bias") or {}
    if league_bias and "league_id" in df.columns:
        P_final = _apply_league_prob_bias(P_final, df["league_id"].values, league_bias)

    draw_league = bundle.get("draw_league_calibrators") or {}
    draw_global = bundle.get("draw_global_calibrator")
    if (draw_league or draw_global) and "league_id" in df.columns:
        P_final = _apply_draw_calibration(P_final, df["league_id"].values, draw_league, draw_global)
    elif draw_global:
        P_final = _apply_draw_calibration(P_final, None, {}, draw_global)

    return sanitize_prob(P_final)


def predict_outcomes(df, bundle):
    if isinstance(bundle, dict) and bundle and "feature_cols" not in bundle:
        if "league_id" not in df.columns:
            raise RuntimeError("predict_outcomes(): df должен содержать league_id для мульти-моделей")
        df_local = df.reset_index(drop=True)
        preds = np.zeros((len(df_local), 3), dtype=float)
        for lid, part in df_local.groupby("league_id"):
            sub = bundle.get(int(lid))
            if sub is None:
                raise RuntimeError(f"Нет outcome-модели для лиги {lid}")
            local = _predict_outcomes_with_bundle(part, sub)
            preds[part.index] = local
        return sanitize_prob(preds)

    return _predict_outcomes_with_bundle(df, bundle)


# =========================
# TOTALS (Over 2.5)
# =========================
def _predict_totals_with_bundle(df, bundle):
    feature_cols = bundle["feature_cols"]
    model = bundle.get("xgb_model") or bundle.get("model")

    if model is None:
        raise RuntimeError("Totals bundle has no model key (xgb_model/model).")

    X, _ = _get_X(df, feature_cols, priors=bundle.get("feature_priors"))
    dmat = xgb.DMatrix(X, feature_names=feature_cols)

    p = model.predict(dmat)
    p = p if p.ndim == 1 else p[:, 1]
    p = np.clip(p.astype(float), 1e-6, 1 - 1e-6)

    league_cals = bundle.get("league_logit_calibrators") or {}
    global_cal = bundle.get("global_logit_calibrator")
    if (league_cals or global_cal) and "league_id" in df.columns:
        p = _apply_logistic_calibration(p, df["league_id"].values, league_cals, global_cal)
    elif global_cal:
        p = _apply_logistic_calibration(p, None, {}, global_cal)

    offsets = bundle.get("league_offsets") or {}
    if offsets and "league_id" in df.columns:
        lids = df["league_id"].astype(int).values
        adj = np.array([offsets.get(int(l), 0.0) for l in lids], dtype="float64")
        if np.any(adj):
            p = np.clip(p + adj, 1e-6, 1 - 1e-6)

    return p


def predict_totals(df, bundle):
    if isinstance(bundle, dict) and bundle and "feature_cols" not in bundle:
        if "league_id" not in df.columns:
            raise RuntimeError("predict_totals(): df должен содержать league_id для мульти-моделей")
        df_local = df.reset_index(drop=True)
        res = np.zeros(len(df_local), dtype=float)
        for lid, part in df_local.groupby("league_id"):
            sub = bundle.get(int(lid))
            if sub is None:
                raise RuntimeError(f"Нет totals-модели для лиги {lid}")
            res[part.index] = _predict_totals_with_bundle(part, sub)
        return res

    return _predict_totals_with_bundle(df, bundle)
