from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from api.core.config import settings

# Никакого sqlite: если вдруг кто-то подложит, — сразу падаем
if settings.DATABASE_URL.lower().startswith("sqlite"):
    raise RuntimeError(
        f"[DB] You passed a SQLite URL ('{settings.DATABASE_URL}'), "
        f"but the app requires PostgreSQL. Fix DATABASE_URL."
    )

# Для PostgreSQL не нужны спец connect_args
engine = create_engine(settings.DATABASE_URL, pool_pre_ping=True)

# Проверим диалект прямо сейчас
if engine.dialect.name != "postgresql":
    raise RuntimeError(f"[DB] Unexpected SQLAlchemy dialect: {engine.dialect.name}. "
                       f"Check DATABASE_URL: {settings.DATABASE_URL}")

print(f"[DB] Using engine: {engine.url!s}")

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_tables():
    """
    Регистрируем ВСЕ модели и создаём таблицы. Сиды — необязательны.
    """
    import api.models  # noqa: F401  (важно: чтобы Base «увидел» модели)
    from api.models import Base

    # создаём отсутствующие таблицы
    Base.metadata.create_all(bind=engine)

    # Необязательные сиды тарифов
    try:
        from sqlalchemy.orm import Session
        from api.models import SubscriptionPlan

        with SessionLocal() as db:  # type: Session
            has_any = db.query(SubscriptionPlan).count() > 0
            if not has_any:
                plans = [
                    SubscriptionPlan(
                        code="FREE",
                        name="Бесплатный",
                        description="Базовый доступ к данным",
                        price=0,
                        duration_days=30,
                        limit_reports_per_month=10,
                        limit_alerts_per_day=3,
                        is_active=True,
                    ),
                    SubscriptionPlan(
                        code="START",
                        name="Старт",
                        description="Для знакомства с расширенными возможностями",
                        price=199,
                        duration_days=30,
                        limit_reports_per_month=30,
                        limit_alerts_per_day=10,
                        is_active=True,
                    ),
                    SubscriptionPlan(
                        code="PRO",
                        name="Pro",
                        description="Для продвинутых пользователей",
                        price=499,
                        duration_days=30,
                        limit_reports_per_month=100,
                        limit_alerts_per_day=30,
                        is_active=True,
                    ),
                    SubscriptionPlan(
                        code="ELITE",
                        name="Elite",
                        description="Максимум возможностей для профи",
                        price=1299,
                        duration_days=30,
                        limit_reports_per_month=500,
                        limit_alerts_per_day=100,
                        is_active=True,
                    ),
                ]
                db.add_all(plans)
                db.commit()
                print("[DB] Seeded default subscription plans: FREE/START/PRO/ELITE")
            else:
                print("[DB] subscription_plans already seeded; skip.")
    except Exception as e:
        print(f"[DB] Seed plans skipped due to error: {e}")
