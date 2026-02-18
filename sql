
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose ps
NAME                                 COMMAND                  SERVICE             STATUS              PORTS
table-dependency-viewer-api-1        "uvicorn main:app --…"   api                 running             0.0.0.0:5312->8000/tcp
table-dependency-viewer-frontend-1   "/docker-entrypoint.…"   frontend            running             0.0.0.0:15312->80/tcp
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs -f api
table-dependency-viewer-api-1  | BOOT FILE: /app/api/main.py
table-dependency-viewer-api-1  | /app/api/main.py:62: UserWarning: Field name "schema" in "DependencyItem" shadows an attribute in parent "BaseModel"
table-dependency-viewer-api-1  |   class DependencyItem(BaseModel):
table-dependency-viewer-api-1  | Reg
table-dependency-viewer-api-1  | INFO:     Started server process [1]
table-dependency-viewer-api-1  | INFO:     Waiting for application startup.
table-dependency-viewer-api-1  | META COUNT: 0
table-dependency-viewer-api-1  | META SAMPLE: []
table-dependency-viewer-api-1  | ⚠️ rebuilding orderbreaches cache
table-dependency-viewer-api-1  | INFO:     Application startup complete.
table-dependency-viewer-api-1  | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
