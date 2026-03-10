select tech_etl.etl_source_to_greenplum_new(
v_source_schema_name := 'SAPSR3',
v_source_table_name := 'ZLE_DOG_LIMIT',
v_fields_list := 'ALL',
v_target_schema_name := 'STG',
v_target_table_name := 'ZLE_DOG_LIMIT',
v_server_id := 1, -- 2 в случае oracle_sap_bi_prod
v_distribution_field := 'EBELN',
v_pk := '"MANDT" || "EBELN"'
);