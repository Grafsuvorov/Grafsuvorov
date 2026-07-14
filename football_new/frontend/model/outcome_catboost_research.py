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
from features.team_potential import build_team_potential_features
from features.team_stats_form import build_team_stats_form
from models.blending import apply_market_anchor, sanitize_prob
from train_outcomes import (
    CAL_DAYS,
    GAP_DAYS,
    VAL_DAYS,
    MARKET_COLS_1X2,
    _train_outcomes_single,
    build_safe_feature_list,
)


OUT_PATH = Path("tmp/outcome_catboost_research.json")
CATEGORICAL_COLS = ["league_id", "home_team_id", "away_team_id"]
MARKET_NUMERIC_COLS = [
    "avg_odds_home",
    "avg_odds_draw",
    "avg_odds_away",
    "p_home_norm",
    "p_draw_norm",
    "p_away_norm",
    "overround_1x2",
    "n_bookmakers",
]


def _prepare_y_outcome_3(df: pd.DataFrame) -> np.ndarray:
    h = df["home_goals"].astype(float)
    a = df["away_goals"].astype(float)
    return np.where(h > a, 2, np.where(h < a, 0, 1)).astype(int)


def _weighted_metric(metrics: dict[int, dict], key: str) -> float | None:
    rows = [(int(v["val_n"]), float(v[key])) for v in metrics.values() if key in v and v.get("val_n")]
    if not rows:
        return None
    total_n = sum(n for n, _ in rows)
    if total_n <= 0:
        return None
    return sum(n * val for n, val in rows) / total_n


def _safe_market_probs(df: pd.DataFrame) -> np.ndarray:
    probs = np.stack(
        [
            df["p_away_norm"].astype(float).values,
            df["p_draw_norm"].astype(float).values,
            df["p_home_norm"].astype(float).values,
        ],
        axis=1,
    )
    return sanitize_prob(probs)


def _metric_pack(y: np.ndarray, p: np.ndarray) -> dict[str, Any]:
    pred = np.argmax(p, axis=1)
    return {
        "val_acc": float(accuracy_score(y, pred)),
        "val_ll": float(log_loss(y, p, labels=[0, 1, 2])),
        "val_n": int(len(y)),
    }


def _build_cb_feature_sets(df: pd.DataFrame) -> tuple[list[str], list[str], list[str]]:
    numeric_safe = build_safe_feature_list(df)
    numeric_base = [c for c in numeric_safe if c not in MARKET_NUMERIC_COLS]
    numeric_market = sorted(set(numeric_base + [c for c in MARKET_NUMERIC_COLS if c in df.columns]))
    categorical = [c for c in CATEGORICAL_COLS if c in df.columns]
    return numeric_base, numeric_market, categorical


def _prepare_cb_frame(df: pd.DataFrame, numeric_cols: list[str], categorical_cols: list[str]) -> pd.DataFrame:
    use_cols = list(numeric_cols) + list(categorical_cols)
    X = df[use_cols].copy()
    for c in numeric_cols:
        X[c] = pd.to_numeric(X[c], errors="coerce").replace([np.inf, -np.inf], np.nan).fillna(0.0)
    for c in categorical_cols:
        X[c] = X[c].astype("Int64").astype(str).fillna("NA")
    return X


def _train_catboost_variant(
    tr: pd.DataFrame,
    cal: pd.DataFrame,
    val: pd.DataFrame,
    numeric_cols: list[str],
    categorical_cols: list[str],
    use_market_anchor: bool,
) -> dict[str, Any]:
    try:
        from catboost import CatBoostClassifier
    except ImportError as exc:
        raise RuntimeError("catboost is not installed in frontend/model/.venv") from exc

    X_tr = _prepare_cb_frame(tr, numeric_cols, categorical_cols)
    X_cal = _prepare_cb_frame(cal, numeric_cols, categorical_cols)
    X_val = _prepare_cb_frame(val, numeric_cols, categorical_cols)

    y_tr = _prepare_y_outcome_3(tr)
    y_cal = _prepare_y_outcome_3(cal)
    y_val = _prepare_y_outcome_3(val)

    cat_idx = [X_tr.columns.get_loc(c) for c in categorical_cols]
    w_tr = recency_weights(tr, ts_col="date_utc", now_override=None)

    model = CatBoostClassifier(
        loss_function="MultiClass",
        eval_metric="MultiClass",
        iterations=900,
        learning_rate=0.03,
        depth=6,
        l2_leaf_reg=6.0,
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

    P_cal_raw = sanitize_prob(model.predict_proba(X_cal))
    P_val_raw = sanitize_prob(model.predict_proba(X_val))

    lr = LogisticRegression(max_iter=300, solver="lbfgs")
    lr.fit(P_cal_raw, y_cal)
    P_cal = sanitize_prob(lr.predict_proba(P_cal_raw))
    P_val = sanitize_prob(lr.predict_proba(P_val_raw))

    tau_market = 0.0
    if use_market_anchor and all(c in cal.columns for c in MARKET_COLS_1X2):
        Pm_cal = _safe_market_probs(cal)
        Pm_val = _safe_market_probs(val)
        best = (0.0, log_loss(y_cal, P_cal, labels=[0, 1, 2]))
        for tau in np.linspace(0.0, 0.6, 7):
            P_try = apply_market_anchor(P_cal, Pm_cal, float(tau))
            ll = log_loss(y_cal, P_try, labels=[0, 1, 2])
            if ll < best[1]:
                best = (float(tau), float(ll))
        tau_market = best[0]
        if tau_market > 0:
            P_cal = apply_market_anchor(P_cal, Pm_cal, tau_market)
            P_val = apply_market_anchor(P_val, Pm_val, tau_market)

    metrics = _metric_pack(y_val, P_val)
    metrics["tau_market"] = float(tau_market)
    metrics["n_numeric_features"] = int(len(numeric_cols))
    metrics["n_categorical_features"] = int(len(categorical_cols))
    return metrics


def _run_market_only(df_full: pd.DataFrame) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[(df_full["league_id"] == lid) & (df_full["has_result"])].copy()
        if subset.empty or not all(c in subset.columns for c in MARKET_COLS_1X2):
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
        Pm_val = _safe_market_probs(val)
        out[lid] = _metric_pack(y_val, Pm_val)
    return out


def _run_current_stack(df_full: pd.DataFrame) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[df_full["league_id"] == lid].copy()
        if subset.empty:
            continue
        try:
            res = _train_outcomes_single(subset, league_id=lid)
            out[lid] = res["metrics"]
        except RuntimeError as exc:
            out[lid] = {"error": str(exc)}
    return out


def _run_catboost(df_full: pd.DataFrame, use_market_features: bool, use_market_anchor: bool) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[(df_full["league_id"] == lid) & (df_full["has_result"])].copy().reset_index(drop=True)
        if subset.empty:
            continue
        try:
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
            numeric_cols = numeric_market if use_market_features else numeric_base
            out[lid] = _train_catboost_variant(
                tr=tr,
                cal=cal,
                val=val,
                numeric_cols=numeric_cols,
                categorical_cols=categorical,
                use_market_anchor=use_market_anchor,
            )
        except RuntimeError as exc:
            out[lid] = {"error": str(exc)}
    return out


def main():
    print("=== BUILD DATASET FOR CATBOOST OUTCOME RESEARCH ===")
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
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = df_all.merge(build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = add_outcome_scenario_features(df_all)
    df_train = df_all[df_all["has_result"]].copy()
    print(f"TRAIN: {df_train.shape}")

    numeric_base, numeric_market, categorical = _build_cb_feature_sets(df_train)

    market_only = _run_market_only(df_train)
    current_stack = _run_current_stack(df_train)
    catboost_plain = _run_catboost(df_train, use_market_features=False, use_market_anchor=False)
    catboost_market = _run_catboost(df_train, use_market_features=True, use_market_anchor=True)

    report = {
        "feature_counts": {
            "catboost_plain_numeric": len(numeric_base),
            "catboost_market_numeric": len(numeric_market),
            "categorical": len(categorical),
        },
        "market_only": {
            "by_league": market_only,
            "weighted_val_acc": _weighted_metric(market_only, "val_acc"),
            "weighted_val_ll": _weighted_metric(market_only, "val_ll"),
        },
        "current_stack": {
            "by_league": current_stack,
            "weighted_val_acc": _weighted_metric(current_stack, "val_acc"),
            "weighted_val_ll": _weighted_metric(current_stack, "val_ll"),
        },
        "catboost_plain": {
            "by_league": catboost_plain,
            "weighted_val_acc": _weighted_metric(catboost_plain, "val_acc"),
            "weighted_val_ll": _weighted_metric(catboost_plain, "val_ll"),
        },
        "catboost_market": {
            "by_league": catboost_market,
            "weighted_val_acc": _weighted_metric(catboost_market, "val_acc"),
            "weighted_val_ll": _weighted_metric(catboost_market, "val_ll"),
        },
    }

    cur_ll = report["current_stack"]["weighted_val_ll"]
    report["delta_vs_current"] = {
        "market_only_val_ll": None if report["market_only"]["weighted_val_ll"] is None or cur_ll is None else float(report["market_only"]["weighted_val_ll"] - cur_ll),
        "catboost_plain_val_ll": None if report["catboost_plain"]["weighted_val_ll"] is None or cur_ll is None else float(report["catboost_plain"]["weighted_val_ll"] - cur_ll),
        "catboost_market_val_ll": None if report["catboost_market"]["weighted_val_ll"] is None or cur_ll is None else float(report["catboost_market"]["weighted_val_ll"] - cur_ll),
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
