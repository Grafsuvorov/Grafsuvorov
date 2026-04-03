import pandas as pd
import numpy as np


def build_h2h_recent_features(schedule: pd.DataFrame, window: int = 5) -> pd.DataFrame:
    df = schedule.sort_values("date_utc").copy()
    rows = []

    for row in df.itertuples():
        h, a = row.home_team_id, row.away_team_id
        t = row.date_utc

        past = df[
            (
                ((df.home_team_id == h) & (df.away_team_id == a))
                | ((df.home_team_id == a) & (df.away_team_id == h))
            )
            & (df.date_utc < t)
        ].tail(window)

        if past.empty:
            rows.append([
                row.fixture_id,
                0,
                0,
                0,
                np.nan,
                np.nan,
                np.nan,
            ])
            continue

        aligned_home_goals = np.where(
            past.home_team_id.values == h,
            past.home_goals.values,
            past.away_goals.values,
        )
        aligned_away_goals = np.where(
            past.home_team_id.values == h,
            past.away_goals.values,
            past.home_goals.values,
        )
        results = np.sign(aligned_home_goals - aligned_away_goals)
        points = np.where(results > 0, 3, np.where(results == 0, 1, 0))

        avg_goal_diff = (aligned_home_goals - aligned_away_goals).mean()
        avg_points = points.mean()
        last_result = results[-1]
        last_goal_diff = aligned_home_goals[-1] - aligned_away_goals[-1]

        time_since_last = (t - past.iloc[-1].date_utc).days
        rows.append([
            row.fixture_id,
            avg_goal_diff,
            avg_points,
            last_result,
            last_goal_diff,
            float(time_since_last),
            len(past),
        ])

    res = pd.DataFrame(
        rows,
        columns=[
            "fixture_id",
            "h2h_avg_goal_diff",
            "h2h_avg_points",
            "h2h_last_result",
            "h2h_last_goal_diff",
            "h2h_days_since",
            "h2h_matches_sample",
        ],
    )
    return res
