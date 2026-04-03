insert into dds.transportation_aluminium_business_plan_position(
	dt_business_plan_yyyy,
	version_code,
	business_plan_transportation_stage_type_code,
	position_code,
	plant_code,
	is_pickup_at_plant,
	transport_type_code,
	transport_departure_hub_at_plant_code,
	russian_port_code,
	transport_destination_hub_at_russian_port_code,
	container_ownership_type_code,
	repacking_reason_code,
	container_length_type_code,
	platform_ownership_type_code,
	vehicle_quantity
)
select 
	gjahr as dt_business_plan_yyyy,
	"version" as version_code,
	oper as business_plan_transportation_stage_type_code,
	posnr as position_code,
	werks as plant_code,
	pickup as is_pickup_at_plant,
	sdabw as transport_type_code,
	werks_kn as transport_departure_hub_at_plant_code,
	port_from as russian_port_code,
	port_frkn as transport_destination_hub_at_russian_port_code,
	zpr_cont as container_ownership_type_code,
	zpr_pl as repacking_reason_code,
	prdouble as container_length_type_code,
	zlencont as platform_ownership_type_code,
	menge_sum as vehicle_quantity
from ods."/rusal/bp_schedp_ral";