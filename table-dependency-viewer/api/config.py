import os

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:0506@localhost:5432/dwh",
)

TABLE_LOADING_HISTORY   = "public.log_objects_loading_history"
TABLE_ENTITIES_META     = "public.entities_meta"
TABLE_TABLES_META       = "public.tables_meta"
TABLE_YT_SLA            = "public.yt_sla"
TABLE_YTREK_INCIDENTS   = "public.ytrek_incidents"
TABLE_DATA_QUALITY      = "public.data_quality_results"
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
DBT_MANIFEST_DIR        = os.getenv("DBT_MANIFEST_DIR", "config_files/dbt")
ADMIN_CICD_SCRIPT       = os.getenv("ADMIN_CICD_SCRIPT", "scripts/ci_cd.sh")
YTRACK_ISSUE_URL        = os.getenv("YTRACK_ISSUE_URL", "https://yt.rusal.ru/issue/{id}")
DEV_DATABASE_URL        = os.getenv("DEV_DATABASE_URL", "")
AIRFLOW_DEV_BASE_URL    = os.getenv("AIRFLOW_DEV_BASE_URL", "")
AIRFLOW_DEV_DAG_ID      = os.getenv("AIRFLOW_DEV_DAG_ID", "")
AIRFLOW_DEV_USERNAME    = os.getenv("AIRFLOW_DEV_USERNAME", "")
AIRFLOW_DEV_PASSWORD    = os.getenv("AIRFLOW_DEV_PASSWORD", "")
DEV_META_LOCK_TTL_MIN   = int(os.getenv("DEV_META_LOCK_TTL_MIN", "30"))
DEV_META_DEPLOY_HOST    = os.getenv("DEV_META_DEPLOY_HOST", "")
DEV_META_DEPLOY_PORT    = int(os.getenv("DEV_META_DEPLOY_PORT", "22"))
DEV_META_DEPLOY_USER    = os.getenv("DEV_META_DEPLOY_USER", "")
DEV_META_DEPLOY_PASSWORD = os.getenv("DEV_META_DEPLOY_PASSWORD", "")
DEV_META_DEPLOY_BASE_DIR = os.getenv("DEV_META_DEPLOY_BASE_DIR", "")
DEV_META_DEPLOY_SSH_KEY_PATH = os.getenv("DEV_META_DEPLOY_SSH_KEY_PATH", "")
DEV_META_DEPLOY_STRICT_HOST_KEY = os.getenv("DEV_META_DEPLOY_STRICT_HOST_KEY", "false")

# PROD ONLY — в локале нет
TABLE_TABLES_META_CLICK = None
TABLE_TABLE_COMPARE     = None

AUTH_ENABLED = os.getenv("AUTH_ENABLED", "false")
AUTH_SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "change_me")
AUTH_ACCESS_TTL_MIN = int(os.getenv("AUTH_ACCESS_TTL_MIN", "480"))
AUTH_ALLOW_REGISTER = os.getenv("AUTH_ALLOW_REGISTER", "false")
AUTH_BOOTSTRAP_ADMIN_EMAIL = os.getenv("AUTH_BOOTSTRAP_ADMIN_EMAIL")
AUTH_BOOTSTRAP_ADMIN_PASSWORD = os.getenv("AUTH_BOOTSTRAP_ADMIN_PASSWORD")
