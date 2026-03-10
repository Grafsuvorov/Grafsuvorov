insert into ods.payment_document_position
select
	tech_etl.util_text_to_date_validation(regup."LAUFD") as dt_program_execution,
	tech_etl.util_text_to_null_validation(regup."LAUFI") as additional_identifier_code,
	tech_etl.util_text_to_null_validation(regup."XVORL") as is_trial_execution,
	tech_etl.util_text_to_null_validation(regup."ZBUKR") as payer_unit_balance_code,
	tech_etl.util_text_to_null_validation(regup."LIFNR") as supplier_code,
	tech_etl.util_text_to_null_validation(regup."KUNNR") as customer_code,
	tech_etl.util_text_to_null_validation(substring(regup."EMPFG" from '[0-9].{0,9}')) as payee_code,
	tech_etl.util_text_to_null_validation(regup."VBLNR") as payment_document_code,
	tech_etl.util_text_to_null_validation(regup."BUKRS") as unit_balance_code,
	tech_etl.util_text_to_null_validation(regup."BELNR") as accounting_document_code,
	tech_etl.util_text_to_null_validation(regup."GJAHR")::numeric as accounting_document_fiscal_year,
	tech_etl.util_text_to_null_validation(regup."BUZEI")::numeric as accounting_document_position_line_item_code
from stg."REGUP" regup
where 1=1
and regup."MANDT" = '400';