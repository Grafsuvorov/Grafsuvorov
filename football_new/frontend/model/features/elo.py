# features/elo.py

import numpy as np
import pandas as pd
from config import ELO_INIT, ELO_HOME_ADV


def elo_expected(r_home, r_away):
    ea = 1 / (1 + 10 ** ((r_away - (r_home + ELO_HOME_ADV)) / 400))
    return ea, 1 - ea


def update_k(games):
    if games < 10:
        return 28
    if games < 20:
        return 22
    return 18


def compute_elo(schedule: pd.DataFrame) -> pd.DataFrame:
    schedule = schedule.sort_values("date_utc")
    ratings = {}
    games = {}

    rows = []

    for row in schedule.itertuples():
        h, a = row.home_team_id, row.away_team_id
        rh = ratings.get(h, ELO_INIT)
        ra = ratings.get(a, ELO_INIT)

        eh, ea = elo_expected(rh, ra)

        rows.append([
            row.fixture_id,
            rh,
            ra,
            rh - ra,
            eh,
            ea,
        ])

        if pd.notna(row.home_goals):
            s_h = 1 if row.home_goals > row.away_goals else 0.5 if row.home_goals == row.away_goals else 0
            s_a = 1 - s_h

            k_h = update_k(games.get(h, 0))
            k_a = update_k(games.get(a, 0))

            ratings[h] = rh + k_h * (s_h - eh)
            ratings[a] = ra + k_a * (s_a - ea)

            games[h] = games.get(h, 0) + 1
            games[a] = games.get(a, 0) + 1

    return pd.DataFrame(
        rows,
        columns=[
            "fixture_id",
            "elo_home",
            "elo_away",
            "elo_diff",
            "p_home_elo",
            "p_away_elo",
        ],
    )


# === ЕДИНАЯ ТОЧКА ВХОДА ===
def build_elo_features(schedule: pd.DataFrame, mode: str = "train") -> pd.DataFrame:
    return compute_elo(schedule)
