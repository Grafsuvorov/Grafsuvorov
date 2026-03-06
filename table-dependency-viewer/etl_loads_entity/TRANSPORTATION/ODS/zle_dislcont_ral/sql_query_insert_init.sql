insert into ods.zle_dislcont_ral
(id, pos, container, numnakl, carnumber, oper_code, oper_date, oper_time, load_station, erdat, erzet, ernam, aedat, aezet, aenam)

select
	"ID" as "id",
	"POS" as "pos",
	"CONTAINER" as container,
	"NUMNAKL" as numnakl,
	"CARNUMBER" as carnumber,
	tech_etl.util_text_to_null_validation("OPER_CODE") as oper_code,
	tech_etl.util_text_to_date_validation("OPER_DATE") as oper_date,
	tech_etl.util_text_to_time_validation("OPER_TIME") as oper_time,
	tech_etl.util_text_to_null_validation("LOAD_STATION") as load_station,
	tech_etl.util_text_to_date_validation("ERDAT") as erdat,
	tech_etl.util_text_to_time_validation("ERZET") as erzet,
	tech_etl.util_text_to_null_validation("ERNAM") as ernam,
	tech_etl.util_text_to_date_validation("AEDAT") as aedat,
	tech_etl.util_text_to_time_validation("AEZET") as aezet,
	tech_etl.util_text_to_null_validation("AENAM") as aenam
from stg."ZLE_DISLCONT"
where "MANDT" = '400';