
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose up -d --force-recreate
[+] Running 2/2
 ⠿ Container table-dependency-viewer-api-1       Started                                                                           0.9s
 ⠿ Container table-dependency-viewer-frontend-1  Started                                                                           0.9s
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose exec api /bin/sh -c 'ls /app/etl_loads_entity | head'
1C_FI
ALARM_ACCIDENT_LOADER_1
ALARM_ACCIDENT_LOADER_2
ALARM_ACCIDENT_LOADER_3
ALARM_ACCIDENT_LOADER_4
ALVERSE
BI_FI
BI_FI_FACT_PAYMENTS
BI_INVESTMENT
BI_SB_WUC
[root@rgm-s-dwhapp01 table-dependency-viewer]# docker compose logs --tail=10 api
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.toro2_flc_avc depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.toro2_ntf_hdr depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.toro2_ntf_wrp depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.toro2_ord_cst depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.toro2_ord_hdr depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ❌ BROKEN DEP: stg.toro2_ord_opr depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
table-dependency-viewer-api-1  | ⚠️ rebuilding orderbreaches cache
table-dependency-viewer-api-1  | Ошибка при старте приложения: /app/scripts/dagre_layout.cjs
table-dependency-viewer-api-1  | INFO:     Application startup complete.
table-dependency-viewer-api-1  | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
[root@rgm-s-dwhapp01 table-dependency-viewer]# cd table-dependency-viewer
