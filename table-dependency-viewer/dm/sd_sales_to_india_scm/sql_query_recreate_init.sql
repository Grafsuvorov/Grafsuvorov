DROP TABLE IF EXISTS dm.sd_sales_to_india_scm cascade;

CREATE TABLE dm.sd_sales_to_india_scm (
	delivery_number_sales varchar(10) NULL,									-- SD.000002 "Продажная поставка"
	plant_producer_name varchar(30) NULL,									-- SD.000007 "Завод"
	port_of_loading_code varchar(10) NULL,									-- SD.000008 "Направление (код)"
	dt_shipment date NULL,													-- SD.000010 "Дата отгрузки"
	material_aggr_name varchar(70) NULL,									-- SD.000016 "Материал"
	weight_net numeric(13, 3) NULL,											-- SD.000032 "Вес нетто"
	customer_for_reporting_name varchar(150) NULL,							-- SD.000037 "Покупатель"
	contract_name varchar(105) NULL,										-- SD.000038 "Контракт"
	bill_of_lading_number varchar(30) NULL,									-- SD.000041 "Номер коносамента"
	dimensions_unit varchar(20) NULL,										-- SD.000079 "Размер единицы готовой продукции"
	material_specification_name varchar(50) NULL,							-- SD.000089 "Спецификация"
	sales_order varchar(18) NULL,											-- SD.000123 "Заказ ЦК"
	customer_grade_name varchar(30) NULL,									-- SD.000144 "Марка клиента"
	end_user_name varchar(140) NULL,										-- SD.000164 "Конечный потребитель"
	invoice_provisional_number varchar(30) NULL,							-- SD.000167 "Инвойс (счет клиенту)"
	material_shape_name_full varchar(30) NULL,								-- SD.000180 "Форма"
	port_of_destination_name varchar(30) NULL,								-- SD.000376 "Порт назначения"
	country_of_customer_name varchar(15) NULL,								-- SD.000644 "Страна покупателя"
	port_of_destination_code varchar(30) NULL,								-- SD.000645 "Порт назначения (код)"
	dt_port_of_destination_arrival date NULL,								-- SD.000659 "Дата прибытия в порт назначения"
	bis_license_number varchar(30) NULL,									-- SD.000729 "№ лицензии BIS"
	postal_code_of_buyer_code varchar(10) NULL,								-- SD.000730 "Почтовый индекс покупателя"
	bill_of_lading_in_delivery_country_code varchar(10) NULL,				-- SD.001054 "Группа коносамента страны поставки"
	bill_of_lading_in_delivery_country_number varchar(30) NULL,				-- SD.001055 "Коносамент страны поставки"
	dt_bill_of_lading_in_delivery_country date NULL, 						-- SD.001056 "Дата коносамента страны поставки"
	dt_vessel_arrived_to_delivery_country date NULL,						-- SD.001057 "Дата прихода в порт выгрузки страны поставки"
	bill_of_lading_in_delivery_country_nomination_code	varchar(20) NULL,	-- SD.001058 "Номинация коносамента в страну поставки"
	vessel_in_delivery_country_actual_code varchar(10) NULL,				-- SD.001059 "Судно факт страны поставки (код)"
	vessel_in_delivery_country_actual_name varchar(40) NULL,				-- SD.001060 "Судно факт страны поставки"
    dttm_inserted timestamp NOT NULL DEFAULT now(),
    dttm_updated timestamp NOT NULL DEFAULT now(),
    job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
    deleted_flag bool NOT NULL DEFAULT FALSE
)
WITH (
    appendonly=TRUE,
    orientation=COLUMN,
    compresstype=zstd,
    compresslevel=3
)

DISTRIBUTED BY (
    delivery_number_sales
);

COMMENT ON TABLE dm.sd_sales_to_india_scm IS 'Отгрузка ГП с лицензией BIS';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.delivery_number_sales IS 'Продажная поставка | Продажная поставка | dm_calc.sd_sales_main_scm.delivery_number_sales';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.plant_producer_name IS 'Завод | Название завода производителя | dm_calc.sd_sales_main_scm.plant_producer_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.port_of_loading_code IS 'Направление (код) | Код направления погрузки. Например, RTI-ZARUBI. Например, RTI-ZARUBI | dm_calc.sd_sales_main_scm.tsw_location_code';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.dt_shipment IS 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sd_sales_main_scm.dt_shipment';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.material_aggr_name IS 'Материал | Материал | dm_calc.sd_sales_main_scm.material_aggr_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.weight_net IS 'Вес нетто | Вес нетто | dm_calc.sd_sales_main_scm.weight_net';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.customer_for_reporting_name IS 'Покупатель | Покупатель | dm_calc.sd_sales_main_scm.customer_for_reporting_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.contract_name is 'Контракт | Номер контракта из клиентского лота, если его нет, то "Плановый контракт" из заявки под план производства | dm_calc.sd_sales_main_scm.contract_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.bill_of_lading_number IS 'Номер коносамента | Номер коносамента | dm_calc.sd_sales_main_scm.bill_of_lading_number';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.dimensions_unit IS 'Размер единицы готовой продукции | Размер единицы готовой продукции | dm_calc.sd_sales_main_scm.dimensions_unit';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.material_specification_name IS 'Спецификация | Спецификация | dm_calc.sd_sales_main_scm.material_specification_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.sales_order IS 'Заказ ЦК | Это системный номер заказа ЦК в отгрузке | dm_calc.sd_sales_main_scm.sales_order';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.customer_grade_name IS 'Марка клиента | Марка клиента | dm_calc.sd_sales_main_scm.customer_grade_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.end_user_name IS 'Конечный потребитель | Имя контрагента, который является потребителем металла, т.е. будет использовальзовать метал для производства своей продукции, т.е. для собственных нужд. В одной сделке Потребитель и Конечный потребитель могут быть разные юр.лица, а может быть одно | dm_calc.sd_sales_main_scm.end_user_for_reporting_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.invoice_provisional_number IS 'Provisional invoice | Инвойс (счет клиенту) | dm_calc.sd_sales_main_scm.invoice_provisional_number';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.material_shape_name_full IS 'Форма | Форма | dm_calc.sd_sales_main_scm.material_shape_name_full';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.port_of_destination_name IS 'Порт назначения | Порт назначения | dm_calc.sd_sales_main_scm.port_of_destination_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.country_of_customer_name IS 'Страна покупателя | Страна покупателя | dm_calc.sd_sales_main_scm.country_of_customer_name';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.port_of_destination_code IS 'Порт назначения (код) | Порт назначения (код) | dm_calc.sd_sales_main_scm.port_of_destination_code';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.dt_port_of_destination_arrival IS 'Дата прибытия в порт назначения) | Дата прибытия в порт назначения | dm_calc.sd_sales_main_scm.dt_port_of_destination_arrival';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.bis_license_number IS '№ лицензии BIS | Лицензия BIS для поставок в Индию | dm_calc.sd_sales_main_scm.bis_license_number';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.postal_code_of_buyer_code IS 'Почтовый индекс покупателя | Почтовый индекс адреса покупателя | dm_calc.sd_sales_main_scm.postal_code_of_buyer_code';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.bill_of_lading_in_delivery_country_code IS 'Группа коносамента страны поставки | Дата коносамента в страну поставки.= SD.000040  "Группа коносамента", если = SD.000340 Страна POD (код) = SD.000577 "Страна поставки по контракту (код)" Иначе "Группа коносамента в ин.порту" SD.000047, если = SD.000768 "Страна порт выгрузки 2 (код)" = SD.000577 "Страна поставки по контракту (код)" Иначе = пусто | Расчётное';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.bill_of_lading_in_delivery_country_number IS 'Коносамент страны поставки | Системный номер коносамента в страну поставки | dds.bill_of_lading.bill_of_lading_number';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.dt_bill_of_lading_in_delivery_country IS 'Дата коносамента страны поставки | Номер коносамента в страну поставки | dds.bill_of_lading.dt_bill_of_lading';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.dt_vessel_arrived_to_delivery_country IS 'Дата прихода в порт выгрузки страны поставки | Дата прихода в порт выгрузки страны поставки | dds.bill_of_lading.dt_vessel_arrival_to_destination_port';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.bill_of_lading_in_delivery_country_nomination_code IS 'Номинация коносамента в страну поставки | Номинация коносамента в страну поставки | dds.bill_of_lading.nomination_code';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.vessel_in_delivery_country_actual_code IS 'Судно факт страны поставки (код) | Номер судна из номинации коносамента в страну поставки | dds.nomination.vessel_code';
COMMENT ON COLUMN dm.sd_sales_to_india_scm.vessel_in_delivery_country_actual_name IS 'Судно факт страны поставки | Название судна в страну поставки | dict_dds.transport_vehicle_texts.vessel_name';
