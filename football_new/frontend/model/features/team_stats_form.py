# features/team_stats_form.py

import numpy as np
import pandas as pd


def _ewm_with_fallback(series: pd.Series, span: int, min_periods: int = 3) -> pd.Series:
    ewm = series.shift(1).ewm(span=span, min_periods=min_periods, adjust=False).mean()
    exp = series.shift(1).expanding(min_periods=min_periods).mean()
    return ewm.fillna(exp)


def build_team_stats_form(
    schedule: pd.DataFrame,
    stats: pd.DataFrame,
    window: int = 5,
) -> pd.DataFrame:
    """
    Team-level rolling/ewm form from match stats (no leakage).
    Uses only shift(1) with fallback to expanding mean.
    """

    if stats is None or stats.empty:
        base = pd.DataFrame({"fixture_id": schedule["fixture_id"]})
        return base

    required_cols = [
        "fixture_id",
        "team_id",
        "expected_goals",
        "shots_on_goal",
        "total_shots",
        "shots_insidebox",
        "corners",
        "dangerous_attacks",
        "possession",
    ]
    if any(col not in stats.columns for col in required_cols):
        stats = stats.copy()
        for col in required_cols:
            if col not in stats.columns:
                stats[col] = np.nan

    side_frames = []

    for side in ["home", "away"]:
        team_col = f"{side}_team_id"

        merged = schedule[["fixture_id", "date_utc", team_col, "home_goals", "away_goals"]].merge(
            stats,
            left_on=["fixture_id", team_col],
            right_on=["fixture_id", "team_id"],
            how="left",
        )

        per_team = []
        for _, g in merged.groupby(team_col):
            g = g.sort_values("date_utc").copy()

            if side == "home":
                g["goals_for"] = g["home_goals"]
            else:
                g["goals_for"] = g["away_goals"]

            goals_minus_xg = g["goals_for"] - g["expected_goals"]

            g["xg_ema"] = _ewm_with_fallback(g["expected_goals"], window)
            g["goals_minus_xg_ema"] = _ewm_with_fallback(goals_minus_xg, window)
            g["shots_on_goal_ema"] = _ewm_with_fallback(g["shots_on_goal"], window)
            g["total_shots_ema"] = _ewm_with_fallback(g["total_shots"], window)
            g["shots_insidebox_ema"] = _ewm_with_fallback(g["shots_insidebox"], window)
            g["corners_ema"] = _ewm_with_fallback(g["corners"], window)
            g["danger_attacks_ema"] = _ewm_with_fallback(g["dangerous_attacks"], window)
            g["possession_ema"] = _ewm_with_fallback(g["possession"], window)

            tempo_raw = g[["total_shots", "corners", "dangerous_attacks"]].sum(axis=1)
            g["tempo_ema"] = _ewm_with_fallback(tempo_raw, window)

            xg_per_shot = g["expected_goals"] / g["total_shots"].replace(0, np.nan)
            g["xg_per_shot_ema"] = _ewm_with_fallback(xg_per_shot, window)

            out = g[[
                "fixture_id",
                "xg_ema",
                "goals_minus_xg_ema",
                "shots_on_goal_ema",
                "total_shots_ema",
                "shots_insidebox_ema",
                "corners_ema",
                "danger_attacks_ema",
                "possession_ema",
                "tempo_ema",
                "xg_per_shot_ema",
            ]].copy()
            per_team.append(out)

        if per_team:
            side_df = pd.concat(per_team, ignore_index=True)
        else:
            side_df = merged[["fixture_id"]].copy()

        side_df = side_df.add_prefix(f"{side}_")
        side_df = side_df.rename(columns={f"{side}_fixture_id": "fixture_id"})
        side_frames.append(side_df)

    if not side_frames:
        return pd.DataFrame({"fixture_id": schedule["fixture_id"]})

    res = side_frames[0].merge(side_frames[1], on="fixture_id", how="outer")

    res["xg_ema_diff"] = res["home_xg_ema"] - res["away_xg_ema"]
    res["goals_minus_xg_ema_diff"] = res["home_goals_minus_xg_ema"] - res["away_goals_minus_xg_ema"]
    res["team_stats_tempo_diff"] = res["home_tempo_ema"] - res["away_tempo_ema"]
    res["shots_insidebox_ema_diff"] = res["home_shots_insidebox_ema"] - res["away_shots_insidebox_ema"]
    res["xg_per_shot_ema_diff"] = res["home_xg_per_shot_ema"] - res["away_xg_per_shot_ema"]

    return res
