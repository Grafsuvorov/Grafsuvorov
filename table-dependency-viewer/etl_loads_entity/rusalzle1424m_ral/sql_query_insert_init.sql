insert into ods."/rusal/zle1424m_ral"
(
	vbeln,
	scheme
)

select 
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_null_validation("SCHEME") as scheme	
from stg."/RUSAL/ZLE1424M";
