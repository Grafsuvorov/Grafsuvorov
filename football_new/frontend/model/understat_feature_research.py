import json

import pandas as pd

from config import UNDERSTAT_MIN_SEASON
from data.build_dataset import build_dataset
from data.loader import load_stats
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.team_stats_form import build_team_stats_form
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from train_outcomes import _train_outcomes_single
from train_totals import _train_totals_single


ALL_UNDERSTAT_PREFIXES = ("home_us_", "away_us_", "us_")


def _weighted_metric(metrics_by_league, metric_name):
    num = 0.0
    den = 0
    for metrics in metrics_by_league.values():
        n = int(metrics.get("val_n", 0))
        val = metrics.get(metric_name)
        if n <= 0 or val is None:
            continue
        num += float(val) * n
        den += n
    return (num / den) if den else None


def _add_derived(df_all: pd.DataFrame) -> pd.DataFrame:
    df = df_all.copy()
    pairs = {
        "us_attack_edge_5": ("home_us_xg_all_5", "away_us_xga_all_5"),
        "us_attack_edge_10": ("home_us_xg_all_10", "away_us_xga_all_10"),
        "us_def_edge_5": ("away_us_xg_all_5", "home_us_xga_all_5"),
        "us_def_edge_10": ("away_us_xg_all_10", "home_us_xga_all_10"),
        "us_npxg_edge_5": ("home_us_npxg_all_5", "away_us_npxga_all_5"),
        "us_npxg_edge_10": ("home_us_npxg_all_10", "away_us_npxga_all_10"),
        "us_home_control_5": ("home_us_deep_all_5", "away_us_deep_allowed_all_5"),
        "us_away_control_5": ("away_us_deep_all_5", "home_us_deep_allowed_all_5"),
        "us_home_press_5": ("away_us_ppda_allowed_all_5", "home_us_ppda_all_5"),
        "us_away_press_5": ("home_us_ppda_allowed_all_5", "away_us_ppda_all_5"),
        "us_home_finishing_regress_5": ("home_us_goal_minus_xg_all_5", "away_us_goal_against_minus_xga_all_5"),
        "us_away_finishing_regress_5": ("away_us_goal_minus_xg_all_5", "home_us_goal_against_minus_xga_all_5"),
        "us_home_npxg_regress_5": ("home_us_goal_minus_npxg_all_5", "away_us_goal_against_minus_npxga_all_5"),
        "us_away_npxg_regress_5": ("away_us_goal_minus_npxg_all_5", "home_us_goal_against_minus_npxga_all_5"),
        "us_home_finishing_regress_3": ("home_us_goal_minus_xg_all_3", "away_us_goal_against_minus_xga_all_3"),
        "us_away_finishing_regress_3": ("away_us_goal_minus_xg_all_3", "home_us_goal_against_minus_xga_all_3"),
        "us_home_npxg_regress_3": ("home_us_goal_minus_npxg_all_3", "away_us_goal_against_minus_npxga_all_3"),
        "us_away_npxg_regress_3": ("away_us_goal_minus_npxg_all_3", "home_us_goal_against_minus_npxga_all_3"),
    }
    for out_col, (left, right) in pairs.items():
        if left in df.columns and right in df.columns:
            df[out_col] = pd.to_numeric(df[left], errors="coerce") - pd.to_numeric(df[right], errors="coerce")
    return df


def _build_base_df() -> pd.DataFrame:
    df_all = build_dataset(return_all=True)
    df_all = df_all[df_all["season"].astype(int) >= int(UNDERSTAT_MIN_SEASON)].copy()

    match_stats = load_stats()
    if not match_stats.empty:
        match_stats = match_stats[match_stats["fixture_id"].isin(df_all["fixture_id"])].copy()

    feats_list = [
        build_elo_features(df_all, mode="train"),
        build_form_xg_features(df_all, match_stats, window=5),
        build_team_stats_form(df_all, match_stats, window=5),
        build_h2h_features(df_all, mode="train"),
        build_h2h_recent_features(df_all, window=5),
        build_league_context_features(df_all, window=60),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_all = _add_derived(df_all)
    return df_all[df_all["has_result"]].copy()


def _select_variant(df: pd.DataFrame, keep_cols) -> pd.DataFrame:
    keep_cols = set(keep_cols)
    understat_cols = [
        c for c in df.columns
        if c.startswith(ALL_UNDERSTAT_PREFIXES)
    ]
    drop_cols = [c for c in understat_cols if c not in keep_cols]
    return df.drop(columns=drop_cols, errors="ignore").copy()


def _train_variant(df: pd.DataFrame):
    out = {}
    tot = {}
    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        subset = df[df["league_id"] == lid].copy()
        out[lid] = _train_outcomes_single(subset, league_id=lid)["metrics"]
        tot[lid] = _train_totals_single(subset)["metrics"]
    return {
        "outcomes": {
            "weighted_val_ll": _weighted_metric(out, "val_ll"),
            "weighted_val_acc": _weighted_metric(out, "val_acc"),
            "by_league": out,
        },
        "totals": {
            "weighted_val_ll": _weighted_metric(tot, "val_ll"),
            "weighted_val_acc": _weighted_metric(tot, "val_acc"),
            "weighted_val_brier": _weighted_metric(tot, "val_brier"),
            "by_league": tot,
        },
    }


def main():
    df = _build_base_df()

    variants = {
        "baseline": [],
        "xg_core": [
            "home_us_xg_all_5", "away_us_xg_all_5", "home_us_xga_all_5", "away_us_xga_all_5",
            "home_us_xg_all_10", "away_us_xg_all_10", "home_us_xga_all_10", "away_us_xga_all_10",
        ],
        "npxg_core": [
            "home_us_npxg_all_5", "away_us_npxg_all_5", "home_us_npxga_all_5", "away_us_npxga_all_5",
            "home_us_npxg_all_10", "away_us_npxg_all_10", "home_us_npxga_all_10", "away_us_npxga_all_10",
        ],
        "tempo_control": [
            "home_us_deep_all_5", "away_us_deep_all_5",
            "home_us_deep_allowed_all_5", "away_us_deep_allowed_all_5",
            "home_us_ppda_all_5", "away_us_ppda_all_5",
            "home_us_ppda_allowed_all_5", "away_us_ppda_allowed_all_5",
        ],
        "results_proxy": [
            "home_us_pts_all_5", "away_us_pts_all_5",
            "home_us_scored_all_5", "away_us_scored_all_5",
            "home_us_missed_all_5", "away_us_missed_all_5",
            "home_us_pts_all_10", "away_us_pts_all_10",
        ],
        "overperform_regression": [
            "home_us_goal_minus_xg_all_5", "away_us_goal_minus_xg_all_5",
            "home_us_goal_against_minus_xga_all_5", "away_us_goal_against_minus_xga_all_5",
            "home_us_goal_minus_npxg_all_5", "away_us_goal_minus_npxg_all_5",
            "home_us_goal_against_minus_npxga_all_5", "away_us_goal_against_minus_npxga_all_5",
            "home_us_goal_minus_xg_all_10", "away_us_goal_minus_xg_all_10",
            "home_us_goal_against_minus_xga_all_10", "away_us_goal_against_minus_xga_all_10",
            "home_us_goal_minus_npxg_all_10", "away_us_goal_minus_npxg_all_10",
            "home_us_goal_against_minus_npxga_all_10", "away_us_goal_against_minus_npxga_all_10",
        ],
        "regression_v2": [
            "home_us_goal_minus_xg_all_3", "away_us_goal_minus_xg_all_3",
            "home_us_goal_against_minus_xga_all_3", "away_us_goal_against_minus_xga_all_3",
            "home_us_goal_minus_npxg_all_3", "away_us_goal_minus_npxg_all_3",
            "home_us_goal_against_minus_npxga_all_3", "away_us_goal_against_minus_npxga_all_3",
            "home_us_goal_minus_xg_home_5", "away_us_goal_minus_xg_away_5",
            "home_us_goal_against_minus_xga_home_5", "away_us_goal_against_minus_xga_away_5",
            "home_us_goal_minus_npxg_home_5", "away_us_goal_minus_npxg_away_5",
            "home_us_goal_against_minus_npxga_home_5", "away_us_goal_against_minus_npxga_away_5",
            "home_us_goal_minus_xg_std_all_5", "away_us_goal_minus_xg_std_all_5",
            "home_us_goal_against_minus_xga_std_all_5", "away_us_goal_against_minus_xga_std_all_5",
            "home_us_goal_minus_npxg_std_all_5", "away_us_goal_minus_npxg_std_all_5",
            "home_us_goal_against_minus_npxga_std_all_5", "away_us_goal_against_minus_npxga_std_all_5",
        ],
        "derived_edges": [
            "us_attack_edge_5", "us_attack_edge_10",
            "us_def_edge_5", "us_def_edge_10",
            "us_npxg_edge_5", "us_npxg_edge_10",
            "us_home_control_5", "us_away_control_5",
            "us_home_press_5", "us_away_press_5",
            "us_home_finishing_regress_5", "us_away_finishing_regress_5",
            "us_home_npxg_regress_5", "us_away_npxg_regress_5",
            "us_home_finishing_regress_3", "us_away_finishing_regress_3",
            "us_home_npxg_regress_3", "us_away_npxg_regress_3",
        ],
        "compact_mix": [
            "home_us_xg_all_5", "away_us_xg_all_5", "home_us_xga_all_5", "away_us_xga_all_5",
            "home_us_npxg_all_5", "away_us_npxg_all_5", "home_us_npxga_all_5", "away_us_npxga_all_5",
            "home_us_deep_all_5", "away_us_deep_all_5",
            "home_us_ppda_all_5", "away_us_ppda_all_5",
            "us_attack_edge_5", "us_def_edge_5", "us_npxg_edge_5",
            "home_us_goal_minus_xg_all_5", "away_us_goal_minus_xg_all_5",
            "home_us_goal_against_minus_xga_all_5", "away_us_goal_against_minus_xga_all_5",
        ],
    }

    report = {"window": {"season_from": int(UNDERSTAT_MIN_SEASON), "rows": int(len(df))}, "variants": {}}
    baseline_summary = None

    for name, keep_cols in variants.items():
        df_variant = _select_variant(df, keep_cols)
        summary = _train_variant(df_variant)
        report["variants"][name] = summary
        if name == "baseline":
            baseline_summary = summary

    for name, summary in report["variants"].items():
        if name == "baseline":
            continue
        summary["delta_vs_baseline"] = {
            "outcomes_val_ll": summary["outcomes"]["weighted_val_ll"] - baseline_summary["outcomes"]["weighted_val_ll"],
            "outcomes_val_acc": summary["outcomes"]["weighted_val_acc"] - baseline_summary["outcomes"]["weighted_val_acc"],
            "totals_val_ll": summary["totals"]["weighted_val_ll"] - baseline_summary["totals"]["weighted_val_ll"],
            "totals_val_acc": summary["totals"]["weighted_val_acc"] - baseline_summary["totals"]["weighted_val_acc"],
            "totals_val_brier": summary["totals"]["weighted_val_brier"] - baseline_summary["totals"]["weighted_val_brier"],
        }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
