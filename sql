router = APIRouter()

# ... ВСЕ router.get() ЗДЕСЬ ...

app.include_router(router)


❌ было (слишком рано):

router = APIRouter()
app.include_router(router)
