insert into ods."auas_ral"
select 
tech_etl.util_text_to_null_validation("BELNR") as belnr,
tech_etl.util_text_to_null_validation("LFDNR") as lfdnr,
"WTGBTR" as wtgbtr,
tech_etl.util_text_to_null_validation("TWAER") as twaer,
"WKGBTR" as wkgbtr,
tech_etl.util_text_to_null_validation("KEY01") as key01,
tech_etl.util_text_to_null_validation("PLFNR") as plfnr
from stg."AUAS" 
where "MANDT" = '400';