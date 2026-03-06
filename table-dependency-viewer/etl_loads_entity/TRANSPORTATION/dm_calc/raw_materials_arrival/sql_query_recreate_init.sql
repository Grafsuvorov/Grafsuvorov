drop table if exists dm_calc.raw_materials_arrival;

create table if not exists dm_calc.raw_materials_arrival (
	material_code varchar(19) null,
	batch_code varchar(10) null,
	plant_code varchar(4) null,
	transport_bill_code varchar(35) null,	
	railcar_code varchar(20) null,
	transport_bill_and_railcar_code varchar(126) null,
	supplier_code varchar(10) null,
	producer_code varchar(10) null,
	business_scheme_type_code varchar(10) null,
	dt_arrival_by_accounting date null,
	dt_discharge date null,
	dt_posting date null,
	warehouse_code varchar(4) null,
	railway_track_at_plant_number varchar(3) null,
	purchase_contract_code varchar(10) null,
	bill_of_lading_number varchar(30) null,
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

comment on table dm_calc.raw_materials_arrival is 'Сырье. Данные поступления';
comment on column dm_calc.raw_materials_arrival.material_code is 'Материал (код) | Материал (код) | ';
comment on column dm_calc.raw_materials_arrival.batch_code is 'Партия (код) | Партия (код) | ';
comment on column dm_calc.raw_materials_arrival.plant_code is 'Завод (код) | Завод (код) | ';
comment on column dm_calc.raw_materials_arrival.transport_bill_code is 'Накладная (код) | Накладная (код) | ';
comment on column dm_calc.raw_materials_arrival.railcar_code is 'Вагон (код) | Вагон (код) | ';
comment on column dm_calc.raw_materials_arrival.transport_bill_and_railcar_code is 'Накладная-Вагон (код) | Накладная-Вагон (код) | ';
comment on column dm_calc.raw_materials_arrival.supplier_code is 'Поставщик (код) | Поставщик (код) | ';
comment on column dm_calc.raw_materials_arrival.producer_code is 'Производитель (код) | Производитель (код) | ';
comment on column dm_calc.raw_materials_arrival.business_scheme_type_code is 'Тип бизнес-схемы (код) | Тип бизнес-схемы (код) | ';
comment on column dm_calc.raw_materials_arrival.dt_arrival_by_accounting is 'Дата поступления | Дата поступления | ';
comment on column dm_calc.raw_materials_arrival.dt_discharge is 'Дата разгрузки | Дата разгрузки | ';
comment on column dm_calc.raw_materials_arrival.dt_posting is 'Дата бухгалтерского учета | Дата бухгалтерского учета | ';
comment on column dm_calc.raw_materials_arrival.warehouse_code is 'Склад (код) | Склад (код) | ';
comment on column dm_calc.raw_materials_arrival.railway_track_at_plant_number is 'Номер пути | Номер пути | ';
comment on column dm_calc.raw_materials_arrival.purchase_contract_code is 'Договор (код) | Договор (код) | ';
comment on column dm_calc.raw_materials_arrival.bill_of_lading_number is 'Номер коносамента (код) | Номер коносамента (код) | ';
comment on column dm_calc.raw_materials_arrival.weight_net is 'Тоннаж | Тоннаж | ';
