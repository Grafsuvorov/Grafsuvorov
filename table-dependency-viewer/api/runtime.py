"""Shared database engines used by API routers and services."""

from sqlalchemy import create_engine

from .config import DATABASE_URL, DBT_LOGS_DATABASE_URL, DEV_DATABASE_URL


def _engine(url: str):
    if not url:
        raise RuntimeError("DATABASE_URL is not configured")
    return create_engine(url, pool_pre_ping=True, pool_recycle=1800)


engine = _engine(DATABASE_URL)
dbt_logs_engine = (
    create_engine(DBT_LOGS_DATABASE_URL, pool_pre_ping=True, pool_recycle=1800)
    if DBT_LOGS_DATABASE_URL
    else None
)
dev_engine = (
    create_engine(DEV_DATABASE_URL, pool_pre_ping=True, pool_recycle=1800)
    if DEV_DATABASE_URL
    else engine
)
