"""OHD Prototype Review: dbt metadata and delivery without ETL metadata."""
from dataclasses import replace
import os
from urllib.parse import urlsplit

import yaml

from .. import config
from .prototype_review_dbt import dbt_registry_path
from .prototype_review_item import resolve_prototype_review_item


def ohd_settings():
    def setting(name):
        return os.getenv(name, getattr(config, name, "")).strip()
    dbt_token = setting("OHD_DBT_GITLAB_TOKEN") or setting("OHD_GITLAB_TOKEN")
    return {
        "dev_database_url": os.getenv("OHD_DEV_DATABASE_URL") or os.getenv("DBT_LOGS_DATABASE_URL", ""),
        "api_url": setting("OHD_GITLAB_API_URL").rstrip("/"),
        "ssl_verify": (setting("OHD_GITLAB_SSL_VERIFY") or "true").lower() not in {"0", "false", "no", "off"},
        "project": setting("OHD_DBT_GITLAB_PROJECT"),
        "token": dbt_token,
        "analyst_project": setting("OHD_ANALYST_GITLAB_PROJECT"),
        "analyst_token": setting("OHD_ANALYST_GITLAB_TOKEN") or setting("OHD_GITLAB_TOKEN") or dbt_token,
        "youtrack_project": os.getenv("OHD_YOUTRACK_PROJECT", "ОХД - Общее Хранилище Данных (Данные партнеров)"),
        "youtrack_project_id": os.getenv("OHD_YOUTRACK_PROJECT_ID", ""),
        "youtrack_queue": os.getenv("OHD_YOUTRACK_QUEUE", ""),
        "direction_field": os.getenv("OHD_YOUTRACK_DIRECTION_FIELD_NAME", "Дашборд КХД/Направление"),
    }


def require_ohd_settings(settings, *, delivery=False):
    required = {"api_url": "OHD_GITLAB_API_URL", "project": "OHD_DBT_GITLAB_PROJECT",
                "analyst_project": "OHD_ANALYST_GITLAB_PROJECT",
                "token": "OHD_GITLAB_TOKEN (или OHD_DBT_GITLAB_TOKEN)",
                "analyst_token": "OHD_GITLAB_TOKEN (или OHD_ANALYST_GITLAB_TOKEN)"}
    required.update({"youtrack_queue": "OHD_YOUTRACK_QUEUE"} if delivery else {
        "dev_database_url": "DBT_LOGS_DATABASE_URL (или OHD_DEV_DATABASE_URL)"})
    missing = [name for key, name in required.items() if not settings.get(key)]
    if missing:
        raise ValueError("Для режима ОХД настройте: " + ", ".join(missing))
    api = urlsplit(settings["api_url"])
    if api.scheme not in {"https", "http"} or not api.hostname or api.username or api.password:
        raise ValueError("OHD_GITLAB_API_URL должен содержать адрес API GitLab, например https://gitlab.example/api/v4")


def load_ohd_bundle(*, loader, **kwargs):
    """Use the OHD instance even for full MR links; reject another server."""
    mr = urlsplit(str(kwargs.get("mr_input") or "").strip())
    api = urlsplit(kwargs["gitlab_api_url"])
    if mr.netloc:
        origin = lambda value: (value.hostname, value.port or (443 if value.scheme == "https" else 80))
        if mr.scheme not in {"http", "https"} or origin(mr) != origin(api):
            raise ValueError(f"Ссылка MR ведёт на другой GitLab ({mr.hostname}); для ОХД настроен {api.hostname}. "
                             "Проверьте ссылку и OHD_GITLAB_API_URL.")
    return loader(**kwargs)


class OhdReviewContext:
    """Read authoritative registry from OHD main, never from KHD tables_meta."""
    def __init__(self, *, settings, read_file, base_resolver):
        self.settings = settings
        self.read_file = read_file
        self.base_resolver = base_resolver
        self.registries = {}

    def registry(self, target_fqn):
        key = target_fqn.lower()
        if key not in self.registries:
            schema, table = key.split(".", 1)
            content = self.read_file(project=self.settings["project"], token=self.settings["token"],
                                     file_path=dbt_registry_path(schema, table), ref="main",
                                     api_url=self.settings["api_url"], ssl_verify=self.settings["ssl_verify"])
            value = yaml.safe_load(content) if content else {}
            if not isinstance(value, dict) or not isinstance(value.get("relation", {}), dict):
                raise ValueError(f"Некорректный dbt registry ОХД для {target_fqn}")
            relation = value.get("relation") or {}
            if content and not relation:
                raise ValueError(f"В dbt registry ОХД для {target_fqn} отсутствует relation")
            if relation and (str(relation.get("schema_name") or "").lower() != schema
                             or str(relation.get("table_name") or "").lower() != table):
                raise ValueError(f"Имя relation в dbt registry ОХД не совпадает с {target_fqn}")
            self.registries[key] = value
        return self.registries[key]

    def resolve_item(self, **kwargs):
        target = kwargs["target_fqn"]
        registry = self.registry(target)
        relation = registry.get("relation") or {}
        entities = relation.get("entity") or []
        if isinstance(entities, str):
            entities = [n.strip() for n in entities.split(",") if n.strip()]
        meta = {"table_schema": relation.get("schema_name"), "table_name": relation.get("table_name"),
                "key_attributes": relation.get("unique_key") or [], "entity_name": entities[0] if entities else ""}
        duplicates = next((d for d in registry.get("dq") or [] if d.get("check_type") == "duplicates"), {})
        nulls = next((d for d in registry.get("dq") or [] if d.get("check_type") == "nulls"), {})
        resolver = replace(self.base_resolver,
            find_meta=lambda _: meta if relation else None,
            find_meta_variants=lambda _: [{**meta, "entity_name": name} for name in entities],
            get_click_meta_index=lambda: {"meta": {}}, impact_summary=lambda _: {},
            existing_null_conditions=lambda *_: nulls.get("conditions") or [],
            existing_duplicate_filter=lambda *_: duplicates.get("filter") or "",
            dev_database_url=self.settings["dev_database_url"])
        if kwargs.get("key_attributes_override") is None:
            kwargs["key_attributes_override"] = relation.get("unique_key") or []
        result = resolve_prototype_review_item(**kwargs, resolver=resolver)
        result.update(scd_type=relation.get("scd_type") or "scd1", version_key=relation.get("version_key") or [],
                      copy_to_clickhouse=False, table_id=None, yaml_bundle=None)
        return result


def deliver_ohd_issue(*, issue_result, review_items, bundle, user, dependencies, source_load=None):
    """Publish only to dbt; no ETL workspace writes, IDs or engineering MR."""
    if source_load or any(item.get("is_clickhouse_view") for item in review_items):
        raise ValueError("В режиме ОХД поддерживается только dbt Greenplum")
    result = {"meta_branch": None, "meta_files": [], "meta_error": None, "meta_mr": None,
              "meta_mr_error": None, "dbt_registry": None, "dbt_registry_error": None}
    if not issue_result.get("issue_id"):
        return result
    try:
        dbt = dependencies.publish_dbt(task_id=issue_result["issue_id"],
            author=getattr(user, "email", None) or getattr(user, "username", None) or "prototype-review",
            review_items=review_items, changed_files=bundle.get("files") or [], deleted_files=bundle.get("deleted_files") or [])
        result["dbt_registry"] = dbt
        if dbt.get("mr_url"):
            dependencies.add_comment(base_url=dependencies.youtrack_url, token=dependencies.youtrack_token,
                issue_id=issue_result["issue_id"], ssl_verify=dependencies.youtrack_ssl_verify,
                text=f"MR ОХД с SQL, registry и DQ создан в dbt.\nСсылка: {dbt['mr_url']}\nЦелевая ветка: main")
            dbt["task_link_attached"] = True
    except Exception as exc:
        result["dbt_registry_error"] = str(exc)
    return result
