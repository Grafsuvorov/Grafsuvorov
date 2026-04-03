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


def _apply_draw_prior(P, prior_draw, gamma):
    if gamma <= 0 or prior_draw is None or prior_draw <= 0 or prior_draw >= 1:
        return sanitize_prob(P)

    P = sanitize_prob(P)
    pD = P[:, 1]
    new_pD = (1.0 - gamma) * pD + gamma * float(prior_draw)

    old_draw = np.clip(pD, 1e-6, 1 - 1e-6)
    scale = np.clip((1.0 - new_pD) / (1.0 - old_draw), 0.0, 10.0)
    P[:, 0] = P[:, 0] * scale
    P[:, 2] = P[:, 2] * scale
    P[:, 1] = new_pD
    return sanitize_prob(P)


def _apply_draw_threshold(P, threshold):
    if threshold is None or threshold <= 0:
        return sanitize_prob(P)

    P = sanitize_prob(P)
    pD = P[:, 1]
    max_other = np.maximum(P[:, 0], P[:, 2])
    boost = pD >= float(threshold)
    if boost.any():
        pD[boost] = np.maximum(pD[boost], max_other[boost] + 1e-6)
        P[:, 1] = pD
        P = sanitize_prob(P)
    return P


def _apply_draw_rule(P, df, threshold, max_elo_diff, max_goal_diff):
    if threshold is None or threshold <= 0:
        return sanitize_prob(P)

    P = sanitize_prob(P)
    mask = np.ones(len(P), dtype=bool)
    if "elo_diff" in df.columns and np.isfinite(max_elo_diff):
        mask &= df["elo_diff"].abs().values <= max_elo_diff
    if "goal_diff_avg_6_diff" in df.columns and np.isfinite(max_goal_diff):
        mask &= df["goal_diff_avg_6_diff"].abs().values <= max_goal_diff

    pD = P[:, 1]
    max_other = np.maximum(P[:, 0], P[:, 2])
    boost = mask & (pD >= float(threshold))
    if boost.any():
        pD[boost] = np.maximum(pD[boost], max_other[boost] + 1e-6)
        P[:, 1] = pD
        P = sanitize_prob(P)
    return P


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

    stage_alpha = float(bundle.get("stage_alpha", 0.0))
    stage_draw_model = bundle.get("stage_draw_model")
    stage_homeaway_model = bundle.get("stage_homeaway_model")
    if stage_alpha > 0 and stage_draw_model is not None and stage_homeaway_model is not None:
        stage_draw_best = bundle.get("stage_draw_best_iter")
        stage_homeaway_best = bundle.get("stage_homeaway_best_iter")

        draw_cols = bundle.get("stage_draw_feature_cols") or feature_cols
        draw_priors = bundle.get("stage_draw_feature_priors")
        X_draw, _ = _get_X(df, draw_cols, priors=draw_priors)
        dmat_draw = xgb.DMatrix(X_draw, feature_names=draw_cols)

        p_draw = stage_draw_model.predict(dmat_draw, iteration_range=(0, int(stage_draw_best))) if stage_draw_best else stage_draw_model.predict(dmat_draw)
        p_home = stage_homeaway_model.predict(dmat, iteration_range=(0, int(stage_homeaway_best))) if stage_homeaway_best else stage_homeaway_model.predict(dmat)

        p_draw = sanitize_prob(p_draw)
        p_home = sanitize_prob(p_home)
        draw_mkt_alpha = float(bundle.get("stage_draw_market_alpha", 0.0))
        if draw_mkt_alpha > 0 and "p_draw_norm" in df.columns:
            p_mkt_draw = sanitize_prob(df["p_draw_norm"].astype(float).values)
            p_draw = sanitize_prob((1.0 - draw_mkt_alpha) * p_draw + draw_mkt_alpha * p_mkt_draw)

        homeaway_mkt_alpha = float(bundle.get("stage_homeaway_market_alpha", 0.0))
        if homeaway_mkt_alpha > 0 and all(c in df.columns for c in ["p_home_norm", "p_away_norm"]):
            p_home_mkt = df["p_home_norm"].astype(float).values
            p_away_mkt = df["p_away_norm"].astype(float).values
            denom = np.clip(p_home_mkt + p_away_mkt, 1e-6, None)
            p_home_mkt = sanitize_prob(p_home_mkt / denom)
            p_home = sanitize_prob((1.0 - homeaway_mkt_alpha) * p_home + homeaway_mkt_alpha * p_home_mkt)
        P_stage = np.stack(
            [(1.0 - p_draw) * (1.0 - p_home), p_draw, (1.0 - p_draw) * p_home],
            axis=1,
        )
        P_final = sanitize_prob((1.0 - stage_alpha) * P_final + stage_alpha * P_stage)

    draw_prior = bundle.get("draw_prior")
    draw_gamma = float(bundle.get("draw_prior_gamma", 0.0))
    if draw_prior is not None and draw_gamma > 0:
        P_final = _apply_draw_prior(P_final, float(draw_prior), draw_gamma)

    draw_threshold = bundle.get("draw_threshold")
    if draw_threshold is not None and float(draw_threshold) > 0:
        P_final = _apply_draw_threshold(P_final, float(draw_threshold))

    rule_t = float(bundle.get("rule_draw_threshold", 0.0))
    if rule_t > 0:
        max_elo = float(bundle.get("rule_max_elo_diff", float("inf")))
        max_goal = float(bundle.get("rule_max_goal_diff", float("inf")))
        P_final = _apply_draw_rule(P_final, df, rule_t, max_elo, max_goal)

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
        # apply top-level league bias if present
        league_bias = bundle.get("league_prob_bias") or {}
        if league_bias:
            preds = _apply_league_prob_bias(preds, df_local["league_id"].values, league_bias)
        return sanitize_prob(preds)

    return _predict_outcomes_with_bundle(df, bundle)


# =========================
# TOTALS (Over 2.5)
# =========================
def _predict_totals_with_bundle(df, bundle):
    feature_cols = bundle["feature_cols"]
    model = bundle["xgb_model"]
    iso = bundle.get("iso")
    best_iter = bundle.get("xgb_best_iter") or bundle.get("best_iter")

    X = ensure_features_strict(df.copy(), feature_cols)

    if hasattr(model, "predict_proba"):
        p = model.predict_proba(X)[:, 1]
    else:
        dmat = xgb.DMatrix(X, feature_names=feature_cols)
        if best_iter is not None:
            p = model.predict(dmat, iteration_range=(0, int(best_iter)))
        else:
            p = model.predict(dmat)
    p = np.clip(p.astype(float), 1e-6, 1 - 1e-6)

    if iso is not None:
        try:
            p = iso.predict(p)
        except Exception:
            p = iso.transform(p)

    return np.clip(p, 1e-6, 1 - 1e-6)


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
