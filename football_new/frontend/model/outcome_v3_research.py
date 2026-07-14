import json
from pathlib import Path
import sys
from typing import Any

import numpy as np
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, log_loss

THIS_DIR = Path(__file__).resolve().parent
if str(THIS_DIR) not in sys.path:
    sys.path.insert(0, str(THIS_DIR))

from data.build_dataset import build_dataset
from data.loader import load_stats
from data.splits import recency_weights, temporal_split_by_league
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.match_context import build_match_context_features
from features.outcome_script import add_outcome_scenario_features, build_result_script_features
from features.opponent_segments import build_opponent_segment_features
from features.season_motivation import build_season_motivation_features
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form
from models.blending import sanitize_prob
from models.calibration import fit_multinomial_lr_calibrator, apply_multinomial_lr
from models.poisson import build_poisson_probs_for_arrays, train_poisson_pair
from outcome_catboost_research import (
    _build_cb_feature_sets,
    _prepare_cb_frame,
    _prepare_y_outcome_3,
    _safe_market_probs,
    _metric_pack,
)
from train_outcomes import (
    CAL_DAYS,
    GAP_DAYS,
    VAL_DAYS,
    _train_outcomes_single,
)


OUT_PATH = Path("tmp/outcome_v3_research.json")
BASE_CATEGORICAL_COLS = ["league_id", "home_team_id", "away_team_id"]
EPL_HOME_DEBIAS = {
    "enabled": True,
    "league_id": 39,
    "alpha": 0.75,
    "threshold": 0.02,
    "away_share": 0.70,
}
FACT_HOME_STABILIZER = {
    "enabled": True,
    "base_alpha": 0.55,
    "threshold": 0.015,
    "away_share": 0.72,
    "min_score": 0.45,
    "epl_boost": 1.15,
}
EPL_FINAL_ANCHOR = {
    "enabled": True,
    "league_id": 39,
}


def _build_contradiction_features(df: pd.DataFrame) -> pd.DataFrame:
    out = pd.DataFrame({"fixture_id": df["fixture_id"].values}, index=df.index)

    def _num(col: str, default: float = 0.0) -> pd.Series:
        if col not in df.columns:
            return pd.Series(default, index=df.index, dtype=float)
        return pd.to_numeric(df[col], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(default)

    p_home = _num("p_home_norm")
    p_draw = _num("p_draw_norm")
    p_away = _num("p_away_norm")
    elo_diff = _num("elo_diff")
    points_last5_diff = _num("mc_points_last5_diff")
    season_avg_diff = _num("mc_points_season_avg_diff")
    points_diff = _num("sm_points_diff")
    pos_diff = _num("sm_position_diff")
    xg_ema_diff = _num("xg_ema_diff")
    matchup_home_att = _num("ls_matchup_home_attack_vs_away_def_10")
    matchup_away_att = _num("ls_matchup_away_attack_vs_home_def_10")
    attack_xg_diff = _num("tp_attack_xg_diff")
    defense_xga_diff = _num("tp_defense_xga_diff")

    out["cf_market_home_minus_away"] = p_home - p_away
    out["cf_market_home_minus_draw"] = p_home - p_draw
    out["cf_market_entropy_like"] = -(p_home * np.log(np.clip(p_home, 1e-6, 1.0)) + p_draw * np.log(np.clip(p_draw, 1e-6, 1.0)) + p_away * np.log(np.clip(p_away, 1e-6, 1.0)))

    out["cf_elo_home_edge_flag"] = (elo_diff > 40.0).astype(float)
    out["cf_elo_away_edge_flag"] = (elo_diff < -40.0).astype(float)
    out["cf_form_home_edge_flag"] = ((points_last5_diff > 0.75) | (season_avg_diff > 0.35)).astype(float)
    out["cf_form_away_edge_flag"] = ((points_last5_diff < -0.75) | (season_avg_diff < -0.35)).astype(float)
    out["cf_table_home_edge_flag"] = ((points_diff > 6.0) | (pos_diff > 4.0)).astype(float)
    out["cf_table_away_edge_flag"] = ((points_diff < -6.0) | (pos_diff < -4.0)).astype(float)
    out["cf_xg_home_edge_flag"] = ((xg_ema_diff > 0.15) | (attack_xg_diff > 0.08)).astype(float)
    out["cf_xg_away_edge_flag"] = ((xg_ema_diff < -0.15) | (attack_xg_diff < -0.08)).astype(float)
    out["cf_matchup_home_edge_flag"] = (matchup_home_att > matchup_away_att + 0.10).astype(float)
    out["cf_matchup_away_edge_flag"] = (matchup_away_att > matchup_home_att + 0.10).astype(float)

    out["cf_home_fact_score"] = (
        0.25 * out["cf_elo_home_edge_flag"]
        + 0.20 * out["cf_form_home_edge_flag"]
        + 0.20 * out["cf_table_home_edge_flag"]
        + 0.20 * out["cf_xg_home_edge_flag"]
        + 0.15 * out["cf_matchup_home_edge_flag"]
    )
    out["cf_away_fact_score"] = (
        0.25 * out["cf_elo_away_edge_flag"]
        + 0.20 * out["cf_form_away_edge_flag"]
        + 0.20 * out["cf_table_away_edge_flag"]
        + 0.20 * out["cf_xg_away_edge_flag"]
        + 0.15 * out["cf_matchup_away_edge_flag"]
    )
    out["cf_fact_score_diff"] = out["cf_home_fact_score"] - out["cf_away_fact_score"]

    out["cf_market_home_but_facts_away"] = (
        (p_home > p_away)
        & (out["cf_away_fact_score"] > out["cf_home_fact_score"] + 0.20)
    ).astype(float)
    out["cf_market_away_but_facts_home"] = (
        (p_away > p_home)
        & (out["cf_home_fact_score"] > out["cf_away_fact_score"] + 0.20)
    ).astype(float)

    out["cf_market_away_and_facts_away"] = (
        (p_away > p_home + 0.04)
        & (out["cf_away_fact_score"] >= 0.45)
    ).astype(float)
    out["cf_market_home_and_facts_home"] = (
        (p_home > p_away + 0.04)
        & (out["cf_home_fact_score"] >= 0.45)
    ).astype(float)

    out["cf_home_contradiction_score"] = (
        0.35 * (p_away > p_home + 0.04).astype(float)
        + 0.20 * out["cf_elo_away_edge_flag"]
        + 0.15 * out["cf_form_away_edge_flag"]
        + 0.10 * out["cf_table_away_edge_flag"]
        + 0.10 * out["cf_xg_away_edge_flag"]
        + 0.10 * out["cf_matchup_away_edge_flag"]
    )
    out["cf_away_contradiction_score"] = (
        0.35 * (p_home > p_away + 0.04).astype(float)
        + 0.20 * out["cf_elo_home_edge_flag"]
        + 0.15 * out["cf_form_home_edge_flag"]
        + 0.10 * out["cf_table_home_edge_flag"]
        + 0.10 * out["cf_xg_home_edge_flag"]
        + 0.10 * out["cf_matchup_home_edge_flag"]
    )
    out["cf_defense_xga_diff"] = defense_xga_diff
    return out.replace([np.inf, -np.inf], np.nan).fillna(0.0)


def _weighted_metric(metrics: dict[int, dict], key: str) -> float | None:
    rows = [(int(v["val_n"]), float(v[key])) for v in metrics.values() if key in v and v.get("val_n")]
    if not rows:
        return None
    total_n = sum(n for n, _ in rows)
    if total_n <= 0:
        return None
    return sum(n * val for n, val in rows) / total_n


def _prepare_y_draw(df: pd.DataFrame) -> np.ndarray:
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    return (h == a).astype(int).values


def _prepare_y_side(df: pd.DataFrame) -> np.ndarray:
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    return (h > a).astype(int).values


def _safe_logit(p: np.ndarray) -> np.ndarray:
    p = np.clip(np.asarray(p, dtype=float), 1e-6, 1 - 1e-6)
    return np.log(p / (1.0 - p))


def _draw_risk_features(df: pd.DataFrame, p_market: np.ndarray, p_pois: np.ndarray | None = None) -> pd.DataFrame:
    out = pd.DataFrame(index=df.index)
    out["market_draw_prob"] = p_market[:, 1]
    if p_pois is None:
        out["poisson_draw_prob"] = 0.0
        out["poisson_entropy"] = 0.0
    else:
        out["poisson_draw_prob"] = p_pois[:, 1]
        out["poisson_entropy"] = -np.sum(np.clip(p_pois, 1e-6, 1.0) * np.log(np.clip(p_pois, 1e-6, 1.0)), axis=1)
    out["market_entropy"] = -np.sum(np.clip(p_market, 1e-6, 1.0) * np.log(np.clip(p_market, 1e-6, 1.0)), axis=1)

    for src, col in [
        ("elo_diff", "elo_diff_abs"),
        ("tp_match_balance_abs", "tp_match_balance_abs"),
        ("tp_match_openness", "tp_match_openness"),
        ("mc_strength_gap", "mc_strength_gap_abs"),
        ("goal_diff_avg_6_diff", "goal_diff_avg_6_diff_abs"),
    ]:
        if src in df.columns:
            series = pd.to_numeric(df[src], errors="coerce")
            out[col] = series.abs() if col.endswith("_abs") else series

    out["similar_strength_flag"] = (
        (out.get("elo_diff_abs", pd.Series(np.nan, index=df.index)).fillna(999.0) < 50.0)
        .astype(int)
    )
    out["draw_risk_score"] = (
        0.45 * out["market_draw_prob"].fillna(0.0)
        + 0.35 * out["poisson_draw_prob"].fillna(0.0)
        + 0.10 * out["similar_strength_flag"].astype(float)
        + 0.10 * (out.get("market_entropy", pd.Series(0.0, index=df.index)).fillna(0.0))
    )
    return out.replace([np.inf, -np.inf], np.nan).fillna(0.0)


def _prepare_numeric(df: pd.DataFrame, cols: list[str]) -> pd.DataFrame:
    X = df[cols].copy()
    for c in cols:
        X[c] = pd.to_numeric(X[c], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(0.0)
    return X


def _fit_catboost_multiclass(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    numeric_cols: list[str],
    categorical_cols: list[str],
) -> tuple[np.ndarray, np.ndarray]:
    from catboost import CatBoostClassifier

    X_tr = _prepare_cb_frame(tr, numeric_cols, categorical_cols)
    X_cal = _prepare_cb_frame(cal, numeric_cols, categorical_cols)
    X_val = _prepare_cb_frame(val, numeric_cols, categorical_cols)
    y_tr = _prepare_y_outcome_3(tr)
    y_cal = _prepare_y_outcome_3(cal)
    cat_idx = [X_tr.columns.get_loc(c) for c in categorical_cols]
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)

    model = CatBoostClassifier(
        loss_function="MultiClass",
        eval_metric="MultiClass",
        iterations=1200,
        learning_rate=0.03,
        depth=6,
        l2_leaf_reg=8.0,
        random_strength=1.5,
        bagging_temperature=0.5,
        min_data_in_leaf=20,
        random_seed=123,
        verbose=False,
        allow_writing_files=False,
    )
    model.fit(
        X_tr,
        y_tr,
        sample_weight=w_tr,
        cat_features=cat_idx,
        eval_set=(X_cal, y_cal),
        use_best_model=True,
    )
    return sanitize_prob(model.predict_proba(X_cal)), sanitize_prob(model.predict_proba(X_val))


def _fit_catboost_binary(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    numeric_cols: list[str],
    categorical_cols: list[str],
    y_tr: np.ndarray,
    y_cal: np.ndarray,
    pred_cal: pd.DataFrame | None = None,
    pred_val: pd.DataFrame | None = None,
) -> tuple[np.ndarray, np.ndarray]:
    from catboost import CatBoostClassifier

    X_tr = _prepare_cb_frame(tr, numeric_cols, categorical_cols)
    X_cal = _prepare_cb_frame(cal, numeric_cols, categorical_cols)
    X_pred_cal = _prepare_cb_frame(pred_cal if pred_cal is not None else cal, numeric_cols, categorical_cols)
    X_pred_val = _prepare_cb_frame(pred_val if pred_val is not None else val, numeric_cols, categorical_cols)
    cat_idx = [X_tr.columns.get_loc(c) for c in categorical_cols]
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)

    model = CatBoostClassifier(
        loss_function="Logloss",
        eval_metric="Logloss",
        iterations=1000,
        learning_rate=0.03,
        depth=5,
        l2_leaf_reg=8.0,
        random_strength=1.5,
        bagging_temperature=0.5,
        min_data_in_leaf=20,
        random_seed=123,
        verbose=False,
        allow_writing_files=False,
    )
    model.fit(
        X_tr,
        y_tr,
        sample_weight=w_tr,
        cat_features=cat_idx,
        eval_set=(X_cal, y_cal),
        use_best_model=True,
    )
    return sanitize_prob(model.predict_proba(X_pred_cal)[:, 1]), sanitize_prob(model.predict_proba(X_pred_val)[:, 1])


def _compose_from_draw_side(p_draw: np.ndarray, p_home_not_draw: np.ndarray) -> np.ndarray:
    p_draw = sanitize_prob(p_draw)
    p_home_not_draw = sanitize_prob(p_home_not_draw)
    p_home = (1.0 - p_draw) * p_home_not_draw
    p_away = (1.0 - p_draw) * (1.0 - p_home_not_draw)
    P = np.stack([p_away, p_draw, p_home], axis=1)
    return sanitize_prob(P / np.clip(P.sum(axis=1, keepdims=True), 1e-6, None))


def _blend_probs(
    p_cb: np.ndarray,
    p_pois: np.ndarray,
    p_market: np.ndarray,
    p_draw_side: np.ndarray,
    weights: tuple[float, float, float, float],
) -> np.ndarray:
    w_cb, w_pois, w_mkt, w_ds = weights
    out = (w_cb * p_cb) + (w_pois * p_pois) + (w_mkt * p_market) + (w_ds * p_draw_side)
    out = sanitize_prob(out)
    return out / out.sum(axis=1, keepdims=True)


def _fact_home_contradiction_score(df: pd.DataFrame, P_market: np.ndarray, P_pois: np.ndarray) -> np.ndarray:
    idx = df.index

    def _num(col: str, default: float = 0.0) -> pd.Series:
        if col not in df.columns:
            return pd.Series(default, index=idx, dtype=float)
        return pd.to_numeric(df[col], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(default)

    market_home = pd.Series(P_market[:, 2], index=idx)
    market_away = pd.Series(P_market[:, 0], index=idx)
    pois_home = pd.Series(P_pois[:, 2], index=idx)
    pois_away = pd.Series(P_pois[:, 0], index=idx)

    elo_diff = _num("elo_diff")
    points_last5_diff = _num("mc_points_last5_diff")
    season_avg_diff = _num("mc_points_season_avg_diff")
    points_diff = _num("sm_points_diff")
    pos_diff = _num("sm_position_diff")
    xg_ema_diff = _num("xg_ema_diff")
    matchup_home_att = _num("ls_matchup_home_attack_vs_away_def_10")
    matchup_away_att = _num("ls_matchup_away_attack_vs_home_def_10")

    score = pd.Series(0.0, index=idx, dtype=float)
    score += 0.28 * (market_away > market_home + 0.04).astype(float)
    score += 0.18 * (pois_away > pois_home + 0.08).astype(float)
    score += 0.16 * (elo_diff < -55.0).astype(float)
    score += 0.12 * (points_last5_diff < -0.9).astype(float)
    score += 0.08 * (season_avg_diff < -0.45).astype(float)
    score += 0.08 * (points_diff < -8.0).astype(float)
    score += 0.05 * (pos_diff < -5.0).astype(float)
    score += 0.03 * (xg_ema_diff < -0.18).astype(float)
    score += 0.02 * (matchup_away_att > matchup_home_att + 0.18).astype(float)
    return score.clip(0.0, 1.0).values


def _apply_prob_stabilizers(
    P: np.ndarray,
    P_market: np.ndarray,
    P_pois: np.ndarray,
    df: pd.DataFrame,
    league_id: int,
) -> np.ndarray:
    P = sanitize_prob(np.asarray(P, dtype=float)).copy()
    P_market = sanitize_prob(np.asarray(P_market, dtype=float))
    P_pois = sanitize_prob(np.asarray(P_pois, dtype=float))

    if FACT_HOME_STABILIZER["enabled"]:
        contradiction = _fact_home_contradiction_score(df, P_market, P_pois)
        excess = np.maximum(0.0, P[:, 2] - P_market[:, 2] - float(FACT_HOME_STABILIZER["threshold"]))
        alpha = float(FACT_HOME_STABILIZER["base_alpha"])
        if int(league_id) == int(EPL_HOME_DEBIAS["league_id"]):
            alpha *= float(FACT_HOME_STABILIZER["epl_boost"])
        active = contradiction >= float(FACT_HOME_STABILIZER["min_score"])
        shift = alpha * excess * contradiction * active.astype(float)
        if np.any(shift > 0):
            P[:, 2] -= shift
            P[:, 0] += shift * float(FACT_HOME_STABILIZER["away_share"])
            P[:, 1] += shift * (1.0 - float(FACT_HOME_STABILIZER["away_share"]))

    if EPL_HOME_DEBIAS["enabled"] and int(league_id) == int(EPL_HOME_DEBIAS["league_id"]):
        excess = np.maximum(0.0, P[:, 2] - P_market[:, 2] - float(EPL_HOME_DEBIAS["threshold"]))
        shift = float(EPL_HOME_DEBIAS["alpha"]) * excess
        if np.any(shift > 0):
            P[:, 2] -= shift
            P[:, 0] += shift * float(EPL_HOME_DEBIAS["away_share"])
            P[:, 1] += shift * (1.0 - float(EPL_HOME_DEBIAS["away_share"]))

    P = np.clip(P, 1e-6, 1 - 1e-6)
    return P / P.sum(axis=1, keepdims=True)


def _search_market_anchor(y_cal: np.ndarray, P_cal: np.ndarray, P_market: np.ndarray) -> tuple[float, float]:
    best_alpha = 0.0
    best_ll = float(log_loss(y_cal, sanitize_prob(P_cal), labels=[0, 1, 2]))
    for alpha in np.linspace(0.0, 0.70, 15):
        P_try = sanitize_prob((1.0 - alpha) * P_cal + alpha * P_market)
        P_try = P_try / np.clip(P_try.sum(axis=1, keepdims=True), 1e-6, None)
        ll = float(log_loss(y_cal, P_try, labels=[0, 1, 2]))
        if ll < best_ll:
            best_ll = ll
            best_alpha = float(alpha)
    return best_alpha, best_ll


def _apply_market_anchor(P: np.ndarray, P_market: np.ndarray, alpha: float) -> np.ndarray:
    if alpha <= 0:
        return sanitize_prob(P)
    out = sanitize_prob((1.0 - alpha) * P + alpha * P_market)
    return out / np.clip(out.sum(axis=1, keepdims=True), 1e-6, None)


def _search_blend_weights(y_cal: np.ndarray, P_cb: np.ndarray, P_pois: np.ndarray, P_mkt: np.ndarray, P_ds: np.ndarray):
    best = None
    best_ll = float("inf")
    for w_cb in np.linspace(0.35, 0.65, 7):
        for w_pois in np.linspace(0.10, 0.25, 4):
            for w_mkt in np.linspace(0.15, 0.35, 5):
                for w_ds in np.linspace(0.00, 0.15, 4):
                    s = w_cb + w_pois + w_mkt + w_ds
                    if not (0.99 <= s <= 1.01):
                        continue
                    weights = tuple(float(x / s) for x in (w_cb, w_pois, w_mkt, w_ds))
                    P_try = _blend_probs(P_cb, P_pois, P_mkt, P_ds, weights)
                    ll = log_loss(y_cal, P_try, labels=[0, 1, 2])
                    if ll < best_ll:
                        best_ll = float(ll)
                        best = weights
    return best, best_ll


def _run_market_only(df_full: pd.DataFrame) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[(df_full["league_id"] == lid) & (df_full["has_result"])].copy()
        if subset.empty:
            continue
        _, _, val = temporal_split_by_league(
            subset,
            ts_col="date_utc",
            league_col="league_id",
            cal_days=CAL_DAYS,
            val_days=VAL_DAYS,
            gap_days=GAP_DAYS,
            min_cal_per_league=12,
            min_val_per_league=6,
            now_override=None,
        )
        if val.empty:
            continue
        y_val = _prepare_y_outcome_3(val)
        out[lid] = _metric_pack(y_val, _safe_market_probs(val))
    return out


def _run_current_stack(df_full: pd.DataFrame) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[df_full["league_id"] == lid].copy()
        if subset.empty:
            continue
        try:
            out[lid] = _train_outcomes_single(subset, league_id=lid)["metrics"]
        except RuntimeError as exc:
            out[lid] = {"error": str(exc)}
    return out


def _run_v3_by_league(df_full: pd.DataFrame) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[(df_full["league_id"] == lid) & (df_full["has_result"])].copy().reset_index(drop=True)
        if subset.empty:
            continue

        tr, cal, val = temporal_split_by_league(
            subset,
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
            continue

        numeric_base, numeric_market, categorical = _build_cb_feature_sets(subset)
        categorical = [c for c in BASE_CATEGORICAL_COLS if c in categorical]

        P_cal_cb, P_val_cb = _fit_catboost_multiclass(tr, cal, val, numeric_market, categorical)

        pois = train_poisson_pair(
            tr=tr,
            cal=cal,
            val=val,
            feature_cols=numeric_base,
            ts_col="date_utc",
            now_override=None,
        )
        P_cal_pois, _ = build_poisson_probs_for_arrays(pois["lam_cal_home"], pois["lam_cal_away"])
        P_val_pois, _ = build_poisson_probs_for_arrays(pois["lam_val_home"], pois["lam_val_away"])
        P_cal_mkt = _safe_market_probs(cal)
        P_val_mkt = _safe_market_probs(val)

        draw_cal_feats = _draw_risk_features(cal, P_cal_mkt, P_cal_pois)
        draw_val_feats = _draw_risk_features(val, P_val_mkt, P_val_pois)
        draw_num_cols = list(draw_cal_feats.columns)
        draw_cat_cols = [c for c in categorical if c in cal.columns]
        cal_draw_frame = pd.concat([cal.reset_index(drop=True), draw_cal_feats.reset_index(drop=True)], axis=1)
        val_draw_frame = pd.concat([val.reset_index(drop=True), draw_val_feats.reset_index(drop=True)], axis=1)
        tr_draw_feats = _draw_risk_features(tr, _safe_market_probs(tr), None)
        tr_draw_frame = pd.concat([tr.reset_index(drop=True), tr_draw_feats.reset_index(drop=True)], axis=1)

        p_cal_draw = None
        p_val_draw = None
        try:
            p_cal_draw, p_val_draw = _fit_catboost_binary(
                tr_draw_frame,
                cal_draw_frame,
                val_draw_frame,
                draw_num_cols,
                draw_cat_cols,
                _prepare_y_draw(tr),
                _prepare_y_draw(cal),
            )
        except Exception:
            p_cal_draw = P_cal_mkt[:, 1]
            p_val_draw = P_val_mkt[:, 1]

        tr_side = tr[_prepare_y_draw(tr) == 0].copy()
        cal_side = cal[_prepare_y_draw(cal) == 0].copy()
        val_side = val.copy()
        p_cal_side = None
        p_val_side = None
        try:
            p_cal_side_raw, p_val_side_raw = _fit_catboost_binary(
                tr_side,
                cal_side,
                val_side,
                numeric_market,
                categorical,
                _prepare_y_side(tr_side),
                _prepare_y_side(cal_side),
                pred_cal=cal,
                pred_val=val,
            )
            p_cal_side = p_cal_side_raw
            p_val_side = p_val_side_raw
        except Exception:
            denom_cal = np.clip(1.0 - P_cal_mkt[:, 1], 1e-6, None)
            denom_val = np.clip(1.0 - P_val_mkt[:, 1], 1e-6, None)
            p_cal_side = np.clip(P_cal_mkt[:, 2] / denom_cal, 1e-6, 1 - 1e-6)
            p_val_side = np.clip(P_val_mkt[:, 2] / denom_val, 1e-6, 1 - 1e-6)

        P_cal_ds = _compose_from_draw_side(p_cal_draw, p_cal_side)
        P_val_ds = _compose_from_draw_side(p_val_draw, p_val_side)

        y_cal = _prepare_y_outcome_3(cal)
        y_val = _prepare_y_outcome_3(val)
        weights, best_ll = _search_blend_weights(y_cal, P_cal_cb, P_cal_pois, P_cal_mkt, P_cal_ds)
        P_cal_blend = _blend_probs(P_cal_cb, P_cal_pois, P_cal_mkt, P_cal_ds, weights)
        P_val_blend = _blend_probs(P_val_cb, P_val_pois, P_val_mkt, P_val_ds, weights)
        P_cal_blend = _apply_prob_stabilizers(P_cal_blend, P_cal_mkt, P_cal_pois, cal, lid)
        P_val_blend = _apply_prob_stabilizers(P_val_blend, P_val_mkt, P_val_pois, val, lid)

        cal_lr = fit_multinomial_lr_calibrator(P_cal_blend, y_cal)
        P_cal_final = apply_multinomial_lr(P_cal_blend, cal["league_id"], cal_lr, {})
        P_val_final = apply_multinomial_lr(P_val_blend, val["league_id"], cal_lr, {})

        epl_anchor_alpha = 0.0
        epl_anchor_cal_ll = None
        if EPL_FINAL_ANCHOR["enabled"] and int(lid) == int(EPL_FINAL_ANCHOR["league_id"]):
            epl_anchor_alpha, epl_anchor_cal_ll = _search_market_anchor(y_cal, P_cal_final, P_cal_mkt)
            P_val_final = _apply_market_anchor(P_val_final, P_val_mkt, epl_anchor_alpha)

        metrics = _metric_pack(y_val, P_val_final)
        metrics["blend_weights"] = {
            "catboost": weights[0],
            "poisson": weights[1],
            "market": weights[2],
            "draw_side": weights[3],
        }
        metrics["cal_ll_best"] = best_ll
        metrics["epl_anchor_alpha"] = epl_anchor_alpha
        metrics["epl_anchor_cal_ll"] = epl_anchor_cal_ll
        out[lid] = metrics
    return out


def main():
    print("=== BUILD DATASET FOR OUTCOME V3 RESEARCH ===")
    df_all = build_dataset(return_all=True)
    print(f"RAW: {df_all.shape}")

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    feats = [
        build_elo_features(df_all, mode="train"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_team_potential_features(df_all),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
        build_match_context_features(df_all, lookback=5),
        build_season_motivation_features(df_all),
        build_opponent_segment_features(df_all, windows=(5, 10)),
        _build_contradiction_features(df_all),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)
    df_train = df_all[df_all["has_result"]].copy()
    print(f"TRAIN: {df_train.shape}")

    market = _run_market_only(df_train)
    current = _run_current_stack(df_train)
    v3 = _run_v3_by_league(df_train)

    report = {
        "market_only": {
            "by_league": market,
            "weighted_val_acc": _weighted_metric(market, "val_acc"),
            "weighted_val_ll": _weighted_metric(market, "val_ll"),
        },
        "current_stack": {
            "by_league": current,
            "weighted_val_acc": _weighted_metric(current, "val_acc"),
            "weighted_val_ll": _weighted_metric(current, "val_ll"),
        },
        "outcome_v3": {
            "by_league": v3,
            "weighted_val_acc": _weighted_metric(v3, "val_acc"),
            "weighted_val_ll": _weighted_metric(v3, "val_ll"),
        },
    }
    cur_ll = report["current_stack"]["weighted_val_ll"]
    mkt_ll = report["market_only"]["weighted_val_ll"]
    v3_ll = report["outcome_v3"]["weighted_val_ll"]
    report["delta"] = {
        "v3_vs_current_val_ll": None if v3_ll is None or cur_ll is None else float(v3_ll - cur_ll),
        "v3_vs_market_val_ll": None if v3_ll is None or mkt_ll is None else float(v3_ll - mkt_ll),
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
