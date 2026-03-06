drop table if exists dm.sb_wuc_backup cascade;

CREATE table dm.sb_wuc_backup (
	dt_report date null,                                      --Отчетная дата
	realization_status varchar(12) NULL,                       --Статус реализации 
	plant_producer_code varchar(12) NULL,                      --Завод производитель (код)
	plant_manufact varchar(90) NULL,                      --Завод производитель
	plant_manufact_rus_name varchar(90) NULL,             --Завод производитель на русском
	direction varchar(180) NULL,                     --Направление --Порт погрузки в МКТРЕК
	tsw_location_code varchar(30) NULL,                    --Порт погрузки(код) в МКТРЕК
	material_type varchar(210) NULL,                      --Тип материала
	material_rus_type varchar(210) NULL,                      --Тип материала
	material_group_report_mc varchar(27) NULL,                      --Группа материала 
	shipment_market_code varchar(3) NULL,                      --Рынок в отгрузке (код)!!!!
	ovk_market_text varchar(120) NULL,                 --Рынок в отгрузке
	weight_net numeric(13, 3) NULL,                            --Вес нетто
	weight_nk numeric(13, 3) NULL,               --Вес НК
	weight_gross numeric(13, 3) NULL,                          --Вес брутто!!!!
	quota varchar(18) NULL,                                    --Quota 
	port_of_discharge_code varchar(30) NULL,                   --Порт выгрузки (код)!!!! 
	port_discharge varchar(90) NULL,                   --Порт выгрузки
	port_of_discharge_in_foreign_port_code varchar(30) NULL,   --Второй иностранный порт (код)--чтобы вытащить английское название
	port_discharge_abroad_sec varchar(90) NULL,   --Второй иностранный порт
	delivery_point_name varchar(84) NULL,                      --Пункт доставки по инкотермс
	"ordering" varchar(18) NULL,                              --Order              --Заказ ЦK в МКТРЕК 
	metal_grade varchar(90) NULL,                               --Марка --Марка по спецификации в МКТРЕК
	buyer_end_name varchar(420) NULL,                           --Конечный потребитель
	delivery_split_reason_code varchar(30) NULL,               --Причина деления (код)!!!!
	delivery_split_reason_name varchar(180) null,              --Причина деления 
	"location" varchar(45) NULL,                                --Локация 339
	location_from_stock varchar(45) NULL,                                --Локация 339
	country_of_discharge_port_code varchar(9) NULL,            --Страна POD (код)!!!!
	country varchar(45) NULL,                                  --Страна POD
	country_rus_name varchar(45) NULL,                         --Страна POD на русском
	region_of_destination_port_code varchar(30) NULL,          --Регион POD (код)!!!!
	region varchar(60) null,          --Регион POD 
	region_rus_name varchar(60) null,                          --Регион POD 
	dest_port varchar(90) NULL,                                --Порт назначения
	delivery_number_initial varchar(30) NULL,                  --Исходная поставка!!!!
	delivery_number_sales varchar(30) NULL,                    --Продажная поставка!!!!
	delivery_number_outbound varchar(30) null,                 --Исходящая поставка !!!!
	delivery_number_of_producer_plant varchar(30) null,        --Заводская поставка !!!!
	batch varchar(30) NULL,                                    --Партия!!!!
	uni varchar(180) NULL, 
	dt_release_material timestamp NULL,                        --Дата ОМ !!!!
	release_material_status_code varchar(3) null,              --Статус ОМ!!!!
	ovk_port_vigruz_group varchar(60) null,                    --Порт выгрузки группа 
	receiving_plant_in_sap_system_code varchar(12) NULL,       --Принимающий завод грузополучателя в системе SAP!!!! 
	dt_bill_of_lading timestamp NULL,                          --Дата коносамента!!!!
	material_code varchar(54) NULL,                            --Номер материала
	material_name varchar(120) null,                           --Наименование материала
	delivery_basis varchar(9) NULL,                            --Базис поставки!!!!
	customer_code varchar(30) NULL,                            --Покупатель!!!!
	customer_name varchar(450) NULL,
	dt_ownership_transfer date null,                           --Дата ППС
	dt_shipment timestamp NULL,                                --Дата отгрузки!!!!
	--delivery_country varchar(54) NULL,                         --Страна поставки!!!!
	--delivery_region_code varchar(30) NULL,                     --Регион поставки(код)!!!!
	delivery_region varchar(80) NULL,                          --Регион поставки
	delivery_region_rus_name varchar(80) NULL,                 --Регион поставки на русском
	dt_prepared_for_realization date null,                     --Дата готовности в релизу SD.000344
	dt_updated timestamp null,								   --Дата и время последнего изменения на источнике
	material_group_for_scm_report_name varchar(30) NULL,       --Группа материала для отчета Металл в Цепочке Поставок
	dt_realization_forecast date null,                         --Расчетная дата реализации
	vessel_and_voyage_plan_search_name varchar(180) NULL,      --Судно / номер рейса (план)
	vessel_and_voyage_actual_search_name varchar(180) NULL,    --Судно / номер рейса (факт)
	dt_barge_loading date null,                                --Дата погрузки на баржу
	dt_barge_arrival date null,                                --Дата доставки баржи
	delivery_country_in_contract_code varchar(11) NULL,
	commitment_weight numeric(15, 3) NULL,
	total_commitment_weight numeric(15, 3) NULL,
	lot_code varchar(30) NULL,
	homogenisation_name varchar(30) NULL,
	port_of_discharge_country_code varchar(3) NULL,
	dt_warehouse_confirmation date NULL,
	second_shipping_instruction_code varchar(10) NULL,
	dt_release date NULL,
	notice_name varchar(30) NULL,
	dt_notice date NULL,
	final_release_code varchar(30) NULL,
	dt_final_invoice_payment date NULL,
	vehicle_in_foreign_port_code varchar(20) NULL,
	vehicle_type_in_foreign_port_code varchar(4) NULL,
	--shipment_market_name varchar(40) NULL,
	is_consigment_warehouse_applicable varchar(1) NULL,
	dt_transfer_from_consignment_to_customer date NULL,
	dt_forwarder_discharge_invoice_or_cmr_documented date NULL,
	transportation_scenario_code varchar(2) NULL,
	delivery_country_in_contract_name varchar(15) NULL,
	delivery_country_in_contract_rus_name varchar(15) NULL,
	prepared_for_realization_status_name varchar(8) NULL,
	bill_of_lading_in_foreign_port varchar(90) NULL,
	bill_of_lading_in_foreign_port_nomination varchar(60) NULL,
	bill_of_lading_number varchar(90) NULL,
	business_location_name varchar(150) NULL,   -- Статус в Supply chain (Business) SD.000492 было business_location_name вернула business_location_sap_precalc_name - из озера
	container_after_repacking varchar(60) NULL,
	contract_name varchar(105) NULL,
	contract_plan_code varchar(30) NULL,
	contract_plan_name varchar(300) NULL,
	customer_grade_name varchar(90) NULL,
	delivery_instruction_code varchar(30) NULL,
	delivery_notice_number varchar(90) NULL,
	dimensions_unit varchar(60) NULL,
	dt_arrival_by_railway timestamp NULL,
	dt_arrival_in_port_of_discharge timestamp NULL,
	dt_arrival_in_port_of_discharge_plan timestamp NULL,
	dt_arrived_via_ul_system date NULL,
	dt_delivery_notice date NULL,
	dt_discharge_in_foreign_port date NULL, --Дата разгрузки в ин. порту
	dt_expected_bill_of_lading date NULL,
	dt_expected_delivery timestamp NULL,
	dt_final_release date NULL,
	dt_forwarder timestamp NULL,
	dt_repacked date NULL,
	dt_sailed_loading_port timestamp NULL,
	dt_storage_end_in_foreign_port timestamp NULL,
	dt_storage_start_in_foreign_port timestamp NULL,
	dt_storage_start_in_second_foreign_warehouse timestamp NULL,
	dt_warehouse date NULL,
	external_contract_in_lot_number varchar(35) NULL,
	finish_good_group_code varchar(90) NULL,
	finish_good_unit_diameter varchar(60) NULL,
	finish_good_unit_height varchar(30) NULL,
	finish_good_unit_length varchar(30) NULL,
	finish_good_unit_width varchar(30) NULL,
	foreign_port_of_discharge_location_code varchar(150) NULL,
	forwarder_name varchar(300) NULL,
	incoterms_location_plan_code varchar(84) NULL,
	incoterms_plan_code varchar(9) NULL,
	instruction_number varchar(30) NULL,
	invoice_final_number varchar(90) NULL,
	invoice_provisional_number varchar(90) NULL,
	is_plan_or_actual varchar(3) NULL,
	is_shipped_via_overseas_second_foreign_warehouse varchar(3) NULL,
	is_shipped_via_overseas_warehouse varchar(3) NULL,
	lot_contract_code varchar(30) NULL,
	lot_customer_code varchar(30) NULL,
	lot_customer_name varchar(450) NULL, 
	lot_delivery_basis_code varchar(9) NULL,
	lot_delivery_point_name varchar(84) NULL,
	material_shape_name_full varchar(90) NULL,
	material_shape_rus_name_full varchar(90) NULL,
	material_specification_name varchar(150) NULL,
	pb_number varchar(105) NULL,
	pieces bigint NULL,
	plant_owner_code varchar(12) NULL,
	pledge_in_bank_name varchar(420) NULL,
	port_of_loading_in_foreign_port_name varchar(90) NULL,
	railcar varchar(60) NULL,
	railway_movement_status_name varchar(30) NULL,
	railway_platform varchar(36) NULL,
	release_group_name varchar(90) NULL,
	sales_contract_code varchar(30) NULL,
	second_foreign_port_of_discharge_location_code varchar(30) NULL,
	shipment_period_preferred varchar(90) NULL,
	station_destination varchar(90) NULL,
	transport_bill varchar(105) NULL,
	transport_railcar_type_name varchar(120) NULL,
	uni_in_shipment varchar(180) NULL,
	vessel_in_foreign_port_actual_name varchar(120) NULL,
	warehouse_gross_weight varchar(17) NULL,
	warehouse_shipment_type_name varchar(90) NULL,
	exporter_name varchar(450) NULL,                           --Экспортер (код)
	country_of_end_user_name varchar(45) NULL,                  --Страна конечного потребителя
	country_of_end_user_rus_name varchar(50) null,        -- SD.000601 Страна конечного потребителя на русском
	buyer_plan_name varchar(450) NULL,                          --Плановый покупатель
	customer_for_scm_report_name varchar(450) NULL,             --Клиент для отчета Металл в Цепочке Поставок
	forwarder_instruction_name varchar(30) NULL,                --Поручение
	dt_forwarder_instruction date NULL,                         --Дата поручения
	forwarder_in_foreign_port_name varchar(450) NULL,           --Экспедитор в иностранном порту
	dt_storage_payed_in_foreign_port_by_rusal date NULL,        --Дата окончания хранения на складе за счет RUSAL по Релизу
	shipment_instruction_in_foreign_port_name varchar(30) NULL, --Инструкция на отгрузку Ин Порт
	dt_shipment_instruction_in_foreign_port date NULL,          --Дата инструкции на отгрузку Ин Порт
	dt_shipment_instruction_date_from date NULL,                --Инструкция на отгрузку хранение по графику 'Дата с'
	dt_shipment_instruction_date_to date NULL,                  --Инструкция на отгрузку хранение по графику 'Дата по'
	shipment_instruction_in_second_foreign_port_name varchar(30) NULL, --Инструкция на отгрузку Ин Порт 2
	dt_shipment_instruction_in_second_foreign_port date NULL,   --Дата инструкции на отгрузку Ин Порт 2
	dt_invoice_provisional date NULL,                           --Дата предварительного инвойса
	provisional_invoice_payment_status_code varchar(3) NULL,    --Статус оплаты предварительного инвойса
	invoice_provisional_code varchar(30) NULL,                  --Фактура предварительного инвойса
	mh1_storage_document_number varchar(60) NULL,               --Акт на склад СВХ
	dt_mh1_storage_document date NULL,                          --Дата акта на склад СВХ
	--mh3_storage_document_number varchar(60) NULL,               --Акт со склада СВХ
	--dt_mh3_storage_document date NULL,                          --Дата акта со склада СВХ
	dt_departure_from_foreigh_port date NULL,                 --EXP: Load out date -- Данчик вытаскивал
	foreign_port_terminal_name varchar(30) NULL,                                --Данчик вытаскивал
	russian_port_bill_of_lading_forwarder_code varchar(30) NULL,  --EXP: WH Operator's code
	foreign_port_bill_of_lading_forwarder_code varchar(30) NULL,  --EXP: WH Operator's code 2
	uzbekistan_cargo_declaration_73 varchar(50) NULL,             --EXP: ГТД ИМ73
	shipment_instruction_in_foreign_port_code varchar(30) NULL,   --Группа инструкции на отгрузку Ин Порт
	customer_special_requirement varchar(150) NULL,              --Номер заказа клиента
	plant_producer_name varchar(90) null,                        --Завод производитель
	vessel_plan_name varchar(120) null,                          --Судно план
	dt_bill_of_lading_in_foreign_port date null,                 --Дата коносамента в ин.порту
	dt_arrival_in_second_port_of_discharge date null,            --Дата прибытия в порт выгрузки 2
	port_of_discharge_in_foreign_port_name varchar(90) null,     --Второй иностранный порт
	dt_storage_end_in_second_foreign_warehouse date NULL,        --Окончание хранение склад 2
	railway_train_number varchar(50) null,                        --Номер поезда
	customs_declaration_number varchar(90) null,                  --Номер ГТД (код)
	sales_team_code varchar(4) null,                              --Сбытовая команда (код) 
	sales_team_name varchar(60) null,                              --Сбытовая команда 
    ready_for_realization_status_name varchar(60) null,           --Статус готовности к реализации
    receiving_plant_in_sap_system_name  varchar(50) null,          --Принимающий завод грузополучателя в системе SAP
    port_of_discharge_plan_code varchar(10) NULL,                             --Плановый порт выгрузки (код)
	port_of_discharge_plan_name varchar(30) NULL,                              --Плановый порт выгрузки
	second_foreign_port_of_discharge_plan_code varchar(10) NULL,              --Плановый порт выгрузки 2 (код)
	second_foreign_port_of_discharge_plan_name varchar(30) null,               --Плановый порт выгрузки 2
	dt_arrival_in_port_of_destination date null,                  --Дата прибытия в порт назначения
	voyage_number_internal varchar(20) null,                      --Номер рейса внутренний
	vessel_and_voyage_number_reporting_name varchar(200) null,    --Судно / Номер рейса / Номер рейса поставщика
    shipment_instruction_group_ds varchar(10) NULL,              --Группа инструкции ДСБ (код)
	dt_shipment_instruction_ds date null,                        --Дата инструкции ДСБ
	shipment_instruction_number_ds varchar(30) null,                    --Номер инструкции ДСБ 
	shipment_instruction_nomination_code_ds varchar(20) null,                    --Номинация инструкции ДСБ 
	--ver 108
	end_buyer_code varchar(10) NULL,                              --Конечный покупатель (код) SD.000640
	country_of_end_user_code varchar(3) NULL,                     --Страна конечного потребителя (код) SD.000641    
	country_of_customer_code varchar(30) NULL,                    --Страна покупателя (код) SD.000643         
	country_of_customer_name varchar(15) NULL,                    --Страна покупателя SD.000644  
	country_of_destination_port_code varchar(30) NULL,            --Страна порта назначения (код) SD.000646    
	country_of_destination_port_name varchar(15) NULL,            --Страна порта назначения  SD.000647
	is_mirrored_resale_code varchar(4) NULL,                      --Зеркало SD.000648    
	delivery_region_code varchar(10) NULL,                        --Регион поставки по контракту (код) SD.000652      
	supply_chain_customer_portal_status_name varchar(50) NULL,    --Статус в Supply chain (Portal) SD.000656  
	port_of_destination_code varchar(30) NULL,                    --Порт назначения (код) SD.000645  
	--ver 125
	dt_realization_for_reporting date NULL,                       --Дата реализации План/Факт SD.000683
	dt_realization_for_reporting_mmyyyy varchar(7) NULL,          --Месяц реализации SD.000684 
	--ver 132
	dt_quota_yyyymm varchar(18) NULL,                            --Quota для бизнеса SD.000687 
	storage_duration_in_calendar_days varchar(6) NULL,                     --Сроки нахождения в локации SD.000688
	--ver 136
	is_vehicle_allocated_name varchar(4) NULL,				    -- Признак Распределенный вагон SD.000664
	--ver 108 new
	sap_shipdata_reference_code varchar(16) NULL,						-- ID_SHIPDATA SD.000654
	--129
	dt_realization date null,											-- Дата реализации SD.000687
	internal_compound_key_code varchar(16) null,						-- Внутренний уникальный идентификатор записи SD.000688*/
	--108
	bill_of_lading_group_code varchar(30) NULL,							-- Группа коносамента SD.000040
	bill_of_lading_route varchar(18) NULL,								-- Маршрут коносамента SD.000043
	lot_group varchar(30) NULL,											-- Группа лот SD.000061
	port_of_loading_code varchar(10) NULL,								-- Порт погрузки (код) SD.000649
	port_of_loading_name varchar(30) NULL,								-- Порт погрузки SD.000653
	--137
	buyer_agent_code varchar(10) null,									-- Trading company (код) SD.000703
	buyer_agent_name varchar(35) null,									-- Trading company SD.000704
	--146
	pb1_number varchar(35) NULL,										-- Номер PB 1 SD.000592
	pb2_number varchar(35) NULL,										-- Номер PB 2 SD.000593
	pb3_number varchar(35) NULL,										-- Номер PB 3 SD.000594
	pb1_warehouse_name varchar(30) NULL,								-- Склад PB 1 SD.000595
	pb2_warehouse_name varchar(30) NULL,								-- Склад PB 2 SD.000596
	pb3_warehouse_name varchar(30) NULL,								-- Склад PB 3 SD.000597
	----153
	sales_order_in_shipment varchar(90) NULL,                           -- Заказ ЦК в отгрузке SD.000005	
	is_tolling_code varchar(4) NULL,                                    -- Признак толлинг SD.000749
	location_stay_duration_category_code varchar(10) NULL,              -- Сроки нахождения в локации (месяц) SD.000750
	----154
    dt_pb1_number date NULL,                                            -- Date PB 1 SD.000751
	dt_pb2_number date NULL,                                            -- Date PB 2 SD.000752
	dt_pb3_number date NULL,                                            -- Date PB 3 SD.000753  
	 -----Для витрины оборотный капитал 167
	transport_railcar_type_code varchar(12) NULL,						-- Тип вагона (код) SD.000028
    dt_arrival_in_second_port_of_discharge_plan  date NULL,             -- Дата прибытия в порт выгрузки 2 план SD.000157
    dt_train_scheduled_arrival date NULL,	 							-- Плановая дата прибытия по ЖД (с фактом) SD.000697
    second_port_of_discharge_country_code varchar(3) NULL,              -- Код страны порта выгрузки 2 SD.000768
    second_port_of_discharge_region_code varchar(3) null,               -- Код региона порта выгрузки 2 SD.000769
    second_port_of_discharge_region_name varchar(80) null,             -- Регион порт выгрузки 2 SD.000770
    second_port_of_discharge_region_rus_name varchar(80) null,         -- Регион порт выгрузки 2 SD.000770 на русском
    customer_for_scm_report_code varchar(30) null,                      -- Клиент для отчета Металл в Цепочке Поставок (код) SD.000771  
    country_of_customer_for_reporting_code varchar(3) NULL,            -- Код страны Клиент для отчета Металл в Цепочке Поставок SD.000772 
    country_of_customer_for_reporting_name varchar(80) null,             -- Cтрана Клиент для отчета Металл в Цепочке Поставок SD.000773 
  ------
	----данные срезов
    business_location_for_reporting_name varchar(150) NULL,                  -- Статус среза SD.000717|SD.000717  -
    plan_or_actual_code varchar(3) NULL,                       -- Источник данных среза План/Факт SD.000718
     ---------новые
    normative_railway_trip_duration_days_quantity varchar(12) null,     -- SD.000774 Норма движения по жд (дни) 
    normative_route_trip_duration_days_quantity varchar(12) null,       -- SD.000775 Норма доставки по маршруту завода    --------        
	normative_marine_transit1_duration_days_quantity varchar(12) null,  -- SD.000776 Норма морского транзита  
    normative_marine_transit2_duration_days_quantity varchar(12) null,  -- SD.000777 Норма морского транзита 2  
      ----166
    consignee_code varchar(30) NULL,									-- Получатель материала (код) SD.000080
	consignee_name varchar(360) NULL,									-- Грузополучатель SD.000081
	customs_invoice_code varchar(10) NULL,                              -- SD.000779 Custom's invoice Group 
	customs_invoice_number varchar(30) NULL,                            -- SD.000780 Custom's invoice Number 
	dt_customs_invoice date NULL,                                       -- SD.000781 Custom's invoice Date
	--------177
    tolling_scheme_name varchar(60) NULL,                               -- SD.000908 Толлинг 
     ---
    receiving_warehouse_code varchar(12) null,							-- Принимающий склад SD.000098
    --business_location_stay_normative_weight numeric(13,3) null,         -- Норматив SD.000915
    business_location_stay_normative_average_allocated_weight numeric(13,3) null,         -- Средневзвешенное значение норматива SD.000916
    ------новые для ОК
    material_group_for_wc_reporting_name varchar(27) NULL,              -- SD.000959 Группа материалов для отчета Оборотный капитал
    business_location_for_wc_reporting_name varchar(150) NULL,          -- SD.000960 Локация для отчета Оборотный капитал
    business_location_plan_weight numeric(13,3) null,                   -- SD.000961 Цель для Локации отчета Оборотный капитал
    material_cost_actual_hfm_usd_currency_amount numeric(13,3) null,    -- HFM Себестоимость   -----Новое в структуре
    material_cost_actual_usd_currency_amount numeric(13,3) null,        -- SD.000962 Сумма в доллар ФАКТ (Сумма в долларах факт от веса поставки)
    material_cost_plan_usd_currency_amount numeric(13,3) null,          -- SD.000963 Сумма в доллар ЦЕЛЬ
    business_location_allocated_plan_weight numeric(13,3) null,         -- SD.000964 Цель пропорциональная
    report_comment1_text varchar(300) NULL,                             -- SD.000965 Комментарий 1
    report_comment2_text varchar(300) NULL,                             -- SD.000966 Комментарий 2
    report_comment3_text varchar(300) NULL,                             -- SD.000967 Комментарий 3
    -----
    ---DWH-6803
	warehouse_or_responsible_customer_for_storage_name /*calculated_location_name*/ varchar(450) NULL,   -- SD.000919 General storage location       
	---215 Новое
	dt_shipment_actual date NULL,										-- SD.000976 "Дата отгрузки из Shipdata"
	---236
	dt_acceptance_in_russian_port_planned date null,                    -- SD.000705 Плановая дата принятия в порту РФ 
	---241
	vessel_load_daily_plan_weight numeric(13,3) null,                            -- SD.001045 Цель погрузки на судно 
	vessel_load_daily_allocated_plan_weight numeric(13,3) null,                  -- SD.001046 Цель пропорциональная погрузки на судно 
	---237
	--forwarder_in_foreign_port_code varchar(10) null,                    -- SD.000950 Экспедитор в иностранном порту (код) 
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
) 
WITH (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED by (dt_report, delivery_number_sales,batch);

comment on table dm.sb_wuc_backup IS 'Металлы в цепочке поставок на последнего оператора';
comment on column dm.sb_wuc_backup.delivery_number_initial is 'Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах | map_zmk_track_exp_keys.VBELN_exp01';
comment on column dm.sb_wuc_backup.delivery_number_sales is 'Продажная поставка | Если поставка разделена, то деленная поставка, если нет, то Исходная поставка. Если отгрузка через агента (РТД) - выводится поставка завода производителя | map_zmk_track_exp_keys.VBELN_P_exp01';
comment on column dm.sb_wuc_backup.delivery_number_of_producer_plant is 'Номер поставки завода производителя | Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе | map_zmk_track_exp_keys.VBELN_LF_exp01';
comment on column dm.sb_wuc_backup.batch is 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков. | map_zmk_track_exp_keys.CHARG_exp01';
comment on column dm.sb_wuc_backup.plant_producer_code is 'Завод производитель (код) | Код завода производителя | sales_batch_delivery.plant_producer_code';
comment on column dm.sb_wuc_backup.tsw_location_code is 'Направление (код) | Напрвление погрузки. Например, RTI-ZARUBI | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | map_zmk_track_exp_keys.DATEOT_exp01';
comment on column dm.sb_wuc_backup.shipment_market_code is 'Рынок в отгрузке (код) | Код рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | sales_batch_delivery.market_in_shipment_code';
comment on column dm.sb_wuc_backup.weight_gross is 'Вес брутто | Вес брутто | map_zmk_track_exp_keys.BTGEW_exp02';
comment on column dm.sb_wuc_backup.weight_net is 'Вес нетто | Вес нетто | map_zmk_track_exp_keys.LFIMG_exp02';
comment on column dm.sb_wuc_backup.customer_code is 'Покупатель(код) | Системный код покупателя из клиентского лота, если его нет то Плановый покупатель из заявки под план производства.  | map_zmk_track_exp_keys.KUNNR_exp02';
comment on column dm.sb_wuc_backup.customer_name is 'Покупатель | Наименование покупателя из клиентского лота, если его нет то Плановый покупатель из заявки под план производства.  | map_zmk_track_exp_keys.KUNNR_exp02';
comment on column dm.sb_wuc_backup.quota is 'Квота | Квота из клиентского лота, если его нет, то Квота  из заявки под план производства | map_zmk_track_exp_keys.QUOTA_exp02';
comment on column dm.sb_wuc_backup.dt_bill_of_lading is 'Дата коносамента | Дата коносамента из РФ. Документ, который используют в водных перевозках из российских портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | map_zmk_track_exp_keys.LDDAT_Y_exp02';
comment on column dm.sb_wuc_backup.port_of_discharge_code is 'Порт выгрузки (код) | Системный номер порта выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, P000000034 | transport_route.transport_route_destination_hub_code';
comment on column dm.sb_wuc_backup.port_of_discharge_in_foreign_port_code is 'Порт выгрузки 2 (код) | Системный номер порта выгрузки (место назначения) из Маршрута коносамента в ин. порту. | map_zmk_track_exp_keys.KNEND_KOP_exp02';
comment on column dm.sb_wuc_backup.delivery_basis is 'Базис поставки | Базис поставки (Инкотермс 1), это правило поставки Инкотермс.  Базис обозначается тремя латинскими буквами, например EXW, CIP, DAP и пр. Инфо берем из клиентского лота, ели его нет то из заявки под план производства | map_zmk_track_exp_keys.BASIS_exp02';
comment on column dm.sb_wuc_backup.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс (Инкотермс 2), это место передачи груза, это может быть город, аэропорт, морской либо речной порт.  Инфо берем из клиентского лота, ели его нет то из заявки под план производства | map_zmk_track_exp_keys.BASIS2_exp02';
comment on column dm.sb_wuc_backup.receiving_plant_in_sap_system_code is 'Принимающий завод грузополучателя в системе SAP | Системный номер завода оператора, собственника продукции при реализации клиенту | sales_batch_delivery.receiving_plant_in_sap_system_code';
comment on column dm.sb_wuc_backup.material_code is 'Код материала | Системный номер материала. Например, APT0006ING0045. Аналог поля  Номер материала | map_zmk_track_exp_keys.MATNR_exp02';
comment on column dm.sb_wuc_backup.uni is 'UNI | Если Причина деления постави = ""4- Перевеска"", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | map_zmk_track_exp_keys.UNI_exp02';
comment on column dm.sb_wuc_backup.material_name is '- | - | material_texts.material_name';
comment on column dm.sb_wuc_backup.delivery_split_reason_name is 'Причина деления | - | delivery_split_reason_texts.delivery_split_reason_name';
comment on column dm.sb_wuc_backup.country_of_discharge_port_code is 'Страна POD (код) | - | map_zmk_track_exp_keys.LAND1_POD_exp02';
comment on column dm.sb_wuc_backup.region_of_destination_port_code is 'Регион POD (код) | - | map_zmk_track_exp_keys.WWGSG_POD_exp02';
comment on column dm.sb_wuc_backup.delivery_number_outbound is 'Исходящая поставка | - | map_zmk_track_exp_keys.VBELN_ISH_exp03';
comment on column dm.sb_wuc_backup.dt_release_material is 'Дата ОМ | Дата проводки ОМ | map_zmk_track_exp_keys.WADAT_IST_ISH_exp04';
comment on column dm.sb_wuc_backup.release_material_status_code is 'Статус ОМ | Статус проводки ОМ | map_zmk_track_exp_keys.WBSTK_ISH_exp04';
comment on column dm.sb_wuc_backup.delivery_split_reason_code is 'Причина деления (код) | Причина разделения партии на разные поставки. Допустимы значения из домена /RUSAL/SD2925M_SPLIT_REASON | map_zmk_track_exp_keys.REASON_exp02';
comment on column dm.sb_wuc_backup.dt_ownership_transfer is 'Дата перехода права собственности | - | map_zmk_track_exp_keys.DATEPPS_exp01';
comment on column dm.sb_wuc_backup.dt_prepared_for_realization is 'Дата готовности к реализации | - | map_zmk_track_exp_keys.READY_TO_SHIP_DATE_exp04';
comment on column dm.sb_wuc_backup.dt_report is 'Отчетная дата | - | map_zmk_track_exp_keys.dt_balance';
comment on column dm.sb_wuc_backup.realization_status is 'Статус реализации | - | map_zmk_track_exp_keys';
comment on column dm.sb_wuc_backup.plant_manufact is 'Наименование завода производителя | - | map_zmk_track_exp_keys.plant_producer_name';
comment on column dm.sb_wuc_backup.direction is 'Направление | - | map_zmk_track_exp_keys.port_of_loading_name';
comment on column dm.sb_wuc_backup.material_type is 'Тип материала | - | map_zmk_track_exp_keys.material_aggr_name';
comment on column dm.sb_wuc_backup.material_group_report_mc is 'Группа материала | - | map_zmk_track_exp_keys.material_group_code';
comment on column dm.sb_wuc_backup.ovk_market_text is 'Рынок | - | map_zmk_track_exp_keys.market_in_shipment_name';
comment on column dm.sb_wuc_backup.weight_nk is 'Тоннаж вес + НК | - | map_zmk_track_exp_keys.weight_net_with_wirerod';
comment on column dm.sb_wuc_backup.port_discharge is 'Порт выгрузки | - | map_zmk_track_exp_keys.port_of_discharge_name';
comment on column dm.sb_wuc_backup.port_discharge_abroad_sec is 'Второй иностранный порт выгрузки | - | transport_hub.transport_hub_name_eng';
comment on column dm.sb_wuc_backup."ordering" is 'Заказ | - | map_zmk_track_exp_keys.sales_order';
comment on column dm.sb_wuc_backup.metal_grade is 'Vfhrf | - | map_zmk_track_exp_keys.grade_name';
comment on column dm.sb_wuc_backup.buyer_end_name is 'Наименование конечного покупателя | - | map_zmk_track_exp_keys.end_user_name';
comment on column dm.sb_wuc_backup.location_from_stock is 'Локация | - | map_zmk_track_exp_keys.location';
comment on column dm.sb_wuc_backup.country is 'Страна назначения (код) | - | country_texts.country_short_name';
comment on column dm.sb_wuc_backup.region is 'Регион поставки | - | sales_delivery_region_texts.delivery_region_name';
comment on column dm.sb_wuc_backup.dest_port is 'Порт назначения | - | map_zmk_track_exp_keys.port_of_destination_code';
comment on column dm.sb_wuc_backup.ovk_port_vigruz_group is 'Порт выгрузки группа | - | map_zmk_track_exp_keys';
--comment on column dm.sb_wuc_backup.delivery_country is 'Страна поставки | - | delivery_country.delivery_country';
--comment on column dm.sb_wuc_backup.delivery_region_code is 'Код региона поставки | - | sales_delivery_region_texts.delivery_region_code';
comment on column dm.sb_wuc_backup.delivery_region is 'Наименование региона поставки | - | sales_delivery_region_texts.delivery_region_name';  
comment on column dm.sb_wuc_backup.dt_updated is 'Дата и время последнего изменения на источнике | - | map_zmk_track_exp_keys.dt_updated';
comment on column dm.sb_wuc_backup.material_group_for_scm_report_name is 'Группа материала для отчета Металл в Цепочке Поставок | - | /RUSAL/CARGOORD-MAT_FOR_REP';
comment on column dm.sb_wuc_backup.dt_realization_forecast is 'Расчетная дата реализации | - | ZMK_TRACK_EXP04 - REALIZATION_DATE_CALC';
comment on column dm.sb_wuc_backup.vessel_and_voyage_plan_search_name is 'Судно / номер рейса (план) | - | Расчетное';
comment on column dm.sb_wuc_backup.vessel_and_voyage_actual_search_name is 'Судно / номер рейса (факт) | - | Расчетное';
comment on column dm.sb_wuc_backup.dt_barge_loading is 'Дата погрузки на баржу | Дата баржевого коносамента | Расчетное';
comment on column dm.sb_wuc_backup.dt_barge_arrival is 'Дата доставки баржи | Доставка по баржевому коносаменту | Расчетное';
comment on column dm.sb_wuc_backup.delivery_country_in_contract_code is 'Страна поставки по контракту (код) | Страна поставки по контракту (код) | dm_calc.sd_sales_svh_stock_by_date.delivery_country_in_contract_code';
comment on column dm.sb_wuc_backup.commitment_weight is 'Объем обязательств | Объем обязательств | dm_calc.sd_sales_svh_stock_by_date.commitment_weight';
comment on column dm.sb_wuc_backup.total_commitment_weight is 'Объем обязательств итого | Объем обязательств итого | dm_calc.sd_sales_svh_stock_by_date.total_commitment_weight';
comment on column dm.sb_wuc_backup.lot_code is 'Номер лота | номер лота | dm_calc.sd_sales_svh_stock_by_date.lot_code';
comment on column dm.sb_wuc_backup.homogenisation_name is 'HMG | Гомогенизация | dm_calc.sd_sales_svh_stock_by_date.homogenisation_name';
comment on column dm.sb_wuc_backup.port_of_discharge_country_code is 'Страна порта выгрузки | Страна порта выгрузки 1 | dm_calc.sd_sales_svh_stock_by_date.port_of_discharge_country_code';
comment on column dm.sb_wuc_backup.dt_warehouse_confirmation is 'Дата Storage confirmation | Дата Storage confirmation | dm_calc.sd_sales_svh_stock_by_date.dt_warehouse_confirmation';
comment on column dm.sb_wuc_backup.second_shipping_instruction_code is 'Группа инструкции на отгрузку Ин Порт 2 | Группа инструкции на отгрузку Ин Порт 2 | dm_calc.sd_sales_svh_stock_by_date.second_shipping_instruction_code';
comment on column dm.sb_wuc_backup.dt_release is 'Дата релиз | Дата релиз | dm_calc.sd_sales_svh_stock_by_date.dt_release';
comment on column dm.sb_wuc_backup.notice_name is 'Номер нотиса | Номер нотиса | dm_calc.sd_sales_svh_stock_by_date.notice_name';
comment on column dm.sb_wuc_backup.dt_notice is 'Дата нотиса | Дата нотиса | dm_calc.sd_sales_svh_stock_by_date.dt_notice';
comment on column dm.sb_wuc_backup.final_release_code is 'Номер Финальный релиз | Номер Финальный релиз | dm_calc.sd_sales_svh_stock_by_date.final_release_code';
comment on column dm.sb_wuc_backup.dt_final_invoice_payment is 'Дата оплаты Final Invoice | Дата оплаты Final Invoice | dm_calc.sd_sales_svh_stock_by_date.dt_final_invoice_payment';
comment on column dm.sb_wuc_backup.vehicle_in_foreign_port_code is 'Номер ТС в ин. порту | Номер ТС в ин. порту | dm_calc.sd_sales_svh_stock_by_date.vehicle_in_foreign_port_code';
comment on column dm.sb_wuc_backup.vehicle_type_in_foreign_port_code is 'Тип ТС в ин. порту | Тип ТС в ин. порту | dm_calc.sd_sales_svh_stock_by_date.vehicle_type_in_foreign_port_code';
--comment on column dm.sb_wuc_backup.shipment_market_name is 'Рынок в отгрузке | Название рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | dm_calc.sd_sales_svh_stock_by_date.shipment_market_name';
comment on column dm.sb_wuc_backup.is_consigment_warehouse_applicable is 'Признак консигнации | Отображает "X" при налиичии в логистике Консигнационного склада | dm_calc.sd_sales_svh_stock_by_date.is_consigment_warehouse_applicable';
comment on column dm.sb_wuc_backup.dt_transfer_from_consignment_to_customer is 'Дата перехода из консигнации клиенту | Отображает дату - «Дата Provisional Invoice» если «Признак консигнации» = X  | dm_calc.sd_sales_svh_stock_by_date.dt_transfer_from_consignment_to_customer';
comment on column dm.sb_wuc_backup.dt_forwarder_discharge_invoice_or_cmr_documented is 'ТН/CMR: Дата выгрузки авто | Экспедиторская дата выгрузки автотранспорта | dm_calc.sd_sales_svh_stock_by_date.dt_forwarder_discharge_invoice_or_cmr_documented';
comment on column dm.sb_wuc_backup.transportation_scenario_code is 'Сценарий маршрута | Сценарий маршрута | dm_calc.sd_sales_svh_stock_by_date.transportation_scenario_code';
comment on column dm.sb_wuc_backup.delivery_country_in_contract_name is 'Страна поставки по контракту | Страна поставки по контракту | dm_calc.sd_sales_svh_stock_by_date.delivery_country_in_contract_name';
comment on column dm.sb_wuc_backup.prepared_for_realization_status_name is 'Статус Реализации | Статус готовности к реализации | dm_calc.sd_sales_svh_stock_by_date.prepared_for_realization_status_name';
----70-fields
comment on column dm.sb_wuc_backup.bill_of_lading_in_foreign_port is 'Коносамент в ин.порту  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.bill_of_lading_in_foreign_port_nomination is 'Номинация коносамента в ин. порту  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.bill_of_lading_number is 'Номер коносамента  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.business_location_name is 'Статус в Supply chain (Business)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.container_after_repacking is 'Контейнер после перетарки  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.contract_name is 'Контракт  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.contract_plan_code is 'Плановый контракт (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.contract_plan_name is 'Плановый контракт  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.customer_grade_name is 'Марка клиента  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.delivery_instruction_code is 'Инструкция на доставку  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.delivery_notice_number is 'Номер нотиса о доставке  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dimensions_unit is 'Размер единицы готовой продукции  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_arrival_by_railway is 'Дата прибытия по ЖД  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_arrival_in_port_of_discharge is 'Дата прибытия в порт выгрузки  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_arrival_in_port_of_discharge_plan is 'Дата прибытия в порт выгрузки план  |  | dm_calc.sd_sales_main_scm';
--comment on column dm.sb_wuc_backup.dt_arrival_in_second_port_of_discharge is 'Дата прибытия в порт выгрузки 2  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_arrived_via_ul_system is 'Дата прибытия УЛ  |  | dm_calc.sd_sales_main_scm';
--comment on column dm.sb_wuc_backup.dt_bill_of_lading_in_foreign_port is 'Дата коносамента в ин.порту  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_delivery_notice is 'Дата нотиса о доставке  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_discharge_in_foreign_port is 'Дата выгрузки в порту  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_expected_bill_of_lading is 'Ожидаемая дата коносамента  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_expected_delivery is 'Expected delivery  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_final_release is 'Дата Финальный релиз  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_forwarder is 'Дата экспедитора  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_repacked is 'Дата перетарки  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_sailed_loading_port is 'Sailed L.Port  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_storage_end_in_foreign_port is 'Окончание хранения в ин. порту  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_storage_start_in_foreign_port is 'Дата начала хранения ин. склад  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_storage_start_in_second_foreign_warehouse is 'Начало хранения склад 2  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_warehouse is 'Дата склада  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.external_contract_in_lot_number is 'Контракт в лоте/Квотный контракт  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.finish_good_group_code is 'Группа продукции  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.finish_good_unit_diameter is 'Диаметр единицы готовой продукции  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.finish_good_unit_height is 'Высота единицы готовой продукции  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.finish_good_unit_length is 'Длина единицы готовой продукции  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.finish_good_unit_width is 'Ширина единицы готовой продукции  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.foreign_port_of_discharge_location_code is 'Иностранный порт (код локации)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.forwarder_name is 'Экспедитор  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.incoterms_location_plan_code is 'Плановый пункт доставки по инкотермс  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.incoterms_plan_code is 'Плановый базис поставки   |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.instruction_number is 'Номер распоряжения  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.invoice_final_number is 'Final Invoice  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.invoice_provisional_number is 'Provisional invoice  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.is_plan_or_actual is 'Признак План/Факт  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.is_shipped_via_overseas_second_foreign_warehouse is 'Наличие Иностранный склад 2  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.is_shipped_via_overseas_warehouse is 'Наличие Иностранный склад  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.lot_contract_code is 'Контракт в лоте (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.lot_customer_code is 'Покупатель в лоте (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.lot_customer_name is 'Покупатель в лоте  |  | KNA1-NAME1+NAME2+NAME3+NAME4';
comment on column dm.sb_wuc_backup.lot_delivery_basis_code is 'Базис поставки в лоте  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.lot_delivery_point_name is 'Пункт доставки по инкотермс в лоте  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.material_shape_name_full is 'Форма  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.material_specification_name is 'Спецификация  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pb_number is 'LotWshe/PB number  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pieces is 'PCS  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.plant_owner_code is 'Завод собственник (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pledge_in_bank_name is 'Pledge Bank  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.port_of_loading_in_foreign_port_name is 'Порт погрузки 2  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.railcar is 'Вагон  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.railway_movement_status_name is 'Статус движения по ЖД  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.railway_platform is 'Платформа  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.release_group_name is 'Релиз  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.sales_contract_code is 'Контракт (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.second_foreign_port_of_discharge_location_code is 'Иностранный порт 2 (код локации)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.shipment_period_preferred is 'Желаемый период отгрузки  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.station_destination is 'Станция назначения  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.transport_bill is 'Накладная  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.transport_railcar_type_name is 'Тип вагона  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.uni_in_shipment is 'UNI в отгрузке  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.vessel_in_foreign_port_actual_name is 'Судно факт в ин. порту  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.vessel_plan_name is 'Судно план  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.warehouse_gross_weight is 'Вес брутто (с учетом склада)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.warehouse_shipment_type_name is 'СВХ  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.customer_special_requirement is 'Номер заказа клиента | Номер заказа клиента, инфо берем из клиентского лота, еслти лота нет то из транзакции ZSD2882M-Регистрация заявок клиентов | map_zmk_track_exp_keys.SPEC_ORDER_exp02';
comment on column dm.sb_wuc_backup.dt_storage_end_in_second_foreign_warehouse is 'Окончание хранение склад 2 | Дата окончания хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт | map_zmk_track_exp_keys.FINISH_STORAGE2_exp03';
comment on column dm.sb_wuc_backup.railway_train_number is 'Номер поезда |  | Расчетное';
comment on column dm.sb_wuc_backup.customs_declaration_number is 'Номер ГТД | Номер грузовой таможенной декларации | map_zmk_track_exp_keys.GTD_exp01';
comment on column dm.sb_wuc_backup.exporter_name is 'Экспортер (код) | Экспортер (код) | Расчетное';
comment on column dm.sb_wuc_backup.country_of_end_user_name is 'Страна конечного потребителя | Страна конечного потребителя | Расчетное';
comment on column dm.sb_wuc_backup.buyer_plan_name is 'Плановый покупатель | Плановый покупатель | Расчетное';
comment on column dm.sb_wuc_backup.customer_for_scm_report_name is 'Клиент для отчета Металл в Цепочке Поставок | Клиент для отчета Металл в Цепочке Поставок | Расчетное';
comment on column dm.sb_wuc_backup.sales_team_code is 'Сбытовая команда (код) | Сбытовая команда (код) | /RUSAL/SD556-WWGSG';
comment on column dm.sb_wuc_backup.sales_team_name is 'Сбытовая команда | Сбытовая команда | T25A1-BEZEK ';
comment on column dm.sb_wuc_backup.ready_for_realization_status_name is 'Статус готовности к реализации  | Статус готовности к реализации  | Значение домента /RUSAL/REALIZATION_STATUS';
comment on column dm.sb_wuc_backup.receiving_plant_in_sap_system_name is 'Принимающий завод грузополучателя в системе SAP  | Принимающий завод грузополучателя в системе SAP  | T001W-NAME1';
comment on column dm.sb_wuc_backup.port_of_discharge_plan_code is 'Плановый порт выгрузки  (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.port_of_discharge_plan_name is 'Плановый порт выгрузки   |  | TVKNT - KNOTE';
comment on column dm.sb_wuc_backup.second_foreign_port_of_discharge_plan_code is 'Плановый порт выгрузки 2 (код)  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.second_foreign_port_of_discharge_plan_name is 'Плановый порт выгрузки 2  |  | TVKNT - KNOTE';
comment on column dm.sb_wuc_backup.dt_arrival_in_port_of_destination is 'Дата прибытия в порт назначения  | Дата прибытия в порт назначения согласно сценирю маршрута, в котором анализируется какое количество коносаментов будет | Расчетное';
comment on column dm.sb_wuc_backup.voyage_number_internal is 'Номер рейса внутренний  |  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.vessel_and_voyage_number_reporting_name is 'Судно / Номер рейса / Номер рейса поставщика  | Объеденены поля Судно, Рейс внутренний, Рейс поставщика
по номинации из поручения, либо коносамента РФ. | Расчетное';
comment on column dm.sb_wuc_backup.shipment_instruction_group_ds is 'Группа инструкции ДСБ (код)  | Группа инструкции на отгрузку в порту РФ | Расчетное';
comment on column dm.sb_wuc_backup.dt_shipment_instruction_ds is 'Дата инструкции ДСБ  | Дата инструкции на отгрузку в порту РФ | Расчетное';
comment on column dm.sb_wuc_backup.shipment_instruction_number_ds is 'Номер инструкции ДСБ  | Номер инструкции на отгрузку в порту РФ | Расчетное';
comment on column dm.sb_wuc_backup.shipment_instruction_nomination_code_ds is 'Номинация инструкции ДСБ | Номинация инструкции на отгрузку в порту РФ | Расчетное';
--ver 108
comment on column dm.sb_wuc_backup.end_buyer_code is 'Конечный покупатель (код) | - | Расчетное';
comment on column dm.sb_wuc_backup.country_of_end_user_code is 'Страна конечного потребителя (код) | - | Расчетное';
comment on column dm.sb_wuc_backup.country_of_customer_code is 'Страна покупателя (код) | - | Расчетное';
comment on column dm.sb_wuc_backup.country_of_customer_name is 'Страна покупателя | - | Расчетное';
comment on column dm.sb_wuc_backup.country_of_destination_port_code is 'Страна порта назначения (код) | - | Расчетное';
comment on column dm.sb_wuc_backup.country_of_destination_port_name is 'Страна порта назначения | - | Расчетное';
comment on column dm.sb_wuc_backup.is_mirrored_resale_code is 'Зеркало | - | Расчетное';
comment on column dm.sb_wuc_backup.delivery_region_code is 'Регион поставки по контракту (код) | - | Расчетное';
comment on column dm.sb_wuc_backup.supply_chain_customer_portal_status_name is 'Статус в Supply chain (Portal) | - | Расчетное';
comment on column dm.sb_wuc_backup.port_of_destination_code is 'Порт назначения (код) | - | Расчетное';
--ver 125
comment on column dm.sb_wuc_backup.dt_realization_for_reporting is 'Дата реализации План | Расчет даты реализации в зависимости от инкотермс и наличия иностранного склада | ZMK_TRACK_EXP04-REALIZATION_DATE_PF	 ';
comment on column dm.sb_wuc_backup.dt_realization_for_reporting_mmyyyy is 'Месяц реализации | Месяц и год от даты реализации | Расчетное';
--ver 132
comment on column dm.sb_wuc_backup.dt_quota_yyyymm is 'Квота для отчета | Квота в формате ГГГГ.ММ | Расчетное';  
comment on column dm.sb_wuc_backup.storage_duration_in_calendar_days is 'Сроки нахождения в локации | - | Расчетное';
--ver 136
comment on column dm.sb_wuc_backup.is_vehicle_allocated_name is 'Признак Распределенный вагон | Признак того, что вагон участвовал в распределении | Расчетное';
--ver 108 new
comment on column dm.sb_wuc_backup.sap_shipdata_reference_code is 'Код в таблице SHIPDATA | - | Расчетное';
--129
comment on column dm.sb_wuc_backup.dt_realization is 'Дата реализации | - | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.internal_compound_key_code is 'Внутренний уникальный идентификатор записи | - | dm_calc.sd_sales_main_scm';
--108
comment on column dm.sb_wuc_backup.bill_of_lading_group_code is 'Группа коносамента | Системный номер коносамента из РФ | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.bill_of_lading_route is 'Маршрут коносамента | Системный номер маршрута коносамента из РФ, который содерит в себе   информацию  о порте погрузки и порте выгрузки | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.lot_group is 'Группа лот | Системный номер документа ЛОТ (Клиентский лот),  это совокупность поставок клиенту, привязанная к определённому номеру сбытового контракта и месяцу квоты | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.port_of_loading_code is 'Порт погрузки (код) | МР - место размещения. Системный код порта погрузки. Например, ZARUBINO | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.port_of_loading_name is 'Порт погрузки | - | dm_calc.sd_sales_main_scm';
--137
comment on column dm.sb_wuc_backup.buyer_agent_code is 'Trading company (код) | Системный код промежуточного покупателя из клиентского лота.Если его нет, то из заявки под план производства.  | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.buyer_agent_name is 'Trading company | Наименование промежуточного покупателя из клиентского лота.Если его нет, то из заявки под план производства.  | dm_calc.sd_sales_main_scm';
--146
comment on column dm.sb_wuc_backup.pb1_number is 'Номер PB 1 | Внешняя идентификация 1-й накладной. | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pb2_number is 'Номер PB 2 | Внешняя идентификация 2-й накладной. | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pb3_number is 'Номер PB 3 | Внешняя идентификация 3-й накладной. | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pb1_warehouse_name is 'Склад PB 1 | Склад 1-й накладной. | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pb2_warehouse_name is 'Склад PB 2 | Склад 2-й накладной. | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.pb3_warehouse_name is 'Склад PB 3 | Склад 3-й накладной. | dm_calc.sd_sales_main_scm';
----	153
comment on column dm.sb_wuc_backup.sales_order_in_shipment is 'Заказ ЦК в отгрузке | ЦК - центральная компания.№ заказа центральной компании (заявки) под план производства. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. Изначально заказы ЦК вносятся в тразакции ZSD2882M-Регистрация заявок клиентов.  Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.is_tolling_code is 'Признак толлинг | Метка толлингово контракта в поставке | dm_calc.sd_sales_stock_by_date';
comment on column dm.sb_wuc_backup.location_stay_duration_category_code is 'Сроки нахождения в локации (месяц) |Отображает данные в формате (<=1M, >1M<=2M, >2M<=3M . тд). по полю "Сроки нахождения в локации" SD.000688 | 
<=1M», если "Сроки нахождения в локации" SD.000688
 ≤30 дней;
иначе 
«>1M<=2M», если "Сроки нахождения в локации" SD.000688 >30 дней и ≤60 дней;
иначе 
«>2M<=3M», если "Сроки нахождения в локации" SD.000688 >60 дней и ≤90 дней;
иначе 
«>3M<=6M», если "Сроки нахождения в локации" SD.000688 >90 дней и ≤180 дней;
иначе 
«>6M<=1Y», если "Сроки нахождения в локации" SD.000688 >180 дней и ≤365 дней;
иначе 
«>1Y», если "Сроки нахождения в локации" SD.000688 >365 дней;';
----	154
comment on column dm.sb_wuc_backup.dt_pb1_number is 'Дата PB 1 | Дата создания 1-й внешней накладной (PB) | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_pb2_number is 'Дата PB 2 | Дата создания 2-й внешней накладной (PB) | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.dt_pb3_number is 'Дата PB 3 | Дата создания 3-й внешней накладной (PB) | dm_calc.sd_sales_main_scm';
comment on column dm.sb_wuc_backup.business_location_for_reporting_name is 'Статус среза | Статус среза | dm_calc.sales_delivery_actual_business_location_by_date';
comment on column dm.sb_wuc_backup.plan_or_actual_code is 'Источник данных среза План/Факт | Признак того, на основании фактических (F) или плановых (P) данных рассчитан статус среза | dm_calc.sales_delivery_actual_business_location_by_date';
comment on column dm.sb_wuc_backup.receiving_warehouse_code is 'Принимающий склад | Принимающий склад | dm_calc.sd_sales_main_scm';
--215
COMMENT ON COLUMN dm.sb_wuc_backup.dt_shipment_actual IS 'Дата отгрузки из Shipdata | Дата отгрузки с завода производителя из Shipdata | dm_calc.sd_sales_main_scm.dt_shipment_actual';
---236
COMMENT ON COLUMN dm.sb_wuc_backup.dt_acceptance_in_russian_port_planned IS 'Плановая дата принятия в порту РФ | Плановая дата прнятия в порту РФ, дата прибытия со сроком приемки | dm_calc.sd_sales_main_scm.dt_acceptance_in_russian_port_planned';
---241
COMMENT ON COLUMN dm.sb_wuc_backup.vessel_load_daily_plan_weight IS 'Цель погрузки на судно | Дневная цель погрузки на судно в порту погрузки в тоннах | Рассчетное на dds.sales_location_stay_normative.normative_days_quantity для At Russian Port';
COMMENT ON COLUMN dm.sb_wuc_backup.vessel_load_daily_allocated_plan_weight IS 'Цель пропорциональная погрузки на судно | Пропорциональная девная цель погрузки на судно в порту погрузки в тоннах  | Рассчетное на dds.sales_location_stay_normative.normative_days_quantity для At Russian Port';
---237
--COMMENT ON COLUMN dm.sb_wuc_backup.forwarder_in_foreign_port_code IS 'Экспедитор в иностранном порту (код) | Код контрагента, осуществляющего прием и хранение готовой продукции на складе в ин. порту. | dm_calc.sales_delivery_actual_part_2.forwarder_in_foreign_port_code';   
