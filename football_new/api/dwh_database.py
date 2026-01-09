# api/dwh_database.py
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from api.core.config import settings
import logging

logger = logging.getLogger(__name__)

# Use dedicated DWH URL when provided, otherwise fall back to primary DB URL.
dwh_database_url = getattr(settings, 'DWH_DATABASE_URL', None) or settings.DATABASE_URL
dwh_engine = create_engine(dwh_database_url)
DWH_SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=dwh_engine)

def get_dwh_db():
    db = DWH_SessionLocal()
    try:
        yield db
    finally:
        db.close()

def create_dwh_users_table():
    """Создает/мигрирует таблицу users (для Postgres)."""
    try:
        with dwh_engine.connect() as conn:
            conn.execute(text("""
                CREATE TABLE IF NOT EXISTS football.users
            (
                id integer NOT NULL DEFAULT nextval('football.users_id_seq'::regclass),
                email character varying(255) COLLATE pg_catalog."default" NOT NULL,
                username character varying(100) COLLATE pg_catalog."default" NOT NULL,
                full_name character varying(255) COLLATE pg_catalog."default",
                hashed_password character varying(255) COLLATE pg_catalog."default" NOT NULL,
                is_active boolean DEFAULT true,
                is_verified boolean DEFAULT false,
                created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,


                updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
                reset_password_token timestamp without time zone,
                reset_password_expires timestamp without time zone,
                verification_token character varying(255) COLLATE pg_catalog."default",
                verification_token_expires timestamp without time zone,
                CONSTRAINT users_pkey PRIMARY KEY (id),
                CONSTRAINT users_email_key UNIQUE (email),
                CONSTRAINT users_username_key UNIQUE (username),
                CONSTRAINT users_verification_token_key UNIQUE (verification_token)
            )
            """))
            # лёгкие idempotent-апдейты
            conn.execute(text("""
                DO $$
                BEGIN
                    IF NOT EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = 'football' AND table_name = 'users' AND column_name = 'verification_token'
                    ) THEN
                        ALTER TABLE football.users ADD COLUMN verification_token VARCHAR(255) UNIQUE;
                    END IF;

                    IF NOT EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = 'football' AND table_name = 'users' AND column_name = 'verification_token_expires'
                    ) THEN
                        ALTER TABLE football.users ADD COLUMN verification_token_expires TIMESTAMP;
                    END IF;

                    IF NOT EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = 'football' AND table_name = 'users' AND column_name = 'reset_password_token'
                    ) THEN
                        ALTER TABLE football.users ADD COLUMN reset_password_token VARCHAR(255) UNIQUE;
                    END IF;

                    IF NOT EXISTS (
                        SELECT 1 FROM information_schema.columns 
                        WHERE table_schema = 'football' AND table_name = 'users' AND column_name = 'reset_password_expires'
                    ) THEN
                        ALTER TABLE football.users ADD COLUMN reset_password_expires TIMESTAMP;
                    END IF;
                END $$;
            """))
            conn.commit()
            logger.info("✅ DWH 'users' table ready")
    except Exception as e:
        logger.error(f"❌ DWH users table init error: {e}")
        raise

# ===== SAFE GETTERS: явные SELECT с фикс. порядком =====

def _row_to_user(row):
    """Преобразуем к простому объекту с нужными атрибутами."""
    class UserObj:
        pass
    u = UserObj()
    # порядок соответствует SELECT ниже
    u.id = row[0]
    u.email = row[1]
    u.username = row[2]
    u.hashed_password = row[3]
    u.is_verified = row[4]
    u.verification_token = row[5]
    u.verification_token_expires = row[6]
    u.created_at = row[7]
    u.updated_at = row[8]
    return u

def get_user_by_email(email: str):
    try:
        with dwh_engine.connect() as conn:
            row = conn.execute(text("""
                SELECT 
                    id,
                    email,
                    username,
                    hashed_password,
                    is_verified,
                    COALESCE(verification_token, '') AS verification_token,
                    verification_token_expires,
                    created_at,
                    updated_at
                FROM football.users
                WHERE email = :email
                LIMIT 1
            """), {"email": email}).fetchone()
            return _row_to_user(row) if row else None
    except Exception as e:
        logger.error(f"❌ get_user_by_email error: {e}")
        return None

def get_user_by_username(username: str):
    try:
        with dwh_engine.connect() as conn:
            row = conn.execute(text("""
                SELECT 
                    id,
                    email,
                    username,
                    hashed_password,
                    is_verified,
                    COALESCE(verification_token, '') AS verification_token,
                    verification_token_expires,
                    created_at,
                    updated_at
                FROM football.users
                WHERE username = :username
                LIMIT 1
            """), {"username": username}).fetchone()
            return _row_to_user(row) if row else None
    except Exception as e:
        logger.error(f"❌ get_user_by_username error: {e}")
        return None

def create_user_in_dwh(user_data: dict):
    try:
        with dwh_engine.connect() as conn:
            res = conn.execute(text("""
                INSERT INTO football.users (
                    email, username, hashed_password, is_verified, 
                    verification_token, verification_token_expires, 
                    created_at, updated_at
                )
                VALUES (
                    :email, :username, :hashed_password, :is_verified, 
                    :verification_token, :verification_token_expires, 
                    CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                )
                RETURNING id
            """), user_data)
            user_id = res.fetchone()[0]
            conn.commit()
            logger.info(f"✅ DWH user created id={user_id}")
            return user_id
    except Exception as e:
        logger.error(f"❌ create_user_in_dwh error: {e}")
        raise

def update_user_verification_in_dwh(email: str, is_verified: bool = True):
    try:
        with dwh_engine.connect() as conn:
            conn.execute(text("""
                UPDATE football.users
                SET is_verified = :is_verified,
                    verification_token = NULL,
                    verification_token_expires = NULL,
                    updated_at = CURRENT_TIMESTAMP
                WHERE email = :email
            """), {"email": email, "is_verified": is_verified})
            conn.commit()
            return True
    except Exception as e:
        logger.error(f"❌ update_user_verification_in_dwh error: {e}")
        return False

def update_user_verification_token_in_dwh(email: str, verification_token: str, verification_expires):
    try:
        with dwh_engine.connect() as conn:
            conn.execute(text("""
                UPDATE football.users
                SET verification_token = :verification_token,
                    verification_token_expires = :verification_expires,
                    updated_at = CURRENT_TIMESTAMP
                WHERE email = :email
            """), {
                "email": email,
                "verification_token": verification_token,
                "verification_expires": verification_expires
            })
            conn.commit()
            return True
    except Exception as e:
        logger.error(f"❌ update_user_verification_token_in_dwh error: {e}")
        return False

def update_user_reset_password_token_in_dwh(email: str, reset_token: str, reset_expires):
    try:
        with dwh_engine.connect() as conn:
            conn.execute(text("""
                UPDATE football.users
                SET reset_password_token = :reset_token,
                    reset_password_expires = :reset_expires,
                    updated_at = CURRENT_TIMESTAMP
                WHERE email = :email
            """), {
                "email": email,
                "reset_token": reset_token,
                "reset_expires": reset_expires
            })
            conn.commit()
            return True
    except Exception as e:
        logger.error(f"❌ update_user_reset_password_token_in_dwh error: {e}")
        return False

def get_user_by_verification_token(token: str):
    try:
        with dwh_engine.connect() as conn:
            row = conn.execute(text("""
                SELECT 
                    id,
                    email,
                    username,
                    hashed_password,
                    is_verified,
                    COALESCE(verification_token, '') AS verification_token,
                    verification_token_expires,
                    created_at,
                    updated_at
                FROM football.users
                WHERE verification_token = :token
                  AND verification_token_expires > CURRENT_TIMESTAMP
                LIMIT 1
            """), {"token": token}).fetchone()
            return _row_to_user(row) if row else None
    except Exception as e:
        logger.error(f"❌ get_user_by_verification_token error: {e}")
        return None

def get_user_by_reset_token(token: str):
    """Исправлено имя колонки: reset_password_expires."""
    try:
        with dwh_engine.connect() as conn:
            row = conn.execute(text("""
                SELECT 
                    id,
                    email,
                    username,
                    hashed_password,
                    is_verified,
                    COALESCE(verification_token, '') AS verification_token,
                    verification_token_expires,
                    created_at,
                    updated_at
                FROM football.users
                WHERE reset_password_token = :token
                  AND reset_password_expires > CURRENT_TIMESTAMP
                LIMIT 1
            """), {"token": token}).fetchone()
            return _row_to_user(row) if row else None
    except Exception as e:
        logger.error(f"❌ get_user_by_reset_token error: {e}")
        return None

def update_user_password_in_dwh(email: str, new_hashed_password: str):
    try:
        with dwh_engine.connect() as conn:
            conn.execute(text("""
                UPDATE football.users
                SET hashed_password = :hashed_password,
                    reset_password_token = NULL,
                    reset_password_expires = NULL,
                    updated_at = CURRENT_TIMESTAMP
                WHERE email = :email
            """), {
                "email": email,
                "hashed_password": new_hashed_password
            })
            conn.commit()
            return True
    except Exception as e:
        logger.error(f"❌ update_user_password_in_dwh error: {e}")
        return False
