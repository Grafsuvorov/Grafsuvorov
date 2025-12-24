# config.py
from dotenv import load_dotenv
import os
load_dotenv()
TABLE_LOADING_HISTORY = os.getenv("TABLE_LOADING_HISTORY", "tech_etl.log_objects_loading_history")
TABLE_ENTITIES_META = os.getenv("TABLE_ENTITIES_META", "tech_etl.entities_meta")
TABLE_TABLES_META = os.getenv("TABLE_TABLES_META", "tech_etl.tables_meta")
TABLE_TABLE_COMPARE = os.getenv("TABLE_TABLE_COMPARE", "tech_monitoring.vw_table_compare")
TABLE_YT_SLA = os.getenv("TABLE_YT_SLA", "tech_etl.yt_sla")
TABLE_TABLES_META_CLICK = os.getenv("TABLE_TABLES_META_CLICK", "tech_etl.tables_meta_clickhouse_upload")
DATABASE_URL = os.getenv("DATABASE_URL")

