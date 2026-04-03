insert into ods.ausp_ral
select tech_etl.util_text_to_null_validation("ATINN") as atinn,
tech_etl.util_text_to_null_validation("ATZHL") as atzhl,
tech_etl.util_text_to_null_validation("KLART") as klart,
tech_etl.util_text_to_null_validation("MAFID") as mafid,
"ATFLV" as atflv,
tech_etl.util_text_to_null_validation("ATWRT") as atwrt,
tech_etl.util_text_to_null_validation("OBJEK") as objek
from stg."AUSP"
where "MANDT" = '400';