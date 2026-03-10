DROP TABLE IF EXISTS dm.sales_delivery_tracking_domestic CASCADE;

CREATE TABLE dm.sales_delivery_tracking_domestic (
	delivery_number_initial varchar(30) NULL,				-- SD.000001 "Исходная поставка"
	delivery_number_sales varchar(30) NULL,					-- SD.000002 "Продажная поставка"
	delivery_number_of_producer_plant varchar(30) NULL,		-- SD.000003 "Номер поставки завода производителя"
	batch varchar(30) NULL,									-- SD.000004 "Партия"
	sales_order_in_shipment varchar(90) NULL,				-- SD.000005 "Заказ ЦК в отгрузке"
	plant_producer_code varchar(12) NULL,					-- SD.000006 "Завод (код)"
	plant_producer_name varchar(90) NULL,					-- SD.000007 "Завод"
	dt_shipment date NULL,									-- SD.000010 "Дата отгрузки"
	material_aggr_name varchar(210) NULL,					-- SD.000016 "Материал"
	material_group_code varchar(27) NULL,					-- SD.000017 "Группа материалов"
	shipment_market_code varchar(3) NULL,					-- SD.000018 "Рынок в отгрузке (код)"
	shipment_market_name varchar(120) NULL,					-- SD.000019 "Рынок в отгрузке"
	transport_type_at_plant_code varchar(12) NULL,			-- SD.000025 "Тип вагона на заводе (код)"
	transport_type_at_plant_name varchar(120) NULL,			-- SD.000026 "Тип вагона на заводе"
	transport_railcar_type_code varchar(12) NULL,			-- SD.000028 "Тип вагона (код)"
	transport_railcar_type_name varchar(120) NULL,			-- SD.000029 "Тип вагона"
	weight_gross numeric(13, 3) NULL,						-- SD.000031 "Вес брутто"
	weight_net numeric(13, 3) NULL,							-- SD.000032 "Вес нетто"
	weight_net_with_wirerod numeric(13, 3) NULL,			-- SD.000033 "Вес Н&K"
	sales_order varchar(18) NULL,							-- SD.000123 "Заказ ЦК"
	material_code varchar(54) NULL,							-- SD.000143 "Номер материала"
	material_shape_name_full varchar(90) NULL,				-- SD.000180 "Форма"
	material_name varchar(120) NULL,						-- SD.000200 "Наименование материала"
	finish_good_group_code varchar(90) NULL,				-- SD.000257 "Группа продукции"
	warehouse_shipment_type_name varchar(90) NULL,			-- SD.000489 "СВХ"
	dt_shipment_yyyymm varchar(7) NULL,						-- SD.000893 "Месяц Дата отгрузки с завода"
	----------------------------------------------------------------------------------------------------
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT FALSE
)
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED BY (delivery_number_initial, delivery_number_sales, delivery_number_of_producer_plant, batch);


COMMENT ON TABLE dm.sales_delivery_tracking_domestic IS 'Витрина "Внутренний рынок"';
-- SD.000001
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.delivery_number_initial IS 'Исходная поставка |
Исходная (первая) поставка, от которой начинается оформление цепочки продаж.
Источник поступления данных транзакция ZSD2925M - Загрузка данных об отгрузке на трейдерах |
dm_calc.sd_sales_main_scm.delivery_number_initial';
-- SD.000002
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.delivery_number_sales IS 'Продажная поставка |
Если поставка разделена, то деленная поставка, если нет, то Исходная поставка.
Если отгрузка через агента (РТД) - выводится поставка завода производителя |
dm_calc.sd_sales_main_scm.delivery_number_sales';
-- SD.000003
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.delivery_number_of_producer_plant IS 'Номер поставки завода производителя |
Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе |
dm_calc.sd_sales_main_scm.delivery_number_of_producer_plant';
-- SD.000004
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.batch IS 'Партия |
Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков |
dm_calc.sd_sales_main_scm.batch';
-- SD.000005
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.sales_order_in_shipment IS 'Заказ ЦК в отгрузке |
№ заказа центральной компании (заявки) под план производства.
Источник поступления данных транзакция ZSD2925M - Загрузка данных об отгрузке на трейдерах.
Изначально заказы ЦК вносятся в тразакции ZSD2882M-Регистрация заявок клиентов.
Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК |
dm_calc.sd_sales_main_scm.sales_order_in_shipment';
-- SD.000006
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.plant_producer_code IS 'Завод производитель (код) |
Код завода производителя |
dm_calc.sd_sales_main_scm.plant_producer_code';
-- SD.000007
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.plant_producer_name IS 'Завод |
Название завода производителя |
dm_calc.sd_sales_main_scm.plant_producer_name';
-- SD.000010
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.dt_shipment is 'Дата отгрузки |
Дата отгрузки с завода производителя |
dm_calc.sd_sales_main_scm.dt_shipment';
-- SD.000016
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.material_aggr_name IS 'Материал |
Код признака "Материал". Применяется для готовой алюминиевой продукции |
dm_calc.sd_sales_main_scm.material_aggr_name';
-- SD.000017
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.material_group_code IS 'Группа материалов |
Группа материалов. Например, для кода материала APT0006ING0045, код Группа материалов = A02-Алюминий первичный АТЧ, раскисленный |
dm_calc.sd_sales_main_scm.material_group_code';
-- SD.000018
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.shipment_market_code IS 'Рынок в отгрузке (код) |
Код рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) |
dm_calc.sd_sales_main_scm.shipment_market_code';
-- SD.000019
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.shipment_market_name IS 'Рынок в отгрузке |
Название рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) |
dm_calc.sd_sales_main_scm.shipment_market_name';
-- SD.000025
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.transport_type_at_plant_code IS 'Тип вагона на заводе (код) |
Системный код типа вагона, указанный в исходной поставке или графике отгрузке на заводе производителе |
dm_calc.sd_sales_main_scm.transport_type_at_plant_code';
-- SD.000026
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.transport_type_at_plant_name IS 'Тип вагона на заводе |
Название типа вагона, указанный в исходной поставке или графике отгрузке на заводе производителе |
dm_calc.sd_sales_main_scm.transport_type_at_plant_name';
-- SD.000028
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.transport_railcar_type_code IS 'Тип вагона (код) |
Код типа вагона на текущий момент |
dm_calc.sd_sales_main_scm.transport_railcar_type_code';
-- SD.000029
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.transport_railcar_type_name IS 'Тип вагона |
Название типа вагона на текущий момент |
dm_calc.sd_sales_main_scm.transport_railcar_type_name';
-- SD.000031
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.weight_gross IS 'Вес брутто |
Вес брутто |
dm_calc.sd_sales_main_scm.weight_gross';
-- SD.000032
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.weight_net IS 'Вес нетто |
Вес нетто |
dm_calc.sd_sales_main_scm.weight_net';
-- SD.000033
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.weight_net_with_wirerod IS 'Вес Н&K |
Вес нетто + катанки |
dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
-- SD.000123
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.sales_order IS 'Заказ ЦК |
Это системный номер заказа ЦК в отгрузке |
dm_calc.sd_sales_main_scm.sales_order';
-- SD.000143
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.material_code IS 'Код материала |
Системный номер материала. Например, APT0006ING0045. Аналог поля Номер материала |
dm_calc.sd_sales_main_scm.material_code';
-- SD.000180
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.material_shape_name_full is 'Форма |
Форма |
dm_calc.sd_sales_main_scm.material_shape_name_full';
-- SD.000200
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.material_name IS 'Наименование материала |
Наименование материала |
dm_calc.sd_sales_main_scm.material_name';
-- SD.000257
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.finish_good_group_code is 'Группа продукции |
Признак группы материала (ALLOY, PRIMARY и т.п.) |
dm_calc.sd_sales_main_scm.finish_good_group_code';
-- SD.000489
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.warehouse_shipment_type_name IS 'СВХ |
Отображает тип СВХ: "На склад клиенту"; "Со склада клиенту" |
dm_calc.sd_sales_main_scm.warehouse_shipment_type_name';
-- SD.000893
COMMENT ON COLUMN dm.sales_delivery_tracking_domestic.dt_shipment_yyyymm IS 'Месяц Дата отгрузки с завода |
Поле в формате даты год.месяц по полю Дата отгрузки с завода |
dm_calc.sd_sales_main_scm.dt_shipment_yyyymm';