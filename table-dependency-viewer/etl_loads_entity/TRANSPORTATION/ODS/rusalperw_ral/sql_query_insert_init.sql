insert into ods."/rusal/perw_ral"
select
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("ID") as "id",
	tech_etl.util_text_to_null_validation("POS") as pos,
	tech_etl.util_text_to_null_validation("POSV") as posv,
	tech_etl.util_text_to_null_validation("UNAME") as uname,
	tech_etl.util_text_to_date_validation("CPUDT") as cpudt,
	tech_etl.util_text_to_time_validation("CPUTM") as cputm,
	tech_etl.util_text_to_null_validation("EBELN") as ebeln,
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_null_validation("BL") as bl,
	tech_etl.util_text_to_date_validation("WWERT") as wwert,
	"N_PLATA" * (10 ^ (2 - coalesce(dp1.decimal_place_number, 2))) as n_plata,
	"NDS" * (10 ^ (2 - coalesce(dp1.decimal_place_number, 2))) as nds,
	tech_etl.util_text_to_null_validation("WAERS") as waers,	
	"N_DMBTR" * (10 ^ (2 - coalesce(dp2.decimal_place_number, 2))) as n_dmbtr,
	tech_etl.util_text_to_null_validation("N_HWAER") as n_hwaer,
	"N_DMBE2" * (10 ^ (2 - coalesce(dp3.decimal_place_number, 2))) as n_dmbe2,
	tech_etl.util_text_to_null_validation("N_HWAE2") as n_hwae2
from stg."/RUSAL/PERW"
	left join dict_dds.currency_decimal_place_ral as dp1			---джойн с TCURX RAL
		on dp1.currency_code = "WAERS"
	left join dict_dds.currency_decimal_place_ral as dp2			---джойн с TCURX RAL
		on dp2.currency_code = "N_HWAER"
	left join dict_dds.currency_decimal_place_ral as dp3			---джойн с TCURX RAL
		on dp3.currency_code = "N_HWAE2"
where "MANDT" = '400';