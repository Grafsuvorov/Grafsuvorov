insert into ods."/rusal/perw_ral" (
	werks,
	id,
	pos,
	posv,
	uname,
	cpudt,
	cputm,
	ebeln,
	vbeln,
	bl,
	wwert,
	n_plata,
	nds,
	waers,
	n_dmbtr,
	n_hwaer,
	n_dmbe2,
	n_hwae2,
	statuss,
	dok_1172,
	declaration,
	n_nakl,
	n_wag,
	own_vag,
	platf,
	kursf,
	n_ves_n,
	d_otpravl,
	bl_bum,
	databl,
	nomtk,
	ztype,
	wapprove,
	vag_source,
	pr_no_rzd
)
with cte as (select currency_code, decimal_place_number from dict_dds.currency_decimal_place_ral)
select
	tech_etl.util_text_to_null_validation(perw."WERKS") as werks,
	tech_etl.util_text_to_null_validation(perw."ID") as "id",
	tech_etl.util_text_to_null_validation(perw."POS") as pos,
	tech_etl.util_text_to_null_validation(perw."POSV") as posv,
	tech_etl.util_text_to_null_validation(perw."UNAME") as uname,
	tech_etl.util_text_to_date_validation(perw."CPUDT") as cpudt,
	tech_etl.util_text_to_time_validation(perw."CPUTM") as cputm,
	tech_etl.util_text_to_null_validation(perw."EBELN") as ebeln,
	tech_etl.util_text_to_null_validation(perw."VBELN") as vbeln,
	tech_etl.util_text_to_null_validation(perw."BL") as bl,
	tech_etl.util_text_to_date_validation(perw."WWERT") as wwert,
	perw."N_PLATA" * (10 ^ (2 - coalesce(dp1.decimal_place_number, 2))) as n_plata,
	perw."NDS" * (10 ^ (2 - coalesce(dp1.decimal_place_number, 2))) as nds,
	tech_etl.util_text_to_null_validation(perw."WAERS") as waers,
	perw."N_DMBTR" * (10 ^ (2 - coalesce(dp2.decimal_place_number, 2))) as n_dmbtr,
	tech_etl.util_text_to_null_validation(perw."N_HWAER") as n_hwaer,
	perw."N_DMBE2" * (10 ^ (2 - coalesce(dp3.decimal_place_number, 2))) as n_dmbe2,
	tech_etl.util_text_to_null_validation(perw."N_HWAE2") as n_hwae2,
	tech_etl.util_text_to_null_validation(perw."STATUSS") as statuss,
	tech_etl.util_text_to_null_validation(perw."DOK_1172") as dok_1172,
	tech_etl.util_text_to_null_validation(perw."DECLARATION") as declaration,
	tech_etl.util_text_to_null_validation(perw."N_NAKL") as n_nakl,
	tech_etl.util_text_to_null_validation(perw."N_WAG") as n_wag,
	tech_etl.util_text_to_null_validation(perw."OWN_VAG") as own_vag,
	tech_etl.util_text_to_null_validation(perw."PLATF") as platf,
	perw."KURSF" as kursf,
	perw."N_VES_N" as n_ves_n,
	tech_etl.util_text_to_date_validation(perw."D_OTPRAVL") as d_otpravl,
	tech_etl.util_text_to_null_validation(perw."BL_BUM") as bl_bum,
	tech_etl.util_text_to_date_validation(perw."DATABL") as databl,
	tech_etl.util_text_to_null_validation(perw."NOMTK") as nomtk,
	tech_etl.util_text_to_null_validation(perw."ZTYPE") as ztype,
	tech_etl.util_text_to_null_validation(perw."WAPPROVE") as wapprove,
	tech_etl.util_text_to_null_validation(perw."VAG_SOURCE") as vag_source,
	tech_etl.util_text_to_null_validation(perw."PR_NO_RZD") as pr_no_rzd
from stg."/RUSAL/PERW" as perw
	left join cte as dp1			---джойн с TCURX RAL
		   on dp1.currency_code = perw."WAERS"
	left join cte as dp2			---джойн с TCURX RAL
		   on dp2.currency_code = perw."N_HWAER"
	left join cte as dp3			---джойн с TCURX RAL
	  	   on dp3.currency_code = perw."N_HWAE2"
where perw."MANDT" = '400';


