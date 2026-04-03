insert into ods.vbuk_ral
select
	l."VBELN" as vbeln,
	tech_etl.util_text_to_null_validation(l."KOSTK") as kostk,
	tech_etl.util_text_to_null_validation(l."SAPRL") as saprl
from stg."VBUK" as l
where "MANDT" = '400';