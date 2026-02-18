FROM python:3.11-slim

WORKDIR /app/api

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

COPY api/ /app/api/

RUN pip install --index-url=https://pypi.nx.sib.rual.ru/simple \
    --trusted-host=nx.sib.rual.ru --trusted-host=pypi.nx.sib.rual.ru \
    --retries 100 --timeout 600000 --no-cache-dir \
     fastapi "uvicorn[standard]" sqlalchemy psycopg2-binary pyyaml openpyxl

EXPOSE 8000

CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "5312"]


[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose ps
NAME                                 COMMAND                  SERVICE             STATUS              PORTS
table-dependency-viewer-api-1        "uvicorn api.main:ap…"   api                 exited (1)
table-dependency-viewer-frontend-1   "/docker-entrypoint.…"   frontend            running             0.0.0.0:15312->80/tcp
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs -f api
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/bin/uvicorn", line 8, in <module>
table-dependency-viewer-api-1  |     sys.exit(main())
table-dependency-viewer-api-1  |              ^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1485, in __call__
table-dependency-viewer-api-1  |     return self.main(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1406, in main
table-dependency-viewer-api-1  |     rv = self.invoke(ctx)
table-dependency-viewer-api-1  |          ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1269, in invoke
table-dependency-viewer-api-1  |     return ctx.invoke(self.callback, **ctx.params)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 824, in invoke
table-dependency-viewer-api-1  |     return callback(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 433, in main
table-dependency-viewer-api-1  |     run(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 606, in run
table-dependency-viewer-api-1  |     server.run()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/server.py", line 75, in run
table-dependency-viewer-api-1  |     return asyncio_run(self.serve(sockets=sockets), loop_factory=self.config.get_loop_factory())
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/_compat.py", line 30, in asyncio_run
table-dependency-viewer-api-1  |     return runner.run(main)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/asyncio/runners.py", line 118, in run
table-dependency-viewer-api-1  |     return self._loop.run_until_complete(task)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "uvloop/loop.pyx", line 1518, in uvloop.loop.Loop.run_until_complete
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/server.py", line 79, in serve
table-dependency-viewer-api-1  |     await self._serve(sockets)
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/server.py", line 86, in _serve
table-dependency-viewer-api-1  |     config.load()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/config.py", line 441, in load
table-dependency-viewer-api-1  |     self.loaded_app = import_from_string(self.app)
table-dependency-viewer-api-1  |                       ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 22, in import_from_string
table-dependency-viewer-api-1  |     raise exc from None
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 19, in import_from_string
table-dependency-viewer-api-1  |     module = importlib.import_module(module_str)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/importlib/__init__.py", line 126, in import_module
table-dependency-viewer-api-1  |     return _bootstrap._gcd_import(name[level:], package, level)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1126, in _find_and_load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1140, in _find_and_load_unlocked
table-dependency-viewer-api-1  | ModuleNotFoundError: No module named 'api'
