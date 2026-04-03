insert into ods."/rusal/indel_1_ral" (
	 dataprek
	,dataskl
	,gtd
	,start_storage2
	,vbeln
	,delind
	,potrebit
	,contract_p
	,sammg_p
	,sammg_y
	,load_out_date
	,loc_name
	,sammg_i
	,v_co2wgt
	,co2wgt_scope1
	,co2wgt_scope2
	,co2wgt_scope3
	,container_out
	,num_mh1
	,num_mh3
)

select
	tech_etl.util_text_to_date_validation("DATAPREK") as dataprek,
	tech_etl.util_text_to_date_validation("DATASKL") as dataskl,
	tech_etl.util_text_to_null_validation("GTD") as gtd,
	tech_etl.util_text_to_date_validation("START_STORAGE2") as start_storage2,
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
    tech_etl.util_text_to_null_validation("DELIND") as delind,
	tech_etl.util_text_to_null_validation("POTREBIT") as potrebit,
	tech_etl.util_text_to_null_validation("CONTRACT_P") as contract_p,
	tech_etl.util_text_to_null_validation("SAMMG_P") as sammg_p,
	tech_etl.util_text_to_null_validation("SAMMG_Y") as sammg_y,
	tech_etl.util_text_to_date_validation("LOAD_OUT_DATE") as load_out_date,
	tech_etl.util_text_to_null_validation("LOC_NAME") as loc_name,
	tech_etl.util_text_to_null_validation("SAMMG_I") as sammg_i,
	"V_CO2WGT" as v_co2wgt,
	"CO2WGT_SCOPE1" as co2wgt_scope1,
	"CO2WGT_SCOPE2" as co2wgt_scope2,
	"CO2WGT_SCOPE3" as co2wgt_scope3,
	tech_etl.util_text_to_null_validation("CONTAINER_OUT") as container_out,
	tech_etl.util_text_to_null_validation("NUM_MH1") as num_mh1,
	tech_etl.util_text_to_null_validation("NUM_MH3") as num_mh3
from stg."/RUSAL/INDEL_1"
where "MANDT" = '400';