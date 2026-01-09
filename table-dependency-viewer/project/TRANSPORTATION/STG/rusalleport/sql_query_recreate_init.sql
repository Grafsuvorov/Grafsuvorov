select tech_etl.etl_source_to_greenplum_new(
    v_source_schema_name := 'SAPSR3',
    v_source_table_name := '/RUSAL/LEPORT',
    v_fields_list := 'DATAVP,TERMINAL_RF,BL_FIRST,MANDT,BL,DATABL,CONTAINER,TRATY,PORT_FROM,PORT_TO,ROUTE,TERMINAL_TO,EXPED_PORT,EXPED_FREIGHT,DATA_SHIP,DATAOT,NAKLADN,VAGON,OWNER_PLATF,AUTO,VBELN_LE,ERDAT,ERZET,ERNAM,AEDAT,AEZET,AENAM,DATADU,DU',
    v_target_schema_name := 'STG',
    v_target_table_name := '/RUSAL/LEPORT',
    v_server_id := '1',
    v_distribution_field := 'RN',
    v_pk := '"CONTAINER" || "MANDT" || "DATABL" || "BL"'
);