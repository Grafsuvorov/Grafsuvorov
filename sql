select
  groupname,
  num_running,
  num_queued,
  num_executed,
  memory_used,
  memory_available
from gp_toolkit.gp_resgroup_status
where groupname = (
  select rolresgroup
  from pg_roles
  where rolname = current_user
);
