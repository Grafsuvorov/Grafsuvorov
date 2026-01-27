DDL (Greenplum)
CREATE TABLE dict.dict_entity (
    entity_id      int4        NOT NULL,
    entity_name    varchar(50) NOT NULL,
    entity_desc    varchar(255),
    owner_team     varchar(50),
    is_active      bool        DEFAULT true,
    dttm_inserted  timestamp   DEFAULT now(),
    dttm_updated   timestamp   DEFAULT now(),
    CONSTRAINT pk_dict_entity PRIMARY KEY (entity_id)
)
DISTRIBUTED BY (entity_id);
Пример данных
INSERT INTO dict.dict_entity (
    entity_id,
    entity_name,
    entity_desc,
    owner_team
)
VALUES (
    35,
    'sb_wuc',
    'Sales balance with forecast',
    'SCM'
);
🧱 2. Справочник таблиц
dict_table
Конкретная таблица / витрина (узел в графе)
DDL
CREATE TABLE dict.dict_table (
    table_id         int4         NOT NULL,
    entity_id        int4         NOT NULL,
    entity_name      varchar(50)  NOT NULL,
    schema_name      varchar(50)  NOT NULL,
    table_name       varchar(100) NOT NULL,
    full_table_name  varchar(200) NOT NULL,
    layer            varchar(30)  NOT NULL,
    is_active        bool         DEFAULT true,
    dttm_inserted    timestamp    DEFAULT now(),
    dttm_updated     timestamp    DEFAULT now(),
    CONSTRAINT pk_dict_table PRIMARY KEY (table_id)
)
DISTRIBUTED BY (table_id);
💡 entity_name — денормализация намеренно, чтобы не джойнить в мониторинге.
Пример данных
INSERT INTO dict.dict_table (
    table_id,
    entity_id,
    entity_name,
    schema_name,
    table_name,
    full_table_name,
    layer
)
VALUES (
    1134,
    35,
    'sb_wuc',
    'dm',
    'sales_stock_balance_with_forecast',
    'dm.sales_stock_balance_with_forecast',
    'gp'
);
🧱 3. Факт запусков таблиц
fact_table_load_run
Одна строка = один запуск одной таблицы
DDL
CREATE TABLE monitoring.fact_table_load_run (
    run_id         uuid         NOT NULL,
    entity_id      int4         NOT NULL,
    entity_name    varchar(50)  NOT NULL,
    table_id       int4         NOT NULL,
    table_name     varchar(200) NOT NULL,
    pipeline_name  varchar(100) NOT NULL,
    start_dttm     timestamp    NOT NULL,
    end_dttm       timestamp,
    duration_sec   int4,
    status         varchar(20)  NOT NULL,
    rows_count     int8,
    error_text     text,
    dt             date         NOT NULL,
    dttm_inserted  timestamp    DEFAULT now(),
    CONSTRAINT pk_fact_table_load_run PRIMARY KEY (run_id)
)
DISTRIBUTED BY (table_id)
PARTITION BY RANGE (dt) (
    START (date '2025-01-01') INCLUSIVE
    END   (date '2030-01-01') EXCLUSIVE
    EVERY (INTERVAL '1 month')
);
Пример — успешный запуск
INSERT INTO monitoring.fact_table_load_run (
    run_id,
    entity_id,
    entity_name,
    table_id,
    table_name,
    pipeline_name,
    start_dttm,
    end_dttm,
    duration_sec,
    status,
    rows_count,
    dt
)
VALUES (
    '7c1d1a6e-5e7f-4a5a-9c11-91e3a1a0a111',
    35,
    'sb_wuc',
    1134,
    'dm.sales_stock_balance_with_forecast',
    'gp_to_s3_to_clickhouse',
    now() - interval '3 minute',
    now(),
    180,
    'SUCCESS',
    12345678,
    current_date
);
Пример — ошибка
INSERT INTO monitoring.fact_table_load_run (
    run_id,
    entity_id,
    entity_name,
    table_id,
    table_name,
    pipeline_name,
    start_dttm,
    status,
    error_text,
    dt
)
VALUES (
    gen_random_uuid(),
    35,
    'sb_wuc',
    1134,
    'dm.sales_stock_balance_with_forecast',
    'gp_to_s3_to_clickhouse',
    now(),
    'FAILED',
    'ERROR: could not read from S3 (timeout)',
    current_date
);
🧱 4. Этапы загрузки
fact_table_load_stage
Детализация запуска: где именно тормоз / упало
DDL
CREATE TABLE monitoring.fact_table_load_stage (
    run_id        uuid         NOT NULL,
    table_id      int4         NOT NULL,
    stage_name    varchar(50)  NOT NULL,
    start_dttm    timestamp    NOT NULL,
    end_dttm      timestamp,
    duration_sec  int4,
    rows_count    int8,
    bytes_mb      numeric(18,2),
    status        varchar(20)  NOT NULL,
    error_text    text,
    dt            date         NOT NULL,
    dttm_inserted timestamp    DEFAULT now()
)
DISTRIBUTED BY (table_id)
PARTITION BY RANGE (dt) (
    START (date '2025-01-01') INCLUSIVE
    END   (date '2030-01-01') EXCLUSIVE
    EVERY (INTERVAL '1 month')
);
Примеры этапов
-- этап выгрузки в S3
INSERT INTO monitoring.fact_table_load_stage (
    run_id,
    table_id,
    stage_name,
    start_dttm,
    end_dttm,
    duration_sec,
    rows_count,
    bytes_mb,
    status,
    dt
)
VALUES (
    '7c1d1a6e-5e7f-4a5a-9c11-91e3a1a0a111',
    1134,
    's3_export',
    now() - interval '3 minute',
    now() - interval '1 minute',
    120,
    12345678,
    8420.5,
    'SUCCESS',
    current_date
);
-- этап загрузки в ClickHouse
INSERT INTO monitoring.fact_table_load_stage (
    run_id,
    table_id,
    stage_name,
    start_dttm,
    end_dttm,
    duration_sec,
    rows_count,
    status,
    dt
)
VALUES (
    '7c1d1a6e-5e7f-4a5a-9c11-91e3a1a0a111',
    1134,
    'clickhouse_load',
    now() - interval '1 minute',
    now(),
    60,
    12345678,
    'SUCCESS',
    current_date
);
