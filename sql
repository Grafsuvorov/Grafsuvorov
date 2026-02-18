
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs --tail=80 api
table-dependency-viewer-api-1  | FileNotFoundError: /app/scripts/dagre_layout.cjs
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54539 - "GET /api/incidents/history?days=7&limit=10 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54537 - "GET /api/incidents/timeline?days=7 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54543 - "GET /api/dq/summary?days=7&delta=10 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54540 - "GET /api/metrics HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54539 - "GET /api/dq/alerts?days=7&delta=10&limit=8 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54538 - "GET /api/incidents/active HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:54541 - "GET /api/night-summary?days=30&limit=10 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     127.0.0.1:48988 - "GET /api/graph/diagnostics?include_any=true HTTP/1.1" 500 Internal Server Error
table-dependency-viewer-api-1  | ERROR:    Exception in ASGI application
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/protocols/http/httptools_impl.py", line 416, in run_asgi
table-dependency-viewer-api-1  |     result = await app(  # type: ignore[func-returns-value]
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/middleware/proxy_headers.py", line 60, in __call__
table-dependency-viewer-api-1  |     return await self.app(scope, receive, send)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/applications.py", line 1134, in __call__
table-dependency-viewer-api-1  |     await super().__call__(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/applications.py", line 107, in __call__
table-dependency-viewer-api-1  |     await self.middleware_stack(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 186, in __call__
table-dependency-viewer-api-1  |     raise exc
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 164, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, _send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/cors.py", line 87, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/exceptions.py", line 63, in __call__
table-dependency-viewer-api-1  |     await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
table-dependency-viewer-api-1  |     raise exc
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
table-dependency-viewer-api-1  |     await app(scope, receive, sender)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/middleware/asyncexitstack.py", line 18, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 716, in __call__
table-dependency-viewer-api-1  |     await self.middleware_stack(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 736, in app
table-dependency-viewer-api-1  |     await route.handle(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 290, in handle
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 119, in app
table-dependency-viewer-api-1  |     await wrap_app_handling_exceptions(app, request)(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
table-dependency-viewer-api-1  |     raise exc
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
table-dependency-viewer-api-1  |     await app(scope, receive, sender)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 105, in app
table-dependency-viewer-api-1  |     response = await f(request)
table-dependency-viewer-api-1  |                ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 424, in app
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
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 958, in _dagre_layout
table-dependency-viewer-api-1  |     raise FileNotFoundError(script_path)
table-dependency-viewer-api-1  | FileNotFoundError: /app/scripts/dagre_layout.cjs
