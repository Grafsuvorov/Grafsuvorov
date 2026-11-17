-- Открытые задачи инженеров/администраторов, включая задачи без worklog.
-- Worklog используется ТОЛЬКО как общий справочник author -> email:
-- INNER JOIN с пользователями по email, без issue_id в сопоставлении людей.
-- Трудозатраты конкретной задачи не определяют её исполнителя.
WITH identities AS (
    SELECT DISTINCT u.id AS user_id, lower(trim(w.author)) AS yt_author
    FROM tech_etl.yt_issue_worklog w
    INNER JOIN tech_etl.app_users u
      ON lower(trim(w.author_email)) = lower(trim(u.email))
    WHERE u.role IN ('engineer', 'admin')
      AND COALESCE(w.deleted_flag, false) = false
      AND NULLIF(trim(w.author), '') IS NOT NULL
),
aliases AS (
    SELECT user_id, yt_author AS alias FROM identities
    UNION
    SELECT id, lower(trim(email)) FROM tech_etl.app_users WHERE role IN ('engineer', 'admin')
    UNION
    SELECT id, lower(trim(username)) FROM tech_etl.app_users WHERE role IN ('engineer', 'admin')
),
unique_aliases AS (
    SELECT alias, min(user_id) AS user_id FROM aliases
    WHERE NULLIF(alias, '') IS NOT NULL
    GROUP BY alias HAVING count(DISTINCT user_id) = 1
),
issues AS (
    SELECT DISTINCT ON (s.issue_id) s.*
    FROM tech_etl.yt_issue_snapshot s
    ORDER BY s.issue_id, s.dttm_loaded DESC NULLS LAST, s.updated_at DESC NULLS LAST
),
custom_assignee AS (
    SELECT DISTINCT ON (issue_id) issue_id, NULLIF(trim(field_value), '') AS assignee
    FROM tech_etl.yt_issue_custom_field
    WHERE lower(trim(field_name)) IN ('assignee', 'исполнитель')
    ORDER BY issue_id, dttm_loaded DESC NULLS LAST
),
last_assignment AS (
    SELECT DISTINCT ON (issue_id) issue_id, NULLIF(trim(value_to), '') AS assignee
    FROM tech_etl.yt_issue_timeline WHERE event_type = 'Assignee change'
    ORDER BY issue_id, ts DESC NULLS LAST
),
executor AS (
    SELECT DISTINCT ON (issue_id) issue_id, author
    FROM tech_etl.yt_issue_timeline
    WHERE event_type = 'State change' AND value_to IN ('В работе', 'Ожидание релиза')
    ORDER BY issue_id, ts DESC NULLS LAST
),
tasks AS (
    SELECT s.*, COALESCE(NULLIF(trim(s.assignee), ''), c.assignee, a.assignee,
        CASE WHEN a.issue_id IS NULL THEN e.author END) AS effective_assignee
    FROM issues s
    LEFT JOIN custom_assignee c ON c.issue_id = s.issue_id
    LEFT JOIN last_assignment a ON a.issue_id = s.issue_id
    LEFT JOIN executor e ON e.issue_id = s.issue_id
)
SELECT u.id AS app_user_id, u.role AS app_role, u.is_active AS app_user_active,
       u.email, u.username, i.issue_id, i.summary, i.project_key,
       i.current_state AS issue_state, i.effective_assignee AS youtrack_assignee,
       i.created_at, i.updated_at, i.dttm_loaded AS snapshot_loaded_at
FROM tasks i
INNER JOIN unique_aliases a ON a.alias = lower(trim(i.effective_assignee))
INNER JOIN tech_etl.app_users u ON u.id = a.user_id
WHERE lower(trim(COALESCE(i.current_state, ''))) NOT IN
      ('done', 'fixed', 'завершена', 'duplicate', 'отклонено')
  AND (i.resolved_at IS NULL OR lower(trim(i.current_state)) IN (
      'dev. подготовлено к релизу', 'new', 'open', 'to do', 'в работе', 'визуализация',
      'зарегистрирована', 'интеграция', 'ожидание релиза', 'отложена / в ожидании',
      'подлежит обсуждению', 'проверка / тест', 'прод. подлежит проверке',
      'системный анализ', 'требуется уточнение'
  ))
ORDER BY u.role, u.username, u.id, i.updated_at DESC NULLS LAST, i.issue_id;
