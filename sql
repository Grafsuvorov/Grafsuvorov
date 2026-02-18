[root@rgm-s-dwhapp01 table-dependency-viewer]# curl -x "" -i "http://localhost:5312/api/graph/diagnostics?include_any=true" | head -n 20
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    21  100    21    0     0    164      0 --:--:-- --:--:-- --:--:--   165
HTTP/1.1 500 Internal Server Error
date: Wed, 18 Feb 2026 16:23:43 GMT
server: uvicorn
content-length: 21
content-type: text/plain; charset=utf-8

Internal Server Error[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api node -v
v20.20.0
[root@rgm-s-dwhapp01 table-dependency-viewer]#  docker compose logs --tail=50 api
table-dependency-viewer-api-1  |     raw_response = await run_endpoint_function(
table-dependency-viewer-api-1  |                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 314, in run_endpoint_function
table-dependency-viewer-api-1  |     return await run_in_threadpool(dependant.call, **values)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/concurrency.py", line 32, in run_in_threadpool
table-dependency-viewer-api-1  |     return await anyio.to_thread.run_sync(func)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/anyio/to_thread.py", line 63, in run_sync
table-dependency-viewer-api-1  |     return await get_async_backend().run_sync_in_worker_thread(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 2502, in run_sync_in_worker_thread
table-dependency-viewer-api-1  |     return await future
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 986, in run
table-dependency-viewer-api-1  |     result = context.run(func, *args)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 2971, in get_graph_diagnostics
table-dependency-viewer-api-1  |     snapshot = get_graph_snapshot()
table-dependency-viewer-api-1  |                ^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 1280, in get_graph_snapshot
table-dependency-viewer-api-1  |     snapshot = build_graph_snapshot()
table-dependency-viewer-api-1  |                ^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 1253, in build_graph_snapshot
table-dependency-viewer-api-1  |     entity_layout = _dagre_layout(entity_layout_nodes, entity_edges, rankdir="LR")
table-dependency-viewer-api-1  |                     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 982, in _dagre_layout
table-dependency-viewer-api-1  |     raise RuntimeError(f"dagre layout failed: {result.stderr.strip()}")
table-dependency-viewer-api-1  | RuntimeError: dagre layout failed: node:internal/modules/cjs/loader:1210
table-dependency-viewer-api-1  |   throw err;
table-dependency-viewer-api-1  |   ^
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | Error: Cannot find module 'dagre'
table-dependency-viewer-api-1  | Require stack:
table-dependency-viewer-api-1  | - /app/scripts/dagre_layout.cjs
table-dependency-viewer-api-1  |     at Module._resolveFilename (node:internal/modules/cjs/loader:1207:15)
table-dependency-viewer-api-1  |     at Module._load (node:internal/modules/cjs/loader:1038:27)
table-dependency-viewer-api-1  |     at Module.require (node:internal/modules/cjs/loader:1289:19)
table-dependency-viewer-api-1  |     at require (node:internal/modules/helpers:182:18)
table-dependency-viewer-api-1  |     at Object.<anonymous> (/app/scripts/dagre_layout.cjs:2:15)
table-dependency-viewer-api-1  |     at Module._compile (node:internal/modules/cjs/loader:1521:14)
table-dependency-viewer-api-1  |     at Module._extensions..js (node:internal/modules/cjs/loader:1623:10)
table-dependency-viewer-api-1  |     at Module.load (node:internal/modules/cjs/loader:1266:32)
table-dependency-viewer-api-1  |     at Module._load (node:internal/modules/cjs/loader:1091:12)
table-dependency-viewer-api-1  |     at Function.executeUserEntryPoint [as runMain] (node:internal/modules/run_main:164:12) {
table-dependency-viewer-api-1  |   code: 'MODULE_NOT_FOUND',
table-dependency-viewer-api-1  |   requireStack: [ '/app/scripts/dagre_layout.cjs' ]
table-dependency-viewer-api-1  | }
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | Node.js v20.20.0
