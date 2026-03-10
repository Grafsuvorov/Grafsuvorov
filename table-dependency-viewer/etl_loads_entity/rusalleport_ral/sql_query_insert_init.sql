insert into ods."/rusal/leport_ral"
(container, bl, databl, port_to, terminal_rf, data_ship, erdat, erzet, ernam, aedat, aezet, aenam)

select
	"CONTAINER" as container,
	"BL" as bl,
	tech_etl.util_text_to_date_validation("DATABL") as databl,
	tech_etl.util_text_to_null_validation("PORT_TO") as port_to,
	tech_etl.util_text_to_null_validation("TERMINAL_RF") as terminal_rf,
	tech_etl.util_text_to_date_validation("DATA_SHIP") as data_ship,
	tech_etl.util_text_to_date_validation("ERDAT") as erdat,
	tech_etl.util_text_to_time_validation("ERZET") as erzet,
	tech_etl.util_text_to_null_validation("ERNAM") as ernam,
	tech_etl.util_text_to_date_validation("AEDAT") as aedat,
	tech_etl.util_text_to_time_validation("AEZET") as aezet,
	tech_etl.util_text_to_null_validation("AENAM") as aenam
from stg."/RUSAL/LEPORT"
where "MANDT" = '400';