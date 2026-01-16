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
