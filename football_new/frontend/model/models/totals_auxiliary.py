from typing import Dict, List, Optional

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import brier_score_loss, log_loss

from config import CAL_DAYS, TOTALS_AUX_MODEL_PATH, VAL_DAYS
from data.splits import recency_weights, temporal_split_by_league
from train_totals import select_totals_feature_cols


POSITIVE_TOTALS_AUX_LEAGUES = {39, 61, 78}
AUX_EXCLUDE_COLS = {"p_base_shadow", "target_btts", "target_open4"}
TOTALS_AUX_MAX_DELTA = 0.18
TOTALS_AUX_MIN_PROB = 0.08
TOTALS_AUX_MAX_PROB = 0.92
TOTALS_AUX_BLEND_META = 0.72
TOTALS_AUX_BLEND_BASE = 0.18
TOTALS_AUX_BLEND_MKT = 0.10


def _safe_prob(p: np.ndarray) -> np.ndarray:
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, 1e-6, 1.0 - 1e-6)


def _bounded_prob(p: np.ndarray) -> np.ndarray:
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, TOTALS_AUX_MIN_PROB, TOTALS_AUX_MAX_PROB)


def _safe_logit(p: np.ndarray) -> np.ndarray:
    p = _safe_prob(p)
    return np.log(p / (1.0 - p))


def _sigmoid(x: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-x))


def _compute_p_over_mkt(df: pd.DataFrame) -> np.ndarray:
    over = pd.to_numeric(df.get("avg_odds_over25"), errors="coerce")
    under = pd.to_numeric(df.get("avg_odds_under25"), errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    p = imp_over / overround
    return pd.to_numeric(p, errors="coerce").to_numpy(dtype=float)


def _binary_target(df: pd.DataFrame, target_col: str) -> np.ndarray:
    return pd.to_numeric(df[target_col], errors="coerce").fillna(0.0).astype(int).to_numpy()


def _fit_aux_model(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    feature_cols: List[str],
    target_col: str,
) -> Dict[str, object]:
    priors = (
        tr[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )
    x_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    x_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    y_tr = _binary_target(tr, target_col)
    y_cal = _binary_target(cal, target_col)
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)

    dtr = xgb.DMatrix(x_tr, label=y_tr, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(x_cal, label=y_cal, feature_names=feature_cols)
    params = {
        "objective": "binary:logistic",
        "eta": 0.035,
        "max_depth": 6,
        "min_child_weight": 10.0,
        "subsample": 0.90,
        "colsample_bytree": 0.90,
        "lambda": 2.0,
        "alpha": 0.0,
        "tree_method": "hist",
        "eval_metric": "logloss",
        "seed": 123,
    }
    model = xgb.train(
        params,
        dtr,
        num_boost_round=1000,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=90,
        verbose_eval=False,
    )
    best_iter = model.best_iteration + 1 if model.best_iteration is not None else None
    p_cal_raw = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso.fit(p_cal_raw, y_cal)
    except Exception:
        iso = None
    return {
        "model": model,
        "best_iter": best_iter,
        "feature_cols": feature_cols,
        "feature_priors": priors,
        "iso": iso,
    }


def _predict_aux(df: pd.DataFrame, bundle: Dict[str, object]) -> np.ndarray:
    feature_cols = bundle["feature_cols"]
    x = (
        df[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .fillna(pd.Series(bundle["feature_priors"]))
        .fillna(0.0)
    )
    dmat = xgb.DMatrix(x, feature_names=feature_cols)
    best_iter = bundle.get("best_iter")
    model = bundle["model"]
    raw = model.predict(dmat, iteration_range=(0, best_iter)) if best_iter else model.predict(dmat)
    iso = bundle.get("iso")
    if iso is not None:
        raw = iso.predict(raw)
    return _safe_prob(raw)


def _fit_final_aux_bundle(df_hist: pd.DataFrame, feature_cols: List[str], target_col: str) -> Optional[Dict[str, object]]:
    if len(df_hist) < 120:
        return None
    hist = df_hist.sort_values("date_utc").copy()
    cut = hist["date_utc"].max() - pd.Timedelta(days=max(int(CAL_DAYS), 45))
    tr = hist[hist["date_utc"] < cut].copy()
    cal = hist[hist["date_utc"] >= cut].copy()
    if len(cal) < 25:
        split_idx = max(int(len(hist) * 0.8), len(hist) - 30)
        tr = hist.iloc[:split_idx].copy()
        cal = hist.iloc[split_idx:].copy()
    if tr.empty or cal.empty:
        return None
    return _fit_aux_model(tr, cal, feature_cols, target_col)


def _tune_meta_weights(shadow_df: pd.DataFrame) -> Dict[str, float]:
    best = None
    p_base = _safe_prob(shadow_df["p_base"].to_numpy())
    p_btts = _safe_prob(shadow_df["p_btts"].to_numpy())
    p_open = _safe_prob(shadow_df["p_open"].to_numpy())
    p_mkt_raw = pd.to_numeric(shadow_df["p_mkt"], errors="coerce").to_numpy(dtype=float)
    p_mkt = np.where(np.isfinite(p_mkt_raw), p_mkt_raw, p_base)
    p_mkt = _safe_prob(p_mkt)
    y = _binary_target(shadow_df, "target_over25")

    for w_btts in np.linspace(-0.6, 1.2, 10):
        for w_open in np.linspace(-0.6, 1.4, 11):
            for w_mkt in np.linspace(0.0, 0.6, 7):
                z = (
                    _safe_logit(p_base)
                    + w_btts * (p_btts - 0.5)
                    + w_open * (p_open - 0.5)
                    + w_mkt * (p_mkt - 0.5)
                )
                p_raw = _safe_prob(_sigmoid(z))
                p = _regularize_meta_output(p_base, p_raw, p_mkt)
                ll = log_loss(y, p, labels=[0, 1])
                br = brier_score_loss(y, p)
                over_share = float((p >= 0.5).mean())
                extreme_rate = float(((p <= 0.10) | (p >= 0.90)).mean())
                drift = float(np.mean(np.abs(p - p_base)))
                key = (
                    ll + 0.08 * extreme_rate + 0.03 * drift,
                    br,
                    abs(over_share - 0.5),
                    extreme_rate,
                    drift,
                )
                if best is None or key < best["key"]:
                    best = {
                        "key": key,
                        "weights": {
                            "w_btts": float(w_btts),
                            "w_open": float(w_open),
                            "w_mkt": float(w_mkt),
                        },
                    }
    return best["weights"]


def _regularize_meta_output(p_base: np.ndarray, p_meta: np.ndarray, p_mkt: np.ndarray) -> np.ndarray:
    p_base = _safe_prob(p_base)
    p_meta = _safe_prob(p_meta)
    p_mkt = np.where(np.isfinite(p_mkt), p_mkt, p_base)
    p_mkt = _safe_prob(p_mkt)

    mixed = (
        TOTALS_AUX_BLEND_META * p_meta
        + TOTALS_AUX_BLEND_BASE * p_base
        + TOTALS_AUX_BLEND_MKT * p_mkt
    )
    delta = np.clip(mixed - p_base, -TOTALS_AUX_MAX_DELTA, TOTALS_AUX_MAX_DELTA)
    return _bounded_prob(p_base + delta)


def _apply_meta(p_base: np.ndarray, p_btts: np.ndarray, p_open: np.ndarray, p_mkt: np.ndarray, weights: Dict[str, float]) -> np.ndarray:
    p_mkt = np.where(np.isfinite(p_mkt), p_mkt, p_base)
    z = (
        _safe_logit(p_base)
        + float(weights["w_btts"]) * (_safe_prob(p_btts) - 0.5)
        + float(weights["w_open"]) * (_safe_prob(p_open) - 0.5)
        + float(weights["w_mkt"]) * (_safe_prob(p_mkt) - 0.5)
    )
    p_raw = _safe_prob(_sigmoid(z))
    return _regularize_meta_output(p_base, p_raw, p_mkt)


def train_totals_auxiliary(df_train: pd.DataFrame, p_base_train: np.ndarray) -> Dict[str, object]:
    df = df_train.copy().reset_index(drop=True)
    df["target_btts"] = ((df["home_goals"].fillna(0) > 0) & (df["away_goals"].fillna(0) > 0)).astype(float)
    df["target_open4"] = ((df["home_goals"].fillna(0) + df["away_goals"].fillna(0)) >= 4).astype(float)
    df["p_base_shadow"] = _safe_prob(p_base_train)

    bundle: Dict[str, object] = {
        "positive_leagues": sorted(POSITIVE_TOTALS_AUX_LEAGUES),
        "leagues": {},
    }

    for lid in sorted(POSITIVE_TOTALS_AUX_LEAGUES):
        hist_l = df[df["league_id"].astype(int) == lid].copy().sort_values("date_utc")
        if len(hist_l) < 160:
            continue

        tr, cal, val = temporal_split_by_league(
            hist_l,
            ts_col="date_utc",
            league_col="league_id",
            cal_days=CAL_DAYS,
            val_days=VAL_DAYS,
            gap_days=0,
            min_cal_per_league=12,
            min_val_per_league=6,
            now_override=None,
        )
        if tr.empty or cal.empty or val.empty:
            continue

        feature_cols = [c for c in select_totals_feature_cols(hist_l) if c not in AUX_EXCLUDE_COLS]
        btts_shadow = _fit_aux_model(tr, cal, feature_cols, "target_btts")
        open_shadow = _fit_aux_model(tr, cal, feature_cols, "target_open4")

        shadow = val.copy().reset_index(drop=True)
        shadow["p_base"] = _safe_prob(val["p_base_shadow"].to_numpy())
        shadow["p_btts"] = _predict_aux(val, btts_shadow)
        shadow["p_open"] = _predict_aux(val, open_shadow)
        shadow["p_mkt"] = _compute_p_over_mkt(val)
        weights = _tune_meta_weights(shadow)

        btts_full = _fit_final_aux_bundle(hist_l, feature_cols, "target_btts")
        open_full = _fit_final_aux_bundle(hist_l, feature_cols, "target_open4")
        if btts_full is None or open_full is None:
            continue

        bundle["leagues"][int(lid)] = {
            "weights": weights,
            "btts": btts_full,
            "open": open_full,
        }

    joblib.dump(bundle, TOTALS_AUX_MODEL_PATH)
    return bundle


def apply_totals_auxiliary(df: pd.DataFrame, p_base: np.ndarray, aux_bundle: Optional[Dict[str, object]]) -> np.ndarray:
    out = _safe_prob(np.asarray(p_base, dtype=float).copy())
    if not aux_bundle or "leagues" not in aux_bundle or "league_id" not in df.columns:
        return out

    leagues = aux_bundle.get("leagues") or {}
    if not leagues:
        return out

    df_local = df.reset_index(drop=True)
    for lid, part in df_local.groupby("league_id"):
        lid_int = int(lid)
        info = leagues.get(lid_int)
        if info is None:
            continue
        idx = part.index.to_numpy()
        p_base_local = out[idx]
        p_btts = _predict_aux(part, info["btts"])
        p_open = _predict_aux(part, info["open"])
        p_mkt = _compute_p_over_mkt(part)
        out[idx] = _apply_meta(p_base_local, p_btts, p_open, p_mkt, info["weights"])
    return _safe_prob(out)
