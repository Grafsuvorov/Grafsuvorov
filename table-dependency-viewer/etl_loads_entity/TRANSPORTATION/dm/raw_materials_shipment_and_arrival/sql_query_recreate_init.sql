drop table if exists dm.raw_materials_shipment_and_arrival cascade;

create table if not exists dm.raw_materials_shipment_and_arrival (
	transport_bill_code varchar(35) null,
	railcar_code varchar(20) null,
	transport_bill_and_railcar_code varchar(126) null,
	departure_type_code varchar(2) null,
	departure_type_name varchar(150) null,
	status_name varchar(140) null,							
	russian_port_pier_code varchar(10) null,
	russian_port_pier_name varchar(90) null,
	russian_port_pier_search_name varchar(100) null,
	russian_port_code varchar(10) null,
	russian_port_name varchar(90) null,
	russian_port_search_name varchar(100) null,
	russian_port_terminal_code varchar(10) null,
	russian_port_terminal_name varchar(90) null,
	russian_port_terminal_search_name varchar(100) null,
	vessel_code varchar(10) null,
	vessel_name varchar(180) null,
	vessel_search_name varchar(190) null,
	import_method_code varchar(1) null,
	import_method_name varchar(180) null,
	import_method_search_name varchar(190) null,
	dt_general_act date null,
	supplier_code varchar(10) null,
	supplier_name varchar(140) null,
	supplier_search_name varchar(150) null,
	producer_code varchar(10) null,
	producer_name varchar(140) null,
	producer_search_name varchar(150) null,
	business_scheme_type_code varchar(10) null,
	dt_departure date null,
	dt_shipping date null,
	dt_shipping_yyyy varchar(4) null,
	dt_shipping_dd varchar(2) null,
	dt_shipping_mmm varchar(12) null,
	package_type_code varchar(3) null,
	package_type_name varchar(180) null,
	package_type_search_name varchar(180) null,
	material_code varchar(18) null,
	material_name varchar(120) null,
	material_search_name varchar(140) null,
	etsng_code varchar(6) null,
	etsng_name varchar(80) null,
	etsng_search_name varchar(90) null,
	railway_station_of_departure_code varchar(10) null,
	railway_station_of_departure_name varchar(90) null,
	railway_station_of_departure_search_name varchar(100) null,
	plant_of_departure_code varchar(4) null,
	plant_of_departure_name varchar(90) null,
	plant_of_departure_search_name varchar(100) null,
	transport_type_code varchar(4) null,
	transport_type_name varchar(120) null,
	transport_type_search_name varchar(125) null,
	railcar_capacity numeric(13, 3) null,
	redirection_type_code varchar(2) null,
	redirection_type_name varchar(120) null,
	redirection_type_search_name varchar(125) null,
	dt_redirected date null,
	redirection_created_by_code varchar(12) null,
	redirection_created_by_name varchar(80) null,
	transport_bill_after_redirection_code varchar(35) null,
	dt_shipment_after_redirection date null,
	station_of_destination_after_redirection_code varchar(10) null,
	station_of_destination_after_redirection_name varchar(90) null,
	station_of_destination_after_redirection_search_name varchar(100) null,
	station_of_destination_before_redirection_code varchar(10) null,
	station_of_destination_before_redirection_name varchar(90) null,
	station_of_destination_before_redirection_search_name varchar(100) null,
	plant_of_destination_before_redirection_code varchar(4) null,
	plant_of_destination_before_redirection_name varchar(90) null,
	plant_of_destination_before_redirection_search_name varchar(100) null,
	dt_train_operation date null,
	dislocation_railcar_operation_code varchar(2) null,
	dislocation_railcar_operation_name varchar(80) null,
	dislocation_railcar_operation_search_name varchar(85) null,
	dislocation_station_of_departure_code varchar(10) null,
	dislocation_station_of_destination_code varchar(10) null,
	dislocation_station_current_code varchar(10) null,
	dislocation_station_current_name varchar(90) null,
	dislocation_station_current_search_name varchar(100) null,
	distance_left_to_destination_kilometer_quantity int null,
	dt_dislocation_arrival_to_destination_station date null,
	dt_dislocation_estimated_arrival_to_destination_station date null,
	dt_vessel_arrival_to_russian_port date null,
	dt_vessel_discharge_in_russian_port date null,
	dt_arrival_to_destination_station date null,
	dt_zdc_arrival_to_destination_station date null,
	dt_arrival_by_accounting date null,
	dt_arrival_yyyy varchar(4) null,
	dt_arrival_dd varchar(2) null,
	dt_arrival_mmm varchar(12) null,
	dt_discharge date null,
	dt_posting date null,
	purchase_contract_code varchar(10) null,
	railway_station_of_destination_code varchar(10) null,
	railway_station_of_destination_name varchar(90) null,
	railway_station_of_destination_search_name varchar(100) null,
	plant_of_destination_code varchar(4) null,
	plant_of_destination_name varchar(90) null,
	plant_of_destination_search_name varchar(100) null,
	warehouse_code varchar(4) null,
	warehouse_name varchar(16) null,
	warehouse_search_name varchar(25) null,
	railway_track_at_plant_number varchar(3) null,
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

comment on table dm.raw_materials_shipment_and_arrival is 'Сырье. Отгрузка и поступление'; 
comment on column dm.raw_materials_shipment_and_arrival.transport_bill_code is 'Накладная (код) | Наакладная (код) | dm_calc.raw_materials_shipment_and_arrival.transport_bill_code';
comment on column dm.raw_materials_shipment_and_arrival.railcar_code is 'Вагон (код) | Вагон (код) | dm_calc.raw_materials_shipment_and_arrival.railcar_code';
comment on column dm.raw_materials_shipment_and_arrival.transport_bill_and_railcar_code is 'Накладная-Вагон (код) | Накладная-Вагон (код) | dm_calc.raw_materials_shipment_and_arrival.transport_bill_and_railcar_code';
comment on column dm.raw_materials_shipment_and_arrival.departure_type_code is 'Источник данных перевозки (код) | Источник данных перевозки (код) | dm_calc.raw_materials_shipment_and_arrival.departure_type_code';
comment on column dm.raw_materials_shipment_and_arrival.departure_type_name is 'Источник данных перевозки (наименование) | Источник данных перевозки (наименование) | dm_calc.raw_materials_shipment_and_arrival.departure_type_name';
comment on column dm.raw_materials_shipment_and_arrival.status_name is 'Статус отгрузки (наименование) | Статус отгрузки (наименование) | См. алгоритм';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_pier_code is 'Причал в порту РФ (код) | Причал в порту РФ (код) | dm_calc.raw_materials_shipment_and_arrival.russian_port_pier_code';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_pier_name is 'Причал в порту РФ (наименование) | Причал в порту РФ (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_pier_search_name is 'Причал в порту РФ (код и наименование) | Причал в порту РФ (код и наименование) | Объединить russian_port_pier_code и russian_port_pier_name';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_code is 'Порт РФ (код) | Порт РФ (код) | dm_calc.raw_materials_shipment_and_arrival.russian_port_code';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_name is 'Порт РФ (наименование) | Порт РФ (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_search_name is 'Порт РФ (код и наименование) | Порт РФ (код и наименование) | Объединить russian_port_code и russian_port_name';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_terminal_code is 'Терминал в порту РФ (код) | Терминал в порту РФ (код) | dm_calc.raw_materials_shipment_and_arrival.russian_port_terminal_code';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_terminal_name is 'Терминал в порту РФ (наименование) | Терминал в порту РФ (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.russian_port_terminal_search_name is 'Терминал в порту РФ (код и наименование) | Терминал в порту РФ (код и наименование) | Объединить russian_port_terminal_code и russian_port_terminal_name';
comment on column dm.raw_materials_shipment_and_arrival.vessel_code is 'Судно (код) | Судно (код) | dm_calc.raw_materials_shipment_and_arrival.vessel_code';
comment on column dm.raw_materials_shipment_and_arrival.vessel_name is 'Судно (наименование) | Судно (наименование) | dict_dds.transport_vessel_old.vessel_name';
comment on column dm.raw_materials_shipment_and_arrival.vessel_search_name is 'Судно (код и наименование) | Судно (код и наименование) | Объединить vessel_code и vessel_name';
comment on column dm.raw_materials_shipment_and_arrival.import_method_code is 'Схема реализации (код) | Схема реализации (код) | dm_calc.raw_materials_shipment_and_arrival.import_method_code';
comment on column dm.raw_materials_shipment_and_arrival.import_method_name is 'Схема реализации (наименование) | Схема реализации (наименование) | dict_dds.import_method_texts.import_method_name';
comment on column dm.raw_materials_shipment_and_arrival.import_method_search_name is 'Схема реализации (код и наименование) | Схема реализации (код и наименование) | Объединить import_method_code и import_method_name';
comment on column dm.raw_materials_shipment_and_arrival.dt_general_act is 'Дата генерального акта | Дата генерального акта | dm_calc.raw_materials_shipment_and_arrival.dt_general_act';
comment on column dm.raw_materials_shipment_and_arrival.supplier_code is 'Поставщик (код) | Поставщик (код) | dm_calc.raw_materials_shipment_and_arrival.supplier_code';
comment on column dm.raw_materials_shipment_and_arrival.supplier_name is 'Поставщик (наименование) | Поставщик (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm.raw_materials_shipment_and_arrival.supplier_search_name is 'Поставщик (код и наименование) | Поставщик (код и наименование) | Объединить supplier_code и supplier_name';
comment on column dm.raw_materials_shipment_and_arrival.producer_code is 'Производитель (код) | Производитель (код) | dm_calc.raw_materials_shipment_and_arrival.producer_code';
comment on column dm.raw_materials_shipment_and_arrival.producer_name is 'Производитель (наименование) | Производитель (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm.raw_materials_shipment_and_arrival.producer_search_name is 'Производитель (код и наименование) | Производитель (код и наименование) | Объединить producer_code и producer_name';
comment on column dm.raw_materials_shipment_and_arrival.business_scheme_type_code is 'Тип бизнес-схемы (код) | Тип бизнес-схемы (код) | dm_calc.raw_materials_shipment_and_arrival.business_scheme_type_code';
comment on column dm.raw_materials_shipment_and_arrival.dt_departure is 'Дата отправки вагона | Дата отправки вагона | dm_calc.raw_materials_shipment_and_arrival.dt_departure';
comment on column dm.raw_materials_shipment_and_arrival.dt_shipping is 'Дата отгрузки вагона | Дата отгрузки вагона | dm_calc.raw_materials_shipment_and_arrival.dt_shipping';
comment on column dm.raw_materials_shipment_and_arrival.dt_shipping_yyyy is 'Год отгрузки вагона | Год отгрузки вагона | Год из dm_calc.raw_materials_shipment_and_arrival.dt_shipping';
comment on column dm.raw_materials_shipment_and_arrival.dt_shipping_dd is 'День отгрузки вагона | День отгрузки вагона | День из dm_calc.raw_materials_shipment_and_arrival.dt_shipping';
comment on column dm.raw_materials_shipment_and_arrival.dt_shipping_mmm is 'Месяц отгрузки вагона | Месяц отгрузки вагона | Месяц из dm_calc.raw_materials_shipment_and_arrival.dt_shipping';
comment on column dm.raw_materials_shipment_and_arrival.package_type_code is 'Тип тары (код) | Тип тары (код) | dm_calc.raw_materials_shipment_and_arrival.package_type_code';
comment on column dm.raw_materials_shipment_and_arrival.package_type_name is 'Тип тары (наименование) | Тип тары (наименование) | dict_dds.package_type_texts.package_type_name';
comment on column dm.raw_materials_shipment_and_arrival.package_type_search_name is 'Тип тары (код и наименование) | Тип тары (код и наименование) | Объединить package_type_code и package_type_name';
comment on column dm.raw_materials_shipment_and_arrival.material_code is 'Материал (код) | Материал (код) | dm_calc.raw_materials_shipment_and_arrival.material_code';
comment on column dm.raw_materials_shipment_and_arrival.material_name is 'Материал (наименование) | Материал (наименование) | dict_dds.material_texts.material_name';
comment on column dm.raw_materials_shipment_and_arrival.material_search_name is 'Материал (код и наименование) | Материал (код и наименование) | Объединить material_code и material_name';
comment on column dm.raw_materials_shipment_and_arrival.etsng_code is 'Код груза ЕТСНГ (код) | Код груза ЕТСНГ (код) | dm_calc.raw_materials_shipment_and_arrival.etsng_code';
comment on column dm.raw_materials_shipment_and_arrival.etsng_name is 'Код груза ЕТСНГ (наименование) | Код груза ЕТСНГ (наименование) | dict_dds.etsng.etsng_name_rus';
comment on column dm.raw_materials_shipment_and_arrival.etsng_search_name is 'Код груза (код и наименование) | Код груза (код и наименование) | Объединить etsng_code и etsng_name';
comment on column dm.raw_materials_shipment_and_arrival.railway_station_of_departure_code is 'Станция отправления (код) | Станция отправления (код) | dm_calc.raw_materials_shipment_and_arrival.railway_station_of_departure_code';
comment on column dm.raw_materials_shipment_and_arrival.railway_station_of_departure_name is 'Станция отправления (наименование) | Станция отправления (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.railway_station_of_departure_search_name is 'Станция отправления (код и наименование) | Станция отправления (код и наименование) | Объединить railway_station_of_departure_code и railway_station_of_departure_name';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_departure_code is 'Завод отправления (код) | Завод отправления (код) | dm_calc.raw_materials_shipment_and_arrival.plant_of_departure_code';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_departure_name is 'Завод отправления (наименование) | Завод отправления (наименование) | dict_dds.plant_and_subsidiary.plant_full_name';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_departure_search_name is 'Завод отправления (код и наименование) | Завод отправления (код и наименование) | Объединить plant_of_departure_code и plant_of_departure_name';
comment on column dm.raw_materials_shipment_and_arrival.transport_type_code is 'Тип ПС (код) | Тип ПС (код) | dm_calc.raw_materials_shipment_and_arrival.transport_type_code';
comment on column dm.raw_materials_shipment_and_arrival.transport_type_name is 'Тип ПС (наименование) | Тип ПС (наименование) | dict_dds.transport_transfer_type.transport_transfer_type_name_rus';
comment on column dm.raw_materials_shipment_and_arrival.transport_type_search_name is 'Тип ПС (код и наименование) | Тип ПС (код и наименование) | Объединить transport_type_code и transport_type_name';
comment on column dm.raw_materials_shipment_and_arrival.railcar_capacity is 'Грузоподъемность ПС | Грузоподъемность ПС | dm_calc.raw_materials_shipment_and_arrival.railcar_capacity';
comment on column dm.raw_materials_shipment_and_arrival.redirection_type_code is 'Тип переадресации (код) | Тип переадресации (код) | dm_calc.raw_materials_shipment_and_arrival.redirection_type_code';
comment on column dm.raw_materials_shipment_and_arrival.redirection_type_name is 'Тип переадресации (наименование) | Тип переадресации (наименование) | dict_dds.transport_redirection_type_texts.redirection_type_name';
comment on column dm.raw_materials_shipment_and_arrival.redirection_type_search_name is 'Тип переадресации (код и наименование) | Тип переадресации (код и наименование) | Объединить redirection_type_code и redirection_type_name';
comment on column dm.raw_materials_shipment_and_arrival.dt_redirected is 'Дата создания записи | Дата создания записи | dm_calc.raw_materials_shipment_and_arrival.dt_redirected';
comment on column dm.raw_materials_shipment_and_arrival.redirection_created_by_code is 'Автор создания записи | Автор создания записи | dm_calc.raw_materials_shipment_and_arrival.redirection_created_by_code';
comment on column dm.raw_materials_shipment_and_arrival.redirection_created_by_name is 'ФИО создания записи | ФИО создания записи | dict_dds.person_main_data.person_code';	
comment on column dm.raw_materials_shipment_and_arrival.transport_bill_after_redirection_code is 'Накладная после переадресации | Накладная после переадресации | dm_calc.raw_materials_shipment_and_arrival.transport_bill_after_redirection_code';
comment on column dm.raw_materials_shipment_and_arrival.dt_shipment_after_redirection is 'Дата отгрузки после переадресации | Дата отгрузки после переадресации | dm_calc.raw_materials_shipment_and_arrival.dt_shipment_after_redirection';
comment on column dm.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_code is 'Станция переадресации (код) | Станция переадресации (код) | dm_calc.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_code';
comment on column dm.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_name is 'Станция переадресации (наименование) | Станция переадресации (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_search_name is 'Станция переадресации (код и наименование) | Станция переадресации (код и наименование) | Объединить station_of_destination_after_redirection_code и station_of_destination_after_redirection_name';
comment on column dm.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_code is 'Станция назначения до переадресации (код) | Станция назначения до переадресации (код) | dm_calc.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_code';
comment on column dm.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_name is 'Станция назначения до переадресации (наименование) | Станция назначения до переадресации (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_search_name is 'Станция назначения до переадресации (код и наименование) | Станция назначения до переадресации (код и наименование) | Объединить station_of_destination_before_redirection_code и station_of_destination_before_redirection_name';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_code is 'Завод назначения до переадресации (код) | Завод назначения до переадресации (код) | dm_calc.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_code';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_name is 'Завод назначения до переадресации (наименование) | Завод назначения до переадресации (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_search_name is 'Завод назначения до переадресации (код и наименование) | Завод назначения до переадресации (код и наименование) | Объединить plant_of_destination_before_redirection_code и plant_of_destination_before_redirection_name';
comment on column dm.raw_materials_shipment_and_arrival.dt_train_operation is 'Дата текущего нахождения | Дата текущего нахождения | dm_calc.raw_materials_shipment_and_arrival.dt_train_operation';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_railcar_operation_code is 'Операция текущего нахождения по дислокации (код) | Операция текущего нахождения по дислокации (код) | dm_calc.raw_materials_shipment_and_arrival.dislocation_railcar_operation_code';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_railcar_operation_name is 'Операция текущего нахождения по дислокации (наименование) | Операция текущего нахождения по дислокации (наименование) | dict_dds.transport_operation_texts.transport_operation_full_name';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_railcar_operation_search_name is 'Операция текущего нахождения по дислокации (код и наименование) | Операция текущего нахождения по дислокации (код и наименование) | Объединить dislocation_railcar_operation_code и dislocation_railcar_operation_name';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_station_of_departure_code is 'Станция отправления по дислокации (код) | Станция отправления по дислокации (код) | dm_calc.raw_materials_shipment_and_arrival.dislocation_station_of_departure_code';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_station_of_destination_code is 'Станция назначения по дислокации (код) | Станция назначения по дислокации (код) | dm_calc.raw_materials_shipment_and_arrival.dislocation_station_of_destination_code';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_station_current_code is 'Станция текущего нахождения по дислокации (код) | Станция текущего нахождения по дислокации (код) | dm_calc.raw_materials_shipment_and_arrival.dislocation_station_current_code';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_station_current_name is 'Станция текущего нахождения по дислокации (наименование) | Станция текущего нахождения по дислокации (наименование) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.dislocation_station_current_search_name is 'Станция текущего нахождения по дислокации (код и наименование) | Станция текущего нахождения по дислокации (код и наименование) | Объединить dislocation_station_current_code и dislocation_station_current_name';
comment on column dm.raw_materials_shipment_and_arrival.distance_left_to_destination_kilometer_quantity is 'Оставшееся расстояние в КМ до станции назначения | Оставшееся расстояние в КМ до станции назначения | dm_calc.raw_materials_shipment_and_arrival.distance_left_to_destination_kilometer_quantity';
comment on column dm.raw_materials_shipment_and_arrival.dt_dislocation_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным дислокации | Фактическая дата прибытия на станцию назначения по данным дислокации | dm_calc.raw_materials_shipment_and_arrival.dt_dislocation_arrival_to_destination_station';
comment on column dm.raw_materials_shipment_and_arrival.dt_dislocation_estimated_arrival_to_destination_station is 'Прогнозная дата прибытия на станцию назначения по данным дислокации | Прогнозная дата прибытия на станцию назначения по данным дислокации | dm_calc.raw_materials_shipment_and_arrival.dt_dislocation_estimated_arrival_to_destination_station';
comment on column dm.raw_materials_shipment_and_arrival.dt_vessel_arrival_to_russian_port is 'Дата прихода судна в порт РФ | Дата прихода судна в порт РФ | dm_calc.raw_materials_shipment_and_arrival.dt_vessel_arrival_to_russian_port';
comment on column dm.raw_materials_shipment_and_arrival.dt_vessel_discharge_in_russian_port is 'Дата выгрузки с судна в порту РФ | Дата выгрузки с судна в порту РФ | dm_calc.raw_materials_shipment_and_arrival.dt_vessel_discharge_in_russian_port';
comment on column dm.raw_materials_shipment_and_arrival.dt_arrival_to_destination_station is 'Дата прибытя на станцию назначения | Дата прибытя на станцию назначения | dm_calc.raw_materials_shipment_and_arrival.dt_arrival_to_destination_station';
comment on column dm.raw_materials_shipment_and_arrival.dt_zdc_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | dm_calc.raw_materials_shipment_and_arrival.dt_zdc_arrival_to_destination_station';
comment on column dm.raw_materials_shipment_and_arrival.dt_arrival_by_accounting is 'Дата поступления | Дата поступления | dm_calc.raw_materials_shipment_and_arrival.dt_arrival_by_accounting';
comment on column dm.raw_materials_shipment_and_arrival.dt_arrival_yyyy is 'Год прибытя на станцию назначения | Год прибытя на станцию назначения | Год из dm_calc.raw_materials_shipment_and_arrival.dt_arrival';
comment on column dm.raw_materials_shipment_and_arrival.dt_arrival_dd is 'День прибытя на станцию назначения | День прибытя на станцию назначения | День из dm_calc.raw_materials_shipment_and_arrival.dt_arrival';
comment on column dm.raw_materials_shipment_and_arrival.dt_arrival_mmm is 'Месяц прибытя на станцию назначения | Месяц прибытя на станцию назначения | Месяц из dm_calc.raw_materials_shipment_and_arrival.dt_arrival';
comment on column dm.raw_materials_shipment_and_arrival.dt_discharge is 'Дата разгрузки | Дата разгрузки | dm_calc.raw_materials_shipment_and_arrival.dt_discharge';
comment on column dm.raw_materials_shipment_and_arrival.dt_posting is 'Дата бухгалтерского учета | Дата бухгалтерского учета | dm_calc.raw_materials_shipment_and_arrival.dt_posting';
comment on column dm.raw_materials_shipment_and_arrival.purchase_contract_code is 'Договор (код) | Договор (код) | dm_calc.raw_materials_shipment_and_arrival.purchase_contract_code';
comment on column dm.raw_materials_shipment_and_arrival.railway_station_of_destination_code is 'Станция назначения (код) | Станция назначения (код) | dm_calc.raw_materials_shipment_and_arrival.railway_station_of_destination_code';
comment on column dm.raw_materials_shipment_and_arrival.railway_station_of_destination_name is 'Станция назначения (назначение) | Станция назначения (назначение) | dict_dds.transport_hub.transport_hub_name';
comment on column dm.raw_materials_shipment_and_arrival.railway_station_of_destination_search_name is 'Станция назначения (код и назначение) | Станция назначения (код и назначение) | Объединить railway_station_of_destination_code и railway_station_of_destination_name';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_destination_code is 'Завод назначения (код) | Завод назначения (код) | dm_calc.raw_materials_shipment_and_arrival.plant_of_destination_code';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_destination_name is 'Завод назначения (наименование) | Завод назначения (наименование) | dict_dds.plant_and_subsidiary.plant_full_name';
comment on column dm.raw_materials_shipment_and_arrival.plant_of_destination_search_name is 'Завод назначения (код и наименование) | Завод назначения (код и наименование) | Объединить plant_of_destination_code и plant_of_destination_name';
comment on column dm.raw_materials_shipment_and_arrival.warehouse_code is 'Склад (код) | Склад (код) | dm_calc.raw_materials_shipment_and_arrival.warehouse_code';
comment on column dm.raw_materials_shipment_and_arrival.warehouse_name is 'Склад (наименование) | Склад (наименование) | dict_dds.warehouse.warehouse_name';
comment on column dm.raw_materials_shipment_and_arrival.warehouse_search_name is 'Склад (код и наименование) | Склад (код и наименование) | Объединить warehouse_code и warehouse_name';
comment on column dm.raw_materials_shipment_and_arrival.railway_track_at_plant_number is 'Номер пути | Номер пути | dm_calc.raw_materials_shipment_and_arrival.railway_track_at_plant_number';
comment on column dm.raw_materials_shipment_and_arrival.weight_net is 'Тоннаж | Тоннаж | dm_calc.raw_materials_shipment_and_arrival.weight_net';
