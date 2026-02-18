[root@rgm-s-dwhapp01 api]# ls
config.py  Dockerfile  Dockerfile.orig  __init__.py  main.py  __pycache__

       
[root@rgm-s-dwhapp01 table-dependency-viewer]# ls
api                 __init__.py          node_modules       scripts                      tailwind.config.js
dist                meta_data_file.yaml  package.json       sql_query_recreate_init.sql  test.py
docker-compose.yml  meta_info            package-lock.json  sql_query_truncate.sql       vite.config.js
index.html          nginx.conf           requirements.txt   src
[root@rgm-s-dwhapp01 table-dependency-viewer]#


Docker-compose.yml
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

Dockerfile.orig
FROM python:3.11-slim

WORKDIR /app

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY api/ /app/api/
COPY etl_loads_entity/ /app/etl_loads_entity/

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]

Dockerfile
FROM node:20-alpine AS build

ENV HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"

WORKDIR /app
COPY package*.json ./

RUN npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010
RUN npm i -g npm@9
RUN npm ci --include=dev

COPY . .
RUN npm run build

FROM nginx:alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
