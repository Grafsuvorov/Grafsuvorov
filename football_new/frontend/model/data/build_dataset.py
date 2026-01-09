# Python 3.9
# FULL pre-match dataset builder (TRAIN = INFERENCE)
# NO LEAKAGE

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text
from typing import List

DB_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"
LEAGUE_IDS = [39, 61, 78, 135, 140]
STAT_COLS = [
    "tackles",
    "goals_prevented",
    "expected_goals",
    "total_shots",
    "passes_accurate",
    "shots_off_goal",
    "shots_insidebox",
    "passes",
    "fouls",
    "red_cards",
    "possession",
    "dangerous_attacks",
    "yellow_cards",
    "offsides",
    "corners",
    "shots_on_goal",
    "saves",
    "blocked_shots",
    "passes_percentage",
    "shots_outsidebox",
    "attacks",
]


# =========================================================
# BASE SCHEDULE
# =========================================================
def load_schedule(engine):
    return pd.read_sql(
        text("""
            SELECT
                fixture_id,
                date::timestamptz AS date_utc,
                season,
                league_id,
                home_team_id,
                away_team_id,
                home_goals,
                away_goals
            FROM football.api_football_schedule
            WHERE league_id IN :lids
            ORDER BY date
        """),
        engine,
        params={"lids": tuple(LEAGUE_IDS)},
    )


def load_match_stats(engine, fixture_ids: List[int]):
    if not fixture_ids:
        return pd.DataFrame()

    cols_sql = ",".join(STAT_COLS)
    return pd.read_sql(
        text(f"""
            SELECT
                fixture_id,
                team_id,
                {cols_sql}
            FROM football.api_football_match_stats
            WHERE fixture_id = ANY(:ids)
        """),
        engine,
        params={"ids": fixture_ids},
    )


# =========================================================
# TARGETS
# =========================================================
def build_targets(df):
    known = df["home_goals"].notna() & df["away_goals"].notna()
    df["has_result"] = known

    df["target_result"] = np.where(
        known,
        np.sign(df["home_goals"] - df["away_goals"]),
        np.nan,
    )

    df["target_over25"] = np.where(
        known,
        (df["home_goals"] + df["away_goals"] >= 3).astype(int),
        np.nan,
    )

    return df


# =========================================================
# TEAM GOALS FORM
# =========================================================
def build_team_form(df, window=5):
    rows = []

    for side in ["home", "away"]:
        t = (
            df[[
                "fixture_id",
                "date_utc",
                f"{side}_team_id",
                "home_goals",
                "away_goals",
            ]]
            .rename(columns={f"{side}_team_id": "team_id"})
            .copy()
        )

        t["goals_for"] = np.where(side == "home", t["home_goals"], t["away_goals"])
        t["goals_against"] = np.where(side == "home", t["away_goals"], t["home_goals"])

        t = t.sort_values("date_utc")

        t["avg_goals_for"] = (
            t.groupby("team_id")["goals_for"]
            .apply(lambda s: s.shift(1).rolling(window).mean())
            .reset_index(level=0, drop=True)
        )

        t["avg_goals_against"] = (
            t.groupby("team_id")["goals_against"]
            .apply(lambda s: s.shift(1).rolling(window).mean())
            .reset_index(level=0, drop=True)
        )

        t = t[["fixture_id", "avg_goals_for", "avg_goals_against"]]
        t.columns = [
            "fixture_id",
            f"{side}_avg_goals_for",
            f"{side}_avg_goals_against",
        ]

        rows.append(t)

    return rows[0].merge(rows[1], on="fixture_id", how="left")


def build_match_stats_features(sched: pd.DataFrame, engine, short_window: int = 3, long_window: int = 8) -> pd.DataFrame:
    stats = load_match_stats(engine, sched["fixture_id"].tolist())
    if stats.empty:
        return pd.DataFrame({"fixture_id": []})

    stats = stats.merge(
        sched[["fixture_id", "date_utc"]],
        on="fixture_id",
        how="left",
    )

    feature_cols = []
    for col in STAT_COLS:
        feature_cols.append(f"{col}_ma_short")
        feature_cols.append(f"{col}_ma_long")

    grouped = []
    for team_id, g in stats.groupby("team_id"):
        g = g.sort_values("date_utc").copy()
        for col in STAT_COLS:
            g[f"{col}_ma_short"] = g[col].shift(1).rolling(short_window, min_periods=1).mean()
            g[f"{col}_ma_long"] = g[col].shift(1).rolling(long_window, min_periods=1).mean()
        grouped.append(g[["fixture_id", "team_id"] + feature_cols])

    feats = pd.concat(grouped, ignore_index=True)

    def _merge_side(prefix: str, team_col: str):
        tmp = sched[["fixture_id", team_col]].merge(
            feats,
            left_on=["fixture_id", team_col],
            right_on=["fixture_id", "team_id"],
            how="left",
        )
        tmp = tmp.drop(columns=[team_col, "team_id"])
        tmp = tmp.rename(columns=lambda c: c if c == "fixture_id" else f"{prefix}_{c}")
        return tmp

    home_feats = _merge_side("home_stat", "home_team_id")
    away_feats = _merge_side("away_stat", "away_team_id")
    return home_feats.merge(away_feats, on="fixture_id", how="left")


# =========================================================
# MAIN DATASET (PUBLIC API)
# =========================================================
def build_dataset(return_all=True):
    engine = create_engine(DB_URL)

    sched = load_schedule(engine)
    sched["date_utc"] = pd.to_datetime(sched["date_utc"], utc=True)
    sched = build_targets(sched)

    form = build_team_form(sched, window=5)
    match_stats = build_match_stats_features(sched, engine)

    df = (
        sched
        .merge(form, on="fixture_id", how="left")
        .merge(match_stats, on="fixture_id", how="left")
        .sort_values("date_utc")
        .reset_index(drop=True)
    )

    return df if return_all else df[df["has_result"]]
