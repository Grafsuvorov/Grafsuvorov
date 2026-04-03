drop view if exists dm_view.raw_materials_shipment_and_arrival;

create or replace view dm_view.raw_materials_shipment_and_arrival as
select
	transport_bill_code,
	railcar_code,
	transport_bill_and_railcar_code,
	departure_type_code,
	departure_type_name,
	status_name,			
	russian_port_pier_code,
	russian_port_pier_name,
	russian_port_pier_search_name,
	russian_port_code,
	russian_port_name,
	russian_port_search_name,
	russian_port_terminal_code,
	russian_port_terminal_name,
	russian_port_terminal_search_name,
	vessel_code,
	vessel_name,
	vessel_search_name,
	import_method_code,
	import_method_name,
	import_method_search_name,
	dt_general_act,
	supplier_code,
	supplier_name,
	supplier_search_name,
	producer_code,
	producer_name,
	producer_search_name,
	business_scheme_type_code,
	dt_departure,
	dt_shipping,
	dt_shipping_yyyy,
	dt_shipping_dd,
	dt_shipping_mmm,
	package_type_code,
	package_type_name,
	package_type_search_name,
	material_code,
	material_name,
	material_search_name,
	etsng_code,
	etsng_name,
	etsng_search_name,
	railway_station_of_departure_code,
	railway_station_of_departure_name,
	railway_station_of_departure_search_name,
	plant_of_departure_code,
	plant_of_departure_name,
	plant_of_departure_search_name,
	transport_type_code,
	transport_type_name,
	transport_type_search_name,
	railcar_capacity,
	redirection_type_code,
	redirection_type_name,
	redirection_type_search_name,
	dt_redirected,
	redirection_created_by_code,
	redirection_created_by_name,
	transport_bill_after_redirection_code,
	dt_shipment_after_redirection,
	station_of_destination_after_redirection_code,
	station_of_destination_after_redirection_name,
	station_of_destination_after_redirection_search_name,
	station_of_destination_before_redirection_code,
	station_of_destination_before_redirection_name,
	station_of_destination_before_redirection_search_name,
	plant_of_destination_before_redirection_code,
	plant_of_destination_before_redirection_name,
	plant_of_destination_before_redirection_search_name,
	dt_train_operation,
	dislocation_railcar_operation_code,
	dislocation_railcar_operation_name,
	dislocation_railcar_operation_search_name,
	dislocation_station_of_departure_code,
	dislocation_station_of_destination_code,
	dislocation_station_current_code,
	dislocation_station_current_name,
	dislocation_station_current_search_name,
	distance_left_to_destination_kilometer_quantity,
	dt_dislocation_arrival_to_destination_station,
	dt_dislocation_estimated_arrival_to_destination_station,
	dt_vessel_arrival_to_russian_port,
	dt_vessel_discharge_in_russian_port,
	dt_arrival_to_destination_station,
	dt_zdc_arrival_to_destination_station,
	dt_arrival_by_accounting,
	dt_arrival_yyyy,
	dt_arrival_dd,
	dt_arrival_mmm,
	dt_discharge,
	dt_posting,
	purchase_contract_code,
	railway_station_of_destination_code,
	railway_station_of_destination_name,
	railway_station_of_destination_search_name,
	plant_of_destination_code,
	plant_of_destination_name,
	plant_of_destination_search_name,
	warehouse_code,
	warehouse_name,
	warehouse_search_name,
	railway_track_at_plant_number,
	weight_net,
	dttm_inserted,
	dttm_updated,
	job_name,
	deleted_flag
from dm.raw_materials_shipment_and_arrival
where 1=1
  and deleted_flag = false;

comment on view dm_view.raw_materials_shipment_and_arrival is 'Сырье. Отгрузка и поступление'; 
comment on column dm_view.raw_materials_shipment_and_arrival.transport_bill_code is 'Накладная (код) | Накладная (код) | dm.raw_materials_shipment_and_arrival.transport_bill_code';
comment on column dm_view.raw_materials_shipment_and_arrival.railcar_code is 'Вагон (код) | Вагон (код) | dm.raw_materials_shipment_and_arrival.railcar_code';
comment on column dm_view.raw_materials_shipment_and_arrival.transport_bill_and_railcar_code is 'Накладная-Вагон (код) | Накладная-Вагон (код) | dm.raw_materials_shipment_and_arrival.transport_bill_and_railcar_code';
comment on column dm_view.raw_materials_shipment_and_arrival.departure_type_code is 'Источник данных перевозки (код) | Источник данных перевозки (код) | dm.raw_materials_shipment_and_arrival.departure_type_code';
comment on column dm_view.raw_materials_shipment_and_arrival.departure_type_name is 'Источник данных перевозки (наименование) | Источник данных перевозки (наименование) | dm.raw_materials_shipment_and_arrival.departure_type_name';
comment on column dm_view.raw_materials_shipment_and_arrival.status_name is 'Статус отгрузки (наименование) | Статус отгрузки (наименование) | dm.raw_materials_shipment_and_arrival.status_name';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_pier_code is 'Причал в порту РФ (код) | Причал в порту РФ (код) | dm.raw_materials_shipment_and_arrival.russian_port_pier_code';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_pier_name is 'Причал в порту РФ (наименование) | Причал в порту РФ (наименование) | dm.raw_materials_shipment_and_arrival.russian_port_pier_name';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_pier_search_name is 'Причал в порту РФ (код и наименование) | Причал в порту РФ (код и наименование) | dm.raw_materials_shipment_and_arrival.russian_port_pier_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_code is 'Порт РФ (код) | Порт РФ (код) | dm.raw_materials_shipment_and_arrival.russian_port_code';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_name is 'Порт РФ (наименование) | Порт РФ (наименование) | dm.raw_materials_shipment_and_arrival.russian_port_name';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_search_name is 'Порт РФ (код и наименование) | Порт РФ (код и наименование) | dm.raw_materials_shipment_and_arrival.russian_port_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_terminal_code is 'Терминал в порту РФ (код) | Терминал в порту РФ (код) | dm.raw_materials_shipment_and_arrival.russian_port_terminal_code';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_terminal_name is 'Терминал в порту РФ (наименование) | Терминал в порту РФ (наименование) | dm.raw_materials_shipment_and_arrival.russian_port_terminal_name';
comment on column dm_view.raw_materials_shipment_and_arrival.russian_port_terminal_search_name is 'Терминал в порту РФ (код и наименование) | Терминал в порту РФ (код и наименование) | dm.raw_materials_shipment_and_arrival.russian_port_terminal_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.vessel_code is 'Судно (код) | Судно (код) | dm.raw_materials_shipment_and_arrival.vessel_code';
comment on column dm_view.raw_materials_shipment_and_arrival.vessel_name is 'Судно (наименование) | Судно (наименование) | dm.raw_materials_shipment_and_arrival.vessel_name';
comment on column dm_view.raw_materials_shipment_and_arrival.vessel_search_name is 'Судно (код и наименование) | Судно (код и наименование) | dm.raw_materials_shipment_and_arrival.vessel_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.import_method_code is 'Схема реализации (код) | Схема реализации (код) | dm.raw_materials_shipment_and_arrival.import_method_code';
comment on column dm_view.raw_materials_shipment_and_arrival.import_method_name is 'Схема реализации (наименование) | Схема реализации (наименование) | dm.raw_materials_shipment_and_arrival.import_method_name';
comment on column dm_view.raw_materials_shipment_and_arrival.import_method_search_name is 'Схема реализации (код и наименование) | Схема реализации (код и наименование) | dm.raw_materials_shipment_and_arrival.import_method_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_general_act is 'Дата генерального акта | Дата генерального акта | dm.raw_materials_shipment_and_arrival.dt_general_act';
comment on column dm_view.raw_materials_shipment_and_arrival.supplier_code is 'Поставщик (код) | Поставщик (код) | dm.raw_materials_shipment_and_arrival.supplier_code';
comment on column dm_view.raw_materials_shipment_and_arrival.supplier_name is 'Поставщик (наименование) | Поставщик (наименование) | dm.raw_materials_shipment_and_arrival.supplier_name';
comment on column dm_view.raw_materials_shipment_and_arrival.supplier_search_name is 'Поставщик (код и наименование) | Поставщик (код и наименование) | dm.raw_materials_shipment_and_arrival.supplier_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.producer_code is 'Производитель (код) | Производитель (код) | dm.raw_materials_shipment_and_arrival.producer_code';
comment on column dm_view.raw_materials_shipment_and_arrival.producer_name is 'Производитель (наименование) | Производитель (наименование) | dm.raw_materials_shipment_and_arrival.producer_name';
comment on column dm_view.raw_materials_shipment_and_arrival.producer_search_name is 'Производитель (код и наименование) | Производитель (код и наименование) | dm.raw_materials_shipment_and_arrival.producer_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.business_scheme_type_code is 'Тип бизнес-схемы (код) | Тип бизнес-схемы (код) | dm.raw_materials_shipment_and_arrival.business_scheme_type_code';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_departure is 'Дата отправки вагона | Дата отправки вагона | dm.raw_materials_shipment_and_arrival.dt_departure';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_shipping is 'Дата отгрузки вагона | Дата отгрузки вагона | dm.raw_materials_shipment_and_arrival.dt_shipping';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_shipping_yyyy is 'Год отгрузки вагона | Год отгрузки вагона | dm.raw_materials_shipment_and_arrival.dt_shipping_yyyy';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_shipping_dd is 'День отгрузки вагона | День отгрузки вагона | dm.raw_materials_shipment_and_arrival.dt_shipping_dd';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_shipping_mmm is 'Месяц отгрузки вагона | Месяц отгрузки вагона | dm.raw_materials_shipment_and_arrival.dt_shipping_mmm';
comment on column dm_view.raw_materials_shipment_and_arrival.package_type_code is 'Тип тары (код) | Тип тары (код) | dm.raw_materials_shipment_and_arrival.package_type_code';
comment on column dm_view.raw_materials_shipment_and_arrival.package_type_name is 'Тип тары (наименование) | Тип тары (наименование) | dm.raw_materials_shipment_and_arrival.package_type_name';
comment on column dm_view.raw_materials_shipment_and_arrival.package_type_search_name is 'Тип тары (код и наименование) | Тип тары (код и наименование) | dm.raw_materials_shipment_and_arrival.package_type_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.material_code is 'Материал (код) | Материал (код) | dm.raw_materials_shipment_and_arrival.material_code';
comment on column dm_view.raw_materials_shipment_and_arrival.material_name is 'Материал (наименование) | Материал (наименование) | dm.raw_materials_shipment_and_arrival.material_name';
comment on column dm_view.raw_materials_shipment_and_arrival.material_search_name is 'Материал (код и наименование) | Материал (код и наименование) | dm.raw_materials_shipment_and_arrival.material_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.etsng_code is 'Код груза ЕТСНГ (код) | Код груза ЕТСНГ (код) | dm.raw_materials_shipment_and_arrival.etsng_code';
comment on column dm_view.raw_materials_shipment_and_arrival.etsng_name is 'Код груза ЕТСНГ (наименование) | Код груза ЕТСНГ (наименование) | dm.raw_materials_shipment_and_arrival.etsng_name';
comment on column dm_view.raw_materials_shipment_and_arrival.etsng_search_name is 'Код груза (код и наименование) | Код груза (код и наименование) | dm.raw_materials_shipment_and_arrival.etsng_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_station_of_departure_code is 'Станция отправления (код) | Станция отправления (код) | dm.raw_materials_shipment_and_arrival.railway_station_of_departure_code';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_station_of_departure_name is 'Станция отправления (наименование) | Станция отправления (наименование) | dm.raw_materials_shipment_and_arrival.railway_station_of_departure_name';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_station_of_departure_search_name is 'Станция отправления (код и наименование) | Станция отправления (код и наименование) | dm.raw_materials_shipment_and_arrival.railway_station_of_departure_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_departure_code is 'Завод отправления (код) | Завод отправления (код) | dm.raw_materials_shipment_and_arrival.plant_of_departure_code';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_departure_name is 'Завод отправления (наименование) | Завод отправления (наименование) | dm.raw_materials_shipment_and_arrival.plant_of_departure_name';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_departure_search_name is 'Завод отправления (код и наименование) | Завод отправления (код и наименование) | dm.raw_materials_shipment_and_arrival.plant_of_departure_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.transport_type_code is 'Тип ПС (код) | Тип ПС (код) | dm.raw_materials_shipment_and_arrival.transport_type_code';
comment on column dm_view.raw_materials_shipment_and_arrival.transport_type_name is 'Тип ПС (наименование) | Тип ПС (наименование) | dm.raw_materials_shipment_and_arrival.transport_type_name';
comment on column dm_view.raw_materials_shipment_and_arrival.transport_type_search_name is 'Тип ПС (код и наименование) | Тип ПС (код и наименование) | dm.raw_materials_shipment_and_arrival.transport_type_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.railcar_capacity is 'Грузоподъемность ПС | Грузоподъемность ПС | dm.raw_materials_shipment_and_arrival.railcar_capacity';
comment on column dm_view.raw_materials_shipment_and_arrival.redirection_type_code is 'Тип переадресации (код) | Тип переадресации (код) | dm.raw_materials_shipment_and_arrival.redirection_type_code';
comment on column dm_view.raw_materials_shipment_and_arrival.redirection_type_name is 'Тип переадресации (наименование) | Тип переадресации (наименование) | dm.raw_materials_shipment_and_arrival.redirection_type_name';
comment on column dm_view.raw_materials_shipment_and_arrival.redirection_type_search_name is 'Тип переадресации (код и наименование) | Тип переадресации (код и наименование) | dm.raw_materials_shipment_and_arrival.redirection_type_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_redirected is 'Дата создания записи | Дата создания записи | dm.raw_materials_shipment_and_arrival.dt_redirected';
comment on column dm_view.raw_materials_shipment_and_arrival.redirection_created_by_code is 'Автор создания записи | Автор создания записи | dm.raw_materials_shipment_and_arrival.redirection_created_by_code';	
comment on column dm_view.raw_materials_shipment_and_arrival.redirection_created_by_name is 'ФИО создания записи | ФИО создания записи | dm.raw_materials_shipment_and_arrival.redirection_created_by_name';	
comment on column dm_view.raw_materials_shipment_and_arrival.transport_bill_after_redirection_code is 'Накладная после переадресации | Накладная после переадресации | dm.raw_materials_shipment_and_arrival.transport_bill_after_redirection_code';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_shipment_after_redirection is 'Дата отгрузки после переадресации | Дата отгрузки после переадресации | dm.raw_materials_shipment_and_arrival.dt_shipment_after_redirection';
comment on column dm_view.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_code is 'Станция переадресации (код) | Станция переадресации (код) | dm.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_code';
comment on column dm_view.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_name is 'Станция переадресации (наименование) | Станция переадресации (наименование) | dm.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_name';
comment on column dm_view.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_search_name is 'Станция переадресации (код и наименование) | Станция переадресации (код и наименование) | dm.raw_materials_shipment_and_arrival.station_of_destination_after_redirection_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_code is 'Станция назначения до переадресации (код) | Станция назначения до переадресации (код) | dm.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_code';
comment on column dm_view.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_name is 'Станция назначения до переадресации (наименование) | Станция назначения до переадресации (наименование) | dm.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_name';
comment on column dm_view.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_search_name is 'Станция назначения до переадресации (код и наименование) | Станция назначения до переадресации (код и наименование) | dm.raw_materials_shipment_and_arrival.station_of_destination_before_redirection_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_code is 'Завод назначения до переадресации (код) | Завод назначения до переадресации (код) | dm.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_code';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_name is 'Завод назначения до переадресации (наименование) | Завод назначения до переадресации (наименование) | dm.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_name';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_search_name is 'Завод назначения до переадресации (код и наименование) | Завод назначения до переадресации (код и наименование) | dm.raw_materials_shipment_and_arrival.plant_of_destination_before_redirection_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_train_operation is 'Дата текущего нахождения | Дата текущего нахождения | dm.raw_materials_shipment_and_arrival.dt_train_operation';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_railcar_operation_code is 'Операция текущего нахождения по дислокации (код) | Операция текущего нахождения по дислокации (код) | dm.raw_materials_shipment_and_arrival.dislocation_railcar_operation_code';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_railcar_operation_name is 'Операция текущего нахождения по дислокации (наименование) | Операция текущего нахождения по дислокации (наименование) | dm.raw_materials_shipment_and_arrival.dislocation_railcar_operation_name';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_railcar_operation_search_name is 'Операция текущего нахождения по дислокации (код и наименование) | Операция текущего нахождения по дислокации (код и наименование) | dm.raw_materials_shipment_and_arrival.dislocation_railcar_operation_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_station_of_departure_code is 'Станция отправления по дислокации (код) | Станция отправления по дислокации (код) | dm.raw_materials_shipment_and_arrival.dislocation_station_of_departure_code';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_station_of_destination_code is 'Станция назначения по дислокации (код) | Станция назначения по дислокации (код) | dm.raw_materials_shipment_and_arrival.dislocation_station_of_destination_code';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_station_current_code is 'Станция текущего нахождения по дислокации (код) | Станция текущего нахождения по дислокации (код) | dm.raw_materials_shipment_and_arrival.dislocation_station_current_code';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_station_current_name is 'Станция текущего нахождения по дислокации (наименование) | Станция текущего нахождения по дислокации (наименование) | dm.raw_materials_shipment_and_arrival.dislocation_station_current_name';
comment on column dm_view.raw_materials_shipment_and_arrival.dislocation_station_current_search_name is 'Станция текущего нахождения по дислокации (код и наименование) | Станция текущего нахождения по дислокации (код и наименование) | dm.raw_materials_shipment_and_arrival.dislocation_station_current_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.distance_left_to_destination_kilometer_quantity is 'Оставшееся расстояние в КМ до станции назначения | Оставшееся расстояние в КМ до станции назначения | dm.raw_materials_shipment_and_arrival.distance_left_to_destination_kilometer_quantity';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_dislocation_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным дислокации | Фактическая дата прибытия на станцию назначения по данным дислокации | dm.raw_materials_shipment_and_arrival.dt_dislocation_arrival_to_destination_station';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_dislocation_estimated_arrival_to_destination_station is 'Прогнозная дата прибытия на станцию назначения по данным дислокации | Прогнозная дата прибытия на станцию назначения по данным дислокации | dm.raw_materials_shipment_and_arrival.dt_dislocation_estimated_arrival_to_destination_station';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_vessel_arrival_to_russian_port is 'Дата прихода судна в порт РФ | Дата прихода судна в порт РФ | dm.raw_materials_shipment_and_arrival.dt_vessel_arrival_to_russian_port';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_vessel_discharge_in_russian_port is 'Дата выгрузки с судна в порту РФ | Дата выгрузки с судна в порту РФ | dm.raw_materials_shipment_and_arrival.dt_vessel_discharge_in_russian_port';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_arrival_to_destination_station is 'Дата прибытя на станцию назначения | Дата прибытя на станцию назначения | dm.raw_materials_shipment_and_arrival.dt_arrival_to_destination_station';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_zdc_arrival_to_destination_station is 'Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | Фактическая дата прибытия на станцию назначения по данным АСУ ЖДЦ | dm.raw_materials_shipment_and_arrival.dt_zdc_arrival_to_destination_station';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_arrival_by_accounting is 'Дата поступления | Дата поступления | dm.raw_materials_shipment_and_arrival.dt_arrival_by_accounting';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_arrival_yyyy is 'Год прибытя на станцию назначения | Год прибытя на станцию назначения | dm.raw_materials_shipment_and_arrival.dt_arrival_yyyy';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_arrival_dd is 'День прибытя на станцию назначения | День прибытя на станцию назначения | dm.raw_materials_shipment_and_arrival.dt_arrival_dd';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_arrival_mmm is 'Месяц прибытя на станцию назначения | Месяц прибытя на станцию назначения | dm.raw_materials_shipment_and_arrival.dt_arrival_mmm';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_discharge is 'Дата разгрузки | Дата разгрузки | dm.raw_materials_shipment_and_arrival.dt_discharge';
comment on column dm_view.raw_materials_shipment_and_arrival.dt_posting is 'Дата бухгалтерского учета | Дата бухгалтерского учета | dm.raw_materials_shipment_and_arrival.dt_posting';
comment on column dm_view.raw_materials_shipment_and_arrival.purchase_contract_code is 'Договор (код) | Договор (код) | dm.raw_materials_shipment_and_arrival.purchase_contract_code';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_station_of_destination_code is 'Станция назначения (код) | Станция назначения (код) | dm.raw_materials_shipment_and_arrival.railway_station_of_destination_code';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_station_of_destination_name is 'Станция назначения (назначение) | Станция назначения (назначение) | dm.raw_materials_shipment_and_arrival.railway_station_of_destination_name';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_station_of_destination_search_name is 'Станция назначения (код и назначение) | Станция назначения (код и назначение) | dm.raw_materials_shipment_and_arrival.railway_station_of_destination_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_destination_code is 'Завод назначения (код) | Завод назначения (код) | dm.raw_materials_shipment_and_arrival.plant_of_destination_code';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_destination_name is 'Завод назначения (наименование) | Завод назначения (наименование) | dm.raw_materials_shipment_and_arrival.plant_of_destination_name';
comment on column dm_view.raw_materials_shipment_and_arrival.plant_of_destination_search_name is 'Завод назначения (код и наименование) | Завод назначения (код и наименование) | dm.raw_materials_shipment_and_arrival.plant_of_destination_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.warehouse_code is 'Склад (код) | Склад (код) | dm.raw_materials_shipment_and_arrival.warehouse_code';
comment on column dm_view.raw_materials_shipment_and_arrival.warehouse_name is 'Склад (наименование) | Склад (наименование) | dm.raw_materials_shipment_and_arrival.warehouse_name';
comment on column dm_view.raw_materials_shipment_and_arrival.warehouse_search_name is 'Склад (код и наименование) | Склад (код и наименование) | dm.raw_materials_shipment_and_arrival.warehouse_search_name';
comment on column dm_view.raw_materials_shipment_and_arrival.railway_track_at_plant_number is 'Номер пути | Номер пути | dm.raw_materials_shipment_and_arrival.railway_track_at_plant_number';
comment on column dm_view.raw_materials_shipment_and_arrival.weight_net is 'Тоннаж | Тоннаж | dm.raw_materials_shipment_and_arrival.weight_net';
