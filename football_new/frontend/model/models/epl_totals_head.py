from typing import Dict, List, Optional

import joblib
import numpy as np
import pandas as pd
import xgboost as xgb
from sklearn.isotonic import IsotonicRegression
from sklearn.metrics import log_loss

from config import CAL_DAYS, TOTALS_EPL_HEAD_MODEL_PATH, VAL_DAYS
from data.splits import recency_weights, temporal_split_by_league
from decision.totals_policy import apply_total_league_policy, should_block_total_candidate


EPL_LEAGUE_ID = 39
HEAD_CANDIDATE_COLS = [
    "p_base_shadow",
    "p_over_mkt",
    "overround_1x2",
    "n_bookmakers",
    "p_home_norm",
    "p_draw_norm",
    "p_away_norm",
    "tp_match_openness",
    "tp_match_tempo_sum",
    "tp_match_balance_abs",
    "tp_match_control_balance_abs",
    "tp_match_quality_edge_abs",
    "tp_home_attack_xg",
    "tp_away_attack_xg",
    "tp_home_matchup_attack_vs_defense",
    "tp_away_matchup_attack_vs_defense",
    "home_us_npxg_all_5",
    "away_us_npxg_all_5",
    "home_us_npxga_all_5",
    "away_us_npxga_all_5",
    "home_xg_ema",
    "away_xg_ema",
]


def _safe_prob(p: np.ndarray) -> np.ndarray:
    arr = np.asarray(p, dtype=float)
    return np.clip(arr, 1e-6, 1.0 - 1e-6)


def _compute_p_over_mkt(df: pd.DataFrame) -> np.ndarray:
    over = pd.to_numeric(df.get("avg_odds_over25"), errors="coerce")
    under = pd.to_numeric(df.get("avg_odds_under25"), errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    p = imp_over / overround
    return pd.to_numeric(p, errors="coerce").to_numpy(dtype=float)


def _prepare_feature_cols(df: pd.DataFrame) -> List[str]:
    return [c for c in HEAD_CANDIDATE_COLS if c in df.columns]


def _fit_head_model(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    feature_cols: List[str],
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
    y_tr = pd.to_numeric(tr["target_over25"], errors="coerce").fillna(0.0).astype(int).to_numpy()
    y_cal = pd.to_numeric(cal["target_over25"], errors="coerce").fillna(0.0).astype(int).to_numpy()
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)

    dtr = xgb.DMatrix(x_tr, label=y_tr, weight=w_tr, feature_names=feature_cols)
    dcal = xgb.DMatrix(x_cal, label=y_cal, feature_names=feature_cols)
    params = {
        "objective": "binary:logistic",
        "eta": 0.03,
        "max_depth": 4,
        "min_child_weight": 8.0,
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
        num_boost_round=800,
        evals=[(dtr, "train"), (dcal, "cal")],
        early_stopping_rounds=80,
        verbose_eval=False,
    )
    best_iter = model.best_iteration + 1 if model.best_iteration is not None else None
    raw = model.predict(dcal, iteration_range=(0, best_iter)) if best_iter else model.predict(dcal)
    iso = IsotonicRegression(out_of_bounds="clip", y_min=0.0, y_max=1.0)
    try:
        iso.fit(raw, y_cal)
    except Exception:
        iso = None
    return {
        "model": model,
        "best_iter": best_iter,
        "feature_cols": feature_cols,
        "feature_priors": priors,
        "iso": iso,
    }


def _predict_head(df: pd.DataFrame, bundle: Dict[str, object]) -> np.ndarray:
    feature_cols = bundle["feature_cols"]
    df_local = df.copy()
    if "p_base_shadow" in feature_cols and "p_base_shadow" not in df_local.columns:
        raise KeyError("p_base_shadow helper column is required for EPL totals head inference")
    x = (
        df_local[feature_cols]
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


def _fit_final_bundle(df_hist: pd.DataFrame, feature_cols: List[str]) -> Optional[Dict[str, object]]:
    if len(df_hist) < 140:
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
    return _fit_head_model(tr, cal, feature_cols)


def _ev(p: float, odds: float) -> Optional[float]:
    if p is None or odds is None or not np.isfinite(p) or not np.isfinite(odds) or odds <= 1.01:
        return None
    return float(p * odds - 1.0)


def _profit_total(outcome: str, odds: float, home_goals: float, away_goals: float) -> float:
    goals = float(home_goals) + float(away_goals)
    if outcome == "Over2.5":
        return float(odds) - 1.0 if goals > 2.5 else -1.0
    return float(odds) - 1.0 if goals < 3.0 else -1.0


def _roi_score(df_val: pd.DataFrame, p_mix: np.ndarray) -> Dict[str, float]:
    profits: List[float] = []
    p_arr = _safe_prob(p_mix)
    for i, (_, row) in enumerate(df_val.iterrows()):
        row_dict = row.to_dict()
        row_dict["p_over25"] = float(p_arr[i])
        row_dict["p_under25"] = float(1.0 - p_arr[i])

        candidates = []
        for outcome, odds_key, prob in (
            ("Over2.5", "avg_odds_over25", row_dict["p_over25"]),
            ("Under2.5", "avg_odds_under25", row_dict["p_under25"]),
        ):
            odds = row_dict.get(odds_key)
            edge = _ev(prob, odds)
            if edge is None or edge < 0.02:
                continue
            if should_block_total_candidate(row_dict, outcome):
                continue
            candidates.append(("TOTAL", outcome, float(odds), float(edge)))

        candidates = apply_total_league_policy(row_dict, candidates)
        total_candidates = [c for c in candidates if c[0] == "TOTAL"]
        if not total_candidates:
            continue
        _, outcome, odds, _ = max(total_candidates, key=lambda x: x[3])
        profits.append(_profit_total(outcome, odds, row["home_goals"], row["away_goals"]))

    if not profits:
        return {"roi": -1.0, "profit": 0.0, "bets": 0}
    profit = float(np.sum(profits))
    bets = len(profits)
    return {"roi": profit / bets, "profit": profit, "bets": bets}


def train_epl_totals_head(df_train: pd.DataFrame, p_base_train: np.ndarray) -> Dict[str, object]:
    df = df_train.copy().reset_index(drop=True)
    df["p_base_shadow"] = _safe_prob(p_base_train)
    if "p_over_mkt" not in df.columns:
        df["p_over_mkt"] = _compute_p_over_mkt(df)

    hist = df[df["league_id"].astype(int) == EPL_LEAGUE_ID].copy().sort_values("date_utc")
    if len(hist) < 180:
        bundle = {"league_id": EPL_LEAGUE_ID, "enabled": False}
        joblib.dump(bundle, TOTALS_EPL_HEAD_MODEL_PATH)
        return bundle

    tr, cal, val = temporal_split_by_league(
        hist,
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
        bundle = {"league_id": EPL_LEAGUE_ID, "enabled": False}
        joblib.dump(bundle, TOTALS_EPL_HEAD_MODEL_PATH)
        return bundle

    feature_cols = _prepare_feature_cols(hist)
    shadow = _fit_head_model(tr, cal, feature_cols)
    p_head_val = _predict_head(val, shadow)
    p_base_val = _safe_prob(val["p_base_shadow"].to_numpy())
    y_val = pd.to_numeric(val["target_over25"], errors="coerce").fillna(0.0).astype(int).to_numpy()

    best = None
    for alpha in np.linspace(0.0, 1.0, 11):
        p_mix = _safe_prob((1.0 - alpha) * p_base_val + alpha * p_head_val)
        ll = log_loss(y_val, p_mix, labels=[0, 1])
        roi_stats = _roi_score(val, p_mix)
        key = (-roi_stats["roi"], -roi_stats["profit"], ll)
        if best is None or key < best["key"]:
            best = {
                "key": key,
                "alpha": float(alpha),
                "ll": float(ll),
                "roi": float(roi_stats["roi"]),
                "profit": float(roi_stats["profit"]),
                "bets": int(roi_stats["bets"]),
            }

    full = _fit_final_bundle(hist, feature_cols)
    if full is None:
        bundle = {"league_id": EPL_LEAGUE_ID, "enabled": False}
        joblib.dump(bundle, TOTALS_EPL_HEAD_MODEL_PATH)
        return bundle

    bundle = {
        "league_id": EPL_LEAGUE_ID,
        "enabled": True,
        "alpha": float(best["alpha"]),
        "head": full,
        "shadow_logloss": float(best["ll"]),
        "shadow_roi": float(best["roi"]),
        "shadow_profit": float(best["profit"]),
        "shadow_bets": int(best["bets"]),
    }
    joblib.dump(bundle, TOTALS_EPL_HEAD_MODEL_PATH)
    return bundle


def apply_epl_totals_head(df: pd.DataFrame, p_base: np.ndarray, head_bundle: Optional[Dict[str, object]]) -> np.ndarray:
    p = _safe_prob(p_base)
    if not head_bundle or not head_bundle.get("enabled") or "league_id" not in df.columns:
        return p

    out = p.copy()
    alpha = float(head_bundle.get("alpha", 0.0))
    if alpha <= 0:
        return out

    df_local = df.reset_index(drop=True).copy()
    df_local["p_base_shadow"] = _safe_prob(p_base)
    if "p_over_mkt" not in df_local.columns:
        df_local["p_over_mkt"] = _compute_p_over_mkt(df_local)
    for lid, part in df_local.groupby("league_id"):
        if int(lid) != EPL_LEAGUE_ID:
            continue
        p_head = _predict_head(part, head_bundle["head"])
        idx = part.index.to_numpy()
        out[idx] = _safe_prob((1.0 - alpha) * out[idx] + alpha * p_head)
    return out
