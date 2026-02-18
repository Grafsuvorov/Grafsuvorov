volumes:
        - /root/table-dependency-viewer/scripts:/app/scripts:ro
        - /root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity:/app/etl_loads_entity:ro

  (оставь оба volume)

  ## Перезапусти:

  cd /root/table-dependency-viewer
  docker compose up -d --force-recreate

  ## Проверка:

  docker compose exec api ls /app/scripts
  curl -s "http://localhost:5312/api/graph/diagnostics?include_any=true" | head

  После этого CORS/500 исчезнут и главная страница загрузится.
