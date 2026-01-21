Traceback (most recent call last):
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 281, in <module>
    sys.exit(main())
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 266, in main
    write_file(os.path.join(out_dir, "meta_data_file.yaml"), metadata_content, args.overwrite)
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 245, in write_file
    ensure_write_path(path, overwrite)
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\generate_stg_files.py", line 241, in ensure_write_path
    raise RuntimeError(f"File already exists: {path}")
RuntimeError: File already exists: C:\Users\SuvorovND\GIT\table-dependency-viewer\meta_data_file.yaml


sql_query_recreate_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/SALES_MM/stg/klah/sql_query_recreate_init.sql
sql_query_insert_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/SALES_MM/stg/klah/sql_query_insert_init.sql
sql_query_truncate: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/SALES_MM/stg/klah/sql_query_truncate.sql
