insert into ods."/rusal/dtl_pdx_h_ral"
select 
	tech_etl.util_text_to_null_validation("EBELN") as ebeln,
	tech_etl.util_text_to_null_validation("NAME") as name,
	tech_etl.util_text_to_null_validation("OE") as oe,
	tech_etl.util_text_to_null_validation("URL") as url,
	tech_etl.util_text_to_null_validation("DOCID") as docid,
	tech_etl.util_text_to_null_validation("DOCIDINT") as docidint,
	tech_etl.util_text_to_null_validation("PDX_LOAD") as pdx_load,
	tech_etl.util_text_to_null_validation("STATUS") as status,
	tech_etl.util_text_to_null_validation("PAYDOX_STATUS") as paydox_status,
	tech_etl.util_text_to_date_validation("BEDAT") as bedat,
	tech_etl.util_text_to_null_validation("BSART_PD") as bsart_pd
from stg."/RUSAL/DTL_PDX_H"
where "MANDT" = '400';