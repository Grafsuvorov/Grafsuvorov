insert into ods.bank_statement_position
select
tech_etl.util_text_to_null_validation("KUKEY") as statement_code,
tech_etl.util_text_to_null_validation("ESNUM")  as statement_position_line_item_code,
substring(tech_etl.util_text_to_null_validation("BELNR")from '[0-9].{0,10}')  as accounting_document_code,
substring(tech_etl.util_text_to_null_validation("NBBLN") from '[0-9].{0,10}')as support_accounting_document_code
from stg."FEBEP"
where 1=1
and "MANDT" = '400';