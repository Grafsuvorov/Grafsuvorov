-- Текущий список задач YouTrack для пользователей приложения с ролями
-- engineer и admin. Таблица yt_issue_snapshot должна быть предварительно
-- обновлена загрузчиком scripts/ytrek_load_to_gp.py.
--
-- Приоритет сопоставления: точная почта пользователя приложения с автором
-- или создателем worklog. Сопоставление с текущим assignee оставлено как
-- запасной вариант для задач без трудозатрат.

WITH users AS (
    SELECT
        u.id,
        u.email,
        u.username,
        u.role,
        u.is_active
    FROM tech_etl.app_users u
    WHERE u.role IN ('engineer', 'admin')
),
issues AS (
    SELECT DISTINCT ON (s.issue_id)
        s.issue_id,
        s.summary,
        s.project_key,
        s.assignee,
        s.created_by,
        s.current_state,
        s.created_at,
        s.updated_at,
        s.resolved_at,
        s.dttm_loaded
    FROM tech_etl.yt_issue_snapshot s
    ORDER BY s.issue_id, s.dttm_loaded DESC NULLS LAST
),
worklog_email AS (
    SELECT DISTINCT
        w.issue_id,
        lower(trim(w.author)) AS email,
        'worklog_author'::text AS match_source
    FROM tech_etl.yt_issue_worklog w
    WHERE w.author LIKE '%@%'

    UNION

    SELECT DISTINCT
        w.issue_id,
        lower(trim(w.creator)) AS email,
        'worklog_creator'::text AS match_source
    FROM tech_etl.yt_issue_worklog w
    WHERE w.creator LIKE '%@%'
),
user_tasks AS (
    -- Точное совпадение с корпоративной почтой из worklog.
    SELECT
        u.id AS user_id,
        w.issue_id,
        string_agg(DISTINCT w.match_source, ', ' ORDER BY w.match_source) AS match_source
    FROM users u
    JOIN worklog_email w
      ON w.email = lower(trim(u.email))
    GROUP BY u.id, w.issue_id

    UNION ALL

    -- Если в задаче нет worklog с почтой, используем текущего исполнителя.
    SELECT
        u.id AS user_id,
        i.issue_id,
        'assignee_fallback'::text AS match_source
    FROM users u
    JOIN issues i
      ON lower(trim(i.assignee)) IN (
          lower(trim(u.email)),
          lower(trim(split_part(u.email, '@', 1))),
          lower(trim(u.username))
      )
    WHERE NOT EXISTS (
        SELECT 1
        FROM worklog_email w
        WHERE w.issue_id = i.issue_id
          AND w.email = lower(trim(u.email))
    )
)
SELECT
    u.role AS app_role,
    u.is_active AS app_user_active,
    u.email,
    u.username,
    i.issue_id,
    i.summary,
    i.project_key,
    i.current_state AS issue_state,
    i.assignee AS youtrack_assignee,
    i.created_by AS youtrack_reporter,
    i.created_at,
    i.updated_at,
    i.resolved_at,
    ut.match_source,
    CASE
        WHEN i.issue_id IS NULL THEN 'Нет задач в загруженном срезе YouTrack'
        WHEN i.resolved_at IS NOT NULL THEN 'Завершена'
        ELSE 'Открыта'
    END AS task_status
FROM users u
LEFT JOIN user_tasks ut ON ut.user_id = u.id
LEFT JOIN issues i ON i.issue_id = ut.issue_id
ORDER BY
    CASE u.role WHEN 'admin' THEN 1 WHEN 'engineer' THEN 2 ELSE 3 END,
    u.username,
    i.updated_at DESC NULLS LAST;
