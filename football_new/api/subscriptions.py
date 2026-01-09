# api/subscriptions.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from decimal import Decimal

from api.database import get_db
from api.services.subscription_service import SubscriptionService
from api.schemas.subscriptions import (
    SubscriptionPlanDTO,
    PurchaseRequest,
    PurchaseResponse,
    UserSubscriptionsResponse,
    AddFundsRequest,
)
from api.models import User, SubscriptionPlan  # <-- добавили SubscriptionPlan

router = APIRouter(
    prefix="/subscriptions", 
    tags=["Подписки"],
    responses={404: {"description": "Not found"}}
)

# Временная авторизация (только для локального теста)
async def get_current_user_for_testing() -> User:
    return User(
        id=1,
        username="test_user",
        email="test@example.com",
        balance=Decimal("100.00"),
        subscription_status="free",
    )

@router.get("/ping")
async def ping():
    return {"ok": True}

@router.get("/plans", response_model=List[SubscriptionPlanDTO])
async def get_subscription_plans(db: Session = Depends(get_db)):
    try:
        service = SubscriptionService(db)
        plans = service.get_active_plans()
        return plans
    except Exception as e:
        print(f"Error in get_subscription_plans: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/me", response_model=UserSubscriptionsResponse)
async def get_my_subscriptions(
    current_user: User = Depends(get_current_user_for_testing),
    db: Session = Depends(get_db),
):
    service = SubscriptionService(db)
    try:
        return service.get_user_subscriptions_info(current_user.id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.post("/purchase", response_model=PurchaseResponse)
async def purchase_subscription(
    request: PurchaseRequest,
    current_user: User = Depends(get_current_user_for_testing),
    db: Session = Depends(get_db),
):
    service = SubscriptionService(db)
    try:
        return service.purchase_subscription(current_user.id, request.plan_code)
    except ValueError as e:
        msg = str(e)
        if "уже есть активная подписка" in msg:
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=msg)
        if "Недостаточно средств" in msg:
            raise HTTPException(status_code=status.HTTP_402_PAYMENT_REQUIRED, detail=msg)
        if "не найден" in msg:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=msg)
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=msg)

@router.post("/add-funds")
async def add_funds_to_user(
    request: AddFundsRequest,
    current_user: User = Depends(get_current_user_for_testing),
    db: Session = Depends(get_db),
):
    if request.amount <= 0:
        raise HTTPException(status_code=400, detail="Сумма должна быть больше 0")
    service = SubscriptionService(db)
    try:
        service.add_funds_to_user(current_user.id, request.amount, request.reason)
        return {"success": True, "message": f"Баланс пополнен на {request.amount} ₽"}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


# =========================
# DEV: Полностью новые планы
# =========================
@router.post("/dev/seed-new-plans")
def dev_seed_new_plans(db: Session = Depends(get_db)):
    """
    Активирует новый каталог планов (апсерт по code) и деактивирует все старые.
    Безопасно для уже купленных подписок: мы НЕ удаляем записи, только is_active у старых = False.
    """
    NEW_PLANS = [
        {
            "code": "FREE",
            "name": "Бесплатный",
            "description": "Базовый доступ: ограниченные лимиты, но без оплаты.",
            "price": Decimal("0.00"),
            "duration_days": 30,
            "limit_reports_per_month": 5,
            "limit_alerts_per_day": 1,
            "is_active": True,
        },
        {
            "code": "START",
            "name": "Старт",
            "description": "Оптимально для начала: больше отчётов и уведомлений.",
            "price": Decimal("149.00"),
            "duration_days": 30,
            "limit_reports_per_month": 20,
            "limit_alerts_per_day": 5,
            "is_active": True,
        },
        {
            "code": "PRO",
            "name": "Про",
            "description": "Расширенные лимиты и приоритет в очередях.",
            "price": Decimal("499.00"),
            "duration_days": 30,
            "limit_reports_per_month": 60,
            "limit_alerts_per_day": 15,
            "is_active": True,
        },
        {
            "code": "ELITE",
            "name": "Элитный",
            "description": "Максимум возможностей: высокие лимиты и премиум-поддержка.",
            "price": Decimal("999.00"),
            "duration_days": 30,
            "limit_reports_per_month": 200,
            "limit_alerts_per_day": 50,
            "is_active": True,
        },
    ]

    # 1) деактивируем все существующие планы
    db.query(SubscriptionPlan).update({SubscriptionPlan.is_active: False})
    db.commit()

    # 2) апсертим новые по code
    activated = []
    for p in NEW_PLANS:
        row = db.query(SubscriptionPlan).filter(SubscriptionPlan.code == p["code"]).first()
        if row:
            row.name = p["name"]
            row.description = p["description"]
            row.price = p["price"]
            row.duration_days = p["duration_days"]
            row.limit_reports_per_month = p["limit_reports_per_month"]
            row.limit_alerts_per_day = p["limit_alerts_per_day"]
            row.is_active = True
        else:
            row = SubscriptionPlan(**p)
            db.add(row)
        activated.append(p["code"])

    db.commit()
    return {"ok": True, "activated": activated}
