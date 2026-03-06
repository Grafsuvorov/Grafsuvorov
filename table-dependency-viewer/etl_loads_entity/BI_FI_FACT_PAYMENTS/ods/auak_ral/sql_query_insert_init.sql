insert into ods."auak_ral"
select tech_etl.util_text_to_null_validation("BELNR") as belnr,
tech_etl.util_text_to_null_validation("PERBZ") as perbz,
tech_etl.util_text_to_null_validation("OBJNR") as objnr,
tech_etl.util_text_to_null_validation("GJAHR") as gjahr,
tech_etl.util_text_to_null_validation("KOKRS") as kokrs
from stg."AUAK" 
where "MANDT" = '400';