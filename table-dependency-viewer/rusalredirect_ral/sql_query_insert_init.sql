insert into ods."/rusal/redirect_ral"
(traid, bolnr1, lfdat1, change_type, bolnr2, lfdat2, knanf2, knend2, knend3, erdat, ernam)

select
	tech_etl.util_text_to_null_validation("TRAID") as traid,
	tech_etl.util_text_to_null_validation("BOLNR1") as bolnr1,
	tech_etl.util_text_to_date_validation("LFDAT1") as lfdat1,
	tech_etl.util_text_to_null_validation("CHANGE_TYPE") as change_type,
	tech_etl.util_text_to_null_validation("BOLNR2") as bolnr2,
	tech_etl.util_text_to_date_validation("LFDAT2") as lfdat2,
	tech_etl.util_text_to_null_validation("KNANF2") as knanf2,
	tech_etl.util_text_to_null_validation("KNEND2") as knend2,
	tech_etl.util_text_to_null_validation("KNEND3") as knend3,
	tech_etl.util_text_to_date_validation("ERDAT") as erdat,
	tech_etl.util_text_to_null_validation("ERNAM") as ernam
from stg."/RUSAL/REDIRECT"
where "MANDT" = '400';