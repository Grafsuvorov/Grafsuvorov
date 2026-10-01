from fastapi import APIRouter, Request


router = APIRouter(tags=["system"])


@router.get("/ping")
def ping() -> dict[str, bool]:
    return {"pong": True}


@router.get("/api/routes")
def list_routes(request: Request) -> list[str]:
    return [route.path for route in request.app.routes]
