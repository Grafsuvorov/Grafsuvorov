#!/usr/bin/env python3
"""Standalone OHD issue creation diagnostic. Edit CONFIG below; no .env needed."""
from __future__ import annotations

import argparse
from datetime import datetime
import json
import ssl
import sys
from urllib import error, parse, request

# Все настройки задаются здесь. Скрипт не читает .env.
CONFIG = {
    "url": "https://yt.rusal.ru",
    "token": "",                         # Вставьте токен YouTrack ОХД.
    "ssl_verify": False,
    "use_system_proxy": False,
    "timeout_seconds": 30,
    "project_id": "",                    # Например 0-123; не 173-515 (это ID поля).
    "project": "SDS",                    # shortName или точное имя; используется при пустом project_id.
    "queue": "SDS",
    "summary": "[TEST ОХД] Создание задачи и обязательная оценка",
    "description": "Тестовая задача для отладки API Prototype Review. Можно удалить после проверки.",
    "card_type_field": "Тип карточки",
    "card_type_value": "Task",
    "estimate_field_id": "173-515",      # Обязательное поле из ответа workflow ОХД.
    "estimate_field_name": "Оценка (чел./час.)",
    "estimate_minutes": 60,               # Для period: минуты; числовые поля ниже получают часы.
    "estimate_hours": 1,
    "estimate_text": "1ч",
    "field_identifier": "both",          # both / name / id — способ указать поле в POST.
    "estimate_type_override": "",        # Например PeriodIssueCustomField; пусто = тип из API.
    "estimate_value_override_enabled": False,
    "estimate_value_override": {"minutes": 60},  # Можно заменить на 1 или "1ч" для ручного опыта.
    "assignee_login": "",                # Точный login YouTrack; пусто = не отправлять.
    "assignee_field": "Assignee",
    # Дополнительные enum-поля. Имена должны совпадать с выводом --fields.
    # Пример: {"name": "Subsystem", "value": "DE (Data Engineer)"}
    # Пример: {"name": "Дашборд КХД/Направление", "value": "Релиз"}
    "enum_fields": [],
}


def redact(value, config):
    text = str(value)
    token = str(config["token"]).strip()
    return text.replace(token, "***") if token else text


class Api:
    def __init__(self, config):
        self.config = config
        self.base = config["url"].strip().rstrip("/").removesuffix("/api")
        origin = parse.urlsplit(self.base)
        if origin.scheme not in {"http", "https"} or not origin.hostname or origin.username or origin.password:
            raise ValueError("Некорректный CONFIG['url']")
        if not str(config["token"]).strip():
            raise ValueError("Вставьте токен в CONFIG['token'] в начале скрипта")
        context = ssl.create_default_context() if config["ssl_verify"] else ssl._create_unverified_context()
        proxy = request.ProxyHandler() if config["use_system_proxy"] else request.ProxyHandler({})
        self.opener = request.build_opener(proxy, request.HTTPSHandler(context=context))

    def call(self, method, path, params=None, payload=None):
        url = self.base + path + ("?" + parse.urlencode(params) if params else "")
        req = request.Request(url, method=method,
            headers={"Authorization": "Bearer " + self.config["token"].strip(),
                     "Accept": "application/json", "Content-Type": "application/json"},
            data=json.dumps(payload, ensure_ascii=False).encode("utf-8") if payload is not None else None)
        print(f"{method} {url}")
        try:
            with self.opener.open(req, timeout=self.config["timeout_seconds"]) as response:
                print(f"HTTP {response.status}")
                data = response.read().decode("utf-8")
                return json.loads(data) if data else {}
        except error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            code = exc.code
            exc.close()
            raise ValueError(f"HTTP {code}: {redact(body, self.config)}") from None
        except (error.URLError, OSError) as exc:
            raise ValueError(redact(f"Ошибка подключения: {getattr(exc, 'reason', exc)}", self.config)) from None

    def list_all(self, path, fields):
        items = []
        while True:
            batch = self.call("GET", path, {"fields": fields, "$top": 100, "$skip": len(items)})
            if not isinstance(batch, list):
                raise ValueError("Вместо списка API вернул: " + redact(batch, self.config))
            if not batch:
                return items
            items.extend(batch)


def project_id(api, config):
    if config["project_id"].strip():
        return config["project_id"].strip()
    projects = api.list_all("/api/admin/projects", "id,name,shortName")
    matches = [p for p in projects if config["project"].strip().casefold()
               in {str(p.get("id", "")).casefold(), str(p.get("name", "")).casefold(), str(p.get("shortName", "")).casefold()}]
    if len(matches) != 1:
        print(json.dumps(projects, ensure_ascii=False, indent=2))
        raise ValueError("Проект не найден однозначно. Заполните CONFIG['project_id'] реальным ID из списка.")
    return matches[0]["id"]


def find_field(fields, name, field_id=""):
    if field_id:
        matches = [f for f in fields if f.get("id") == field_id]
    else:
        matches = [f for f in fields if (f.get("field") or {}).get("name", "").strip().casefold() == name.strip().casefold()]
    if len(matches) != 1:
        raise ValueError(f"Поле не найдено однозначно: name={name!r}, project_field_id={field_id!r}. Проверьте --fields.")
    return matches[0]


def issue_type(field):
    kind = field.get("$type", "")
    values = {"EnumProjectCustomField": "SingleEnumIssueCustomField", "UserProjectCustomField": "SingleUserIssueCustomField",
              "StateProjectCustomField": "StateIssueCustomField", "PeriodProjectCustomField": "PeriodIssueCustomField",
              "SimpleProjectCustomField": "SimpleIssueCustomField", "TextProjectCustomField": "TextIssueCustomField"}
    if kind not in values:
        raise ValueError(f"Неизвестный тип поля {kind!r}; добавьте явное соответствие в issue_type().")
    return values[kind]


def field_payload(field, value, config, type_override=""):
    data = {"$type": type_override or issue_type(field), "value": value}
    identifier = config["field_identifier"]
    if identifier not in {"both", "name", "id"}:
        raise ValueError("field_identifier должен быть both, name или id")
    if identifier in {"both", "id"}:
        data["id"] = field["id"]
    if identifier in {"both", "name"}:
        data["name"] = field["field"]["name"]
    return data


def build_payload(fields, pid, config):
    estimate = find_field(fields, config["estimate_field_name"], config["estimate_field_id"])
    kind = config["estimate_type_override"] or issue_type(estimate)
    value_type = str((estimate["field"].get("fieldType") or {}).get("valueType") or
                     (estimate["field"].get("fieldType") or {}).get("id") or "").lower()
    if config["estimate_value_override_enabled"]:
        value = config["estimate_value_override"]
    elif kind == "PeriodIssueCustomField" or value_type == "period":
        value = {"minutes": config["estimate_minutes"]}
    elif value_type in {"integer", "int", "float", "double", "number"}:
        value = config["estimate_hours"]
    elif value_type in {"string", "text"}:
        value = config["estimate_text"]
    else:
        raise ValueError(f"Нужен явный estimate_value_override для типа {value_type!r}")
    custom = [field_payload(estimate, value, config, kind)]
    if config["card_type_value"]:
        field = find_field(fields, config["card_type_field"])
        custom.append(field_payload(field, {"name": config["card_type_value"]}, config))
    if config["assignee_login"]:
        field = find_field(fields, config["assignee_field"])
        custom.append(field_payload(field, {"login": config["assignee_login"]}, config))
    for entry in config["enum_fields"]:
        field = find_field(fields, entry["name"])
        custom.append(field_payload(field, {"name": entry["value"]}, config))
    return {"project": {"id": pid}, "queue": config["queue"],
            "summary": config["summary"] + " " + datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "description": config["description"], "customFields": custom}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Создать одну тестовую задачу ОХД. Все настройки в CONFIG в начале файла.")
    parser.add_argument("--fields", action="store_true", help="Только показать поля проекта, без POST")
    parser.add_argument("--dry-run", action="store_true", help="Показать поля и payload, без POST")
    args = parser.parse_args(argv)
    try:
        api = Api(CONFIG)
        pid = project_id(api, CONFIG)
        print(f"Проект: {pid}; SSL verify: {CONFIG['ssl_verify']}")
        fields = api.list_all(f"/api/admin/projects/{parse.quote(pid, safe='')}/customFields",
                             "id,$type,canBeEmpty,field(id,name,fieldType(id,valueType))")
        print("\nПОЛЯ ПРОЕКТА (canBeEmpty не отражает все обязательные поля workflow):")
        print(redact(json.dumps(fields, ensure_ascii=False, indent=2), CONFIG))
        if args.fields:
            return 0
        payload = build_payload(fields, pid, CONFIG)
        print("\nPAYLOAD СОЗДАНИЯ:")
        print(redact(json.dumps(payload, ensure_ascii=False, indent=2), CONFIG))
        if args.dry_run:
            print("DRY RUN: задача не создавалась.")
            return 0
        # Exactly one POST. Do not automatically retry: a failed workflow can return an issue ID.
        result = api.call("POST", "/api/issues", {"fields": "id,idReadable,summary"}, payload)
        print("\nЗАДАЧА СОЗДАНА:")
        print(redact(json.dumps(result, ensure_ascii=False, indent=2), CONFIG))
        readable = result.get("idReadable") or result.get("id")
        if readable:
            print(f"Ссылка: {api.base}/issue/{parse.quote(readable, safe='')}")
            try:
                saved = api.call("GET", f"/api/issues/{parse.quote(readable, safe='')}",
                    {"fields": "id,idReadable,customFields(id,name,$type,value(id,name,minutes,presentation,text,login))"})
                print("\nСОХРАНЁННЫЕ ПОЛЯ:")
                print(redact(json.dumps(saved, ensure_ascii=False, indent=2), CONFIG))
            except ValueError as exc:
                print(f"Задача создана, но чтение сохранённых полей не удалось: {redact(exc, CONFIG)}")
        return 0
    except ValueError as exc:
        print("\nОШИБКА: " + redact(exc, CONFIG), file=sys.stderr)
        print("Повторная отправка автоматически не выполнялась. Если ответ содержит error_issue_id, проверьте наличие задачи перед новым запуском.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
