PS C:\Users\SuvorovND\GIT\table-dependency-viewer> python scripts\audit_depends_on.py --root "C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity" --debug --out reports\depends_audit.txt
[DEBUG] repo_root=C:\Users\SuvorovND\GIT\table-dependency-viewer
[DEBUG] root=C:\Users\SuvorovND\GIT\meta_info\database\greenplum\schema_name\tech_etl\etl_loads_entity
[DEBUG] meta_index size=2436
Traceback (most recent call last):
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\scripts\audit_depends_on.py", line 187, in <module>
    raise SystemExit(main())
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\scripts\audit_depends_on.py", line 153, in main
    rel = str(meta_path.relative_to(repo_root))
  File "C:\Users\SuvorovND\AppData\Local\Programs\Python\Python39\lib\pathlib.py", line 928, in relative_to
    raise ValueError("{!r} is not in the subpath of {!r}"
ValueError: 'C:\\Users\\SuvorovND\\GIT\\meta_info\\database\\greenplum\\schema_name\\tech_etl\\etl_loads_entity\\1C_FI\\dm\\account_debt_for_working_capital_1c\\meta_data_file.yaml' is not in the subpath of 'C:\\Users\\SuvorovND\\GIT\\table-dependency-viewer' OR one path is relative and the other is absolute.
