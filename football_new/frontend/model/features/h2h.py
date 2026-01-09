# features/h2h.py
import pandas as pd
import numpy as np


def compute_h2h(schedule: pd.DataFrame) -> pd.DataFrame:
    """
    H2H features without leakage:
    - uses only matches strictly before current match date
    - supports datasets WITHOUT xG columns (home_xg/away_xg)
    """
    df = schedule.sort_values("date_utc").copy()

    has_xg = ("home_xg" in df.columns) and ("away_xg" in df.columns)

    rows = []

    for row in df.itertuples():
        h, a = row.home_team_id, row.away_team_id
        t = row.date_utc

        past = df[
            (
                ((df.home_team_id == h) & (df.away_team_id == a)) |
                ((df.home_team_id == a) & (df.away_team_id == h))
            ) & (df.date_utc < t)
        ]

        if past.empty:
            rows.append([
                row.fixture_id,
                np.nan, np.nan, np.nan, np.nan,  # xg/goal diffs
                0,                                # matches
                np.nan, np.nan                     # last diffs
            ])
            continue

        # экспоненциальные веса по давности (без утечки)
        days = (t - past["date_utc"]).dt.days.clip(lower=1)
        w = np.exp(-days / 180.0)
        w = w / w.sum()

        # goals aligned to current home team
        g_h = np.where(past.home_team_id.values == h, past.home_goals.values, past.away_goals.values)
        g_a = np.where(past.home_team_id.values == h, past.away_goals.values, past.home_goals.values)

        goal_diff = float(np.sum(w * (g_h - g_a)))
        goals_for = float(np.sum(w * g_h))
        goals_against = float(np.sum(w * g_a))

        # last match diffs (последний по времени, до текущего)
        last = past.iloc[-1]
        if last.home_team_id == h:
            last_goal_diff = float(last.home_goals - last.away_goals)
        else:
            last_goal_diff = float(last.away_goals - last.home_goals)

        # xG aligned if available
        if has_xg:
            xg_h = np.where(past.home_team_id.values == h, past.home_xg.values, past.away_xg.values)
            xg_a = np.where(past.home_team_id.values == h, past.away_xg.values, past.home_xg.values)
            xg_diff = float(np.sum(w * (xg_h - xg_a)))

            if last.home_team_id == h:
                last_xg_diff = float(last.home_xg - last.away_xg)
            else:
                last_xg_diff = float(last.away_xg - last.home_xg)
        else:
            xg_diff = np.nan
            last_xg_diff = np.nan

        rows.append([
            row.fixture_id,
            xg_diff,
            goal_diff,
            goals_for,
            goals_against,
            int(len(past)),
            last_goal_diff,
            last_xg_diff
        ])

    return pd.DataFrame(rows, columns=[
        "fixture_id",
        "h2h_xg_diff",
        "h2h_goal_diff",
        "h2h_goals_for",
        "h2h_goals_against",
        "h2h_matches",
        "h2h_last_result_diff",
        "h2h_last_xg_diff",
    ])


def build_h2h_features(schedule: pd.DataFrame, mode: str = "train") -> pd.DataFrame:
    return compute_h2h(schedule)
