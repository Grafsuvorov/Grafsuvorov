drop table if exists dm.sales_delivery_estimated_business_location_by_date cascade;

create table if not exists dm.sales_delivery_estimated_business_location_by_date (
    sales_delivery_code varchar null,
    batch varchar null,
    shipment_market_code varchar null,
    business_location_name varchar null,
    dt_business_location date null,
    plan_or_actual_code varchar null,
    tsw_location_name varchar null,
    weight_net_with_wirerod numeric(13, 3) null,
    port_of_discharge_name varchar null,
    delivery_basis varchar null,
    delivery_point_name varchar null,
    uni varchar null,
    material_code varchar null,
    material_aggr_name varchar null,
    delivery_region_name varchar null,
    transportation_scenario_code varchar null,
    customer_for_scm_report_name varchar null,
    material_group_for_scm_report_name varchar null,
    sales_team_name varchar null,
    dt_shipment_actual varchar null,
    customer_name varchar null,
    contract_name varchar null,
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
distributed by (sales_delivery_code, batch);

comment on table dm.sales_delivery_estimated_business_location_by_date is 'Прогнозные даты и статусы поставки';
comment on column dm.sales_delivery_estimated_business_location_by_date.sales_delivery_code is 'Поставка среза | Продажная поставка, по которой сохраняется срез статуса | dm_calc.sales_delivery_scenario.delivery_number_sales';
comment on column dm.sales_delivery_estimated_business_location_by_date.batch is 'Сценарий маршрута | Сценарий маршрута | dm_calc.sales_delivery_scenario.transportation_scenario_code';
comment on column dm.sales_delivery_estimated_business_location_by_date.shipment_market_code is 'Сценарий маршрута | Сценарий маршрута | dm_calc.sales_delivery_scenario.transportation_scenario_code';
comment on column dm.sales_delivery_estimated_business_location_by_date.business_location_name is 'Статус среза | Расчитывается по дате в столбце "План КХД" | dm_calc.sales_delivery_scenario.business_location_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.dt_business_location is 'Дата среза | Дата среза по которой будут собираться данные в отчет | dm_calc.sales_delivery_scenario.dt_business_location';
comment on column dm.sales_delivery_estimated_business_location_by_date.plan_or_actual_code is 'Источник данных среза План/Факт | Признак того, на основании фактических (F) или плановых (P) данных рассчитан статус среза | dm_calc.sales_delivery_scenario.plan_or_actual_code';
comment on column dm.sales_delivery_estimated_business_location_by_date.tsw_location_name is 'Порт погрузки | Название порта погрузки. Например, ZARUBINO | dm_calc.sd_sales_main_scm.tsw_location_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.weight_net_with_wirerod is 'Вес Н&K | Вес нетто + катанки | dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
comment on column dm.sales_delivery_estimated_business_location_by_date.port_of_discharge_name is 'Порт выгрузки | Порт выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, BUSAN | dm_calc.sd_sales_main_scm.port_of_discharge_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.delivery_basis is 'Базис поставки | Базис поставки (Инкотермс 1), это правило поставки Инкотермс.  Базис обозначается тремя латинскими буквами, например EXW, CIP, DAP и пр. Инфо берем из клиентского лота, ели его нет то из заявки под план производства | dm_calc.sd_sales_main_scm.delivery_basis';
comment on column dm.sales_delivery_estimated_business_location_by_date.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс (Инкотермс 2), это место передачи груза, это может быть город, аэропорт, морской либо речной порт.  Инфо берем из клиентского лота, ели его нет то из заявки под план производства | dm_calc.sd_sales_main_scm.delivery_point_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.uni is 'UNI | Если Причина деления постави = ""4- Перевеска"", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки; Иначе: Накладная + Вагон | dm_calc.sd_sales_main_scm.uni';
comment on column dm.sales_delivery_estimated_business_location_by_date.material_code is 'Код материала | Системный номер материала. Например, APT0006ING0045. Аналог поля  Номер материала | dm_calc.sd_sales_main_scm.material_code';
comment on column dm.sales_delivery_estimated_business_location_by_date.material_aggr_name is 'Код материала | Системный номер материала. Например, APT0006ING0045. Аналог поля  Номер материала | dm_calc.sd_sales_main_scm.material_code';
comment on column dm.sales_delivery_estimated_business_location_by_date.delivery_region_name is 'Регион доставки | Название региона доставки | dm_calc.sd_sales_main_scm.delivery_region_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.transportation_scenario_code is 'Сценарий маршрута | Код сценария маршрута, который определяет тип маршрута и способ доставки | dm_calc.sd_sales_main_scm.transportation_scenario_code';
comment on column dm.sales_delivery_estimated_business_location_by_date.customer_for_scm_report_name is 'Покупатель для отчета SCM | Название покупателя для отчета SCM | dm_calc.sd_sales_main_scm.customer_for_scm_report_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.material_group_for_scm_report_name is 'Группа материалов для отчета SCM | Название группы материалов для отчета SCM | dm_calc.sd_sales_main_scm.material_group_for_scm_report_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.sales_team_name is 'Сбытовая команда | Наименование сбытовой команды | dm_calc.sd_sales_main_scm.sales_team_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.dt_shipment_actual is 'Дата фактической отгрузки | Фактическая дата отгрузки | dm_calc.sd_sales_main_scm.dt_shipment_actual';
comment on column dm.sales_delivery_estimated_business_location_by_date.customer_name is 'Название клиента | Название клиента | dm_calc.sd_sales_main_scm.customer_name';
comment on column dm.sales_delivery_estimated_business_location_by_date.contract_name is 'Название контракта | Название контракта | dm_calc.sd_sales_main_scm.contract_name';
