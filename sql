
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 448, in main
table-dependency-viewer-api-1  |     run(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 620, in run
table-dependency-viewer-api-1  |     config.load_app()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/config.py", line 434, in load_app
table-dependency-viewer-api-1  |     return import_from_string(self.app)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 19, in import_from_string
table-dependency-viewer-api-1  |     module = importlib.import_module(module_str)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/importlib/__init__.py", line 126, in import_module
table-dependency-viewer-api-1  |     return _bootstrap._gcd_import(name[level:], package, level)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1147, in _find_and_load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 690, in _load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap_external>", line 940, in exec_module
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 136, in <module>
table-dependency-viewer-api-1  |     from .runtime import engine, dbt_logs_engine, dev_engine
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 14, in <module>
table-dependency-viewer-api-1  |     engine = _engine(DATABASE_URL)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 10, in _engine
table-dependency-viewer-api-1  |     raise RuntimeError("DATABASE_URL is not configured")
table-dependency-viewer-api-1  | RuntimeError: DATABASE_URL is not configured
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/bin/uvicorn", line 8, in <module>
table-dependency-viewer-api-1  |     sys.exit(main())
table-dependency-viewer-api-1  |              ^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1653, in __call__
table-dependency-viewer-api-1  |     return self.main(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1560, in main
table-dependency-viewer-api-1  |     rv = self.invoke(ctx)
table-dependency-viewer-api-1  |          ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1414, in invoke
table-dependency-viewer-api-1  |     return ctx.invoke(self.callback, **ctx.params)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 911, in invoke
table-dependency-viewer-api-1  |     return callback(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 448, in main
table-dependency-viewer-api-1  |     run(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 620, in run
table-dependency-viewer-api-1  |     config.load_app()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/config.py", line 434, in load_app
table-dependency-viewer-api-1  |     return import_from_string(self.app)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 19, in import_from_string
table-dependency-viewer-api-1  |     module = importlib.import_module(module_str)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/importlib/__init__.py", line 126, in import_module
table-dependency-viewer-api-1  |     return _bootstrap._gcd_import(name[level:], package, level)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1147, in _find_and_load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 690, in _load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap_external>", line 940, in exec_module
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 136, in <module>
table-dependency-viewer-api-1  |     from .runtime import engine, dbt_logs_engine, dev_engine
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 14, in <module>
table-dependency-viewer-api-1  |     engine = _engine(DATABASE_URL)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 10, in _engine
table-dependency-viewer-api-1  |     raise RuntimeError("DATABASE_URL is not configured")
table-dependency-viewer-api-1  | RuntimeError: DATABASE_URL is not configured
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/bin/uvicorn", line 8, in <module>
table-dependency-viewer-api-1  |     sys.exit(main())
table-dependency-viewer-api-1  |              ^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1653, in __call__
table-dependency-viewer-api-1  |     return self.main(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1560, in main
table-dependency-viewer-api-1  |     rv = self.invoke(ctx)
table-dependency-viewer-api-1  |          ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1414, in invoke
table-dependency-viewer-api-1  |     return ctx.invoke(self.callback, **ctx.params)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 911, in invoke
table-dependency-viewer-api-1  |     return callback(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 448, in main
table-dependency-viewer-api-1  |     run(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 620, in run
table-dependency-viewer-api-1  |     config.load_app()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/config.py", line 434, in load_app
table-dependency-viewer-api-1  |     return import_from_string(self.app)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 19, in import_from_string
table-dependency-viewer-api-1  |     module = importlib.import_module(module_str)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/importlib/__init__.py", line 126, in import_module
table-dependency-viewer-api-1  |     return _bootstrap._gcd_import(name[level:], package, level)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1147, in _find_and_load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 690, in _load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap_external>", line 940, in exec_module
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 136, in <module>
table-dependency-viewer-api-1  |     from .runtime import engine, dbt_logs_engine, dev_engine
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 14, in <module>
table-dependency-viewer-api-1  |     engine = _engine(DATABASE_URL)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 10, in _engine
table-dependency-viewer-api-1  |     raise RuntimeError("DATABASE_URL is not configured")
table-dependency-viewer-api-1  | RuntimeError: DATABASE_URL is not configured
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/bin/uvicorn", line 8, in <module>
table-dependency-viewer-api-1  |     sys.exit(main())
table-dependency-viewer-api-1  |              ^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1653, in __call__
table-dependency-viewer-api-1  |     return self.main(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1560, in main
table-dependency-viewer-api-1  |     rv = self.invoke(ctx)
table-dependency-viewer-api-1  |          ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1414, in invoke
table-dependency-viewer-api-1  |     return ctx.invoke(self.callback, **ctx.params)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 911, in invoke
table-dependency-viewer-api-1  |     return callback(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 448, in main
table-dependency-viewer-api-1  |     run(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 620, in run
table-dependency-viewer-api-1  |     config.load_app()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/config.py", line 434, in load_app
table-dependency-viewer-api-1  |     return import_from_string(self.app)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 19, in import_from_string
table-dependency-viewer-api-1  |     module = importlib.import_module(module_str)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/importlib/__init__.py", line 126, in import_module
table-dependency-viewer-api-1  |     return _bootstrap._gcd_import(name[level:], package, level)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1147, in _find_and_load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 690, in _load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap_external>", line 940, in exec_module
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 136, in <module>
table-dependency-viewer-api-1  |     from .runtime import engine, dbt_logs_engine, dev_engine
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 14, in <module>
table-dependency-viewer-api-1  |     engine = _engine(DATABASE_URL)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 10, in _engine
table-dependency-viewer-api-1  |     raise RuntimeError("DATABASE_URL is not configured")
table-dependency-viewer-api-1  | RuntimeError: DATABASE_URL is not configured
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/bin/uvicorn", line 8, in <module>
table-dependency-viewer-api-1  |     sys.exit(main())
table-dependency-viewer-api-1  |              ^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1653, in __call__
table-dependency-viewer-api-1  |     return self.main(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1560, in main
table-dependency-viewer-api-1  |     rv = self.invoke(ctx)
table-dependency-viewer-api-1  |          ^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 1414, in invoke
table-dependency-viewer-api-1  |     return ctx.invoke(self.callback, **ctx.params)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/click/core.py", line 911, in invoke
table-dependency-viewer-api-1  |     return callback(*args, **kwargs)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 448, in main
table-dependency-viewer-api-1  |     run(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/main.py", line 620, in run
table-dependency-viewer-api-1  |     config.load_app()
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/config.py", line 434, in load_app
table-dependency-viewer-api-1  |     return import_from_string(self.app)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages/uvicorn/importer.py", line 19, in import_from_string
table-dependency-viewer-api-1  |     module = importlib.import_module(module_str)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/importlib/__init__.py", line 126, in import_module
table-dependency-viewer-api-1  |     return _bootstrap._gcd_import(name[level:], package, level)
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1204, in _gcd_import
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1176, in _find_and_load
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 1147, in _find_and_load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 690, in _load_unlocked
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap_external>", line 940, in exec_module
table-dependency-viewer-api-1  |   File "<frozen importlib._bootstrap>", line 241, in _call_with_frames_removed
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 136, in <module>
table-dependency-viewer-api-1  |     from .runtime import engine, dbt_logs_engine, dev_engine
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 14, in <module>
table-dependency-viewer-api-1  |     engine = _engine(DATABASE_URL)
table-dependency-viewer-api-1  |              ^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/runtime.py", line 10, in _engine
table-dependency-viewer-api-1  |     raise RuntimeError("DATABASE_URL is not configured")
table-dependency-viewer-api-1  | RuntimeError: DATABASE_URL is not configured
