insert into ods."/rul/rw_head_ral"
select
	tech_etl.util_text_to_null_validation("MATNR") as "matnr",
	tech_etl.util_text_to_null_validation("CHARG") as "charg",
	tech_etl.util_text_to_null_validation("WERKS") as "werks",
	"N_NETTO_N" as "n_netto_n",
	"N_NETTO_V" as "n_netto_v"
from stg."/RUL/RW_HEAD"
where "MANDT" = '400';