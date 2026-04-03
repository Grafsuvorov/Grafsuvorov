drop table if exists dds.transportation_raw_materials_business_plan_position;

create table dds.transportation_raw_materials_business_plan_position (
	dt_business_plan_yyyy varchar(4) null,
	material_code varchar(18) null,
	version_code varchar(3) null,
	position_code varchar(6) null,
	etsng_code varchar(6) null,
	transportation_scheme_code varchar(7) null,
	transport_type_code varchar(4) null,
	transport_departure_hub_code varchar(10) null,
	transport_destination_hub_code varchar(10) null,
	vehicle_quantity numeric(13, 3) null,
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
distributed by (transport_type_code, transport_departure_hub_code, transport_destination_hub_code);

comment on table dds.transportation_raw_materials_business_plan_position is 'Бизнес-план по транспортировке Корзины сырья: Позиция';
comment on column dds.transportation_raw_materials_business_plan_position.dt_business_plan_yyyy is 'Год бинес-плана | Год бинес-плана | ods.zle2464m_bp_rawp_ral.gjahr';
comment on column dds.transportation_raw_materials_business_plan_position.material_code is 'Материал (код) | Материал (код) | ods.zle2464m_bp_rawp_ral.matnr';
comment on column dds.transportation_raw_materials_business_plan_position.version_code is 'Версия (код) | Версия (код) | ods.zle2464m_bp_rawp_ral.version';
comment on column dds.transportation_raw_materials_business_plan_position.position_code is 'Позиция бизнес-плана (код) | Позиция бизнес-плана (код) | ods.zle2464m_bp_rawp_ral.posnr';
comment on column dds.transportation_raw_materials_business_plan_position.etsng_code is 'ЕТСНГ исходный (код) | ЕТСНГ исходный (код) | ods.zle2464m_bp_rawp_ral.etsng';
comment on column dds.transportation_raw_materials_business_plan_position.transportation_scheme_code is 'Схема перевозки (код) | Схема перевозки (код) | sods.zle2464m_bp_rawp_ral.scheme';
comment on column dds.transportation_raw_materials_business_plan_position.transport_type_code is 'Тип транспортного средства (код) | Тип транспортного средства (код) | ods.zle2464m_bp_rawp_ral.sdabw';
comment on column dds.transportation_raw_materials_business_plan_position.transport_departure_hub_code is 'Транспортный узел места отправления (код) | Транспортный узел места отправления (код) | ods.zle2464m_bp_rawp_ral.knanf';
comment on column dds.transportation_raw_materials_business_plan_position.transport_destination_hub_code is 'Транспортный узел места назначения (код) | Транспортный узел места назначения (код) | ods.zle2464m_bp_rawp_ral.knend';
comment on column dds.transportation_raw_materials_business_plan_position.vehicle_quantity is 'Количество транспортных средств | Количество транспортных средств | ods.zle2464m_bp_rawp_ral.menge';
