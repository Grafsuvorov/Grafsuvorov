insert into ods."/rusal/perp_ral"
select
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("ID") as id,
	tech_etl.util_text_to_null_validation("POS") as pos,
	tech_etl.util_text_to_null_validation("SRVPOS") as srvpos,
	tech_etl.util_text_to_null_validation("NOMD") as nomd,
	"SUMS" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as sums,
	"NDS" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as nds,	
	tech_etl.util_text_to_null_validation("WAERS") as waers,
	tech_etl.util_text_to_null_validation("AKT_ID") as akt_id,
	tech_etl.util_text_to_null_validation("FISTL") as fistl,
	tech_etl.util_text_to_null_validation("ETSNG") as etsng,
	tech_etl.util_text_to_null_validation("EBELNY") as ebelny
from stg."/RUSAL/PERP"
	left join dict_dds.currency_decimal_place_ral as dp			---джойн с TCURX RAL
		on dp.currency_code = "WAERS"
where "MANDT" = '400';