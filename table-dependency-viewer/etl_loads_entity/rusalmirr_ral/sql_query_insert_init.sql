insert into ods."/rusal/mirr_ral"
select
	tech_etl.util_text_to_null_validation("AWTYP") as awtyp,
	tech_etl.util_text_to_null_validation("AWKEY") as awkey,
	tech_etl.util_text_to_null_validation("BUKRS") as bukrs,
	tech_etl.util_text_to_null_validation("BELNR") as belnr,
	tech_etl.util_text_to_null_validation("GJAHR") as gjahr
from stg."/RUSAL/MIRR"
where "MANDT" = '400';
