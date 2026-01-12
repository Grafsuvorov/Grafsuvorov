Может сложиться ситуация, когда часть create и insert изменилась, при первом запуске часть create применилась, а при втором запуске докатили остальное. Что в итоге должно там оказаться?
attempts_count - должна ли обновляться строка или добавляется ещё одна по объекту и количеству попыток. Из-за этого может быть ерунда.
  CREATE TABLE tech_etl.release_objects (

    release_id text NOT NULL,

    object_id serial NOT NULL,

    target_system text NOT NULL, -- greenplum / clickhouse

    schema_name text NOT NULL,

    table_name text NOT NULL,

    entity_id int NOT NULL,

    entity_name text NOT NULL,

    change_type text NOT NULL, -- ddl / insert / truncate / recreate

    final_status text NOT NULL, -- SUCCESS / FAILED

    attempts_count int NOT NULL,

    created_at timestamp DEFAULT now(),

    PRIMARY KEY (object_id)

)

DISTRIBUTED BY (release_id);
