insert into ods.bank_statement_header
select
tech_etl.util_text_to_null_validation("ANWND") as statement_type_code,
substring(tech_etl.util_text_to_null_validation("ABSND") from '^\d+') as bic_code,
substring(tech_etl.util_text_to_null_validation("ABSND") from '\s+(\d+)\s+') as company_account_code,
substring(tech_etl.util_text_to_null_validation("ABSND") from '\s+([A-Za-z]+$)') as statement_currency_code,
substring(tech_etl.util_text_to_null_validation("AZIDT") from 1 for 4)::numeric as statement_fiscal_year,
substring(tech_etl.util_text_to_null_validation("AZIDT") from 5) as statement_number,
tech_etl.util_text_to_null_validation("EMKEY") as payee_code,
tech_etl.util_text_to_null_validation("KUKEY") as statement_code
from stg."FEBKO"
where 1=1
and "MANDT" = '400';