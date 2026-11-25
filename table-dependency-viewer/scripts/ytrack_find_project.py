#!/usr/bin/env python3
"""Read-only YouTrack project lookup; prints configuration without credentials."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import ssl
import sys
from urllib import error, parse, request

# Вставьте токен сюда для локального запуска. Непустое значение важнее .env.
SCRIPT_YOUTRACK_TOKEN = ""
# Пустой URL / None для SSL означают: взять из .env или окружения.
SCRIPT_YOUTRACK_URL = ""
SCRIPT_YOUTRACK_SSL_VERIFY = None  # True — проверять сертификат; False — не проверять.


def load_env(path: str) -> None:
    try:
        from dotenv import load_dotenv
    except ImportError:
        # Allow running this diagnostic with Python's standard library only.
        for raw in Path(path).read_text(encoding="utf-8-sig").splitlines():
            line = raw.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, value = line.removeprefix("export ").split("=", 1)
            value = value.strip()
            if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
                value = value[1:-1]
            else:
                value = re.split(r"\s+#", value, maxsplit=1)[0].rstrip()
            os.environ.setdefault(key.strip(), value)
    else:
        load_dotenv(path, override=False)


def issue_key(value: str) -> str:
    value = value.strip()
    if "://" in value:
        parts = parse.urlsplit(value).path.split("/")
        value = parts[parts.index("issue") + 1] if "issue" in parts else ""
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*-\d+", value):
        raise ValueError("Укажите код задачи (SDS-471) или ссылку вида https://yt.../issue/SDS-471/...")
    return value.upper()


class YouTrack:
    def __init__(self, base_url: str, token: str, verify: bool):
        self.base_url = base_url.rstrip("/").removesuffix("/api")
        origin = parse.urlsplit(self.base_url)
        if origin.scheme not in {"http", "https"} or not origin.hostname or origin.username or origin.password:
            raise ValueError("Некорректный YOUTRACK_URL")
        self.token = token
        context = ssl.create_default_context() if verify else ssl._create_unverified_context()
        self.opener = request.build_opener(request.ProxyHandler({}), request.HTTPSHandler(context=context))

    def get(self, path: str, params: dict) -> object:
        req = request.Request(self.base_url + path + "?" + parse.urlencode(params),
                              headers={"Accept": "application/json", "Authorization": f"Bearer {self.token}"})
        try:
            with self.opener.open(req, timeout=30) as response:
                return json.load(response)
        except error.HTTPError as exc:
            hints = {401: "Проверьте токен выбранного режима (ОХД: OHD_YOUTRACK_TOKEN; КХД: YOUTRACK_TOKEN).", 403: "Токену не хватает прав. Попробуйте --issue SDS-471 вместо списка проектов.",
                     404: "Проверьте адрес YouTrack и код задачи; задача также может быть недоступна токену."}
            raise ValueError(f"GET {path}: HTTP {exc.code}. {hints.get(exc.code, 'Ошибка YouTrack API.')}") from None
        except (error.URLError, TimeoutError, OSError) as exc:
            reason = getattr(exc, "reason", exc)
            detail = str(reason).replace(self.token, "***") if self.token else str(reason)
            hint = ("Ошибка проверки сертификата. Проверьте доверенный CA или настройку SSL_VERIFY."
                    if isinstance(reason, ssl.SSLCertVerificationError) or "CERTIFICATE_VERIFY_FAILED" in detail
                    else "Проверьте доступ к серверу, DNS и VPN из среды запуска скрипта.")
            raise ValueError(f"GET {self.base_url}{path}: {type(reason).__name__}: {detail}. {hint}") from None

    def project_from_issue(self, value: str) -> dict:
        # Request the project directly from a known issue, without admin/projects permissions.
        data = self.get(f"/api/issues/{issue_key(value)}", {"fields": "idReadable,project(id,name,shortName)"})
        project = data.get("project") if isinstance(data, dict) else None
        if not isinstance(project, dict) or not project.get("id"):
            raise ValueError("YouTrack не вернул project.id для задачи")
        return project

    def projects(self) -> list[dict]:
        result = []
        skip = 0
        while True:
            batch = self.get("/api/admin/projects", {"fields": "id,name,shortName", "$top": 100, "$skip": skip})
            if not isinstance(batch, list):
                raise ValueError("YouTrack вернул некорректный список проектов")
            if not batch:
                return result
            result.extend(batch)
            skip += len(batch)


def find_projects(projects: list[dict], query: str) -> list[dict]:
    query = query.strip().casefold()
    exact = [p for p in projects if any(str(p.get(k) or "").casefold() == query for k in ("id", "shortName", "name"))]
    return exact or [p for p in projects if query in str(p.get("name") or "").casefold()
                     or query in str(p.get("shortName") or "").casefold()]


def print_config(project: dict, mode: str) -> None:
    prefix = "OHD_YOUTRACK" if mode == "ohd" else "YOUTRACK"
    print("\nЗначения для .env:")
    for suffix, key in (("PROJECT", "name"), ("PROJECT_ID", "id"), ("QUEUE", "shortName")):
        print(f"{prefix}_{suffix}={project.get(key) or ''}")
    field = "OHD_YOUTRACK_DIRECTION_FIELD_NAME" if mode == "ohd" else "YOUTRACK_DASHBOARD_DIRECTION_FIELD_NAME"
    print(f"{field}=Дашборд КХД/Направление")


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="Найти YouTrack project.id и shortName. Только GET, без создания задач.")
    parser.add_argument("--env-file", default=".env", help="Файл настроек (по умолчанию .env); переменные окружения имеют приоритет")
    parser.add_argument("--mode", choices=("ohd", "khd"), default="ohd", help="Префикс настроек для результата")
    selectors = parser.add_mutually_exclusive_group()
    selectors.add_argument("--issue", help="Код или ссылка известной задачи, например SDS-471")
    selectors.add_argument("--project", help="Название, shortName или ID проекта, поддерживается часть названия")
    selectors.add_argument("--list", action="store_true", help="Все доступные проекты, со всеми страницами API")
    args = parser.parse_args(argv)
    try:
        if Path(args.env_file).is_file():
            load_env(args.env_file)
        elif args.env_file != ".env":
            raise ValueError("Указанный файл настроек не найден")
        token_key = "OHD_YOUTRACK_TOKEN" if args.mode == "ohd" else "YOUTRACK_TOKEN"
        token = SCRIPT_YOUTRACK_TOKEN.strip() or os.getenv(token_key, "").strip()
        if not token:
            raise ValueError(f"Вставьте токен в SCRIPT_YOUTRACK_TOKEN в начале скрипта или задайте {token_key} в .env")
        verify = (SCRIPT_YOUTRACK_SSL_VERIFY if SCRIPT_YOUTRACK_SSL_VERIFY is not None else
                  os.getenv("YOUTRACK_SSL_VERIFY", "true").strip().lower() not in {"0", "false", "no", "off"})
        client = YouTrack(SCRIPT_YOUTRACK_URL.strip() or os.getenv("YOUTRACK_URL", "https://yt.rusal.ru").strip(), token, verify)
        print(f"YouTrack: {client.base_url}; проверка SSL: {verify}")
        if args.issue:
            projects = [client.project_from_issue(args.issue)]
        else:
            projects = client.projects()
            if not args.list:
                query = args.project or os.getenv("OHD_YOUTRACK_PROJECT" if args.mode == "ohd" else "YOUTRACK_PROJECT", "")
                if not query.strip():
                    raise ValueError("Укажите --issue, --project или --list")
                projects = find_projects(projects, query)
        if not projects:
            raise ValueError("Проект не найден среди доступных токену. Попробуйте --issue SDS-471 или --list.")
        print("ID\tSHORT NAME\tНАЗВАНИЕ")
        for project in projects:
            print(f"{project.get('id', '')}\t{project.get('shortName', '')}\t{project.get('name', '')}")
        if len(projects) == 1:
            print_config(projects[0], args.mode)
        elif not args.list:
            print("\nНайдено несколько проектов. Уточните --project точным кодом или используйте --issue.")
            return 2
        return 0
    except (ValueError, IndexError) as exc:
        message = str(exc)
        for secret in (SCRIPT_YOUTRACK_TOKEN.strip(), os.getenv("YOUTRACK_TOKEN", "").strip(), os.getenv("OHD_YOUTRACK_TOKEN", "").strip()):
            if secret:
                message = message.replace(secret, "***")
        print(f"Ошибка: {message}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
