insert into ods."/rusal/otmm_rv_ral"(
	matnr,
	werks,
	popers,
	poperpo,
	id_ves
)
select 
	tech_etl.util_text_to_null_validation("MATNR") as matnr,	
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("POPERS") as popers,	
	tech_etl.util_text_to_null_validation("POPERPO") as poperpo,	
	tech_etl.util_text_to_null_validation("ID_VES") as id_ves		
from stg."/RUSAL/OTMM_RV";