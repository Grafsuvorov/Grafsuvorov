# features/calendar.py

import pandas as pd
import numpy as np


def compute_calendar_features(schedule):
    df = schedule.sort_values("date_utc")

    rows = []

    for team_side, col in [("home", "home_team_id"), ("away", "away_team_id")]:
        grouped = df.groupby(col)

        for tid, g in grouped:
            g = g.sort_values("date_utc").reset_index(drop=True)

            g["rest_days"] = g["date_utc"].diff().dt.total_seconds() / 86400
            g["rest_days"].fillna(7.0, inplace=True)  # default first match

            g["short_rest"] = (g["rest_days"] < 4).astype(int)
            g["long_rest"] = (g["rest_days"] > 10).astype(int)

            # density = span (days) across last 14 matches
            ts = g["date_utc"].astype("int64")
            g["density14"] = ts.rolling(14, min_periods=1).apply(
                lambda x: (x.max() - x.min()) / 86_400_000_000_000 if len(x) > 1 else 0,
                raw=True,
            )

            rows.append(g[["fixture_id", "rest_days", "short_rest", "long_rest", "density14"]])

    out = pd.concat(rows)
    return out.groupby("fixture_id").first().reset_index()


def build_calendar_features(schedule):
    return compute_calendar_features(schedule)
