[root@rgm-s-dwhapp01 table-dependency-viewer]# sed -n '1,20p' api/Dockerfile
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY api/ /app/api/

RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple \
    --trusted-host=nx.sib.rual.ru --trusted-host=pypi.nx.sib.rual.ru \
    --retries 100 --timeout 600000 --no-cache-dir \
     fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
[root@rgm-s-dwhapp01 table-dependency-viewer]# sed -n '1,20p' api/Dockerfile.orig
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY api/ /app/api/
COPY etl_loads_entity/ /app/etl_loads_entity/

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"][root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose config
services:
  api:
    build:
      context: /root/table-dependency-viewer
      dockerfile: api/Dockerfile
    environment:
      DATABASE_URL: postgresql+psycopg2://gpetl:gpetl@10.66.229.201:5432/dwh
      TABLE_ENTITIES_META: tech_etl.entities_meta
      TABLE_LOADING_HISTORY: tech_etl.log_objects_loading_history
      TABLE_TABLE_COMPARE: tech_monitoring.vw_table_compare
      TABLE_TABLES_META: tech_etl.tables_meta
      TABLE_TABLES_META_CLICK: tech_etl.tables_meta_clickhouse_upload
      TABLE_YT_SLA: tech_etl.yt_sla
      TABLE_YTREK_INCIDENTS: tech_etl.YTREK_INCIDENTS
    env_file:
    - ./api/.env
    networks:
      default: null
    ports:
    - mode: ingress
      target: 8000
      published: 5312
      protocol: tcp
    volumes:
    - type: bind
      source: /root/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity
      target: /app/etl_loads_entity
      read_only: true
      bind:
        create_host_path: true
  frontend:
    build:
      context: /root/table-dependency-viewer
      dockerfile: Dockerfile
    networks:
      default: null
    ports:
    - mode: ingress
      target: 80
      published: 80
      protocol: tcp
networks:
  default:
    name: table-dependency-viewer_default
