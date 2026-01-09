import os
from datetime import datetime, timezone

from sqlalchemy import create_engine, text
from passlib.context import CryptContext


DB_URL = os.getenv("DWH_DATABASE_URL") or os.getenv("DATABASE_URL") or "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"


def main():
    email = os.getenv("TEST_USER_EMAIL", "test_user@example.com")
    username = os.getenv("TEST_USER_NAME", "test_user")
    plain_password = os.getenv("TEST_USER_PASSWORD", "TestPassw0rd!")
    # Сгенерируем хеш совместимо с приложением
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    hashed_password = pwd_context.hash(plain_password)
    is_verified = True

    engine = create_engine(DB_URL)
    with engine.begin() as conn:
        # убедимся, что schema есть
        conn.execute(text("CREATE SCHEMA IF NOT EXISTS football"))

        # создадим таблицу, если её нет (в точном соответствии с DWH)
        conn.execute(text(
            """
            CREATE TABLE IF NOT EXISTS football.users (
                id SERIAL PRIMARY KEY,
                email VARCHAR(255) UNIQUE NOT NULL,
                username VARCHAR(100) UNIQUE NOT NULL,
                full_name VARCHAR(255),
                hashed_password VARCHAR(255) NOT NULL,
                is_active BOOLEAN DEFAULT TRUE,
                is_verified BOOLEAN DEFAULT FALSE,
                verification_token VARCHAR(255) UNIQUE,
                verification_token_expires TIMESTAMP,
                reset_password_token VARCHAR(255) UNIQUE,
                reset_password_expires TIMESTAMP,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """
        ))

        # upsert по email/username
        row = conn.execute(text("SELECT id FROM football.users WHERE email=:e OR username=:u LIMIT 1"), {"e": email, "u": username}).fetchone()
        if row:
            user_id = row[0]
            conn.execute(text(
                """
                UPDATE football.users
                SET hashed_password=:hp, is_verified=:v, updated_at=CURRENT_TIMESTAMP
                WHERE id=:id
                """
            ), {"hp": hashed_password, "v": is_verified, "id": user_id})
            print(f"Updated existing user id={user_id}")
        else:
            user_id = conn.execute(text(
                """
                INSERT INTO football.users (
                    email, username, hashed_password, is_verified, created_at, updated_at
                ) VALUES (
                    :e, :u, :hp, :v, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
                ) RETURNING id
                """
            ), {"e": email, "u": username, "hp": hashed_password, "v": is_verified}).scalar()
            print(f"Created user id={user_id}")

        print("Login credentials:")
        print(f"  email: {email}")
        print(f"  password: {plain_password}")


if __name__ == "__main__":
    main()


