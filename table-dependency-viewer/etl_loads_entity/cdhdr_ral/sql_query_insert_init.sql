insert into ods.cdhdr_ral
select 
tech_etl.util_text_to_null_validation("CHANGENR") as changenr,
tech_etl.util_text_to_null_validation("USERNAME") as username,
tech_etl.util_text_to_null_validation("OBJECTCLAS") as objectclas,
tech_etl.util_text_to_null_validation("OBJECTID") as objectid,
tech_etl.util_text_to_date_validation("UDATE") as udate,
tech_etl.util_text_to_time_validation("UTIME") as utime,
tech_etl.util_text_to_time_validation("TCODE") as tcode
from stg."CDHDR"
where "MANDANT" = '400';