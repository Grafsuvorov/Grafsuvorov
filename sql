 Исправь так:

  services:
    frontend:
      build: .
      ports:
        - "15312:80"
    api:
      build:
        context: .
        dockerfile: api/Dockerfile
      volumes:
        - /root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity:/app/etl_loads_entity:ro
      ports:
        - "5312:8000"
      env_file:
        - ./api/.env
      environment:
        - META_PARENT_DIR=/app/etl_loads_entity

  После этого:

  docker compose up -d --force-recreate
  docker compose exec api /bin/sh -c 'ls /app/etl_loads_entity | head'
  docker compose logs --tail=10 api

  META COUNT должен стать > 0.

