insert into ods."/rusal/ekkont_ral"
select
	tech_etl.util_text_to_null_validation("EBELN") as ebeln,
	tech_etl.util_text_to_null_validation("LIFNR") as lifnr
from stg."/RUSAL/EKKONT"
where "MANDT" = '400';