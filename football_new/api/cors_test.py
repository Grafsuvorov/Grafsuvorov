from fastapi import APIRouter

router = APIRouter()

@router.get("/cors-test")
async def cors_test():
    return {"message": "CORS test endpoint", "status": "ok"}

@router.post("/cors-test-post")
async def cors_test_post():
    return {"message": "CORS test POST endpoint", "status": "ok"}
