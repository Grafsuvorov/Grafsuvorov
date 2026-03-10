drop table if exists dm_calc.raw_materials_shipment_and_arrival;

create table if not exists dm_calc.raw_materials_shipment_and_arrival (
	transport_bill_code varchar(35) null,
	railcar_code varchar(20) null,
	transport_bill_and_railcar_code varchar(126) null,
	departure_type_code varchar(2) null,
	departure_type_name varchar(150) null,
	dt_shipping date null,
	dt_departure date null,
	russian_port_pier_code varchar(10) null,
	russian_port_code varchar(10) null,
	russian_port_terminal_code varchar(10) null,
	supplier_code varchar(10) null,
	producer_code varchar(10) null,
	business_scheme_type_code varchar(10) null,
	package_type_code varchar(3) null,
	material_code varchar(18) null,
	railway_station_of_departure_code varchar(10) null,
	plant_of_departure_code varchar(4) null,
	railway_station_of_destination_code varchar(10) null,
	plant_of_destination_code varchar(4) null,
	warehouse_code varchar(4) null,
	railway_track_at_plant_number varchar(3) null,
	dt_discharge date null,
	dt_posting date null,
	purchase_contract_code varchar(10) null,
	import_method_code varchar(1) null,
	is_compound_cargo varchar(1) null,
	etsng_code varchar(6) null,
	transport_type_code varchar(4) null,
	railcar_capacity numeric(13, 3) null,
	redirection_type_code varchar(2) null,
	dt_redirected date null,
	redirection_created_by_code varchar(12) null,
	transport_bill_after_redirection_code varchar(35) null,
	dt_shipment_after_redirection date null,
	station_of_destination_after_redirection_code varchar(10) null,
	station_of_destination_before_redirection_code varchar(10) null,
	plant_of_destination_before_redirection_code varchar(4) null,
	dt_train_operation date null,
	dislocation_railcar_operation_code varchar(2) null,
	dislocation_station_of_departure_code varchar(10) null,
	dislocation_station_of_destination_code varchar(10) null,
	dislocation_station_current_code varchar(10) null,
	distance_left_to_destination_kilometer_quantity int null,
	dt_dislocation_arrival_to_destination_station date null,
	dt_dislocation_estimated_arrival_to_destination_station date null,
	dt_vessel_arrival_to_russian_port date null,
	dt_vessel_discharge_in_russian_port date null,
	dt_arrival_to_destination_station date null,
	dt_zdc_arrival_to_destination_station date null,
	dt_arrival_by_accounting date null,
	vessel_code varchar(10) null,
	bill_of_lading_number varchar(30) null,
	delivery_code varchar(10) null,
	dt_general_act date null,
	weight_net numeric(13, 3) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false 	
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (
	transport_bill_code,
	railcar_code	
);

comment on table dm_calc.raw_materials_shipment_and_arrival is 'Сырье. Отгрузка и поступление'; 
comment on column dm_calc.raw_materials_shipment_and_arrival.transport_bill_code is 'Накладная (код) | Накладная (код) | dm_calc.raw_materials_shipment.transport_bill_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.railcar_code is 'Вагон (код) | Вагон (код) | dm_calc.raw_materials_shipment.railcar_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.transport_bill_and_railcar_code is 'Накладная-Вагон (код) | Накладная-Вагон (код) | dm_calc.raw_materials_shipment.transport_bill_and_railcar_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.departure_type_code is 'Источник данных перевозки (код) | Источник данных перевозки (код) | dm_calc.raw_materials_shipment.departure_type_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.departure_type_name is 'Источник данных перевозки (наименование) | Источник данных перевозки (наименование) | dm_calc.raw_materials_shipment.departure_type_name';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_shipping is 'Дата отгрузки вагона | Дата отгрузки вагона | dm_calc.raw_materials_shipment.dt_shipping';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_departure is 'Дата отправки вагона | Дата отправки вагона | dm_calc.raw_materials_shipment.dt_departure';
comment on column dm_calc.raw_materials_shipment_and_arrival.russian_port_pier_code is 'Причал в порту РФ (код) | Причал в порту РФ (код) | dm_calc.raw_materials_shipment.russian_port_pier_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.russian_port_code is 'Порт РФ (код) | Порт РФ (код) | dm_calc.raw_materials_shipment.russian_port_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.russian_port_terminal_code is 'Терминал в порту РФ (код) | Терминал в порту РФ (код) | dm_calc.raw_materials_shipment.russian_port_terminal_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.supplier_code is 'Поставщик (код) | Поставщик (код) | dm_calc.raw_materials_arrival.supplier_code, dm_calc.raw_materials_shipment.supplier_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.producer_code is 'Производитель (код) | Производитель (код) | dm_calc.raw_materials_arrival.producer_code, dm_calc.raw_materials_shipment.producer_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.business_scheme_type_code is 'Тип бизнес-схемы (код) | Тип бизнес-схемы (код) | dm_calc.raw_materials_arrival.business_scheme_type_code, dm_calc.raw_materials_shipment.business_scheme_type_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.package_type_code is 'Тип упаковки (код) | Тип упаковки (код) | dm_calc.raw_materials_shipment.package_type_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.material_code is 'Материал (код) | Материал (код) | dm_calc.raw_materials_shipment.material_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.railway_station_of_departure_code is 'Станция отправления (код) | Станция отправления (код) | dm_calc.raw_materials_shipment.railway_station_of_departure_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.plant_of_departure_code is 'Завод отправления (код) | Завод отправления (код) | dm_calc.raw_materials_shipment.plant_of_departure_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.railway_station_of_destination_code is 'Станция назначения (код) | Станция назначения (код) | dm_calc.raw_materials_shipment.railway_station_of_destination_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.plant_of_destination_code is 'Завод назначения (код) | Завод назначения (код) | dm_calc.raw_materials_shipment.plant_of_destination_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.warehouse_code is 'Склад (код) | Склад (код) | dm_calc.raw_materials_arrival.warehouse_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.railway_track_at_plant_number is 'Номер пути | Номер пути | dm_calc.raw_materials_arrival.railway_track_at_plant_number';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_discharge is 'Дата разгрузки | Дата разгрузки | dm_calc.raw_materials_arrival.dt_discharge';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_posting is 'Дата бухгалтерского учета | Дата бухгалтерского учета | dm_calc.raw_materials_arrival.dt_posting';
comment on column dm_calc.raw_materials_shipment_and_arrival.purchase_contract_code is 'Договор (код) | Договор (код) | dm_calc.raw_materials_arrival.purchase_contract_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.import_method_code is 'Схема реализации (код) | Схема реализации (код) | dm_calc.raw_materials_shipment.import_method_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.is_compound_cargo is 'Вагон составной (сборный) (код) | Вагон составной (сборный) (код) | dm_calc.raw_materials_shipment.is_compound_cargo';
comment on column dm_calc.raw_materials_shipment_and_arrival.etsng_code is 'Код груза ЕТСНГ (код) | Код груза ЕТСНГ (код) | dm_calc.raw_materials_shipment.etsng_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.transport_type_code is 'Тип ПС (код) | Тип ПС (код) | dm_calc.raw_materials_shipment.transport_type_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.railcar_capacity is 'Грузоподъемность ПС | Грузоподъемность ПС | dm_calc.raw_materials_shipment.railcar_capacity';
comment on column dm_calc.raw_materials_shipment_and_arrival.redirection_type_code is 'Тип переадресации (код) | Тип переадресации (код) | dm_calc.raw_materials_shipment.redirection_type_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_redirected is 'Дата создания записи | Дата создания записи | dm_calc.raw_materials_shipment.dt_redirected';
comment on column dm_calc.raw_materials_shipment_and_arrival.redirection_created_by_code is 'Автор создания записи | Автор создания записи | dm_calc.raw_materials_shipment.redirection_created_by_code';	
comment on column dm_calc.raw_materials_shipment_and_arrival.transport_bill_after_redirection_code is 'Накладная после переадресации | Накладная после переадресации | dm_calc.raw_materials_shipment.transport_bill_after_redirection_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_shipment_after_redirection is 'Дата отгрузки после переадресации | Дата отгрузки после переадресации | dm_calc.raw_materials_shipment.dt_shipment_after_redirection';
comment on column dm_calc.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_code is 'Станция переадресации (код) | Станция переадресации (код) | dm_calc.raw_materials_shipment.station_of_destination_after_redirection_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_code is 'Станция назначения до переадресации (код) | Станция назначения до переадресации (код) | dm_calc.raw_materials_shipment.station_of_destination_before_redirection_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_code is 'Завод назначения до переадресации (код) | Завод назначения до переадресации (код) | dm_calc.raw_materials_shipment.plant_of_destination_before_redirection_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_train_operation is 'Дата текущего нахождения | Дата текущего нахождения | dm_calc.raw_materials_shipment.dt_train_operation';
comment on column dm_calc.raw_materials_shipment_and_arrival.dislocation_railcar_operation_code is 'Операция текущего нахождения по дислокации (код) | Операция текущего нахождения по дислокации (код) | dm_calc.raw_materials_shipment.dislocation_railcar_operation_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dislocation_station_of_departure_code is 'Станция отправления по дислокации (код) | Станция отправления по дислокации (код) | dm_calc.raw_materials_shipment.dislocation_station_of_departure_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dislocation_station_of_destination_code is 'Станция назначения по дислокации (код) | Станция назначения по дислокации (код) | dm_calc.raw_materials_shipment.dislocation_station_of_destination_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dislocation_station_current_code is 'Станция текущего нахождения по дислокации (код) | Станция текущего нахождения по дислокации (код) | dm_calc.raw_materials_shipment.dislocation_station_current_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.distance_left_to_destination_kilometer_quantity is 'Оставшееся расстояние в КМ до станции назначения | Оставшееся расстояние в КМ до станции назначения | dm_calc.raw_materials_shipment.distance_left_to_destination_kilometer_quantity';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_dislocation_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным дислокации | Фактическая дата прибытия на станцию назначения по данным дислокации | dm_calc.raw_materials_shipment.dt_dislocation_arrival_to_destination_station';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_dislocation_estimated_arrival_to_destination_station is 'Прогнозная дата прибытия на станцию назначения по данным дислокации | Прогнозная дата прибытия на станцию назначения по данным дислокации | dm_calc.raw_materials_shipment.dt_dislocation_estimated_arrival_to_destination_station';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_vessel_arrival_to_russian_port is 'Дата прихода судна в порт РФ | Дата прихода судна в порт РФ | dm_calc.raw_materials_shipment.dt_vessel_arrival_to_russian_port';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_vessel_discharge_in_russian_port is 'Дата выгрузки с судна в порту РФ | Дата выгрузки с судна в порту РФ | dm_calc.raw_materials_shipment.dt_vessel_discharge_in_russian_port';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_arrival_to_destination_station is 'Дата прибытя на станцию назначения | Дата прибытя на станцию назначения | dm_calc.raw_materials_shipment.dt_arrival_to_destination_station';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_zdc_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | dm_calc.raw_materials_shipment.dt_zdc_arrival_to_destination_station';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_arrival_by_accounting is 'Дата поступления | Дата поступления | dm_calc.raw_materials_arrival.dt_arrival_by_accounting, dm_calc.raw_materials_shipment.dt_arrival_by_accounting';
comment on column dm_calc.raw_materials_shipment_and_arrival.vessel_code is 'Судно (код) | Судно (код) | dm_calc.raw_materials_shipment.vessel_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.bill_of_lading_number is 'Номер коносамента (код) | Номер коносамента (код) | dm_calc.raw_materials_shipment.bill_of_lading_number';
comment on column dm_calc.raw_materials_shipment_and_arrival.delivery_code is 'Поставка (код) | Поставка (код) | dm_calc.raw_materials_shipment.delivery_code';
comment on column dm_calc.raw_materials_shipment_and_arrival.dt_general_act is 'Дата генерального акта | Дата генерального акта | dm_calc.raw_materials_shipment.dt_general_act';
comment on column dm_calc.raw_materials_shipment_and_arrival.weight_net is 'Тоннаж | Тоннаж | dm_calc.raw_materials_shipment.weight_net';
