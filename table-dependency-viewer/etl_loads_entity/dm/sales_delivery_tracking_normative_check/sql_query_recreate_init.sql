drop table if exists dm.sales_delivery_tracking_normative_check cascade;

create table if not exists dm.sales_delivery_tracking_normative_check (
	delivery_number_sales varchar(30) null,
	batch varchar(30) null,
	weight_net_with_wirerod numeric(13, 3) null,
	delivery_basis varchar(9) null,
	delivery_point_name varchar(84) null,
	uni varchar(180) null,
	customer_for_reporting_name varchar(450) null,
	delivery_region_code varchar(10) null,
	tsw_location_name varchar(180) null,
	dt_business_location date null,
	dt_shipment date null,
	dt_scenario_start date null,
	dt_shipment_yyyy numeric(4) null,
	business_location_name varchar(50) null,
	port_of_discharge_name varchar(90) null,
	material_code varchar(54) null,
	region_name varchar(20) null, -- delivery_region_name
	time_in_stat numeric(4),
	weighted_average_time_spent_in_the_status numeric(13, 3) null,
	the_amount_of_metal_with_a_normal_shelf_life numeric(13, 3) null,
	the_amount_of_metal_with_an_extended_shelf_life numeric(13, 3) null,
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
	delivery_number_sales,
	batch,
	dt_business_location
);

comment on table dm.sales_delivery_tracking_normative_check is 'Эйджинг. Детальная таблица'; -- Таблица содержит делальные данные по поставкам  в разрезе года и статуса.
comment on column dm.sales_delivery_tracking_normative_check.delivery_number_sales is 'Продажная поставка | Продажная поставка | dm_calc.sd_sales_main_scm.delivery_number_sales';
comment on column dm.sales_delivery_tracking_normative_check.weight_net_with_wirerod is 'Вес Н&K | Вес Н&K | dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
comment on column dm.sales_delivery_tracking_normative_check.delivery_basis is 'Базис поставки | Базис поставки | dm_calc.sd_sales_main_scm.delivery_basis';
comment on column dm.sales_delivery_tracking_normative_check.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс | dm_calc.sd_sales_main_scm.delivery_point_name';
comment on column dm.sales_delivery_tracking_normative_check.uni is 'UNI | UNI | dm_calc.sd_sales_main_scm.uni';
comment on column dm.sales_delivery_tracking_normative_check.customer_for_reporting_name is 'Клиент для отчета Металл в Цепочке Поставок | Клиент для отчета Металл в Цепочке Поставок | dm_calc.sd_sales_main_scm.customer_for_scm_report_name';
comment on column dm.sales_delivery_tracking_normative_check.delivery_region_code is 'Регион поставки по контракту (код) | Регион поставки по контракту (код) | dm_calc.sd_sales_main_scm.delivery_region_code';
comment on column dm.sales_delivery_tracking_normative_check.tsw_location_name is 'Порт погрузки | Порт погрузки | dm_calc.sd_sales_main_scm.port_of_loading_name';
comment on column dm.sales_delivery_tracking_normative_check.dt_business_location is 'Год отгрузки | Год отгрузки | dm_calc.sd_sales_main_scm.dt_shipment';
comment on column dm.sales_delivery_tracking_normative_check.dt_shipment is 'Дата отгрузки | Дата отгрузки | dm_calc.sd_sales_main_scm.dt_shipment';
comment on column dm.sales_delivery_tracking_normative_check.dt_scenario_start is 'Дата начала сценария | Дата начала сценария | dm_calc.sales_delivery_actual_business_location_by_date.dt_business_location';
comment on column dm.sales_delivery_tracking_normative_check.dt_shipment_yyyy is 'Год отгрузки | Год отгрузки | dm_calc.sd_sales_main_scm.dt_shipment';
comment on column dm.sales_delivery_tracking_normative_check.business_location_name is 'Статус среза | Статус среза | dm_calc.sales_delivery_scenario.business_location_name';
comment on column dm.sales_delivery_tracking_normative_check.port_of_discharge_name is 'Порт/Станция выгрузки | Порт/Станция выгрузки | dm_calc.sd_sales_main_scm.port_of_discharge_code';
comment on column dm.sales_delivery_tracking_normative_check.material_code is 'Код материала | Код материала | dm_calc.sd_sales_main_scm.material_code';
comment on column dm.sales_delivery_tracking_normative_check.region_name is 'Название региона | Название региона | dm_calc.sd_sales_main_scm.delivery_region_name';
comment on column dm.sales_delivery_tracking_normative_check.time_in_stat is 'Время нахождения в статусе | Время нахождения в статусе | dm_calc.sales_delivery_actual_business_location_by_date.time_in_stat';
comment on column dm.sales_delivery_tracking_normative_check.weighted_average_time_spent_in_the_status is 'Взвешенное среднее время нахождения в статусе | Взвешенное среднее время нахождения в статусе | average_time_in_status.weighted_average_time_spent_in_the_status';
comment on column dm.sales_delivery_tracking_normative_check.the_amount_of_metal_with_a_normal_shelf_life is 'Количество металла с нормальным сроком хранения | Количество металла с нормальным сроком хранения | sum';
comment on column dm.sales_delivery_tracking_normative_check.the_amount_of_metal_with_an_extended_shelf_life is 'Количество металла с превышенным сроком хранения | Количество металла с превышенным сроком хранения | sum';
