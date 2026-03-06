insert into ods."dms_phio2file_ral"
select tech_etl.util_text_to_null_validation("FILE_ID") as file_id,
tech_etl.util_text_to_null_validation("FILENAME") as filename
from stg."DMS_PHIO2FILE";
