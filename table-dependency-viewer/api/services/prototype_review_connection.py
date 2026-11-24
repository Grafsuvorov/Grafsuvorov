"""Read-only OHD connection diagnostics without logging credentials."""
import logging
import time
from urllib.parse import urlsplit, unquote, parse_qsl

from sqlalchemy import create_engine, text


logger = logging.getLogger("uvicorn.error")


def check_ohd_database_connection(database_url: str, *, source: str = "OHD") -> dict:
    database_url = str(database_url or "").strip()
    try:
        parsed = urlsplit(database_url)
        host = parsed.hostname or "default/socket"
        port = parsed.port or 5432
        database = unquote(parsed.path.lstrip("/"))
        username = unquote(parsed.username or "")
        if not database_url or not parsed.scheme:
            raise ValueError()
    except ValueError:
        logger.error("[OHD DB CHECK] invalid connection URL in %s", source)
        raise ValueError("Некорректный формат подключения ОХД. Проверьте OHD_DEV_DATABASE_URL / DBT_LOGS_DATABASE_URL.") from None

    logger.info("[OHD DB CHECK] START source=%s host=%s port=%s database=%s user=%s",
                source, host, port, database, username)
    started = time.perf_counter()
    engine = None
    try:
        engine = create_engine(database_url, connect_args={"connect_timeout": 5})
        with engine.connect() as conn:
            identity = dict(conn.execute(text("""
                SELECT current_database() AS database_name,
                       current_user AS user_name,
                       inet_server_addr()::text AS server_address,
                       inet_server_port() AS server_port
            """)).mappings().one())
    except Exception as exc:
        # Neither exception tracebacks nor raw DSNs belong in logs/job errors.
        # Driver errors may repeat the URL or a decoded/encoded password.
        message = str(exc)
        secrets = {database_url, parsed.password or "", unquote(parsed.password or "")}
        secrets.update(value for key, value in parse_qsl(parsed.query)
                       if key.lower() in {"password", "passwd", "sslpassword", "token", "access_token", "secret"})
        for secret in sorted(secrets, key=len, reverse=True):
            if secret:
                message = message.replace(secret, "***")
        logger.error("[OHD DB CHECK] FAILED source=%s host=%s port=%s database=%s duration=%.3fs error=%s",
                     source, host, port, database, time.perf_counter() - started, message)
        raise ValueError(f"Не удалось подключиться к ОХД ({host}:{port}, база {database}): {message}") from None
    finally:
        if engine is not None:
            engine.dispose()
    logger.info("[OHD DB CHECK] OK source=%s server=%s port=%s database=%s user=%s duration=%.3fs",
                source, identity.get("server_address"), identity.get("server_port"), identity.get("database_name"),
                identity.get("user_name"), time.perf_counter() - started)
    return identity
