table_name: purchase_agreement_header
table_schema: dds
table_id: 2030
source_id: 6
source_type: GREENPLUM
flag_has_views: false
table_load_mode: TRUNCATE_INIT
job_id: 298
job_name: STG_LOADER
table_loading_index: 1
entity_id: 34
entity_name: TRANSPORTATION
object_type: TABLE
table_load_interval:
  days: 1
  hours: 0
  minutes: 0
  seconds: 0
flag_waiting_dag_finished: false
start_date: '2024-12-22 01:30:00'
sql_query_recreate_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/TRANSPORTATION/dds/purchase_agreement_header/sql_query_recreate_init.sql
sql_query_insert_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/TRANSPORTATION/dds/purchase_agreement_header/sql_query_insert_init.sql
sql_query_truncate: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/TRANSPORTATION/dds/purchase_agreement_header/sql_query_truncate.sql
depends_on:
  ods:
    - dms_doc2loio_ral
    - dms_ph_cd1_ral
    - dms_phio2file_ral
    - ekko_ral
verification:
  - duplicate_check
key_attributes:
  - purchase_agreement_code


table_name: accounting_external_contracts
table_schema: dm_calc
table_id: 1401
source_id: 15
source_type: GREENPLUM
flag_has_views: false
table_load_mode: TRUNCATE_INIT
job_id: 296
job_name: STG_JOB
table_loading_index: 1
entity_id: 36
entity_name: BI_FI
object_type: TABLE
table_load_interval:
  days: 1
  hours: 0
  minutes: 0
  seconds: 0
flag_waiting_dag_finished: false
start_date: '2024-12-22 03:00:00'
sql_query_recreate_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/BI_FI/dm_calc/accounting_external_contracts/sql_query_recreate_init.sql
sql_query_insert_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/BI_FI/dm_calc/accounting_external_contracts/sql_query_insert_init.sql
sql_query_truncate: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/BI_FI/dm_calc/accounting_external_contracts/sql_query_truncate.sql
depends_on:
  dict_dds:
    - user_main_data
    - purchase_group
    - sales_group
    - personnel_main_data
  dds:
    - sales_contract
    - purchase_order_header
    - sales_document_counterparty_role
    - financial_loan_terms
    - purchase_contract_header
    - purchase_agreement_header
    - purchase_document_counterparty_role
verification:
  - duplicate_check
key_attributes:
  - contract_code
  - unit_balance_code
  - dt_external_contract
