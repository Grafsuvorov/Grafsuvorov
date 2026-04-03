from __future__ import annotations

import argparse
import os
from pathlib import Path
from typing import Iterable

import requests
from sqlalchemy import create_engine, text


ROOT = Path(__file__).resolve().parents[1]
ICONS_DIR = ROOT / "frontend" / "public" / "icons"
PLAYER_DIR = ICONS_DIR / "player_photos"
TEAM_DIR = ICONS_DIR / "team_logos"

SUPPORTED_LEAGUES = {
    1: {"name": "World Cup", "seasons": [2022, 2026]},
    4: {"name": "Euro Championship", "seasons": [2020, 2024]},
    960: {"name": "Euro Championship - Qualification", "seasons": [2023]},
    29: {"name": "World Cup - Qualification Africa", "seasons": [2022, 2026]},
    30: {"name": "World Cup - Qualification Asia", "seasons": [2022, 2026]},
    31: {"name": "World Cup - Qualification CONCACAF", "seasons": [2022, 2026]},
    32: {"name": "World Cup - Qualification Europe", "seasons": [2020, 2024]},
    33: {"name": "World Cup - Qualification Oceania", "seasons": [2022, 2026]},
    34: {"name": "World Cup - Qualification South America", "seasons": [2022, 2026]},
    37: {"name": "World Cup - Qualification Intercontinental Play-offs", "seasons": [2022, 2026]},
}


def _session(api_key: str) -> requests.Session:
    s = requests.Session()
    s.headers.update(
        {
            "x-rapidapi-key": api_key,
            "x-rapidapi-host": "v3.football.api-sports.io",
            "Connection": "close",
        }
    )
    return s


def _safe_download(session: requests.Session, url: str, target: Path) -> bool:
    if not url or target.exists():
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    resp = session.get(url, timeout=(10, 60))
    resp.raise_for_status()
    target.write_bytes(resp.content)
    return True


def _iter_target_leagues() -> Iterable[tuple[int, dict]]:
    for league_id, meta in SUPPORTED_LEAGUES.items():
        yield league_id, meta


def download_league_logos(session: requests.Session) -> int:
    written = 0
    for league_id, meta in _iter_target_leagues():
        season = meta["seasons"][0]
        resp = session.get(
            "https://v3.football.api-sports.io/leagues",
            params={"id": league_id, "season": season},
            timeout=(10, 60),
        )
        resp.raise_for_status()
        rows = (resp.json() or {}).get("response", []) or []
        if not rows:
            continue
        logo_url = ((rows[0] or {}).get("league") or {}).get("logo")
        target = ICONS_DIR / f"{meta['name'].replace(' ', '_')}.png"
        written += int(_safe_download(session, logo_url, target))
    return written


def _db_engine() -> str:
    db_url = os.getenv("DATABASE_URL") or os.getenv("DB_URL")
    if not db_url:
        raise RuntimeError("DATABASE_URL/DB_URL is required")
    return create_engine(db_url, pool_pre_ping=True)


def _load_team_ids(engine) -> list[int]:
    sql = text(
        """
        SELECT DISTINCT home_team_id AS team_id
        FROM football.api_football_schedule
        WHERE season >= 2020 AND league_id = ANY(:league_ids) AND home_team_id IS NOT NULL
        UNION
        SELECT DISTINCT away_team_id AS team_id
        FROM football.api_football_schedule
        WHERE season >= 2020 AND league_id = ANY(:league_ids) AND away_team_id IS NOT NULL
        ORDER BY team_id
        """
    )
    with engine.connect() as conn:
        return [int(r.team_id) for r in conn.execute(sql, {"league_ids": list(SUPPORTED_LEAGUES.keys())}).mappings().all()]


def _load_player_ids(engine) -> list[int]:
    sql = text(
        """
        WITH p AS (
          SELECT DISTINCT player_id
          FROM football.api_football_player_stats
          WHERE fixture_id IN (
            SELECT fixture_id
            FROM football.api_football_schedule
            WHERE season >= 2020 AND league_id = ANY(:league_ids)
          )
          UNION
          SELECT DISTINCT player_id
          FROM football.api_football_topscorers
          WHERE season >= 2020 AND league_id = ANY(:league_ids)
          UNION
          SELECT DISTINCT player_id
          FROM football.api_football_topassists_min
          WHERE season >= 2020 AND league_id = ANY(:league_ids)
        )
        SELECT player_id
        FROM p
        WHERE player_id IS NOT NULL
        ORDER BY player_id
        """
    )
    with engine.connect() as conn:
        return [int(r.player_id) for r in conn.execute(sql, {"league_ids": list(SUPPORTED_LEAGUES.keys())}).mappings().all()]


def download_team_logos(session: requests.Session, engine, limit: int | None = None) -> int:
    written = 0
    for idx, team_id in enumerate(_load_team_ids(engine), start=1):
        if limit and idx > limit:
            break
        target = TEAM_DIR / f"{team_id}.png"
        if target.exists():
            continue
        resp = session.get(
            "https://v3.football.api-sports.io/teams",
            params={"id": team_id},
            timeout=(10, 60),
        )
        resp.raise_for_status()
        rows = (resp.json() or {}).get("response", []) or []
        if not rows:
            continue
        logo_url = ((rows[0] or {}).get("team") or {}).get("logo")
        written += int(_safe_download(session, logo_url, target))
    return written


def download_player_photos(session: requests.Session, engine, limit: int | None = None) -> int:
    written = 0
    for idx, player_id in enumerate(_load_player_ids(engine), start=1):
        if limit and idx > limit:
            break
        target = PLAYER_DIR / f"{player_id}.png"
        if target.exists():
            continue
        resp = session.get(
            "https://v3.football.api-sports.io/players",
            params={"id": player_id},
            timeout=(10, 60),
        )
        resp.raise_for_status()
        rows = (resp.json() or {}).get("response", []) or []
        if not rows:
            continue
        photo_url = ((rows[0] or {}).get("player") or {}).get("photo")
        written += int(_safe_download(session, photo_url, target))
    return written


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", choices=["all", "logos", "teams", "players"], default="all")
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    api_key = os.getenv("API_FOOTBALL_KEY")
    if not api_key:
        raise RuntimeError("API_FOOTBALL_KEY is required")

    session = _session(api_key)
    engine = None

    total = 0
    if args.only in {"all", "logos"}:
        total += download_league_logos(session)
    if args.only in {"all", "teams"}:
        engine = engine or _db_engine()
        total += download_team_logos(session, engine, limit=args.limit)
    if args.only in {"all", "players"}:
        engine = engine or _db_engine()
        total += download_player_photos(session, engine, limit=args.limit)

    print({"written": total, "mode": args.only})


if __name__ == "__main__":
    main()
