insert into ods."/rusal/mirp_ral"
select
	tech_etl.util_text_to_null_validation("AWTYP") as awtyp,
	tech_etl.util_text_to_null_validation("AWKEY") as awkey,
	tech_etl.util_text_to_null_validation("ZBUKRS") as zbukrs,
	tech_etl.util_text_to_null_validation("ZBELNR") as zbelnr,
	tech_etl.util_text_to_null_validation("ZGJAHR") as zgjahr,
	tech_etl.util_text_to_null_validation("ZBLART") as zblart,
	tech_etl.util_text_to_null_validation("ZSTBLG") as zstblg	
from stg."/RUSAL/MIRP"
where "MANDT" = '400';
