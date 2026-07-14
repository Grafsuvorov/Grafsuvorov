from __future__ import annotations

import os

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, text

from .settings import DB_URL, DEFAULT_MODE, DEFAULT_PREDICTION_HOURS, LEAGUES


def _adapt_v4_csv_snapshot(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()
    out["match_start_utc"] = pd.to_datetime(out["date_utc"], utc=True, errors="coerce")
    out["prediction_time_utc"] = out["match_start_utc"] - pd.to_timedelta(DEFAULT_PREDICTION_HOURS, unit="h")
    out["odds_snapshot_time_utc"] = out["prediction_time_utc"]
    out["mode"] = DEFAULT_MODE
    out["hours_before_match"] = float(DEFAULT_PREDICTION_HOURS)

    out["avg_odds_home_current"] = out["avg_odds_home"]
    out["avg_odds_draw_current"] = out["avg_odds_draw"]
    out["avg_odds_away_current"] = out["avg_odds_away"]
    out["avg_odds_home_open"] = out["avg_odds_home"]
    out["avg_odds_draw_open"] = out["avg_odds_draw"]
    out["avg_odds_away_open"] = out["avg_odds_away"]
    out["n_bookmakers_current"] = out["n_bookmakers"]
    out["n_bookmakers_open"] = out["n_bookmakers"]
    out["market_timing_source"] = "synthetic_same_snapshot"

    hg = pd.to_numeric(out["home_goals"], errors="coerce").fillna(0)
    ag = pd.to_numeric(out["away_goals"], errors="coerce").fillna(0)
    out["target_result"] = ((hg > ag).astype(int) * 2) + ((hg == ag).astype(int))
    out["target_over25"] = ((hg + ag) >= 3).astype(int)
    return out


def load_v5_snapshot() -> pd.DataFrame:
    csv_path = os.getenv("V5_SNAPSHOT_CSV")
    if csv_path:
        df = pd.read_csv(csv_path)
        if "match_start_utc" not in df.columns and "date_utc" in df.columns:
            df = _adapt_v4_csv_snapshot(df)
        if "market_timing_source" not in df.columns:
            has_distinct_timed_cols = {
                "avg_odds_home_open",
                "avg_odds_draw_open",
                "avg_odds_away_open",
                "avg_odds_home_current",
                "avg_odds_draw_current",
                "avg_odds_away_current",
            }.issubset(df.columns)
            if has_distinct_timed_cols:
                same_open_current = (
                    (df["avg_odds_home_open"] == df["avg_odds_home_current"])
                    & (df["avg_odds_draw_open"] == df["avg_odds_draw_current"])
                    & (df["avg_odds_away_open"] == df["avg_odds_away_current"])
                )
                df["market_timing_source"] = np.where(
                    same_open_current.fillna(False),
                    "synthetic_same_snapshot",
                    "timed_from_csv",
                )
            else:
                df["market_timing_source"] = "unknown"
        for col in ("match_start_utc", "prediction_time_utc", "odds_snapshot_time_utc", "date_utc"):
            if col in df.columns:
                df[col] = pd.to_datetime(df[col], utc=True, errors="coerce")
        return df.sort_values(["match_start_utc", "fixture_id"]).reset_index(drop=True)

    engine = create_engine(DB_URL, pool_pre_ping=True)
    q = text(
        """
        WITH odds_snap AS (
          SELECT
            s.fixture_id,
            MAX(CASE WHEN os.snapshot_time_utc <= (s.date::timestamp - (:prediction_hours || ' hours')::interval)
                     THEN os.snapshot_time_utc END) AS current_snapshot_time_utc,
            MIN(os.snapshot_time_utc) AS open_snapshot_time_utc
          FROM football.api_football_schedule s
          LEFT JOIN football.odds_snapshots_v1 os
            ON os.fixture_id = s.fixture_id
          WHERE s.league_id = ANY(:league_ids)
          GROUP BY s.fixture_id
        ),
        current_odds AS (
          SELECT
            o.fixture_id,
            o.snapshot_time_utc,
            o.bookmaker_count,
            o.avg_odds_home,
            o.avg_odds_draw,
            o.avg_odds_away,
            o.avg_odds_over25,
            o.avg_odds_under25
          FROM football.odds_snapshots_v1 o
          JOIN odds_snap x
            ON x.fixture_id = o.fixture_id
           AND x.current_snapshot_time_utc = o.snapshot_time_utc
        ),
        open_odds AS (
          SELECT
            o.fixture_id,
            o.snapshot_time_utc,
            o.bookmaker_count,
            o.avg_odds_home,
            o.avg_odds_draw,
            o.avg_odds_away,
            o.avg_odds_over25,
            o.avg_odds_under25
          FROM football.odds_snapshots_v1 o
          JOIN odds_snap x
            ON x.fixture_id = o.fixture_id
           AND x.open_snapshot_time_utc = o.snapshot_time_utc
        )
        SELECT
          s.fixture_id,
          s.league_id,
          s.league_name AS league,
          s.season::text AS season,
          s.round,
          s.date::timestamp AS match_start_utc,
          (s.date::timestamp - (:prediction_hours || ' hours')::interval) AS prediction_time_utc,
          :mode AS mode,
          :prediction_hours::double precision AS hours_before_match,
          s.home_team_id,
          s.away_team_id,
          s.home_team,
          s.away_team,
          s.home_goals,
          s.away_goals,
          COALESCE(co.avg_odds_home, v.avg_odds_home) AS avg_odds_home_current,
          COALESCE(co.avg_odds_draw, v.avg_odds_draw) AS avg_odds_draw_current,
          COALESCE(co.avg_odds_away, v.avg_odds_away) AS avg_odds_away_current,
          COALESCE(oo.avg_odds_home, v.avg_odds_home) AS avg_odds_home_open,
          COALESCE(oo.avg_odds_draw, v.avg_odds_draw) AS avg_odds_draw_open,
          COALESCE(oo.avg_odds_away, v.avg_odds_away) AS avg_odds_away_open,
          COALESCE(co.bookmaker_count, v.n_bookmakers) AS n_bookmakers_current,
          COALESCE(oo.bookmaker_count, v.n_bookmakers) AS n_bookmakers_open,
          COALESCE(co.snapshot_time_utc, s.date::timestamp) AS odds_snapshot_time_utc,
          CASE
            WHEN co.snapshot_time_utc IS NOT NULL AND oo.snapshot_time_utc IS NOT NULL AND co.snapshot_time_utc <> oo.snapshot_time_utc
              THEN 'timed_from_odds_snapshots_v1'
            WHEN co.snapshot_time_utc IS NOT NULL AND oo.snapshot_time_utc IS NOT NULL
              THEN 'timed_single_point_from_odds_snapshots_v1'
            ELSE 'single_snapshot_db'
          END AS market_timing_source
        FROM football.api_football_schedule s
        JOIN football.v_ml_epl_training v
          ON v.fixture_id = s.fixture_id
        LEFT JOIN current_odds co
          ON co.fixture_id = s.fixture_id
        LEFT JOIN open_odds oo
          ON oo.fixture_id = s.fixture_id
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
        df = pd.read_sql(
            q,
            conn,
            params={
                "league_ids": list(LEAGUES),
                "prediction_hours": DEFAULT_PREDICTION_HOURS,
                "mode": DEFAULT_MODE,
            },
        )

    df["match_start_utc"] = pd.to_datetime(df["match_start_utc"], utc=True, errors="coerce")
    df["prediction_time_utc"] = pd.to_datetime(df["prediction_time_utc"], utc=True, errors="coerce")
    df["odds_snapshot_time_utc"] = pd.to_datetime(df["odds_snapshot_time_utc"], utc=True, errors="coerce")
    df["target_result"] = (
        (pd.to_numeric(df["home_goals"], errors="coerce") > pd.to_numeric(df["away_goals"], errors="coerce")).astype(int) * 2
        + (pd.to_numeric(df["home_goals"], errors="coerce") == pd.to_numeric(df["away_goals"], errors="coerce")).astype(int)
    )
    df["target_over25"] = (
        pd.to_numeric(df["home_goals"], errors="coerce").fillna(0)
        + pd.to_numeric(df["away_goals"], errors="coerce").fillna(0)
        >= 3
    ).astype(int)
    return df.sort_values(["match_start_utc", "fixture_id"]).reset_index(drop=True)
