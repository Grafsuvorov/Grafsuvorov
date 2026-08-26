from dotenv import load_dotenv
import os

load_dotenv()


def _env_int(name: str, default: int) -> int:
    value = os.getenv(name)
    if value is None:
        return default
    value = str(value).strip()
    if not value:
        return default
    try:
        return int(value)
    except ValueError:
        return default

TABLE_LOADING_HISTORY   = os.getenv("TABLE_LOADING_HISTORY", "tech_etl.log_objects_loading_history")
TABLE_ENTITIES_META     = os.getenv("TABLE_ENTITIES_META", "tech_etl.entities_meta")
TABLE_TABLES_META       = os.getenv("TABLE_TABLES_META", "tech_etl.tables_meta")
TABLE_TABLE_COMPARE     = os.getenv("TABLE_TABLE_COMPARE", "tech_monitoring.vw_table_compare")
TABLE_YT_SLA            = os.getenv("TABLE_YT_SLA", "tech_etl.yt_sla")
TABLE_TABLES_META_CLICK = os.getenv("TABLE_TABLES_META_CLICK", "tech_etl.tables_meta_clickhouse_upload")
DATABASE_URL            = os.getenv("DATABASE_URL")
DBT_LOGS_DATABASE_URL   = os.getenv("DBT_LOGS_DATABASE_URL", "")
TABLE_YTREK_INCIDENTS   = os.getenv("TABLE_YTREK_INCIDENTS", "tech_etl.ytrek_incidents")
TABLE_DATA_QUALITY      = os.getenv("TABLE_DATA_QUALITY", "dq.data_quality_results")
TABLE_RELEASE_LOG       = os.getenv("TABLE_RELEASE_LOG", "public.release_log")
TABLE_RELEASE_OBJECTS   = os.getenv("TABLE_RELEASE_OBJECTS", "public.release_objects")
TABLE_YT_ISSUE_SNAPSHOT = os.getenv("TABLE_YT_ISSUE_SNAPSHOT", "tech_etl.yt_issue_snapshot")
TABLE_YT_ISSUE_CUSTOM   = os.getenv("TABLE_YT_ISSUE_CUSTOM", "tech_etl.yt_issue_custom_field")
TABLE_YT_ISSUE_TIMELINE = os.getenv("TABLE_YT_ISSUE_TIMELINE", "tech_etl.yt_issue_timeline")
TABLE_YT_ISSUE_WORKLOG  = os.getenv("TABLE_YT_ISSUE_WORKLOG", "tech_etl.yt_issue_worklog")
TABLE_YT_ISSUE_COMMENT  = os.getenv("TABLE_YT_ISSUE_COMMENT", "tech_etl.yt_issue_comment")
TABLE_CLICK_LOAD_RUN    = os.getenv("TABLE_CLICK_LOAD_RUN", "public.click_fact_table_load_run")
TABLE_CLICK_LOAD_STAGE  = os.getenv("TABLE_CLICK_LOAD_STAGE", "public.click_fact_table_load_stage")
CLICK_META_DIR          = os.getenv("CLICK_META_DIR", "config_files/meta")
DEV_CLICK_META_DIR      = os.getenv("DEV_CLICK_META_DIR", "config_files/meta_dev")
ENTITY_META_DIR         = os.getenv("ENTITY_META_DIR", "etl_loads_entity")
DEV_ENTITY_META_DIR     = os.getenv("DEV_ENTITY_META_DIR", "etl_loads_entity_dev")
DBT_MANIFEST_DIR        = os.getenv("DBT_MANIFEST_DIR", "config_files/dbt")
TABLE_DBT_MODEL_CATALOG = os.getenv("TABLE_DBT_MODEL_CATALOG", "dc_dbt.model")
TABLE_DBT_MODEL_LOG     = os.getenv("TABLE_DBT_MODEL_LOG", "tech_monitoring.log_dbt_model")
TABLE_DBT_RUN_LOG       = os.getenv("TABLE_DBT_RUN_LOG", "tech_monitoring.log_dbt_run")
DEV_COPY_SCHEMA_SYNC_DAG_ID = os.getenv("DEV_COPY_SCHEMA_SYNC_DAG_ID", "information_schema_sync")
TABLE_SAY_COMPARE_GP_METADATA_LOG = os.getenv(
    "TABLE_SAY_COMPARE_GP_METADATA_LOG",
    "tech_monitoring.say_compare_gp_metadata_log",
)
TABLE_SAY_COMPARE_GP_METADATA_PROD_VS_DEV = os.getenv(
    "TABLE_SAY_COMPARE_GP_METADATA_PROD_VS_DEV",
    "tech_monitoring.say_compare_gp_metadata_prod_vs_dev",
)
ADMIN_CICD_SCRIPT       = os.getenv("ADMIN_CICD_SCRIPT", "scripts/ci_cd.sh")
YTRACK_ISSUE_URL        = os.getenv("YTRACK_ISSUE_URL", "https://yt.rusal.ru/issue/{id}")
YOUTRACK_URL           = os.getenv("YOUTRACK_URL", "https://yt.rusal.ru")
YOUTRACK_TOKEN         = os.getenv("YOUTRACK_TOKEN", "")
YOUTRACK_PROJECT_ID    = os.getenv("YOUTRACK_PROJECT_ID", "")
DEV_DATABASE_URL        = os.getenv("DEV_DATABASE_URL", "")
AIRFLOW_DEV_BASE_URL    = os.getenv("AIRFLOW_DEV_BASE_URL", "")
AIRFLOW_DEV_DAG_ID      = os.getenv("AIRFLOW_DEV_DAG_ID", "")
AIRFLOW_DEV_USERNAME    = os.getenv("AIRFLOW_DEV_USERNAME", "")
AIRFLOW_DEV_PASSWORD    = os.getenv("AIRFLOW_DEV_PASSWORD", "")
DEV_META_LOCK_TTL_MIN   = _env_int("DEV_META_LOCK_TTL_MIN", 30)
DEV_META_DEPLOY_HOST    = os.getenv("DEV_META_DEPLOY_HOST", "")
DEV_META_DEPLOY_PORT    = _env_int("DEV_META_DEPLOY_PORT", 22)
DEV_META_DEPLOY_USER    = os.getenv("DEV_META_DEPLOY_USER", "")
DEV_META_DEPLOY_PASSWORD = os.getenv("DEV_META_DEPLOY_PASSWORD", "")
DEV_META_DEPLOY_BASE_DIR = os.getenv("DEV_META_DEPLOY_BASE_DIR", "")
DEV_META_DEPLOY_SSH_KEY_PATH = os.getenv("DEV_META_DEPLOY_SSH_KEY_PATH", "")
DEV_META_DEPLOY_STRICT_HOST_KEY = os.getenv("DEV_META_DEPLOY_STRICT_HOST_KEY", "false")
ENTITY_META_GIT_REPO = os.getenv("ENTITY_META_GIT_REPO", "")
ENTITY_META_GIT_META_ROOT = os.getenv(
    "ENTITY_META_GIT_META_ROOT",
    "meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity",
)
GITLAB_TOKEN = os.getenv("GITLAB_TOKEN", "")
GITLAB_PROJECT = os.getenv("GITLAB_PROJECT", "")
ANALYST_GITLAB_PROJECT = os.getenv("ANALYST_GITLAB_PROJECT", "")
GITLAB_API_URL = os.getenv("GITLAB_API_URL", "")
GITLAB_SSL_VERIFY = os.getenv("GITLAB_SSL_VERIFY", "true")
CLICK_META_GIT_ROOT = os.getenv("CLICK_META_GIT_ROOT", "config_files/meta")
META_WORKSPACE_ROOT = os.getenv("META_WORKSPACE_ROOT", "/var/lib/table-dependency-viewer/meta-workspaces")
TABLE_APP_FEEDBACK = os.getenv("TABLE_APP_FEEDBACK", "tech_etl.app_feedback")

CORP_AI_API_KEY = os.getenv("CORP_AI_API_KEY", "")
CORP_AI_BASE_URL = os.getenv("CORP_AI_BASE_URL", "")
CORP_AI_MODEL = os.getenv("CORP_AI_MODEL", "coder-ultra")
CORP_AI_SSL_VERIFY = os.getenv("CORP_AI_SSL_VERIFY", "false")
CORP_AI_TIMEOUT_SEC = _env_int("CORP_AI_TIMEOUT_SEC", 60)
YOUTRACK_QUEUE = os.getenv("YOUTRACK_QUEUE", "")
YOUTRACK_PROJECT = os.getenv("YOUTRACK_PROJECT", "КХД")
YOUTRACK_ISSUE_TYPE = os.getenv("YOUTRACK_ISSUE_TYPE", "task")
YOUTRACK_SSL_VERIFY = os.getenv("YOUTRACK_SSL_VERIFY", "false")
YOUTRACK_DEFAULT_ESTIMATE_MINUTES = _env_int("YOUTRACK_DEFAULT_ESTIMATE_MINUTES", 60)
YOUTRACK_ESTIMATE_FIELD_NAME = os.getenv("YOUTRACK_ESTIMATE_FIELD_NAME", "Оценка (чел./час.)")

AUTH_ENABLED = os.getenv("AUTH_ENABLED", "false")
AUTH_SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "change_me")
AUTH_ACCESS_TTL_MIN = _env_int("AUTH_ACCESS_TTL_MIN", 480)
AUTH_ALLOW_REGISTER = os.getenv("AUTH_ALLOW_REGISTER", "false")
AUTH_BOOTSTRAP_ADMIN_EMAIL = os.getenv("AUTH_BOOTSTRAP_ADMIN_EMAIL")
AUTH_BOOTSTRAP_ADMIN_PASSWORD = os.getenv("AUTH_BOOTSTRAP_ADMIN_PASSWORD")
