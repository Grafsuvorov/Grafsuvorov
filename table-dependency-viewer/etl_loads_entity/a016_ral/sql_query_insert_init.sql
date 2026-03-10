insert into ods.a016_ral
select 
	tech_etl.util_text_to_null_validation("KAPPL") as kappl,
	tech_etl.util_text_to_null_validation("KSCHL") as kschl,
	tech_etl.util_text_to_null_validation("EVRTN") as evrtn,
	tech_etl.util_text_to_null_validation("EVRTP") as evrtp,
	tech_etl.util_text_to_date_validation("DATBI") as datbi,
	tech_etl.util_text_to_date_validation("DATAB") as datab,
	tech_etl.util_text_to_null_validation("KNUMH") as knumh
from stg."A016"
where "MANDT" = '400';