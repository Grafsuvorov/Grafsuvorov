@app.on_event("startup")
def warm_up_cache():
    try:
        get_cached_meta_and_index()
        get_cached_order_breaches()  # 🔥 прогрев orderbreaches
        get_graph_snapshot()
    except Exception as e:
        print("Ошибка при старте приложения:", e)


BASE_DIR = Path(__file__).resolve().parent.parent

META_PARENT_DIRS = [Path(r"C:\\Users\\SuvorovND\\GIT\\meta_info\\database\\greenplum\\schema_name\\tech_etl\\etl_loads_entity")]


def iter_meta_dirs(targets: Optional[List[str]] = None):
    """Yield existing metadata directories, searching both root and project/* trees.""

[root@rgm-s-dwhapp01 etl_loads_entity]# pwd
/root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity
