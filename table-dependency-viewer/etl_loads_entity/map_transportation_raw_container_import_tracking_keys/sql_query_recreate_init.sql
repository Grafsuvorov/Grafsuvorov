drop table if exists ods.map_transportation_raw_container_import_tracking_keys ;

create table ods.map_transportation_raw_container_import_tracking_keys  (
	container_code varchar null,
	transport_bill_code varchar null,
	bill_of_lading_number varchar null,
	dt_bill_of_lading date null,
	port_of_loading_code varchar null,
	station_of_destination_code varchar null,
	russian_port_terminal_of_discharge_code varchar null,
	russian_port_station_of_departure_code varchar null,
	dt_arrival_to_russian_port_of_discharge date null,
	dt_vessel_discharge date null,
	dt_railway_departure date null,
	dt_arrival_to_plant date null,
	receiving_plant_code varchar null,
	dt_departure_from_port_of_loading date null,
	russian_port_of_destination_code varchar null,
	transport_platform_code varchar null,
	raw_material_code varchar null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar not null default 'airflow'::character varying,
	deleted_flag bool not null default false
) with (appendonly=true, orientation=column, compresstype=zstd, compresslevel=3)
distributed by (container_code, transport_bill_code);

comment on table ods.map_transportation_raw_container_import_tracking_keys is 'Отслеживание импортных контейнеров';
comment on column ods.map_transportation_raw_container_import_tracking_keys.container_code is 'Номер контейнера (код) | | stg.ZMK_TRACK_IMP.CONTAINER';
comment on column ods.map_transportation_raw_container_import_tracking_keys.transport_bill_code is 'Транспортная накладная (код) | | stg.ZMK_TRACK_IMP.NUMNAKL';
comment on column ods.map_transportation_raw_container_import_tracking_keys.bill_of_lading_number is 'Коносамент | | stg.ZMK_TRACK_IMP.BL';
comment on column ods.map_transportation_raw_container_import_tracking_keys.dt_bill_of_lading is 'Дата коносамента | | stg.ZMK_TRACK_IMP.DATABL';
comment on column ods.map_transportation_raw_container_import_tracking_keys.port_of_loading_code is 'Порт отправления в ин.государстве (код) | | stg.ZMK_TRACK_IMP.PORT_FROM';
comment on column ods.map_transportation_raw_container_import_tracking_keys.station_of_destination_code is 'Станция назначения (код) | | stg.ZMK_TRACK_IMP.ZDKODSTTO';
comment on column ods.map_transportation_raw_container_import_tracking_keys.russian_port_terminal_of_discharge_code is 'Терминал выгрузки в порту РФ (код) | | stg.ZMK_TRACK_IMP.TERMINAL_TO';
comment on column ods.map_transportation_raw_container_import_tracking_keys.russian_port_station_of_departure_code is 'Станция отгрузки из порта РФ (код) | | stg.ZMK_TRACK_IMP.STSHIP';
comment on column ods.map_transportation_raw_container_import_tracking_keys.dt_arrival_to_russian_port_of_discharge is 'Дата прибытия в порт выгрузки | | stg.ZMK_TRACK_IMP.EVENTDATE';
comment on column ods.map_transportation_raw_container_import_tracking_keys.dt_vessel_discharge is 'Дата выгрузки с судна | | stg.ZMK_TRACK_IMP.DATADU';
comment on column ods.map_transportation_raw_container_import_tracking_keys.dt_railway_departure is 'Дата отправки по ЖД | | stg.ZMK_TRACK_IMP.DATATOTR';
comment on column ods.map_transportation_raw_container_import_tracking_keys.dt_arrival_to_plant is 'Дата прибытия по ЖД на завод | | stg.ZMK_TRACK_IMP.DATEW';
comment on column ods.map_transportation_raw_container_import_tracking_keys.receiving_plant_code is 'Завод-получатель (код) | | stg.ZMK_TRACK_IMP.WERKS';
comment on column ods.map_transportation_raw_container_import_tracking_keys.dt_departure_from_port_of_loading is 'Дата отгрузки из ин.порта | | stg.ZMK_TRACK_IMP.DATATR';
comment on column ods.map_transportation_raw_container_import_tracking_keys.russian_port_of_destination_code is 'Порт прибытия из ин.государства (код) | | stg.ZMK_TRACK_IMP.PORT_TO';
comment on column ods.map_transportation_raw_container_import_tracking_keys.transport_platform_code is 'Номер платформы/авто | | stg.ZMK_TRACK_IMP.VAGON';
comment on column ods.map_transportation_raw_container_import_tracking_keys.raw_material_code is 'Номер материала сырья (Код) | | stg.ZMK_TRACK_IMP.MATNR';