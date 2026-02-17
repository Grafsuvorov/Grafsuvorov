[root@rgm-s-dwhapp01 ~]# cd table-dependency-viewer
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose build
[+] Building 1.5s (13/14)
 => [table-dependency-viewer_frontend internal] load build definition fro  0.0s
 => => transferring dockerfile: 372B                                       0.0s
 => [table-dependency-viewer_api internal] load build definition from Doc  0.0s
 => => transferring dockerfile: 624B                                       0.0s
 => [table-dependency-viewer_api internal] load metadata for docker.io/li  1.4s
 => CANCELED [table-dependency-viewer_frontend internal] load metadata fo  1.5s
 => CANCELED [table-dependency-viewer_frontend internal] load metadata fo  1.5s
 => [table-dependency-viewer_api internal] load .dockerignore              0.0s
 => => transferring context: 162B                                          0.0s
 => [table-dependency-viewer_api 1/5] FROM docker.io/library/python:3.11-  0.0s
 => [table-dependency-viewer_api internal] load build context              0.0s
 => => transferring context: 1.09kB                                        0.0s
 => [table-dependency-viewer_api  1/12] FROM docker.io/library/python:3.1  0.0s
 => CACHED [table-dependency-viewer_api  2/12] WORKDIR /app                0.0s
 => CACHED [table-dependency-viewer_api 2/5] WORKDIR /app                  0.0s
 => CACHED [table-dependency-viewer_api 3/5] COPY api/ /app/api/           0.0s
 => ERROR [table-dependency-viewer_api 4/5] COPY etl_loads_entity/ /app/e  0.0s
------
 > [table-dependency-viewer_api 4/5] COPY etl_loads_entity/ /app/etl_loads_entit                                            y/:
------
failed to solve: rpc error: code = Unknown desc = failed to compute cache key: f                                            ailed to calculate checksum of ref 446fed7b-4e6f-4b3b-a2fa-04c3760f6aff::xbzvlf9                                            8byudtzpg9k3vuk0c4: "/etl_loads_entity": not found
[root@rgm-s-dwhapp01 table-dependency-viewer]# ^C
[root@rgm-s-dwhapp01 table-dependency-viewer]# cd meta_info/
[root@rgm-s-dwhapp01 meta_info]# cd database/
[root@rgm-s-dwhapp01 database]# cd greenplum/
[root@rgm-s-dwhapp01 greenplum]# cd schema_name/
[root@rgm-s-dwhapp01 schema_name]# cd tech_etl/
[root@rgm-s-dwhapp01 tech_etl]# cd etl_loads_entity/
[root@rgm-s-dwhapp01 etl_loads_entity]# ^C
[root@rgm-s-dwhapp01 etl_loads_entity]# docker compose build
[+] Building 5.2s (16/22)
 => [table-dependency-viewer_frontend internal] load build definition from Dockerfile                       0.0s
 => => transferring dockerfile: 372B                                                                        0.0s
 => [table-dependency-viewer_api internal] load build definition from Dockerfile                            0.0s
 => => transferring dockerfile: 577B                                                                        0.0s
 => [table-dependency-viewer_api internal] load metadata for docker.io/library/python:3.11-slim             2.0s
 => [table-dependency-viewer_frontend internal] load metadata for docker.io/library/nginx:alpine            3.9s
 => [table-dependency-viewer_frontend internal] load metadata for docker.io/library/node:20-alpine          3.8s
 => [table-dependency-viewer_api internal] load .dockerignore                                               0.0s
 => => transferring context: 162B                                                                           0.0s
 => [table-dependency-viewer_api 1/4] FROM docker.io/library/python:3.11-slim@sha256:0b23cfb7425d065008b77  0.0s
 => [table-dependency-viewer_api internal] load build context                                               0.0s
 => => transferring context: 343.69kB                                                                       0.0s
 => CACHED [table-dependency-viewer_api 2/4] WORKDIR /app                                                   0.0s
 => [table-dependency-viewer_api 3/4] COPY api/ /app/api/                                                   0.1s
 => CANCELED [table-dependency-viewer_api 4/4] RUN pip install --index-url=https://pypi.nx.sib.rual.ru/sim  3.0s
 => [table-dependency-viewer_frontend internal] load .dockerignore                                          0.0s
 => => transferring context: 162B                                                                           0.0s
 => CANCELED [table-dependency-viewer_frontend build 1/6] FROM docker.io/library/node:20-alpine@sha256:09e  0.9s
 => => resolve docker.io/library/node:20-alpine@sha256:09e2b3d9726018aecf269bd35325f46bf75046a643a66d28360  0.0s
 => => sha256:09e2b3d9726018aecf269bd35325f46bf75046a643a66d28360ec71132750ec8 7.67kB / 7.67kB              0.0s
 => => sha256:c3324aa3efea082c8d294a93b97ba82adc5498a202bd48802f5a8af152e7dd9e 1.72kB / 1.72kB              0.0s
 => => sha256:458b0b7c1c6027b37124839bf527a5c54936ab27a9c9643051a3d801c4560a6c 6.52kB / 6.52kB              0.0s
 => => sha256:589002ba0eaed121a1dbf42f6648f29e5be55d5c8a6ee0f8eaa0285cc21ac153 0B / 3.86MB                  1.2s
 => => sha256:ad6d96c196e3198e14ea37df8bba4f54bf92fb525eb65e49fa4027c7dee13f80 0B / 42.78MB                 1.2s
 => => sha256:eb87f4721c91769ed5206f34a9ab6ec98fc1d5235c12c2fc956665b1155e9ecb 0B / 1.26MB                  1.2s
 => CANCELED [table-dependency-viewer_frontend stage-1 1/3] FROM docker.io/library/nginx:alpine@sha256:1d1  0.8s
 => => resolve docker.io/library/nginx:alpine@sha256:1d13701a5f9f3fb01aaa88cef2344d65b6b5bf6b7d9fa4cf0dca5  0.0s
 => => sha256:589002ba0eaed121a1dbf42f6648f29e5be55d5c8a6ee0f8eaa0285cc21ac153 0B / 3.86MB                  1.2s
 => => sha256:1d13701a5f9f3fb01aaa88cef2344d65b6b5bf6b7d9fa4cf0dca557a8d7702ba 10.33kB / 10.33kB            0.0s
 => => sha256:c032460d1fd73978317479ba23c37bcb57d93156cab122eb3c54b8e4bdc292fa 2.50kB / 2.50kB              0.0s
 => => sha256:b76de378d57272a1dd9091a05dd548a3639dfb792ebdbf95d06704d2950afdea 11.65kB / 11.65kB            0.0s
 => [table-dependency-viewer_frontend internal] load build context                                          0.8s
 => => transferring context: 22.41MB                                                                        0.8s
 => ERROR [table-dependency-viewer_frontend stage-1 2/3] COPY nginx.conf /etc/nginx/conf.d/default.conf     0.0s
------
 > [table-dependency-viewer_frontend stage-1 2/3] COPY nginx.conf /etc/nginx/conf.d/default.conf:
------
failed to solve: rpc error: code = Unknown desc = failed to compute cache key: failed to calculate checksum of re           f 446fed7b-4e6f-4b3b-a2fa-04c3760f6aff::ufxrg06qjyjdzn2b7x4rpqns9: "/nginx.conf": not found
