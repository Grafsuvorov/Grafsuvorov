insert into ods."/rusal/alloc_wag_ral"
select 
	tech_etl.util_text_to_null_validation("MARKET") as market,
	tech_etl.util_text_to_null_validation("MONTH_OTGR") as month_otgr,
	tech_etl.util_text_to_null_validation("MATKL") as matkl,
	tech_etl.util_text_to_null_validation("PIMARY") as pimary,
	tech_etl.util_text_to_null_validation("LOCID") as locid,
	tech_etl.util_text_to_null_validation("MATNR") as matnr,
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("KORR_BW") as korr_bw,
	tech_etl.util_text_to_null_validation("NUMVR") as numvr,
	tech_etl.util_text_to_null_validation("RESERV") as reserv,
	tech_etl.util_text_to_null_validation("NO_RASP") as no_rasp,
	tech_etl.util_text_to_null_validation("ALLOCNR") as allocnr,
	tech_etl.util_text_to_null_validation("WAGNR") as wagnr,
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_date_validation("D_WERKS_OTGR_P") as d_werks_otgr_p,
	tech_etl.util_text_to_null_validation("VBELI") as vbeli
from stg."/RUSAL/ALLOC_WAG" aw
where aw."MANDT" = '400';