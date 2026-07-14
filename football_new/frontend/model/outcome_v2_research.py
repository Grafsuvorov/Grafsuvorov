import json
from pathlib import Path

import pandas as pd

from data.build_dataset import build_dataset
from data.loader import load_stats
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
from train_outcomes import build_safe_feature_list, _train_outcomes_single


OUT_PATH = Path("tmp/outcome_v2_research.json")
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


def _run_by_league(df: pd.DataFrame, feature_cols: list[str]) -> dict:
    league_metrics = {}
    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        subset = df[df["league_id"] == lid].copy()
        if subset.empty:
            continue
        try:
            res = _train_outcomes_single(subset, league_id=lid, feature_cols_override=feature_cols)
            league_metrics[lid] = res["metrics"]
        except RuntimeError as exc:
            league_metrics[lid] = {"error": str(exc)}
    return league_metrics


def main():
    print("=== BUILD DATASET FOR OUTCOME V2 RESEARCH ===")
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

    baseline = _run_by_league(df_train, baseline_cols)
    v2 = _run_by_league(df_train, v2_cols)

    report = {
        "feature_counts": {"baseline": len(baseline_cols), "v2": len(v2_cols)},
        "baseline": {
            "by_league": baseline,
            "weighted_val_acc": _weighted_metric(baseline, "val_acc"),
            "weighted_val_ll": _weighted_metric(baseline, "val_ll"),
        },
        "v2": {
            "by_league": v2,
            "weighted_val_acc": _weighted_metric(v2, "val_acc"),
            "weighted_val_ll": _weighted_metric(v2, "val_ll"),
        },
    }

    if report["baseline"]["weighted_val_acc"] is not None and report["v2"]["weighted_val_acc"] is not None:
        report["delta"] = {
            "val_acc": float(report["v2"]["weighted_val_acc"] - report["baseline"]["weighted_val_acc"]),
            "val_ll": float(report["v2"]["weighted_val_ll"] - report["baseline"]["weighted_val_ll"]),
        }
    else:
        report["delta"] = None

    OUT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
