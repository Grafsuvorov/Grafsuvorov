PS C:\Users\SuvorovND\GIT\table-dependency-viewer> python scripts\build_depends_on.py --file "C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity" --write                                    
Traceback (most recent call last):
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\scripts\build_depends_on.py", line 187, in <module>
    raise SystemExit(main())
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\scripts\build_depends_on.py", line 147, in main
    data = load_yaml(meta_path)
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\scripts\build_depends_on.py", line 96, in load_yaml
    with path.open("r", encoding="utf-8") as fh:
  File "C:\Users\SuvorovND\AppData\Local\Programs\Python\Python39\lib\pathlib.py", line 1241, in open
    return io.open(self, mode, buffering, encoding, errors, newline,
  File "C:\Users\SuvorovND\AppData\Local\Programs\Python\Python39\lib\pathlib.py", line 1109, in _opener
    return self._accessor.open(self, flags, mode)
PermissionError: [Errno 13] Permission denied: 'C:\\Users\\SuvorovND\\GIT\\meta_info\\database\\greenplum\\schema_name\\tech_etl\\etl_loads_entity'
