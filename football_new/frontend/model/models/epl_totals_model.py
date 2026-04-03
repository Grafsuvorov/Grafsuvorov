from typing import Dict, List, Optional

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import brier_score_loss, log_loss

from config import CAL_DAYS, GAP_DAYS, TOTALS_EPL_MODEL_PATH, VAL_DAYS
from data.splits import recency_weights, temporal_split_by_league
from decision.totals_decision import decide_total_bet
from decision.totals_policy import apply_total_league_policy, should_block_total_candidate
from models.poisson import build_poisson_probs_for_arrays, train_poisson_pair
from train_totals import select_totals_feature_cols


EPL_LEAGUE_ID = 39


def _safe_prob(p: np.ndarray) -> np.ndarray:
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, 1e-6, 1.0 - 1e-6)


def _prepare_y(df: pd.DataFrame) -> np.ndarray:
    goals = pd.to_numeric(df["home_goals"], errors="coerce").fillna(0.0) + pd.to_numeric(df["away_goals"], errors="coerce").fillna(0.0)
    return (goals > 2.5).astype(int).to_numpy()


def _compute_p_over_mkt(df: pd.DataFrame) -> np.ndarray:
    over = pd.to_numeric(df.get("avg_odds_over25"), errors="coerce")
    under = pd.to_numeric(df.get("avg_odds_under25"), errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    out = imp_over / overround
    return pd.to_numeric(out, errors="coerce").to_numpy(dtype=float)


def _safe_blend(p_model: np.ndarray, p_mkt: np.ndarray, alpha: float) -> np.ndarray:
    p_model = _safe_prob(p_model)
    p_mkt = _safe_prob(p_mkt)
    out = p_model.copy()
    use = np.isfinite(p_mkt)
    if alpha > 0 and use.any():
        out[use] = (1.0 - alpha) * p_model[use] + alpha * p_mkt[use]
    return _safe_prob(out)


def _ev(prob: float, odds: float) -> Optional[float]:
    if prob is None or odds is None or not np.isfinite(prob) or not np.isfinite(odds) or odds <= 1.01:
        return None
    return float(prob * odds - 1.0)


def _roi_score(df: pd.DataFrame, p_over: np.ndarray) -> Dict[str, float]:
    profits: List[float] = []
    p_arr = _safe_prob(p_over)
    for i, (_, row) in enumerate(df.iterrows()):
        row_dict = row.to_dict()
        row_dict["p_over25"] = float(p_arr[i])
        row_dict["p_under25"] = float(1.0 - p_arr[i])
        candidates = []
        for outcome, prob, odds_key in (
            ("Over2.5", row_dict["p_over25"], "avg_odds_over25"),
            ("Under2.5", row_dict["p_under25"], "avg_odds_under25"),
        ):
            odds = row_dict.get(odds_key)
            edge = _ev(prob, odds)
            if edge is None or edge < 0.02:
                continue
            if should_block_total_candidate(row_dict, outcome):
                continue
            tier = decide_total_bet(edge, odds, EPL_LEAGUE_ID, prob)
            if tier == "NO BET":
                continue
            candidates.append(("TOTAL", outcome, float(odds), float(edge)))
        candidates = apply_total_league_policy(row_dict, candidates)
        total_candidates = [c for c in candidates if c[0] == "TOTAL"]
        if not total_candidates:
            continue
        _, outcome, odds, _ = max(total_candidates, key=lambda x: x[3])
        goals = float(row["home_goals"]) + float(row["away_goals"])
        if outcome == "Over2.5":
            profits.append(float(odds) - 1.0 if goals > 2.5 else -1.0)
        else:
            profits.append(float(odds) - 1.0 if goals < 3.0 else -1.0)
    if not profits:
        return {"roi": -1.0, "profit": 0.0, "bets": 0}
    profit = float(np.sum(profits))
    bets = len(profits)
    return {"roi": profit / bets, "profit": profit, "bets": bets}


def _fit_xgb(tr: pd.DataFrame, cal: pd.DataFrame, feature_cols: List[str], params: Dict[str, float]) -> Dict[str, object]:
    priors = (
        tr[feature_cols]
        .replace([np.inf, -np.inf], np.nan)
        .mean()
        .fillna(0.0)
        .to_dict()
    )
    x_tr = tr[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    x_cal = cal[feature_cols].replace([np.inf, -np.inf], np.nan).fillna(0.0)
    y_tr = _prepare_y(tr)
    y_cal = _prepare_y(cal)
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)
    dtr = xgb.DMatrix(x_tr, label=y_tr, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(x_cal, label=y_cal, feature_names=feature_cols)
    full_params = {
        "objective": "binary:logistic",
        "subsample": 0.90,
        "colsample_bytree": 0.90,
        "lambda": 2.0,
        "alpha": 0.0,
        "tree_method": "hist",
        "eval_metric": "logloss",
        "seed": 123,
        **params,
    }
    model = xgb.train(
        full_params,
        dtr,
        num_boost_round=1200,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=90,
        verbose_eval=False,
    )
    best_iter = model.best_iteration + 1 if model.best_iteration is not None else None
    raw = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso.fit(raw, y_cal)
        p_iso = _safe_prob(iso.predict(raw))
    except Exception:
        iso = None
        p_iso = _safe_prob(raw)
    return {
        "model": model,
        "best_iter": best_iter,
        "feature_cols": feature_cols,
        "feature_priors": priors,
        "iso": iso,
        "p_cal_iso": p_iso,
        "y_cal": y_cal,
    }


def _predict_xgb(df: pd.DataFrame, bundle: Dict[str, object]) -> np.ndarray:
    x = (
        df[bundle["feature_cols"]]
        .replace([np.inf, -np.inf], np.nan)
        .fillna(pd.Series(bundle["feature_priors"]))
        .fillna(0.0)
    )
    dmat = xgb.DMatrix(x, feature_names=bundle["feature_cols"])
    model = bundle["model"]
    best_iter = bundle.get("best_iter")
    raw = model.predict(dmat, iteration_range=(0, best_iter)) if best_iter else model.predict(dmat)
    iso = bundle.get("iso")
    if iso is not None:
        raw = iso.predict(raw)
    return _safe_prob(raw)


def _train_single_bundle(hist: pd.DataFrame, feature_cols: List[str], params: Dict[str, float]) -> Optional[Dict[str, object]]:
    if len(hist) < 180:
        return None
    tr, cal, val = temporal_split_by_league(
        hist,
        ts_col="date_utc",
        league_col="league_id",
        cal_days=CAL_DAYS,
        val_days=VAL_DAYS,
        gap_days=GAP_DAYS,
        min_cal_per_league=12,
        min_val_per_league=6,
        now_override=None,
    )
    if tr.empty or cal.empty or val.empty:
        return None

    xgb_bundle = _fit_xgb(tr, cal, feature_cols, params)
    p_xgb_val = _predict_xgb(val, xgb_bundle)

    pois = train_poisson_pair(
        tr=tr,
        cal=cal,
        val=val,
        feature_cols=feature_cols,
        ts_col="date_utc",
        now_override=None,
    )
    _, p_pois_val = build_poisson_probs_for_arrays(pois["lam_val_home"], pois["lam_val_away"])
    p_mkt_val = _compute_p_over_mkt(val)

    best = None
    for alpha_mix in np.linspace(0.0, 0.9, 10):
        p_mix = _safe_prob(alpha_mix * p_pois_val + (1.0 - alpha_mix) * p_xgb_val)
        for alpha_mkt in np.linspace(0.0, 0.6, 7):
            p_final = _safe_blend(p_mix, p_mkt_val, float(alpha_mkt))
            roi_stats = _roi_score(val, p_final)
            ll = log_loss(_prepare_y(val), p_final, labels=[0, 1])
            br = brier_score_loss(_prepare_y(val), p_final)
            key = (-roi_stats["roi"], -roi_stats["profit"], ll, br)
            if best is None or key < best["key"]:
                best = {
                    "key": key,
                    "alpha_mix": float(alpha_mix),
                    "alpha_mkt": float(alpha_mkt),
                    "roi": float(roi_stats["roi"]),
                    "profit": float(roi_stats["profit"]),
                    "bets": int(roi_stats["bets"]),
                    "ll": float(ll),
                    "brier": float(br),
                    "val_df": val.copy(),
                }

    # full fit for inference
    hist_sorted = hist.sort_values("date_utc").copy()
    cut = hist_sorted["date_utc"].max() - pd.Timedelta(days=max(int(CAL_DAYS), 45))
    tr_full = hist_sorted[hist_sorted["date_utc"] < cut].copy()
    cal_full = hist_sorted[hist_sorted["date_utc"] >= cut].copy()
    if len(cal_full) < 25:
        split_idx = max(int(len(hist_sorted) * 0.8), len(hist_sorted) - 30)
        tr_full = hist_sorted.iloc[:split_idx].copy()
        cal_full = hist_sorted.iloc[split_idx:].copy()
    full_xgb = _fit_xgb(tr_full, cal_full, feature_cols, params)
    return {
        "league_id": EPL_LEAGUE_ID,
        "enabled": True,
        "feature_cols": feature_cols,
        "xgb_model": full_xgb["model"],
        "xgb_best_iter": full_xgb["best_iter"],
        "iso": full_xgb["iso"],
        "feature_priors": full_xgb["feature_priors"],
        "poisson": train_poisson_pair(
            tr=tr_full,
            cal=cal_full,
            val=cal_full,
            feature_cols=feature_cols,
            ts_col="date_utc",
            now_override=None,
        ),
        "alpha_mix": float(best["alpha_mix"]),
        "alpha_market": float(best["alpha_mkt"]),
        "shadow_roi": float(best["roi"]),
        "shadow_profit": float(best["profit"]),
        "shadow_bets": int(best["bets"]),
        "shadow_ll": float(best["ll"]),
        "shadow_brier": float(best["brier"]),
        "params": params,
    }


def train_epl_totals_model(df_train: pd.DataFrame) -> Dict[str, object]:
    hist = df_train[df_train["league_id"].astype(int) == EPL_LEAGUE_ID].copy().sort_values("date_utc")
    if len(hist) < 180:
        bundle = {"league_id": EPL_LEAGUE_ID, "enabled": False}
        joblib.dump(bundle, TOTALS_EPL_MODEL_PATH)
        return bundle

    feature_cols = select_totals_feature_cols(hist)
    param_grid = [
        {"eta": 0.02, "max_depth": 4, "min_child_weight": 8.0},
        {"eta": 0.03, "max_depth": 4, "min_child_weight": 8.0},
        {"eta": 0.02, "max_depth": 5, "min_child_weight": 10.0},
        {"eta": 0.03, "max_depth": 5, "min_child_weight": 10.0},
        {"eta": 0.04, "max_depth": 5, "min_child_weight": 12.0},
        {"eta": 0.03, "max_depth": 6, "min_child_weight": 12.0},
    ]

    best_bundle = None
    best_key = None
    for params in param_grid:
        try:
            bundle = _train_single_bundle(hist, feature_cols, params)
        except Exception:
            continue
        if bundle is None:
            continue
        key = (-bundle["shadow_roi"], -bundle["shadow_profit"], bundle["shadow_ll"], bundle["shadow_brier"])
        if best_key is None or key < best_key:
            best_key = key
            best_bundle = bundle

    if best_bundle is None:
        best_bundle = {"league_id": EPL_LEAGUE_ID, "enabled": False}

    joblib.dump(best_bundle, TOTALS_EPL_MODEL_PATH)
    return best_bundle


def apply_epl_totals_model(df: pd.DataFrame, p_base: np.ndarray, model_bundle: Optional[Dict[str, object]]) -> np.ndarray:
    if not model_bundle or not model_bundle.get("enabled") or "league_id" not in df.columns:
        return _safe_prob(p_base)

    out = _safe_prob(p_base)
    df_local = df.reset_index(drop=True).copy()
    for lid, part in df_local.groupby("league_id"):
        if int(lid) != EPL_LEAGUE_ID:
            continue
        p_xgb = _predict_xgb(part, model_bundle)
        pois = model_bundle["poisson"]
        x = (
            part[model_bundle["feature_cols"]]
            .replace([np.inf, -np.inf], np.nan)
            .fillna(pd.Series(model_bundle["feature_priors"]))
            .fillna(0.0)
        )
        dmat = xgb.DMatrix(x, feature_names=model_bundle["feature_cols"])
        n_best_h = int(pois.get("n_best_home") or 0)
        n_best_a = int(pois.get("n_best_away") or 0)
        pred_h = pois["model_home"].predict(dmat, iteration_range=(0, n_best_h)) if n_best_h else pois["model_home"].predict(dmat)
        pred_a = pois["model_away"].predict(dmat, iteration_range=(0, n_best_a)) if n_best_a else pois["model_away"].predict(dmat)
        _, p_pois = build_poisson_probs_for_arrays(np.clip(np.exp(pred_h), 1e-6, 5.0), np.clip(np.exp(pred_a), 1e-6, 5.0))
        p_mix = _safe_prob(float(model_bundle["alpha_mix"]) * p_pois + (1.0 - float(model_bundle["alpha_mix"])) * p_xgb)
        p_mkt = _compute_p_over_mkt(part)
        p_final = _safe_blend(p_mix, p_mkt, float(model_bundle["alpha_market"]))
        out[part.index.to_numpy()] = p_final
    return out
