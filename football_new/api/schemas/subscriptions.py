from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
from decimal import Decimal

class SubscriptionPlanDTO(BaseModel):
    id: int
    code: str
    name: str
    description: Optional[str]
    price: Decimal
    duration_days: int
    limit_reports_per_month: int
    limit_alerts_per_day: int
    is_active: bool
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class PurchaseRequest(BaseModel):
    plan_code: str

class PurchaseResponse(BaseModel):
    success: bool
    message: str
    new_balance: Decimal
    subscription_until: Optional[datetime]
    aggregated_limits: dict

class UserSubscriptionDTO(BaseModel):
    id: int
    plan_code: str
    plan_name: str
    price_at_purchase: Decimal
    start_at: datetime
    end_at: datetime
    is_active: bool

    class Config:
        from_attributes = True

class UserSubscriptionsResponse(BaseModel):
    balance: Decimal
    subscription_status: str
    subscription_until: Optional[datetime]
    active_subscriptions: List[UserSubscriptionDTO]
    aggregated_limits: dict

class AddFundsRequest(BaseModel):
    amount: Decimal
    reason: Optional[str] = "manual_credit"
