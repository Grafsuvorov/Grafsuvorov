import numpy as np
import pandas as pd


def _num(df: pd.DataFrame, col: str) -> pd.Series:
    if col not in df.columns:
        return pd.Series(np.nan, index=df.index, dtype=float)
    return pd.to_numeric(df[col], errors="coerce")


def _diff(df: pd.DataFrame, out_col: str, left: str, right: str):
    if left in df.columns and right in df.columns:
        df[out_col] = _num(df, left) - _num(df, right)


def _ratio(df: pd.DataFrame, out_col: str, num_col: str, den_col: str):
    if num_col in df.columns and den_col in df.columns:
        den = _num(df, den_col).replace(0, np.nan)
        df[out_col] = _num(df, num_col) / den


def build_result_script_features(df: pd.DataFrame, window: int = 8) -> pd.DataFrame:
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
                g[f"{metric}_form"] = g[metric].shift(1).rolling(window, min_periods=3).mean()
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


def add_outcome_scenario_features(df_all: pd.DataFrame) -> pd.DataFrame:
    df = df_all.copy()

    _diff(df, "osc_control_possession_diff", "home_possession_ema", "away_possession_ema")
    _diff(df, "osc_control_tempo_diff", "home_tempo_ema", "away_tempo_ema")
    _diff(df, "osc_control_danger_diff", "home_danger_attacks_mean", "away_danger_attacks_mean")
    _diff(df, "osc_control_understat_diff", "usys_home_control_matchup_5", "usys_away_control_matchup_5")
    _diff(df, "osc_pressing_edge_diff", "usys_home_press_matchup_5", "usys_away_press_matchup_5")

    _ratio(df, "osc_home_box_share", "home_shots_insidebox_ema", "home_total_shots_ema")
    _ratio(df, "osc_away_box_share", "away_shots_insidebox_ema", "away_total_shots_ema")
    _diff(df, "osc_box_share_diff", "osc_home_box_share", "osc_away_box_share")
    _diff(df, "osc_shot_quality_diff", "home_xg_per_shot_ema", "away_xg_per_shot_ema")
    _diff(df, "osc_transition_edge_home", "home_goals_minus_xg_ema", "away_possession_ema")
    _diff(df, "osc_transition_edge_away", "away_goals_minus_xg_ema", "home_possession_ema")
    _diff(df, "osc_transition_matchup_diff", "usys_home_efficiency_matchup_5", "usys_away_efficiency_matchup_5")

    _diff(df, "osc_first_goal_home", "home_xg_for_mean", "away_xg_against_mean")
    _diff(df, "osc_first_goal_away", "away_xg_for_mean", "home_xg_against_mean")
    _diff(df, "osc_first_goal_matchup", "usys_home_npxg_matchup_3", "usys_away_npxg_matchup_3")
    _diff(df, "osc_front_run_edge", "osc_first_goal_home", "osc_first_goal_away")

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

    _diff(df, "osc_resilience_finish_diff", "home_goals_minus_xg_ema", "away_goals_minus_xg_ema")
    _diff(df, "osc_resilience_us_trend_diff", "usys_home_finish_trend_3v10", "usys_away_finish_trend_3v10")
    _diff(df, "osc_resilience_def_trend_diff", "usys_home_def_finish_trend_3v10", "usys_away_def_finish_trend_3v10")
    _diff(df, "osc_resilience_venue_diff", "usys_home_venue_strength_5", "usys_away_venue_strength_5")

    _diff(df, "osc_draw_script_diff", "home_rs_is_draw_form", "away_rs_is_draw_form")
    _diff(df, "osc_close_script_diff", "home_rs_is_close_game_form", "away_rs_is_close_game_form")
    _diff(df, "osc_fav_conversion_diff", "home_rs_won_as_fav_form", "away_rs_won_as_fav_form")
    _diff(df, "osc_dog_upset_diff", "home_rs_won_as_dog_form", "away_rs_won_as_dog_form")
    _diff(df, "osc_dog_resilience_diff", "home_rs_avoid_loss_as_dog_form", "away_rs_avoid_loss_as_dog_form")
    _diff(df, "osc_fav_drop_diff", "home_rs_dropped_points_as_fav_form", "away_rs_dropped_points_as_fav_form")

    _diff(df, "osc_home_script_dominance", "osc_control_understat_diff", "usys_away_npxg_matchup_5")
    _diff(df, "osc_away_script_counter", "usys_away_npxg_matchup_5", "osc_control_understat_diff")
    _diff(df, "osc_home_script_direct", "osc_transition_edge_home", "osc_draw_balance_control_abs")
    _diff(df, "osc_away_script_direct", "osc_transition_edge_away", "osc_draw_balance_control_abs")

    return df
