-- Незавершённые задачи, по которым пользователи приложения с ролями
-- engineer и admin списывали время. Автор worklog не обязательно является
-- текущим исполнителем задачи. Задачи без трудозатрат сюда не попадают.
--
-- Статус берётся из последнего загруженного среза yt_issue_snapshot:
-- resolved_at IS NULL означает, что задача не завершена.
-- Актуальность результата зависит от актуальности этого среза.
-- Запрос только читает данные; одна строка на пользователя и задачу.

WITH users AS (
    SELECT
        u.id,
        u.email,
        u.username,
        u.role,
        u.is_active
    FROM tech_etl.app_users u
    WHERE u.role IN ('engineer', 'admin')
      AND NULLIF(trim(u.email), '') IS NOT NULL
),
issues AS (
    SELECT DISTINCT ON (s.issue_id)
        s.issue_id,
        s.summary,
        s.project_key,
        s.assignee,
        s.current_state,
        s.created_at,
        s.updated_at,
        s.resolved_at,
        s.dttm_loaded
    FROM tech_etl.yt_issue_snapshot s
    ORDER BY s.issue_id, s.dttm_loaded DESC NULLS LAST,
             s.updated_at DESC NULLS LAST
),
worklog_email AS (
    SELECT DISTINCT
        w.issue_id,
        lower(trim(w.author_email)) AS email
    FROM tech_etl.yt_issue_worklog w
    WHERE w.deleted_flag = false
      AND NULLIF(trim(w.author_email), '') IS NOT NULL
)
SELECT
    u.id AS app_user_id,
    u.role AS app_role,
    u.is_active AS app_user_active,
    u.email,
    u.username,
    i.issue_id,
    i.summary,
    i.project_key,
    i.current_state AS issue_state,
    i.assignee AS youtrack_assignee,
    i.created_at,
    i.updated_at,
    i.dttm_loaded AS snapshot_loaded_at
FROM users u
JOIN worklog_email w ON w.email = lower(trim(u.email))
JOIN issues i ON i.issue_id = w.issue_id
WHERE i.resolved_at IS NULL
ORDER BY
    CASE u.role WHEN 'admin' THEN 1 WHEN 'engineer' THEN 2 ELSE 3 END,
    u.username,
    u.id,
    i.updated_at DESC NULLS LAST,
    i.issue_id;
