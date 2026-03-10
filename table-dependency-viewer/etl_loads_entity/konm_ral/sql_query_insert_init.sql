insert into ods.konm_ral
select 
	tech_etl.util_text_to_null_validation("KNUMH") as knumh,
	tech_etl.util_text_to_null_validation("KOPOS") as kopos,
	tech_etl.util_text_to_null_validation("KLFN1") as klfn1,
	"KSTBM" as kstbm,
	"KBETR" as kbetr
from stg."KONM"
where "MANDT" = '400';