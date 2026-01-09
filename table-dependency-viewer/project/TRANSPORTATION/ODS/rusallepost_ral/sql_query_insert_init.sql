insert into ods."/rusal/lepost_ral"
select
	tech_etl.util_text_to_null_validation("ID") as "id",
	tech_etl.util_text_to_null_validation("POS") as "pos",
	tech_etl.util_text_to_null_validation("TYPE_LOAD") as "type_load",
	tech_etl.util_text_to_null_validation("NUMVAG") as "numvag",
	tech_etl.util_text_to_null_validation("NUMNAKL") as "numnakl",
	tech_etl.util_text_to_null_validation("ZDKODSTFR") as "zdkodstfr",
	tech_etl.util_text_to_date_validation("DATEOT") as "dateot",
	"NETTO" as "netto",
	tech_etl.util_text_to_date_validation("DATEW") as "datew",
	tech_etl.util_text_to_null_validation("ZDKODSTTO") as "zdkodstto",
	"DRYWEIGHT" as "dryweight",
	tech_etl.util_text_to_null_validation("LIFNR_PR") as "lifnr_pr",
	tech_etl.util_text_to_null_validation("LIFNR") as "lifnr",
	tech_etl.util_text_to_null_validation("EBELN") as "ebeln",
	tech_etl.util_text_to_null_validation("EBELP") as "ebelp",
	tech_etl.util_text_to_null_validation("WERKS") as "werks",
	tech_etl.util_text_to_null_validation("MATNR") as "matnr",
	tech_etl.util_text_to_date_validation("ERDAT") as "erdat",
	tech_etl.util_text_to_time_validation("ERZET") as "erzet",
	tech_etl.util_text_to_null_validation("ERNAM") as "ernam",
	tech_etl.util_text_to_date_validation("AEDAT") as "aedat",
	tech_etl.util_text_to_time_validation("AEZET") as "aezet",
	tech_etl.util_text_to_null_validation("AENAM") as "aenam",
	tech_etl.util_text_to_null_validation("CHECK_CONT") as "check_cont",
	tech_etl.util_text_to_null_validation("R_NUMNAKL") as "r_numnakl"
from stg."/RUSAL/LEPOST"
where "MANDT" = '400';