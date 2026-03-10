insert into ods.zlereject_ral (
	werks,
	id,
	pos,
	numrej,
	daterej,
	timerej,
	"text",
	rejdel
)
select
	"WERKS" as werks,
	"ID" as id,
	tech_etl.util_text_to_null_validation("POS") as pos,
	"NUMREJ" as numrej,
	tech_etl.util_text_to_date_validation("DATEREJ") as daterej,
	tech_etl.util_text_to_time_validation("TIMEREJ") as timerej,
	tech_etl.util_text_to_null_validation("TEXT") as "text",
	tech_etl.util_text_to_null_validation("REJDEL") as rejdel
from stg."ZLEREJECT"
where "MANDT" = '400';