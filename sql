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
      - /root/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity:/app/etl_loads_entity:ro
    ports:
      - "5312:8000"

    env_file:
      - ./api/.env
    environment:
      - META_PARENT_DIR=/root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity
