
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
[root@rgm-s-dwhapp01 table-dependency-viewer]# ^C
[root@rgm-s-dwhapp01 table-dependency-viewer]# ls -la docker-compose*.yml
-rwxrwxrwx. 1 root root 330 Feb 17 18:27 docker-compose.yml
[root@rgm-s-dwhapp01 table-dependency-viewer]# rg -n "Dockerfile.orig|etl_loads_entity" -S api Dockerfile docker-compose.yml
-bash: rg: command not found
[root@rgm-s-dwhapp01 table-dependency-viewer]# DOCKER_BUILDKIT=0 docker compose build --no-cache --progress=plain api
Sending build context to Docker daemon  2.888MB
Step 1/8 : FROM python:3.11-slim
3.11-slim: Pulling from library/python
0c8d55a45c0d: Already exists
64faa99400e1: Already exists
8cbc47ff628d: Already exists
d85099f0969e: Already exists
Digest: sha256:0b23cfb7425d065008b778022a17b1551c82f8b4866ee5a7a200084b7e2eafbf
Status: Downloaded newer image for python:3.11-slim
 ---> 466c0182639b
Step 2/8 : WORKDIR /app
 ---> Running in 9d22143c5afb
 ---> Removed intermediate container 9d22143c5afb
 ---> 647f029fa824
Step 3/8 : ENV PYTHONDONTWRITEBYTECODE=1
 ---> Running in 13d6f0ee3938
 ---> Removed intermediate container 13d6f0ee3938
 ---> 2ad3996b3678
Step 4/8 : ENV PYTHONUNBUFFERED=1
 ---> Running in 80a5d05b7b99
 ---> Removed intermediate container 80a5d05b7b99
 ---> 5088e3a4189b
Step 5/8 : COPY api/ /app/api/
 ---> 9973812015fb
Step 6/8 : RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple     --trusted-host=nx.sib.rual.ru --trusted-host=pypi.nx.sib.rual.ru     --retries 100 --timeout 600000 --no-cache-dir      fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl
 ---> Running in f78beaf5391d
Looking in indexes: https://pypi.nx.sib.rual.ru/simple
Collecting fastapi
  Downloading https://pypi.nx.sib.rual.ru/packages/fastapi/0.129.0/fastapi-0.129.0-py3-none-any.whl (102 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 103.0/103.0 kB 1.6 MB/s eta 0:00:00
Collecting sqlalchemy
  Downloading https://pypi.nx.sib.rual.ru/packages/sqlalchemy/2.0.46/sqlalchemy-2.0.46-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (3.3 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 3.3/3.3 MB 2.0 MB/s eta 0:00:00
Collecting psycopg2-binary
  Downloading https://pypi.nx.sib.rual.ru/packages/psycopg2-binary/2.9.11/psycopg2_binary-2.9.11-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.whl (4.2 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 4.2/4.2 MB 1.6 MB/s eta 0:00:00
Collecting pyyaml
  Downloading https://pypi.nx.sib.rual.ru/packages/pyyaml/6.0.3/pyyaml-6.0.3-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (806 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 806.6/806.6 kB 1.8 MB/s eta 0:00:00
Collecting openpyxl
  Downloading https://pypi.nx.sib.rual.ru/packages/openpyxl/3.1.5/openpyxl-3.1.5-py2.py3-none-any.whl (250 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 250.9/250.9 kB 2.1 MB/s eta 0:00:00
Collecting uvicorn[standard]
  Downloading https://pypi.nx.sib.rual.ru/packages/uvicorn/0.41.0/uvicorn-0.41.0-py3-none-any.whl (68 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 68.8/68.8 kB 249.5 MB/s eta 0:00:00
Collecting starlette<1.0.0,>=0.40.0 (from fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/starlette/0.52.1/starlette-0.52.1-py3-none-any.whl (74 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 74.3/74.3 kB 241.9 MB/s eta 0:00:00
Collecting pydantic>=2.7.0 (from fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/pydantic/2.12.5/pydantic-2.12.5-py3-none-any.whl (463 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 463.6/463.6 kB 2.0 MB/s eta 0:00:00
Collecting typing-extensions>=4.8.0 (from fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/typing-extensions/4.15.0/typing_extensions-4.15.0-py3-none-any.whl (44 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 44.6/44.6 kB 231.5 MB/s eta 0:00:00
Collecting typing-inspection>=0.4.2 (from fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/typing-inspection/0.4.2/typing_inspection-0.4.2-py3-none-any.whl (14 kB)
Collecting annotated-doc>=0.0.2 (from fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/annotated-doc/0.0.4/annotated_doc-0.0.4-py3-none-any.whl (5.3 kB)
Collecting click>=7.0 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/click/8.3.1/click-8.3.1-py3-none-any.whl (108 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 108.3/108.3 kB 1.8 MB/s eta 0:00:00
Collecting h11>=0.8 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/h11/0.16.0/h11-0.16.0-py3-none-any.whl (37 kB)
Collecting httptools>=0.6.3 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/httptools/0.7.1/httptools-0.7.1-cp311-cp311-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl (456 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 456.6/456.6 kB 2.0 MB/s eta 0:00:00
Collecting python-dotenv>=0.13 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/python-dotenv/1.2.1/python_dotenv-1.2.1-py3-none-any.whl (21 kB)
Collecting uvloop>=0.15.1 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/uvloop/0.22.1/uvloop-0.22.1-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.manylinux_2_28_x86_64.whl (3.8 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 3.8/3.8 MB 2.0 MB/s eta 0:00:00
Collecting watchfiles>=0.20 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/watchfiles/1.1.1/watchfiles-1.1.1-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (456 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 456.1/456.1 kB 1.9 MB/s eta 0:00:00
Collecting websockets>=10.4 (from uvicorn[standard])
  Downloading https://pypi.nx.sib.rual.ru/packages/websockets/16.0/websockets-16.0-cp311-cp311-manylinux1_x86_64.manylinux_2_28_x86_64.manylinux_2_5_x86_64.whl (184 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 184.6/184.6 kB 1.6 MB/s eta 0:00:00
Collecting greenlet>=1 (from sqlalchemy)
  Downloading https://pypi.nx.sib.rual.ru/packages/greenlet/3.3.1/greenlet-3.3.1-cp311-cp311-manylinux_2_24_x86_64.manylinux_2_28_x86_64.whl (590 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 590.3/590.3 kB 1.7 MB/s eta 0:00:00
Collecting et-xmlfile (from openpyxl)
  Downloading https://pypi.nx.sib.rual.ru/packages/et-xmlfile/2.0.0/et_xmlfile-2.0.0-py3-none-any.whl (18 kB)
Collecting annotated-types>=0.6.0 (from pydantic>=2.7.0->fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/annotated-types/0.7.0/annotated_types-0.7.0-py3-none-any.whl (13 kB)
Collecting pydantic-core==2.41.5 (from pydantic>=2.7.0->fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/pydantic-core/2.41.5/pydantic_core-2.41.5-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl (2.1 MB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 2.1/2.1 MB 1.5 MB/s eta 0:00:00
Collecting anyio<5,>=3.6.2 (from starlette<1.0.0,>=0.40.0->fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/anyio/4.12.1/anyio-4.12.1-py3-none-any.whl (113 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 113.6/113.6 kB 1.9 MB/s eta 0:00:00
Collecting idna>=2.8 (from anyio<5,>=3.6.2->starlette<1.0.0,>=0.40.0->fastapi)
  Downloading https://pypi.nx.sib.rual.ru/packages/idna/3.11/idna-3.11-py3-none-any.whl (71 kB)
     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ 71.0/71.0 kB 245.7 MB/s eta 0:00:00
Installing collected packages: websockets, uvloop, typing-extensions, pyyaml, python-dotenv, psycopg2-binary, idna, httptools, h11, greenlet, et-xmlfile, click, annotated-types, annotated-doc, uvicorn, typing-inspection, sqlalchemy, pydantic-core, openpyxl, anyio, watchfiles, starlette, pydantic, fastapi
Successfully installed annotated-doc-0.0.4 annotated-types-0.7.0 anyio-4.12.1 click-8.3.1 et-xmlfile-2.0.0 fastapi-0.129.0 greenlet-3.3.1 h11-0.16.0 httptools-0.7.1 idna-3.11 openpyxl-3.1.5 psycopg2-binary-2.9.11 pydantic-2.12.5 pydantic-core-2.41.5 python-dotenv-1.2.1 pyyaml-6.0.3 sqlalchemy-2.0.46 starlette-0.52.1 typing-extensions-4.15.0 typing-inspection-0.4.2 uvicorn-0.41.0 uvloop-0.22.1 watchfiles-1.1.1 websockets-16.0
WARNING: Running pip as the 'root' user can result in broken permissions and conflicting behaviour with the system package manager. It is recommended to use a virtual environment instead: https://pip.pypa.io/warnings/venv

[notice] A new release of pip is available: 24.0 -> 26.0.1
[notice] To update, run: pip install --upgrade pip
 ---> Removed intermediate container f78beaf5391d
 ---> 3fbf54fa9bac
Step 7/8 : EXPOSE 8000
 ---> Running in 0b48dd07180a
 ---> Removed intermediate container 0b48dd07180a
 ---> 91332167c3f1
Step 8/8 : CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
 ---> Running in f15a85875246
 ---> Removed intermediate container f15a85875246
 ---> be2c778b5ed7
Successfully built be2c778b5ed7
Successfully tagged table-dependency-viewer_api:latest
