insert into dds.transportation_raw_materials_business_plan_position(	
	dt_business_plan_yyyy,
	material_code,
	version_code,
	position_code,
	etsng_code,
	transportation_scheme_code,
	transport_type_code,
	transport_departure_hub_code,
	transport_destination_hub_code,
	vehicle_quantity
)
select 
	gjahr as dt_business_plan_yyyy,
	matnr as material_code,
	"version" as version_code,
	posnr as position_code,
	etsng as etsng_code,
	scheme as transportation_scheme_code,
	sdabw as transport_type_code,
	knanf as transport_departure_hub_code,
	knend as transport_destination_hub_code,
	menge as vehicle_quantity		
from ods."zle2464m_bp_rawp_ral";