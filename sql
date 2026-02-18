# stage с node
FROM node:20-slim AS node

# stage с python
FROM python:3.11-slim

WORKDIR /app/api
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# копируем node runtime
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
ENV PATH="/usr/local/bin:${PATH}"

COPY api/ /app/api/
RUN npm install -g dagre
ENV NODE_PATH=/usr/local/lib/node_modules

RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple \
  --trusted-host=nx.sib.rual.ru --trusted-host=pypi.nx.sib.rual.ru \
  --retries 100 --timeout 600000 --no-cache-dir \
  fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]


root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose build --no-cache api
[+] Building 2.8s (12/13)
 => [internal] load build definition from Dockerfile                                                                                 0.0s
 => => transferring dockerfile: 900B                                                                                                 0.0s
 => [internal] load metadata for docker.io/library/python:3.11-slim                                                                  0.0s
 => [internal] load metadata for docker.io/library/node:20-slim                                                                      1.5s
 => [internal] load .dockerignore                                                                                                    0.0s
 => => transferring context: 162B                                                                                                    0.0s
 => [stage-1 1/7] FROM docker.io/library/python:3.11-slim                                                                            0.0s
 => [internal] load build context                                                                                                    0.0s
 => => transferring context: 1.80kB                                                                                                  0.0s
 => CACHED [node 1/1] FROM docker.io/library/node:20-slim@sha256:c6585df72c34172bebd8d36abed961e231d7d3b5cee2e01294c4495e8a03f687    0.0s
 => CACHED [stage-1 2/7] WORKDIR /app/api                                                                                            0.0s
 => [stage-1 3/7] COPY --from=node /usr/local/bin/node /usr/local/bin/node                                                           0.3s
 => [stage-1 4/7] COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules                                           0.5s
 => [stage-1 5/7] COPY api/ /app/api/                                                                                                0.1s
 => ERROR [stage-1 6/7] RUN npm install -g dagre                                                                                     0.3s
------
 > [stage-1 6/7] RUN npm install -g dagre:
#6 0.180 /bin/sh: 1: npm: not found
------
failed to solve: rpc error: code = Unknown desc = process "/bin/sh -c npm install -g dagre" did not complete successfully: exit code: 127
[root@rgm-s-dwhapp01 table-dependency-viewer]#
