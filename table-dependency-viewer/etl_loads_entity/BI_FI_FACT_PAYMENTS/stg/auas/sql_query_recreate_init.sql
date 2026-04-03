select tech_etl.etl_source_to_greenplum_new(
        v_source_schema_name := 'SAPSR3',
        v_source_table_name := 'AUAS',
        v_fields_list := 'BELNR,LFDNR,WTGBTR,TWAER,WKGBTR,KEY01,PLFNR,MANDT',
        v_target_schema_name := 'STG',
        v_target_table_name := 'AUAS',
        v_server_id := 1,
        v_distribution_field := 'MANDT,BELNR,LFDNR',
        v_pk := '"MANDT" || "BELNR" || "LFDNR"'
        );