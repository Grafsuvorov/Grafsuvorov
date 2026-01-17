drop table if exists dm.production_aluminium_casting_schedule cascade;

create table dm.production_aluminium_casting_schedule
(
    plant_name text null,
    plant_code varchar(12) not null,
    casting_department_name text null,
    casting_department_code varchar(12) null,
    casting_unit_name text null,
    casting_unit_code varchar(12) null,
    sales_request_code varchar(36) not null,
    sales_request_type_code varchar(50) null,
    dt_casting_plan_start timestamp null,
    dt_casting_plan_end timestamp null,
    dt_warehouse_acceptance_plan_start timestamp null,
    dt_warehouse_acceptance_plan_end timestamp null,
    sales_request_raw_metal_total_weight numeric(15, 5) null,
    sales_request_raw_metal_current_month_weight numeric(15, 5) null,
    accepted_plan_weight numeric(15, 5) null,
    acceprted_plan_weight numeric(15, 5) null,
    data_type_name text null,
    shape_for_reporting_name varchar(50) null,
    dt_report date not null,
    version_code varchar(6) not null,
    sales_request_status_code varchar(36) null,
    status_updated_by varchar(36) null,
    dt_status_updated timestamp null,
    load_dt timestamp default now(),
    dttm_inserted 										timestamp not null default now(),
    dttm_updated 										timestamp not null default now(),
    job_name 											varchar(60) not null default 'airflow'::character varying,
    deleted_flag										bool not null default false
)
WITH 
(
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by ("plant_code", "sales_request_code");

comment on table dm.production_aluminium_casting_schedule IS 'MISHKA|График литья';
comment on column dm.production_aluminium_casting_schedule.plant_name IS 'Название завода|MISHKA';
comment on column dm.production_aluminium_casting_schedule.plant_code IS 'Код завода|SAP(RAL) код завода|MISHKA';
comment on column dm.production_aluminium_casting_schedule.casting_department_name IS 'Название литейного отделения|Название литейного отделения, в котором находится литейный агрегат|MISHKA';
comment on column dm.production_aluminium_casting_schedule.casting_department_code IS 'Код литейного отделения|Код литейного отделения, в котором находится литейный агрегат|MISHKA';
comment on column dm.production_aluminium_casting_schedule.casting_unit_name IS 'Название литейного агрегата|Название литейного агрегата|MISHKA';
comment on column dm.production_aluminium_casting_schedule.casting_unit_code IS 'Код литейного агрегата|Код литейного агрегата|MISHKA';
comment on column dm.production_aluminium_casting_schedule.sales_request_code IS 'Номер заказа ЦК|SAP(RAL) Номер заказа ЦК|MISHKA';
comment on column dm.production_aluminium_casting_schedule.sales_request_type_code IS 'Тип заказа|SAP(RAL) тип заказа ЦК|MISHKA';
comment on column dm.production_aluminium_casting_schedule.dt_casting_plan_start IS 'Плановая дата начала первой ходки|Плановая дата начала первой ходки|MISHKA';
comment on column dm.production_aluminium_casting_schedule.dt_casting_plan_end IS 'Плановая дата окончания последней ходки|Плановая дата окончания последней ходки|MISHKA';
comment on column dm.production_aluminium_casting_schedule.dt_warehouse_acceptance_plan_start IS 'Плановая дата передачи на СГП первой ходки|Плановая дата передачи на СГП первой ходки|MISHKA';
comment on column dm.production_aluminium_casting_schedule.dt_warehouse_acceptance_plan_end IS 'Плановая дата передачи на СГП последней ходки|Плановая дата передачи на СГП последней ходки|MISHKA';
comment on column dm.production_aluminium_casting_schedule.sales_request_raw_metal_total_weight IS 'Вес ходок по заказу|Вес ходок по заказу|MISHKA';
comment on column dm.production_aluminium_casting_schedule.sales_request_raw_metal_current_month_weight IS 'Вес ходок за месяц|Вес ходок за месяц|MISHKA';
comment on column dm.production_aluminium_casting_schedule.accepted_plan_weight IS 'Принято в план|Принято в план|MISHKA';
comment on column dm.production_aluminium_casting_schedule.data_type_name IS 'Состояние в графике|Состояние в плане|MISHKA';
comment on column dm.production_aluminium_casting_schedule.shape_for_reporting_name IS 'Продукт|Обозначение продукта|MISHKA';
comment on column dm.production_aluminium_casting_schedule.dt_report IS 'Плановый месяц|Первое число планового месяца|MISHKA';
comment on column dm.production_aluminium_casting_schedule.version_code IS 'Версия графика|Версия плана|MISHKA';
comment on column dm.production_aluminium_casting_schedule.sales_request_status_code IS 'Статус заказа ЦК|Код актуального статуса заказа, SAP(RAL)|ods.cdpos_ral.value_new';
comment on column dm.production_aluminium_casting_schedule.status_updated_by IS 'Установил статус|Учетная запись пользователя, установившего статус, SAP(RAL)|ods.cdhdr_ral.username';
comment on column dm.production_aluminium_casting_schedule.dt_status_updated IS 'Дата установки статуса|Дата и время установки последжнего статуса, SAP(RAL)|ods.cdhdr_ral.udate и ods.cdhdr_ral.utime';
comment on column dm.production_aluminium_casting_schedule.load_dt IS 'Дата и время загрузки строки|Дата и время записи строки в БД|Автоматически';