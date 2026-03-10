insert into dds.raw_materials_allocation_list_for_production(
	material_code,
	plant_code,
	dt_purchase_from_yyyymm,
	dt_purchase_to_yyyymm,
	weighing_method_for_accounting_code
)
select 
	matnr as material_code,	
	werks as plant_code,
	popers as dt_purchase_from_yyyymm,	
	poperpo as dt_purchase_to_yyyymm,	
	id_ves as weighing_method_for_accounting_code		
from ods."/rusal/otmm_rv_ral";