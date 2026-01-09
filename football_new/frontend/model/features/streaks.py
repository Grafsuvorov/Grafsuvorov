import numpy as np
import pandas as pd


def _calc_streak(series: pd.Series, target: int) -> pd.Series:
    streak = []
    current = 0
    for val in series.fillna(0).astype(int):
        if val == target:
            current += 1
        else:
            current = 0
        streak.append(current)
    return pd.Series(streak, index=series.index)


def build_streak_features(schedule: pd.DataFrame, window: int = 6) -> pd.DataFrame:
    df = schedule.sort_values("date_utc").copy()
    rows = []

    for side in ["home", "away"]:
        side_cols = {
            "team": f"{side}_team_id",
            "gf": f"{side}_goals",
            "ga": f"{'away' if side == 'home' else 'home'}_goals",
        }
        tmp = df[["fixture_id", "date_utc", side_cols["team"], side_cols["gf"], side_cols["ga"]]].copy()
        tmp = tmp.rename(columns={
            side_cols["team"]: "team_id",
            side_cols["gf"]: "goals_for",
            side_cols["ga"]: "goals_against",
        })
        tmp["result"] = np.sign(tmp["goals_for"] - tmp["goals_against"])
        tmp_groups = []
        for team_id, g in tmp.groupby("team_id"):
            g = g.sort_values("date_utc").copy()
            g["points"] = np.where(g["result"] > 0, 3, np.where(g["result"] == 0, 1, 0))
            g["goal_diff"] = g["goals_for"] - g["goals_against"]
            g["points_avg_%d" % window] = (
                g["points"].shift(1).rolling(window, min_periods=1).mean()
            )
            g["goal_diff_avg_%d" % window] = (
                g["goal_diff"].shift(1).rolling(window, min_periods=1).mean()
            )
            g["wins_streak"] = _calc_streak(g["result"].shift(1).fillna(0), 1)
            g["loss_streak"] = _calc_streak(g["result"].shift(1).fillna(0), -1)
            g["unbeaten_streak"] = _calc_streak(
                (g["result"].shift(1) >= 0).astype(int),
                1,
            )
            tmp_groups.append(g)
        enriched = pd.concat(tmp_groups, ignore_index=True)
        enriched = enriched[[
            "fixture_id",
            "points_avg_%d" % window,
            "goal_diff_avg_%d" % window,
            "wins_streak",
            "loss_streak",
            "unbeaten_streak",
        ]]
        prefix = f"{side}"
        enriched = enriched.add_prefix(f"{prefix}_")
        enriched = enriched.rename(columns={f"{prefix}_fixture_id": "fixture_id"})
        rows.append(enriched)

    res = rows[0].merge(rows[1], on="fixture_id", how="outer")
    return res
