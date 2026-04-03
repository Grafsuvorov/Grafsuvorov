insert into ods."/rusal/perf_ral"
select
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("ID") as id,
	tech_etl.util_text_to_null_validation("POS") as pos,
	tech_etl.util_text_to_null_validation("BUKRS") as bukrs,
	tech_etl.util_text_to_null_validation("BELNR") as belnr,
	tech_etl.util_text_to_null_validation("GJAHR") as gjahr,
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_null_validation("POSNR") as posnr,
	tech_etl.util_text_to_null_validation("TYPE") as type,
	tech_etl.util_text_to_date_validation("CPUDT") as cpudt,
	tech_etl.util_text_to_time_validation("CPUTM") as cputm
from stg."/RUSAL/PERF"
where "MANDT" = '400';
