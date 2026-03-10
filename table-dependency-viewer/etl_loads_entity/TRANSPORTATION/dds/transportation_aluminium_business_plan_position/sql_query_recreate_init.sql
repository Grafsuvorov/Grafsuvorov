drop table if exists dds.transportation_aluminium_business_plan_position;

create table dds.transportation_aluminium_business_plan_position (
	dt_business_plan_yyyy varchar(4) null,
	version_code varchar(3) null,
	business_plan_transportation_stage_type_code varchar(2) null,
	position_code varchar(6) null,
	plant_code varchar(4) null,
	is_pickup_at_plant varchar(1) null,
	transport_type_code varchar(4) null,
	transport_departure_hub_at_plant_code varchar(10) null,
	russian_port_code varchar(10) null,
	transport_destination_hub_at_russian_port_code varchar(10) null,
	container_ownership_type_code varchar(2) null,
	repacking_reason_code varchar(2) null,
	container_length_type_code varchar(1) null,
	platform_ownership_type_code varchar(1) null,
	vehicle_quantity numeric(13,0) null,
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
distributed by (transport_type_code, plant_code, transport_departure_hub_at_plant_code, transport_destination_hub_at_russian_port_code, container_ownership_type_code, repacking_reason_code);

comment on table dds.transportation_aluminium_business_plan_position is 'Бизнес-план по транспортировке Готовой продукции: Позиция';
comment on column dds.transportation_aluminium_business_plan_position.dt_business_plan_yyyy is 'Год бизнес-плана | Год бизнес-плана | ods./rusal/bp_schedp_ral.GJAHR';
comment on column dds.transportation_aluminium_business_plan_position.version_code is 'Версия (код) | Версия (код) | ods./rusal/bp_schedp_ral.VERSION';
comment on column dds.transportation_aluminium_business_plan_position.business_plan_transportation_stage_type_code is 'Тип бизнес-плана (по этапу транспортировки) (код) | Тип бизнес-плана (по этапу транспортировки) (код) | ods./rusal/bp_schedp_ral.OPER';
comment on column dds.transportation_aluminium_business_plan_position.position_code is 'Позиция бизнес-плана (код) | Позиция бизнес-плана (код) | ods./rusal/bp_schedp_ral.POSNR';
comment on column dds.transportation_aluminium_business_plan_position.plant_code is 'Завод (код) | Завод (код) | ods./rusal/bp_schedp_ral.WERKS';
comment on column dds.transportation_aluminium_business_plan_position.is_pickup_at_plant is 'Идентификатор: самовывоз (код) | Идентификатор: самовывоз (код) | ods./rusal/bp_schedp_ral.PICKUP';
comment on column dds.transportation_aluminium_business_plan_position.transport_type_code is 'Тип транспортного средства (код) | ГТип транспортного средства (код) | ods./rusal/bp_schedp_ral.SDABW';
comment on column dds.transportation_aluminium_business_plan_position.transport_departure_hub_at_plant_code is 'Cтанция завода (код) | Cтанция завода (код) | ods./rusal/bp_schedp_ral.WERKS_KN';
comment on column dds.transportation_aluminium_business_plan_position.russian_port_code is 'Порт РФ (код) | Порт РФ (код) | ods./rusal/bp_schedp_ral.PORT_FROM';
comment on column dds.transportation_aluminium_business_plan_position.transport_destination_hub_at_russian_port_code is 'Cтанция порта РФ (код) | Cтанция порта РФ (код) | ods./rusal/bp_schedp_ral.PORT_FRKN';
comment on column dds.transportation_aluminium_business_plan_position.container_ownership_type_code is 'Принадлежность контейнера (код) | Принадлежность контейнера (код) | ods./rusal/bp_schedp_ral.ZPR_CONT';
comment on column dds.transportation_aluminium_business_plan_position.repacking_reason_code is 'Причина перетарки (код) | Причина перетарки (код) | ods./rusal/bp_schedp_ral.ZPR_PL';
comment on column dds.transportation_aluminium_business_plan_position.container_length_type_code is 'Футовость контейнера (код) | Футовость контейнера (код) | ods./rusal/bp_schedp_ral.PRDOUBLE';
comment on column dds.transportation_aluminium_business_plan_position.platform_ownership_type_code is 'Принадлежность платформы (код) | Принадлежность платформы (код) | ods./rusal/bp_schedp_ral.ZLENCONT';
comment on column dds.transportation_aluminium_business_plan_position.vehicle_quantity is 'Количество транспортных средств | Количество транспортных средств | ods./rusal/bp_schedp_ral.MENGE_SUM';
