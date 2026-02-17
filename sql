[root@rgm-s-dwhapp01 ~]# ls
airflow                     N3R7A2C7_light      recipe.yml
anaconda-ks.cfg             N3R7A2C7_light_sbx  repos
audit_parse                 nodejs              ru_ru.json
copy_on_the_fly_s3.py       node_modules        sqlite
Dockerfile                  p312_cmp            sqlite-autoconf-3400100
get_parq_schema.py          package.json        table-dependency-viewer
gitlab_certs                package-lock.json   table-dependency-viewer.tar
glossary.yml                parq.py             telegraf.conf
khd_etl_greenplum           queries.py          tempor
lec1_frag4_current_time.py  rag_advct.2.0       venv
logs                        rag_advct.2.0.zip
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
 > [table-dependency-viewer_api 4/5] COPY etl_loads_entity/ /app/etl_loads_entit            y/:
------
failed to solve: rpc error: code = Unknown desc = failed to compute cache key: f            ailed to calculate checksum of ref 446fed7b-4e6f-4b3b-a2fa-04c3760f6aff::xbzvlf9            8byudtzpg9k3vuk0c4: "/etl_loads_entity": not found
[root@rgm-s-dwhapp01 table-dependency-viewer]# ^C
[root@rgm-s-dwhapp01 table-dependency-viewer]# cd meta_info/
[root@rgm-s-dwhapp01 meta_info]# cd database/
[root@rgm-s-dwhapp01 database]# cd greenplum/
[root@rgm-s-dwhapp01 greenplum]# cd schema_name/
[root@rgm-s-dwhapp01 schema_name]# cd tech_etl/
[root@rgm-s-dwhapp01 tech_etl]# cd etl_loads_entity/
[root@rgm-s-dwhapp01 etl_loads_entity]#
