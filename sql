@router.get("/api/routes")
def list_routes():
    return [route.path for route in app.routes]
