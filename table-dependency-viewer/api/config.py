DATABASE_URL = "postgresql+psycopg2://postgres:0506@localhost:5432/dwh"

TABLE_LOADING_HISTORY   = "public.log_objects_loading_history"
TABLE_ENTITIES_META     = "public.entities_meta"
TABLE_TABLES_META       = "public.tables_meta"
TABLE_YT_SLA            = "public.yt_sla"
TABLE_YTREK_INCIDENTS   = "public.ytrek_incidents"
TABLE_DATA_QUALITY      = "public.data_quality_results"

# PROD ONLY — в локале нет
TABLE_TABLES_META_CLICK = None
TABLE_TABLE_COMPARE     = None

