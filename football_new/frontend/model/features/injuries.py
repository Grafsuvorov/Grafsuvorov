# features/injuries.py

import pandas as pd
import numpy as np


def compute_injury_features(schedule, inj):
    inj["injury_date"] = pd.to_datetime(inj["injury_date"])

    rows = []

    for row in schedule.itertuples():
        t = row.date_utc
        fixture_id = row.fixture_id

        home = inj[
            (inj.team_id == row.home_team_id)
            & (inj.injury_date <= t.floor("D"))
        ]

        away = inj[
            (inj.team_id == row.away_team_id)
            & (inj.injury_date <= t.floor("D"))
        ]

        rows.append([
            fixture_id,
            len(home),
            len(away),
            home["impact_score"].sum() if "impact_score" in home else np.nan,
            away["impact_score"].sum() if "impact_score" in away else np.nan
        ])

    return pd.DataFrame(rows, columns=[
        "fixture_id",
        "inj_home_count",
        "inj_away_count",
        "inj_home_impact",
        "inj_away_impact"
    ])
