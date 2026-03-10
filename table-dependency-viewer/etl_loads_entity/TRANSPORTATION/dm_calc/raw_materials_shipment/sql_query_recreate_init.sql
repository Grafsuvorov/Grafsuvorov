drop table if exists dm_calc.raw_materials_shipment;

create table if not exists dm_calc.raw_materials_shipment (
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
	distance_left_to_destination_kilometer_quantity int8 null,
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

comment on table dm_calc.raw_materials_shipment is 'Сырье. Данные отгрузки'; 
comment on column dm_calc.raw_materials_shipment.transport_bill_code is 'Накладная (код) | Накладная (код) | ';
comment on column dm_calc.raw_materials_shipment.railcar_code is 'Транспортное средство (код) | Транспортное средство (код) | ';
comment on column dm_calc.raw_materials_shipment.transport_bill_and_railcar_code is 'Накладная-Транспортное средство (код) | Накладная-Транспортное средство (код) | ';
comment on column dm_calc.raw_materials_shipment.departure_type_code is 'Источник данных перевозки (код) | Источник данных перевозки (код) |  ';
comment on column dm_calc.raw_materials_shipment.departure_type_name is 'Источник данных перевозки (наименование) | Источник данных перевозки (наименование) |  ';
comment on column dm_calc.raw_materials_shipment.dt_shipping is 'Дата отгрузки транспортного средства | Дата отгрузки транспортного средства | ';
comment on column dm_calc.raw_materials_shipment.dt_departure is 'Дата отправки вагона | Дата отправки вагона | ';
comment on column dm_calc.raw_materials_shipment.russian_port_pier_code is 'Причал в порту РФ (код) | Причал в порту РФ (код) | ';
comment on column dm_calc.raw_materials_shipment.russian_port_code is 'Порт РФ (код) | Порт РФ (код) | ';
comment on column dm_calc.raw_materials_shipment.russian_port_terminal_code is 'Терминал в порту РФ (код) | Терминал в порту РФ (код) | ';
comment on column dm_calc.raw_materials_shipment.supplier_code is 'Поставщик (код) | Поставщик (код) | ';
comment on column dm_calc.raw_materials_shipment.producer_code is 'Производитель (код) | Производитель (код) | ';
comment on column dm_calc.raw_materials_shipment.business_scheme_type_code is 'Тип бизнес-схемы (код) | Тип бизнес-схемы (код) | ';
comment on column dm_calc.raw_materials_shipment.package_type_code is 'Тип упаковки (код) | Тип упаковки (код) | ';
comment on column dm_calc.raw_materials_shipment.material_code is 'Материал (код) | Материал (код) | ';
comment on column dm_calc.raw_materials_shipment.railway_station_of_departure_code is 'Станция отправления (код) | Станция отправления (код) | ';
comment on column dm_calc.raw_materials_shipment.plant_of_departure_code is 'Завод отправления (код) | Завод отправления (код) | ';
comment on column dm_calc.raw_materials_shipment.railway_station_of_destination_code is 'Станция назначения (код) | Станция назначения (код) | ';
comment on column dm_calc.raw_materials_shipment.plant_of_destination_code is 'Завод назначения (код) | Завод назначения (код) | ';
comment on column dm_calc.raw_materials_shipment.import_method_code is 'Схема реализации (код) | Схема реализации (код) | ';
comment on column dm_calc.raw_materials_shipment.is_compound_cargo is 'Вагон составной (сборный) (код) | Вагон составной (сборный) (код) |  ';
comment on column dm_calc.raw_materials_shipment.etsng_code is 'Код груза ЕТСНГ (код) | Код груза ЕТСНГ (код) | ';
comment on column dm_calc.raw_materials_shipment.transport_type_code is 'Тип ПС (код) | Тип ПС (код) | ';
comment on column dm_calc.raw_materials_shipment.railcar_capacity is 'Грузоподъемность ПС | Грузоподъемность ПС | ';
comment on column dm_calc.raw_materials_shipment.redirection_type_code is 'Тип переадресации (код) | Тип переадресации (код) | ';
comment on column dm_calc.raw_materials_shipment.dt_redirected is 'Дата создания записи | Дата создания записи | ';
comment on column dm_calc.raw_materials_shipment.redirection_created_by_code is 'ФИО создания записи | ФИО создания записи | ';	
comment on column dm_calc.raw_materials_shipment.transport_bill_after_redirection_code is 'Накладная после переадресации (код) | Накладная после переадресации (код) | ';
comment on column dm_calc.raw_materials_shipment.dt_shipment_after_redirection is 'Дата отгрузки после переадресации | Дата отгрузки после переадресации | ';
comment on column dm_calc.raw_materials_shipment.station_of_destination_after_redirection_code is 'Станция переадресации (код) | Станция переадресации (код) | ';
comment on column dm_calc.raw_materials_shipment.station_of_destination_before_redirection_code is 'Станция назначения до переадресации (код) | Станция назначения до переадресации (код) | ';
comment on column dm_calc.raw_materials_shipment.plant_of_destination_before_redirection_code is 'Завод назначения до переадресации (код) | Завод назначения до переадресации (код) | ';
comment on column dm_calc.raw_materials_shipment.dt_train_operation is 'Дата текущего нахождения | Дата текущего нахождения | ';
comment on column dm_calc.raw_materials_shipment.dislocation_railcar_operation_code is 'Операция текущего нахождения по дислокации (код) | Операция текущего нахождения по дислокации (код) | ';
comment on column dm_calc.raw_materials_shipment.dislocation_station_of_departure_code is 'Станция отправления по дислокации (код) | Станция отправления по дислокации (код) | ';
comment on column dm_calc.raw_materials_shipment.dislocation_station_of_destination_code is 'Станция назначения по дислокации (код) | Станция назначения по дислокации (код) | ';
comment on column dm_calc.raw_materials_shipment.dislocation_station_current_code is 'Станция текущего нахождения по дислокации (код) | Станция текущего нахождения по дислокации (код) | ';
comment on column dm_calc.raw_materials_shipment.distance_left_to_destination_kilometer_quantity is 'Оставшееся расстояние в КМ до станции назначения | Оставшееся расстояние в КМ до станции назначения | ';
comment on column dm_calc.raw_materials_shipment.dt_dislocation_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным дислокации | Фактическая дата прибытия на станцию назначения по данным дислокации | ';
comment on column dm_calc.raw_materials_shipment.dt_dislocation_estimated_arrival_to_destination_station is 'Прогнозная дата прибытия на станцию назначения по данным дислокации | Прогнозная дата прибытия на станцию назначения по данным дислокации | ';
comment on column dm_calc.raw_materials_shipment.dt_vessel_arrival_to_russian_port is 'Дата прихода судна в порт РФ | Дата прихода судна в порт РФ | ';
comment on column dm_calc.raw_materials_shipment.dt_vessel_discharge_in_russian_port is 'Дата выгрузки с судна в порту РФ | Дата выгрузки с судна в порту РФ | ';
comment on column dm_calc.raw_materials_shipment.dt_arrival_to_destination_station is 'Дата прибытя на станцию назначения | Дата прибытя на станцию назначения | ';
comment on column dm_calc.raw_materials_shipment.dt_zdc_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | ';
comment on column dm_calc.raw_materials_shipment.dt_arrival_by_accounting is 'Дата поступления | Дата поступления | ';
comment on column dm_calc.raw_materials_shipment.vessel_code is 'Судно (код) | Судно (код) | ';
comment on column dm_calc.raw_materials_shipment.bill_of_lading_number is 'Номер коносамента (код) | Номер коносамента (код) | ';
comment on column dm_calc.raw_materials_shipment.delivery_code is 'Поставка (код) | Поставка (код) | ';
comment on column dm_calc.raw_materials_shipment.dt_general_act is 'Дата генерального акта | Дата генерального акта | ';
comment on column dm_calc.raw_materials_shipment.weight_net is 'Тоннаж | Тоннаж | ';
