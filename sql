строка = 1 запуск релиза целиком

CREATE TABLE dwh.release_log (
    release_id        text        NOT NULL,
    release_type      text        NOT NULL,  -- manual / scheduled / hotfix
    task_id           text        NOT NULL,  -- YouTrack / Jira
    initiated_by      text        NOT NULL,  -- кто запустил DAG
    git_branch        text        NOT NULL,
    git_commit_hash   text        NOT NULL,

    started_at        timestamp   NOT NULL,
    finished_at       timestamp,
    status            text        NOT NULL,  -- RUNNING / SUCCESS / PARTIAL / FAILED

    total_objects     int         NOT NULL,
    failed_objects    int         DEFAULT 0,

    error_summary     text,                   -- краткое описание, если релиз упал
    created_at        timestamp   DEFAULT now()
)
DISTRIBUTED BY (release_id);

📌 Пояснение полей
Поле	Значение
release_id	Уникальный идентификатор релиза
release_type	Тип релиза: ручной / плановый / хотфикс
task_id	Номер задачи (обязателен)
initiated_by	Пользователь / сервис, запустивший DAG
git_branch	Ветка Git
git_commit_hash	Коммит релиза
started_at	Время старта DAG
finished_at	Время завершения
status	Итог релиза
total_objects	Сколько объектов вошло в релиз
failed_objects	Сколько объектов в итоге не применились
error_summary	Короткое описание причины фейла
2️⃣ Таблица release_objects — объекты релиза

Назначение
1 строка = 1 таблица / объект, который должен быть изменён в релизе

CREATE TABLE dwh.release_objects (
    release_id       text      NOT NULL,
    object_id        bigserial NOT NULL,

    target_system    text      NOT NULL,   -- greenplum / clickhouse
    schema_name      text      NOT NULL,
    table_name       text      NOT NULL,

    change_type      text      NOT NULL,   -- ddl / insert / truncate / recreate
    final_status     text      NOT NULL,   -- SUCCESS / FAILED
    attempts_count   int       NOT NULL,

    created_at       timestamp DEFAULT now(),
    PRIMARY KEY (object_id)
)
DISTRIBUTED BY (release_id);

📌 Пояснение полей
Поле	Значение
release_id	Ссылка на релиз
object_id	Уникальный ID объекта в релизе
target_system	Где выполняется объект
schema_name	Схема
table_name	Таблица
change_type	Тип изменения
final_status	Финальный результат
attempts_count	Сколько попыток было всего

📌 attempts_count = COUNT(*) из таблицы попыток

3️⃣ Таблица release_object_attempts — попытки выполнения (ключевая)

Назначение
1 строка = 1 попытка выполнения объекта
👉 именно она решает проблему clear task и повторных ошибок

CREATE TABLE dwh.release_object_attempts (
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

📌 Пояснение полей
Поле	Значение
release_id	Идентификатор релиза
object_id	Ссылка на объект
attempt_no	Номер попытки (Airflow try_number)
airflow_task_id	ID таска Airflow
started_at	Старт попытки
finished_at	Конец попытки
status	Результат попытки
error_message	Текст ошибки
error_stacktrace	Полный стек (если есть)
