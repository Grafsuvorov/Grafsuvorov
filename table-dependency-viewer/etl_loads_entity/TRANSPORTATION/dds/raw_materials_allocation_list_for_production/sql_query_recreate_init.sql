drop table if exists dds.raw_materials_allocation_list_for_production;

create table dds.raw_materials_allocation_list_for_production (
	material_code varchar(18) null,
	plant_code varchar(4) null,
	dt_purchase_from_yyyymm varchar(6) null,
	dt_purchase_to_yyyymm varchar(6) null,
	weighing_method_for_accounting_code varchar(3) null,
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
distributed by (material_code);

comment on table dds.raw_materials_allocation_list_for_production is 'Разделительная ведомость поставок сырья для обеспечения производства';
comment on column dds.raw_materials_allocation_list_for_production.material_code is 'Материал (код) | Материал (код) | ods."/rusal/otmm_rv_ral".matnr';
comment on column dds.raw_materials_allocation_list_for_production.plant_code is 'Завод (код) | Завод (код) | ods."/rusal/otmm_rv_ral".werks';
comment on column dds.raw_materials_allocation_list_for_production.dt_purchase_from_yyyymm is 'Период закупки с | МПериод закупки с | ods."/rusal/otmm_rv_ral".popers';
comment on column dds.raw_materials_allocation_list_for_production.dt_purchase_to_yyyymm is 'Период закупки по | Период закупки по | ods."/rusal/otmm_rv_ral".poperpo';
comment on column dds.raw_materials_allocation_list_for_production.weighing_method_for_accounting_code is 'Способ учета веса (код) | Способ учета веса (код) | ods."/rusal/otmm_rv_ral".id_ves';
