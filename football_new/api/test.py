from fastapi import APIRouter

router = APIRouter()

@router.get("/test")
async def test_endpoint():
    return {"message": "Test endpoint working", "status": "ok"}

@router.get("/test/health")
async def test_health():
    return {"message": "Test health check", "status": "healthy"}

@router.post("/test/data")
async def test_post(data: dict):
    return {"message": "Test POST endpoint", "received_data": data, "status": "ok"}
