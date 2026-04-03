# api/services/subscription_service.py
from sqlalchemy.orm import Session
from sqlalchemy import and_
from datetime import datetime, timedelta
from decimal import Decimal
from typing import Dict, Optional, List

from api.models import User, SubscriptionPlan, UserSubscription, WalletTransaction
# ВАЖНО: plural — subscriptions
from api.schemas.subscriptions import (
    PurchaseRequest,
    PurchaseResponse,
    UserSubscriptionsResponse,
)

class SubscriptionService:
    def __init__(self, db: Session):
        self.db = db

    def get_active_plans(self) -> List[SubscriptionPlan]:
        return self.db.query(SubscriptionPlan).filter(SubscriptionPlan.is_active == True).all()

    def get_plan_by_code(self, plan_code: str) -> Optional[SubscriptionPlan]:
        return (
            self.db.query(SubscriptionPlan)
            .filter(and_(SubscriptionPlan.code == plan_code, SubscriptionPlan.is_active == True))
            .first()
        )

    def get_user_active_subscriptions(self, user_id: int) -> List[UserSubscription]:
        now = datetime.utcnow()
        return (
            self.db.query(UserSubscription)
            .filter(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_active == True,
                    UserSubscription.end_at > now,
                )
            )
            .all()
        )

    def get_aggregated_limits(self, user_id: int) -> Dict:
        now = datetime.utcnow()
        active_subs = (
            self.db.query(UserSubscription)
            .join(SubscriptionPlan)
            .filter(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_active == True,
                    UserSubscription.end_at > now,
                )
            )
            .all()
        )
        total_reports = sum(sub.plan.limit_reports_per_month for sub in active_subs)
        total_alerts = sum(sub.plan.limit_alerts_per_day for sub in active_subs)
        return {"reports_per_month_total": total_reports, "alerts_per_day_total": total_alerts}

    def can_purchase_plan(self, user_id: int, plan_id: int) -> bool:
        now = datetime.utcnow()
        existing_sub = (
            self.db.query(UserSubscription)
            .filter(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.plan_id == plan_id,
                    UserSubscription.is_active == True,
                    UserSubscription.end_at > now,
                )
            )
            .first()
        )
        return existing_sub is None

    def purchase_subscription(self, user_id: int, plan_code: str) -> PurchaseResponse:
        try:
            plan = self.get_plan_by_code(plan_code)
            if not plan:
                raise ValueError("План подписки не найден или неактивен")

            if not self.can_purchase_plan(user_id, plan.id):
                raise ValueError("У вас уже есть активная подписка на этот план")

            user = self.db.query(User).filter(User.id == user_id).first()
            if not user:
                raise ValueError("Пользователь не найден")

            if user.balance < plan.price:
                raise ValueError("Недостаточно средств на балансе")

            if plan.price > 0:
                transaction = WalletTransaction(
                    user_id=user_id, amount=plan.price, type="debit", reason=f"subscription:{plan.code}"
                )
                self.db.add(transaction)
                user.balance -= plan.price

            start_at = datetime.utcnow()
            end_at = start_at + timedelta(days=plan.duration_days)

            subscription = UserSubscription(
                user_id=user_id,
                plan_id=plan.id,
                price_at_purchase=plan.price,
                start_at=start_at,
                end_at=end_at,
                is_active=True,
            )
            self.db.add(subscription)

            self._update_user_subscription_status(user_id)
            self.db.commit()

            user = self.db.query(User).filter(User.id == user_id).first()
            aggregated_limits = self.get_aggregated_limits(user_id)

            return PurchaseResponse(
                success=True,
                message=f"Подписка {plan.name} успешно оформлена",
                new_balance=user.balance,
                subscription_until=user.subscription_until,
                aggregated_limits=aggregated_limits,
            )
        except Exception:
            self.db.rollback()
            raise

    def _update_user_subscription_status(self, user_id: int):
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            return

        active_subs = self.get_user_active_subscriptions(user_id)
        if not active_subs:
            user.subscription_status = "free"
            user.subscription_until = None
        else:
            user.subscription_status = "active"
            user.subscription_until = max(sub.end_at for sub in active_subs)

    def get_user_subscriptions_info(self, user_id: int) -> UserSubscriptionsResponse:
        user = self.db.query(User).filter(User.id == user_id).first()
        if not user:
            raise ValueError("Пользователь не найден")

        now = datetime.utcnow()
        active_subs = (
            self.db.query(UserSubscription)
            .join(SubscriptionPlan)
            .filter(
                and_(
                    UserSubscription.user_id == user_id,
                    UserSubscription.is_active == True,
                    UserSubscription.end_at > now,
                )
            )
            .all()
        )

        aggregated_limits = self.get_aggregated_limits(user_id)
        subscription_dtos = [
            {
                "id": sub.id,
                "plan_code": sub.plan.code,
                "plan_name": sub.plan.name,
                "price_at_purchase": sub.price_at_purchase,
                "start_at": sub.start_at,
                "end_at": sub.end_at,
                "is_active": sub.is_active,
            }
            for sub in active_subs
        ]

        return UserSubscriptionsResponse(
            balance=user.balance,
            subscription_status=user.subscription_status,
            subscription_until=user.subscription_until,
            active_subscriptions=subscription_dtos,
            aggregated_limits=aggregated_limits,
        )

    def add_funds_to_user(self, user_id: int, amount: Decimal, reason: str = "manual_credit"):
        try:
            user = self.db.query(User).filter(User.id == user_id).first()
            if not user:
                raise ValueError("Пользователь не найден")

            transaction = WalletTransaction(user_id=user_id, amount=amount, type="credit", reason=reason)
            self.db.add(transaction)

            user.balance += amount
            self.db.commit()
        except Exception:
            self.db.rollback()
            raise
