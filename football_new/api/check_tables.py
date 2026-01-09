#!/usr/bin/env python3
"""
Проверка создания таблиц для подписок
"""
import os
import sys
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from sqlalchemy import create_engine, text
from api.core.config import settings

# Подключение к базе данных
engine = create_engine(settings.DATABASE_URL)

def check_tables():
    """Проверяем, существуют ли таблицы для подписок"""
    try:
        with engine.connect() as conn:
            # Проверяем, есть ли схема football
            result = conn.execute(text("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name = 'football'
            """))
            schemas = result.fetchall()
            print(f"Схемы: {[s[0] for s in schemas]}")
            
            if not schemas:
                print("❌ Схема 'football' не найдена!")
                return False
            
            # Проверяем таблицы в схеме football
            result = conn.execute(text("""
                SELECT table_name 
                FROM information_schema.tables 
                WHERE table_schema = 'football'
                ORDER BY table_name
            """))
            tables = result.fetchall()
            print(f"Таблицы в схеме football: {[t[0] for t in tables]}")
            
            # Проверяем конкретно таблицы подписок
            subscription_tables = [t[0] for t in tables if 'subscription' in t[0]]
            print(f"Таблицы подписок: {subscription_tables}")
            
            if not subscription_tables:
                print("❌ Таблицы подписок не найдены!")
                return False
                
            return True
            
    except Exception as e:
        print(f"❌ Ошибка при проверке таблиц: {e}")
        return False

def create_tables_manually():
    """Создаем таблицы вручную"""
    try:
        with engine.connect() as conn:
            # Создаем схему football если её нет
            conn.execute(text("CREATE SCHEMA IF NOT EXISTS football"))
            conn.commit()
            
            # Создаем таблицу subscription_plans
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS football.subscription_plans (
                    id SERIAL PRIMARY KEY,
                    code VARCHAR(50) UNIQUE NOT NULL,
                    name VARCHAR(100) NOT NULL,
                    description TEXT,
                    price NUMERIC(14,2) NOT NULL DEFAULT 0.00,
                    duration_days INTEGER NOT NULL DEFAULT 30,
                    limit_reports_per_month INTEGER NOT NULL DEFAULT 10,
                    limit_alerts_per_day INTEGER NOT NULL DEFAULT 5,
                    is_active BOOLEAN NOT NULL DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            # Создаем таблицу user_subscriptions
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS football.user_subscriptions (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    plan_id INTEGER NOT NULL,
                    status VARCHAR(20) NOT NULL DEFAULT 'active',
                    start_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    end_date TIMESTAMP,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            # Создаем таблицу wallet_transactions
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS football.wallet_transactions (
                    id SERIAL PRIMARY KEY,
                    user_id INTEGER NOT NULL,
                    amount NUMERIC(14,2) NOT NULL,
                    transaction_type VARCHAR(20) NOT NULL,
                    description TEXT,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                )
            """))
            
            conn.commit()
            print("✅ Таблицы созданы успешно!")
            return True
            
    except Exception as e:
        print(f"❌ Ошибка при создании таблиц: {e}")
        return False

def seed_plans():
    """Заполняем таблицу планов тестовыми данными"""
    try:
        with engine.connect() as conn:
            # Проверяем, есть ли уже планы
            result = conn.execute(text("SELECT COUNT(*) FROM football.subscription_plans"))
            count = result.scalar()
            
            if count > 0:
                print(f"✅ Планы уже существуют ({count} записей)")
                return True
            
            # Добавляем тестовые планы
            conn.execute(text("""
                INSERT INTO football.subscription_plans 
                (code, name, description, price, duration_days, limit_reports_per_month, limit_alerts_per_day, is_active, created_at, updated_at)
                VALUES 
                ('FREE', 'Бесплатный', 'Базовый доступ к данным', 0, 30, 10, 3, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('START', 'Старт', 'Для знакомства с расширенными возможностями', 199, 30, 30, 10, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('PRO', 'Pro', 'Для продвинутых пользователей', 499, 30, 100, 50, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP),
                ('ENTERPRISE', 'Enterprise', 'Для корпоративных клиентов', 999, 30, 1000, 200, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
            """))
            
            conn.commit()
            print("✅ Планы добавлены успешно!")
            return True
            
    except Exception as e:
        print(f"❌ Ошибка при добавлении планов: {e}")
        return False

if __name__ == "__main__":
    print("🔍 Проверяем таблицы подписок...")
    
    if not check_tables():
        print("🔧 Создаем таблицы вручную...")
        if create_tables_manually():
            print("🌱 Заполняем планы...")
            seed_plans()
        else:
            print("❌ Не удалось создать таблицы")
            sys.exit(1)
    else:
        print("✅ Таблицы уже существуют")
        seed_plans()
    
    print("🎉 Готово!")
