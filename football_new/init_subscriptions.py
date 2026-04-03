#!/usr/bin/env python3
"""
Скрипт для инициализации планов подписок
"""

import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from api.database import SessionLocal, create_tables
from api.models import SubscriptionPlan
from decimal import Decimal
import sqlite3

def init_subscription_plans():
    """Инициализирует планы подписок"""
    print("🚀 Инициализация планов подписок...")
    
    # Настраиваем SQLite для правильной работы с UTF-8
    sqlite3.register_adapter(str, lambda s: s.encode('utf-8') if s else None)
    
    db = SessionLocal()
    
    try:
        # Создаем таблицы
        create_tables()
        print("✅ Таблицы созданы")
        
        # Проверяем, есть ли уже планы
        existing_plans = db.query(SubscriptionPlan).all()
        if existing_plans:
            print(f"✅ Планы уже существуют: {len(existing_plans)}")
            for plan in existing_plans:
                print(f"   - {plan.name} ({plan.code}): {plan.price} ₽")
            return
        
        # Создаем планы подписок
        plans = [
            SubscriptionPlan(
                code="BASIC",
                name="Базовый план",
                description="Базовый план для начинающих пользователей",
                price=Decimal("0.00"),
                duration_days=30,
                limit_reports_per_month=10,
                limit_alerts_per_day=5,
                is_active=True
            ),
            SubscriptionPlan(
                code="PRO",
                name="Профессиональный план",
                description="Профессиональный план для активных пользователей",
                price=Decimal("0.00"),
                duration_days=30,
                limit_reports_per_month=30,
                limit_alerts_per_day=15,
                is_active=True
            ),
            SubscriptionPlan(
                code="ENTERPRISE",
                name="Корпоративный план",
                description="Корпоративный план для крупных организаций",
                price=Decimal("0.00"),
                duration_days=30,
                limit_reports_per_month=100,
                limit_alerts_per_day=50,
                is_active=True
            )
        ]
        
        # Добавляем планы в базу
        for plan in plans:
            db.add(plan)
        
        # Коммитим изменения
        db.commit()
        
        print("✅ Планы подписок созданы:")
        for plan in plans:
            print(f"   - {plan.name} ({plan.code}): {plan.price} ₽")
        
        print("🎉 Инициализация завершена успешно!")
        
    except Exception as e:
        print(f"❌ Ошибка при инициализации: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    init_subscription_plans()
