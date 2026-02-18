
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api /bin/sh -c 'ls -la /app/etl_loads_entity | head'
total 8
drwxr-xr-x. 2 root root    6 Feb 18 11:08 .
drwxr-xr-x. 1 root root 4096 Feb 18 12:32 ..
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api /bin/sh -c 'echo $META_PARENT_DIR'
/root/table-dependency-viewer/meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity
[root@rgm-s-dwhapp01 table-dependency-viewer]#
