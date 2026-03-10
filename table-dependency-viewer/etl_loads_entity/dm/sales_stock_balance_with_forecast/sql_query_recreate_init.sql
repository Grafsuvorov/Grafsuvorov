drop table if exists dm.sales_stock_balance_with_forecast cascade;
/*select dt_report,delivery_number_sales,batch,warehouse_or_responsible_customer_for_storage_name
  from dm.sales_stock_balance_with_forecast 
  where delivery_number_sales is not null  
  group by dt_report,delivery_number_sales,batch,warehouse_or_responsible_customer_for_storage_name 
  having count(*)>1 
  order by dt_report desc
*/  
/*select *  
 from dm.sales_stock_balance_with_forecast 
 where dt_report='2025-10-21' and delivery_number_sales='0110370417' and batch='0013506626' */
create TABLE if not exists dm.sales_stock_balance_with_forecast (
    dt_report date NULL,                                                -- Отчетная дата
    delivery_number_sales varchar(30) NULL,                             -- Продажная поставка SD.000002
    batch varchar(30) NULL,                                             -- Партия SD.000004
    sales_order_in_shipment varchar(90) NULL,                           -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
    plant_producer_name varchar(90) NULL,                               -- Завод производитель SD.000007  
    tsw_location_name varchar(180) NULL,                                -- Направление SD.000009   
 	dt_shipment timestamp NULL,                                         -- Дата отгрузки SD.000010 
 	dt_arrival_by_railway date NULL,									-- Дата прибытия по ЖД SD.000011
	dt_forwarder date NULL,												-- Дата экспедитора SD.000012
	railcar varchar(60) NULL,											-- Вагон SD.000013
	transport_bill varchar(105) NULL,									-- Накладная SD.000014
	railway_platform varchar(36) NULL,									-- Платформа SD.000015
	material_aggr_name varchar(210) NULL,								-- Материал SD.000016
	material_group_code varchar(27) NULL,								-- Группа материалов SD.000017
    forwarder_name varchar(300) NULL,									-- Экспедитор SD.000021
 	dt_warehouse date NULL,												-- Дата склада SD.000024
	transport_railcar_type_name varchar(120) NULL,						-- Тип вагона SD.000029
	weight_gross numeric(13, 3) NULL,									-- Вес брутто SD.000031
	weight_net numeric(13, 3) NULL,										-- Вес нетто SD.000032
	weight_net_with_wirerod numeric(13, 3) NULL,						-- Вес Н&K SD.000033
	contract_name varchar(105) NULL, 									-- Контракт SD.000038
	bill_of_lading_number varchar(90) NULL,								-- Номер коносамента SD.000041
	dt_bill_of_lading date NULL,										-- Дата коносамента SD.000042
	port_of_discharge_name varchar(90) NULL,							-- Порт выгрузки SD.000045
	bill_of_lading_in_foreign_port varchar(90) NULL,					-- Коносамент в ин.порту SD.000048
	dt_bill_of_lading_in_foreign_port date NULL,						-- Дата коносамента в ин.порту SD.000049
	bill_of_lading_in_foreign_port_nomination varchar(60) NULL,			-- Номинация коносамента в ин. порту SD.000050
	port_of_discharge_in_foreign_port_name varchar(90) NULL,			-- Порт выгрузки 2 SD.000055
	dt_sailed_loading_port date NULL,									-- Дата отплытия из порта погрузки SD.000058
	dt_arrival_in_port_of_discharge date NULL,							-- Дата прибытия в порт выгрузки SD.000059
	dt_arrival_in_second_port_of_discharge date NULL,					-- Дата прибытия в порт выгрузки 2 SD.000060
	external_contract_in_lot_number	varchar(35) NULL,					-- Контракт в лоте SD.000063
	lot_customer_code varchar(30) NULL,									-- Покупатель в лоте (код) SD.000064
	lot_delivery_basis_code varchar(9) NULL,							-- Базис поставки в лоте SD.000065
	lot_delivery_point_name varchar(84) NULL,							-- Пункт доставки по инкотермс в лоте SD.000066
	delivery_basis varchar(9) NULL,										-- Базис поставки SD.000067
	delivery_point_name varchar(84) NULL,								-- Пункт доставки по инкотермс SD.000068
	receiving_plant_in_sap_system_code varchar(12) NULL,				-- Принимающий завод грузополучателя в системе SAP SD.000076
	dimensions_unit varchar(60) NULL,									-- Размер единицы готовой продукции SD.000079
	customs_declaration_number varchar(90) NULL,						-- Номер ГТД SD.000087
	material_specification_name varchar(150) NULL,						-- Спецификация SD.000089
	instruction_number varchar(30) NULL,								-- Номер распоряжения SD.000101
	pieces int8 NULL,													-- PCS SD.000115
	container_after_repacking varchar(60) NULL,							-- Контейнер после перетарки SD.000119
	sales_order varchar(18) NULL,										-- Заказ ЦК SD.000123
	customer_special_requirement varchar(150) NULL,						-- Трейдеры: спец. заказ клиента SD.000127
	dt_arrival_in_port_of_discharge_plan date NULL,						-- Дата прибытия в порт выгрузки план SD.000130
	dt_delivery_notice date NULL,										-- Дата нотиса о доставке SD.000132
	delivery_notice_number varchar(90) NULL,							-- Номер нотиса о доставке SD.000133
	vessel_plan_name varchar(120) NULL,									-- Судно план SD.000134
	vessel_in_foreign_port_actual_name varchar(120) NULL,				-- Судно факт в ин. порту SD.000142
	customer_grade_name varchar(90) NULL,								-- Марка клиента SD.000144
	grade_name varchar(90) NULL,										-- Марка по спецификации SD.000145
	contract_plan_name varchar(300) NULL,								-- Плановый контракт SD.000148
	uni varchar(180) NULL,												-- UNI SD.000151
	uni_in_shipment varchar(180) NULL,									-- UNI в отгрузке SD.000152
	pb_number varchar(105) NULL,										-- LotWshe/PB number SD.000158
	is_plan_or_actual varchar(3) NULL,									-- Признак План/Факт SD.000159
	dt_expected_delivery timestamp NULL,								-- Ожидаемая дата доставки до клиента SD.000162
	end_user_for_reporting_name	varchar(140) NULL,						-- Конечный потребитель SD.000164
	invoice_provisional_number varchar(90) NULL,						-- Инвойс (счет клиенту) SD.000167
	release_group_name varchar(90) NULL,								-- Релиз SD.000169
	pledge_in_bank_name varchar(420) NULL,								-- Pledge Bank SD.000172
	dt_storage_start_in_foreign_port date NULL,							-- Дата начала хранения ин. склад SD.000175
	dt_storage_end_in_foreign_port date NULL,							-- Окончание хранения в ин. порту SD.000176
	dt_storage_start_in_second_foreign_warehouse date NULL,				-- Начало хранения склад 2 SD.000177
	dt_storage_end_in_second_foreign_warehouse date NULL,				-- Окончание хранение склад 2 SD.000178
	sales_contract_code varchar(30) NULL,								-- Контракт сбыта (код) SD.000179
	material_shape_name_full varchar(90) NULL,							-- Форма SD.000180
	lot_customer_name varchar(450) NULL,                                -- Покупатель в лоте SD.000193                 --------------(!!!)
	dt_realization_forecast date null, 									-- Расчетная дата реализации SD.000243
	pledge_in_bank_code varchar(10) NULL,								-- Pledge Bank (code) SD.000252
	dt_expected_bill_of_lading date null,								-- Ожидаемая дата коносамента SD.000253
	delivery_instruction_code varchar(30) NULL,							-- Иструкция на доставку SD.000254
	incoterms_plan_code varchar(9) NULL,								-- Плановый базис поставки SD.000255
	incoterms_location_plan_code varchar(84) NULL,						-- Плановый пункт доставки по инкотермс SD.000256
	dt_release_material date NULL,										-- Дата ОМ SD.000259
	release_material_status_code varchar(3) null,                       -- Статус ОМ SD.000260
	delivery_region_name varchar(20) NULL,								-- Регион поставки по контракту SD.000338
	"location" varchar(45) NULL,                                        -- Локация SD.000339
	country_of_discharge_port_name varchar(45) NULL,                     --Страна POD SD.000341                       -------------(!!!)
	region_of_destination_port_name varchar(60) null,					-- Регион POD SD.000343
	dt_prepared_for_realization date NULL,								-- Дата готовности к реализации SD.000344
	port_of_destination_name varchar(30) NULL,							-- Порт назначения SD.000376
	is_consigment_warehouse_applicable varchar(1) NULL,					-- Признак консигнации SD.000480
	dt_transfer_from_consignment_to_customer date NULL,					-- Дата перехода из консигнации клиенту SD.000481
	dt_final_release date NULL,											-- Дата Финальный релиз SD.000482
	is_shipped_via_overseas_warehouse varchar(3) NULL,					-- Наличие Иностранный склад SD.000483
	dt_forwarder_discharge_invoice_or_cmr_documented date NULL,			-- ТН/CMR: Дата выгрузки авто SD.000484
	is_shipped_via_overseas_second_foreign_warehouse varchar(3) NULL,	-- Наличие Иностранный склад 2 SD.000485
	dt_arrived_via_ul_system date NULL,									-- Дата прибытия УЛ SD.000487
	dt_repacked date NULL,												-- Дата перетарки SD.000488
	warehouse_shipment_type_name varchar(90) NULL,						-- СВХ SD.000489
	warehouse_gross_weight varchar(17) NULL,							-- Вес брутто (с учетом склада) SD.000490
	railway_movement_status_name varchar(30) NULL,						-- Статус движения по ЖД SD.000491
	business_location_name varchar(50) NULL,							-- Статус в Supply chain (Business) SD.000492
	transportation_scenario_code varchar(2) NULL,						-- Сценарий маршрута SD.000550	
	delivery_country_in_contract_name varchar(150) NULL,					-- Страна поставки по контракту SD.000576
	commitment_weight numeric(15, 3) NULL,								-- Объем обязательств SD.000578
	total_commitment_weight numeric(15, 3) NULL,						-- Объем обязательств итого SD.000579
	lot_code varchar(30) NULL,											-- Номер лота SD.000580
	homogenisation_name varchar(30) NULL,								-- Гомогенизация SD.000581
	port_of_discharge_country_code varchar(3) NULL,						-- Страна порта выгрузки 1 SD.000582
	dt_warehouse_confirmation date NULL,								-- Дата Storage confirmation SD.000583
	dt_release date NULL,												-- Дата релиза SD.000585
	notice_name varchar(30) NULL,										-- Номер нотиса SD.000586
	dt_notice date NULL,												-- Дата нотиса SD.000587
	final_release_code varchar(30) NULL,								-- Номер Финальный релиз SD.000588
	dt_final_invoice_payment date NULL,									-- Дата оплаты Final Invoice SD.000589
	vehicle_in_foreign_port_code varchar(20) NULL,						-- Тип ТС в ин. порту (код) SD.000590
	vehicle_type_in_foreign_port_code varchar(4) NULL,					-- Тип ТС в ин. порту SD.000591
	pb1_number varchar(35) NULL,										-- Номер PB 1 SD.000592                  -------------(!!!)
	pb2_number varchar(35) NULL,										-- Номер PB 2 SD.000593                  -------------(!!!)
	pb3_number varchar(35) NULL,										-- Номер PB 3 SD.000594                  -------------(!!!)
	pb1_warehouse_name varchar(30) NULL,								-- Склад PB 1 SD.000595                  -------------(!!!)
	pb2_warehouse_name varchar(30) NULL,								-- Склад PB 2 SD.000596                  -------------(!!!)
	pb3_warehouse_name varchar(30) NULL,								-- Склад PB 3 SD.000597                  -------------(!!!)
	realization_status_name varchar(3) NULL,							-- Статус Реализации SD.000599	         -------------(!!!)
	exporter_name varchar(35) NULL,										-- Экспортёр SD.000600
	country_of_end_user_name varchar(150) NULL,							-- Страна конечного потребителя SD.000601
	buyer_plan_name varchar(450) NULL, 									-- Плановый покупатель SD.000602
	customer_for_scm_report_name varchar(450) NULL, 					-- Клиент для отчета Металл в Цепочке Поставок SD.000603
	material_group_for_scm_report_name varchar(30) NULL,				-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	assignment_name	varchar(30) NULL,									-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	vessel_and_voyage_plan_search_name varchar(180) NULL,               -- Судно / номер рейса (план) SD.000607
	vessel_and_voyage_actual_search_name varchar(180) NULL,             -- Судно / номер рейса (факт) SD.000608
	forwarder_in_foreign_port_name varchar(450) NULL,					-- Экспедитор в иностранном порту SD.000609
	dt_storage_payed_in_foreign_port_by_rusal date NULL,				-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	shipment_instruction_in_foreign_port_name varchar(30) NULL,			-- Инструкция на отгрузку Ин Порт SD.000612
	dt_shipment_instruction_in_foreign_port	date NULL,					-- Дата инструкции на отгрузку Ин Порт SD.000613
	dt_shipment_instruction_date_from date NULL,						-- SI: Дата с SD.000614
	dt_shipment_instruction_date_to	date NULL,							-- SI: Дата по SD.000615
	dt_barge_loading date NULL,											-- Дата погрузки на баржу SD.000616
	dt_barge_arrival date NULL,											-- Дата доставки баржи SD.000617
	shipment_instruction_in_second_foreign_port_name varchar(30) NULL,	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	dt_shipment_instruction_in_second_foreign_port date NULL,			-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	dt_invoice_provisional date NULL,									-- Дата инвойса SD.000620
	provisional_invoice_payment_status_code	varchar(3) NULL,			-- Статус оплаты инвойса SD.000621
	prepared_for_realization_status_name varchar(8) NULL,				-- Признак ППС (код) SD.000623
	mh1_storage_document_number varchar(60) NULL,						-- № Акта МХ-1 SD.000625
	dt_mh1_storage_document date NULL,									-- Дата Акта МХ-1 SD.000626
	mh3_storage_document_number varchar(60) NULL,						-- № Акта МХ-3 SD.000627
	dt_mh3_storage_document date NULL,									-- Дата Акта МХ-3 SD.000628
	dt_departure_from_foreigh_port date NULL,							-- EXP: Load out date SD.000629
	foreign_port_terminal_name varchar(30) NULL,                        -- EXP: Storage location SD.000630            -----------(!!!)
	russian_port_bill_of_lading_forwarder_code varchar(30) NULL,		-- EXP: WH Operator's code SD.000632
	foreign_port_bill_of_lading_forwarder_code varchar(30) NULL,		-- EXP: WH Operator's code 2 SD.000633
	uzbekistan_cargo_declaration_73	varchar(50) NULL,					-- EXP: ГТД ИМ73 SD.000634
	business_location_sap_precalc_name varchar(150) NULL,				-- Статус в Supply chain (Business) SD.000636
	ready_for_realization_status_name varchar(60) null,                 -- Статус готовности к реализации SD.000639
	country_of_destination_port_code varchar(30) NULL,					-- Страна порта назначения (код) SD.000646
	sales_team_name varchar(20) NULL,									-- Сбытовая команда SD.000651
	delivery_region_code varchar(10) NULL,								-- Регион поставки по контракту (код) SD.000652
	receiving_plant_in_sap_system_name varchar(50) NULL,				-- Завод собственник SD.000655
	dt_shipment_instruction date null, 									-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	shipment_instruction_name varchar(30) null,							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	dt_quota_yyyymm varchar(7) NULL,									-- Квота в формате гггг.мм SD.000687 
	storage_duration_in_calendar_days varchar(6) NULL,                  -- Сроки нахождения в локации SD.000688                 -------(!!!)
	buyer_agent_name varchar(35) null,									-- Trading company SD.000704                                       ---(!!!)
	dt_realization date NULL,											-- Дата реализации SD.000720
	internal_compound_key_code varchar(16) NULL,						-- Внутренний уникальный идентификатор записи SD.000721	
	is_tolling_code varchar(4) NULL,                                    -- Признак толлинг SD.000749 ------------(!!!)
	location_stay_duration_category_code varchar(10) NULL,              -- Сроки нахождения в локации (месяц) SD.000750
	customer_for_reporting_code	varchar(10) NULL,						-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
	warehouse_or_responsible_customer_for_storage_name varchar(450) NULL,   -- SD.000919 General storage location             
	customs_invoice_code varchar(10) NULL,								-- SD.000779 "Custom's invoice Group"
	customs_invoice_number varchar(30) NULL,							-- SD.000780 "Custom's invoice Number"
	dt_customs_invoice date NULL,										-- SD.000781 "Custom's invoice Date"
	dt_arrival_in_second_port_of_discharge_plan date NULL,				-- Дата прибытия в порт выгрузки 2 план SD.000157
	dt_acceptance_in_russian_port_planned date NULL,              		-- SD.000705 Плановая дата принятия в порту РФ 
	dt_shipment_yyyymm varchar(7) NULL, 								-- SD.000893 "Месяц Дата отгрузки с завода"
	--236
	material_group_name varchar(180) NULL,                              --SD.0000?? Группа материала название
	buyer_plan_code varchar(30) NULL,                                   -- SD.000124 Плановый покупатель (код)
	------------------------------------------------  
	-----272 доработка
	dt_train_scheduled_arrival date NULL,	 			             --SD.000697 Плановая дата прибытия по ЖД (с фактом)  
	--274 доработка
	dt_bill_of_lading_in_russian_port_created date NULL,            --SD.001214 Дата загрузки Коносамента РФ в САП
	dt_bill_of_lading_in_foreign_port_created date NULL,            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	dt_bill_of_lading_in_russian_port_scan_copy_uploaded date NULL, --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	bill_of_lading_group_code_in_foreign_port varchar(30) null,     --SD.000047 Группа коносамента в ин.порту 
	dt_bill_of_lading_in_foreign_port_scan_copy_uploaded date null, --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта       
	--295
	delivery_country_in_contract_code varchar null,                     --SD.000577 Страна поставки по контракту (код)
	--302
	country_of_consignee_code varchar null,                             --SD.001360 Код страны грузоплучателя    
	--311
	storage_duration_in_russian_port_in_calendar_days integer null,         --SD.001385 Количество дней хранения в порту РФ
	storage_duration_in_russian_port_category_code varchar null,            --SD.001386 Категория хранения в порту РФ
	dt_arrival_by_railway_planned date NULL,					--SD.001395 Плановая дата прибытия по жд (нормативная)                                                         
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
DISTRIBUTED by (delivery_number_sales);

comment on table dm.sales_stock_balance_with_forecast is 'Отчет по стокам (плановый и реализованный металл)';
comment on column dm.sales_stock_balance_with_forecast.dt_report is 'Отчетная дата | Отчетная дата | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.dt_report';
comment on column dm.sales_stock_balance_with_forecast.delivery_number_sales is 'Продажная поставка | Если поставка разделена, то деленная поставка, если нет, то Исходная поставка. Если отгрузка через агента (РТД) - выводится поставка завода производителя | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_number_sales';
comment on column dm.sales_stock_balance_with_forecast.batch is 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.batch';
comment on column dm.sales_stock_balance_with_forecast.sales_order_in_shipment is 'Заказ ЦК в отгрузке | ЦК - центральная компания. № заказа центральной компании (заявки) под план производства. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. Изначально заказы ЦК вносятся в тразакции ZSD2882M-Регистрация заявок клиентов.  Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.sales_order_in_shipment';
comment on column dm.sales_stock_balance_with_forecast.plant_producer_name is 'Завод | Название завода производителя | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.plant_producer_name';
comment on column dm.sales_stock_balance_with_forecast.tsw_location_name is 'Направление | Название порта погрузки | dm_calc.sales_stock_realised_by_date sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.tsw_location_name';
comment on column dm.sales_stock_balance_with_forecast.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.dt_shipment';
comment on column dm.sales_stock_balance_with_forecast.dt_arrival_by_railway is 'Дата прибытия по ЖД | Дата прибытия вагона по железной дороге на конечную станцию | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_arrival_by_railway';
comment on column dm.sales_stock_balance_with_forecast.dt_forwarder is 'Дата экспедитора | Дата, когда экспедитор принял груз на склад, и подготовил документы для экспорта - готовность к вывозу | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_forwarder';
comment on column dm.sales_stock_balance_with_forecast.railcar is 'Вагон | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.railcar';
comment on column dm.sales_stock_balance_with_forecast.transport_bill is 'Накладная | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.transport_bill';
comment on column dm.sales_stock_balance_with_forecast.railway_platform is 'Платформа | Номер платформы, на которой передвигается контейнер, по  жд  от Завода производителя. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.railway_platform';
comment on column dm.sales_stock_balance_with_forecast.material_aggr_name is 'Материал | Код признака «Материал». Применяется для готовой алюминиевой продукции. Например, для кода материала APT0006ING0045, код признака Материл = COMMODITY | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.material_aggr_name';
comment on column dm.sales_stock_balance_with_forecast.material_group_code is 'Группа материалов | Группа материалов. Например, для кода материала APT0006ING0045, код Группа материалов = A02-Алюминий первичный АТЧ, раскисленный. | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.material_group_code';
comment on column dm.sales_stock_balance_with_forecast.forwarder_name is 'Экспедитор | Название экспедитора,  который примет груз, после его прибытия с завода в конечную точку по жд или авто, и который  подготовит документы для экспорта. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.forwarder_name';
comment on column dm.sales_stock_balance_with_forecast.dt_warehouse is 'Дата склада | Дата прибытия на склад порта, когда экспедитор принял груз на склад | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_warehouse';
comment on column dm.sales_stock_balance_with_forecast.transport_railcar_type_name is 'Тип вагона | Название  типа вагона на текущий момент | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.transport_railcar_type_name';
comment on column dm.sales_stock_balance_with_forecast.weight_gross is 'Вес брутто | Вес брутто | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.weight_gross';
comment on column dm.sales_stock_balance_with_forecast.weight_net is 'Вес нетто | Вес нетто | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.weight_net';
comment on column dm.sales_stock_balance_with_forecast.weight_net_with_wirerod is 'Вес Н&K | Вес нетто + катанки | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.weight_net_with_wirerod';
comment on column dm.sales_stock_balance_with_forecast.contract_name is 'Контракт | Номер контракта из клиентского лота, если его нет, то  Плановый контракт  из заявки под план производства | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.contract_name';
comment on column dm.sales_stock_balance_with_forecast.bill_of_lading_number is 'Номер коносамента | Номер коносамента из РФ, номер на бумажном носителе. Документ, который используют в водных перевозках. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.bill_of_lading_number';
comment on column dm.sales_stock_balance_with_forecast.dt_bill_of_lading is 'Дата коносамента | Дата коносамента из РФ. Документ, который используют в водных перевозках из российских портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_bill_of_lading';
comment on column dm.sales_stock_balance_with_forecast.port_of_discharge_name is 'Порт выгрузки | Порт выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, BUSAN | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.port_of_discharge_name';
comment on column dm.sales_stock_balance_with_forecast.bill_of_lading_in_foreign_port is 'Коносамент в ин.порту | Номер коносамента в ин. порту, номер на бумажном носителе. Документ, который используют в водных перевозках из иностранных портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.bill_of_lading_in_foreign_port';
comment on column dm.sales_stock_balance_with_forecast.dt_bill_of_lading_in_foreign_port is 'Дата коносамента в ин.порту | Дата коносамента в ин. порту,  документ, который используют в водных перевозках из иностранных портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_bill_of_lading_in_foreign_port';
comment on column dm.sales_stock_balance_with_forecast.bill_of_lading_in_foreign_port_nomination is 'Номинация коносамента в ин. порту | Номинация (номер документа) коносамента в ин. порту. Номинация  это процесс назначения судна на выполнение определенного вида работ. Этот процесс происходит между клиентом и агентом, который занимается организацией перевозки грузов. Номинация сообщает владельцу или управляющей компании судна о предстоящих заданиях и условиях работы. В одну номинацию могут быть включены несколько коносаментов | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.bill_of_lading_in_foreign_port_nomination';
comment on column dm.sales_stock_balance_with_forecast.port_of_discharge_in_foreign_port_name is 'Порт выгрузки 2 | Порт погрузки  (место назначения из Маршрута коносамента в ин. порту.) | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.port_of_discharge_in_foreign_port_name';
comment on column dm.sales_stock_balance_with_forecast.dt_sailed_loading_port is 'Sailed L.Port | Дата отплытия из порта погрузки | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_sailed_loading_port';
comment on column dm.sales_stock_balance_with_forecast.dt_arrival_in_port_of_discharge is 'Дата прибытия в порт выгрузки | Дата прибытия в порт выгрузки из коносамента | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_arrival_in_port_of_discharge';
comment on column dm.sales_stock_balance_with_forecast.dt_arrival_in_second_port_of_discharge is 'Дата прибытия в порт выгрузки 2 | Дата прибытия в порт выгрузки из коносамента в ин. порту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_arrival_in_second_port_of_discharge';
comment on column dm.sales_stock_balance_with_forecast.external_contract_in_lot_number is 'Контракт в лоте | Контракт из группы Лот | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.external_contract_in_lot_number';
comment on column dm.sales_stock_balance_with_forecast.lot_customer_code is 'Покупатель в лоте (код) | Покупатель  из группы Лот. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.lot_customer_code';
comment on column dm.sales_stock_balance_with_forecast.lot_delivery_basis_code is 'Базис поставки в лоте | Базис поставки (Инкотермс 1) из группы Лот | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.lot_delivery_basis_code';
comment on column dm.sales_stock_balance_with_forecast.lot_delivery_point_name is 'Пункт доставки по инкотермс в лоте | Пункт доставки по инкотермс  из группы Лот | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.lot_delivery_point_name';
comment on column dm.sales_stock_balance_with_forecast.delivery_basis is 'Базис поставки | Базис поставки (Инкотермс 1), это правило поставки Инкотермс.  | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_basis';
comment on column dm.sales_stock_balance_with_forecast.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс (Инкотермс 2), это место передачи груза, это может быть город, аэропорт, морской либо речной порт | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.sales_stock_realised.delivery_point_name';
comment on column dm.sales_stock_balance_with_forecast.receiving_plant_in_sap_system_code is 'Принимающий завод грузополучателя в системе SAP | Системный номер завода оператора, собственника продукции при реализации клиенту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.receiving_plant_in_sap_system_code';
comment on column dm.sales_stock_balance_with_forecast.dimensions_unit is 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.dimensions_unit';
comment on column dm.sales_stock_balance_with_forecast.customs_declaration_number is 'Номер ГТД | Номер грузовой таможенной декларации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.customs_declaration_number';
comment on column dm.sales_stock_balance_with_forecast.material_specification_name is 'Спецификация | Название документа с набором требований, которым должен соответствовать разрабатываемый продукт | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.material_specification_name';
comment on column dm.sales_stock_balance_with_forecast.instruction_number is 'Номер распоряжения | Номер распоряжения на отгрузку (номер заказа в системе), создается только для отгрузок на внутренний рынок и СНГ, этот документ является указанием к отгрузке Заводу производителю, в нем указано кому, что и сколько нужно отгрузить. Распоряжение на отгрузку создается ДСБ по контракту с клиентом из Заказа ЦК в отгрузке (в тразакции ZSD2882M-Регистрация заявок клиентов) и выдается производителю. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.instruction_number';
comment on column dm.sales_stock_balance_with_forecast.pieces is 'PCS | Количество грузовых мест в поставке | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pieces';
comment on column dm.sales_stock_balance_with_forecast.container_after_repacking is 'Контейнер после перетарки | Номер транспортного средства после перетарки | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.container_after_repacking';
comment on column dm.sales_stock_balance_with_forecast.sales_order is 'Заказ ЦК | Это системный номер заказа ЦК в отгрузке | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.sales_order';
comment on column dm.sales_stock_balance_with_forecast.customer_special_requirement is 'Трейдеры: спец. заказ клиента | Номер заказа клиента, инфо берем из клиентского лота, еслти лота нет то из транзакции ZSD2882M-Регистрация заявок клиентов | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.customer_special_requirement';
comment on column dm.sales_stock_balance_with_forecast.dt_arrival_in_port_of_discharge_plan is 'Дата прибытия в порт выгрузки план | Плановая дата прибытия в порт выгрузки по коносаменту РФ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_arrival_in_port_of_discharge_plan';
comment on column dm.sales_stock_balance_with_forecast.dt_delivery_notice is 'Дата нотиса о доставке | Дата документа, который создает ДСБ (дирекция по сбыту) для базисов поставки  DDP или DAP для отражения даты доставки клиенту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_delivery_notice';
comment on column dm.sales_stock_balance_with_forecast.delivery_notice_number is 'Номер нотиса о доставке | Номер документа (на бумажном носителе), который создает ДСБ (дирекция по сбыту) для базисов поставки  DDP или DAP для отражения даты доставки клиенту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_notice_number';
comment on column dm.sales_stock_balance_with_forecast.vessel_plan_name is 'Судно план | Название судна согласно справочнику OIGVT из плановой номинации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.vessel_plan_name';
comment on column dm.sales_stock_balance_with_forecast.vessel_in_foreign_port_actual_name is 'Судно факт в ин. порту | Название судна из Номинации коносамента в ин. порту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.vessel_in_foreign_port_actual_name';
comment on column dm.sales_stock_balance_with_forecast.customer_grade_name is 'Марка клиента | Код марки материала клиента  | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.customer_grade_name';
comment on column dm.sales_stock_balance_with_forecast.grade_name is 'Марка по спецификации | Наименование марки по спецификации | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.grade_name';
comment on column dm.sales_stock_balance_with_forecast.contract_plan_name is 'Плановый контракт | Номер договора с клиентом, по которому предполагется продажа, поэтому это плановый контракт | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.contract_plan_name';
comment on column dm.sales_stock_balance_with_forecast.uni is 'UNI | UNI | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.uni';
comment on column dm.sales_stock_balance_with_forecast.uni_in_shipment is 'UNI в отгрузке | «Накладная» и «Вагон» разделенные знаком‘-’ | dm_calc.sales_stock_realised_by_date sd_sales_stock_by_date, sd_sales_svh_stock_by_date.uni_in_shipment';
comment on column dm.sales_stock_balance_with_forecast.pb_number is 'LotWshe/PB number | Внешняя идентификация накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb_number';
comment on column dm.sales_stock_balance_with_forecast.is_plan_or_actual is 'Признак План/Факт | Идентификатор отгрузки от завода производителя | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.is_plan_or_actual';
comment on column dm.sales_stock_balance_with_forecast.dt_expected_delivery is 'Expected delivery | Ожидаемая дата доставки до клиента, является расчетной. Формула рассчета зависит от «Сценарий маршрута». | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_expected_delivery';
comment on column dm.sales_stock_balance_with_forecast.end_user_for_reporting_name is 'Конечный потребитель | Имя контрагента, который является потребителем металла, т.е. будет использовальзовать метал для производства своей продукции | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.sales_stock_realised.end_user_for_reporting_name';
comment on column dm.sales_stock_balance_with_forecast.invoice_provisional_number is 'Provisional invoice | Инвойс (счет клиенту), он может быть предварительным или окончательным. Предварительный - когда указывают цену, в которой ещё не уверены.  | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.invoice_provisional_number';
comment on column dm.sales_stock_balance_with_forecast.release_group_name is 'Релиз | Документ, который дает право распоряжения грузом, один из документов перехода права собственности | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.release_group_name';
comment on column dm.sales_stock_balance_with_forecast.pledge_in_bank_name is 'Pledge Bank | Имя кредитора, который открыл нам кредитную линию по залогу, то у кого мы взяли деньги | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pledge_in_bank_name';
comment on column dm.sales_stock_balance_with_forecast.dt_storage_start_in_foreign_port is 'Дата начала хранения ин. склад | Дата начала хранения металла на удаленном складе, после поступления груза в ин. порт из РФ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_storage_start_in_foreign_port';
comment on column dm.sales_stock_balance_with_forecast.dt_storage_end_in_foreign_port is 'Окончание хранения в ин. порту | Дата окончания хранения металла на удаленном складе, после поступления груза в ин. порт из РФ  | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_storage_end_in_foreign_port';
comment on column dm.sales_stock_balance_with_forecast.dt_storage_start_in_second_foreign_warehouse is 'Начало хранения склад 2 | Дата начала хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт  | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_storage_start_in_second_foreign_warehouse';
comment on column dm.sales_stock_balance_with_forecast.dt_storage_end_in_second_foreign_warehouse is 'Окончание хранение склад 2 | Дата окончания хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт  | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_storage_end_in_second_foreign_warehouse';
comment on column dm.sales_stock_balance_with_forecast.sales_contract_code is 'Контракт сбыта (код) | Контракт сбыта (код) | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.sales_contract_code';
comment on column dm.sales_stock_balance_with_forecast.material_shape_name_full is 'Форма | Форма | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.material_shape_name_full';
comment on column dm.sales_stock_balance_with_forecast.lot_customer_name is 'Покупатель в лоте | Покупатель в лоте | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.lot_customer_name';
comment on column dm.sales_stock_balance_with_forecast.dt_realization_forecast is 'Расчетная дата реализации | Расчетная дата реализации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_realization_forecast';
comment on column dm.sales_stock_balance_with_forecast.pledge_in_bank_code is 'Pledge Bank | Имя кредитора, который открыл нам кредитную линию по залогу, то у кого мы взяли деньги. Залог- это кредитная линия под проценты/комиссию, под залог метала или дебиторской задолженности, в зависимости от вида заключенного договора. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pledge_in_bank_code';
comment on column dm.sales_stock_balance_with_forecast.dt_expected_bill_of_lading is 'Ожидаемая дата коносамента | Ожидаемая дата коносамента | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_expected_bill_of_lading';
comment on column dm.sales_stock_balance_with_forecast.delivery_instruction_code is 'Инструкция на доставку | Инструкция на доставку | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_instruction_code';
comment on column dm.sales_stock_balance_with_forecast.incoterms_plan_code is 'Плановый базис поставки | Плановый базис поставки | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.incoterms_plan_code';
comment on column dm.sales_stock_balance_with_forecast.incoterms_location_plan_code is 'Плановый пункт доставки по инкотермс | Плановый пункт доставки по инкотермс | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.incoterms_location_plan_code';
comment on column dm.sales_stock_balance_with_forecast.dt_release_material is 'Дата ОМ | Дата проводки ОМ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_release_material';
comment on column dm.sales_stock_balance_with_forecast.release_material_status_code is 'Статус ОМ | Статус проводки ОМ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.release_material_status_code';
comment on column dm.sales_stock_balance_with_forecast.delivery_region_name is 'Регион поставки по контракту | Регион поставки по контракту | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_region_name';
comment on column dm.sales_stock_balance_with_forecast."location" is 'Локация | Локация | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.location';
comment on column dm.sales_stock_balance_with_forecast.country_of_discharge_port_name is 'Страна POD | Страна POD | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.country_of_discharge_port_name';
comment on column dm.sales_stock_balance_with_forecast.region_of_destination_port_name is 'Регион POD | Регион POD | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.region_of_destination_port_name';
comment on column dm.sales_stock_balance_with_forecast.dt_prepared_for_realization is 'Дата готовности к реализации | Дата готовности к реализации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_prepared_for_realization';
comment on column dm.sales_stock_balance_with_forecast.port_of_destination_name is 'Порт назначения | Порт назначения | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.port_of_destination_name';
comment on column dm.sales_stock_balance_with_forecast.is_consigment_warehouse_applicable is 'Признак консигнации | Отображает "X" при налиичии в логистике Консигнационного склада | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.is_consigment_warehouse_applicable';
comment on column dm.sales_stock_balance_with_forecast.dt_transfer_from_consignment_to_customer is 'Дата перехода из консигнации клиенту | Отображает дату - «Дата Provisional Invoice» если «Признак консигнации» = X | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_transfer_from_consignment_to_customer';
comment on column dm.sales_stock_balance_with_forecast.dt_final_release is 'Дата Финальный релиз | Отображает дату созданого финального релиза | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_final_release';
comment on column dm.sales_stock_balance_with_forecast.is_shipped_via_overseas_warehouse is 'Наличие Иностранный склад | Отображает метку наличия промежуточного склада 1  в логистике | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.is_shipped_via_overseas_warehouse';
comment on column dm.sales_stock_balance_with_forecast.dt_forwarder_discharge_invoice_or_cmr_documented is 'ТН/CMR: Дата выгрузки авто | Экспедиторская дата выгрузки автотранспорта | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_forwarder_discharge_invoice_or_cmr_documented';
comment on column dm.sales_stock_balance_with_forecast.is_shipped_via_overseas_second_foreign_warehouse is 'Наличие Иностранный склад 2 | Отображает метку наличия промежуточного склада 2  в логистике | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.is_shipped_via_overseas_second_foreign_warehouse';
comment on column dm.sales_stock_balance_with_forecast.dt_arrived_via_ul_system is 'Дата прибытия УЛ | Отображает дату прибытия отправленную нам с интеграцией с Умной логистикой | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_arrived_via_ul_system';
comment on column dm.sales_stock_balance_with_forecast.dt_repacked is 'Дата перетарки | Экспедиторская дата перетарки | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_repacked';
comment on column dm.sales_stock_balance_with_forecast.warehouse_shipment_type_name is 'СВХ | Отображает тип СВХ: "На склад клиенту"; "Со склада клиенту" | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.warehouse_shipment_type_name';
comment on column dm.sales_stock_balance_with_forecast.warehouse_gross_weight is 'Вес брутто (с учетом склада) | Расчетный вес. Уменьшается с потреблением материала со склада | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.warehouse_gross_weight';
comment on column dm.sales_stock_balance_with_forecast.railway_movement_status_name is 'Статус движения по ЖД | Статус движения по ЖД | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.railway_movement_status_name';
comment on column dm.sales_stock_balance_with_forecast.business_location_name is 'Статус в Supply chain (Business) | Статус логистического этапа транспортировки/хранения | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date, finish_goods_warehouse_stock_plant_by_date.business_location_name';
comment on column dm.sales_stock_balance_with_forecast.transportation_scenario_code is 'Сценарий маршрута | Сценарий маршрута | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.transportation_scenario_code';
comment on column dm.sales_stock_balance_with_forecast.delivery_country_in_contract_name is 'Страна поставки по контракту | Страна поставки по контракту | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_country_in_contract_name';
comment on column dm.sales_stock_balance_with_forecast.commitment_weight is 'Объем обязательств | Объем обязательств | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.commitment_weight';
comment on column dm.sales_stock_balance_with_forecast.total_commitment_weight is 'Объем обязательств | Объем обязательств | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.total_commitment_weight';
comment on column dm.sales_stock_balance_with_forecast.lot_code is 'Номер лота | Номер лота | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.lot_code';
comment on column dm.sales_stock_balance_with_forecast.homogenisation_name is 'HMG | Гомогенизация | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.homogenisation_name';
comment on column dm.sales_stock_balance_with_forecast.port_of_discharge_country_code is 'Страна порта выгрузки | Страна порта выгрузки 1 | dm_calc.sales_stock_realised_by_date, sales_stock_forecast_hist, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.port_of_discharge_country_code';
comment on column dm.sales_stock_balance_with_forecast.dt_warehouse_confirmation is 'Дата Storage confirmation | Дата Storage confirmation | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_warehouse_confirmation';
comment on column dm.sales_stock_balance_with_forecast.dt_release is 'Дата релиза | Дата релиза | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_release';
comment on column dm.sales_stock_balance_with_forecast.notice_name is 'Номер нотиса | Номер нотиса | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.notice_name';
comment on column dm.sales_stock_balance_with_forecast.dt_notice is 'Дата нотиса | Дата нотиса | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_notice';
comment on column dm.sales_stock_balance_with_forecast.final_release_code is 'Номер Финальный релиз | Номер Финальный релиз | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.final_release_code';
comment on column dm.sales_stock_balance_with_forecast.dt_final_invoice_payment is 'Дата оплаты Final Invoice | Дата оплаты Final Invoice | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_final_invoice_payment';
comment on column dm.sales_stock_balance_with_forecast.vehicle_in_foreign_port_code is 'Тип ТС в ин. порту (код) | Тип ТС в ин. порту (код) | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.vehicle_in_foreign_port_code';
comment on column dm.sales_stock_balance_with_forecast.vehicle_type_in_foreign_port_code is 'Тип ТС в ин. порту | Тип ТС в ин. порту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.vehicle_type_in_foreign_port_code';
comment on column dm.sales_stock_balance_with_forecast.pb1_number is 'Номер PB 1 | Внешняя идентификация 1-й накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb1_number';
comment on column dm.sales_stock_balance_with_forecast.pb2_number is 'Номер PB 2 | Внешняя идентификация 2-й накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb2_number';
comment on column dm.sales_stock_balance_with_forecast.pb3_number is 'Номер PB 3 | Внешняя идентификация 3-й накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb3_number';
comment on column dm.sales_stock_balance_with_forecast.pb1_warehouse_name is 'Склад PB 1 | Склад 1-й накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb1_warehouse_name';
comment on column dm.sales_stock_balance_with_forecast.pb2_warehouse_name is 'Склад PB 2 | Склад 2-й накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb2_warehouse_name';
comment on column dm.sales_stock_balance_with_forecast.pb3_warehouse_name is 'Склад PB 3 | Склад 3-й накладной | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.pb3_warehouse_name';
comment on column dm.sales_stock_balance_with_forecast.realization_status_name is 'Статус Реализации | Статус Реализации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.realization_status_name';
comment on column dm.sales_stock_balance_with_forecast.exporter_name is 'Экспортёр | Экспортёр | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.exporter_name';
comment on column dm.sales_stock_balance_with_forecast.country_of_end_user_name is 'Страна конечного потребителя | Страна конечного потребителя | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.country_of_end_user_name';
comment on column dm.sales_stock_balance_with_forecast.buyer_plan_name is 'Плановый покупатель | Плановый покупатель | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.buyer_plan_name';
comment on column dm.sales_stock_balance_with_forecast.customer_for_scm_report_name is 'Клиент для отчета Металл в Цепочке Поставок | Клиент для отчета Металл в Цепочке Поставок | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.customer_for_scm_report_name';
comment on column dm.sales_stock_balance_with_forecast.material_group_for_scm_report_name is 'Группа материала для отчета Металл в Цепочке Поставок | Группа материала для отчета Металл в Цепочке Поставок | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.material_group_for_scm_report_name';
comment on column dm.sales_stock_balance_with_forecast.assignment_name is 'Поручение | Поручение | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.assignment_name';
comment on column dm.sales_stock_balance_with_forecast.vessel_and_voyage_plan_search_name is 'Судно / номер рейса (план) | Судно / номер рейса (план) | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.vessel_and_voyage_plan_search_name';
comment on column dm.sales_stock_balance_with_forecast.vessel_and_voyage_actual_search_name is 'Судно / номер рейса (факт) | Судно / номер рейса (факт) | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.vessel_and_voyage_actual_search_name';
comment on column dm.sales_stock_balance_with_forecast.forwarder_in_foreign_port_name is 'Экспедитор в иностранном порту | Экспедитор в иностранном порту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.forwarder_in_foreign_port_name';
comment on column dm.sales_stock_balance_with_forecast.dt_storage_payed_in_foreign_port_by_rusal is 'Дата окончания хранения на складе за счет RUSAL по Релизу | Дата окончания хранения на складе за счет RUSAL по Релизу | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_storage_payed_in_foreign_port_by_rusal';
comment on column dm.sales_stock_balance_with_forecast.shipment_instruction_in_foreign_port_name is 'Инструкция на отгрузку Ин Порт | Инструкция на отгрузку Ин Порт | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.shipment_instruction_in_foreign_port_name';
comment on column dm.sales_stock_balance_with_forecast.dt_shipment_instruction_in_foreign_port is 'Дата инструкции на отгрузку Ин Порт | Дата инструкции на отгрузку Ин Порт | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_shipment_instruction_in_foreign_port';
comment on column dm.sales_stock_balance_with_forecast.dt_shipment_instruction_date_from is 'SI: Дата с | Инструкция на отгрузку хранение по графику "Дата с" | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_shipment_instruction_date_from';
comment on column dm.sales_stock_balance_with_forecast.dt_shipment_instruction_date_to is 'SI: Дата по | Инструкция на отгрузку хранение по графику "Дата по" | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_shipment_instruction_date_to';
comment on column dm.sales_stock_balance_with_forecast.dt_barge_loading is 'Дата погрузки на баржу | Дата баржевого коносамента | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_barge_loading';
comment on column dm.sales_stock_balance_with_forecast.dt_barge_arrival is 'Дата доставки баржи | Доставка по баржевому коносаменту | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_barge_arrival';
comment on column dm.sales_stock_balance_with_forecast.shipment_instruction_in_second_foreign_port_name is 'Инструкция на отгрузку Ин Порт 2 | Инструкция на отгрузку Ин Порт 2 | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.shipment_instruction_in_second_foreign_port_name';
comment on column dm.sales_stock_balance_with_forecast.dt_shipment_instruction_in_second_foreign_port is 'Дата инструкции на отгрузку Ин Порт 2 | Дата инструкции на отгрузку Ин Порт 2 | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_shipment_instruction_in_second_foreign_port';
comment on column dm.sales_stock_balance_with_forecast.dt_invoice_provisional is 'Дата инвойса | Дата предварительного инвойса | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_invoice_provisional';
comment on column dm.sales_stock_balance_with_forecast.provisional_invoice_payment_status_code is 'Статус оплаты инвойса | Статус оплаты предварительного инвойса | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.provisional_invoice_payment_status_code';
comment on column dm.sales_stock_balance_with_forecast.prepared_for_realization_status_name is 'Признак ППС (код) | Статус готовности к реализации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.prepared_for_realization_status_name';
comment on column dm.sales_stock_balance_with_forecast.mh1_storage_document_number is '№ Акта МХ-1 | Акт на склад СВХ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.mh1_storage_document_number';
comment on column dm.sales_stock_balance_with_forecast.dt_mh1_storage_document is 'Дата Акта МХ-1 | Дата акта на склад СВХ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_mh1_storage_document';
comment on column dm.sales_stock_balance_with_forecast.mh3_storage_document_number is '№ Акта МХ-3 | Акт со склада СВХ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.mh3_storage_document_number';
comment on column dm.sales_stock_balance_with_forecast.dt_mh3_storage_document is 'Дата Акта МХ-3 | Дата акта со склада СВХ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_mh3_storage_document';
comment on column dm.sales_stock_balance_with_forecast.dt_departure_from_foreigh_port is 'EXP: Load out date | EXP: Load out date | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_departure_from_foreigh_port';
comment on column dm.sales_stock_balance_with_forecast.foreign_port_terminal_name is 'EXP: Storage location | EXP: Storage location | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.foreign_port_terminal_name';
comment on column dm.sales_stock_balance_with_forecast.russian_port_bill_of_lading_forwarder_code is 'EXP: WH Operators code | EXP: WH Operators code | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.russian_port_bill_of_lading_forwarder_code';
comment on column dm.sales_stock_balance_with_forecast.foreign_port_bill_of_lading_forwarder_code is 'EXP: WH Operators code 2 | EXP: WH Operators code 2 | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.foreign_port_bill_of_lading_forwarder_code';
comment on column dm.sales_stock_balance_with_forecast.uzbekistan_cargo_declaration_73 is 'EXP: ГТД ИМ73 | EXP: ГТД ИМ73 | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.uzbekistan_cargo_declaration_73';
comment on column dm.sales_stock_balance_with_forecast.business_location_sap_precalc_name is 'Статус в Supply chain (SAP) | Статус логистического этапа транспортировки/хранения из интеграционной таблицы | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.business_location_sap_precalc_name';
comment on column dm.sales_stock_balance_with_forecast.ready_for_realization_status_name is 'Статус готовности к реализации  | Статус готовности к реализации  | dm_calc.sales_stock_realised_by_date.ready_for_realization_status_name';
comment on column dm.sales_stock_balance_with_forecast.country_of_destination_port_code is 'Страна порта назначения (код) | Код страны порта назначения | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.country_of_destination_port_code';
comment on column dm.sales_stock_balance_with_forecast.sales_team_name is 'Сбытовая команда | Сбытовая команда | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.sales_team_name';
comment on column dm.sales_stock_balance_with_forecast.delivery_region_code is 'Регион поставки по контракту (код) | Регион поставки по контракту (код) | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.delivery_region_code';
comment on column dm.sales_stock_balance_with_forecast.receiving_plant_in_sap_system_name is 'Завод собственник | Принимающий завод грузополучателя в системе SAP | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.receiving_plant_in_sap_system_name';
comment on column dm.sales_stock_balance_with_forecast.dt_shipment_instruction is 'Дата инструкции ДСБ | Номер инструкции на отгрузку в порту РФ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_shipment_instruction';
comment on column dm.sales_stock_balance_with_forecast.shipment_instruction_name is 'Номер инструкции ДСБ  | Номинация инструкции на отгрузку в порту РФ | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.shipment_instruction_name';
comment on column dm.sales_stock_balance_with_forecast.dt_quota_yyyymm is 'Квота в формате гггг.мм | Квота из клиентского лота, если его нет, то Квота  из заявки под план производства | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_quota_yyyymm';
comment on column dm.sales_stock_balance_with_forecast.storage_duration_in_calendar_days is 'Сроки нахождения в локации| Сроки нахождения в локации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.storage_duration_in_calendar_days';
comment on column dm.sales_stock_balance_with_forecast.buyer_agent_name is 'Trading company | Наименование промежуточного покупателя из клиентского лота. Если его нет, то из заявки под план производства. | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.buyer_agent_name';
comment on column dm.sales_stock_balance_with_forecast.dt_realization is 'Дата реализации | Дата реализации | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.dt_realization';
comment on column dm.sales_stock_balance_with_forecast.internal_compound_key_code is 'Внутренний уникальный идентификатор записи | Внутренний уникальный идентификатор записи | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.internal_compound_key_code';
comment on column dm.sales_stock_balance_with_forecast.is_tolling_code is 'Признак толлинг | Метка толлингово контракта в поставке | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.is_tolling_code';
comment on column dm.sales_stock_balance_with_forecast.location_stay_duration_category_code is 'Сроки нахождения в локации (месяц) | Сроки нахождения в локации (месяц) | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.storage_duration_in_calendar_days';
comment on column dm.sales_stock_balance_with_forecast.customer_for_reporting_code	is 'Код САП клиента для отчета Металл в Цепочке Поставок | Код САП клиента для отчета Металл в Цепочке Поставок | dm_calc.sales_stock_realised_by_date, sd_sales_stock_by_date, sd_sales_svh_stock_by_date.storage_duration_in_calendar_days';
comment on column dm.sales_stock_balance_with_forecast.warehouse_or_responsible_customer_for_storage_name	is 'General storage location | General storage location | dm_calc.sd_sales_stock_by_date, sd_sales_svh_stock_by_date.warehouse_or_responsible_customer_for_storage_name';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.customs_invoice_code is 'Custom"s invoice Group | Группа документа Custom"s invoice | dm_calc.sales_stock_realised_by_date.customs_invoice_code, dm_calc.sd_sales_stock_by_date.customs_invoice_code';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.customs_invoice_number is 'Custom"s invoice Number | Номер документа Custom"s invoice | dm_calc.sales_stock_realised_by_date.customs_invoice_number, dm_calc.sd_sales_stock_by_date.customs_invoice_number';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_customs_invoice is 'Custom"s invoice Date | Дата документа Custom"s invoice | dm_calc.sales_stock_realised_by_date.dt_customs_invoice, dm_calc.sd_sales_stock_by_date.dt_customs_invoice';
comment on column dm.sales_stock_balance_with_forecast.dt_arrival_in_second_port_of_discharge_plan is 'Дата прибытия в порт выгрузки 2 план | Плановая дата прибытия в порт выгрузки из коносамента в ин. порту | dm_calc.sales_stock_realised_by_date.dt_arrival_in_second_port_of_discharge_plan, dm_calc.sd_sales_stock_by_date.dt_arrival_in_second_port_of_discharge_plan, dm_calc.sd_sales_svh_stock_by_date.dt_arrival_in_second_port_of_discharge_plan';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_acceptance_in_russian_port_planned IS 'Плановая дата принятия в порту РФ | Плановая дата прнятия в порту РФ, дата прибытия со сроком приемки | dm_calc.sales_stock_realised_by_date.dt_acceptance_in_russian_port_planned, dm_calc.sd_sales_stock_by_date.dt_acceptance_in_russian_port_planned, dm_calc.sd_sales_svh_stock_by_date.dt_acceptance_in_russian_port_planned';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_shipment_yyyymm IS 'Месяц Дата отгрузки с завода | поле в формате даты год.месяц по полю Дата отгрузки с завода | dm_calc.sales_stock_realised_by_date.dt_shipment_yyyymm, dm_calc.sales_stock_forecast_hist.dt_shipment_yyyymm, dm_calc.sales_stock_forecast_hist.dt_shipment_yyyymm, dm_calc.sd_sales_stock_by_date.dt_shipment_yyyymm, dm_calc.sd_sales_svh_stock_by_date.dt_shipment_yyyymm, dm_calc.finish_goods_warehouse_stock_plant_by_date.dt_shipment_yyyymm';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.buyer_plan_code IS 'Плановый покупатель (код) | Системный номер заказчика | dm_calc.sales_stock_realised_by_date.buyer_plan_code, dm_calc.sales_stock_forecast_hist.buyer_plan_code, dm_calc.sales_stock_forecast_hist.buyer_plan_code, dm_calc.sd_sales_stock_by_date.buyer_plan_code, dm_calc.sd_sales_svh_stock_by_date.buyer_plan_code, dm_calc.finish_goods_warehouse_stock_plant_by_date.buyer_plan_code';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_train_scheduled_arrival IS 'Плановая дата прибытия по ЖД (с фактом) | Плановая дата прибытия по ЖД (с фактом)  | dm_calc.sales_stock_realised_by_date.dt_train_scheduled_arrival,dm_calc.sd_sales_stock_by_date.dt_train_scheduled_arrival,dm_calc.sd_sales_svh_stock_by_date.dt_train_scheduled_arrival';
--274
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_bill_of_lading_in_russian_port_created is 'Дата загрузки Коносамента РФ в САП | Дата загрузки Коносамента РФ в САП | dm_calc.sales_stock_realised_by_date.dt_bill_of_lading_in_russian_port_created,dm_calc.sd_sales_stock_by_date.dt_bill_of_lading_in_russian_port_created,dm_calc.sd_sales_svh_stock_by_date.dt_bill_of_lading_in_russian_port_created';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_bill_of_lading_in_foreign_port_created is 'Дата загрузки Коносамента ин. порта в САП | Дата загрузки Коносамента ин. порта в САП | dm_calc.sales_stock_realised_by_date.dt_bill_of_lading_in_foreign_port_created, dm_calc.sd_sales_stock_by_date.dt_bill_of_lading_in_foreign_port_created, dm_calc.sd_sales_svh_stock_by_date.dt_bill_of_lading_in_foreign_port_created';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_bill_of_lading_in_russian_port_scan_copy_uploaded is 'Дата загрузки скан образа в САП для Коносамента РФ | Дата загрузки скан образа в САП для Коносамента РФ | dm_calc.sales_stock_realised.dt_bill_of_lading_in_russian_port_scan_copy_uploaded.sales_stock_realised_by_date.dt_bill_of_lading_in_russian_port_scan_copy_uploaded, dm_calc.sd_sales_stock_by_date.dt_bill_of_lading_in_russian_port_scan_copy_uploaded, dm_calc.sd_sales_svh_stock_by_date.dt_bill_of_lading_in_russian_port_scan_copy_uploaded';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.bill_of_lading_group_code_in_foreign_port is 'Группа коносамента в ин.порту | Группа коносамента в ин.порту | dm_calc.sales_stock_realised_by_date.bill_of_lading_group_code_in_foreign_port, dm_calc.sd_sales_stock_by_date.bill_of_lading_group_code_in_foreign_port, dm_calc.sd_sales_svh_stock_by_date.bill_of_lading_group_code_in_foreign_port';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded is 'Дата загрузки скан образа в САП для Коносамента ин. порта | Дата загрузки скан образа в САП для Коносамента ин. порта | dm_calc.sales_stock_realised_by_date.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded, dm_calc.sd_sales_stock_by_date.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded, dm_calc.sd_sales_svh_stock_by_date.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.delivery_country_in_contract_code is 'Страна поставки по контракту (код) | Страна поставки по контракту (код) | dm_calc.sales_stock_realised.delivery_country_in_contract_code';
--302
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.country_of_consignee_code IS 'Код страны грузоплучателя | Код страны грузоплучателя | dm_calc.sales_stock_realised.country_of_consignee_code';
--311
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.storage_duration_in_russian_port_in_calendar_days is 'Количество дней хранения в порту РФ | Сроки хранения в российском порту, показывает количество дней. | Расчетное';
COMMENT ON COLUMN dm.sales_stock_balance_with_forecast.storage_duration_in_russian_port_category_code is 'Категория хранения в порту РФ | Отображает данные в формате (<=1M, >1M<=2M, >2M<=3M . тд). по полю SD.001385 "Storage period in Russian port" | Расчетное';
