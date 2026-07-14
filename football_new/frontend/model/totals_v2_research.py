import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.metrics import accuracy_score, brier_score_loss, log_loss

from data.build_dataset import build_dataset
from data.loader import load_stats
from data.splits import temporal_split_by_league
from config import CAL_DAYS, GAP_DAYS, VAL_DAYS
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
from models.blending import sanitize_prob
from models.poisson import build_poisson_probs_for_arrays, train_poisson_pair
from train_outcomes import build_safe_feature_list
from train_totals import _train_totals_single


OUT_PATH = Path("tmp/totals_v2_research.json")
MATCH_CONTEXT_PREFIXES = (
    "mc_",
    "home_rest_days",
    "home_matches_last8d",
    "home_matches_last14d",
    "home_points_last5",
    "home_goal_diff_last5",
    "home_points_season_avg",
    "home_home_share_last5",
    "away_rest_days",
    "away_matches_last8d",
    "away_matches_last14d",
    "away_points_last5",
    "away_goal_diff_last5",
    "away_points_season_avg",
    "away_home_share_last5",
)


def _weighted_metric(metrics: dict[int, dict], key: str) -> float | None:
    rows = [(int(v["val_n"]), float(v[key])) for v in metrics.values() if key in v and v.get("val_n")]
    if not rows:
        return None
    total_n = sum(n for n, _ in rows)
    if total_n <= 0:
        return None
    return sum(n * val for n, val in rows) / total_n


def _safe_blend_local(p_model: np.ndarray, p_mkt: np.ndarray, alpha: float) -> np.ndarray:
    p_model = sanitize_prob(p_model)
    p_mkt = sanitize_prob(p_mkt)
    out = p_model.copy()
    use = np.isfinite(p_mkt)
    if alpha > 0 and use.any():
        out[use] = (1.0 - alpha) * p_model[use] + alpha * p_mkt[use]
    return sanitize_prob(out)


def _metric_pack(y: np.ndarray, p: np.ndarray) -> dict:
    return {
        "val_acc": float(accuracy_score(y, (p >= 0.5).astype(int))),
        "val_ll": float(log_loss(y, p, labels=[0, 1])),
        "val_brier": float(brier_score_loss(y, p)),
        "val_n": int(len(y)),
    }


def _run_poisson_variant(df_full: pd.DataFrame, feature_cols: list[str], with_market: bool) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[df_full["league_id"] == lid].copy()
        if subset.empty:
            continue
        train = subset[subset["has_result"]].copy().reset_index(drop=True)
        if train.empty:
            continue
        try:
            tr, cal, val = temporal_split_by_league(
                train,
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
            pois = train_poisson_pair(
                tr=tr,
                cal=cal,
                val=val,
                feature_cols=feature_cols,
                ts_col="date_utc",
                now_override=None,
            )
            _, p_cal = build_poisson_probs_for_arrays(pois["lam_cal_home"], pois["lam_cal_away"])
            _, p_val = build_poisson_probs_for_arrays(pois["lam_val_home"], pois["lam_val_away"])
            y_cal = cal["target_over25"].astype(int).values
            y_val = val["target_over25"].astype(int).values

            alpha = 0.0
            if with_market and "p_over_mkt" in cal.columns and "p_over_mkt" in val.columns:
                pm_cal = sanitize_prob(cal["p_over_mkt"].astype(float).values)
                pm_val = sanitize_prob(val["p_over_mkt"].astype(float).values)
                best = (0.0, log_loss(y_cal, p_cal, labels=[0, 1]))
                for a in np.linspace(0.0, 0.6, 7):
                    mix_cal = _safe_blend_local(p_cal, pm_cal, float(a))
                    ll = log_loss(y_cal, mix_cal, labels=[0, 1])
                    if ll < best[1]:
                        best = (float(a), float(ll))
                alpha = best[0]
                p_val = _safe_blend_local(p_val, pm_val, alpha)

            metrics = _metric_pack(y_val, p_val)
            metrics["alpha_market"] = float(alpha)
            out[lid] = metrics
        except RuntimeError:
            continue
    return out


def _run_current_totals(df_full: pd.DataFrame, feature_cols: list[str]) -> dict[int, dict]:
    out = {}
    for lid in sorted({int(x) for x in df_full["league_id"].dropna().unique()}):
        subset = df_full[df_full["league_id"] == lid].copy()
        if subset.empty:
            continue
        try:
            res = _train_totals_single(subset, feature_cols_override=feature_cols)
            out[lid] = res["metrics"]
        except RuntimeError:
            continue
    return out


def main():
    print("=== BUILD DATASET FOR TOTALS V2 RESEARCH ===")
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

    full_cols = build_safe_feature_list(df_train)
    baseline_cols = [c for c in full_cols if not c.startswith(MATCH_CONTEXT_PREFIXES)]
    v2_cols = full_cols

    print(f"BASELINE FEATS: {len(baseline_cols)}")
    print(f"V2 FEATS: {len(v2_cols)}")

    current_baseline = _run_current_totals(df_train, baseline_cols)
    poisson_baseline = _run_poisson_variant(df_train, baseline_cols, with_market=False)
    poisson_market_baseline = _run_poisson_variant(df_train, baseline_cols, with_market=True)
    poisson_market_v2 = _run_poisson_variant(df_train, v2_cols, with_market=True)

    report = {
        "feature_counts": {"baseline": len(baseline_cols), "v2": len(v2_cols)},
        "current_totals": {
            "by_league": current_baseline,
            "weighted_val_acc": _weighted_metric(current_baseline, "val_acc"),
            "weighted_val_ll": _weighted_metric(current_baseline, "val_ll"),
            "weighted_val_brier": _weighted_metric(current_baseline, "val_brier"),
        },
        "poisson_only": {
            "by_league": poisson_baseline,
            "weighted_val_acc": _weighted_metric(poisson_baseline, "val_acc"),
            "weighted_val_ll": _weighted_metric(poisson_baseline, "val_ll"),
            "weighted_val_brier": _weighted_metric(poisson_baseline, "val_brier"),
        },
        "poisson_market": {
            "by_league": poisson_market_baseline,
            "weighted_val_acc": _weighted_metric(poisson_market_baseline, "val_acc"),
            "weighted_val_ll": _weighted_metric(poisson_market_baseline, "val_ll"),
            "weighted_val_brier": _weighted_metric(poisson_market_baseline, "val_brier"),
        },
        "poisson_market_v2": {
            "by_league": poisson_market_v2,
            "weighted_val_acc": _weighted_metric(poisson_market_v2, "val_acc"),
            "weighted_val_ll": _weighted_metric(poisson_market_v2, "val_ll"),
            "weighted_val_brier": _weighted_metric(poisson_market_v2, "val_brier"),
        },
    }

    report["delta_vs_current"] = {
        "poisson_only_val_ll": None if report["poisson_only"]["weighted_val_ll"] is None else float(report["poisson_only"]["weighted_val_ll"] - report["current_totals"]["weighted_val_ll"]),
        "poisson_market_val_ll": None if report["poisson_market"]["weighted_val_ll"] is None else float(report["poisson_market"]["weighted_val_ll"] - report["current_totals"]["weighted_val_ll"]),
        "poisson_market_v2_val_ll": None if report["poisson_market_v2"]["weighted_val_ll"] is None else float(report["poisson_market_v2"]["weighted_val_ll"] - report["current_totals"]["weighted_val_ll"]),
    }

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
