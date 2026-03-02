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
TABLE_CLICK_LOAD_RUN    = os.getenv("TABLE_CLICK_LOAD_RUN", "public.click_fact_table_load_run")
TABLE_CLICK_LOAD_STAGE  = os.getenv("TABLE_CLICK_LOAD_STAGE", "public.click_fact_table_load_stage")
CLICK_META_DIR          = os.getenv("CLICK_META_DIR", "config_files/meta")
ADMIN_CICD_SCRIPT       = os.getenv("ADMIN_CICD_SCRIPT", "scripts/ci_cd.sh")

# PROD ONLY — в локале нет
TABLE_TABLES_META_CLICK = None
TABLE_TABLE_COMPARE     = None

AUTH_ENABLED = os.getenv("AUTH_ENABLED", "false")
AUTH_SECRET_KEY = os.getenv("AUTH_SECRET_KEY", "change_me")
AUTH_ACCESS_TTL_MIN = int(os.getenv("AUTH_ACCESS_TTL_MIN", "480"))
AUTH_ALLOW_REGISTER = os.getenv("AUTH_ALLOW_REGISTER", "false")
AUTH_BOOTSTRAP_ADMIN_EMAIL = os.getenv("AUTH_BOOTSTRAP_ADMIN_EMAIL")
AUTH_BOOTSTRAP_ADMIN_PASSWORD = os.getenv("AUTH_BOOTSTRAP_ADMIN_PASSWORD")
