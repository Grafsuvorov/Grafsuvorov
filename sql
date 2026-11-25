table-dependency-viewer-api-1  |           )
table-dependency-viewer-api-1  |         ORDER BY size_bytes DESC NULLS LAST, n.nspname, c.relname
table-dependency-viewer-api-1  |     ]
table-dependency-viewer-api-1  | (Background on this error at: https://sqlalche.me/e/21/e3q8)
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54452 - "POST /auth/audit/event HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54458 - "GET /auth/me HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54454 - "GET /api/admin/prototype-review/source-load/servers HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54456 - "GET /api/admin/prototype-review/source-load/tables?target_schema=stg HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     [OHD DB CHECK] START source=OHD_DEV_DATABASE_URL host=res-s-khgpm01.resource.local port=5432 database=dwh user=gpetl
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54480 - "POST /api/admin/prototype-review/run-start HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54484 - "GET /api/admin/prototype-review/run-status/28eb93c0901d422580bd661550ade655 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     [OHD DB CHECK] OK source=OHD_DEV_DATABASE_URL server=10.66.229.231/32 port=5432 database=dwh user=gpetl duration=0.033s
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54500 - "GET /api/admin/prototype-review/run-status/28eb93c0901d422580bd661550ade655 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | BotX completion notification skipped for Nikita.Suvorov@rusal.com: HTTP 401: {"reason":"unauthorized","status":"error","errors":[],"error_data":{}}
table-dependency-viewer-api-1  | BotX completion notification for Nikita.Suvorov@rusal.com: error
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54518 - "POST /api/admin/dev-meta/generate HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54530 - "POST /api/admin/dev-meta/lock HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54532 - "GET /api/admin/dev-meta/files?schema_name=dm HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54618 - "POST /api/admin/dev-meta/validate HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54636 - "POST /api/admin/dev-meta/save HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54640 - "GET /api/admin/dev-meta/files?schema_name=dm HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54644 - "POST /api/admin/dev-meta/run-dag HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54646 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54650 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54688 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54706 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54730 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54744 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54752 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54776 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     [OHD DB CHECK] START source=OHD_DEV_DATABASE_URL host=res-s-khgpm01.resource.local port=5432 database=dwh user=gpetl
table-dependency-viewer-api-1  | INFO:     [OHD DB CHECK] OK source=OHD_DEV_DATABASE_URL server=10.66.229.231/32 port=5432 database=dwh user=gpetl duration=0.029s
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54794 - "POST /api/admin/prototype-review/check-table HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54810 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54836 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54846 - "POST /api/admin/prototype-review/create-issue HTTP/1.1" 400 Bad Request
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54862 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54884 - "POST /api/admin/prototype-review/create-issue HTTP/1.1" 400 Bad Request
table-dependency-viewer-api-1  | INFO:     172.22.0.3:54898 - "POST /api/admin/dev-meta/dag-status HTTP/1.1" 200 OK
