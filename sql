table_name: sales_contract_header
table_schema: dds
table_id: 2016
source_id: 6
source_type: GREENPLUM
flag_has_views: true
table_load_mode: TRUNCATE_INIT
job_id: 296
job_name: STG_JOB
table_loading_index: 1
entity_id: 35
entity_name: BI_SB_WUC
object_type: TABLE
table_load_interval:
  days: 1
  hours: 0
  minutes: 0
  seconds: 0
flag_waiting_dag_finished: false
start_date: '2024-12-22 00:30:00'
sql_query_recreate_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/BI_SB_WUC/dds/sales_contract_header/sql_query_recreate_init.sql
sql_query_insert_init: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/BI_SB_WUC/dds/sales_contract_header/sql_query_insert_init.sql
sql_query_truncate: meta_info/database/greenplum/schema_name/tech_etl/etl_loads_entity/BI_SB_WUC/dds/sales_contract_header/sql_query_truncate.sql
depends_on:
  ods:
    - zsd2902m_tollint_ral
    - vbak_ral
    - vbkd_ral
    - texts_from_sap_fm_read_text
    - zcq_paydox_ral
verification:
  - duplicate_check
key_attributes:
  - sales_contract_code


CREATE TABLE dq.data_quality_results (
	verification_type varchar(15) NULL,
	table_schema varchar(10) NULL,
	table_name varchar(100) NULL,
	metric_result text NULL,
	dt_of_verification timestamp NULL,
	sql_script text NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (table_name);

INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-11 08:58:50.242', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-15 07:06:32.605', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-16 07:04:44.007', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-12 07:04:18.229', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-15 15:57:58.236', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-13 07:01:31.621', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-14 07:01:29.141', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-22 07:01:33.719', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-23 07:01:44.489', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-17 07:07:18.282', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-18 07:01:39.450', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-19 07:05:29.701', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-15 15:58:02.667', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-18 07:01:53.518', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-11 08:58:25.628', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-12 07:04:25.942', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-13 07:01:46.640', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-14 07:01:44.829', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-15 07:06:44.084', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-16 07:04:52.008', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-17 07:07:19.397', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-22 07:01:47.864', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-19 07:05:47.806', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-20 07:07:34.459', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-21 07:01:56.708', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-23 07:01:57.551', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-24 07:01:14.790', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-20 07:07:14.666', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-21 07:01:40.539', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-24 07:00:59.817', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-25 07:01:51.205', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-26 07:03:12.974', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-27 07:08:00.937', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-25 07:01:59.919', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-26 07:03:21.075', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-27 07:09:08.954', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_documents', '1', '2025-12-28 07:01:23.139', '
SELECT *
FROM dds."accounting_documents"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" )
    FROM dds."accounting_documents"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dm', 'demand_planning_purchase_request_analysis_by_status', '1', '2026-01-05 07:06:33.813', '
SELECT *
FROM dm."demand_planning_purchase_request_analysis_by_status"
WHERE CONCAT_WS(''~'', "purchase_requisition_code",  "purchase_requisition_position_line_item_code",  "purchase_request_position_status_name_for_quantity" )
IN (
    SELECT CONCAT_WS(''~'', "purchase_requisition_code",  "purchase_requisition_position_line_item_code",  "purchase_request_position_status_name_for_quantity" )
    FROM dm."demand_planning_purchase_request_analysis_by_status"
    GROUP BY "purchase_requisition_code",  "purchase_requisition_position_line_item_code",  "purchase_request_position_status_name_for_quantity" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dm_calc', 'accounting_document_contracts', '1', '2025-12-19 07:05:45.856', '
SELECT *
FROM dm_calc."accounting_document_contracts"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "accounting_document_position_code" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "accounting_document_position_code" )
    FROM dm_calc."accounting_document_contracts"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "accounting_document_position_code" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'accounting_document_position_correspondence', '1', '2025-12-28 07:01:08.707', '
SELECT *
FROM dds."accounting_document_position_correspondence"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" )
    FROM dds."accounting_document_position_correspondence"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "debit_line_item_number",  "credit_line_item_number",  "debit_item_for_new_item_number",  "credit_item_for_new_item_number",  "debit_item_number_from_ledger_item_split",  "credit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dm', 'demand_planning_purchase_request_analysis', '1', '2026-01-05 07:06:33.533', '
SELECT *
FROM dm."demand_planning_purchase_request_analysis"
WHERE CONCAT_WS(''~'', "purchase_requisition_code",  "purchase_requisition_position_line_item_code" )
IN (
    SELECT CONCAT_WS(''~'', "purchase_requisition_code",  "purchase_requisition_position_line_item_code" )
    FROM dm."demand_planning_purchase_request_analysis"
    GROUP BY "purchase_requisition_code",  "purchase_requisition_position_line_item_code" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'purchase_requisition', '1', '2026-01-05 07:06:22.671', '
SELECT *
FROM dds."purchase_requisition"
WHERE CONCAT_WS(''~'', "purchase_requisition_code",  "purchase_requisition_position_line_item_code" )
IN (
    SELECT CONCAT_WS(''~'', "purchase_requisition_code",  "purchase_requisition_position_line_item_code" )
    FROM dds."purchase_requisition"
    GROUP BY "purchase_requisition_code",  "purchase_requisition_position_line_item_code" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dm', 'account_turnover', '1', '2026-01-22 07:01:34.303', '
SELECT *
FROM dm."account_turnover"
WHERE CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item",  "correspondence_debit_or_credit_code",  "correspondence_line_item_number",  "credit_line_item_number",  "debit_line_item_number",  "credit_item_for_new_item_number",  "debit_item_for_new_item_number",  "credit_item_number_from_ledger_item_split",  "debit_item_number_from_ledger_item_split" )
IN (
    SELECT CONCAT_WS(''~'', "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item",  "correspondence_debit_or_credit_code",  "correspondence_line_item_number",  "credit_line_item_number",  "debit_line_item_number",  "credit_item_for_new_item_number",  "debit_item_for_new_item_number",  "credit_item_number_from_ledger_item_split",  "debit_item_number_from_ledger_item_split" )
    FROM dm."account_turnover"
    GROUP BY "unit_balance_code",  "fiscal_year",  "accounting_document_code",  "position_line_item",  "correspondence_debit_or_credit_code",  "correspondence_line_item_number",  "credit_line_item_number",  "debit_line_item_number",  "credit_item_for_new_item_number",  "debit_item_for_new_item_number",  "credit_item_number_from_ledger_item_split",  "debit_item_number_from_ledger_item_split" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dm_calc', 'accounting_external_contracts', '1', '2025-12-19 07:05:35.879', '
SELECT *
FROM dm_calc."accounting_external_contracts"
WHERE CONCAT_WS(''~'', "contract_code",  "unit_balance_code",  "dt_external_contract" )
IN (
    SELECT CONCAT_WS(''~'', "contract_code",  "unit_balance_code",  "dt_external_contract" )
    FROM dm_calc."accounting_external_contracts"
    GROUP BY "contract_code",  "unit_balance_code",  "dt_external_contract" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('duplicate_check', 'dds', 'investment_expenses', '1', '2025-12-15 07:00:04.725', '
SELECT *
FROM dds."investment_expenses"
WHERE CONCAT_WS(''~'', "unit_budget_code",  "measure_type_code",  "investment_budget_section_code",  "investment_budget_subsection_code",  "version_code",  "fiscal_year",  "division_code",  "is_additional_finance_code",  "unit_budget_partner_code",  "investment_activity_code",  "investment_area_code",  "purchase_document_code",  "investment_budget_adjustment_number",  "investment_activity_status_code",  "financing_status_code",  "budget_group_code",  "amount_currency_code",  "dt_report",  "dt_investment_expense_or_payment",  "dt_created",  "created_by",  "counterparty_code",  "unit_budget_payer_code" )
IN (
    SELECT CONCAT_WS(''~'', "unit_budget_code",  "measure_type_code",  "investment_budget_section_code",  "investment_budget_subsection_code",  "version_code",  "fiscal_year",  "division_code",  "is_additional_finance_code",  "unit_budget_partner_code",  "investment_activity_code",  "investment_area_code",  "purchase_document_code",  "investment_budget_adjustment_number",  "investment_activity_status_code",  "financing_status_code",  "budget_group_code",  "amount_currency_code",  "dt_report",  "dt_investment_expense_or_payment",  "dt_created",  "created_by",  "counterparty_code",  "unit_budget_payer_code" )
    FROM dds."investment_expenses"
    GROUP BY "unit_budget_code",  "measure_type_code",  "investment_budget_section_code",  "investment_budget_subsection_code",  "version_code",  "fiscal_year",  "division_code",  "is_additional_finance_code",  "unit_budget_partner_code",  "investment_activity_code",  "investment_area_code",  "purchase_document_code",  "investment_budget_adjustment_number",  "investment_activity_status_code",  "financing_status_code",  "budget_group_code",  "amount_currency_code",  "dt_report",  "dt_investment_expense_or_payment",  "dt_created",  "created_by",  "counterparty_code",  "unit_budget_payer_code" 
    HAVING COUNT(1)>1
)
');
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_ods', 'T001K', '568', '2025-11-06 13:51:26.519', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'budget_group_texts', '43', '2025-11-06 13:51:27.203', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'client_grp2', '22', '2025-11-06 13:51:43.773', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'material_type', '45', '2025-11-06 13:51:43.929', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'general_ledger_accounts_main_data', '1330659', '2025-11-06 13:51:44.559', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'doc_grp_process', '70', '2025-11-06 13:51:45.966', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'foreign_trade', '13747', '2025-11-06 13:51:59.191', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'vat_rates_texts', '9405', '2025-11-06 13:52:01.234', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'sb_unit_org_department_dsc', '399', '2025-11-06 13:52:03.276', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'plant_and_subsidiary', '613', '2025-11-06 13:52:16.896', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'counterparty_td', '487605', '2025-11-06 13:52:18.780', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'map_counterparty_to_market_region2', '20', '2025-11-06 13:52:20.075', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'accrual_type_texts', '8', '2025-11-06 13:52:33.356', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'indicator_yes_no_texts', '4', '2025-11-06 13:52:33.456', NULL);
INSERT INTO dq.data_quality_results
(verification_type, table_schema, table_name, metric_result, dt_of_verification, sql_script)
VALUES('row_count', 'dict_dds', 'purchase_supplier_master_data', '868029', '2025-11-06 13:52:33.941', NULL);
