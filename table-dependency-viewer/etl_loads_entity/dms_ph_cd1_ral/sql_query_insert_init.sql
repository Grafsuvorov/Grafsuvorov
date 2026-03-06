insert into ods."dms_ph_cd1_ral"
select tech_etl.util_text_to_null_validation("PHIO_ID") as phio_id,
tech_etl.util_text_to_null_validation("LOIO_ID") as loio_id,
tech_etl.util_text_to_null_validation("PROP08") as prop08
from stg."DMS_PH_CD1"
where "MANDT" = '400';
