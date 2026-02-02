-- 1) Статус resource group
select * 
from gp_toolkit.gp_resgroup_status
where groupname = (
  select rolresgroup from pg_roles where rolname = current_user
);

-- 2) Активные запросы в сессии
select
  pid,
  state,
  now() - query_start as running,
  left(query, 200)
from pg_stat_activity
where usename = current_user;

-- 3) Проверка времени/таймзоны
select
  current_timestamp,
  current_setting('TimeZone');
