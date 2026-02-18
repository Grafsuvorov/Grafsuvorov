В api/main.py:

  META_PARENT_DIRS = [Path(os.getenv("META_PARENT_DIR", "/root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity"))]

  И в docker-compose.yml для api добавить:

  environment:
    - META_PARENT_DIR=/root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity

  ———

  После правки:

  cd /root/table-dependency-viewer
  docker compose build --no-cache api
  docker compose up -d --force-recreate

  Проверка:

  docker compose logs -f api

  Ищем строку META COUNT: — должно быть больше 0.

  Скажи, какой вариан
