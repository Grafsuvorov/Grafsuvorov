select tech_etl.etl_source_to_greenplum_new(
    v_source_schema_name := 'SAPSR3',
    v_source_table_name := 'ZLE_DISLCONT',
    v_fields_list := 'MANDT,ID,POS,CONTAINER,NUMNAKL,CARNUMBER,OPER_CODE,OPER_NAME,OPER_DATE,OPER_TIME,OPER_STATION,LOAD_STATION,DEST_STATION,LOAD_DATE,LOAD_TIME,ET_TARIF,WEIGHT,IND1,IND2,IND3,ISFULL,TRNO,CARGOSENDER_OKPO,CARGOSENDER,CARGORECEIVER_OKPO,CARGORECEIVER,ARCHIVE,ERDAT,ERZET,ERNAM,AEDAT,AEZET,AENAM',
    v_target_schema_name := 'STG',
    v_target_table_name := 'ZLE_DISLCONT',
    v_server_id := '1',
    v_distribution_field := 'RN',
    v_pk := '"ID" || "POS" || "CARNUMBER" || "MANDT" || "CONTAINER" || "NUMNAKL"'
);
   