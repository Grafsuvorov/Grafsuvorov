# api/top_rated_players.py
from typing import Optional, List, Dict, Any
from fastapi import APIRouter, Query, HTTPException
import os
import psycopg2
import psycopg2.extras

router = APIRouter(prefix="/api", tags=["top-rated"])

DB_DSN = os.getenv("DB_DSN", "postgresql://postgres:0506@localhost:5432/dwh")

# Диагностика: какой сезон и день реально будут использованы (только там, где есть player_stats)
SQL_DIAGNOSTICS = """
with league_fx as (
  select s.fixture_id,
         s.date::date as d,
         s.date,
         trim(coalesce(s.status,'')) as status,
         s.season,
         s.league_id,
         s.league_name
  from football.api_football_schedule s
  where
    (
      (%(league_id)s is not null and s.league_id = %(league_id)s)
      or
      (%(league_id)s is null and s.league_name = %(league_name)s)
    )
    and trim(coalesce(s.status,'')) in ('Match Finished')
),
fx_with_stats as (
  select f.*
  from league_fx f
  where exists (
    select 1 from football.api_football_player_stats p
    where p.fixture_id = f.fixture_id
      and p.player_rating is not null
  )
),
season_used as (
  select max(season) as season
  from fx_with_stats
),
last_day as (
  select max(d) as d
  from fx_with_stats f
  join season_used s on s.season = f.season
)
select
  (select season from season_used) as season_used,
  (select d from last_day)        as last_day,
  (select count(*) from fx_with_stats f
     join season_used s on s.season = f.season
     join last_day ld on ld.d = f.d) as finished_matches_that_day;
"""

# Основной запрос: топ игроков по последнему дню последнего сезона с реальными stats
SQL_TOP_RATED_LATEST = """
with league_fx as (
  select s.fixture_id,
         s.date::date as d,
         s.date as kickoff,
         s.round,
         trim(coalesce(s.status,'')) as status,
         s.season,
         s.league_id,
         s.league_name
  from football.api_football_schedule s
  where
    (
      (%(league_id)s is not null and s.league_id = %(league_id)s)
      or
      (%(league_id)s is null and s.league_name = %(league_name)s)
    )
    and trim(coalesce(s.status,'')) in ('Match Finished')
),
fx_with_stats as (
  select f.*
  from league_fx f
  where exists (
    select 1 from football.api_football_player_stats p
    where p.fixture_id = f.fixture_id
      and p.player_rating is not null
  )
),
season_used as (
  select max(season) as season
  from fx_with_stats
),
last_day as (
  select max(d) as d
  from fx_with_stats f
  join season_used s on s.season = f.season
),
fx as (
  select f.*
  from fx_with_stats f
  join season_used s on s.season = f.season
  join last_day ld on ld.d = f.d
),
ps as (
  select
    p.player_id,
    p.player_name,
    p.team_id,
    p.team_name,
    p.player_rating as rating,
    p.minutes,
    p.goals,
    p.assists,
    p.shots_on,
    p.fixture_id
  from football.api_football_player_stats p
  join fx using (fixture_id)
  where p.player_rating is not null
    and coalesce(p.minutes, 0) >= %(min_minutes)s
)
select
  ps.player_id,
  ps.player_name,
  ps.team_id,
  ps.team_name,
  ps.rating,
  ps.minutes,
  ps.goals,
  ps.assists,
  ps.fixture_id,
  fx.round,
  fx.kickoff,
  fx.league_id,
  fx.league_name,
  fx.season
from ps
join fx on fx.fixture_id = ps.fixture_id
order by
  ps.rating desc nulls last,
  coalesce(ps.goals, 0) desc,
  coalesce(ps.assists, 0) desc,
  coalesce(ps.shots_on, 0) desc
limit %(limit)s;
"""

def _fetchall(sql: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
    conn = psycopg2.connect(DB_DSN)
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            rows = cur.fetchall()
            return [dict(r) for r in rows]
    finally:
        conn.close()

def _fetchone(sql: str, params: Dict[str, Any]) -> Dict[str, Any]:
    rows = _fetchall(sql, params)
    return rows[0] if rows else {}

@router.get("/top-rated")
def top_rated_latest(
    league: Optional[str] = Query(None, description="Название лиги (если нет league_id)"),
    league_id: Optional[int] = Query(None, description="ID лиги (приоритетнее league)"),
    limit: int = Query(3, ge=1, le=50),
    min_minutes: int = Query(30, ge=0, le=120),
):
    if league_id is None and (league is None or not league.strip()):
        raise HTTPException(status_code=400, detail="Укажи league_id или league (название лиги).")

    params = {
        "league_id": league_id,
        "league_name": (league or "").strip(),
        "limit": limit,
        "min_minutes": min_minutes,
    }
    return _fetchall(SQL_TOP_RATED_LATEST, params)

