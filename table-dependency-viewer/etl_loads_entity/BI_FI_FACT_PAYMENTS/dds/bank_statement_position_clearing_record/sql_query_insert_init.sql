insert into dds.bank_statement_position_clearing_record
select
tech_etl.util_text_to_null_validation("KUKEY") as statement_code,
tech_etl.util_text_to_null_validation("ESNUM")as statement_position_line_item_code,
tech_etl.util_text_to_null_validation("CSNUM") as clearing_position_code,
tech_etl.util_text_to_null_validation("AGKON")  as counterparty_code,
substring (max(case when "SELFD" = 'BELNR' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,10}') end) from 1 for 10) as accounting_document_code,	   
substring (max(case when "SELFD" = 'BELNR' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,14}') end) from 11 for 4) as accounting_document_fiscal_year,	
max(case when "SELFD" = 'PYORD' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,20}') end) as payment_order_code,   
ltrim (max(case when "SELFD" = 'VERTN' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,20}') end), '0') as contract_number,
max(case when "SELFD" = 'WRBTR' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,20}') end)::numeric(17,2) as document_currency_amount,
max(case when "SELFD" = 'XBLNR' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,20}') end) as reference_document_code,
max(case when "SELFD" = 'ZUONR' then substring(tech_etl.util_text_to_null_validation("SELVON") from '[0-9].{0,20}') end) as assignment_number
from stg."FEBCL"
where 1=1
and "MANDT" = '400'
group by 
tech_etl.util_text_to_null_validation("KUKEY"),
tech_etl.util_text_to_null_validation("ESNUM"),
tech_etl.util_text_to_null_validation("CSNUM"),
tech_etl.util_text_to_null_validation("AGKON");