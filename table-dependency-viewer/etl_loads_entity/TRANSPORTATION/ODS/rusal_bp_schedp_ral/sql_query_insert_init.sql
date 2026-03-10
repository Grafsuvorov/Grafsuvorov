insert into ods."/rusal/bp_schedp_ral"(
	gjahr,
	"version",
	oper,
	posnr,
	werks,
	pickup,
	sdabw,
	werks_kn,
	port_from,
	port_frkn,
	zpr_cont,
	zpr_pl,
	prdouble,
	zlencont,
	menge_sum
)
select 
	tech_etl.util_text_to_null_validation("GJAHR") as gjahr,
	tech_etl.util_text_to_null_validation("VERSION") as "version",
	tech_etl.util_text_to_null_validation("OPER") as oper,
	tech_etl.util_text_to_null_validation("POSNR") as posnr,
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("PICKUP") as pickup,
	tech_etl.util_text_to_null_validation("SDABW") as sdabw,
	tech_etl.util_text_to_null_validation("WERKS_KN") as werks_kn,
	tech_etl.util_text_to_null_validation("PORT_FROM") as port_from,
	tech_etl.util_text_to_null_validation("PORT_FRKN") as port_frkn,
	tech_etl.util_text_to_null_validation("ZPR_CONT") as zpr_cont,
	tech_etl.util_text_to_null_validation("ZPR_PL") as zpr_pl,
	tech_etl.util_text_to_null_validation("PRDOUBLE") as prdouble,
	tech_etl.util_text_to_null_validation("ZLENCONT") as zlencont,
	"MENGE_SUM" as menge_sum
from stg."/RUSAL/BP_SCHEDP";