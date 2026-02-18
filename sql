## В api/Dockerfile

  Сделай node‑stage, где ставится dagre, и потом копируй node + npm + node_modules.

  # stage: node + dagre
  FROM node:20-slim AS node
  RUN npm install -g dagre

  # stage: python
  FROM python:3.11-slim
  WORKDIR /app/api
  ENV PYTHONDONTWRITEBYTECODE=1
  ENV PYTHONUNBUFFERED=1

  # копируем node и npm из stage
  COPY --from=node /usr/local/bin/node /usr/local/bin/node
  COPY --from=node /usr/local/bin/npm /usr/local/bin/npm
  COPY --from=node /usr/local/bin/npx /usr/local/bin/npx
  COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
  ENV PATH="/usr/local/bin:${PATH}"
  ENV NODE_PATH=/usr/local/lib/node_modules

  COPY api/ /app/api/

  RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple \
    --trusted-host=nx.sib.rual.ru --trusted-host=pypi.nx.sib.rual.ru \
    --retries 100 --timeout 600000 --no-cache-dir \
    fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

  EXPOSE 8000
  CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]

  Дальше:

  docker compose build --no-cache api
  docker compose up -d --force-recreate

  Проверка:

  curl -x "" -i "http://localhost:5312/api/graph/diagnostics?include_any=true" | head -n 20

  Если 200 — главная загрузится.
