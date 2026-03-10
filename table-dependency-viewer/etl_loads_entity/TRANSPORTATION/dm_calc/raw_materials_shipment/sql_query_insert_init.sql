insert into dm_calc.raw_materials_shipment (
	transport_bill_code,	
	railcar_code,
	transport_bill_and_railcar_code,
	departure_type_code,
	departure_type_name,
	dt_shipping,
	dt_departure,
	russian_port_pier_code,
	russian_port_code,
	russian_port_terminal_code,
	supplier_code,
	producer_code,
	business_scheme_type_code,
	package_type_code,
	material_code,
	railway_station_of_departure_code,
	plant_of_departure_code,
	railway_station_of_destination_code,
	plant_of_destination_code,
	import_method_code,
	is_compound_cargo,
	etsng_code,
	transport_type_code,
	railcar_capacity,
	redirection_type_code,
	dt_redirected,
	redirection_created_by_code,
	transport_bill_after_redirection_code,
	dt_shipment_after_redirection,
	station_of_destination_after_redirection_code,
	station_of_destination_before_redirection_code,
	plant_of_destination_before_redirection_code,
	dt_train_operation,
	dislocation_railcar_operation_code,
	dislocation_station_of_departure_code,
	dislocation_station_of_destination_code,
	dislocation_station_current_code,
	distance_left_to_destination_kilometer_quantity,
	dt_dislocation_arrival_to_destination_station,
	dt_dislocation_estimated_arrival_to_destination_station,
	dt_vessel_arrival_to_russian_port,
	dt_vessel_discharge_in_russian_port,
	dt_arrival_to_destination_station,
	dt_zdc_arrival_to_destination_station,
	dt_arrival_by_accounting,
	vessel_code,
	bill_of_lading_number,
	delivery_code,
	dt_general_act,
	weight_net
)
select
	shipment.transport_bill_code,
	shipment.vehicle_code as railcar_code,
	shipment.transport_bill_and_vehicle_code as transport_bill_and_railcar_code,
	shipment.departure_type_code,
	shipment.departure_type_name,
	shipment.dt_shipping,
	shipment.dt_departure,
	shipment.russian_port_pier_code,
	shipment.russian_port_code,
	shipment.russian_port_terminal_code,
	case when shipment.departure_type_code = '01'
		 then coalesce(tbbl.supplier_code, mm1657m.supplier_code)
		 else coalesce(shipment.supplier_code, mm1657m.supplier_code)
	end as supplier_code,
	case when shipment.departure_type_code = '01'
		 then coalesce(tbbl.producer_code, mm1657m.producer_code)
		 else coalesce(shipment.producer_code, mm1657m.producer_code)
	end as producer_code,
	shipment.business_scheme_type_code,
	shipment.package_type_code,
	shipment.material_code,
	shipment.railway_station_of_departure_code,
	shipment.plant_of_departure_code,
	shipment.railway_station_of_destination_code,
	shipment.plant_of_destination_code,
	shipment.import_method_code,
	shipment.is_compound_cargo,
	shipment.etsng_code,
	shipment.transport_type_code,
	shipment.vehicle_capacity as railcar_capacity,
	shipment.redirection_type_code,
	shipment.dt_redirected,
	shipment.redirection_created_by_code,
	shipment.transport_bill_after_redirection_code,
	shipment.dt_shipment_after_redirection,
	shipment.station_of_destination_after_redirection_code,
	shipment.station_of_destination_before_redirection_code,
	shipment.plant_of_destination_before_redirection_code,
	shipment.dt_train_operation,
	shipment.dislocation_railcar_operation_code,
	shipment.dislocation_station_of_departure_code,
	shipment.dislocation_station_of_destination_code,
	shipment.dislocation_station_current_code,
	shipment.distance_left_to_destination_kilometer_quantity,
	shipment.dt_dislocation_arrival_to_destination_station,
	shipment.dt_dislocation_estimated_arrival_to_destination_station,
	tbbl.dt_vessel_arrival_to_russian_port,
	leport.data_ship as dt_vessel_discharge_in_russian_port,
	shipment.dt_arrival_to_destination_station,
	shipment.dt_zdc_arrival_to_destination_station,
	shipment.dt_arrival_by_accounting,
	tbbl.vessel_code,
	tbbl.bill_of_lading_number,
	tbbl.delivery_code,
	tbbl.dt_general_act,
	case when tbbl.vehicle_code is not null and tbbl.transport_bill_code is not null
		 then tbbl.weight_net
		 else shipment.weight_net
	end as weight_net	
from dds.transport_bill as shipment
	join (select matnr from ods."/rusal/otmm_rv_ral" group by matnr) as arr_matnr
		on arr_matnr.matnr = shipment.material_code
	left join dds.transport_bill_and_bill_of_lading_relation as tbbl
		on tbbl.transport_bill_code = shipment.transport_bill_code and
		   tbbl.vehicle_code = shipment.vehicle_code and
		   tbbl.material_code = shipment.material_code and
		   coalesce(tbbl.package_type_code, '') = coalesce(shipment.package_type_code, '')
	left join ods."/rusal/leport_ral" as leport
		on leport.bl = shipment.transport_bill_code	and
		   leport.container = shipment.vehicle_code and
		   shipment.departure_type_code = '05'
	left join dict_dds.map_transport_hub_to_supplier as mm1657m
		on mm1657m.transport_departure_hub_code = shipment.railway_station_of_departure_code and
		   mm1657m.transport_destination_hub_code = shipment.railway_station_of_destination_code and
		   mm1657m.etsng_code = shipment.etsng_code
where shipment.dt_departure >= '2020-01-01'
	and shipment.vehicle_code <> 'AVTOTRANSP'
	and shipment.transport_bill_code is not null
	and shipment.vehicle_code is not null
;