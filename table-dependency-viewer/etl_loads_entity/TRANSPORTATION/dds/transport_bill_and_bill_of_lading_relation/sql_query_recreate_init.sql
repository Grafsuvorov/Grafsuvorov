drop table if exists dds.transport_bill_and_bill_of_lading_relation;

create table if not exists dds.transport_bill_and_bill_of_lading_relation (
	transport_bill_code varchar(35) null,	
	vehicle_code varchar(20) null,
	transport_bill_and_vehicle_code varchar(126) null,	
	vessel_code varchar(10) null,
	bill_of_lading_number varchar(30) null,
	delivery_code varchar(10) null,
	dt_general_act date null,
	dt_vessel_arrival_to_russian_port date null,
	supplier_code varchar(10) null,
	producer_code varchar(10) null,
	material_code varchar(18) null,
	package_type_code varchar(3) null,
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

comment on table dds.transport_bill_and_bill_of_lading_relation is 'Связь транспортных накладных с коносаментами';
comment on column dds.transport_bill_and_bill_of_lading_relation.transport_bill_code is 'Накладная (код) | Накладная (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.vehicle_code is 'Транспортное средство (код) | Транспортное средство (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.transport_bill_and_vehicle_code is 'Накладная-Транспортное средство (код) | Накладная-Транспортное средство (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.vessel_code is 'Судно (код) | Судно (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.bill_of_lading_number is 'Номер коносамента (код) | Номер коносамента (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.delivery_code is 'Поставка (код) | Поставка (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.dt_general_act is 'Дата генерального акта | Дата генерального акта |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.dt_vessel_arrival_to_russian_port is 'Дата прихода судна в порт РФ | Дата прихода судна в порт РФ |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.supplier_code is 'Поставщик (код) | Поставщик (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.producer_code is 'Производитель (код) | Производитель (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.material_code is 'Материал (код) | Материал (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.package_type_code is 'Тип упаковки (код) | Тип упаковки (код) |  ';
comment on column dds.transport_bill_and_bill_of_lading_relation.weight_net is 'Тоннаж | Тоннаж |  ';