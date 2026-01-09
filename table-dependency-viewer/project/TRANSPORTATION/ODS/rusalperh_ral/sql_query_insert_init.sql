insert into ods."/rusal/perh_ral"
select
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("ID") as id,
	tech_etl.util_text_to_null_validation("NOMS") as noms,
	tech_etl.util_text_to_null_validation("NOMP") as nomp,
	tech_etl.util_text_to_date_validation("BEDAT") as bedat,
	tech_etl.util_text_to_null_validation("STATUS_DOC") as status_doc,
	tech_etl.util_text_to_null_validation("LIFNR") as lifnr,
	tech_etl.util_text_to_null_validation("ZLIFNR") as zlifnr,
	tech_etl.util_text_to_null_validation("LIFNR_PR") as lifnr_pr,
	tech_etl.util_text_to_null_validation("COMMENTS") as comments,
	tech_etl.util_text_to_date_validation("DUEDAT") as duedat,
	tech_etl.util_text_to_null_validation("ERNAM") as ernam,
	tech_etl.util_text_to_date_validation("ERDAT") as erdat,
	tech_etl.util_text_to_time_validation("ERZET") as erzet,
	tech_etl.util_text_to_null_validation("AENAM") as aenam,
	tech_etl.util_text_to_date_validation("AEDAT") as aedat,
	tech_etl.util_text_to_time_validation("AEZET") as aezet,
	tech_etl.util_text_to_null_validation("UVED_ERNAM") as ernam,
	tech_etl.util_text_to_null_validation("TYPE2") as type2,
	tech_etl.util_text_to_null_validation("WAERS") as waers,
	"TAP_SUM" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as tap_sum
from stg."/RUSAL/PERH"
left join dict_dds.currency_decimal_place_ral as dp			---джойн с TCURX RAL
		on dp.currency_code = "WAERS"
where "MANDT" = '400';