  File "<string>", line 1, in <module>
TypeError: unsupported operand type(s) for |: 'type' and 'NoneType'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\multiprocessing\process.py", line 315, in _bootstrap
    self.run()
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\multiprocessing\process.py", line 108, in run
    self._target(*self._args, **self._kwargs)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\_subprocess.py", line 80, in subprocess_started
    target(sockets=sockets)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\server.py", line 67, in run
    return asyncio.run(self.serve(sockets=sockets))
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\asyncio\runners.py", line 44, in run
    return loop.run_until_complete(main)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\asyncio\base_events.py", line 642, in run_until_complete
    return future.result()
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\server.py", line 71, in serve
    await self._serve(sockets)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\server.py", line 78, in _serve
    config.load()
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\config.py", line 436, in load
    self.loaded_app = import_from_string(self.app)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\uvicorn\importer.py", line 19, in import_from_string
    module = importlib.import_module(module_str)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\importlib\__init__.py", line 127, in import_module
    return _bootstrap._gcd_import(name[level:], package, level)
  File "<frozen importlib._bootstrap>", line 1030, in _gcd_import
  File "<frozen importlib._bootstrap>", line 1007, in _find_and_load
  File "<frozen importlib._bootstrap>", line 986, in _find_and_load_unlocked
  File "<frozen importlib._bootstrap>", line 680, in _load_unlocked
  File "<frozen importlib._bootstrap_external>", line 790, in exec_module
  File "<frozen importlib._bootstrap>", line 228, in _call_with_frames_removed
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\main.py", line 1797, in <module>
    def get_entity_loads(
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\routing.py", line 995, in decorator
    self.add_api_route(
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\routing.py", line 934, in add_api_route
    route = route_class(
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\routing.py", line 555, in __init__
    self.dependant = get_dependant(path=self.path_format, call=self.endpoint)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\dependencies\utils.py", line 274, in get_dependant
    endpoint_signature = get_typed_signature(call)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\dependencies\utils.py", line 234, in get_typed_signature
    typed_params = [
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\dependencies\utils.py", line 239, in <listcomp>
    annotation=get_typed_annotation(param.annotation, globalns),
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\fastapi\dependencies\utils.py", line 250, in get_typed_annotation
    annotation = evaluate_forwardref(annotation, globalns, globalns)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\pydantic\_internal\_typing_extra.py", line 409, in eval_type_lenient
    ev, _ = try_eval_type(value, globalns, localns)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\pydantic\_internal\_typing_extra.py", line 378, in try_eval_type
    return eval_type_backport(value, globalns, localns), True
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\pydantic\_internal\_typing_extra.py", line 429, in eval_type_backport
    return _eval_type_backport(value, globalns, localns, type_params)
  File "c:\users\suvorovnd\appdata\local\programs\python\python39\lib\site-packages\pydantic\_internal\_typing_extra.py", line 474, in _eval_type_backport
    raise TypeError(
TypeError: Unable to evaluate type annotation 'str | None'. If you are making use of the new typing syntax (unions using `|` since Python 3.10 or builtins subscripting since Python 3.9), you should either replace the use of new syntax with the existing `typing` constructs or install the `eval_type_backport` package.
