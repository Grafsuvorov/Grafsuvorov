SELECT
    current_user,
    session_user,
    current_database(),
    inet_server_addr(),
    inet_server_port(),
    has_schema_privilege(current_user, 'dm', 'USAGE'),
    has_table_privilege(current_user, 'dm.customer', 'SELECT');
