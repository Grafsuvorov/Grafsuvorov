drop table if exists dm.sales_forwarder_metal_acceptance_delays cascade;
create table dm.sales_forwarder_metal_acceptance_delays (
	 delivery_number_initial varchar null 								--SD.000001 | Исходная поставка
	,plant_producer_code varchar null 									--SD.000006 | Завод производитель (код)
	,plant_producer_name varchar null 									--SD.000007 | Завод							--2025.11.14 добавляю
	,port_of_loading_code varchar null									--SD.000008 | Направление (код) 			--2025.11.06 добавляю
	,dt_arrival_by_railway date null 									--SD.000011 | Дата прибытия по ЖД
	,dt_forwarder date null 											--SD.000012 | Дата экспедитора
	,railcar varchar null 												--SD.000013 | Вагон
	,transport_bill varchar null 										--SD.000014 | Накладная
	,railway_platform varchar null 										--SD.000015 | Платформа
	,forwarder_name varchar null 										--SD.000021 | Экспедитор
	,port_of_discharge_name varchar null 								--SD.000045 | Порт выгрузки
	,route_type varchar null 											--SD.000069 | Тип маршрута
	,route_plant_code varchar null 										--SD.000118 | Маршрут завода
	,sales_order varchar null 											--SD.000123 | Заказ ЦК
	,uni varchar null 													--SD.000151 | UNI
	,port_of_destination_code varchar null					 			--SD.000376 | Порт назначения
	,dt_shipment_actual date null 										--SD.000976 | Дата отгрузки из Shipdata
	,forwarder_metal_acceptance_delay_days_quantity varchar null 		--SD.001252 | Задержка в приемке
	
	,forwarder_in_russian_port_accept_normative_exceed_days int null	--SD.001358 | Задержка в приемке дней		--2025.11.13 добавляю
	,forwarder_in_russian_port_name varchar null						--SD.001359 | Экспедитор портовый			--2025.11.13 добавляю
	
	,dttm_inserted timestamp NOT NULL DEFAULT now()
    ,dttm_updated timestamp NOT NULL DEFAULT now()
    ,job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying
    ,deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED by (
	delivery_number_initial
)
;


COMMENT ON TABLE dm.sales_forwarder_metal_acceptance_delays is 'Консолидированный отчет по задержке приемки экспедиторами';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.delivery_number_initial is 'Исходная поставка | Исходная поставка | dm_calc.sd_sales_main_scm.delivery_number_initial';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.plant_producer_code is 'Завод-производитель (код) | Завод-производитель (код) | dm_calc.sd_sales_main_scm.plant_producer_code';
/*2025.11.14*/COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.plant_producer_name is 'Завод | Завод | dm_calc.sd_sales_main_scm.plant_producer_name';
/*2025.11.06*/COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.port_of_loading_code is 'Направление (код) | Направление (код) | dm_calc.sd_sales_main_scm.tsw_location_code';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.dt_arrival_by_railway is 'Дата прибытия по ЖД | Дата прибытия по ЖД | dm_calc.sd_sales_main_scm.dt_arrival_by_railway';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.dt_forwarder is 'Дата экспедитора | Дата экспедитора | dm_calc.sd_sales_main_scm.dt_forwarder';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.railcar is 'Вагон | Вагон | dm_calc.sd_sales_main_scm.railcar';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.transport_bill is 'Накладная | Накладная | dm_calc.sd_sales_main_scm.transport_bill';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.railway_platform is 'Платформа | Платформа | dm_calc.sd_sales_main_scm.railway_platform';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.forwarder_name is 'Экспедитор | Экспедитор | dm_calc.sd_sales_main_scm.forwarder_name';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.port_of_discharge_name is 'Порт выгрузки | Порт выгрузки | dm_calc.sd_sales_main_scm.port_of_discharge_name';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.route_type is 'Тип маршрута | Тип маршрута | dm_calc.sd_sales_main_scm.route_type';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.route_plant_code is 'Маршрут завода | Маршрут завода | dm_calc.sd_sales_main_scm.route_plant_code';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.sales_order is 'Заказ ЦК | Заказ ЦК | dm_calc.sd_sales_main_scm.sales_order';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.uni is 'UNI | UNI | dm_calc.sd_sales_main_scm.uni';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.port_of_destination_code is 'Порт назначения | Порт назначения | dm_calc.sd_sales_main_scm.port_of_destination_name';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.dt_shipment_actual is 'Дата отгрузки из Shipdata | Дата отгрузки из Shipdata | dm_calc.sd_sales_main_scm.dt_shipment_actual';
COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.forwarder_metal_acceptance_delay_days_quantity is 'Задержка в приемке | Задержка в приемке | dm_calc.sd_sales_main_scm.forwarder_metal_acceptance_delay_days_quantity';
/*2025.11.13*/COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.forwarder_in_russian_port_accept_normative_exceed_days is 'Задержка в приемке дней | Задержка в приемке дней | dm_calc.sd_sales_main_scm.forwarder_metal_acceptance_delay_days_quantity';
/*2025.11.13*/COMMENT ON COLUMN dm.sales_forwarder_metal_acceptance_delays.forwarder_in_russian_port_name is 'Экспедитор портовый | Экспедитор портовый | dict_dds.tech_rusal_sd2925_ex.code_exped';
