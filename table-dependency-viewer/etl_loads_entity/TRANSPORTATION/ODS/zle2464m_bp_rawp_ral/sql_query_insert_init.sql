insert into ods."zle2464m_bp_rawp_ral"(
	gjahr,
	matnr,
	"version",
	posnr,
	etsng,
	scheme,
	sdabw,
	knanf,
	knend,
	menge
)
select 
	tech_etl.util_text_to_null_validation("GJAHR") as gjahr,
	tech_etl.util_text_to_null_validation("MATNR") as matnr,	
	tech_etl.util_text_to_null_validation("VERSION") as "version",
	tech_etl.util_text_to_null_validation("POSNR") as posnr,	
	tech_etl.util_text_to_null_validation("ETSNG") as etsng,	
	tech_etl.util_text_to_null_validation("SCHEME") as scheme,
	tech_etl.util_text_to_null_validation("SDABW") as sdabw,		
	tech_etl.util_text_to_null_validation("KNANF") as knanf,	
	tech_etl.util_text_to_null_validation("KNEND") as knend,
	"MENGE" as menge
from stg."ZLE2464M_BP_RAWP";