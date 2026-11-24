WARNING
Удалённый SQL-файл `dds/dds.unit_balance_operating_periods.sql` не выполнялся в DEV; проверьте влияние удаления на объект и зависимости; Удалённый SQL-файл `dm_calc/dm_calc.fixed_asset_operations.sql` не выполнялся в DEV; проверьте влияние удаления на объект и зависимости; Ключевые поля не найдены автоматически

khin@rusal.com: chat_not_found
table-dependency-viewer-api-1  | INFO:     172.22.0.3:56508 - "GET /api/admin/pr                               ototype-review/run-status/0521c01cb65e4d748242d1c38e96722c HTTP/1.1" 200 OK
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs --tail=200 api
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/applications.py", line 1224, in __call__
table-dependency-viewer-api-1  |     await super().__call__(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/applications.py", line 96, in __call__
table-dependency-viewer-api-1  |     await self.middleware_stack(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 186, in __call__
table-dependency-viewer-api-1  |     raise exc
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/errors.py", line 164, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, _send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/telemetry/_asgi.py", line 151, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/_body_limit.py", line 80, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/base.py", line 203, in __call__
table-dependency-viewer-api-1  |     response = await self.dispatch_func(request, call_next)
table-dependency-viewer-api-1  |                ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/auth.py", line 804, in auth_middleware
table-dependency-viewer-api-1  |     return await call_next(request)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/base.py", line 179, in call_next
table-dependency-viewer-api-1  |     raise app_exc from app_exc.__cause__ or app_exc.__context__
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/base.py", line 149, in coro
table-dependency-viewer-api-1  |     await self.app(scope, receive_or_disconnect, send_no_error)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/cors.py", line 91, in __call__
table-dependency-viewer-api-1  |     await self.simple_response(scope, receive, send, request_headers=headers)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/cors.py", line 149, in simple_response
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/middleware/exceptions.py", line 63, in __call__
table-dependency-viewer-api-1  |     await wrap_app_handling_exceptions(self.app, conn)(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
table-dependency-viewer-api-1  |     raise exc
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
table-dependency-viewer-api-1  |     await app(scope, receive, sender)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/middleware/asyncexitstack.py", line 18, in __call__
table-dependency-viewer-api-1  |     await self.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/routing.py", line 683, in __call__
table-dependency-viewer-api-1  |     await self.middleware_stack(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 2929, in app
table-dependency-viewer-api-1  |     await route.handle(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 1916, in handle
table-dependency-viewer-api-1  |     await self.original_router.handle(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 3015, in handle
table-dependency-viewer-api-1  |     await included_router._handle_selected(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 1945, in _handle_selected
table-dependency-viewer-api-1  |     await original_route.handle(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 1373, in handle
table-dependency-viewer-api-1  |     await effective_context.app(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 175, in app
table-dependency-viewer-api-1  |     await wrap_app_handling_exceptions(app, request)(scope, receive, send)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 53, in wrapped_app
table-dependency-viewer-api-1  |     raise exc
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/_exception_handler.py", line 42, in wrapped_app
table-dependency-viewer-api-1  |     await app(scope, receive, sender)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 161, in app
table-dependency-viewer-api-1  |     response = await f(request)
table-dependency-viewer-api-1  |                ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 762, in app
table-dependency-viewer-api-1  |     raw_response = await run_endpoint_function(
table-dependency-viewer-api-1  |                    ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/routing.py", line 383, in run_endpoint_function
table-dependency-viewer-api-1  |     return await run_in_threadpool(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/starlette/concurrency.py", line 34, in run_in_threadpool
table-dependency-viewer-api-1  |     return await anyio.to_thread.run_sync(func)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/anyio/to_thread.py", line 65, in run_sync
table-dependency-viewer-api-1  |     return await get_async_backend().run_sync_in_worker_thread(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 2779, in run_sync_in_worker_thread
table-dependency-viewer-api-1  |     return await future
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/anyio/_backends/_asyncio.py", line 1124, in run
table-dependency-viewer-api-1  |     result = context.run(func, *args)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/fastapi/telemetry/_api.py", line 244, in _run_sync_endpoint
table-dependency-viewer-api-1  |     return function(**arguments)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/auth.py", line 1049, in write_audit_event
table-dependency-viewer-api-1  |     user = get_current_user_from_request(request)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/auth.py", line 789, in get_current_user_from_request
table-dependency-viewer-api-1  |     user = _get_user_by_email(email)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/auth.py", line 186, in _get_user_by_email
table-dependency-viewer-api-1  |     row = conn.execute(
table-dependency-viewer-api-1  |           ^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1494, in execute
table-dependency-viewer-api-1  |     return meth(
table-dependency-viewer-api-1  |            ^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/sql/elements.py", line 534, in _execute_on_connection
table-dependency-viewer-api-1  |     return connection._execute_clauseelement(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1714, in _execute_clauseelement
table-dependency-viewer-api-1  |     ret = self._execute_context(
table-dependency-viewer-api-1  |           ^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1868, in _execute_context
table-dependency-viewer-api-1  |     return self._exec_single_context(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1996, in _exec_single_context
table-dependency-viewer-api-1  |     self._handle_dbapi_exception(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 2351, in _handle_dbapi_exception
table-dependency-viewer-api-1  |     raise sqlalchemy_exception.with_traceback(exc_info[2]) from e
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/base.py", line 1977, in _exec_single_context
table-dependency-viewer-api-1  |     self.dialect.do_execute(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/sqlalchemy/engine/default.py", line 1192, in do_execute
table-dependency-viewer-api-1  |     cursor.execute(statement, parameters)
table-dependency-viewer-api-1  | sqlalchemy.exc.OperationalError: (psycopg2.OperationalError) server closed the connection unexpectedly
table-dependency-viewer-api-1  |        This probably means the server terminated abnormally
table-dependency-viewer-api-1  |        before or while processing the request.
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | [SQL:
table-dependency-viewer-api-1  |                 SELECT id, email, username, role, password_hash, password_salt, is_active
table-dependency-viewer-api-1  |                 FROM tech_etl.app_users
table-dependency-viewer-api-1  |                 WHERE lower(email) = %(email_normalized)s
table-dependency-viewer-api-1  |                 LIMIT 1
table-dependency-viewer-api-1  |                 ]
table-dependency-viewer-api-1  | [parameters: {'email_normalized': 'nikita.suvorov@rusal.com'}]
table-dependency-viewer-api-1  | (Background on this error at: https://sqlalche.me/e/21/e3q8)
table-dependency-viewer-api-1  | INFO:     172.22.0.3:41976 - "GET /auth/me HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:41972 - "GET /api/admin/prototype-review/source-load/servers HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:41988 - "POST /api/admin/prototype-review/run-start HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:41978 - "GET /api/admin/prototype-review/source-load/tables?target_schema=stg HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:41992 - "GET /api/admin/prototype-review/run-status/407b935c4994454ab585685afee9c4c9 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42000 - "GET /api/admin/prototype-review/run-status/407b935c4994454ab585685afee9c4c9 HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42360 - "POST /auth/audit/event HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42362 - "GET /api/admin/prototype-review/source-load/servers HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42364 - "GET /auth/me HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42366 - "GET /api/admin/prototype-review/source-load/tables?target_schema=stg HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42380 - "POST /api/admin/prototype-review/run-start HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42384 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42404 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42412 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42416 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42418 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42426 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42430 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42434 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42436 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42442 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42450 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42452 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42458 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42460 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42468 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42472 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42476 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42478 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42482 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42490 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42492 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42498 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42500 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42502 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42512 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42514 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42520 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42522 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42524 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42534 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42536 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42540 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42544 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42546 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42554 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42558 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42562 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42564 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42576 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42578 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42582 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42586 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42588 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42596 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42600 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42604 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42606 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42610 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42618 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42622 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42626 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42628 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42632 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42640 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42642 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42648 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42650 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42652 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42662 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42664 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42672 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42676 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42684 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42686 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42692 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42694 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42696 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42708 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42710 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42716 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42738 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:42752 - "GET /api/admin/prototype-review/run-status/f0df244ed8714cf1bf40a60822d0a99c HTTP/1.1" 200 OK
