select
    pid,
    state,
    xact_start,
    now() - xact_start as xact_age,
    query
from pg_stat_activity
where usename = current_user;
