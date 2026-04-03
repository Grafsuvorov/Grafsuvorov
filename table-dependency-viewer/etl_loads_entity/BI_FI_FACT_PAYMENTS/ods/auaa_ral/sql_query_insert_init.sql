insert into ods."auaa_ral"
select tech_etl.util_text_to_null_validation("BELNR") as belnr,
tech_etl.util_text_to_null_validation("LFDNR") as lfdnr,
tech_etl.util_text_to_null_validation("EMTYP") as emtyp,
tech_etl.util_text_to_null_validation("BUKRS") as bukrs
from stg."AUAA" 
where "MANDT" = '400'
;