# api/favorites.py
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Literal
from sqlalchemy import text

from api.auth_dwh import get_current_user_dwh
from api.dwh_database import dwh_engine, create_dwh_favorites_table

router = APIRouter(
    prefix="/api",
    tags=["Избранное"],
    responses={404: {"description": "Not found"}},
)

class FavoriteItem(BaseModel):
    id: int
    name: Optional[str] = None
    league: Optional[str] = None
    season: Optional[str] = None
    team: Optional[str] = None

class FavoritesSyncRequest(BaseModel):
    type: Literal["team", "player"]
    items: List[FavoriteItem]

@router.get("/favorites")
def get_favorites(current_user=Depends(get_current_user_dwh)):
    create_dwh_favorites_table()
    with dwh_engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT item_type, item_id, name, league, season, team
                FROM football.user_favorites
                WHERE user_id = :user_id
                ORDER BY created_at DESC
                """
            ),
            {"user_id": current_user.id},
        ).mappings().all()
    teams = []
    players = []
    for r in rows:
        item = {
            "id": r["item_id"],
            "name": r["name"],
            "league": r["league"],
            "season": r["season"],
            "team": r["team"],
        }
        if r["item_type"] == "team":
            teams.append(item)
        elif r["item_type"] == "player":
            players.append(item)
    return {"teams": teams, "players": players}

@router.post("/favorites/sync")
def sync_favorites(payload: FavoritesSyncRequest, current_user=Depends(get_current_user_dwh)):
    create_dwh_favorites_table()
    item_type = payload.type
    items = payload.items or []
    with dwh_engine.connect() as conn:
        conn.execute(
            text(
                """
                DELETE FROM football.user_favorites
                WHERE user_id = :user_id AND item_type = :item_type
                """
            ),
            {"user_id": current_user.id, "item_type": item_type},
        )
        for item in items:
            conn.execute(
                text(
                    """
                    INSERT INTO football.user_favorites
                        (user_id, item_type, item_id, name, league, season, team)
                    VALUES
                        (:user_id, :item_type, :item_id, :name, :league, :season, :team)
                    ON CONFLICT (user_id, item_type, item_id)
                    DO UPDATE SET
                        name = EXCLUDED.name,
                        league = EXCLUDED.league,
                        season = EXCLUDED.season,
                        team = EXCLUDED.team
                    """
                ),
                {
                    "user_id": current_user.id,
                    "item_type": item_type,
                    "item_id": item.id,
                    "name": item.name,
                    "league": item.league,
                    "season": item.season,
                    "team": item.team,
                },
            )
        conn.commit()
    return {"ok": True, "count": len(items)}
