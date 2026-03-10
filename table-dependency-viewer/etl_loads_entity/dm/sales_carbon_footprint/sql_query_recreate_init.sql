drop table dm.sales_carbon_footprint cascade;

create table dm.sales_carbon_footprint
(sales_delivery_code varchar (10) null,
carbon_emission_weight numeric (17,5)null,
carbon_emission_equivalent_scope1_per_ton_total_weight numeric (17,5) null,
carbon_emission_equivalent_scope2_per_ton_total_weight numeric (17,5) null,
carbon_emission_equivalent_scope3_per_ton_total_weight numeric (17,5) null,
carbon_emission_equivalent_full_scope_per_ton_total_weight numeric (17,5) null,
dt_carbon_emisson_calculated date,
"dttm_inserted" timestamp not null default now(),
"dttm_updated" timestamp not null default now(),
"job_name" varchar(60) not null default 'airflow'::character varying,
"deleted_flag" bool not null default false
)
with (
appendonly=true,
orientation=column,
compresstype=zstd,
compresslevel=1
)
distributed by (sales_delivery_code);

comment on table dm.sales_carbon_footprint is 'Углеродный след в разрезе поставок сбыта';
comment on column dm.sales_carbon_footprint."sales_delivery_code" is 'Поставка (код) | Поставка (код) | dm_calc.carbon_footprint_by_bundle.sales_delivery_code';
comment on column dm.sales_carbon_footprint."carbon_emission_weight" is 'CO2 вал. FullScope поставки | CO2 вал. FullScope поставки | dm_calc.carbon_footprint_by_melt_sd0015.carbon_emission_equivalent_full_scope_per_ton_total_weight';
comment on column dm.sales_carbon_footprint."carbon_emission_equivalent_scope1_per_ton_total_weight" is 'Удельный объем выброса СО2 Scope1 | Сумма удельных объемов выброса СО2 Scope1  по всем плавкам этой поставки.  Где объем выброса СО2 FullScope для плавки равен произведению удельного показателя выброса плавки на вес объема реализации плавки. | dm_calc.carbon_footprint_by_melt_sd0015.carbon_emission_equivalent_full_scope_per_ton_total_weight';
comment on column dm.sales_carbon_footprint."carbon_emission_equivalent_scope2_per_ton_total_weight" is 'Удельный объем выброса СО2 Scope2 | Сумма удельных объемов выброса СО2 Scope2  по всем плавкам этой поставки.  Где объем выброса СО2 FullScope для плавки равен произведению удельного показателя выброса плавки на вес объема реализации плавки. | dm_calc.carbon_footprint_by_melt_sd0015.carbon_emission_equivalent_full_scope_per_ton_total_weight';
comment on column dm.sales_carbon_footprint."carbon_emission_equivalent_scope3_per_ton_total_weight" is 'Удельный объем выброса СО2 Scope3 | Сумма удельных объемов выброса СО2 Scope3  по всем плавкам этой поставки.  Где объем выброса СО2 FullScope для плавки равен произведению удельного показателя выброса плавки на вес объема реализации плавки. | dm_calc.carbon_footprint_by_melt_sd0015.carbon_emission_equivalent_full_scope_per_ton_total_weight';
comment on column dm.sales_carbon_footprint."carbon_emission_equivalent_full_scope_per_ton_total_weight" is 'Удельный объем выброса СО2 FullScope | Сумма удельных объемов выброса СО2 Scope1, Scope2 и Scope3  по всем плавкам этой поставки.  | dm_calc.carbon_footprint_by_melt_sd0015.carbon_emission_equivalent_full_scope_per_ton_total_weight';
