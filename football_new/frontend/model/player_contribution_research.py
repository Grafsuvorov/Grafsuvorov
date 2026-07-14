import json
from copy import deepcopy

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


PLAYER_PREFIXES = ("home_pl_", "away_pl_", "pl_")


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


def _build_feature_frame() -> pd.DataFrame:
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
    return df_all[df_all["has_result"]].copy()


def _drop_player_cols(df: pd.DataFrame) -> pd.DataFrame:
    drop_cols = [
        c for c in df.columns
        if c.startswith(PLAYER_PREFIXES)
    ]
    return df.drop(columns=drop_cols, errors="ignore").copy()


def _train_by_league(df_all: pd.DataFrame):
    outcome_metrics = {}
    totals_metrics = {}

    league_ids = sorted({int(x) for x in df_all["league_id"].dropna().unique()})
    for lid in league_ids:
        subset = df_all[df_all["league_id"] == lid].copy()
        if subset.empty:
            continue
        outcome_metrics[lid] = _train_outcomes_single(subset, league_id=lid)["metrics"]
        totals_metrics[lid] = _train_totals_single(subset)["metrics"]

    return outcome_metrics, totals_metrics


def _summarize(metrics_by_league):
    return {
        "weighted_val_ll": _weighted_metric(metrics_by_league, "val_ll"),
        "weighted_val_acc": _weighted_metric(metrics_by_league, "val_acc"),
        "weighted_val_brier": _weighted_metric(metrics_by_league, "val_brier"),
        "val_n_total": int(sum(int(m.get("val_n", 0)) for m in metrics_by_league.values())),
        "by_league": deepcopy(metrics_by_league),
    }


def main():
    full_df = _build_feature_frame()
    baseline_df = _drop_player_cols(full_df)

    base_out, base_tot = _train_by_league(baseline_df)
    pl_out, pl_tot = _train_by_league(full_df)

    player_cols = sorted(c for c in full_df.columns if c.startswith(PLAYER_PREFIXES))

    report = {
        "window": {
            "season_from": int(UNDERSTAT_MIN_SEASON),
            "rows": int(len(full_df)),
            "player_feature_count": int(len(player_cols)),
        },
        "baseline": {
            "outcomes": _summarize(base_out),
            "totals": _summarize(base_tot),
        },
        "with_player_contribution": {
            "outcomes": _summarize(pl_out),
            "totals": _summarize(pl_tot),
        },
        "player_feature_columns": player_cols,
    }

    report["delta"] = {
        "outcomes_val_ll": (
            report["with_player_contribution"]["outcomes"]["weighted_val_ll"]
            - report["baseline"]["outcomes"]["weighted_val_ll"]
        ),
        "outcomes_val_acc": (
            report["with_player_contribution"]["outcomes"]["weighted_val_acc"]
            - report["baseline"]["outcomes"]["weighted_val_acc"]
        ),
        "totals_val_ll": (
            report["with_player_contribution"]["totals"]["weighted_val_ll"]
            - report["baseline"]["totals"]["weighted_val_ll"]
        ),
        "totals_val_acc": (
            report["with_player_contribution"]["totals"]["weighted_val_acc"]
            - report["baseline"]["totals"]["weighted_val_acc"]
        ),
        "totals_val_brier": (
            report["with_player_contribution"]["totals"]["weighted_val_brier"]
            - report["baseline"]["totals"]["weighted_val_brier"]
        ),
    }

    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
