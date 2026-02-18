
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose build --no-cache api
[+] Building 20.8s (9/9) FINISHED
 => [internal] load build definition from Dockerfile                                                                               0.0s
 => => transferring dockerfile: 581B                                                                                               0.0s
 => [internal] load metadata for docker.io/library/python:3.11-slim                                                                0.0s
 => [internal] load .dockerignore                                                                                                  0.0s
 => => transferring context: 162B                                                                                                  0.0s
 => CACHED [1/4] FROM docker.io/library/python:3.11-slim                                                                           0.0s
 => [internal] load build context                                                                                                  0.0s
 => => transferring context: 343.23kB                                                                                              0.0s
 => [2/4] WORKDIR /app/api                                                                                                         0.1s
 => [3/4] COPY api/ /app/api/                                                                                                      0.1s
 => [4/4] RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple     --trusted-host=nx.sib.rual.ru --trusted-host=pypi.n  20.1s
 => exporting to image                                                                                                             0.4s
 => => exporting layers                                                                                                            0.4s
 => => writing image sha256:568663b24e1ec4881b0d7a9dc5f9c8b210aad9bc0befa08e73dab0263c995fee                                       0.0s
 => => naming to docker.io/library/table-dependency-viewer_api                                                                     0.0s
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose up -d --force-recreate
[+] Running 2/2
 ⠿ Container table-dependency-viewer-frontend-1  Started                                                                           0.7s
 ⠿ Container table-dependency-viewer-api-1       Started                                                                           0.7s
[root@rgm-s-dwhapp01 table-dependency-viewer]#
