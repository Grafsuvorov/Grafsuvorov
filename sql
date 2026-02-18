
ls: cannot access '/app/scripts': No such file or directory
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose up -d --force-recreate
[+] Running 2/2
 ⠿ Container table-dependency-viewer-frontend-1  Started                                                                             0.9s
 ⠿ Container table-dependency-viewer-api-1       Started                                                                             0.9s
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api ls /app/scripts
dagre_layout.cjs
[root@rgm-s-dwhapp01 table-dependency-viewer]# curl -s "http://localhost:5312/api/graph/diagnostics?include_any=true" | head
Proxy Authentication Required[root@rgm-s-dwhapp01 table-dependency-viewer]# curl -i "http://localhost:5312/api/graph/diagnostics?include_any=true" | head -n 20
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100    29  100    29    0     0   3254      0 --:--:-- --:--:-- --:--:--  3625
HTTP/1.1 407 Proxy Authentication Required
Proxy-Authenticate: NTLM
Proxy-Authenticate: Negotiate
Content-Length: 29

Proxy Authentication Required[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs --tail=50 api
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
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 975, in _dagre_layout
table-dependency-viewer-api-1  |     result = subprocess.run(
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/subprocess.py", line 548, in run
table-dependency-viewer-api-1  |     with Popen(*popenargs, **kwargs) as process:
table-dependency-viewer-api-1  |          ^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/subprocess.py", line 1026, in __init__
table-dependency-viewer-api-1  |     self._execute_child(args, executable, preexec_fn, close_fds,
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/subprocess.py", line 1955, in _execute_child
table-dependency-viewer-api-1  |     raise child_exception_type(errno_num, err_msg, err_filename)
table-dependency-viewer-api-1  | FileNotFoundError: [Errno 2] No such file or directory: 'node'
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56555 - "GET /api/incidents/history?days=7&limit=10 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56553 - "GET /api/incidents/timeline?days=7 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56559 - "GET /api/dq/summary?days=7&delta=10 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56556 - "GET /api/metrics HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56555 - "GET /api/dq/alerts?days=7&delta=10&limit=8 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56554 - "GET /api/incidents/active HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     10.13.144.106:56558 - "GET /api/night-summary?days=30&limit=10 HTTP/1.1" 200 OK
