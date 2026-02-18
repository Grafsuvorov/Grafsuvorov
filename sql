[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose build --no-cache api
[+] Building 0.0s (1/1) FINISHED
 => [internal] load build definition from Dockerfile                                                                                 0.0s
 => => transferring dockerfile: 1.23kB                                                                                               0.0s
failed to solve: rpc error: code = Unknown desc = dockerfile parse error on line 1: unknown instruction: stage:


stage: node + dagre
FROM node:20-slim AS node
ENV HTTP_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"
ENV HTTPS_PROXY="http://rgm-s-rtproxnlb01.hq.root.ad:1010"
RUN npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 \
&& npm config set https-proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 \
&& npm install -g dagre

# stage: python
FROM python:3.11-slim
WORKDIR /app/api
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

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
