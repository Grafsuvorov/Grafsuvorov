select tech_etl.etl_source_to_greenplum_new(
        v_source_schema_name := 'SAPSR3',
        v_source_table_name := 'ZFI3436M_BI',
        v_fields_list := 'KUNNRKEY,VERTNKEY,FO_VBELNKEY,FO_POSNRKEY,USNAM,D_NAME,D_STATUS,BUKRS,BUKRS_WAERS,BUKRS_PR,BUKRS_LIFNR,NAME_KUNNR,VERTN_PR,VERTN_PR_NAME,TRADER,TRADER_NAME,NAME_VERTN,WAERS,INCO1,PROC_NDS,VERTN_S,BUDAT_BY,DATE_RATE,USD_RATE,SUMM_PAY,ZAVOD,LFIMG,VRKME,O_WRBTR,WWERT,KURSF,O_DMBTR,HWAER,GRUZPOL,GRUZPOL_NAME,MATNR,NSPECIF,PIMARY,VR_STATUS,LME,Z005,PR_CONTRACTPREMUSD,ZEDO',	
        v_target_schema_name := 'STG',
        v_target_table_name := 'ZFI3436M_BI',
        v_server_id := 1,
        v_distribution_field := 'RN',
        v_pk := '"KUNNRKEY" || "VERTNKEY" || "FO_VBELNKEY" || "FO_POSNRKEY"'
);