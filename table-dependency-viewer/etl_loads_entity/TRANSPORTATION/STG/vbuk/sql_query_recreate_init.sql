select tech_etl.etl_source_to_greenplum_new(
    v_source_schema_name := 'SAPSR3',
    v_source_table_name := 'VBUK',
    v_fields_list := 'ALL',
    v_target_schema_name := 'STG',
    v_target_table_name := 'VBUK',
    v_server_id := 1,
    v_distribution_field := '',
    v_pk := '"MANDT" || "VBELN"' 
);