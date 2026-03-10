CREATE OR REPLACE VIEW dm_view.production_aluminium_casting_schedule
AS SELECT
	dm.production_aluminium_casting_schedule.plant_name,
	dm.production_aluminium_casting_schedule.plant_code,
	dm.production_aluminium_casting_schedule.casting_department_name,
	dm.production_aluminium_casting_schedule.casting_department_code,
	dm.production_aluminium_casting_schedule.casting_unit_name,
	dm.production_aluminium_casting_schedule.casting_unit_code,
	dm.production_aluminium_casting_schedule.sales_request_code,
	dm.production_aluminium_casting_schedule.sales_request_type_code,
	dm.production_aluminium_casting_schedule.dt_casting_plan_start,
	dm.production_aluminium_casting_schedule.dt_casting_plan_end,
	dm.production_aluminium_casting_schedule.dt_warehouse_acceptance_plan_start,
	dm.production_aluminium_casting_schedule.dt_warehouse_acceptance_plan_end,
	dm.production_aluminium_casting_schedule.sales_request_raw_metal_total_weight,
	dm.production_aluminium_casting_schedule.sales_request_raw_metal_current_month_weight,
	dm.production_aluminium_casting_schedule.accepted_plan_weight,
	dm.production_aluminium_casting_schedule.data_type_name,
	dm.production_aluminium_casting_schedule.shape_for_reporting_name,
	dm.production_aluminium_casting_schedule.dt_report,
	dm.production_aluminium_casting_schedule.version_code,
	dm.production_aluminium_casting_schedule.sales_request_status_code,
	dm.production_aluminium_casting_schedule.status_updated_by,
	dm.production_aluminium_casting_schedule.dt_status_updated,
	dm.production_aluminium_casting_schedule.load_dt
FROM dm.production_aluminium_casting_schedule;

comment on view dm_view.production_aluminium_casting_schedule IS 'MISHKA|График литья';
comment on column dm_view.production_aluminium_casting_schedule.plant_name IS 'Название завода|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.plant_code IS 'Код завода|SAP(RAL) код завода|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.casting_department_name IS 'Название литейного отделения|Название литейного отделения, в котором находится литейный агрегат|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.casting_department_code IS 'Код литейного отделения|Код литейного отделения, в котором находится литейный агрегат|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.casting_unit_name IS 'Название литейного агрегата|Название литейного агрегата|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.casting_unit_code IS 'Код литейного агрегата|Код литейного агрегата|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.sales_request_code IS 'Номер заказа ЦК|SAP(RAL) Номер заказа ЦК|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.sales_request_type_code IS 'Тип заказа|SAP(RAL) тип заказа ЦК|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.dt_casting_plan_start IS 'Плановая дата начала первой ходки|Плановая дата начала первой ходки|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.dt_casting_plan_end IS 'Плановая дата окончания последней ходки|Плановая дата окончания последней ходки|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.dt_warehouse_acceptance_plan_start IS 'Плановая дата передачи на СГП первой ходки|Плановая дата передачи на СГП первой ходки|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.dt_warehouse_acceptance_plan_end IS 'Плановая дата передачи на СГП последней ходки|Плановая дата передачи на СГП последней ходки|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.sales_request_raw_metal_total_weight IS 'Вес ходок по заказу|Вес ходок по заказу|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.sales_request_raw_metal_current_month_weight IS 'Вес ходок за месяц|Вес ходок за месяц|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.accepted_plan_weight IS 'Принято в план|Принято в план|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.data_type_name IS 'Состояние в графике|Состояние в плане|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.shape_for_reporting_name IS 'Продукт|Обозначение продукта|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.dt_report IS 'Плановый месяц|Первое число планового месяца|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.version_code IS 'Версия графика|Версия плана|MISHKA';
comment on column dm_view.production_aluminium_casting_schedule.sales_request_status_code IS 'Статус заказа ЦК|Код актуального статуса заказа, SAP(RAL)|ods.cdpos_ral.value_new';
comment on column dm_view.production_aluminium_casting_schedule.status_updated_by IS 'Установил статус|Учетная запись пользователя, установившего статус, SAP(RAL)|ods.cdhdr_ral.username';
comment on column dm_view.production_aluminium_casting_schedule.dt_status_updated IS 'Дата установки статуса|Дата и время установки последжнего статуса, SAP(RAL)|ods.cdhdr_ral.udate и ods.cdhdr_ral.utime';
comment on column dm_view.production_aluminium_casting_schedule.load_dt IS 'Дата и время загрузки строки|Дата и время записи строки в БД|Автоматически';