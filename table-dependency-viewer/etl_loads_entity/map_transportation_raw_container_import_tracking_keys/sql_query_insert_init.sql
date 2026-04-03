insert into ods.map_transportation_raw_container_import_tracking_keys 
(	
	container_code,
	transport_bill_code,
	bill_of_lading_number,
	dt_bill_of_lading,
	port_of_loading_code,
	station_of_destination_code,
	russian_port_terminal_of_discharge_code,
	russian_port_station_of_departure_code,
	dt_arrival_to_russian_port_of_discharge,
	dt_vessel_discharge,
	dt_railway_departure,
	dt_arrival_to_plant,
	receiving_plant_code,
	dt_departure_from_port_of_loading,
	russian_port_of_destination_code,
	transport_platform_code,
	raw_material_code
)

select
	tech_etl.util_text_to_null_validation("CONTAINER") as container_code,
	tech_etl.util_text_to_null_validation("NUMNAKL") as transport_bill_code,
	tech_etl.util_text_to_null_validation("BL") as bill_of_lading_number,
	tech_etl.util_text_to_date_validation("DATABL") as dt_bill_of_lading,
	tech_etl.util_text_to_null_validation("PORT_FROM") as port_of_loading_code,
	tech_etl.util_text_to_null_validation("ZDKODSTTO") as station_of_destination_code,
	tech_etl.util_text_to_null_validation("TERMINAL_TO") as russian_port_terminal_of_discharge_code,
	tech_etl.util_text_to_null_validation("STSHIP") as russian_port_station_of_departure_code,
	tech_etl.util_text_to_date_validation("EVENTDATE") as dt_arrival_to_russian_port_of_discharge,
	tech_etl.util_text_to_date_validation("DATADU") as dt_vessel_discharge,
	tech_etl.util_text_to_date_validation("DATATOTR") as dt_railway_departure,
	tech_etl.util_text_to_date_validation("DATEW") as dt_arrival_to_plant,
	tech_etl.util_text_to_null_validation("WERKS") as receiving_plant_code,
	tech_etl.util_text_to_date_validation("DATATR") as dt_departure_from_port_of_loading,
	tech_etl.util_text_to_null_validation("PORT_TO") as russian_port_of_destination_code,
	tech_etl.util_text_to_null_validation("VAGON") as transport_platform_code,
	tech_etl.util_text_to_null_validation("MATNR") as raw_material_code
from stg."ZMK_TRACK_IMP";