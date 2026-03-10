drop table if exists dm_calc.transportation_aluminium_shipment_from_plant;

create table dm_calc.transportation_aluminium_shipment_from_plant (  -- ключ: initial_delivery_code, initial_delivery_position_code
	initial_delivery_code varchar(10) not null,
	initial_delivery_position_code varchar(6) not null,
	batch_code varchar(10) null,
	plant_producer_code varchar(4) null,
	sales_market_code varchar(1) null,
	dt_shipped date null,
	route_shipping_code varchar(9) null,
	transport_railway_car_type_plan varchar(4) null,
	transport_vehicle_code varchar(20) null,
	transport_bill_code varchar(105) null,
	transport_bill_and_railcar_uni_code varchar(126) null,
	material_code varchar(18) null,
	trade_document_code varchar(10) null,
	trade_document_position_code varchar(6) null,
	is_relevant_transportation_aluminium_shipment_from_plant varchar(1) null,
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
	initial_delivery_code, 
	initial_delivery_position_code,
	batch_code,
	plant_producer_code,
	sales_market_code,
	dt_shipped,
	route_shipping_code,
	transport_railway_car_type_plan,
	material_code);

comment on table dm_calc.transportation_aluminium_shipment_from_plant is 'Реестр поставок - повагонная информация для ДСб';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.initial_delivery_code is 'Номер поставки завода производителя | Номер поставки завода производителя | delivery_position.delivery_document_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.initial_delivery_position_code is 'Позиция поставки | Позиция поставки | delivery_position.delivery_document_position_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.batch_code is 'Партия | Партия | delivery_position.batch_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.plant_producer_code is 'Завод производитель (код) | Завод производитель (код) | delivery_position.plant_producer_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.sales_market_code is 'Рынок сбыта (код) | Рынок сбыта, к которому относится страна потребителя | Алгоритм';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.dt_shipped is 'Дата отгрузки | Дата отгрузки | delivery.dt_shipped';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.route_shipping_code is 'Маршрут отгрузки (код) | Маршрут отгрузки (код) | delivery.route_shipping_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.transport_railway_car_type_plan is 'Тип транспорта, указанный в графике отгрузке на заводе-производеле | Системный тип транспортного средства, указанный в графике отгрузке на заводе производителе | delivery.transport_railway_car_type_plan';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.transport_vehicle_code is 'Номер транспортного средства | Номер транспортного средства | delivery.transport_vehicle_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.transport_bill_code is 'Номер накладной | Номер накладной | delivery.transport_bill_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.transport_bill_and_railcar_uni_code is 'Ж/д Накладная - №Вагона | Ж/д Накладная - №Вагона | delivery.transport_vehicle_code||transport_bill_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.material_code is 'Материал (код) | Материал (код) | delivery_position.material_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.trade_document_code is 'Торговый документ (код) | Торговый документ (код) | delivery_position.trade_document_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.trade_document_position_code is 'Торговый документ, позиция | Торговый документ, позиция (VBAP) | delivery_position.trade_document_position_code';
comment on column dm_calc.transportation_aluminium_shipment_from_plant.is_relevant_transportation_aluminium_shipment_from_plant is 'Релевантность для отчета отгрузка с завода | Релевантность для отчета отгрузка с завода | Заполнение на основе условий выборки данных';