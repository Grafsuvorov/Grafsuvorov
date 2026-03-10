drop table if exists dm.sales_carbon_footprint_by_delivery cascade;

create table dm.sales_carbon_footprint_by_delivery
(
sales_delivery_code varchar (10) null,
plant_name varchar (30) null,
dt_shipment date,
weight_net numeric (13,3),
weight_net_with_wirerod numeric (13,3),
contract_name varchar (105) null,
lot_delivery_basis_code varchar (9) null ,
lot_delivery_point_name varchar (104) null,
uni varchar (180) null,
invoice_provisional_number varchar (90) null,
customer_code varchar (30) null,
customer_name varchar (450) null,
melt_name varchar (12) null, 
melt_weight  numeric (10,5) null, 
melt_carbon_emission_weight numeric (17,5) null,
delivery_carbon_emission_weight numeric (17,5) null,
delivery_carbon_emission_per_ton_weight numeric (10,5) null,
bundle_by_delivery_and_melt_total_weight numeric (17,5) null,
carbon_emission_equivalent_scope1_per_ton_melt_weight numeric (17,5) null,
carbon_emission_equivalent_scope2_per_ton_melt_weight numeric (17,5) null,
carbon_emission_equivalent_scope3_per_ton_melt_weight numeric (17,5) null,
carbon_emission_equivalent_scope1_per_ton_delivery_weight numeric (17,5) null,
carbon_emission_equivalent_scope2_per_ton_delivery_weight numeric (17,5) null,
carbon_emission_equivalent_scope3_per_ton_delivery_weight numeric (17,5) null,
dt_invoice_provisional date null,
dt_invoice_provisional_mmyyyy varchar(7) null,
invoice_provisional_code varchar(10) null,
vat_invoice_of_invoice_provisional_code varchar(10) null,
"dttm_inserted" timestamp not null default now(),
"dttm_updated" timestamp not null default now(),
"job_name" varchar(60) not null default 'airflow'::character varying,
"deleted_flag" bool not null default false
)
with (
appendonly=true,
orientation=column,
compresstype=zstd,
compresslevel=3
)
distributed by (sales_delivery_code);


comment on table dm.sales_carbon_footprint_by_delivery is 'Углеродный след в разрезе поставок сбыта';
comment on column dm.sales_carbon_footprint_by_delivery."sales_delivery_code" is 'Поставка (код) | Поставка (код) | dm_calc.sd_sales_main_scm.delivery_number_sales';
comment on column dm.sales_carbon_footprint_by_delivery."melt_name" is 'Номер плавки | Номер плавки | dm_calc.carbon_footprint_by_bundle_sd0010.melt_name';
comment on column dm.sales_carbon_footprint_by_delivery."melt_weight" is 'Вес производства по плавке тн | Вес производства по плавке тн | dm_calc.carbon_footprint_by_bundle_sd0010.sum_production_bundle_net_weight';
comment on column dm.sales_carbon_footprint_by_delivery."plant_name" is 'Наименование завода | Наименование завода  | dm_calc.sd_sales_main_scm.plant_producer_name';
comment on column dm.sales_carbon_footprint_by_delivery."dt_shipment" is 'Дата отгрузки | Дата отгрузки | dm_calc.sd_sales_main_scm.dt_shipment';
comment on column dm.sales_carbon_footprint_by_delivery."weight_net" is 'Вес нетто | Вес нетто | dm_calc.sd_sales_main_scm.weight_net';
comment on column dm.sales_carbon_footprint_by_delivery."weight_net_with_wirerod" is 'Вес Н&K | Вес Н&K | dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
comment on column dm.sales_carbon_footprint_by_delivery."contract_name" is 'Контракт | Контракт  | dm_calc.sd_sales_main_scm.contract_name';
comment on column dm.sales_carbon_footprint_by_delivery."dt_shipment" is 'Дата отгрузки | Дата отгрузки | dm_calc.sd_sales_main_scm.dt_shipment';
comment on column dm.sales_carbon_footprint_by_delivery."lot_delivery_basis_code" is 'Базис поставки в лоте | Базис поставки в лоте | dm_calc.sd_sales_main_scm.lot_delivery_basis_code';
comment on column dm.sales_carbon_footprint_by_delivery."lot_delivery_point_name" is 'Пункт доставки по инкотермс в лоте | Пункт доставки по инкотермс в лоте | dm_calc.sd_sales_main_scm.lot_delivery_point_name';
comment on column dm.sales_carbon_footprint_by_delivery."uni" is 'UNI | UNI | dm_calc.sd_sales_main_scm.uni';
comment on column dm.sales_carbon_footprint_by_delivery."invoice_provisional_number" is 'Provisional invoice | Provisional invoice  | dm_calc.sd_sales_main_scm.invoice_provisional_number';
comment on column dm.sales_carbon_footprint_by_delivery."customer_code" is 'Покупатель (код) | Покупатель (код)  | dm_calc.sd_sales_main_scm.customer_for_reporting_code';
comment on column dm.sales_carbon_footprint_by_delivery."customer_name" is 'Наименование покупателя | Наименование покупателя | dm_calc.sd_sales_main_scm.customer_for_reporting_name';
comment on column dm.sales_carbon_footprint_by_delivery."lot_delivery_point_name" is 'Пункт доставки по инкотермс в лоте | Пункт доставки по инкотермс в лоте | dm_calc.sd_sales_main_scm.lot_delivery_point_name';
comment on column dm.sales_carbon_footprint_by_delivery."delivery_carbon_emission_weight" is 'Объем выброса CO2 вал. FullScope поставки | Объем выброса  CO2 вал. FullScope поставки | dds.delivery_document_header.carbon_emission_full_scope_weight';
comment on column dm.sales_carbon_footprint_by_delivery."delivery_carbon_emission_per_ton_weight" is 'Объем выброса CO2 уд. FullScope поставки | Объем выброса CO2 уд. FullScope поставки | dm.sales_carbon_footprint_by_bundle.delivery_carbon_emission_per_ton_weight';
comment on column dm.sales_carbon_footprint_by_delivery."melt_carbon_emission_weight" is 'CO2 уд. FullScope плавки | CO2 уд. FullScope плавки |  dm_calc.carbon_footprint_by_melt_sd0015.carbon_emission_equivalent_per_ton_weight';
comment on column dm.sales_carbon_footprint_by_delivery."bundle_by_delivery_and_melt_total_weight" is 'Вес реализации по плавке | Вес реализации по плавке | dm_calc.carbon_footprint_by_bundle.carbon_emission_equivalent_per_ton_weight';
comment on column dm.sales_carbon_footprint_by_delivery."carbon_emission_equivalent_scope1_per_ton_melt_weight" is 'CO2 уд. Scope1 плавки | CO2 уд. Scope1 плавки | dds.delivery_document_header.carbon_emission_equivalent_per_ton_weight';
comment on column dm.sales_carbon_footprint_by_delivery."dt_invoice_provisional_mmyyyy" is 'Месяц предварительного инвойса | Месяц предварительного инвойса | dm_calc.sd_sales_main_scm.dt_invoice_provisional_mmyyyy';
comment on column dm.sales_carbon_footprint_by_delivery."invoice_provisional_code" is 'Группа инвойса | Группа инвойса | dm_calc.sd_sales_main_scm.invoice_provisional_code';
comment on column dm.sales_carbon_footprint_by_delivery."vat_invoice_of_invoice_provisional_code" is 'Фактура предварительного инвойса (код) | Фактура предварительного инвойса (код) | dm_calc.sd_sales_main_scm.vat_invoice_of_invoice_provisional_code';
comment on column dm.sales_carbon_footprint_by_delivery."dt_invoice_provisional" is 'Дата предварительного инвойса | Дата предварительного инвойса | dm_calc.sd_sales_main_scm.dt_invoice_provisional';

