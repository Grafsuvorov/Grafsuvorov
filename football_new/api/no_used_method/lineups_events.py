# api/lineups_events.py
# -*- coding: utf-8 -*-

from fastapi import APIRouter, Query, HTTPException
from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine
from typing import Optional
import os

# === DB engine ===
DB_URL = os.getenv("DB_URL", "postgresql+psycopg2://postgres:0506@localhost:5432/dwh")
engine: Engine = create_engine(DB_URL, pool_pre_ping=True)

router = APIRouter(
    prefix="/api",
    tags=["Составы и события"],
    responses={404: {"description": "Not found"}}
)

@router.get("/lineups-events")
def get_lineups_events(
    fixture_id: int = Query(..., description="ID матча (из API-Football)"),
):
    """
    Возвращает плоские списки lineups и events по матчу.
    Фото игроков подставляется на фронте: /icons/player_photos/{player_id}.png
    """

    # --- LINEUPS: плоские строки (LEFT JOIN на статы) ---
    sql_lineups = text("""
        SELECT
            l.fixture_id,
            l.team_id,
            l.team_name,
            l.coach_id,
            l.coach_name,
            l.formation,
            l.player_id,
            l.player_name,
            l.number,
            l.position,
            l.grid,
            l.is_starting,

            -- статы (могут быть NULL)
            s.player_rating AS rating,
            s.minutes,
            s.captain,
            s.substitute,
            s.goals,
            s.assists,
            s.shots_total,
            s.shots_on,
            s.passes_total,
            s.passes_key,
            s.passes_accuracy,
            s.tackles_total,
            s.tackles_blocks,
            s.tackles_interceptions,
            s.duels_total,
            s.duels_won,
            s.dribbles_attempts,
            s.dribbles_success,
            s.fouls_drawn,
            s.fouls_committed,
            s.penalty_won::float8       AS penalty_won,
            s.penalty_committed::float8 AS penalty_committed,
            s.penalty_scored,
            s.penalty_missed,
            s.penalty_saved
        FROM football.api_football_lineups l
        LEFT JOIN football.api_football_player_stats s
          ON s.fixture_id = l.fixture_id
         AND s.team_id    = l.team_id
         AND s.player_id  = l.player_id
        WHERE l.fixture_id = :fixture_id
        ORDER BY
            l.team_id,
            CASE WHEN l.is_starting THEN 0 ELSE 1 END,
            COALESCE(l.position, 'Z'),
            COALESCE(l.number, 9999)
    """)

    # --- EVENTS: плоские строки + вычисляем период матча ---
    sql_events = text("""
        SELECT
            e.fixture_id,
            e.team_id,
            e.team_name,
            COALESCE(e.elapsed, 0) AS minute,
            COALESCE(e.extra,   0) AS extra,
            e.type,
            e.detail,
            e.comments,
            e.player_id,
            e.player_name,
            e.assist_id,
            e.assist_name,
            CASE
              WHEN COALESCE(e.elapsed,0) <= 45 THEN '1H'
              WHEN COALESCE(e.elapsed,0) <= 90 THEN '2H'
              WHEN COALESCE(e.elapsed,0) <= 120 THEN 'ET'
              ELSE 'PEN'
            END AS period
        FROM football.api_football_match_events e
        WHERE e.fixture_id = :fixture_id
        ORDER BY COALESCE(e.elapsed,0), COALESCE(e.extra,0), e.team_id
    """)

    with engine.begin() as con:
        lineups_rows = con.execute(sql_lineups, {"fixture_id": fixture_id}).mappings().all()
        events_rows  = con.execute(sql_events,  {"fixture_id": fixture_id}).mappings().all()

    # Преобразуем в обычные dict'ы
    lineups = [dict(r) for r in lineups_rows]
    events  = [dict(r) for r in events_rows]

    return {
        "fixture_id": fixture_id,
        "lineups": lineups,
        "events": events
    }


@router.get("/match/lineups-events")
def get_lineups_events_alias(
    fixture_id: int = Query(..., description="ID матча (из API-Football)"),
):
    """Совместимость для нового пути /match/lineups-events."""

    return get_lineups_events(fixture_id)


@router.get("/player-stats-card")
def get_player_stats_card(
    fixture_id: int = Query(..., description="ID матча"),
    player_id: int = Query(..., description="ID игрока"),
    team_id: Optional[int] = Query(None, description="ID команды (опционально)"),
):
    """
    Карточка игрока по матчу (для модалки).
    Возвращает агрегированный JSON по секциям.
    """
    sql = text("""
        WITH s AS (
            SELECT
                s.fixture_id, s.team_id, s.team_name,
                s.player_id, s.player_name,
                s.player_rating, s.minutes, s.captain, s.substitute,
                s.goals, s.assists,
                s.shots_total, s.shots_on,
                s.passes_total, s.passes_key, s.passes_accuracy,
                s.tackles_total, s.tackles_blocks, s.tackles_interceptions,
                s.duels_total, s.duels_won,
                s.dribbles_attempts, s.dribbles_success,
                s.fouls_drawn, s.fouls_committed,
                s.cards_yellow, s.cards_red,
                s.penalty_won::float8       AS penalty_won,
                s.penalty_committed::float8 AS penalty_committed,
                s.penalty_scored, s.penalty_missed, s.penalty_saved
            FROM football.api_football_player_stats s
            WHERE s.fixture_id = :fixture_id
              AND s.player_id  = :player_id
              AND (:team_id IS NULL OR s.team_id = :team_id)
            LIMIT 1
        )
        SELECT
            COALESCE(s.fixture_id, l.fixture_id)             AS fixture_id,
            COALESCE(s.team_id,    l.team_id)                AS team_id,
            COALESCE(s.team_name,  l.team_name)              AS team_name,
            COALESCE(s.player_id,  l.player_id)              AS player_id,
            COALESCE(s.player_name,l.player_name)            AS player_name,
            s.player_rating,
            s.minutes,
            s.captain,
            s.substitute,
            s.goals, s.assists,
            s.shots_total, s.shots_on,
            s.passes_total, s.passes_key, s.passes_accuracy,
            s.tackles_total, s.tackles_blocks, s.tackles_interceptions,
            s.duels_total, s.duels_won,
            s.dribbles_attempts, s.dribbles_success,
            s.fouls_drawn, s.fouls_committed,
            s.cards_yellow, s.cards_red,
            s.penalty_won,
            s.penalty_committed,
            s.penalty_scored, s.penalty_missed, s.penalty_saved,
            l.number, l.position, l.grid, l.formation
        FROM s
        FULL JOIN football.api_football_lineups l
          ON l.fixture_id = COALESCE(s.fixture_id, :fixture_id)
         AND l.player_id  = :player_id
         AND (:team_id IS NULL OR l.team_id = :team_id)
        WHERE COALESCE(s.fixture_id, l.fixture_id) = :fixture_id
        LIMIT 1
    """)

    def _pct(num, den):
        try:
            if num is None or den in (None, 0):
                return None
            return round((float(num) / float(den)) * 100.0, 0)
        except Exception:
            return None

    def _pct_from_text(val):
        if not val:
            return None
        st = str(val).strip().replace('%', '')
        try:
            return round(float(st), 0)
        except Exception:
            return None

    with engine.begin() as con:
        row = con.execute(
            sql,
            {"fixture_id": fixture_id, "player_id": player_id, "team_id": team_id}
        ).mappings().first()

    if not row:
        raise HTTPException(status_code=404, detail="No data for this player/match")

    # производные/проценты
    passes_acc_pct    = _pct_from_text(row.get("passes_accuracy"))
    duels_win_pct     = _pct(row.get("duels_won"), row.get("duels_total"))
    dribbles_succ_pct = _pct(row.get("dribbles_success"), row.get("dribbles_attempts"))
    shots_total       = row.get("shots_total")
    shots_on          = row.get("shots_on")
    shots_off         = (shots_total - shots_on) if (shots_total is not None and shots_on is not None) else None

    return {
        "header": {
            "player_id":    row.get("player_id"),
            "player_name":  row.get("player_name"),
            "team_id":      row.get("team_id"),
            "team_name":    row.get("team_name"),
            "number":       row.get("number"),
            "position":     row.get("position"),
            "rating":       row.get("player_rating"),
            "minutes":      row.get("minutes"),
            "formation":    row.get("formation"),
            "grid":         row.get("grid"),
            "photo_url":    ("/icons/player_photos/%s.png" % row.get("player_id")) if row.get("player_id") else None
        },
        "discipline": {
            "yellow": row.get("cards_yellow"),
            "red":    row.get("cards_red"),
            "fouls_committed": row.get("fouls_committed"),
            "fouls_drawn":     row.get("fouls_drawn"),
        },
        "shooting": {
            "shots_total": shots_total,
            "shots_on":    shots_on,
            "shots_off":   shots_off,
            "xg":          None,  # можно добавить при расширении схемы
            "xgot":        None,
            "goals":       row.get("goals"),
            "headers":     None,
            "in_box":      None,
            "out_box":     None
        },
        "attack": {
            "touches_box":        None,
            "big_chances_missed": None,
            "dribbles_attempts":  row.get("dribbles_attempts"),
            "dribbles_success":   row.get("dribbles_success"),
            "dribbles_success_pct": dribbles_succ_pct,
            "offsides":           None,
            "assists":            row.get("assists"),
        },
        "passing": {
            "passes_total":   row.get("passes_total"),
            "key_passes":     row.get("passes_key"),
            "accuracy_pct":   passes_acc_pct,
            "crosses_success":None,
            "long_balls_succ":None
        },
        "defence": {
            "duels_total":        row.get("duels_total"),
            "duels_won":          row.get("duels_won"),
            "duels_won_pct":      duels_win_pct,
            "aerials_total":      None,
            "aerials_won":        None,
            "tackles_total":      row.get("tackles_total"),
            "interceptions":      row.get("tackles_interceptions"),
            "blocks":             row.get("tackles_blocks"),
            "clearances":         None,
        },
        "penalties": {
            "won":       row.get("penalty_won"),
            "committed": row.get("penalty_committed"),
            "scored":    row.get("penalty_scored"),
            "missed":    row.get("penalty_missed"),
            "saved":     row.get("penalty_saved"),
        },
        "flags": {
            "captain":    row.get("captain"),
            "substitute": row.get("substitute"),
        }
    }
