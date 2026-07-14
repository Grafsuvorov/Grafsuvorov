from fastapi import APIRouter, HTTPException, Response
import httpx


router = APIRouter(
    prefix="/api",
    tags=["Image Proxy"],
    responses={404: {"description": "Not found"}},
)

_HTTP_TIMEOUT = httpx.Timeout(10.0, connect=5.0)
_CACHE_CONTROL = "public, max-age=86400, s-maxage=604800"


async def _fetch_image(url: str) -> Response:
    async with httpx.AsyncClient(timeout=_HTTP_TIMEOUT, follow_redirects=True) as client:
        upstream = await client.get(url)

    if upstream.status_code != 200 or not upstream.content:
        raise HTTPException(status_code=404, detail="Image not found")

    media_type = upstream.headers.get("content-type", "image/png").split(";")[0].strip()
    return Response(
        content=upstream.content,
        media_type=media_type or "image/png",
        headers={"Cache-Control": _CACHE_CONTROL},
    )


@router.get("/team-logo/{team_id}", summary="Proxy team logo")
async def team_logo(team_id: int):
    return await _fetch_image(f"https://media.api-sports.io/football/teams/{team_id}.png")


@router.get("/player-photo/{player_id}", summary="Proxy player photo")
async def player_photo(player_id: int):
    return await _fetch_image(f"https://media.api-sports.io/football/players/{player_id}.png")
