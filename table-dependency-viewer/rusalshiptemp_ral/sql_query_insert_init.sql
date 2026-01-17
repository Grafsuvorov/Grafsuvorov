insert into ods."/rusal/shiptemp_ral"
select
	tech_etl.util_text_to_null_validation("IDENT") as "ident",
	tech_etl.util_text_to_null_validation("VAGON") as "vagon",
	tech_etl.util_text_to_null_validation("NAKLADN") as "nakladn",
	tech_etl.util_text_to_null_validation("TRATY") as "traty",	
	tech_etl.util_text_to_date_validation("DATEOT") as "dateot",
	tech_etl.util_text_to_null_validation("GRADECOD") as "gradecod",
	tech_etl.util_text_to_null_validation("STATIONNC") as "stationnc",
	tech_etl.util_text_to_null_validation("STATIONOC") as "stationoc",
	tech_etl.util_text_to_null_validation("PLANT") as "plant",
	"DRYWEIGHT" as "dryweight",
	tech_etl.util_text_to_null_validation("PROIZID") as "proizid",
	tech_etl.util_text_to_null_validation("FIRMAOID") as "firmaoid",
	tech_etl.util_text_to_null_validation("CARTARE") as "cartare",
	tech_etl.util_text_to_null_validation("FIRMAP") as "firmap",	
	tech_etl.util_text_to_date_validation("AEDAT") as "aedat",
	tech_etl.util_text_to_time_validation("AEZET") as "aezet"
from stg."/RUSAL/SHIPTEMP"
where "MANDT" = '400'
  and "DATEOT" >= '20240601';