# features/injuries.py

import pandas as pd
import numpy as np


def compute_injury_features(schedule, inj):
    if "impact_score" not in inj.columns:
        # Fallback to a neutral 1.0 weight per injury when impact is missing.
        inj = inj.copy()
        inj["impact_score"] = 1.0

    # Preferred path: injuries are tied to a specific fixture (current API payloads).
    if "fixture_id" in inj.columns:
        by_team = (
            inj.groupby(["fixture_id", "team_id"], as_index=False)
            .agg(
                inj_count=("player_id", "count"),
                inj_impact=("impact_score", "sum"),
            )
        )

        home = by_team.rename(
            columns={
                "team_id": "home_team_id",
                "inj_count": "inj_home_count",
                "inj_impact": "inj_home_impact",
            }
        )
        away = by_team.rename(
            columns={
                "team_id": "away_team_id",
                "inj_count": "inj_away_count",
                "inj_impact": "inj_away_impact",
            }
        )

        out = (
            schedule[["fixture_id", "home_team_id", "away_team_id"]]
            .merge(home, on=["fixture_id", "home_team_id"], how="left")
            .merge(away, on=["fixture_id", "away_team_id"], how="left")
        )

        return out.assign(
            inj_home_count=out["inj_home_count"].fillna(0).astype(int),
            inj_away_count=out["inj_away_count"].fillna(0).astype(int),
            inj_home_impact=out["inj_home_impact"].fillna(0.0),
            inj_away_impact=out["inj_away_impact"].fillna(0.0),
        )[[
            "fixture_id",
            "inj_home_count",
            "inj_away_count",
            "inj_home_impact",
            "inj_away_impact",
        ]]

    # Fallback path for legacy schemas that store an injury date.
    if "injury_date" not in inj.columns:
        return pd.DataFrame(
            {
                "fixture_id": schedule["fixture_id"],
                "inj_home_count": 0,
                "inj_away_count": 0,
                "inj_home_impact": 0.0,
                "inj_away_impact": 0.0,
            }
        )

    inj = inj.copy()
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

        rows.append(
            [
                fixture_id,
                len(home),
                len(away),
                home["impact_score"].sum(),
                away["impact_score"].sum(),
            ]
        )

    return pd.DataFrame(
        rows,
        columns=[
            "fixture_id",
            "inj_home_count",
            "inj_away_count",
            "inj_home_impact",
            "inj_away_impact",
        ],
    )
