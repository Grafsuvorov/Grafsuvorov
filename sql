1. Сначала проверь, под кем реально работает пользователь
Пусть он выполнит:
SELECT
    current_user,
    session_user,
    current_database(),
    current_setting('search_path');


Возможно, пользователь подключается через другую роль или к другой базе данных.
2. Проверь права в его сессии
SELECT
    has_schema_privilege(
        current_user, 'dm', 'USAGE'
    ) AS schema_usage,
    has_table_privilege(
        current_user, 'dm.customer', 'SELECT'
    ) AS table_select,
    has_table_privilege(
        session_user, 'dm.customer', 'SELECT'
    ) AS session_user_select;


3. Проверь, кому действительно выданы права
Под администратором:
SELECT
    n.nspname,
    c.relname,
    c.relowner::regrole AS owner,
    c.relacl
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
WHERE n.nspname = 'dm'
  AND c.relname = 'customer';


relacl покажет права, назначенные на таблицу.
4. Если права действительно отсутствуют
Выполни под владельцем таблицы или администратором:
GRANT USAGE ON SCHEMA dm TO user_name;

GRANT SELECT ON TABLE dm.customer TO user_name;


После этого пользователь должен получить true.
Ещё одна важная причина
В Greenplum права выдаются в рамках конкретной базы данных.

Например, ты проверяешь права в prod, а пользователь подключается к dev. Тогда результаты могут отличаться, даже если имена схем и таблиц одинаковые.

Уточни мне два момента:
1. Когда ты проверяешь has_table_privilege('user_name', ...), ты находишься в той же базе Greenplum, что и пользователь?
2. Что возвращает SELECT current_user, session_user; у проблемного пользователя?
По этим двум ответам сможем определить, почему у тебя true, а у него false.
