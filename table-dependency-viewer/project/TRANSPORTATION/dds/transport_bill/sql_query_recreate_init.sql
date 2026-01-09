drop table if exists dds.transport_bill;

create table if not exists dds.transport_bill (
	transport_bill_code varchar(35) null,	
	vehicle_code varchar(20) null,
	transport_bill_and_vehicle_code varchar(126) null,
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
	vehicle_capacity numeric(13, 3) null,
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
	dt_arrival_to_destination_station date null,
	dt_zdc_arrival_to_destination_station date null,
	dt_arrival_by_accounting date null,
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
	vehicle_code
);

comment on table dds.transport_bill is 'Транспортная накладная по суше';
comment on column dds.transport_bill.transport_bill_code is 'Накладная (код) | Накладная (код) |  ';
comment on column dds.transport_bill.vehicle_code is 'Транспортное средство (код) | Транспортное средство (код) |  ';
comment on column dds.transport_bill.transport_bill_and_vehicle_code is 'Накладная-Транспортное средство (код) | Накладная-Транспортное средство (код) |  ';
comment on column dds.transport_bill.departure_type_code is 'Источник данных перевозки (код) | Источник данных перевозки (код) |  ';
comment on column dds.transport_bill.departure_type_name is 'Источник данных перевозки (наименование) | Источник данных перевозки (наименование) |  ';
comment on column dds.transport_bill.dt_shipping is 'Дата отгрузки транспортного средства | Дата отгрузки транспортного средства |  ';
comment on column dds.transport_bill.dt_departure is 'Дата отправки транспортного средства | Дата отправки транспортного средства |  ';
comment on column dds.transport_bill.russian_port_pier_code is 'Причал в порту РФ (код) | Причал в порту РФ (код) |  ';
comment on column dds.transport_bill.russian_port_code is 'Порт РФ (код) | Порт РФ (код) |  ';
comment on column dds.transport_bill.russian_port_terminal_code is 'Терминал в порту РФ (код) | Терминал в порту РФ (код) |  ';
comment on column dds.transport_bill.supplier_code is 'Поставщик (код) | Поставщик (код) |  ';
comment on column dds.transport_bill.producer_code is 'Производитель (код) | Производитель (код) |  ';
comment on column dds.transport_bill.business_scheme_type_code is 'Тип бизнес-схемы (код) | Тип бизнес-схемы (код) |  ';
comment on column dds.transport_bill.package_type_code is 'Тип упаковки (код) | Тип упаковки (код) |  ';
comment on column dds.transport_bill.material_code is 'Материал (код) | Материал (код) |  ';
comment on column dds.transport_bill.railway_station_of_departure_code is 'Станция отправления (код) | Станция отправления (код) |  ';
comment on column dds.transport_bill.plant_of_departure_code is 'Завод отправления (код) | Завод отправления (код) |  ';
comment on column dds.transport_bill.railway_station_of_destination_code is 'Станция назначения (код) | Станция назначения (код) |  ';
comment on column dds.transport_bill.plant_of_destination_code is 'Завод назначения (код) | Завод назначения (код) |  ';
comment on column dds.transport_bill.import_method_code is 'Схема реализации (код) | Схема реализации (код) |  ';
comment on column dds.transport_bill.is_compound_cargo is 'Вагон составной (сборный) (код) | Вагон составной (сборный) (код) |  ';
comment on column dds.transport_bill.etsng_code is 'Код груза ЕТСНГ (код) | Код груза ЕТСНГ (код) |  ';
comment on column dds.transport_bill.transport_type_code is 'Тип ПС (код) | Тип ПС (код) |  ';
comment on column dds.transport_bill.vehicle_capacity is 'Грузоподъемность ПС | Грузоподъемность ПС |  ';
comment on column dds.transport_bill.redirection_type_code is 'Тип переадресации (код) | Тип переадресации (код) |  ';
comment on column dds.transport_bill.dt_redirected is 'Дата фиксации переадресации | Дата фиксации переадресации |  ';
comment on column dds.transport_bill.redirection_created_by_code is 'Автор создания записи | Автор создания записи |  ';
comment on column dds.transport_bill.transport_bill_after_redirection_code is 'Накладная после переадресации (код) | Накладная после переадресации (код) |  ';
comment on column dds.transport_bill.dt_shipment_after_redirection is 'Дата отгрузки после переадресации | Дата отгрузки после переадресации |  ';
comment on column dds.transport_bill.station_of_destination_after_redirection_code is 'Станция переадресации (код) | Станция переадресации (код) |  ';
comment on column dds.transport_bill.station_of_destination_before_redirection_code is 'Станция назначения до переадресации (код) | Станция назначения до переадресации (код) |  ';
comment on column dds.transport_bill.plant_of_destination_before_redirection_code is 'Завод назначения до переадресации (код) | Завод назначения до переадресации (код) |  ';
comment on column dds.transport_bill.dt_train_operation is 'Дата операции по дислокации | Дата операции по дислокации |  ';
comment on column dds.transport_bill.dislocation_railcar_operation_code is 'Операция текущего нахождения (код) | Операция текущего нахождения (код) |  ';
comment on column dds.transport_bill.dislocation_station_of_departure_code is 'Станция отправления по дислокации (код) | Станция отправления по дислокации (код) |  ';
comment on column dds.transport_bill.dislocation_station_of_destination_code is 'Станция назначения по дислокации (код) | Станция назначения по дислокации (код) |  ';
comment on column dds.transport_bill.dislocation_station_current_code is 'Станция текущего нахождения (код) | Станция текущего нахождения (код) |  ';
comment on column dds.transport_bill.distance_left_to_destination_kilometer_quantity is 'Оставшееся расстояние в КМ до станции назначения | Оставшееся расстояние в КМ до станции назначения |  ';
comment on column dds.transport_bill.dt_dislocation_arrival_to_destination_station is 'Фактическая дата прибытия на станцию завода по данным дислокации | Фактическая дата прибытия на станцию завода по данным дислокации |  ';
comment on column dds.transport_bill.dt_dislocation_estimated_arrival_to_destination_station is 'Прогнозная дата прибытия на станцию завода по данным дислокации | Прогнозная дата прибытия на станцию завода по данным дислокации |  ';
comment on column dds.transport_bill.dt_arrival_to_destination_station is 'Дата прибытя на станцию назначения | Дата прибытя на станцию назначения |  ';
comment on column dds.transport_bill.dt_zdc_arrival_to_destination_station is 'Фактическая дата прибытия на станцию завода по данным АСУ ЖДЦ | Фактическая дата прибытия на станцию завода по данным АСУ ЖДЦ |  ';
comment on column dds.transport_bill.dt_arrival_by_accounting is 'Дата поступления | Дата поступления |  ';
comment on column dds.transport_bill.weight_net is 'Тоннаж | Тоннаж |  ';