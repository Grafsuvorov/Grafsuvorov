import json
from typing import Dict, List

import numpy as np
import pandas as pd

from config import TOTALS_UNDERSTAT_SELECTED_FEATURES, UNDERSTAT_MIN_SEASON
from data.build_dataset import build_dataset
from data.loader import load_stats
from decision.outcomes_decision import decide_outcome_bet
from decision.totals_decision import decide_total_bet
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.team_stats_form import build_team_stats_form
from models.inference import predict_outcomes, predict_totals
from train_outcomes import _train_outcomes_single, build_safe_feature_list
from train_totals import _train_totals_single, select_totals_feature_cols


ALL_UNDERSTAT_PREFIXES = ("home_us_", "away_us_", "us_", "usys_")


def _safe_num(series: pd.Series) -> pd.Series:
    return pd.to_numeric(series, errors="coerce")


def _safe_div(num: pd.Series, den: pd.Series) -> pd.Series:
    num = _safe_num(num)
    den = _safe_num(den).replace(0, np.nan)
    return num / den


def _weighted_metric(metrics_by_league: Dict[int, Dict[str, float]], metric_name: str):
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


def _compute_p_market(df: pd.DataFrame) -> pd.Series:
    over = pd.to_numeric(df["avg_odds_over25"], errors="coerce")
    under = pd.to_numeric(df["avg_odds_under25"], errors="coerce")
    imp_over = 1.0 / over.replace(0, np.nan)
    imp_under = 1.0 / under.replace(0, np.nan)
    overround = imp_over + imp_under
    return imp_over / overround


def _bet_profit_total(row: pd.Series) -> float:
    goals = float(row["home_goals"]) + float(row["away_goals"])
    if row["bet_side"] == "OVER":
        return float(row["avg_odds_over25"]) - 1.0 if goals > 2.5 else -1.0
    return float(row["avg_odds_under25"]) - 1.0 if goals <= 2.5 else -1.0


def _bet_profit_outcome(row: pd.Series) -> float:
    if row["bet_side"] == "Home":
        won = row["home_goals"] > row["away_goals"]
    elif row["bet_side"] == "Draw":
        won = row["home_goals"] == row["away_goals"]
    else:
        won = row["home_goals"] < row["away_goals"]
    return float(row["odds_side"]) - 1.0 if won else -1.0


def _roi_summary(df: pd.DataFrame) -> Dict[str, float]:
    bets = df[df["bet_decision"].isin(["A", "B"])].copy()
    stake = float(bets["stake"].sum())
    profit = float(bets["profit"].sum())
    return {
        "matches": int(len(df)),
        "bets": int(len(bets)),
        "coverage": float(len(bets) / len(df)) if len(df) else 0.0,
        "stake": stake,
        "profit": profit,
        "roi": (profit / stake) if stake > 0 else None,
    }


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
    df_all = _add_understat_system_features(df_all)
    return df_all[df_all["has_result"]].copy()


def _add_pair_diff(df: pd.DataFrame, out_col: str, left: str, right: str):
    if left in df.columns and right in df.columns:
        df[out_col] = _safe_num(df[left]) - _safe_num(df[right])


def _add_understat_system_features(df_all: pd.DataFrame) -> pd.DataFrame:
    df = df_all.copy()

    # Matchup: атака одной команды против защиты другой.
    matchup_specs = {
        "usys_home_npxg_matchup_3": ("home_us_npxg_all_3", "away_us_npxga_all_3"),
        "usys_away_npxg_matchup_3": ("away_us_npxg_all_3", "home_us_npxga_all_3"),
        "usys_home_npxg_matchup_5": ("home_us_npxg_all_5", "away_us_npxga_all_5"),
        "usys_away_npxg_matchup_5": ("away_us_npxg_all_5", "home_us_npxga_all_5"),
        "usys_home_npxg_matchup_10": ("home_us_npxg_all_10", "away_us_npxga_all_10"),
        "usys_away_npxg_matchup_10": ("away_us_npxg_all_10", "home_us_npxga_all_10"),
        "usys_home_xg_matchup_5": ("home_us_xg_all_5", "away_us_xga_all_5"),
        "usys_away_xg_matchup_5": ("away_us_xg_all_5", "home_us_xga_all_5"),
        "usys_home_control_matchup_5": ("home_us_deep_all_5", "away_us_deep_allowed_all_5"),
        "usys_away_control_matchup_5": ("away_us_deep_all_5", "home_us_deep_allowed_all_5"),
        "usys_home_press_matchup_5": ("away_us_ppda_allowed_all_5", "home_us_ppda_all_5"),
        "usys_away_press_matchup_5": ("home_us_ppda_allowed_all_5", "away_us_ppda_all_5"),
        "usys_home_control_matchup_10": ("home_us_deep_all_10", "away_us_deep_allowed_all_10"),
        "usys_away_control_matchup_10": ("away_us_deep_all_10", "home_us_deep_allowed_all_10"),
    }
    for out_col, (left, right) in matchup_specs.items():
        _add_pair_diff(df, out_col, left, right)

    # Trend: short vs long form.
    trend_specs = {
        "usys_home_npxg_trend_3v10": ("home_us_npxg_all_3", "home_us_npxg_all_10"),
        "usys_away_npxg_trend_3v10": ("away_us_npxg_all_3", "away_us_npxg_all_10"),
        "usys_home_npxga_trend_3v10": ("home_us_npxga_all_3", "home_us_npxga_all_10"),
        "usys_away_npxga_trend_3v10": ("away_us_npxga_all_3", "away_us_npxga_all_10"),
        "usys_home_xg_trend_3v10": ("home_us_xg_all_3", "home_us_xg_all_10"),
        "usys_away_xg_trend_3v10": ("away_us_xg_all_3", "away_us_xg_all_10"),
        "usys_home_xga_trend_3v10": ("home_us_xga_all_3", "home_us_xga_all_10"),
        "usys_away_xga_trend_3v10": ("away_us_xga_all_3", "away_us_xga_all_10"),
        "usys_home_deep_trend_3v10": ("home_us_deep_all_3", "home_us_deep_all_10"),
        "usys_away_deep_trend_3v10": ("away_us_deep_all_3", "away_us_deep_all_10"),
        "usys_home_ppda_trend_3v10": ("home_us_ppda_all_3", "home_us_ppda_all_10"),
        "usys_away_ppda_trend_3v10": ("away_us_ppda_all_3", "away_us_ppda_all_10"),
        "usys_home_finish_trend_3v10": ("home_us_goal_minus_npxg_all_3", "home_us_goal_minus_npxg_all_10"),
        "usys_away_finish_trend_3v10": ("away_us_goal_minus_npxg_all_3", "away_us_goal_minus_npxg_all_10"),
        "usys_home_def_finish_trend_3v10": ("home_us_goal_against_minus_npxga_all_3", "home_us_goal_against_minus_npxga_all_10"),
        "usys_away_def_finish_trend_3v10": ("away_us_goal_against_minus_npxga_all_3", "away_us_goal_against_minus_npxga_all_10"),
    }
    for out_col, (left, right) in trend_specs.items():
        _add_pair_diff(df, out_col, left, right)

    # Venue strength: домашняя/гостевая устойчивость.
    venue_specs = {
        "usys_home_venue_strength_5": ("home_us_npxg_home_5", "home_us_npxga_home_5"),
        "usys_away_venue_strength_5": ("away_us_npxg_away_5", "away_us_npxga_away_5"),
        "usys_home_venue_strength_10": ("home_us_npxg_home_10", "home_us_npxga_home_10"),
        "usys_away_venue_strength_10": ("away_us_npxg_away_10", "away_us_npxga_away_10"),
        "usys_home_finish_edge_5": ("home_us_goal_minus_npxg_home_5", "away_us_goal_against_minus_npxga_away_5"),
        "usys_away_finish_edge_5": ("away_us_goal_minus_npxg_away_5", "home_us_goal_against_minus_npxga_home_5"),
    }
    for out_col, (left, right) in venue_specs.items():
        _add_pair_diff(df, out_col, left, right)

    _add_pair_diff(df, "usys_matchup_venue_edge_5", "usys_home_venue_strength_5", "usys_away_venue_strength_5")
    _add_pair_diff(df, "usys_matchup_venue_edge_10", "usys_home_venue_strength_10", "usys_away_venue_strength_10")

    # Style efficiency: как команда превращает доступ в штрафную в xG.
    if all(c in df.columns for c in ["home_us_npxg_all_5", "home_us_deep_all_5"]):
        df["usys_home_npxg_per_deep_5"] = _safe_div(df["home_us_npxg_all_5"], df["home_us_deep_all_5"])
        df["usys_away_npxg_per_deep_5"] = _safe_div(df["away_us_npxg_all_5"], df["away_us_deep_all_5"])
        df["usys_home_xga_per_deep_allowed_5"] = _safe_div(df["home_us_xga_all_5"], df["home_us_deep_allowed_all_5"])
        df["usys_away_xga_per_deep_allowed_5"] = _safe_div(df["away_us_xga_all_5"], df["away_us_deep_allowed_all_5"])
        _add_pair_diff(df, "usys_home_efficiency_matchup_5", "usys_home_npxg_per_deep_5", "usys_away_xga_per_deep_allowed_5")
        _add_pair_diff(df, "usys_away_efficiency_matchup_5", "usys_away_npxg_per_deep_5", "usys_home_xga_per_deep_allowed_5")

    # Regression / volatility: hot finishing and defensive noise.
    if "home_us_goal_minus_npxg_std_all_5" in df.columns:
        _add_pair_diff(df, "usys_home_regression_noise_5", "home_us_goal_minus_npxg_std_all_5", "away_us_goal_against_minus_npxga_std_all_5")
        _add_pair_diff(df, "usys_away_regression_noise_5", "away_us_goal_minus_npxg_std_all_5", "home_us_goal_against_minus_npxga_std_all_5")
        _add_pair_diff(df, "usys_home_regression_edge_5", "home_us_goal_minus_npxg_all_5", "away_us_goal_against_minus_npxga_all_5")
        _add_pair_diff(df, "usys_away_regression_edge_5", "away_us_goal_minus_npxg_all_5", "home_us_goal_against_minus_npxga_all_5")

    return df


def _base_totals_understat_cols() -> List[str]:
    base = set(TOTALS_UNDERSTAT_SELECTED_FEATURES)
    base.update(
        [
            "home_us_xg_all_5",
            "away_us_xg_all_5",
            "home_us_xga_all_5",
            "away_us_xga_all_5",
            "home_us_npxg_all_3",
            "away_us_npxg_all_3",
            "home_us_npxga_all_3",
            "away_us_npxga_all_3",
            "home_us_goal_minus_npxg_all_3",
            "away_us_goal_minus_npxg_all_3",
            "home_us_goal_against_minus_npxga_all_3",
            "away_us_goal_against_minus_npxga_all_3",
        ]
    )
    return sorted(base)


def _variant_map(df: pd.DataFrame) -> Dict[str, List[str]]:
    usys_cols = [c for c in df.columns if c.startswith("usys_")]
    core_totals = _base_totals_understat_cols()
    style_cols = [c for c in usys_cols if "control" in c or "press" in c or "efficiency" in c]
    trend_cols = [c for c in usys_cols if "trend" in c]
    matchup_cols = [c for c in usys_cols if "matchup" in c or "venue_edge" in c]
    regression_cols = [c for c in usys_cols if "regression" in c or "finish_edge" in c]
    venue_cols = [c for c in usys_cols if "venue_strength" in c]

    return {
        "baseline": [],
        "core_selected": core_totals,
        "style_trend": sorted(set(core_totals + style_cols + trend_cols)),
        "matchup_trend": sorted(set(core_totals + matchup_cols + trend_cols + venue_cols)),
        "system_full": sorted(set(core_totals + usys_cols)),
        "regression_matchup": sorted(set(core_totals + matchup_cols + regression_cols + venue_cols)),
    }


def _filter_variant(df: pd.DataFrame, keep_cols: List[str]) -> pd.DataFrame:
    understat_cols = [c for c in df.columns if c.startswith(ALL_UNDERSTAT_PREFIXES)]
    drop_cols = [c for c in understat_cols if c not in set(keep_cols)]
    return df.drop(columns=drop_cols, errors="ignore").copy()


def _baseline_feature_cols(df: pd.DataFrame) -> List[str]:
    return [c for c in build_safe_feature_list(df) if not c.startswith(ALL_UNDERSTAT_PREFIXES)]


def _evaluate_totals_predictions(df: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    out["p_over25"] = pd.to_numeric(pd.Series(probs), errors="coerce")
    out["p_market"] = _compute_p_market(out)
    out["edge"] = out["p_over25"] - out["p_market"]
    out["bet_side"] = np.where(out["p_over25"] >= 0.5, "OVER", "UNDER")
    out["odds_side"] = np.where(out["bet_side"] == "OVER", out["avg_odds_over25"], out["avg_odds_under25"])
    out["bet_decision"] = [
        decide_total_bet(edge, odds, int(lid), p)
        for edge, odds, lid, p in zip(out["edge"], out["odds_side"], out["league_id"], out["p_over25"])
    ]
    out["stake"] = np.where(out["bet_decision"] == "A", 1.0, np.where(out["bet_decision"] == "B", 0.4, 0.0))
    bets = out["bet_decision"].isin(["A", "B"])
    out["profit_raw"] = 0.0
    out.loc[bets, "profit_raw"] = out.loc[bets].apply(_bet_profit_total, axis=1)
    out["profit"] = out["profit_raw"] * out["stake"]
    return out


def _evaluate_outcome_predictions(df: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    out["p_away"] = probs[:, 0]
    out["p_draw"] = probs[:, 1]
    out["p_home"] = probs[:, 2]

    if "home_team" not in out.columns:
        out["home_team"] = out["home_team_id"].astype(str)
    if "away_team" not in out.columns:
        out["away_team"] = out["away_team_id"].astype(str)

    options = []
    for side, p_col, odds_col in [
        ("Home", "p_home", "avg_odds_home"),
        ("Draw", "p_draw", "avg_odds_draw"),
        ("Away", "p_away", "avg_odds_away"),
    ]:
        tmp = out[
            [
                "fixture_id",
                "date_utc",
                "league_id",
                "season",
                "home_team",
                "away_team",
                "home_goals",
                "away_goals",
                p_col,
                odds_col,
            ]
        ].copy()
        tmp.columns = [
            "fixture_id",
            "date_utc",
            "league_id",
            "season",
            "home_team",
            "away_team",
            "home_goals",
            "away_goals",
            "p_side",
            "odds_side",
        ]
        tmp["bet_side"] = side
        tmp["ev"] = tmp["p_side"] * tmp["odds_side"] - 1.0
        options.append(tmp)

    opts = pd.concat(options, ignore_index=True).dropna(subset=["p_side", "odds_side", "ev"])
    best_idx = opts.groupby("fixture_id")["ev"].idxmax()
    picks = opts.loc[best_idx].copy().reset_index(drop=True)
    picks["bet_decision"] = [
        decide_outcome_bet(ev, odds, int(lid), side)
        for ev, odds, lid, side in zip(picks["ev"], picks["odds_side"], picks["league_id"], picks["bet_side"])
    ]
    picks["stake"] = np.where(picks["bet_decision"] == "A", 1.0, np.where(picks["bet_decision"] == "B", 0.4, 0.0))
    bets = picks["bet_decision"].isin(["A", "B"])
    picks["profit_raw"] = 0.0
    picks.loc[bets, "profit_raw"] = picks.loc[bets].apply(_bet_profit_outcome, axis=1)
    picks["profit"] = picks["profit_raw"] * picks["stake"]
    return picks


def _by_league_summary(df: pd.DataFrame) -> Dict[str, Dict[str, float]]:
    out = {}
    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        out[str(lid)] = _roi_summary(df[df["league_id"] == lid].copy())
    return out


def _serialize_examples(df: pd.DataFrame, cols: List[str], n: int = 5) -> List[Dict[str, object]]:
    rows = []
    for rec in df.head(n)[cols].to_dict(orient="records"):
        row = dict(rec)
        if row.get("date_utc") is not None and hasattr(row["date_utc"], "isoformat"):
            row["date_utc"] = row["date_utc"].isoformat()
        for key, val in list(row.items()):
            if isinstance(val, (np.floating, float)):
                row[key] = float(val)
            elif isinstance(val, (np.integer, int)):
                row[key] = int(val)
        rows.append(row)
    return rows


def _run_totals_variant(train_df: pd.DataFrame, test_df: pd.DataFrame, name: str, keep_cols: List[str]) -> Dict[str, object]:
    df_variant = _filter_variant(pd.concat([train_df, test_df], ignore_index=True), keep_cols)
    train_part = df_variant[df_variant["season"].astype(int) < int(test_df["season"].max())].copy()
    test_part = df_variant[df_variant["season"].astype(int) == int(test_df["season"].max())].copy()
    bundles = {}
    metrics_by_league = {}
    for lid in sorted({int(x) for x in train_part["league_id"].dropna().unique()}):
        local_train = train_part[train_part["league_id"] == lid].copy()
        if local_train.empty:
            continue
        feature_cols = _baseline_feature_cols(local_train) if name == "baseline" else select_totals_feature_cols(local_train)
        feature_cols = [c for c in feature_cols if c in local_train.columns]
        res = _train_totals_single(local_train, feature_cols_override=feature_cols, return_details=False)
        bundles[lid] = res["bundle"]
        metrics_by_league[lid] = res["metrics"]
    probs = predict_totals(test_part, bundles)
    eval_df = _evaluate_totals_predictions(test_part, probs)
    return {
        "metrics": {
            "val_ll": _weighted_metric(metrics_by_league, "val_ll"),
            "val_acc": _weighted_metric(metrics_by_league, "val_acc"),
            "val_brier": _weighted_metric(metrics_by_league, "val_brier"),
            "val_n": int(sum(int(v.get("val_n", 0)) for v in metrics_by_league.values())),
            "by_league": metrics_by_league,
        },
        "eval_df": eval_df,
        "roi": _roi_summary(eval_df),
        "by_league": _by_league_summary(eval_df),
    }


def _run_outcomes_variant(train_df: pd.DataFrame, test_df: pd.DataFrame, keep_cols: List[str]) -> Dict[str, object]:
    df_variant = _filter_variant(pd.concat([train_df, test_df], ignore_index=True), keep_cols)
    train_part = df_variant[df_variant["season"].astype(int) < int(test_df["season"].max())].copy()
    test_part = df_variant[df_variant["season"].astype(int) == int(test_df["season"].max())].copy()
    bundles = {}
    metrics_by_league = {}
    for lid in sorted({int(x) for x in train_part["league_id"].dropna().unique()}):
        local_train = train_part[train_part["league_id"] == lid].copy()
        if local_train.empty:
            continue
        res = _train_outcomes_single(local_train, league_id=lid)
        bundles[lid] = res["bundle"]
        metrics_by_league[lid] = res["metrics"]
    probs = predict_outcomes(test_part, bundles)
    eval_df = _evaluate_outcome_predictions(test_part, probs)
    return {
        "metrics": {
            "val_ll": _weighted_metric(metrics_by_league, "val_ll"),
            "val_acc": _weighted_metric(metrics_by_league, "val_acc"),
            "val_n": int(sum(int(v.get("val_n", 0)) for v in metrics_by_league.values())),
            "by_league": metrics_by_league,
        },
        "eval_df": eval_df,
        "roi": _roi_summary(eval_df),
        "by_league": _by_league_summary(eval_df),
    }


def _pick_best_variant(results: Dict[str, Dict[str, object]], prefer_metric: str = "roi") -> str:
    best_name = None
    best_score = None
    for name, payload in results.items():
        roi = payload["roi"]["roi"]
        ll = payload["metrics"]["val_ll"]
        coverage = payload["roi"]["coverage"]
        score = (
            -999.0 if roi is None else float(roi),
            -float(ll) if ll is not None else -999.0,
            float(coverage),
        )
        if best_score is None or score > best_score:
            best_name = name
            best_score = score
    return best_name


def _compare_examples(before_df: pd.DataFrame, after_df: pd.DataFrame, market: str) -> Dict[str, List[Dict[str, object]]]:
    before_df = before_df.copy()
    after_df = after_df.copy()
    if "home_team" not in before_df.columns and "home_team_id" in before_df.columns:
        before_df["home_team"] = before_df["home_team_id"].astype(str)
    if "away_team" not in before_df.columns and "away_team_id" in before_df.columns:
        before_df["away_team"] = before_df["away_team_id"].astype(str)
    if "home_team" not in after_df.columns and "home_team_id" in after_df.columns:
        after_df["home_team"] = after_df["home_team_id"].astype(str)
    if "away_team" not in after_df.columns and "away_team_id" in after_df.columns:
        after_df["away_team"] = after_df["away_team_id"].astype(str)

    before_cols = ["fixture_id", "date_utc", "home_team", "away_team", "home_goals", "away_goals", "bet_side", "bet_decision", "profit"]
    after_cols = ["fixture_id", "bet_side", "bet_decision", "profit"]
    merged = before_df[before_cols].rename(
        columns={"bet_side": "bet_side_before", "bet_decision": "bet_decision_before", "profit": "profit_before"}
    ).merge(
        after_df[after_cols].rename(
            columns={"bet_side": "bet_side_after", "bet_decision": "bet_decision_after", "profit": "profit_after"}
        ),
        on="fixture_id",
        how="inner",
    )
    merged["profit_delta"] = merged["profit_after"] - merged["profit_before"]
    merged["changed"] = (
        (merged["bet_side_before"] != merged["bet_side_after"])
        | (merged["bet_decision_before"] != merged["bet_decision_after"])
    )
    changed = merged[merged["changed"]].copy()
    cols = [
        "fixture_id",
        "date_utc",
        "home_team",
        "away_team",
        "home_goals",
        "away_goals",
        "bet_side_before",
        "bet_decision_before",
        "bet_side_after",
        "bet_decision_after",
        "profit_before",
        "profit_after",
        "profit_delta",
    ]
    return {
        "improved": _serialize_examples(changed.sort_values("profit_delta", ascending=False), cols),
        "worsened": _serialize_examples(changed.sort_values("profit_delta", ascending=True), cols),
    }


def main():
    df = _build_feature_frame()
    current_season = int(df["season"].astype(int).max())
    train_df = df[df["season"].astype(int) < current_season].copy()
    test_df = df[df["season"].astype(int) == current_season].copy()
    variants = _variant_map(df)

    totals_results = {}
    outcomes_results = {}
    for name, keep_cols in variants.items():
        totals_results[name] = _run_totals_variant(train_df, test_df, name, keep_cols)
        outcomes_results[name] = _run_outcomes_variant(train_df, test_df, keep_cols)

    best_totals_name = _pick_best_variant(totals_results)
    best_outcomes_name = _pick_best_variant(outcomes_results)

    report = {
        "window": {
            "train_seasons": sorted({int(x) for x in train_df["season"].dropna().astype(int).unique()}),
            "eval_season": current_season,
            "train_rows": int(len(train_df)),
            "eval_rows": int(len(test_df)),
        },
        "variants": {
            name: {
                "totals": {
                    "metrics": payload["metrics"],
                    "roi": payload["roi"],
                    "by_league": payload["by_league"],
                },
                "outcomes": {
                    "metrics": outcomes_results[name]["metrics"],
                    "roi": outcomes_results[name]["roi"],
                    "by_league": outcomes_results[name]["by_league"],
                },
            }
            for name, payload in totals_results.items()
        },
        "best": {
            "totals": {
                "variant": best_totals_name,
                "metrics": totals_results[best_totals_name]["metrics"],
                "roi": totals_results[best_totals_name]["roi"],
                "by_league": totals_results[best_totals_name]["by_league"],
                "examples_vs_baseline": _compare_examples(
                    totals_results["baseline"]["eval_df"],
                    totals_results[best_totals_name]["eval_df"],
                    market="totals",
                ),
            },
            "outcomes": {
                "variant": best_outcomes_name,
                "metrics": outcomes_results[best_outcomes_name]["metrics"],
                "roi": outcomes_results[best_outcomes_name]["roi"],
                "by_league": outcomes_results[best_outcomes_name]["by_league"],
                "examples_vs_baseline": _compare_examples(
                    outcomes_results["baseline"]["eval_df"],
                    outcomes_results[best_outcomes_name]["eval_df"],
                    market="outcomes",
                ),
            },
        },
    }

    print("JSON_REPORT_START")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
