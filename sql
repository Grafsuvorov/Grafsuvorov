[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs -f api
table-dependency-viewer-api-1  | BOOT FILE: /app/api/main.py
table-dependency-viewer-api-1  | /app/api/main.py:62: UserWarning: Field name "s                      chema" in "DependencyItem" shadows an attribute in parent "BaseModel"
table-dependency-viewer-api-1  |   class DependencyItem(BaseModel):
table-dependency-viewer-api-1  | Reg
table-dependency-viewer-api-1  | INFO:     Started server process [1]
table-dependency-viewer-api-1  | INFO:     Waiting for application startup.
table-dependency-viewer-api-1  | META COUNT: 0
table-dependency-viewer-api-1  | META SAMPLE: []
table-dependency-viewer-api-1  | ⚠️ rebuilding orderbreaches cache
table-dependency-viewer-api-1  | INFO:     Application startup complete.
table-dependency-viewer-api-1  | INFO:     Uvicorn running on http://0.0.0.0:800                      0 (Press CTRL+C to quit)
table-dependency-viewer-api-1  | INFO:     10.13.144.106:64523 - "GET /api/healt                      h HTTP/1.1" 404 Not Found
table-dependency-viewer-api-1  | INFO:     10.13.144.106:64523 - "GET /favicon.i                      co HTTP/1.1" 404 Not Found


META_PARENT_DIRS = [Path(r"C:\\Users\\SuvorovND\\GIT\\meta_info\\database\\greenplum\\schema_name\\tech_etl\\etl_loads_entity")]
