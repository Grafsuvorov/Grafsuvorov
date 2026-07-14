from __future__ import annotations

import os

import pandas as pd
from sqlalchemy import create_engine, text

from .settings import DB_URL, LEAGUES


def load_match_snapshot() -> pd.DataFrame:
    csv_path = os.getenv("V4_SNAPSHOT_CSV")
    if csv_path:
        df = pd.read_csv(csv_path)
        df["date_utc"] = pd.to_datetime(df["date_utc"], utc=True, errors="coerce")
        return df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)

    engine = create_engine(DB_URL, pool_pre_ping=True)
    q = text(
        """
        WITH stats AS (
          SELECT
            s.fixture_id,
            MAX(CASE WHEN ms.team_id = s.home_team_id THEN ms.expected_goals END)::double precision AS home_xg,
            MAX(CASE WHEN ms.team_id = s.away_team_id THEN ms.expected_goals END)::double precision AS away_xg,
            MAX(CASE WHEN ms.team_id = s.home_team_id THEN ms.total_shots END)::double precision AS home_shots,
            MAX(CASE WHEN ms.team_id = s.away_team_id THEN ms.total_shots END)::double precision AS away_shots,
            MAX(CASE WHEN ms.team_id = s.home_team_id THEN ms.shots_on_goal END)::double precision AS home_shots_on_goal,
            MAX(CASE WHEN ms.team_id = s.away_team_id THEN ms.shots_on_goal END)::double precision AS away_shots_on_goal,
            MAX(CASE WHEN ms.team_id = s.home_team_id THEN ms.possession END)::double precision AS home_possession,
            MAX(CASE WHEN ms.team_id = s.away_team_id THEN ms.possession END)::double precision AS away_possession,
            MAX(CASE WHEN ms.team_id = s.home_team_id THEN ms.corners END)::double precision AS home_corners,
            MAX(CASE WHEN ms.team_id = s.away_team_id THEN ms.corners END)::double precision AS away_corners,
            MAX(CASE WHEN ms.team_id = s.home_team_id THEN ms.dangerous_attacks END)::double precision AS home_dangerous_attacks,
            MAX(CASE WHEN ms.team_id = s.away_team_id THEN ms.dangerous_attacks END)::double precision AS away_dangerous_attacks
          FROM football.api_football_schedule s
          LEFT JOIN football.api_football_match_stats ms
            ON ms.fixture_id = s.fixture_id
          WHERE s.league_id = ANY(:league_ids)
          GROUP BY s.fixture_id
        )
        SELECT
          s.fixture_id,
          s.date::timestamp AS date_utc,
          s.season::text AS season,
          s.round,
          s.league_id,
          s.league_name AS league,
          s.home_team_id,
          s.away_team_id,
          s.home_team,
          s.away_team,
          s.home_goals,
          s.away_goals,
          v.avg_odds_home,
          v.avg_odds_draw,
          v.avg_odds_away,
          v.avg_odds_over25,
          v.avg_odds_under25,
          v.n_bookmakers,
          stats.home_xg,
          stats.away_xg,
          stats.home_shots,
          stats.away_shots,
          stats.home_shots_on_goal,
          stats.away_shots_on_goal,
          stats.home_possession,
          stats.away_possession,
          stats.home_corners,
          stats.away_corners,
          stats.home_dangerous_attacks,
          stats.away_dangerous_attacks
        FROM football.api_football_schedule s
        JOIN football.v_ml_epl_training v
          ON v.fixture_id = s.fixture_id
        LEFT JOIN stats
          ON stats.fixture_id = s.fixture_id
        WHERE s.league_id = ANY(:league_ids)
          AND s.home_goals IS NOT NULL
          AND s.away_goals IS NOT NULL
          AND v.avg_odds_home IS NOT NULL
          AND v.avg_odds_draw IS NOT NULL
          AND v.avg_odds_away IS NOT NULL
        ORDER BY s.date::timestamp, s.fixture_id
        """
    )
    with engine.connect() as conn:
        df = pd.read_sql(q, conn, params={"league_ids": list(LEAGUES)})
    df["date_utc"] = pd.to_datetime(df["date_utc"], utc=True, errors="coerce")
    return df.sort_values(["date_utc", "fixture_id"]).reset_index(drop=True)
