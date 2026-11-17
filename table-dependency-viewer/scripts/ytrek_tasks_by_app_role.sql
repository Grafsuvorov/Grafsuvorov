-- Текущий список задач YouTrack для пользователей приложения с ролями
-- engineer и admin. Таблица yt_issue_snapshot должна быть предварительно
-- обновлена загрузчиком scripts/ytrek_load_to_gp.py.
--
-- Сопоставление учитывает три варианта идентификатора исполнителя YouTrack:
-- полную почту, часть почты до @ и username из приложения.

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
    CASE
        WHEN i.issue_id IS NULL THEN 'Нет задач в загруженном срезе YouTrack'
        WHEN i.resolved_at IS NOT NULL THEN 'Завершена'
        ELSE 'Открыта'
    END AS task_status
FROM users u
LEFT JOIN issues i
    ON lower(trim(i.assignee)) IN (
        lower(trim(u.email)),
        lower(trim(split_part(u.email, '@', 1))),
        lower(trim(u.username))
    )
ORDER BY
    CASE u.role WHEN 'admin' THEN 1 WHEN 'engineer' THEN 2 ELSE 3 END,
    u.username,
    i.updated_at DESC NULLS LAST;
