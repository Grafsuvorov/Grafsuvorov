Доработка дага:

Добавить вывод в начала лога список всеъ объектов к изменению ( нужно, что бы можно было удобно скопировать и сформировать письмо)

Логирование:

Создать таблицы в схеме tech_etl.

CREATE TABLE tech_etl.release_log (

    release_id        text        NOT NULL,

    release_type      text        NOT NULL,  -- release/ vnerelease/ hotfix

    task_id           text        NOT NULL,  -- YouTrack 

    initiated_by      text        NOT NULL,  -- кто запустил DAG

    started_at        timestamp   NOT NULL,

    finished_at       timestamp,

    status            text        NOT NULL,  -- RUNNING / SUCCESS / FAILED

    total_objects     int         NOT NULL,

    failed_objects    int         DEFAULT 0,

    error_summary     text,                   -- краткое описание, если релиз упал

    created_at        timestamp   DEFAULT now()

)

DISTRIBUTED BY (release_id);



CREATE TABLE tech_etl.release_objects (

    release_id       text      NOT NULL,

    object_id        serialNOT NULL,

    target_system    text      NOT NULL,   -- greenplum / clickhouse

    schema_name      text      NOT NULL,

    table_name       text      NOT NULL,

    entity_id int not null,

    entity_name text not null,

    change_type      text      NOT NULL,   -- ddl / insert / truncate / recreate

    final_status     text      NOT NULL,   -- SUCCESS / FAILED

    attempts_count   int       NOT NULL,

    created_at       timestamp DEFAULT now(),

    

)

DISTRIBUTED BY (release_id);





CREATE TABLE tech_etl.release_object_attempts (

    release_id        text      NOT NULL,

    object_id         bigint    NOT NULL,

    attempt_no        int       NOT NULL,  -- номер попытки

    airflow_task_id   text      NOT NULL,  -- task_id из Airflow

    started_at        timestamp NOT NULL,

    finished_at       timestamp,

    status            text      NOT NULL,  -- SUCCESS / FAILED

    error_message     text,

    error_stacktrace  text,

    created_at        timestamp DEFAULT now()

)

DISTRIBUTED BY (release_id);
