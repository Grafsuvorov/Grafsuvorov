[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose build --no-cache api \
>     --build-arg HTTP_PROXY=http://rgm-s-rtproxnlb01.hq.root.ad:1010 \
>     --build-arg HTTPS_PROXY=http://rgm-s-rtproxnlb01.hq.root.ad:1010
[+] Building 128.3s (14/15)
 => [internal] load build definition from Dockerfile                                                                                 0.0s
 => => transferring dockerfile: 1.20kB                                                                                               0.0s
 => [internal] load metadata for docker.io/library/node:20-slim                                                                      1.4s
 => [internal] load metadata for docker.io/library/python:3.11-slim                                                                  0.0s
 => [internal] load .dockerignore                                                                                                    0.0s
 => => transferring context: 162B                                                                                                    0.0s
 => [stage-1 1/8] FROM docker.io/library/python:3.11-slim                                                                            0.0s
 => [internal] load build context                                                                                                    0.0s
 => => transferring context: 2.10kB                                                                                                  0.0s
 => CACHED [node 1/2] FROM docker.io/library/node:20-slim@sha256:c6585df72c34172bebd8d36abed961e231d7d3b5cee2e01294c4495e8a03f687    0.0s
 => CACHED [stage-1 2/8] WORKDIR /app/api                                                                                            0.0s
 => [node 2/2] RUN npm config set proxy http://rgm-s-rtproxnlb01.hq.root.ad:1010 && npm config set https-proxy http://rgm-s-rtproxn  2.4s
 => [stage-1 3/8] COPY --from=node /usr/local/bin/node /usr/local/bin/node                                                           0.3s
 => [stage-1 4/8] COPY --from=node /usr/local/bin/npm /usr/local/bin/npm                                                             0.2s
 => [stage-1 5/8] COPY --from=node /usr/local/bin/npx /usr/local/bin/npx                                                             0.2s
 => [stage-1 6/8] COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules                                           0.6s
 => [stage-1 7/8] COPY api/ /app/api/                                                                                                0.1s
 => [stage-1 8/8] RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple --trusted-host=nx.sib.rual.ru --trusted-host=pyp  122.6s
 => => # WARNING: Retrying (Retry(total=94, connect=None, read=None, redirect=None, status=None)) after connection broken by 'ProxyError(
 => => # 'Cannot connect to proxy.', OSError('Tunnel connection failed: 407 Proxy Authentication Required'))': /simple/fastapi/
 => => # WARNING: Retrying (Retry(total=93, connect=None, read=None, redirect=None, status=None)) after connection broken by 'ProxyError(
 => => # 'Cannot connect to proxy.', OSError('Tunnel connection failed: 407 Proxy Authentication Required'))': /simple/fastapi/
 => => # WARNING: Retrying (Retry(total=92, connect=None, read=None, redirect=None, status=None)) after connection broken by 'ProxyError(
 => => # 'Cannot connect to proxy.', OSError('Tunnel connection failed: 407 Proxy Authentication Required'))': /simple/fastapi/
