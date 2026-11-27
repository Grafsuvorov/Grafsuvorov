
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_production_waste_repor                t depends on api.sapxi_production_waste_report BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_raw_material_planning                 depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule_cu_fo                rm depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule_folde                r depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule_track                 depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_1c_personnel_attendanc                e depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_raw_cubal_downtime dep                ends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_raw_purchase_planning                 depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule_cu_or                der depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule_folde                r_orders depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_metal_electrolysis_kub                al depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_raw_cubal_downtimeklas                s depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_reject_product_kubal d                epends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.auxiliary_production_anode_z                yfra depends on api.api__stg__auxiliary_production_anode_zyfra BUT META NOT FOUN                D
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.kpi_aggregation_characterist                ic_ppk depends on landing.kpi_aggregation_characteristic_ppk BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule depen                ds on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.sapxi_casting_schedule_oper                 depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: dict_stg.sapxi_foundry_wip_group                _materials depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: dm.kpi_indicators_daily_gd depen                ds on ods.alumina_production_xls BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.alarm_accidents depends on l                anding.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.ad_users depends on api.dag_                load_ad_users BUT META NOT FOUND
table-dependency-viewer-api-1  | ⚠️ rebuilding orderbreaches cache
table-dependency-viewer-api-1  | ⚠️ rebuilding table sizes cache
table-dependency-viewer-api-1  | ❌ table sizes cache refresh error: (psycopg2.e                rrors.LockNotAvailable) canceling statement due to lock timeout
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | [SQL:
table-dependency-viewer-api-1  |         WITH created_ops AS (
table-dependency-viewer-api-1  |             SELECT
table-dependency-viewer-api-1  |                 pso.schemaname AS table_schema,
table-dependency-viewer-api-1  |                 pso.objname AS table_name,
table-dependency-viewer-api-1  |                 MAX(pso.statime) AS dt_creation
table-dependency-viewer-api-1  |             FROM pg_catalog.pg_stat_operations                 pso
table-dependency-viewer-api-1  |             WHERE pso.actionname = 'CREATE'
table-dependency-viewer-api-1  |               AND pso.subtype = 'TABLE'
table-dependency-viewer-api-1  |             GROUP BY pso.schemaname, pso.objnam                e
table-dependency-viewer-api-1  |         )
table-dependency-viewer-api-1  |         SELECT
table-dependency-viewer-api-1  |             n.nspname AS table_schema,
table-dependency-viewer-api-1  |             c.relname AS table_name,
table-dependency-viewer-api-1  |             r.rolname AS owner_name,
table-dependency-viewer-api-1  |             pg_total_relation_size(c.oid)::bigi                nt AS size_bytes,
table-dependency-viewer-api-1  |             created_ops.dt_creation AS dt_creat                ion,
table-dependency-viewer-api-1  |             CASE
table-dependency-viewer-api-1  |                 WHEN created_ops.dt_creation IS                 NULL THEN NULL
table-dependency-viewer-api-1  |                 ELSE EXTRACT(DAY FROM now() - c                reated_ops.dt_creation)::int
table-dependency-viewer-api-1  |             END AS days_old
table-dependency-viewer-api-1  |         FROM pg_catalog.pg_class c
table-dependency-viewer-api-1  |         JOIN pg_catalog.pg_namespace n
table-dependency-viewer-api-1  |           ON n.oid = c.relnamespace
table-dependency-viewer-api-1  |         JOIN pg_catalog.pg_roles r
table-dependency-viewer-api-1  |           ON r.oid = c.relowner
table-dependency-viewer-api-1  |         LEFT JOIN created_ops
table-dependency-viewer-api-1  |           ON created_ops.table_schema = n.nspna                me
table-dependency-viewer-api-1  |          AND created_ops.table_name = c.relname
table-dependency-viewer-api-1  |         WHERE c.relkind IN ('r', 'p', 'm')
table-dependency-viewer-api-1  |           AND n.nspname NOT IN ('pg_catalog', '                information_schema')
table-dependency-viewer-api-1  |           AND n.nspname NOT LIKE 'pg_toast%%%%'
table-dependency-viewer-api-1  |           -- Leaf partitions are physical relat                ions; show only the parent table.
table-dependency-viewer-api-1  |           AND NOT EXISTS (
table-dependency-viewer-api-1  |               SELECT 1
table-dependency-viewer-api-1  |               FROM pg_catalog.pg_inherits paren                t_relation
table-dependency-viewer-api-1  |               WHERE parent_relation.inhrelid =                 c.oid
table-dependency-viewer-api-1  |           )
table-dependency-viewer-api-1  |         ORDER BY size_bytes DESC NULLS LAST, n.                nspname, c.relname
table-dependency-viewer-api-1  |     ]
table-dependency-viewer-api-1  | (Background on this error at: https://sqlalche.                me/e/21/e3q8)
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 1977, in _exec_single_context
table-dependency-viewer-api-1  |     self.dialect.do_execute(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/default.py", line 1192, in do_execute
table-dependency-viewer-api-1  |     cursor.execute(statement, parameters)
table-dependency-viewer-api-1  | psycopg2.errors.LockNotAvailable: canceling sta                tement due to lock timeout
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | The above exception was the direct cause of the                 following exception:
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | Traceback (most recent call last):
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 5037, in _refre                sh_table_sizes_cache
table-dependency-viewer-api-1  |     payload = _build_table_sizes_cache()
table-dependency-viewer-api-1  |               ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/app/api/main.py", line 4985, in _build                _table_sizes_cache
table-dependency-viewer-api-1  |     rows = conn.execute(text(query)).mappings()                .all()
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 1494, in execute
table-dependency-viewer-api-1  |     return meth(
table-dependency-viewer-api-1  |            ^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/sql/elements.py", line 534, in _execute_on_connection
table-dependency-viewer-api-1  |     return connection._execute_clauseelement(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 1714, in _execute_clauseelement
table-dependency-viewer-api-1  |     ret = self._execute_context(
table-dependency-viewer-api-1  |           ^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 1868, in _execute_context
table-dependency-viewer-api-1  |     return self._exec_single_context(
table-dependency-viewer-api-1  |            ^^^^^^^^^^^^^^^^^^^^^^^^^^
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 1996, in _exec_single_context
table-dependency-viewer-api-1  |     self._handle_dbapi_exception(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 2351, in _handle_dbapi_exception
table-dependency-viewer-api-1  |     raise sqlalchemy_exception.with_traceback(e                xc_info[2]) from e
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/base.py", line 1977, in _exec_single_context
table-dependency-viewer-api-1  |     self.dialect.do_execute(
table-dependency-viewer-api-1  |   File "/usr/local/lib/python3.11/site-packages                /sqlalchemy/engine/default.py", line 1192, in do_execute
table-dependency-viewer-api-1  |     cursor.execute(statement, parameters)
table-dependency-viewer-api-1  | sqlalchemy.exc.OperationalError: (psycopg2.erro                rs.LockNotAvailable) canceling statement due to lock timeout
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | [SQL:
table-dependency-viewer-api-1  |         WITH created_ops AS (
table-dependency-viewer-api-1  |             SELECT
table-dependency-viewer-api-1  |                 pso.schemaname AS table_schema,
table-dependency-viewer-api-1  |                 pso.objname AS table_name,
table-dependency-viewer-api-1  |                 MAX(pso.statime) AS dt_creation
table-dependency-viewer-api-1  |             FROM pg_catalog.pg_stat_operations                 pso
table-dependency-viewer-api-1  |             WHERE pso.actionname = 'CREATE'
table-dependency-viewer-api-1  |               AND pso.subtype = 'TABLE'
table-dependency-viewer-api-1  |             GROUP BY pso.schemaname, pso.objnam                e
table-dependency-viewer-api-1  |         )
table-dependency-viewer-api-1  |         SELECT
table-dependency-viewer-api-1  |             n.nspname AS table_schema,
table-dependency-viewer-api-1  |             c.relname AS table_name,
table-dependency-viewer-api-1  |             r.rolname AS owner_name,
table-dependency-viewer-api-1  |             pg_total_relation_size(c.oid)::bigi                nt AS size_bytes,
table-dependency-viewer-api-1  |             created_ops.dt_creation AS dt_creat                ion,
table-dependency-viewer-api-1  |             CASE
table-dependency-viewer-api-1  |                 WHEN created_ops.dt_creation IS                 NULL THEN NULL
table-dependency-viewer-api-1  |                 ELSE EXTRACT(DAY FROM now() - c                reated_ops.dt_creation)::int
table-dependency-viewer-api-1  |             END AS days_old
table-dependency-viewer-api-1  |         FROM pg_catalog.pg_class c
table-dependency-viewer-api-1  |         JOIN pg_catalog.pg_namespace n
table-dependency-viewer-api-1  |           ON n.oid = c.relnamespace
table-dependency-viewer-api-1  |         JOIN pg_catalog.pg_roles r
table-dependency-viewer-api-1  |           ON r.oid = c.relowner
table-dependency-viewer-api-1  |         LEFT JOIN created_ops
table-dependency-viewer-api-1  |           ON created_ops.table_schema = n.nspna                me
table-dependency-viewer-api-1  |          AND created_ops.table_name = c.relname
table-dependency-viewer-api-1  |         WHERE c.relkind IN ('r', 'p', 'm')
table-dependency-viewer-api-1  |           AND n.nspname NOT IN ('pg_catalog', '                information_schema')
table-dependency-viewer-api-1  |           AND n.nspname NOT LIKE 'pg_toast%%%%'
table-dependency-viewer-api-1  |           -- Leaf partitions are physical relat                ions; show only the parent table.
table-dependency-viewer-api-1  |           AND NOT EXISTS (
table-dependency-viewer-api-1  |               SELECT 1
table-dependency-viewer-api-1  |               FROM pg_catalog.pg_inherits paren                t_relation
table-dependency-viewer-api-1  |               WHERE parent_relation.inhrelid =                 c.oid
table-dependency-viewer-api-1  |           )
table-dependency-viewer-api-1  |         ORDER BY size_bytes DESC NULLS LAST, n.                nspname, c.relname
table-dependency-viewer-api-1  |     ]
table-dependency-viewer-api-1  | (Background on this error at: https://sqlalche.                me/e/21/e3q8)
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | ❌ cache warm-up error (table_sizes): (psycopg2                .errors.LockNotAvailable) canceling statement due to lock timeout
table-dependency-viewer-api-1  |
table-dependency-viewer-api-1  | [SQL:
table-dependency-viewer-api-1  |         WITH created_ops AS (
table-dependency-viewer-api-1  |             SELECT
table-dependency-viewer-api-1  |                 pso.schemaname AS table_schema,
table-dependency-viewer-api-1  |                 pso.objname AS table_name,
table-dependency-viewer-api-1  |                 MAX(pso.statime) AS dt_creation
table-dependency-viewer-api-1  |             FROM pg_catalog.pg_stat_operations                 pso
table-dependency-viewer-api-1  |             WHERE pso.actionname = 'CREATE'
table-dependency-viewer-api-1  |               AND pso.subtype = 'TABLE'
table-dependency-viewer-api-1  |             GROUP BY pso.schemaname, pso.objnam                e
table-dependency-viewer-api-1  |         )
table-dependency-viewer-api-1  |         SELECT
table-dependency-viewer-api-1  |             n.nspname AS table_schema,
table-dependency-viewer-api-1  |             c.relname AS table_name,
table-dependency-viewer-api-1  |             r.rolname AS owner_name,
table-dependency-viewer-api-1  |             pg_total_relation_size(c.oid)::bigi                nt AS size_bytes,
table-dependency-viewer-api-1  |             created_ops.dt_creation AS dt_creat                ion,
table-dependency-viewer-api-1  |             CASE
table-dependency-viewer-api-1  |                 WHEN created_ops.dt_creation IS                 NULL THEN NULL
table-dependency-viewer-api-1  |                 ELSE EXTRACT(DAY FROM now() - c                reated_ops.dt_creation)::int
table-dependency-viewer-api-1  |             END AS days_old
table-dependency-viewer-api-1  |         FROM pg_catalog.pg_class c
table-dependency-viewer-api-1  |         JOIN pg_catalog.pg_namespace n
table-dependency-viewer-api-1  |           ON n.oid = c.relnamespace
table-dependency-viewer-api-1  |         JOIN pg_catalog.pg_roles r
table-dependency-viewer-api-1  |           ON r.oid = c.relowner
table-dependency-viewer-api-1  |         LEFT JOIN created_ops
table-dependency-viewer-api-1  |           ON created_ops.table_schema = n.nspna                me
table-dependency-viewer-api-1  |          AND created_ops.table_name = c.relname
table-dependency-viewer-api-1  |         WHERE c.relkind IN ('r', 'p', 'm')
table-dependency-viewer-api-1  |           AND n.nspname NOT IN ('pg_catalog', '                information_schema')
table-dependency-viewer-api-1  |           AND n.nspname NOT LIKE 'pg_toast%%%%'
table-dependency-viewer-api-1  |           -- Leaf partitions are physical relat                ions; show only the parent table.
table-dependency-viewer-api-1  |           AND NOT EXISTS (
table-dependency-viewer-api-1  |               SELECT 1
table-dependency-viewer-api-1  |               FROM pg_catalog.pg_inherits paren                t_relation
table-dependency-viewer-api-1  |               WHERE parent_relation.inhrelid =                 c.oid
table-dependency-viewer-api-1  |           )
table-dependency-viewer-api-1  |         ORDER BY size_bytes DESC NULLS LAST, n.                nspname, c.relname
table-dependency-viewer-api-1  |     ]
table-dependency-viewer-api-1  | (Background on this error at: https://sqlalche.                me/e/21/e3q8)
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46782 - "POST /auth/audit/                event HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46784 - "GET /auth/me HTTP                /1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46804 - "GET /api/admin/pr                ototype-review/source-load/servers?mode=khd HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46806 - "GET /api/admin/pr                ototype-review/source-load/tables?target_schema=stg&mode=khd HTTP/1.1" 500 Inter                nal Server Error
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46892 - "POST /auth/audit/                event HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46894 - "GET /auth/me HTTP                /1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46916 - "GET /api/admin/pr                ototype-review/source-load/servers?mode=khd HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:46918 - "GET /api/admin/pr                ototype-review/source-load/tables?target_schema=stg&mode=khd HTTP/1.1" 500 Inter                nal Server Error
table-dependency-viewer-api-1  | INFO:     172.22.0.3:47146 - "GET /api/admin/pr                ototype-review/source-load/servers?mode=khd HTTP/1.1" 200 OK
table-dependency-viewer-api-1  | INFO:     172.22.0.3:47148 - "GET /api/admin/pr                ototype-review/source-load/tables?target_schema=stg&mode=khd HTTP/1.1" 500 Inter                nal Server Error



  создать одну задачу для 2 stg тиблиц это кнопка наезжает на дата релиза и еще при вводе таблицы таргет он не нахолдит таблицу которая существует кнопку подтянуть параметры сущности убрать при вводе пусть по умолчанию подтягивает если таблица есть как было 
