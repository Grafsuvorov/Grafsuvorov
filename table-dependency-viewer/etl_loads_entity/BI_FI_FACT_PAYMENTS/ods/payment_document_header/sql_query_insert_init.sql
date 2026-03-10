insert into ods.payment_document_header
select
	tech_etl.util_text_to_date_validation(reguh."LAUFD") as dt_program_execution,
	tech_etl.util_text_to_null_validation(reguh."LAUFI") as additional_identifier_code,
	tech_etl.util_text_to_null_validation(reguh."XVORL") as is_trial_execution,
	tech_etl.util_text_to_null_validation(reguh."ZBUKR") as payer_unit_balance_code,
	tech_etl.util_text_to_null_validation(reguh."LIFNR") as supplier_code,
	tech_etl.util_text_to_null_validation(reguh."KUNNR") as customer_code,
	tech_etl.util_text_to_null_validation(substring(reguh."EMPFG" from '[0-9].{0,9}')) as payee_code,
	tech_etl.util_text_to_null_validation(reguh."VBLNR") as payment_document_code,
	tech_etl.util_text_to_null_validation(reguh."PYORD") as payment_order_code
from stg."REGUH" reguh
where 1=1
and reguh."MANDT" = '400';