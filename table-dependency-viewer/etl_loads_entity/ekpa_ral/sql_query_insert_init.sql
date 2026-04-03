insert into ods."ekpa_ral"
select 
tech_etl.util_text_to_null_validation ("EBELN") as ebeln,
tech_etl.util_text_to_null_validation ("EBELP") as ebelp,
tech_etl.util_text_to_null_validation ("EKORG") as ekorg,
tech_etl.util_text_to_date_validation ("ERDAT") as erdat,
tech_etl.util_text_to_null_validation ("ERNAM") as ernam,
tech_etl.util_text_to_null_validation ("LIFN2") as lifn2,
tech_etl.util_text_to_null_validation ("PARVW") as parvw,
tech_etl.util_text_to_null_validation ("PARZA") as parza,
tech_etl.util_text_to_null_validation ("PERNR") as pernr,
tech_etl.util_text_to_null_validation ("WERKS") as werks,
tech_etl.util_text_to_null_validation ("LTSNR") as ltsnr
from stg."EKPA" 
where "MANDT" = '400';