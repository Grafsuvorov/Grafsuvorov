Доработка DAG релиза и логирование
1. Доработка DAG раскатки
1.1. Вывод плана релиза в лог (обязательно)

Требование

В начале выполнения DAG (до применения изменений) необходимо:

Сформировать список всех объектов, которые будут изменены

Разделить объекты по системам:

Greenplum

ClickHouse

Вывести список в лог в читаемом текстовом виде, пригодном для копирования и отправки письмом

Пример формата

========== RELEASE PLAN ==========
Release ID: 2026-01-15_manual_001
Task: YT-1234
Initiated by: ivan.petrov

Greenplum:
- ods.sales_orders (DDL)
- dm_calc.storage_costs (RECREATE)

ClickHouse:
- dm.sales_orders (INSERT)
- dm.storage_costs (TRUNCATE + INSERT)
=================================


📌 Список должен формироваться на основании сравнения Git ↔ мета-таблиц, до выполнения SQL.

2. Логирование релизного процесса

Все таблицы создаются в схеме tech_etl.

2.1. Таблица tech_etl.release_log
Назначение

1 строка = 1 запуск релиза целиком

CREATE TABLE tech_etl.release_log (
    release_id        text        NOT NULL,
    release_type      text        NOT NULL,  -- release / vnerelease / hotfix
    task_id           text        NOT NULL,  -- YouTrack
    initiated_by      text        NOT NULL,  -- пользователь, запустивший DAG

    started_at        timestamp   NOT NULL,
    finished_at       timestamp,

    status            text        NOT NULL,  -- RUNNING / SUCCESS / FAILED / PARTIAL

    total_objects     int         NOT NULL,
    failed_objects    int         DEFAULT 0,

    error_summary     text,
    created_at        timestamp   DEFAULT now()
)
DISTRIBUTED BY (release_id);

Комментарии
COMMENT ON TABLE tech_etl.release_log IS
'Журнал релизов. Одна запись соответствует одному запуску релизного DAG.';

COMMENT ON COLUMN tech_etl.release_log.release_id IS
'Уникальный идентификатор релиза (генерируется DAG)';

COMMENT ON COLUMN tech_etl.release_log.release_type IS
'Тип релиза: release / vnerelease / hotfix';

COMMENT ON COLUMN tech_etl.release_log.task_id IS
'Номер задачи в YouTrack';

COMMENT ON COLUMN tech_etl.release_log.initiated_by IS
'Пользователь или сервис, запустивший DAG';

COMMENT ON COLUMN tech_etl.release_log.started_at IS
'Дата и время начала релиза';

COMMENT ON COLUMN tech_etl.release_log.finished_at IS
'Дата и время завершения релиза';

COMMENT ON COLUMN tech_etl.release_log.status IS
'Финальный статус релиза';

COMMENT ON COLUMN tech_etl.release_log.total_objects IS
'Общее количество объектов, вошедших в релиз';

COMMENT ON COLUMN tech_etl.release_log.failed_objects IS
'Количество объектов, завершившихся с ошибкой';

COMMENT ON COLUMN tech_etl.release_log.error_summary IS
'Краткое описание причины падения релиза (если есть)';

2.2. Таблица tech_etl.release_objects
Назначение

1 строка = 1 объект (таблица), включённый в релиз

CREATE TABLE tech_etl.release_objects (
    release_id       text      NOT NULL,
    object_id        serial    NOT NULL,

    target_system    text      NOT NULL,   -- greenplum / clickhouse
    schema_name      text      NOT NULL,
    table_name       text      NOT NULL,

    entity_id        int       NOT NULL,
    entity_name      text      NOT NULL,

    change_type      text      NOT NULL,   -- ddl / insert / truncate / recreate
    final_status     text      NOT NULL,   -- SUCCESS / FAILED
    attempts_count   int       NOT NULL,

    created_at       timestamp DEFAULT now(),

    PRIMARY KEY (object_id)
)
DISTRIBUTED BY (release_id);

Комментарии
COMMENT ON TABLE tech_etl.release_objects IS
'Список объектов, входящих в релиз. Одна запись — одна таблица.';

COMMENT ON COLUMN tech_etl.release_objects.release_id IS
'Идентификатор релиза';

COMMENT ON COLUMN tech_etl.release_objects.object_id IS
'Уникальный идентификатор объекта в рамках релиза';

COMMENT ON COLUMN tech_etl.release_objects.target_system IS
'Целевая система: greenplum или clickhouse';

COMMENT ON COLUMN tech_etl.release_objects.schema_name IS
'Схема объекта';

COMMENT ON COLUMN tech_etl.release_objects.table_name IS
'Имя таблицы';

COMMENT ON COLUMN tech_etl.release_objects.entity_id IS
'Идентификатор бизнес-сущности';

COMMENT ON COLUMN tech_etl.release_objects.entity_name IS
'Название бизнес-сущности';

COMMENT ON COLUMN tech_etl.release_objects.change_type IS
'Тип изменения объекта';

COMMENT ON COLUMN tech_etl.release_objects.final_status IS
'Финальный статус применения объекта';

COMMENT ON COLUMN tech_etl.release_objects.attempts_count IS
'Количество попыток выполнения объекта';

2.3. Таблица tech_etl.release_object_attempts
Назначение

1 строка = 1 попытка выполнения объекта
Фиксирует ретраи, clear task и повторные ошибки.

CREATE TABLE tech_etl.release_object_attempts (
    release_id        text      NOT NULL,
    object_id         bigint    NOT NULL,

    attempt_no        int       NOT NULL,  -- номер попытки
    airflow_task_id   text      NOT NULL,  -- task_id Airflow

    started_at        timestamp NOT NULL,
    finished_at       timestamp,

    status            text      NOT NULL,  -- SUCCESS / FAILED

    error_message     text,
    error_stacktrace  text,

    created_at        timestamp DEFAULT now()
)
DISTRIBUTED BY (release_id);

Комментарии
COMMENT ON TABLE tech_etl.release_object_attempts IS
'История попыток выполнения объектов релиза (ретраи, clear task).';

COMMENT ON COLUMN tech_etl.release_object_attempts.release_id IS
'Идентификатор релиза';

COMMENT ON COLUMN tech_etl.release_object_attempts.object_id IS
'Ссылка на объект из release_objects';

COMMENT ON COLUMN tech_etl.release_object_attempts.attempt_no IS
'Номер попытки выполнения (Airflow try_number)';

COMMENT ON COLUMN tech_etl.release_object_attempts.airflow_task_id IS
'Идентификатор task_id в Airflow';

COMMENT ON COLUMN tech_etl.release_object_attempts.started_at IS
'Время начала попытки';

COMMENT ON COLUMN tech_etl.release_object_attempts.finished_at IS
'Время завершения попытки';

COMMENT ON COLUMN tech_etl.release_object_attempts.status IS
'Результат попытки выполнения';

COMMENT ON COLUMN tech_etl.release_object_attempts.error_message IS
'Текст ошибки';

COMMENT ON COLUMN tech_etl.release_object_attempts.error_stacktrace IS
'Полный stacktrace ошибки (если есть)';

3. Итог

Решение позволяет:

видеть кто / когда / что релизил

видеть все объекты релиза

хранить полную историю ошибок и ретраев

анализировать проблемные таблицы и релизы

использовать данные для UI, BI и SLA-контроля
