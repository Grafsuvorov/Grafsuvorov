import json

from config import UNDERSTAT_MIN_SEASON
from data.build_dataset import build_dataset
from data.loader import load_stats
from features.build_matrix import build_feature_matrix
from features.confirmed_lineup_delta import build_confirmed_lineup_delta_features
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.team_stats_form import build_team_stats_form
from train_outcomes import _train_outcomes_single, build_safe_feature_list
from sqlalchemy import create_engine
from config import DB_URL


CL_PREFIXES = ("home_cl_", "away_cl_", "cl_")


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


def _run_by_league(df, feature_cols):
    outcome_metrics = {}
    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        subset = df[df["league_id"] == lid].copy()
        if subset.empty:
            continue
        outcome_metrics[lid] = _train_outcomes_single(subset, league_id=lid, feature_cols_override=feature_cols)["metrics"]
    return outcome_metrics


def main():
    engine = create_engine(DB_URL)

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
        build_confirmed_lineup_delta_features(df_all, engine, min_season=UNDERSTAT_MIN_SEASON),
    ]
    df_all = build_feature_matrix(schedule=df_all, feats_list=feats_list, target_df=None)
    df_all = add_draw_diff_features(df_all)
    df_train = df_all[df_all["has_result"]].copy()

    full_cols = build_safe_feature_list(df_train)
    baseline_cols = [c for c in full_cols if not c.startswith(CL_PREFIXES)]
    with_cl_cols = full_cols

    baseline = _run_by_league(df_train, baseline_cols)
    with_cl = _run_by_league(df_train, with_cl_cols)

    cl_cols = sorted(c for c in df_train.columns if c.startswith(CL_PREFIXES))
    report = {
        "window": {
            "season_from": int(UNDERSTAT_MIN_SEASON),
            "rows": int(len(df_train)),
            "confirmed_lineup_feature_count": int(len(cl_cols)),
        },
        "baseline": {
            "weighted_val_acc": _weighted_metric(baseline, "val_acc"),
            "weighted_val_ll": _weighted_metric(baseline, "val_ll"),
            "by_league": baseline,
        },
        "with_confirmed_lineup_delta": {
            "weighted_val_acc": _weighted_metric(with_cl, "val_acc"),
            "weighted_val_ll": _weighted_metric(with_cl, "val_ll"),
            "by_league": with_cl,
        },
        "delta": {
            "val_acc": _weighted_metric(with_cl, "val_acc") - _weighted_metric(baseline, "val_acc"),
            "val_ll": _weighted_metric(with_cl, "val_ll") - _weighted_metric(baseline, "val_ll"),
        },
        "confirmed_lineup_feature_columns": cl_cols,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
