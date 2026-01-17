insert into ods.vbrp_ral (
	vbeln,posnr,vgtyp,vgbel,matnr,pstyv,netwr,aubel,aupos,fkimg,brgew,kvgr5,mwsbp,vgpos)

select
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_null_validation("POSNR") as posnr,
	tech_etl.util_text_to_null_validation("VGTYP") as vgtyp,
	tech_etl.util_text_to_null_validation("VGBEL") as vgbel,
	tech_etl.util_text_to_null_validation("MATNR") as matnr,
	tech_etl.util_text_to_null_validation("PSTYV") as pstyv,
	"NETWR" as netwr,
	tech_etl.util_text_to_null_validation("AUBEL") as aubel,
	tech_etl.util_text_to_null_validation("AUPOS") as aupos,
	"FKIMG" as fkimg,
	"BRGEW" as brgew,
	tech_etl.util_text_to_null_validation("KVGR5") as kvgr5,
	"MWSBP" as mwsbp,
	tech_etl.util_text_to_null_validation("VGPOS") as vgpos
from
	stg."VBRP"
where
	"MANDT" = '400';
