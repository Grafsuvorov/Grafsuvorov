
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
import base64
import hashlib
import hmac
import json
import secrets
from typing import Any, Dict, Optional

from fastapi import APIRouter, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from sqlalchemy import text

from .config import (
    AUTH_ACCESS_TTL_MIN,
    AUTH_ALLOW_REGISTER,
    AUTH_BOOTSTRAP_ADMIN_EMAIL,
    AUTH_BOOTSTRAP_ADMIN_PASSWORD,
    AUTH_ENABLED,
    AUTH_SECRET_KEY,
    DATABASE_URL,
)
from sqlalchemy import create_engine


AUTH_ENABLED = str(AUTH_ENABLED).lower() == "true"
AUTH_ALLOW_REGISTER = str(AUTH_ALLOW_REGISTER).lower() == "true"

ALLOWED_ROLES = {"analyst", "engineer", "admin"}

engine = create_engine(DATABASE_URL)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    email: str
    username: str


class UserRegister(BaseModel):
    email: str
    username: str
    password: str
    role: str = "analyst"


class UserLogin(BaseModel):
    email: str
    password: str


class UserCreate(BaseModel):
    email: str
    username: str
    password: str
    role: str


class UserUpdate(BaseModel):
    role: str


class ChangePassword(BaseModel):
    current_password: str
    new_password: str


class UserMe(BaseModel):
    email: str
    username: str
    role: str


class UserListItem(BaseModel):
    id: int
    email: str
    username: str
    role: str
    is_active: bool


class UserActionResponse(BaseModel):
    status: str


class AuditEventPayload(BaseModel):
    event_type: str
    page: Optional[str] = None
    object_type: Optional[str] = None
    object_id: Optional[str] = None
    object_name: Optional[str] = None
    details: Optional[Dict[str, Any]] = None


class FavoriteTablePayload(BaseModel):
    table_id: int
    table_schema: Optional[str] = None
    table_name: Optional[str] = None
    entity_name: Optional[str] = None


class FavoriteEntityPayload(BaseModel):
    entity_id: int
    entity_name: Optional[str] = None


@dataclass
class AuthUser:
    id: int
    email: str
    username: str
    role: str
    password_hash: str
    password_salt: str
    is_active: bool


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("utf-8")


def _b64url_decode(data: str) -> bytes:
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(data + padding)


def _jwt_encode(payload: Dict[str, Any]) -> str:
    header = {"alg": "HS256", "typ": "JWT"}
    header_b64 = _b64url_encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    payload_b64 = _b64url_encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    signature = hmac.new(AUTH_SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
    signature_b64 = _b64url_encode(signature)
    return f"{header_b64}.{payload_b64}.{signature_b64}"


def _jwt_decode(token: str) -> Dict[str, Any]:
    parts = token.split(".")
    if len(parts) != 3:
        raise ValueError("invalid token")
    header_b64, payload_b64, signature_b64 = parts
    signing_input = f"{header_b64}.{payload_b64}".encode("utf-8")
    expected_sig = hmac.new(AUTH_SECRET_KEY.encode("utf-8"), signing_input, hashlib.sha256).digest()
    if not hmac.compare_digest(expected_sig, _b64url_decode(signature_b64)):
        raise ValueError("invalid signature")
    payload = json.loads(_b64url_decode(payload_b64).decode("utf-8"))
    if "exp" in payload and datetime.now(timezone.utc).timestamp() > payload["exp"]:
        raise ValueError("token expired")
    return payload


def _hash_password(password: str, salt: Optional[str] = None) -> Dict[str, str]:
    if salt is None:
        salt = secrets.token_hex(16)
    pwd = password.encode("utf-8")
    dk = hashlib.pbkdf2_hmac("sha256", pwd, salt.encode("utf-8"), 200_000)
    return {"hash": dk.hex(), "salt": salt}


def _verify_password(password: str, password_hash: str, salt: str) -> bool:
    calc = _hash_password(password, salt)["hash"]
    return hmac.compare_digest(calc, password_hash)


def _create_access_token(email: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(minutes=AUTH_ACCESS_TTL_MIN)
    payload = {
        "sub": email,
        "role": role,
        "exp": int(expire.timestamp()),
        "token_type": "access",
    }
    return _jwt_encode(payload)


def _get_user_by_email(email: str) -> Optional[AuthUser]:
    with engine.connect() as conn:
        row = conn.execute(
            text(
                """
                SELECT id, email, username, role, password_hash, password_salt, is_active
                FROM tech_etl.app_users
                WHERE email = :email
                """
            ),
            {"email": email},
        ).fetchone()
    if not row:
        return None
    return AuthUser(
        id=row[0],
        email=row[1],
        username=row[2],
        role=row[3],
        password_hash=row[4],
        password_salt=row[5],
        is_active=row[6],
    )


def _create_user(email: str, username: str, password: str, role: str) -> AuthUser:
    hashed = _hash_password(password)
    with engine.begin() as conn:
        row = conn.execute(
            text(
                """
                INSERT INTO tech_etl.app_users (email, username, role, password_hash, password_salt, is_active)
                VALUES (:email, :username, :role, :password_hash, :password_salt, true)
                RETURNING id, email, username, role, password_hash, password_salt, is_active
                """
            ),
            {
                "email": email,
                "username": username,
                "role": role,
                "password_hash": hashed["hash"],
                "password_salt": hashed["salt"],
            },
        ).fetchone()
    return AuthUser(
        id=row[0],
        email=row[1],
        username=row[2],
        role=row[3],
        password_hash=row[4],
        password_salt=row[5],
        is_active=row[6],
    )


def _update_user_password(user_id: int, new_password: str) -> None:
    hashed = _hash_password(new_password)
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE tech_etl.app_users
                SET password_hash = :password_hash,
                    password_salt = :password_salt
                WHERE id = :user_id
                """
            ),
            {
                "password_hash": hashed["hash"],
                "password_salt": hashed["salt"],
                "user_id": user_id,
            },
        )


def _set_user_active(user_id: int, is_active: bool) -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE tech_etl.app_users
                SET is_active = :is_active
                WHERE id = :user_id
                """
            ),
            {"user_id": user_id, "is_active": is_active},
        )


def _set_user_role(user_id: int, role: str) -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                UPDATE tech_etl.app_users
                SET role = :role
                WHERE id = :user_id
                """
            ),
            {"user_id": user_id, "role": role},
        )


def _delete_user(user_id: int) -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_users
                WHERE id = :user_id
                """
            ),
            {"user_id": user_id},
        )


def _ensure_users_table() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS tech_etl.app_users (
                    id SERIAL PRIMARY KEY,
                    email TEXT UNIQUE NOT NULL,
                    username TEXT UNIQUE NOT NULL,
                    role TEXT NOT NULL,
                    password_hash TEXT NOT NULL,
                    password_salt TEXT NOT NULL,
                    is_active BOOLEAN NOT NULL DEFAULT TRUE,
                    created_at TIMESTAMP NOT NULL DEFAULT NOW()
                )
                """
            )
        )


def _ensure_audit_table() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE SEQUENCE IF NOT EXISTS tech_etl.app_user_event_id_seq
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS tech_etl.app_user_event (
                    id serial NOT NULL ,
                    ts TIMESTAMP NOT NULL DEFAULT NOW(),
                    user_email TEXT,
                    user_role TEXT,
                    event_type TEXT NOT NULL,
                    status TEXT,
                    page TEXT,
                    object_type TEXT,
                    object_id TEXT,
                    object_name TEXT,
                    details JSON,
                    ip TEXT,
                    user_agent TEXT
                )
                DISTRIBUTED BY (id)
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE INDEX IF NOT EXISTS idx_app_user_event_ts
                ON tech_etl.app_user_event (ts)
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE INDEX IF NOT EXISTS idx_app_user_event_email_ts
                ON tech_etl.app_user_event (user_email, ts DESC)
                """
            )
        )
        pk_exists = conn.execute(
            text(
                """
                SELECT 1
                FROM pg_constraint
                WHERE conname = 'app_user_event_pk'
                LIMIT 1
                """
            )
        ).scalar()
        if not pk_exists:
            conn.execute(
                text(
                    """
                    ALTER TABLE tech_etl.app_user_event
                    ADD CONSTRAINT app_user_event_pk PRIMARY KEY (id)
                    """
                )
            )


def _ensure_favorites_table() -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                CREATE SEQUENCE IF NOT EXISTS tech_etl.app_user_favorite_id_seq
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE TABLE IF NOT EXISTS tech_etl.app_user_favorite (
                    id BIGINT NOT NULL DEFAULT nextval('tech_etl.app_user_favorite_id_seq'),
                    user_email TEXT NOT NULL,
                    object_type TEXT NOT NULL,
                    object_id BIGINT NOT NULL,
                    object_name TEXT,
                    created_at TIMESTAMP NOT NULL DEFAULT NOW()
                )
                DISTRIBUTED BY (id)
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE INDEX IF NOT EXISTS idx_app_user_favorite_user_type
                ON tech_etl.app_user_favorite (user_email, object_type)
                """
            )
        )
        conn.execute(
            text(
                """
                CREATE INDEX IF NOT EXISTS idx_app_user_favorite_object
                ON tech_etl.app_user_favorite (object_type, object_id)
                """
            )
        )


def _list_favorite_tables(user_email: str) -> list[dict[str, Any]]:
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT
                    f.object_id AS table_id,
                    COALESCE(t.table_schema, split_part(f.object_name, '.', 1)) AS table_schema,
                    COALESCE(t.table_name, split_part(f.object_name, '.', 2)) AS table_name,
                    t.entity_id,
                    t.entity_name,
                    t.table_last_load,
                    f.created_at
                FROM tech_etl.app_user_favorite f
                LEFT JOIN tech_etl.tables_meta t
                  ON t.table_id = f.object_id
                WHERE f.user_email = :user_email
                  AND f.object_type = 'table'
                ORDER BY f.created_at DESC
                """
            ),
            {"user_email": user_email},
        ).mappings().all()

    result = []
    seen = set()
    for row in rows:
        table_id = row.get("table_id")
        if table_id in seen:
            continue
        seen.add(table_id)
        item = dict(row)
        if item.get("table_last_load"):
            item["table_last_load"] = item["table_last_load"].strftime("%Y-%m-%d %H:%M:%S")
        if item.get("created_at"):
            item["created_at"] = item["created_at"].strftime("%Y-%m-%d %H:%M:%S")
        result.append(item)
    return result


def _is_favorite_table(user_email: str, table_id: int) -> bool:
    with engine.connect() as conn:
        exists = conn.execute(
            text(
                """
                SELECT 1
                FROM tech_etl.app_user_favorite
                WHERE user_email = :user_email
                  AND object_type = 'table'
                  AND object_id = :table_id
                LIMIT 1
                """
            ),
            {"user_email": user_email, "table_id": table_id},
        ).scalar()
    return bool(exists)


def _list_favorite_entities(user_email: str) -> list[dict[str, Any]]:
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT
                    f.object_id AS entity_id,
                    COALESCE(e.entity_name, f.object_name) AS entity_name,
                    e.entity_last_load,
                    e.entity_load_status,
                    f.created_at
                FROM tech_etl.app_user_favorite f
                LEFT JOIN tech_etl.entities_meta e
                  ON e.entity_id = f.object_id
                WHERE f.user_email = :user_email
                  AND f.object_type = 'entity'
                ORDER BY f.created_at DESC
                """
            ),
            {"user_email": user_email},
        ).mappings().all()

    result = []
    seen = set()
    for row in rows:
        entity_id = row.get("entity_id")
        if entity_id in seen:
            continue
        seen.add(entity_id)
        item = dict(row)
        if item.get("entity_last_load"):
            item["entity_last_load"] = item["entity_last_load"].strftime("%Y-%m-%d %H:%M:%S")
        if item.get("created_at"):
            item["created_at"] = item["created_at"].strftime("%Y-%m-%d %H:%M:%S")
        result.append(item)
    return result


def _is_favorite_entity(user_email: str, entity_id: int) -> bool:
    with engine.connect() as conn:
        exists = conn.execute(
            text(
                """
                SELECT 1
                FROM tech_etl.app_user_favorite
                WHERE user_email = :user_email
                  AND object_type = 'entity'
                  AND object_id = :entity_id
                LIMIT 1
                """
            ),
            {"user_email": user_email, "entity_id": entity_id},
        ).scalar()
    return bool(exists)


def _add_favorite_table(user_email: str, payload: FavoriteTablePayload) -> None:
    object_name = (
        f"{payload.table_schema}.{payload.table_name}"
        if payload.table_schema and payload.table_name
        else str(payload.table_id)
    )
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_user_favorite
                WHERE user_email = :user_email
                  AND object_type = 'table'
                  AND object_id = :table_id
                """
            ),
            {"user_email": user_email, "table_id": payload.table_id},
        )
        conn.execute(
            text(
                """
                INSERT INTO tech_etl.app_user_favorite (
                    user_email,
                    object_type,
                    object_id,
                    object_name
                )
                VALUES (
                    :user_email,
                    'table',
                    :table_id,
                    :object_name
                )
                """
            ),
            {
                "user_email": user_email,
                "table_id": payload.table_id,
                "object_name": object_name,
            },
        )


def _remove_favorite_table(user_email: str, table_id: int) -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_user_favorite
                WHERE user_email = :user_email
                  AND object_type = 'table'
                  AND object_id = :table_id
                """
            ),
            {"user_email": user_email, "table_id": table_id},
        )


def _add_favorite_entity(user_email: str, payload: FavoriteEntityPayload) -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_user_favorite
                WHERE user_email = :user_email
                  AND object_type = 'entity'
                  AND object_id = :entity_id
                """
            ),
            {"user_email": user_email, "entity_id": payload.entity_id},
        )
        conn.execute(
            text(
                """
                INSERT INTO tech_etl.app_user_favorite (
                    user_email,
                    object_type,
                    object_id,
                    object_name
                )
                VALUES (
                    :user_email,
                    'entity',
                    :entity_id,
                    :object_name
                )
                """
            ),
            {
                "user_email": user_email,
                "entity_id": payload.entity_id,
                "object_name": payload.entity_name or str(payload.entity_id),
            },
        )


def _remove_favorite_entity(user_email: str, entity_id: int) -> None:
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                DELETE FROM tech_etl.app_user_favorite
                WHERE user_email = :user_email
                  AND object_type = 'entity'
                  AND object_id = :entity_id
                """
            ),
            {"user_email": user_email, "entity_id": entity_id},
        )


def _request_ip(request: Optional[Request]) -> Optional[str]:
    if not request:
        return None
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    client = getattr(request, "client", None)
    return getattr(client, "host", None)


def _request_user_agent(request: Optional[Request]) -> Optional[str]:
    if not request:
        return None
    return request.headers.get("User-Agent")


def _write_audit_event(
    *,
    event_type: str,
    request: Optional[Request] = None,
    user: Optional[AuthUser] = None,
    user_email: Optional[str] = None,
    user_role: Optional[str] = None,
    status_value: Optional[str] = None,
    page: Optional[str] = None,
    object_type: Optional[str] = None,
    object_id: Optional[str] = None,
    object_name: Optional[str] = None,
    details: Optional[Dict[str, Any]] = None,
) -> None:
    try:
        with engine.begin() as conn:
            conn.execute(
                text(
                    """
                    DELETE FROM tech_etl.app_user_event
                    WHERE ts < (NOW() - INTERVAL '30 days')
                    """
                )
            )
            conn.execute(
                text(
                    """
                    INSERT INTO tech_etl.app_user_event (
                        user_email,
                        user_role,
                        event_type,
                        status,
                        page,
                        object_type,
                        object_id,
                        object_name,
                        details,
                        ip,
                        user_agent
                    )
                    VALUES (
                        :user_email,
                        :user_role,
                        :event_type,
                        :status,
                        :page,
                        :object_type,
                        :object_id,
                        :object_name,
                        CAST(:details AS JSON),
                        :ip,
                        :user_agent
                    )
                    """
                ),
                {
                    "user_email": user.email if user else user_email,
                    "user_role": user.role if user else user_role,
                    "event_type": event_type,
                    "status": status_value,
                    "page": page,
                    "object_type": object_type,
                    "object_id": object_id,
                    "object_name": object_name,
                    "details": json.dumps(details or {}),
                    "ip": _request_ip(request),
                    "user_agent": _request_user_agent(request),
                },
            )
    except Exception:
        # audit logging must not break app flows
        return


def _bootstrap_admin() -> None:
    if not AUTH_BOOTSTRAP_ADMIN_EMAIL or not AUTH_BOOTSTRAP_ADMIN_PASSWORD:
        return
    if _get_user_by_email(AUTH_BOOTSTRAP_ADMIN_EMAIL):
        return
    _create_user(
        email=AUTH_BOOTSTRAP_ADMIN_EMAIL,
        username="admin",
        password=AUTH_BOOTSTRAP_ADMIN_PASSWORD,
        role="admin",
    )


def init_auth() -> None:
    if not AUTH_ENABLED:
        return
    _ensure_users_table()
    try:
        _ensure_audit_table()
    except Exception as exc:
        # Audit is optional; auth startup must not fail on Greenplum DDL quirks.
        print(f"AUTH AUDIT INIT WARNING: {exc}")
    try:
        _ensure_favorites_table()
    except Exception as exc:
        print(f"AUTH FAVORITES INIT WARNING: {exc}")
    _bootstrap_admin()


def get_current_user_from_request(request: Request) -> AuthUser:
    auth_header = request.headers.get("Authorization", "")
    if not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Authentication required")
    token = auth_header.split(" ", 1)[1].strip()
    try:
        payload = _jwt_decode(token)
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    if payload.get("token_type") not in (None, "access"):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = _get_user_by_email(email)
    if not user or not user.is_active:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not active")
    return user


async def auth_middleware(request: Request, call_next):
    if not AUTH_ENABLED:
        return await call_next(request)

    if request.method == "OPTIONS":
        return await call_next(request)

    path = request.url.path
    if path.startswith("/auth/") or path in {"/docs", "/openapi.json", "/api/health"}:
        return await call_next(request)

    try:
        user = get_current_user_from_request(request)
        request.state.user = user
    except HTTPException as exc:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.detail},
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Credentials": "true",
                "Access-Control-Allow-Methods": "*",
                "Access-Control-Allow-Headers": "*",
            },
        )

    return await call_next(request)


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=TokenResponse)
def register(payload: UserRegister, request: Request):
    if not AUTH_ALLOW_REGISTER:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    role = payload.role.lower()
    if role not in ALLOWED_ROLES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
    if _get_user_by_email(payload.email):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")
    user = _create_user(payload.email, payload.username, payload.password, role)
    token = _create_access_token(user.email, user.role)
    _write_audit_event(
        event_type="register_success",
        request=request,
        user=user,
        status_value="success",
        page="/auth/register",
    )
    return TokenResponse(access_token=token, role=user.role, email=user.email, username=user.username)


@router.post("/users", response_model=UserMe)
def create_user(payload: UserCreate, request: Request):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    role = payload.role.lower()
    if role not in ALLOWED_ROLES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
    if _get_user_by_email(payload.email):
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User already exists")
    user = _create_user(payload.email, payload.username, payload.password, role)
    _write_audit_event(
        event_type="admin_create_user",
        request=request,
        user=admin,
        status_value="success",
        page="/auth/users",
        object_type="user",
        object_id=str(user.id),
        object_name=user.email,
        details={"role": user.role},
    )
    return UserMe(email=user.email, username=user.username, role=user.role)


@router.get("/users", response_model=list[UserListItem])
def list_users(request: Request):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    with engine.connect() as conn:
        rows = conn.execute(
            text(
                """
                SELECT id, email, username, role, is_active
                FROM tech_etl.app_users
                ORDER BY created_at DESC
                """
            )
        ).fetchall()
    return [
        UserListItem(
            id=row[0],
            email=row[1],
            username=row[2],
            role=row[3],
            is_active=row[4],
        )
        for row in rows
    ]


@router.post("/users/{user_id}/disable", response_model=UserActionResponse)
def disable_user(user_id: int, request: Request):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    if admin.id == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Нельзя отключить себя")
    _set_user_active(user_id, False)
    _write_audit_event(
        event_type="admin_disable_user",
        request=request,
        user=admin,
        status_value="success",
        page="/auth/users",
        object_type="user",
        object_id=str(user_id),
    )
    return UserActionResponse(status="ok")


@router.post("/users/{user_id}/enable", response_model=UserActionResponse)
def enable_user(user_id: int, request: Request):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    _set_user_active(user_id, True)
    _write_audit_event(
        event_type="admin_enable_user",
        request=request,
        user=admin,
        status_value="success",
        page="/auth/users",
        object_type="user",
        object_id=str(user_id),
    )
    return UserActionResponse(status="ok")


@router.put("/users/{user_id}", response_model=UserActionResponse)
def update_user(user_id: int, payload: UserUpdate, request: Request):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    role = payload.role.lower()
    if role not in ALLOWED_ROLES:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid role")
    _set_user_role(user_id, role)
    _write_audit_event(
        event_type="admin_update_user_role",
        request=request,
        user=admin,
        status_value="success",
        page="/auth/users",
        object_type="user",
        object_id=str(user_id),
        details={"role": role},
    )
    return UserActionResponse(status="ok")


@router.delete("/users/{user_id}", response_model=UserActionResponse)
def delete_user(user_id: int, request: Request):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    if admin.id == user_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Нельзя удалить себя")
    _delete_user(user_id)
    _write_audit_event(
        event_type="admin_delete_user",
        request=request,
        user=admin,
        status_value="success",
        page="/auth/users",
        object_type="user",
        object_id=str(user_id),
    )
    return UserActionResponse(status="ok")


@router.post("/change-password")
def change_password(payload: ChangePassword, request: Request):
    user = get_current_user_from_request(request)
    if not _verify_password(payload.current_password, user.password_hash, user.password_salt):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Неверный текущий пароль")
    _update_user_password(user.id, payload.new_password)
    _write_audit_event(
        event_type="change_password",
        request=request,
        user=user,
        status_value="success",
        page="/auth/change-password",
    )
    return {"status": "ok"}


@router.post("/login", response_model=TokenResponse)
def login(payload: UserLogin, request: Request):
    user = _get_user_by_email(payload.email)
    if not user or not user.is_active:
        _write_audit_event(
            event_type="login",
            request=request,
            user_email=payload.email,
            status_value="failed",
            page="/auth/login",
        )
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    if not _verify_password(payload.password, user.password_hash, user.password_salt):
        _write_audit_event(
            event_type="login",
            request=request,
            user=user,
            status_value="failed",
            page="/auth/login",
        )
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    token = _create_access_token(user.email, user.role)
    _write_audit_event(
        event_type="login",
        request=request,
        user=user,
        status_value="success",
        page="/auth/login",
    )
    return TokenResponse(access_token=token, role=user.role, email=user.email, username=user.username)


@router.get("/me", response_model=UserMe)
def me(request: Request):
    user = get_current_user_from_request(request)
    return UserMe(email=user.email, username=user.username, role=user.role)


@router.post("/logout")
def logout(request: Request):
    user = get_current_user_from_request(request)
    _write_audit_event(
        event_type="logout",
        request=request,
        user=user,
        status_value="success",
        page="/auth/logout",
    )
    return {"status": "ok"}


@router.post("/audit/event")
def write_audit_event(payload: AuditEventPayload, request: Request):
    user = get_current_user_from_request(request)
    _write_audit_event(
        event_type=payload.event_type,
        request=request,
        user=user,
        status_value="success",
        page=payload.page,
        object_type=payload.object_type,
        object_id=payload.object_id,
        object_name=payload.object_name,
        details=payload.details,
    )
    return {"status": "ok"}


@router.get("/favorites/tables")
def list_favorite_tables(request: Request):
    user = get_current_user_from_request(request)
    return {"items": _list_favorite_tables(user.email)}


@router.get("/favorites/entities")
def list_favorite_entities(request: Request):
    user = get_current_user_from_request(request)
    return {"items": _list_favorite_entities(user.email)}


@router.get("/favorites/tables/{table_id}")
def favorite_table_status(table_id: int, request: Request):
    user = get_current_user_from_request(request)
    return {"is_favorite": _is_favorite_table(user.email, table_id)}


@router.get("/favorites/entities/{entity_id}")
def favorite_entity_status(entity_id: int, request: Request):
    user = get_current_user_from_request(request)
    return {"is_favorite": _is_favorite_entity(user.email, entity_id)}


@router.post("/favorites/tables")
def add_favorite_table(payload: FavoriteTablePayload, request: Request):
    user = get_current_user_from_request(request)
    _add_favorite_table(user.email, payload)
    _write_audit_event(
        event_type="add_favorite_table",
        request=request,
        user=user,
        status_value="success",
        page="/auth/favorites/tables",
        object_type="table",
        object_id=str(payload.table_id),
        object_name=(
            f"{payload.table_schema}.{payload.table_name}"
            if payload.table_schema and payload.table_name
            else str(payload.table_id)
        ),
    )
    return {"status": "ok"}


@router.delete("/favorites/tables/{table_id}")
def remove_favorite_table(table_id: int, request: Request):
    user = get_current_user_from_request(request)
    _remove_favorite_table(user.email, table_id)
    _write_audit_event(
        event_type="remove_favorite_table",
        request=request,
        user=user,
        status_value="success",
        page="/auth/favorites/tables",
        object_type="table",
        object_id=str(table_id),
    )
    return {"status": "ok"}


@router.post("/favorites/entities")
def add_favorite_entity(payload: FavoriteEntityPayload, request: Request):
    user = get_current_user_from_request(request)
    _add_favorite_entity(user.email, payload)
    _write_audit_event(
        event_type="add_favorite_entity",
        request=request,
        user=user,
        status_value="success",
        page="/auth/favorites/entities",
        object_type="entity",
        object_id=str(payload.entity_id),
        object_name=payload.entity_name or str(payload.entity_id),
    )
    return {"status": "ok"}


@router.delete("/favorites/entities/{entity_id}")
def remove_favorite_entity(entity_id: int, request: Request):
    user = get_current_user_from_request(request)
    _remove_favorite_entity(user.email, entity_id)
    _write_audit_event(
        event_type="remove_favorite_entity",
        request=request,
        user=user,
        status_value="success",
        page="/auth/favorites/entities",
        object_type="entity",
        object_id=str(entity_id),
    )
    return {"status": "ok"}


@router.get("/users/analytics")
def users_analytics(request: Request, days: int = 30):
    admin = get_current_user_from_request(request)
    if admin.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")

    params = {"days": max(1, min(days, 90))}
    try:
        with engine.connect() as conn:
            totals = conn.execute(
                text(
                    """
                    SELECT
                        COUNT(*) AS events_count,
                        COUNT(DISTINCT user_email) AS users_count,
                        SUM(CASE WHEN event_type = 'login' AND status = 'success' THEN 1 ELSE 0 END) AS logins_count,
                        SUM(CASE WHEN event_type = 'login' AND status = 'failed' THEN 1 ELSE 0 END) AS failed_logins_count,
                        SUM(CASE WHEN event_type = 'page_view' THEN 1 ELSE 0 END) AS page_views_count,
                        SUM(CASE WHEN event_type <> 'page_view' THEN 1 ELSE 0 END) AS actions_count
                    FROM tech_etl.app_user_event
                    WHERE ts >= (NOW() - (:days || ' days')::interval)
                    """
                ),
                params,
            ).mappings().first()

            by_user = conn.execute(
                text(
                    """
                    SELECT
                        COALESCE(user_email, 'unknown') AS user_email,
                        MAX(user_role) AS user_role,
                        COUNT(*) AS events_count,
                        SUM(CASE WHEN event_type = 'login' AND status = 'success' THEN 1 ELSE 0 END) AS logins_count,
                        SUM(CASE WHEN event_type = 'page_view' THEN 1 ELSE 0 END) AS page_views_count,
                        SUM(CASE WHEN event_type <> 'page_view' THEN 1 ELSE 0 END) AS actions_count,
                        MAX(ts) AS last_activity_at
                    FROM tech_etl.app_user_event
                    WHERE ts >= (NOW() - (:days || ' days')::interval)
                    GROUP BY COALESCE(user_email, 'unknown')
                    ORDER BY events_count DESC, last_activity_at DESC
                    LIMIT 50
                    """
                ),
                params,
            ).mappings().all()

            top_pages = conn.execute(
                text(
                    """
                    SELECT page, COUNT(*) AS events_count
                    FROM tech_etl.app_user_event
                    WHERE ts >= (NOW() - (:days || ' days')::interval)
                      AND event_type = 'page_view'
                      AND page IS NOT NULL
                    GROUP BY page
                    ORDER BY events_count DESC, page
                    LIMIT 20
                    """
                ),
                params,
            ).mappings().all()

            top_actions = conn.execute(
                text(
                    """
                    SELECT event_type, COUNT(*) AS events_count
                    FROM tech_etl.app_user_event
                    WHERE ts >= (NOW() - (:days || ' days')::interval)
                      AND event_type <> 'page_view'
                    GROUP BY event_type
                    ORDER BY events_count DESC, event_type
                    LIMIT 20
                    """
                ),
                params,
            ).mappings().all()

            recent_events = conn.execute(
                text(
                    """
                    SELECT
                        ts,
                        user_email,
                        user_role,
                        event_type,
                        status,
                        page,
                        object_type,
                        object_name
                    FROM tech_etl.app_user_event
                    WHERE ts >= (NOW() - (:days || ' days')::interval)
                    ORDER BY ts DESC
                    LIMIT 100
                    """
                ),
                params,
            ).mappings().all()
    except Exception:
        return {
            "summary": {
                "events_count": 0,
                "users_count": 0,
                "logins_count": 0,
                "failed_logins_count": 0,
                "page_views_count": 0,
                "actions_count": 0,
            },
            "users": [],
            "pages": [],
            "actions": [],
            "recent": [],
            "days": params["days"],
        }

    return {
        "summary": dict(totals or {}),
        "users": [dict(row) for row in by_user],
        "pages": [dict(row) for row in top_pages],
        "actions": [dict(row) for row in top_actions],
        "recent": [dict(row) for row in recent_events],
        "days": params["days"],
    }
