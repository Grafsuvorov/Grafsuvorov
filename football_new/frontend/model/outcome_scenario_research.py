import json
from typing import Dict, List

import numpy as np
import pandas as pd

from config import UNDERSTAT_MIN_SEASON
from data.build_dataset import build_dataset
from data.loader import load_stats
from decision.outcomes_decision import decide_outcome_bet
from features.build_matrix import build_feature_matrix
from features.draw_diff import add_draw_diff_features
from features.elo import build_elo_features
from features.form_xg import build_form_xg_features
from features.h2h import build_h2h_features
from features.h2h_recent import build_h2h_recent_features
from features.league import build_league_context_features
from features.team_stats_form import build_team_stats_form
from models.inference import predict_outcomes
from train_outcomes import _train_outcomes_single


UNDERSTAT_PREFIXES = ("home_us_", "away_us_", "us_", "usys_")
RESULT_SCRIPT_PREFIXES = ("home_rs_", "away_rs_", "rs_")


def _num(df: pd.DataFrame, col: str) -> pd.Series:
    return pd.to_numeric(df[col], errors="coerce")


def _diff(df: pd.DataFrame, out_col: str, left: str, right: str):
    if left in df.columns and right in df.columns:
        df[out_col] = _num(df, left) - _num(df, right)


def _ratio(df: pd.DataFrame, out_col: str, num_col: str, den_col: str):
    if num_col in df.columns and den_col in df.columns:
        den = _num(df, den_col).replace(0, np.nan)
        df[out_col] = _num(df, num_col) / den


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


def _bet_profit(row: pd.Series) -> float:
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


def _by_league_summary(df: pd.DataFrame) -> Dict[str, Dict[str, float]]:
    out = {}
    for lid in sorted({int(x) for x in df["league_id"].dropna().unique()}):
        out[str(lid)] = _roi_summary(df[df["league_id"] == lid].copy())
    return out


def _build_base_frame() -> pd.DataFrame:
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
    df_all = df_all.merge(_build_result_script_features(df_all), on="fixture_id", how="left")
    df_all = _add_outcome_scenario_features(df_all)
    return df_all[df_all["has_result"]].copy()


def _build_result_script_features(df: pd.DataFrame, window: int = 8) -> pd.DataFrame:
    sched = df[
        [
            "fixture_id",
            "date_utc",
            "home_team_id",
            "away_team_id",
            "home_goals",
            "away_goals",
            "p_home_norm",
            "p_away_norm",
        ]
    ].copy()
    sched = sched.sort_values("date_utc").reset_index(drop=True)

    side_frames = []
    for side in ("home", "away"):
        team_col = f"{side}_team_id"
        t = sched[["fixture_id", "date_utc", team_col, "home_goals", "away_goals", "p_home_norm", "p_away_norm"]].rename(
            columns={team_col: "team_id"}
        )
        if side == "home":
            gf = pd.to_numeric(t["home_goals"], errors="coerce")
            ga = pd.to_numeric(t["away_goals"], errors="coerce")
            p_team = pd.to_numeric(t["p_home_norm"], errors="coerce")
            p_opp = pd.to_numeric(t["p_away_norm"], errors="coerce")
        else:
            gf = pd.to_numeric(t["away_goals"], errors="coerce")
            ga = pd.to_numeric(t["home_goals"], errors="coerce")
            p_team = pd.to_numeric(t["p_away_norm"], errors="coerce")
            p_opp = pd.to_numeric(t["p_home_norm"], errors="coerce")

        t["is_draw"] = (gf == ga).astype(float)
        t["is_close_game"] = (gf.sub(ga).abs() <= 1).astype(float)
        t["win"] = (gf > ga).astype(float)
        t["not_lose"] = (gf >= ga).astype(float)
        t["clean_sheet_win"] = ((gf > ga) & (ga == 0)).astype(float)
        t["fav"] = (p_team > p_opp).astype(float)
        t["dog"] = (p_team < p_opp).astype(float)
        t["won_as_fav"] = np.where(t["fav"] > 0, (gf > ga).astype(float), np.nan)
        t["won_as_dog"] = np.where(t["dog"] > 0, (gf > ga).astype(float), np.nan)
        t["draw_as_dog"] = np.where(t["dog"] > 0, (gf == ga).astype(float), np.nan)
        t["avoid_loss_as_dog"] = np.where(t["dog"] > 0, (gf >= ga).astype(float), np.nan)
        t["dropped_points_as_fav"] = np.where(t["fav"] > 0, (gf <= ga).astype(float), np.nan)

        metrics = [
            "is_draw",
            "is_close_game",
            "win",
            "not_lose",
            "clean_sheet_win",
            "won_as_fav",
            "won_as_dog",
            "draw_as_dog",
            "avoid_loss_as_dog",
            "dropped_points_as_fav",
        ]
        per_team = []
        for _, g in t.groupby("team_id"):
            g = g.sort_values("date_utc").copy()
            for metric in metrics:
                g[f"{metric}_form"] = (
                    g[metric].shift(1).rolling(window, min_periods=3).mean()
                )
            per_team.append(g[["fixture_id"] + [f"{m}_form" for m in metrics]])
        side_df = pd.concat(per_team, ignore_index=True) if per_team else pd.DataFrame({"fixture_id": []})
        side_df = side_df.add_prefix(f"{side}_rs_").rename(columns={f"{side}_rs_fixture_id": "fixture_id"})
        side_frames.append(side_df)

    res = side_frames[0].merge(side_frames[1], on="fixture_id", how="outer")
    diff_pairs = {
        "rs_draw_rate_diff": ("home_rs_is_draw_form", "away_rs_is_draw_form"),
        "rs_close_game_diff": ("home_rs_is_close_game_form", "away_rs_is_close_game_form"),
        "rs_win_diff": ("home_rs_win_form", "away_rs_win_form"),
        "rs_not_lose_diff": ("home_rs_not_lose_form", "away_rs_not_lose_form"),
        "rs_fav_conversion_diff": ("home_rs_won_as_fav_form", "away_rs_won_as_fav_form"),
        "rs_dog_upset_diff": ("home_rs_won_as_dog_form", "away_rs_won_as_dog_form"),
        "rs_dog_resilience_diff": ("home_rs_avoid_loss_as_dog_form", "away_rs_avoid_loss_as_dog_form"),
        "rs_fav_drop_diff": ("home_rs_dropped_points_as_fav_form", "away_rs_dropped_points_as_fav_form"),
    }
    for out_col, (left, right) in diff_pairs.items():
        _diff(res, out_col, left, right)
    return res


def _add_outcome_scenario_features(df_all: pd.DataFrame) -> pd.DataFrame:
    df = df_all.copy()

    # Control / territorial dominance.
    _diff(df, "osc_control_possession_diff", "home_possession_ema", "away_possession_ema")
    _diff(df, "osc_control_tempo_diff", "home_tempo_ema", "away_tempo_ema")
    _diff(df, "osc_control_danger_diff", "home_danger_attacks_mean", "away_danger_attacks_mean")
    _diff(df, "osc_control_understat_diff", "usys_home_control_matchup_5", "usys_away_control_matchup_5")
    _diff(df, "osc_pressing_edge_diff", "usys_home_press_matchup_5", "usys_away_press_matchup_5")

    # Directness / transition threat.
    _ratio(df, "osc_home_box_share", "home_shots_insidebox_ema", "home_total_shots_ema")
    _ratio(df, "osc_away_box_share", "away_shots_insidebox_ema", "away_total_shots_ema")
    _diff(df, "osc_box_share_diff", "osc_home_box_share", "osc_away_box_share")
    _diff(df, "osc_shot_quality_diff", "home_xg_per_shot_ema", "away_xg_per_shot_ema")
    _diff(df, "osc_transition_edge_home", "home_goals_minus_xg_ema", "away_possession_ema")
    _diff(df, "osc_transition_edge_away", "away_goals_minus_xg_ema", "home_possession_ema")
    _diff(df, "osc_transition_matchup_diff", "usys_home_efficiency_matchup_5", "usys_away_efficiency_matchup_5")

    # First goal / front-running proxy.
    _diff(df, "osc_first_goal_home", "home_xg_for_mean", "away_xg_against_mean")
    _diff(df, "osc_first_goal_away", "away_xg_for_mean", "home_xg_against_mean")
    _diff(df, "osc_first_goal_matchup", "usys_home_npxg_matchup_3", "usys_away_npxg_matchup_3")
    _diff(df, "osc_front_run_edge", "osc_first_goal_home", "osc_first_goal_away")

    # Draw balance / stale mate conditions.
    if "elo_diff" in df.columns:
        df["osc_draw_balance_elo_abs"] = _num(df, "elo_diff").abs()
    if "xg_for_diff" in df.columns:
        df["osc_draw_balance_xg_abs"] = _num(df, "xg_for_diff").abs()
    if "osc_control_possession_diff" in df.columns:
        df["osc_draw_balance_control_abs"] = _num(df, "osc_control_possession_diff").abs()
    if "osc_front_run_edge" in df.columns:
        df["osc_draw_balance_front_abs"] = _num(df, "osc_front_run_edge").abs()
    if all(c in df.columns for c in ["home_xg_against_mean", "away_xg_against_mean"]):
        df["osc_draw_low_event_proxy"] = _num(df, "home_xg_against_mean") + _num(df, "away_xg_against_mean")

    # Resilience / game-state stability.
    _diff(df, "osc_resilience_finish_diff", "home_goals_minus_xg_ema", "away_goals_minus_xg_ema")
    _diff(df, "osc_resilience_us_trend_diff", "usys_home_finish_trend_3v10", "usys_away_finish_trend_3v10")
    _diff(df, "osc_resilience_def_trend_diff", "usys_home_def_finish_trend_3v10", "usys_away_def_finish_trend_3v10")
    _diff(df, "osc_resilience_venue_diff", "usys_home_venue_strength_5", "usys_away_venue_strength_5")

    # Result script conversion from historical outcomes.
    _diff(df, "osc_draw_script_diff", "home_rs_is_draw_form", "away_rs_is_draw_form")
    _diff(df, "osc_close_script_diff", "home_rs_is_close_game_form", "away_rs_is_close_game_form")
    _diff(df, "osc_fav_conversion_diff", "home_rs_won_as_fav_form", "away_rs_won_as_fav_form")
    _diff(df, "osc_dog_upset_diff", "home_rs_won_as_dog_form", "away_rs_won_as_dog_form")
    _diff(df, "osc_dog_resilience_diff", "home_rs_avoid_loss_as_dog_form", "away_rs_avoid_loss_as_dog_form")
    _diff(df, "osc_fav_drop_diff", "home_rs_dropped_points_as_fav_form", "away_rs_dropped_points_as_fav_form")

    # Meta scenarios: likely script of the match.
    _diff(df, "osc_home_script_dominance", "osc_control_understat_diff", "usys_away_npxg_matchup_5")
    _diff(df, "osc_away_script_counter", "usys_away_npxg_matchup_5", "osc_control_understat_diff")
    _diff(df, "osc_home_script_direct", "osc_transition_edge_home", "osc_draw_balance_control_abs")
    _diff(df, "osc_away_script_direct", "osc_transition_edge_away", "osc_draw_balance_control_abs")

    return df


def _variant_map(df: pd.DataFrame) -> Dict[str, List[str]]:
    understat_cols = [c for c in df.columns if c.startswith(UNDERSTAT_PREFIXES)]
    scenario_cols = [c for c in df.columns if c.startswith("osc_")]
    result_script_raw_cols = [c for c in df.columns if c.startswith(("home_rs_", "away_rs_", "rs_"))]
    draw_cols = [c for c in scenario_cols if "draw_" in c]
    control_cols = [c for c in scenario_cols if "control" in c or "pressing" in c]
    transition_cols = [c for c in scenario_cols if "transition" in c or "direct" in c or "shot_quality" in c or "box_share" in c]
    first_goal_cols = [c for c in scenario_cols if "first_goal" in c or "front_run" in c or "script_" in c]
    resilience_cols = [c for c in scenario_cols if "resilience" in c]
    result_script_cols = [c for c in scenario_cols if "conversion" in c or "dog_" in c or "fav_" in c or "close_" in c]

    # Only the strongest existing Understat outcome block.
    core_understat = [
        "home_us_npxg_all_5",
        "away_us_npxg_all_5",
        "home_us_npxga_all_5",
        "away_us_npxga_all_5",
        "home_us_npxg_all_10",
        "away_us_npxg_all_10",
        "home_us_npxga_all_10",
        "away_us_npxga_all_10",
    ]

    return {
        "baseline": [],
        "understat_core": core_understat,
        "draw_balance": draw_cols,
        "control_transition": sorted(set(control_cols + transition_cols)),
        "first_goal_resilience": sorted(set(first_goal_cols + resilience_cols)),
        "result_script": sorted(set(result_script_cols + result_script_raw_cols)),
        "draw_result_script": sorted(set(draw_cols + result_script_cols + result_script_raw_cols)),
        "scenario_system": sorted(set(core_understat + scenario_cols)),
    }


def _filter_variant(df: pd.DataFrame, keep_cols: List[str]) -> pd.DataFrame:
    all_variant_cols = [
        c for c in df.columns
        if c.startswith(UNDERSTAT_PREFIXES) or c.startswith("osc_") or c.startswith(("home_rs_", "away_rs_", "rs_"))
    ]
    drop_cols = [c for c in all_variant_cols if c not in set(keep_cols)]
    return df.drop(columns=drop_cols, errors="ignore").copy()


def _evaluate_predictions(df: pd.DataFrame, probs: np.ndarray) -> pd.DataFrame:
    out = df.copy().reset_index(drop=True)
    if "home_team" not in out.columns:
        out["home_team"] = out["home_team_id"].astype(str)
    if "away_team" not in out.columns:
        out["away_team"] = out["away_team_id"].astype(str)
    out["p_away"] = probs[:, 0]
    out["p_draw"] = probs[:, 1]
    out["p_home"] = probs[:, 2]

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
    picks.loc[bets, "profit_raw"] = picks.loc[bets].apply(_bet_profit, axis=1)
    picks["profit"] = picks["profit_raw"] * picks["stake"]
    return picks


def _run_variant(train_df: pd.DataFrame, test_df: pd.DataFrame, keep_cols: List[str]) -> Dict[str, object]:
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
    eval_df = _evaluate_predictions(test_part, probs)
    return {
        "metrics": {
            "val_ll": _weighted_metric(metrics_by_league, "val_ll"),
            "val_acc": _weighted_metric(metrics_by_league, "val_acc"),
            "val_n": int(sum(int(v.get("val_n", 0)) for v in metrics_by_league.values())),
            "by_league": metrics_by_league,
        },
        "roi": _roi_summary(eval_df),
        "by_league": _by_league_summary(eval_df),
        "eval_df": eval_df,
    }


def _pick_best_variant(results: Dict[str, Dict[str, object]]) -> str:
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


def _serialize_examples(df: pd.DataFrame, cols: List[str], n: int = 5):
    out = []
    for rec in df.head(n)[cols].to_dict(orient="records"):
        row = dict(rec)
        if row.get("date_utc") is not None and hasattr(row["date_utc"], "isoformat"):
            row["date_utc"] = row["date_utc"].isoformat()
        for key, val in list(row.items()):
            if isinstance(val, (np.floating, float)):
                row[key] = float(val)
            elif isinstance(val, (np.integer, int)):
                row[key] = int(val)
        out.append(row)
    return out


def _compare_examples(before_df: pd.DataFrame, after_df: pd.DataFrame):
    merged = before_df[
        [
            "fixture_id",
            "date_utc",
            "home_team",
            "away_team",
            "home_goals",
            "away_goals",
            "bet_side",
            "bet_decision",
            "profit",
        ]
    ].rename(
        columns={"bet_side": "bet_side_before", "bet_decision": "bet_decision_before", "profit": "profit_before"}
    ).merge(
        after_df[["fixture_id", "bet_side", "bet_decision", "profit"]].rename(
            columns={"bet_side": "bet_side_after", "bet_decision": "bet_decision_after", "profit": "profit_after"}
        ),
        on="fixture_id",
        how="inner",
    )
    merged["profit_delta"] = merged["profit_after"] - merged["profit_before"]
    changed = merged[
        (merged["bet_side_before"] != merged["bet_side_after"])
        | (merged["bet_decision_before"] != merged["bet_decision_after"])
    ].copy()
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
    df = _build_base_frame()
    current_season = int(df["season"].astype(int).max())
    train_df = df[df["season"].astype(int) < current_season].copy()
    test_df = df[df["season"].astype(int) == current_season].copy()
    variants = _variant_map(df)

    results = {}
    for name, keep_cols in variants.items():
        results[name] = _run_variant(train_df, test_df, keep_cols)

    best_name = _pick_best_variant(results)
    report = {
        "window": {
            "train_seasons": sorted({int(x) for x in train_df["season"].dropna().astype(int).unique()}),
            "eval_season": current_season,
            "train_rows": int(len(train_df)),
            "eval_rows": int(len(test_df)),
        },
        "variants": {
            name: {
                "metrics": payload["metrics"],
                "roi": payload["roi"],
                "by_league": payload["by_league"],
            }
            for name, payload in results.items()
        },
        "best": {
            "variant": best_name,
            "metrics": results[best_name]["metrics"],
            "roi": results[best_name]["roi"],
            "by_league": results[best_name]["by_league"],
            "examples_vs_baseline": _compare_examples(results["baseline"]["eval_df"], results[best_name]["eval_df"]),
        },
    }
    print("JSON_REPORT_START")
    print(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
