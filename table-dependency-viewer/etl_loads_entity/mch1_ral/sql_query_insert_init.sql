insert into ods.mch1_ral
select 
	tech_etl.util_text_to_null_validation("MATNR") as matnr,	
	tech_etl.util_text_to_null_validation("CHARG") as charg,
	tech_etl.util_text_to_null_validation("CUOBJ_BM") as cuobj_bm,
	tech_etl.util_text_to_date_validation("FVDT3") as fvdt3,
	tech_etl.util_text_to_date_validation("FVDT6") as fvdt6
from stg."MCH1"
where "MANDT" = '400';