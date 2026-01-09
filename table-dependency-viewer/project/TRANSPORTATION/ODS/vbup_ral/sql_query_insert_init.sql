insert into ods.vbup_ral
select
	"VBELN" as vbeln,
	"POSNR" as posnr,
	tech_etl.util_text_to_null_validation("KOSTA") as kosta
from stg."VBUP"
where "MANDT" = '400';