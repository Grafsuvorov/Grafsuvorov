# api/matchday_elo.py
from typing import Optional, Dict, Any, List, Tuple
from fastapi import APIRouter, Query, HTTPException
import os
import psycopg2
import psycopg2.extras
from datetime import date

router = APIRouter(prefix="/api", tags=["matchday-elo"])

DB_DSN = os.getenv("DB_DSN", "postgresql://postgres:0506@localhost:5432/dwh")

HOME_ADV = 60.0
ELO_INIT = 1500.0

def dyn_k(games_played: int) -> float:
    if games_played < 10:  # первые 10 матчей
        return 28.0
    if games_played < 20:
        return 22.0
    return 18.0

def elo_expected(ra: float, rb: float, home_adv: float = HOME_ADV) -> float:
    # вероятность победы хозяев по Эло
    return 1.0 / (1.0 + 10 ** ((rb - (ra + home_adv)) / 400.0))

def _fetch(sql: str, params: Dict[str, Any]) -> List[Dict[str, Any]]:
    conn = psycopg2.connect(DB_DSN)
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql, params)
            return [dict(r) for r in cur.fetchall()]
    finally:
        conn.close()

SQL_CURR_SEASON = """
select max(season)::int as season
from football.api_football_schedule
where ((%(league_id)s is not null and league_id = %(league_id)s)
    or (%(league_id)s is null and league_name = %(league_name)s));
"""

SQL_FINISHED_FOR_ELO = """
select date,
       home_team_id, away_team_id,
       coalesce(score_fulltime_home, home_goals) as gh,
       coalesce(score_fulltime_away, away_goals) as ga
from football.api_football_schedule
where ((%(league_id)s is not null and league_id = %(league_id)s)
    or (%(league_id)s is null and league_name = %(league_name)s))
  and season between %(season_from)s and %(season_to)s
  and trim(coalesce(status,'')) in ('Match Finished')
order by date asc;
"""

SQL_NEXT_ROUND_META = """
select round,
       min(date::date) as first_day,
       count(*) filter (where trim(coalesce(status,'')) not in ('Match Finished','Match Cancelled')) as cnt
from football.api_football_schedule
where ((%(league_id)s is not null and league_id = %(league_id)s)
    or (%(league_id)s is null and league_name = %(league_name)s))
  and trim(coalesce(status,'')) not in ('Match Finished','Match Cancelled')
group by round
order by first_day asc;
"""

SQL_MATCHES_FOR_ROUND = """
select fixture_id, date, trim(coalesce(status,'')) as status,
       home_team_id, home_team, away_team_id, away_team,
       season, league_id, league_name, round
from football.api_football_schedule
where ((%(league_id)s is not null and league_id = %(league_id)s)
    or (%(league_id)s is null and league_name = %(league_name)s))
  and round = %(round)s
  and trim(coalesce(status,'')) not in ('Match Finished','Match Cancelled')
order by date asc;
"""

def build_elo(
    league_id: Optional[int],
    league_name: Optional[str],
    season_to: int,
    seasons_back: int = 2,
) -> Dict[int, float]:
    season_from = max(0, season_to - seasons_back + 1)
    rows = _fetch(
        SQL_FINISHED_FOR_ELO,
        {
            "league_id": league_id,
            "league_name": (league_name or "").strip(),
            "season_from": season_from,
            "season_to": season_to,
        },
    )
    ratings: Dict[int, float] = {}
    games_cnt: Dict[int, int] = {}

    for r in rows:
        hid = int(r["home_team_id"])
        aid = int(r["away_team_id"])
        gh = r["gh"]
        ga = r["ga"]
        if gh is None or ga is None:
            continue

        rh = ratings.get(hid, ELO_INIT)
        ra = ratings.get(aid, ELO_INIT)

        # исход
        s_home = 1.0 if gh > ga else 0.5 if gh == ga else 0.0

        # ожидаемые вероятности с home_adv
        e_home = elo_expected(rh, ra, HOME_ADV)
        e_away = 1.0 - e_home

        kh = dyn_k(games_cnt.get(hid, 0))
        ka = dyn_k(games_cnt.get(aid, 0))

        ratings[hid] = rh + kh * (s_home - e_home)
        ratings[aid] = ra + ka * ((1.0 - s_home) - e_away)

        games_cnt[hid] = games_cnt.get(hid, 0) + 1
        games_cnt[aid] = games_cnt.get(aid, 0) + 1

    return ratings

@router.get("/matchday/elo")
def matchday_elo(
    league: Optional[str] = Query(None, description="Название лиги (если нет league_id)"),
    league_id: Optional[int] = Query(None, description="ID лиги"),
    top: int = Query(3, ge=1, le=10),
    seasons_back: int = Query(2, ge=1, le=5),
    min_cnt: int = Query(3, ge=1, le=20, description="минимум матчей в туре"),
):
    if league_id is None and (league is None or not league.strip()):
        raise HTTPException(status_code=400, detail="Укажи league_id или league.")

    base = {"league_id": league_id, "league_name": (league or "").strip()}

    # текущий сезон
    srow = _fetch(SQL_CURR_SEASON, base)
    if not srow or srow[0]["season"] is None:
        return []
    season = int(srow[0]["season"])

    # Эло по текущему и предыдущему сезону
    elo = build_elo(league_id, league, season_to=season, seasons_back=seasons_back)

    # ближайший тур
    rounds = _fetch(SQL_NEXT_ROUND_META, base)
    if not rounds:
        return []

    chosen = None
    for r in rounds:
        if int(r["cnt"]) >= min_cnt:
            chosen = r
            break
    if chosen is None:
        chosen = rounds[0]

    matches = _fetch(SQL_MATCHES_FOR_ROUND, {**base, "round": chosen["round"]})
    if not matches:
        return []

    # скорим внутри тура: качество (средний Эло) * баланс (насколько матч равный)
    out = []
    for m in matches:
        hid = int(m["home_team_id"])
        aid = int(m["away_team_id"])
        rh = float(elo.get(hid, ELO_INIT))
        ra = float(elo.get(aid, ELO_INIT))
        # «баланс» через вероятность победы хозяев
        p_home = elo_expected(rh, ra, HOME_ADV)
        balance = 1.0 - abs(p_home - 0.5) * 2.0  # 0..1
        quality = (rh + ra) / 2.0
        score = quality * (0.55 + 0.45 * balance)

        out.append(
            {
                "fixture_id": int(m["fixture_id"]),
                "kickoff": m["date"].isoformat() if m["date"] else None,
                "home_team_id": hid,
                "home_team": m["home_team"],
                "away_team_id": aid,
                "away_team": m["away_team"],
                "status": m["status"],
                "round": m["round"],
                "round_day": chosen["first_day"].isoformat() if chosen["first_day"] else None,
                "season": m["season"],
                "league_id": m["league_id"],
                "league_name": m["league_name"],
                "score": round(score, 1),
            }
        )

    out.sort(key=lambda x: x["score"], reverse=True)
    return out[:top]
