   select tech_etl.etl_source_to_greenplum_new(
    v_source_schema_name := 'SAPSR3',
    v_source_table_name := 'ZTLE_RAILCN',
    v_fields_list := 'BELNR_MM,BUZEI_MM,MBLNR_MM,FORWARDER,ERNAM,AEDAT,AEZET,AENAM,MANDT,ID,POS,TYPE_LOAD,CONTAINER,NUMNAKL,DATEOT,CAR_NUM,ZDKODSTFR,TRANS_KN,TRANS_DATE,BORDER_KN,ZDKODSTTO,WERKS,WERKS_NAME,GRADE,MATNR,ETSNG,WEIGHT,WEIGHT_BR,RF_DATE,RF_NUMNAKL,VBELN,DTL_VBELN,DTL_TKNUM,DTL_FKNUM,VBELN_LE05,VBELN_LE35,VBELN_LE30,ERDAT,ERZET',
    v_target_schema_name := 'STG',
    v_target_table_name := 'ZTLE_RAILCN',
    v_server_id := '1',
    v_distribution_field := 'RN',
    v_pk := '"POS" || "TYPE_LOAD" || "NUMNAKL" || "ID" || "CONTAINER" || "MANDT"'
);