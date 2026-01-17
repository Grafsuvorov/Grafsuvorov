ERROR:    Exception in ASGI application
Traceback (most recent call last):
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\protocols\http\h11_impl.py", line 403, in run_asgi
    result = await app(  # type: ignore[func-returns-value]
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\middleware\proxy_headers.py", line 60, in __call__
    return await self.app(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\applications.py", line 1054, in __call__
    await super().__call__(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\applications.py", line 113, in __call__
    await self.middleware_stack(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\middleware\errors.py", line 186, in __call__
    raise exc
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\middleware\errors.py", line 164, in __call__
    await self.app(scope, receive, _send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\middleware\cors.py", line 93, in __call__
    await self.simple_response(scope, receive, send, request_headers=headers)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\middleware\cors.py", line 144, in simple_response
    await self.app(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\middleware\exceptions.py", line 63, in __call__
    await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\_exception_handler.py", line 53, in wrapped_app
    raise exc
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\_exception_handler.py", line 42, in wrapped_app
    await app(scope, receive, sender)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\routing.py", line 716, in __call__
    await self.middleware_stack(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\routing.py", line 736, in app
    await route.handle(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\routing.py", line 290, in handle
    await self.app(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\routing.py", line 78, in app
    await wrap_app_handling_exceptions(app, request)(scope, receive, send)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\_exception_handler.py", line 53, in wrapped_app
    raise exc
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\_exception_handler.py", line 42, in wrapped_app
    await app(scope, receive, sender)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\routing.py", line 75, in app
    response = await f(request)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\routing.py", line 302, in app
    raw_response = await run_endpoint_function(
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\routing.py", line 215, in run_endpoint_function
    return await run_in_threadpool(dependant.call, **values)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\starlette\concurrency.py", line 38, in run_in_threadpool
    return await anyio.to_thread.run_sync(func)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\anyio\to_thread.py", line 56, in run_sync
    return await get_async_backend().run_sync_in_worker_thread(
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\anyio\_backends\_asyncio.py", line 2470, in run_sync_in_worker_thread
    return await future
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\anyio\_backends\_asyncio.py", line 967, in run
    result = context.run(func, *args)
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\main.py", line 1541, in get_graph_table
    snapshot = get_graph_snapshot()
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\main.py", line 451, in get_graph_snapshot
    snapshot = build_graph_snapshot()
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\main.py", line 429, in build_graph_snapshot
    entity_layout = _dagre_layout(entity_layout_nodes, entity_edges, rankdir="LR")
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\main.py", line 287, in _dagre_layout
    raise RuntimeError(f"dagre layout failed: {result.stderr.strip()}")
RuntimeError: dagre layout failed: file:///C:/Users/SuvorovND/GIT/table-dependency-viewer/scripts/dagre_layout.js:1
const fs = require("fs");
           ^

ReferenceError: require is not defined in ES module scope, you can use import instead
This file is being treated as an ES module because it has a '.js' file extension and 'C:\Users\SuvorovND\GIT\table-dependency-viewer\package.json' contains "type": "module". To treat it as a CommonJS script, rename it to use the '.cjs' file extension.
    at file:///C:/Users/SuvorovND/GIT/table-dependency-viewer/scripts/dagre_layout.js:1:12
    at ModuleJob.run (node:internal/modules/esm/module_job:263:25)
    at async ModuleLoader.import (node:internal/modules/esm/loader:540:24)
    at async asyncRunEntryPointWithESMLoader (node:internal/modules/run_main:117:5)

Node.js v20.19.4
