insert into dm.sales_stock_balance_with_forecast(
    dt_report,                                          -- Отчетная дата
	delivery_number_sales,                              -- Продажная поставка SD.000002
	batch,                                              -- Партия SD.000004
	sales_order_in_shipment,                            -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
	plant_producer_name,                                -- Завод производитель SD.000007  
	tsw_location_name,                                  -- Направление SD.000009   
	dt_shipment,                                        -- Дата отгрузки SD.000010 
	dt_arrival_by_railway,								-- Дата прибытия по ЖД SD.000011
	dt_forwarder,										-- Дата экспедитора SD.000012
	railcar,											-- Вагон SD.000013
	transport_bill,									    -- Накладная SD.000014
	railway_platform,									-- Платформа SD.000015
	material_aggr_name,							    	-- Материал SD.000016
	material_group_code,								-- Группа материалов SD.000017
    forwarder_name,									    -- Экспедитор SD.000021
	dt_warehouse,										-- Дата склада SD.000024
    transport_railcar_type_name,						-- Тип вагона SD.000029
    weight_gross,									    -- Вес брутто SD.000031
	weight_net,										    -- Вес нетто SD.000032
	weight_net_with_wirerod,					 	    -- Вес Н&K SD.000033
	contract_name, 									    -- Контракт SD.000038
	bill_of_lading_number,								-- Номер коносамента SD.000041
	dt_bill_of_lading,									-- Дата коносамента SD.000042
    port_of_discharge_name,						        -- Порт выгрузки SD.000045
    bill_of_lading_in_foreign_port,					    -- Коносамент в ин.порту SD.000048
	dt_bill_of_lading_in_foreign_port,					-- Дата коносамента в ин.порту SD.000049
	bill_of_lading_in_foreign_port_nomination,			-- Номинация коносамента в ин. порту SD.000050
	port_of_discharge_in_foreign_port_name,			    -- Порт выгрузки 2 SD.000055
	dt_sailed_loading_port,								-- Дата отплытия из порта погрузки SD.000058
	dt_arrival_in_port_of_discharge,					-- Дата прибытия в порт выгрузки SD.000059
	dt_arrival_in_second_port_of_discharge,				-- Дата прибытия в порт выгрузки 2 SD.000060
	external_contract_in_lot_number,					-- Контракт в лоте SD.000063
	lot_customer_code,									-- Покупатель в лоте (код) SD.000064
	lot_delivery_basis_code,							-- Базис поставки в лоте SD.000065
	lot_delivery_point_name,							-- Пункт доставки по инкотермс в лоте SD.000066
	delivery_basis,										-- Базис поставки SD.000067
	delivery_point_name,								-- Пункт доставки по инкотермс SD.000068
    receiving_plant_in_sap_system_code,				    -- Принимающий завод грузополучателя в системе SAP SD.000076
	dimensions_unit,									-- Размер единицы готовой продукции SD.000079
	customs_declaration_number,					     	-- Номер ГТД SD.000087
	material_specification_name,						-- Спецификация SD.000089
	instruction_number,						     		-- Номер распоряжения SD.000101
	pieces,												-- PCS SD.000115
	container_after_repacking,							-- Контейнер после перетарки SD.000119
	sales_order,										-- Заказ ЦК SD.000123
	customer_special_requirement,						-- Трейдеры: спец. заказ клиента SD.000127
	dt_arrival_in_port_of_discharge_plan,				-- Дата прибытия в порт выгрузки план SD.000130
	dt_delivery_notice,									-- Дата нотиса о доставке SD.000132
	delivery_notice_number,						    	-- Номер нотиса о доставке SD.000133
	vessel_plan_name,									-- Судно план SD.000134
	vessel_in_foreign_port_actual_name,			    	-- Судно факт в ин. порту SD.000142
	customer_grade_name,								-- Марка клиента SD.000144
	grade_name,									    	-- Марка по спецификации SD.000145
	contract_plan_name,								    -- Плановый контракт SD.000148
	uni,												-- UNI SD.000151
	uni_in_shipment,									-- UNI в отгрузке SD.000152
	pb_number,										    -- LotWshe/PB number SD.000158
	is_plan_or_actual,									-- Признак План/Факт SD.000159
	dt_expected_delivery,								-- Ожидаемая дата доставки до клиента SD.000162
	end_user_for_reporting_name,						-- Конечный потребитель SD.000164
	invoice_provisional_number,					     	-- Инвойс (счет клиенту) SD.000167
	release_group_name,							    	-- Релиз SD.000169
	pledge_in_bank_name,								-- Pledge Bank SD.000172
	dt_storage_start_in_foreign_port,					-- Дата начала хранения ин. склад SD.000175
	dt_storage_end_in_foreign_port,						-- Окончание хранения в ин. порту SD.000176
	dt_storage_start_in_second_foreign_warehouse,		-- Начало хранения склад 2 SD.000177
	dt_storage_end_in_second_foreign_warehouse,			-- Окончание хранение склад 2 SD.000178
	sales_contract_code,								-- Контракт сбыта (код) SD.000179
	material_shape_name_full,							-- Форма SD.000180
	lot_customer_name,                                  -- Покупатель в лоте SD.000193                 --------------(!!!)
	dt_realization_forecast, 							-- Расчетная дата реализации SD.000243
	pledge_in_bank_code,								-- Pledge Bank (code) SD.000252
	dt_expected_bill_of_lading,							-- Ожидаемая дата коносамента SD.000253
	delivery_instruction_code,							-- Иструкция на доставку SD.000254
	incoterms_plan_code,								-- Плановый базис поставки SD.000255
	incoterms_location_plan_code,						-- Плановый пункт доставки по инкотермс SD.000256
	dt_release_material,								-- Дата ОМ SD.000259
	release_material_status_code,                        --Статус ОМ SD.000260
	delivery_region_name,								-- Регион поставки по контракту SD.000338
	"location",                                         -- Локация SD.000339
	country_of_discharge_port_name,                      --Страна POD SD.000341                       -------------(!!!)
	region_of_destination_port_name,					-- Регион POD SD.000343
	dt_prepared_for_realization,						-- Дата готовности к реализации SD.000344
	port_of_destination_name,							-- Порт назначения SD.000376
	is_consigment_warehouse_applicable,					-- Признак консигнации SD.000480
	dt_transfer_from_consignment_to_customer,			-- Дата перехода из консигнации клиенту SD.000481
	dt_final_release,									-- Дата Финальный релиз SD.000482
	is_shipped_via_overseas_warehouse,					-- Наличие Иностранный склад SD.000483
	dt_forwarder_discharge_invoice_or_cmr_documented,	-- ТН/CMR: Дата выгрузки авто SD.000484
	is_shipped_via_overseas_second_foreign_warehouse,	-- Наличие Иностранный склад 2 SD.000485
	dt_arrived_via_ul_system,							-- Дата прибытия УЛ SD.000487
	dt_repacked,										-- Дата перетарки SD.000488
	warehouse_shipment_type_name,						-- СВХ SD.000489
	warehouse_gross_weight,							    -- Вес брутто (с учетом склада) SD.000490
	railway_movement_status_name,						-- Статус движения по ЖД SD.000491
	business_location_name,							    -- Статус в Supply chain (Business) SD.000492
	transportation_scenario_code,						-- Сценарий маршрута SD.000550	
	delivery_country_in_contract_name,					-- Страна поставки по контракту SD.000576
	commitment_weight,								    -- Объем обязательств SD.000578
	total_commitment_weight,						    -- Объем обязательств итого SD.000579
	lot_code,											-- Номер лота SD.000580
	homogenisation_name,								-- Гомогенизация SD.000581
	port_of_discharge_country_code,						-- Страна порта выгрузки 1 SD.000582
	dt_warehouse_confirmation,							-- Дата Storage confirmation SD.000583
	dt_release,											-- Дата релиза SD.000585
	notice_name,										-- Номер нотиса SD.000586
	dt_notice,											-- Дата нотиса SD.000587
	final_release_code,								    -- Номер Финальный релиз SD.000588
	dt_final_invoice_payment,							-- Дата оплаты Final Invoice SD.000589
	vehicle_in_foreign_port_code,						-- Тип ТС в ин. порту (код) SD.000590
	vehicle_type_in_foreign_port_code,					-- Тип ТС в ин. порту SD.000591
	pb1_number,									    	-- Номер PB 1 SD.000592                  -------------(!!!)
	pb2_number,									    	-- Номер PB 2 SD.000593                  -------------(!!!)
	pb3_number,									    	-- Номер PB 3 SD.000594                  -------------(!!!)
	pb1_warehouse_name,								    -- Склад PB 1 SD.000595                  -------------(!!!)
	pb2_warehouse_name,								    -- Склад PB 2 SD.000596                  -------------(!!!)
	pb3_warehouse_name,								    -- Склад PB 3 SD.000597                  -------------(!!!)
	realization_status_name,							-- Статус Реализации SD.000599	         -------------(!!!)
	exporter_name,										-- Экспортёр SD.000600
	country_of_end_user_name,							-- Страна конечного потребителя SD.000601
	buyer_plan_name, 									-- Плановый покупатель SD.000602
	customer_for_scm_report_name, 					    -- Клиент для отчета Металл в Цепочке Поставок SD.000603
	material_group_for_scm_report_name,				    -- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	assignment_name,									-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	vessel_and_voyage_plan_search_name,                 -- Судно / номер рейса (план) SD.000607
	vessel_and_voyage_actual_search_name,               -- Судно / номер рейса (факт) SD.000608
	forwarder_in_foreign_port_name,					    -- Экспедитор в иностранном порту SD.000609
	dt_storage_payed_in_foreign_port_by_rusal,			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	shipment_instruction_in_foreign_port_name,			-- Инструкция на отгрузку Ин Порт SD.000612
	dt_shipment_instruction_in_foreign_port,			-- Дата инструкции на отгрузку Ин Порт SD.000613
	dt_shipment_instruction_date_from,					-- SI: Дата с SD.000614
	dt_shipment_instruction_date_to,					-- SI: Дата по SD.000615
	dt_barge_loading,									-- Дата погрузки на баржу SD.000616
	dt_barge_arrival,									-- Дата доставки баржи SD.000617
	shipment_instruction_in_second_foreign_port_name,	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	dt_shipment_instruction_in_second_foreign_port,	    -- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	dt_invoice_provisional,								-- Дата инвойса SD.000620
	provisional_invoice_payment_status_code,			-- Статус оплаты инвойса SD.000621
	prepared_for_realization_status_name,				-- Признак ППС (код) SD.000623
	mh1_storage_document_number,						-- № Акта МХ-1 SD.000625
	dt_mh1_storage_document,							-- Дата Акта МХ-1 SD.000626
	mh3_storage_document_number,						-- № Акта МХ-3 SD.000627
	dt_mh3_storage_document,							-- Дата Акта МХ-3 SD.000628
	dt_departure_from_foreigh_port,						-- EXP: Load out date SD.000629
	foreign_port_terminal_name,                         -- EXP: Storage location SD.000630            -----------(!!!)
	russian_port_bill_of_lading_forwarder_code,		    -- EXP: WH Operator's code SD.000632
	foreign_port_bill_of_lading_forwarder_code,		    -- EXP: WH Operator's code 2 SD.000633
	uzbekistan_cargo_declaration_73,					-- EXP: ГТД ИМ73 SD.000634
	business_location_sap_precalc_name,				    -- Статус в Supply chain (Business) SD.000636
	ready_for_realization_status_name,                  -- Статус готовности к реализации SD.000639
	country_of_destination_port_code,					-- Страна порта назначения (код) SD.000646
	sales_team_name,									-- Сбытовая команда SD.000651
	delivery_region_code,								-- Регион поставки по контракту (код) SD.000652
	receiving_plant_in_sap_system_name,				    -- Завод собственник SD.000655
	dt_shipment_instruction, 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	shipment_instruction_name,							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	dt_quota_yyyymm,									-- Квота в формате гггг.мм SD.000687
	storage_duration_in_calendar_days,                  -- Сроки нахождения в локации SD.000688
	buyer_agent_name,									-- Trading company SD.000704                                       ---(!!!)
	dt_realization,										-- Дата реализации SD.000720
	internal_compound_key_code, 				    	-- Внутренний уникальный идентификатор записи SD.000721	
	is_tolling_code,                                    -- Признак толлинг SD.000749   ---------------(!!!)
	location_stay_duration_category_code,               -- Сроки нахождения в локации (месяц) SD.000750 ---------------(!!!)
	customer_for_reporting_code,						-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
	warehouse_or_responsible_customer_for_storage_name,  -- SD.000919 General storage location   
	customs_invoice_code,								-- SD.000779 "Custom's invoice Group"
	customs_invoice_number,								-- SD.000780 "Custom's invoice Number"
	dt_customs_invoice,									-- SD.000781 "Custom's invoice Date"  
	dt_arrival_in_second_port_of_discharge_plan,		-- Дата прибытия в порт выгрузки 2 план SD.000157 
	dt_acceptance_in_russian_port_planned,              -- SD.000705 Плановая дата принятия в порту РФ
	dt_shipment_yyyymm,  								-- SD.000893 "Месяц Дата отгрузки с завода"
	--236
	material_group_name,                                -- SD.0000?? Группа материала название
	buyer_plan_code,                                    --SD.000124 Плановый покупатель (код) 
	--272 доработка
	dt_train_scheduled_arrival,      	 			    --SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	dt_bill_of_lading_in_russian_port_created,            --SD.001214 Дата загрузки Коносамента РФ в САП
	dt_bill_of_lading_in_foreign_port_created,            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	dt_bill_of_lading_in_russian_port_scan_copy_uploaded, --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	bill_of_lading_group_code_in_foreign_port,            --SD.000047 Группа коносамента в ин.порту 
	dt_bill_of_lading_in_foreign_port_scan_copy_uploaded,  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	 --295
	delivery_country_in_contract_code,                     --SD.000577 Страна поставки по контракту (код)
	--302
	country_of_consignee_code,                             --SD.001360 Код страны грузоплучателя 
	--311
	storage_duration_in_russian_port_in_calendar_days,    --SD.001385 Количество дней хранения в порту РФ
	storage_duration_in_russian_port_category_code,        --SD.001386 Категория хранения в порту РФ
	dt_arrival_by_railway_planned					--SD.001395 Плановая дата прибытия по жд (нормативная)
)
select --Реализованный факт
	scm.dt_report                                           -- Отчетная дата
	,scm.delivery_number_sales                              -- Продажная поставка SD.000002
	,scm.batch                                              -- Партия SD.000004     
	,scm.sales_order_in_shipment                            -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
	,scm.plant_producer_name                                -- Завод производитель SD.000007    
	,scm.tsw_location_name                                  -- Направление SD.000009   
	,scm.dt_shipment                                        -- Дата отгрузки SD.000010  
	,scm.dt_arrival_by_railway								-- Дата прибытия по ЖД SD.000011
	,scm.dt_forwarder										-- Дата экспедитора SD.000012
	,scm.railcar											-- Вагон SD.000013
	,scm.transport_bill									    -- Накладная SD.000014
	,scm.railway_platform									-- Платформа SD.000015
	,scm.material_aggr_name								    -- Материал SD.000016
	,scm.material_group_code								-- Группа материалов SD.000017
	,scm.forwarder_name							        	-- Экспедитор SD.000021
	,scm.dt_warehouse										-- Дата склада SD.000024
	,scm.transport_railcar_type_name						-- Тип вагона SD.000029 
	,scm.weight_gross									    -- Вес брутто SD.000031
	,scm.weight_net										    -- Вес нетто SD.000032
	,scm.weight_net_with_wirerod						    -- Вес Н&K SD.000033
	,scm.contract_name 									    -- Контракт SD.000038
	,scm.bill_of_lading_number								-- Номер коносамента SD.000041
	,scm.dt_bill_of_lading									-- Дата коносамента SD.000042
	,scm.port_of_discharge_name			     				-- Порт выгрузки SD.000045
	,scm.bill_of_lading_in_foreign_port			    		-- Коносамент в ин.порту SD.000048
	,scm.dt_bill_of_lading_in_foreign_port					-- Дата коносамента в ин.порту SD.000049
	,scm.bill_of_lading_in_foreign_port_nomination			-- Номинация коносамента в ин. порту SD.000050
	,scm.port_of_discharge_in_foreign_port_name			    -- Порт выгрузки 2 SD.000055
	,scm.dt_sailed_loading_port								-- Дата отплытия из порта погрузки SD.000058
	,scm.dt_arrival_in_port_of_discharge					-- Дата прибытия в порт выгрузки SD.000059
	,scm.dt_arrival_in_second_port_of_discharge				-- Дата прибытия в порт выгрузки 2 SD.000060
	,scm.external_contract_in_lot_number					-- Контракт в лоте SD.000063
	,scm.lot_customer_code									-- Покупатель в лоте (код) SD.000064
	,scm.lot_delivery_basis_code							-- Базис поставки в лоте SD.000065
	,scm.lot_delivery_point_name							-- Пункт доставки по инкотермс в лоте SD.000066
	,scm.delivery_basis										-- Базис поставки SD.000067
	,scm.delivery_point_name								-- Пункт доставки по инкотермс SD.000068
    ,scm.receiving_plant_in_sap_system_code			    	-- Принимающий завод грузополучателя в системе SAP SD.000076
	,scm.dimensions_unit									-- Размер единицы готовой продукции SD.000079
	,scm.customs_declaration_number					     	-- Номер ГТД SD.000087
	,scm.material_specification_name						-- Спецификация SD.000089
	,scm.instruction_number				    				-- Номер распоряжения SD.000101
	,scm.pieces												-- PCS SD.000115
	,scm.container_after_repacking							-- Контейнер после перетарки SD.000119
	,scm.sales_order										-- Заказ ЦК SD.000123
	,scm.customer_special_requirement						-- Трейдеры: спец. заказ клиента SD.000127
	,scm.dt_arrival_in_port_of_discharge_plan				-- Дата прибытия в порт выгрузки план SD.000130
	,scm.dt_delivery_notice									-- Дата нотиса о доставке SD.000132
	,scm.delivery_notice_number						    	-- Номер нотиса о доставке SD.000133
	,scm.vessel_plan_name									-- Судно план SD.000134
	,scm.vessel_in_foreign_port_actual_name			    	-- Судно факт в ин. порту SD.000142
	,scm.customer_grade_name								-- Марка клиента SD.000144
	,scm.grade_name									    	-- Марка по спецификации SD.000145
	,scm.contract_plan_name							    	-- Плановый контракт SD.000148
	,scm.uni												-- UNI SD.000151
	,scm.uni_in_shipment									-- UNI в отгрузке SD.000152
	,scm.pb_number										    -- LotWshe/PB number SD.000158
	,scm.is_plan_or_actual									-- Признак План/Факт SD.000159
	,scm.dt_expected_delivery								-- Ожидаемая дата доставки до клиента SD.000162
	,scm.end_user_for_reporting_name						-- Конечный потребитель SD.000164
	,scm.invoice_provisional_number						    -- Инвойс (счет клиенту) SD.000167
	,scm.release_group_name								    -- Релиз SD.000169
	,scm.pledge_in_bank_name								-- Pledge Bank SD.000172
	,scm.dt_storage_start_in_foreign_port					-- Дата начала хранения ин. склад SD.000175
	,scm.dt_storage_end_in_foreign_port						-- Окончание хранения в ин. порту SD.000176
	,scm.dt_storage_start_in_second_foreign_warehouse		-- Начало хранения склад 2 SD.000177
	,scm.dt_storage_end_in_second_foreign_warehouse		    -- Окончание хранение склад 2 SD.000178
	,scm.sales_contract_code								-- Контракт сбыта (код) SD.000179
	,scm.material_shape_name_full							-- Форма SD.000180
	,scm.lot_customer_name                                  -- Покупатель в лоте SD.000193                 --------------(!!!)
	,scm.dt_realization_forecast 							-- Расчетная дата реализации SD.000243
	,scm.pledge_in_bank_code								-- Pledge Bank (code) SD.000252
	,scm.dt_expected_bill_of_lading							-- Ожидаемая дата коносамента SD.000253
	,scm.delivery_instruction_code							-- Иструкция на доставку SD.000254
	,scm.incoterms_plan_code								-- Плановый базис поставки SD.000255
	,scm.incoterms_location_plan_code						-- Плановый пункт доставки по инкотермс SD.000256
	,scm.dt_release_material								-- Дата ОМ SD.000259
	,scm.release_material_status_code                       -- Статус ОМ SD.000260
	,scm.delivery_region_name								-- Регион поставки по контракту SD.000338
	,scm."location"                                         -- Локация SD.000339     -------------(!!!)
	,scm.country_of_discharge_port_name                     -- Страна POD SD.000341                       -------------(!!!)
	,scm.region_of_destination_port_name					-- Регион POD SD.000343
	,scm.dt_prepared_for_realization						-- Дата готовности к реализации SD.000344
	,scm.port_of_destination_name							-- Порт назначения SD.000376
	,scm.is_consigment_warehouse_applicable					-- Признак консигнации SD.000480
	,scm.dt_transfer_from_consignment_to_customer			-- Дата перехода из консигнации клиенту SD.000481
	,scm.dt_final_release									-- Дата Финальный релиз SD.000482
	,scm.is_shipped_via_overseas_warehouse					-- Наличие Иностранный склад SD.000483
	,scm.dt_forwarder_discharge_invoice_or_cmr_documented	-- ТН/CMR: Дата выгрузки авто SD.000484
	,scm.is_shipped_via_overseas_second_foreign_warehouse	-- Наличие Иностранный склад 2 SD.000485
	,scm.dt_arrived_via_ul_system							-- Дата прибытия УЛ SD.000487
	,scm.dt_repacked										-- Дата перетарки SD.000488
	,scm.warehouse_shipment_type_name						-- СВХ SD.000489
	,scm.warehouse_gross_weight						    	-- Вес брутто (с учетом склада) SD.000490
	,scm.railway_movement_status_name						-- Статус движения по ЖД SD.000491
	,scm.business_location_name						    	-- Статус в Supply chain (Business) SD.000492
	,scm.transportation_scenario_code						-- Сценарий маршрута SD.000550
	,scm.delivery_country_in_contract_name					-- Страна поставки по контракту SD.000576
	,scm.commitment_weight								    -- Объем обязательств SD.000578
	,scm.total_commitment_weight						    -- Объем обязательств итого SD.000579
	,scm.lot_code											-- Номер лота SD.000580
	,scm.homogenisation_name								-- Гомогенизация SD.000581
	,scm.port_of_discharge_country_code						-- Страна порта выгрузки 1 SD.000582
	,scm.dt_warehouse_confirmation							-- Дата Storage confirmation SD.000583
	,scm.dt_release											-- Дата релиза SD.000585
	,scm.notice_name										-- Номер нотиса SD.000586
	,scm.dt_notice											-- Дата нотиса SD.000587
	,scm.final_release_code								    -- Номер Финальный релиз SD.000588
	,scm.dt_final_invoice_payment							-- Дата оплаты Final Invoice SD.000589
	,scm.vehicle_in_foreign_port_code						-- Тип ТС в ин. порту (код) SD.000590
	,scm.vehicle_type_in_foreign_port_code					-- Тип ТС в ин. порту SD.000591
	,scm.pb1_number									    	-- Номер PB 1 SD.000592                  -------------(!!!)
	,scm.pb2_number									    	-- Номер PB 2 SD.000593                  -------------(!!!)
	,scm.pb3_number								         	-- Номер PB 3 SD.000594                  -------------(!!!)
	,scm.pb1_warehouse_name								    -- Склад PB 1 SD.000595                  -------------(!!!)
	,scm.pb2_warehouse_name								    -- Склад PB 2 SD.000596                  -------------(!!!)
	,scm.pb3_warehouse_name								    -- Склад PB 3 SD.000597                  -------------(!!!)
	,scm.realization_status_name							-- Статус Реализации SD.000599	 -------------(!!!)
	,scm.exporter_name										-- Экспортёр SD.000600
	,scm.country_of_end_user_name							-- Страна конечного потребителя SD.000601
	,scm.buyer_plan_name 									-- Плановый покупатель SD.000602
	,scm.customer_for_scm_report_name 					    -- Клиент для отчета Металл в Цепочке Поставок SD.000603
	,scm.material_group_for_scm_report_name			    	-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	,scm.assignment_name									-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	,scm.vessel_and_voyage_plan_search_name                 -- Судно / номер рейса (план) SD.000607
    ,scm.vessel_and_voyage_actual_search_name               -- Судно / номер рейса (факт) SD.000608
	,scm.forwarder_in_foreign_port_name				    	-- Экспедитор в иностранном порту SD.000609
	,scm.dt_storage_payed_in_foreign_port_by_rusal			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	,scm.shipment_instruction_in_foreign_port_name			-- Инструкция на отгрузку Ин Порт SD.000612
	,scm.dt_shipment_instruction_in_foreign_port			-- Дата инструкции на отгрузку Ин Порт SD.000613
	,scm.dt_shipment_instruction_date_from					-- SI: Дата с SD.000614
	,scm.dt_shipment_instruction_date_to					-- SI: Дата по SD.000615
	,scm.dt_barge_loading									-- Дата погрузки на баржу SD.000616
	,scm.dt_barge_arrival									-- Дата доставки баржи SD.000617
	,scm.shipment_instruction_in_second_foreign_port_name	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,scm.dt_shipment_instruction_in_second_foreign_port		-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,scm.dt_invoice_provisional								-- Дата инвойса SD.000620
	,scm.provisional_invoice_payment_status_code			-- Статус оплаты инвойса SD.000621
	,scm.prepared_for_realization_status_name				-- Признак ППС (код) SD.000623
	,scm.mh1_storage_document_number						-- № Акта МХ-1 SD.000625
	,scm.dt_mh1_storage_document							-- Дата Акта МХ-1 SD.000626
	,scm.mh3_storage_document_number						-- № Акта МХ-3 SD.000627
	,scm.dt_mh3_storage_document							-- Дата Акта МХ-3 SD.000628
	,scm.dt_departure_from_foreigh_port						-- EXP: Load out date SD.000629
	,scm.foreign_port_terminal_name                         -- EXP: Storage location SD.000630            -----------(!!!)
	,scm.russian_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code SD.000632
	,scm.foreign_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code 2 SD.000633
	,scm.uzbekistan_cargo_declaration_73					-- EXP: ГТД ИМ73 SD.000634
	,scm.business_location_sap_precalc_name				    -- Статус в Supply chain (Business) SD.000636
	,scm.ready_for_realization_status_name                  -- Статус готовности к реализации SD.000639
	,scm.country_of_destination_port_code					-- Страна порта назначения (код) SD.000646
	,scm.sales_team_name									-- Сбытовая команда SD.000651
	,scm.delivery_region_code								-- Регион поставки по контракту (код) SD.000652
	,scm.receiving_plant_in_sap_system_name				    -- Завод собственник SD.000655
	,scm.dt_shipment_instruction 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	,scm.shipment_instruction_name							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	,scm.dt_quota_yyyymm									-- Квота в формате гггг.мм SD.000687
	,scm.storage_duration_in_calendar_days                  -- Сроки нахождения в локации SD.000688 -------(!!!)
	,scm.buyer_agent_name									-- Trading company SD.000704                                       ---(!!!)
	,scm.dt_realization										-- Дата реализации SD.000720
	,scm.internal_compound_key_code 				    	-- Внутренний уникальный идентификатор записи SD.000721
	,scm.is_tolling_code                                    -- Признак толлинг SD.000749   ---------------(!!!)
	,case when scm.storage_duration_in_calendar_days::integer=0 then null
		   when scm.storage_duration_in_calendar_days::integer between 1  and 30 then '<=1M'
           when scm.storage_duration_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
           when scm.storage_duration_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
           when scm.storage_duration_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
           when scm.storage_duration_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
           else '>1Y' end  as location_stay_duration_category_code   --Сроки нахождения в локации (месяц) SD.000750 ---------------(!!!)
	,scm.customer_for_reporting_code						-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
	,'REALIZED' as warehouse_or_responsible_customer_for_storage_name  -- SD.000919 General storage location   
	,scm.customs_invoice_code							-- SD.000779 "Custom's invoice Group"
	,scm.customs_invoice_number								-- SD.000780 "Custom's invoice Number"
	,scm.dt_customs_invoice									-- SD.000781 "Custom's invoice Date"
	,scm.dt_arrival_in_second_port_of_discharge_plan		-- Дата прибытия в порт выгрузки 2 план SD.000157 
	,scm.dt_acceptance_in_russian_port_planned              -- SD.000705 Плановая дата принятия в порту РФ
	,to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm -- SD.000893 "Месяц Дата отгрузки с завода"   
	--236
	,scm.material_group_name                                -- SD.0000?? Группа материала название
	,scm.buyer_plan_code                                    -- SD.000124 Плановый покупатель (код) 
	--272 доработка
	,scm.dt_train_scheduled_arrival	 						--SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	,scm.dt_bill_of_lading_in_russian_port_created            --SD.001214 Дата загрузки Коносамента РФ в САП
	,scm.dt_bill_of_lading_in_foreign_port_created            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	,scm.dt_bill_of_lading_in_russian_port_scan_copy_uploaded --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	,scm.bill_of_lading_group_code_in_foreign_port            --SD.000047 Группа коносамента в ин.порту 
	,scm.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	 --295
	,scm.delivery_country_in_contract_code                     --SD.000577 Страна поставки по контракту (код)
	 --302
	,scm.country_of_consignee_code                              --SD.001360 Код страны грузоплучателя 
	--311
	,scm.storage_duration_in_russian_port_in_calendar_days    --SD.001385 Количество дней хранения в порту РФ
	 ,case
   	    when scm.storage_duration_in_russian_port_in_calendar_days is not null 
        then case
	         when scm.storage_duration_in_russian_port_in_calendar_days::integer = 0 then null
   	         when scm.storage_duration_in_russian_port_in_calendar_days::integer between 1  and 30 then '<=1M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		     else '>1Y'
		    end
   	  end as storage_duration_in_russian_port_category_code      --SD.001386 Категория хранения в порту РФ
   	  ,scm.dt_arrival_by_railway_planned					--SD.001395 Плановая дата прибытия по жд (нормативная)
from dm_calc.sales_stock_realised_by_date as scm
where scm.dt_report<=scm.dt_realization
union ALL ---Реализованный План где дата реализации НЕ прошлый месяц
select
     scm.dt_report                                              -- Отчетная дата
	,null as delivery_number_sales                              -- Продажная поставка SD.000002
	,null as batch                                              -- Партия SD.000004
	,scm.sales_order_in_shipment                                -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
	,scm.plant_producer_name            				        -- Завод производитель SD.000007
	--,scm.tsw_location_name              				        -- Направление SD.000009
	,case
        	when ls_09.transport_hub_code is null 
        	then ls_09.location_name
        	else thc_09.transport_hub_name_eng
    end as tsw_location_name                                   -- SD.000009 Направление --Порт погрузки в МКТРЕК   
	,scm.dt_shipment                    				        -- Дата отгрузки SD.000010
	,null as dt_arrival_by_railway								-- Дата прибытия по ЖД SD.000011
	,null as dt_forwarder										-- Дата экспедитора SD.000012
	,null as railcar											-- Вагон SD.000013
	,null as transport_bill									    -- Накладная SD.000014
	,null as railway_platform									-- Платформа SD.000015
	,scm.material_aggr_name			          				    -- Материал SD.000016
	,scm.material_group_code			      				  	-- Группа материалов SD.000017
	,null as forwarder_name							            -- Экспедитор SD.000021
	,null as dt_warehouse								    	-- Дата склада SD.000024
	,scm.transport_railcar_type_name	    					-- Тип вагона SD.000029
	,scm.weight_gross										    -- Вес брутто SD.000031
	,scm.weight_net											    -- Вес нетто SD.000032
	,scm.weight_net_with_wirerod							    -- Вес Н&K SD.000033
	,scm.contract_name 										    -- Контракт SD.000038
	,null as bill_of_lading_number								-- Номер коносамента SD.000041
	,null as dt_bill_of_lading									-- Дата коносамента SD.000042
	--,scm.port_of_discharge_name									-- Порт выгрузки SD.000045
	,thc_045.transport_hub_name_eng as port_of_discharge_name   --SD.000045 Порт выгрузки   
	,null as bill_of_lading_in_foreign_port			    		-- Коносамент в ин.порту SD.000048
	,null as dt_bill_of_lading_in_foreign_port					-- Дата коносамента в ин.порту SD.000049
	,null as bill_of_lading_in_foreign_port_nomination			-- Номинация коносамента в ин. порту SD.000050
	,null as port_of_discharge_in_foreign_port_name			    -- Порт выгрузки 2 SD.000055
	,null as dt_sailed_loading_port								-- Дата отплытия из порта погрузки SD.000058
	,null as dt_arrival_in_port_of_discharge					-- Дата прибытия в порт выгрузки SD.000059
	,null as dt_arrival_in_second_port_of_discharge				-- Дата прибытия в порт выгрузки 2 SD.000060
	,null as external_contract_in_lot_number					-- Контракт в лоте SD.000063
	,null as lot_customer_code									-- Покупатель в лоте (код) SD.000064
	,null as lot_delivery_basis_code							-- Базис поставки в лоте SD.000065
	,null as lot_delivery_point_name							-- Пункт доставки по инкотермс в лоте SD.000066
	,scm.delivery_basis											-- Базис поставки SD.000067
	,scm.delivery_point_name									-- Пункт доставки по инкотермс SD.000068
    ,null as receiving_plant_in_sap_system_code			    	-- Принимающий завод грузополучателя в системе SAP SD.000076
	,scm.dimensions_unit										-- Размер единицы готовой продукции SD.000079
	,null as customs_declaration_number					     	-- Номер ГТД SD.000087
	,scm.material_specification_name							-- Спецификация SD.000089
	,null as instruction_number				    				-- Номер распоряжения SD.000101
	,scm.pieces													-- PCS SD.000115
	,null as container_after_repacking							-- Контейнер после перетарки SD.000119
	,scm.sales_order										    -- Заказ ЦК SD.000123
	,null as customer_special_requirement						-- Трейдеры: спец. заказ клиента SD.000127
	,null as dt_arrival_in_port_of_discharge_plan				-- Дата прибытия в порт выгрузки план SD.000130
	,null as dt_delivery_notice									-- Дата нотиса о доставке SD.000132
	,null as delivery_notice_number						    	-- Номер нотиса о доставке SD.000133
	,null as vessel_plan_name									-- Судно план SD.000134
	,null as vessel_in_foreign_port_actual_name			    	-- Судно факт в ин. порту SD.000142
	,scm.customer_grade_name									-- Марка клиента SD.000144
	,scm.grade_name												-- Марка по спецификации SD.000145
	,scm.contract_plan_name										-- Плановый контракт SD.000148
	,null as uni												-- UNI SD.000151
	,null as uni_in_shipment									-- UNI в отгрузке SD.000152
	,null as pb_number										    -- LotWshe/PB number SD.000158
	,scm.is_plan_or_actual										-- Признак План/Факт SD.000159
	,scm.dt_expected_delivery									-- Ожидаемая дата доставки до клиента SD.000162
	,scm.end_user_for_reporting_name							-- Конечный потребитель SD.000164
	,null as invoice_provisional_number						    -- Инвойс (счет клиенту) SD.000167
	,null as release_group_name								    -- Релиз SD.000169
	,null as pledge_in_bank_name								-- Pledge Bank SD.000172
	,null as dt_storage_start_in_foreign_port					-- Дата начала хранения ин. склад SD.000175
	,null as dt_storage_end_in_foreign_port						-- Окончание хранения в ин. порту SD.000176
	,null as dt_storage_start_in_second_foreign_warehouse		-- Начало хранения склад 2 SD.000177
	,null as dt_storage_end_in_second_foreign_warehouse		    -- Окончание хранение склад 2 SD.000178
	,scm.sales_contract_code									-- Контракт сбыта (код) SD.000179
	,scm.material_shape_name_full								-- Форма SD.000180
	,null as lot_customer_name                                  -- Покупатель в лоте SD.000193                 --------------(!!!)
	,null as dt_realization_forecast 							-- Расчетная дата реализации SD.000243
	,null as pledge_in_bank_code								-- Pledge Bank (code) SD.000252
	,null as dt_expected_bill_of_lading							-- Ожидаемая дата коносамента SD.000253
	,null as delivery_instruction_code							-- Иструкция на доставку SD.000254
	,scm.incoterms_plan_code									-- Плановый базис поставки SD.000255
	,scm.incoterms_location_plan_code							-- Плановый пункт доставки по инкотермс SD.000256
	,null as dt_release_material								-- Дата ОМ SD.000259
	,null as release_material_status_code                       -- Статус ОМ SD.000260
	,scm.delivery_region_name									-- Регион поставки по контракту SD.000338
	,null as "location"                                         -- Локация SD.000339  --------------(!!!)
	,coalesce(thc_341_343.country_short_name_eng,scm.country_of_discharge_port_name) as country_of_discharge_port_name -- Страна POD SD.000341                       -------------(!!!)
	,coalesce(thc_341_343.market_region1_name,scm.region_of_destination_port_name) as region_of_destination_port_name  -- Регион POD SD.000343
	,null as dt_prepared_for_realization						-- Дата готовности к реализации SD.000344
	,scm.port_of_destination_name								-- Порт назначения SD.000376
	,null as is_consigment_warehouse_applicable					-- Признак консигнации SD.000480
	,null as dt_transfer_from_consignment_to_customer			-- Дата перехода из консигнации клиенту SD.000481
	,null as dt_final_release									-- Дата Финальный релиз SD.000482
	,null as is_shipped_via_overseas_warehouse					-- Наличие Иностранный склад SD.000483
	,null as dt_forwarder_discharge_invoice_or_cmr_documented	-- ТН/CMR: Дата выгрузки авто SD.000484
	,null as is_shipped_via_overseas_second_foreign_warehouse	-- Наличие Иностранный склад 2 SD.000485
	,null as dt_arrived_via_ul_system							-- Дата прибытия УЛ SD.000487
	,null as dt_repacked										-- Дата перетарки SD.000488
	,null as warehouse_shipment_type_name						-- СВХ SD.000489
	,null as warehouse_gross_weight						    	-- Вес брутто (с учетом склада) SD.000490
	,null as railway_movement_status_name						-- Статус движения по ЖД SD.000491
	,scm.business_location_name		    						-- Статус в Supply chain (Business) SD.000492
	,null as transportation_scenario_code						-- Сценарий маршрута SD.000550
	,c_576.country_short_name_eng as delivery_country_in_contract_name						-- Страна поставки по контракту SD.000576
	,scm.commitment_weight									    -- Объем обязательств SD.000578
	,null as total_commitment_weight						    -- Объем обязательств итого SD.000579
	,null as lot_code											-- Номер лота SD.000580
	--,scm.homogenisation_name							    	-- Гомогенизация SD.000581
	,hmg_eng./*homog_dsc*/homogenisation_full_name as homogenisation_name  --Гомогенизация SD.000581 
	,scm.port_of_discharge_country_code							-- Страна порта выгрузки 1 SD.000582
	,null as dt_warehouse_confirmation							-- Дата Storage confirmation SD.000583
	,null as dt_release											-- Дата релиза SD.000585
	,null as notice_name										-- Номер нотиса SD.000586
	,null as dt_notice											-- Дата нотиса SD.000587
	,null as final_release_code								    -- Номер Финальный релиз SD.000588
	,null as dt_final_invoice_payment							-- Дата оплаты Final Invoice SD.000589
	,null as vehicle_in_foreign_port_code						-- Тип ТС в ин. порту (код) SD.000590
	,null as vehicle_type_in_foreign_port_code					-- Тип ТС в ин. порту SD.000591
	,null as pb1_number									    	-- Номер PB 1 SD.000592                  -------------(!!!)
	,null as pb2_number									    	-- Номер PB 2 SD.000593                  -------------(!!!)
	,null as pb3_number									    	-- Номер PB 3 SD.000594                  -------------(!!!)
	,null as pb1_warehouse_name								    -- Склад PB 1 SD.000595                  -------------(!!!)
	,null as pb2_warehouse_name								    -- Склад PB 2 SD.000596                  -------------(!!!)
	,null as pb3_warehouse_name								    -- Склад PB 3 SD.000597                  -------------(!!!)
	,'No' as realization_status_name							-- Статус Реализации SD.000599	  -------------(!!!)
	,null as exporter_name										-- Экспортёр SD.000600
	,null as country_of_end_user_name							-- Страна конечного потребителя SD.000601
	,scm.buyer_plan_name 										-- Плановый покупатель SD.000602
	,scm.customer_for_scm_report_name 					    	-- Клиент для отчета Металл в Цепочке Поставок SD.000603
	--,null as material_group_for_scm_report_name				   	-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	,mc.material_for_reporting_code as material_group_for_scm_report_name             --Группа материала для отчета Металл в Цепочке Поставок SD.000604  
	,null as assignment_name									-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	,null as vessel_and_voyage_plan_search_name                 -- Судно / номер рейса (план) SD.000607
    ,null as vessel_and_voyage_actual_search_name               -- Судно / номер рейса (факт) SD.000608
	,null as forwarder_in_foreign_port_name				    	-- Экспедитор в иностранном порту SD.000609
	,null as dt_storage_payed_in_foreign_port_by_rusal			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	,null as shipment_instruction_in_foreign_port_name			-- Инструкция на отгрузку Ин Порт SD.000612
	,null as shipment_instruction_in_foreign_port		    	-- Дата инструкции на отгрузку Ин Порт SD.000613
	,null as dt_shipment_instruction_date_from					-- SI: Дата с SD.000614
	,null as dt_shipment_instruction_date_to					-- SI: Дата по SD.000615
	,null as dt_barge_loading									-- Дата погрузки на баржу SD.000616
	,null as dt_barge_arrival									-- Дата доставки баржи SD.000617
	,null as shipment_instruction_in_second_foreign_port_name	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,null as dt_shipment_instruction_in_second_foreign_port		-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,null as dt_invoice_provisional								-- Дата инвойса SD.000620
	,null as provisional_invoice_payment_status_code			-- Статус оплаты инвойса SD.000621
	,null as prepared_for_realization_status_name				-- Признак ППС (код) SD.000623
	,null as mh1_storage_document_number						-- № Акта МХ-1 SD.000625
	,null as dt_mh1_storage_document							-- Дата Акта МХ-1 SD.000626
	,null as mh3_storage_document_number						-- № Акта МХ-3 SD.000627
	,null as dt_mh3_storage_document							-- Дата Акта МХ-3 SD.000628
	,null as dt_departure_from_foreigh_port						-- EXP: Load out date SD.000629
	,null as foreign_port_terminal_name                         -- EXP: Storage location SD.000630            -----------(!!!)
	,null as russian_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code SD.000632
	,null as foreign_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code 2 SD.000633
	,null as uzbekistan_cargo_declaration_73					-- EXP: ГТД ИМ73 SD.000634
	,null as business_location_sap_precalc_name				    -- Статус в Supply chain (Business) SD.000636
	,null as ready_for_realization_status_name                  -- Статус готовности к реализации SD.000639
	,null as country_of_destination_port_code					-- Страна порта назначения (код) SD.000646
--	,null as sales_team_name									-- Сбытовая команда SD.000651
	,case 
		when ctp.counterparty_code is not null then concat(sb_market.market_region1_name,'_trader') 
		else sb_market.market_region1_name 
	end as sales_team_name  -- SD.000651  Сбытовая команда    
	,null as delivery_region_code								-- Регион поставки по контракту (код) SD.000652
	,null as receiving_plant_in_sap_system_name				    -- Завод собственник SD.000655
	,null as dt_shipment_instruction 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	,null as shipment_instruction_name							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	,null as dt_quota_yyyymm									-- Квота в формате гггг.мм SD.000687
	,null as storage_duration_in_calendar_days                  -- Сроки нахождения в локации SD.000688 -----(!!!)
	,null as buyer_agent_name									-- Trading company SD.000704    -----(!!!)
	,null as dt_realization										-- Дата реализации SD.000720
	,null as internal_compound_key_code 				    	-- Внутренний уникальный идентификатор записи SD.000721
	,null as is_tolling_code                                    -- Признак толлинг SD.000749   ---------------(!!!)
	,null as location_stay_duration_category_code               -- Сроки нахождения в локации (месяц) SD.000750   ---------------(!!!)
	,scm.customer_for_reporting_code							-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
	,'SCHEDULED' as warehouse_or_responsible_customer_for_storage_name  -- SD.000919 General storage location  
	,null as customs_invoice_code								-- SD.000779 "Custom's invoice Group"
	,null as customs_invoice_number								-- SD.000780 "Custom's invoice Number"
	,null as dt_customs_invoice									-- SD.000781 "Custom's invoice Date" 
	,NULL AS dt_arrival_in_second_port_of_discharge_plan				-- Дата прибытия в порт выгрузки 2 план SD.000157   
	,dt_acceptance_in_russian_port_planned               			-- SD.000705 Плановая дата принятия в порту РФ
	,to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm   -- SD.000893 "Месяц Дата отгрузки с завода" 
	,sd_17_2.material_group_full_name  as material_group_name    --Группа материала для отчета Металл в Цеп //as "material_group_report_mc" SD.000017         
    ,scm.buyer_plan_code                                     -- SD.000124 Плановый покупатель (код) 
    --272 доработка
	,null as dt_train_scheduled_arrival	 						--SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	,null as dt_bill_of_lading_in_russian_port_created            --SD.001214 Дата загрузки Коносамента РФ в САП
	,null as dt_bill_of_lading_in_foreign_port_created            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	,null as dt_bill_of_lading_in_russian_port_scan_copy_uploaded --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	,null as bill_of_lading_group_code_in_foreign_port            --SD.000047 Группа коносамента в ин.порту 
	,null as dt_bill_of_lading_in_foreign_port_scan_copy_uploaded  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	 --295
	,scm.delivery_country_in_contract_code                     --SD.000577 Страна поставки по контракту (код) 
	--302
	,cntry_1360.country_code as country_of_consignee_code                 --SD.001360 Код страны грузоплучателя  
	--311
	,null as storage_duration_in_russian_port_in_calendar_days    --SD.001385 Количество дней хранения в порту РФ
	,null as storage_duration_in_russian_port_category_code       --SD.001386 Категория хранения в порту РФ
	,null as dt_arrival_by_railway_planned					--SD.001395 Плановая дата прибытия по жд (нормативная)
	from dm_calc.sales_stock_forecast_hist as scm
	inner join (
		select dt_report, max(dttm_inserted) as dttm_inserted
		from dm_calc.sales_stock_forecast_hist
		group by dt_report
	) as hist_max
    	on scm.dt_report=hist_max.dt_report
    	and scm.dttm_inserted=hist_max.dttm_inserted
 --------SD.0000?? Material Group name----------
 /* left join dict_dds.material as sd_17_1
     on scm.material_code=sd_17_1.material_code*/
  left join dict_dds.material_group_texts as sd_17_2
     on scm.material_group_code=sd_17_2.material_group_code and sd_17_2.language_code='E'	
  	--Страна POD SD.000341 Регион POD SD.000343	
		left join dm_calc.transport_hub_country as thc_341_343
		on scm.port_of_discharge_code=thc_341_343.transport_hub_code  
 --------------------------------SD.000581-----------------------------------------------------	
      left join dict_dds.material_specification ms
		on scm.material_code=ms.material_code 
    left join dict_dds./*homogenization_dsc*/homogenisation_texts as hmg_eng 
         on ms.homogenisation_code=hmg_eng./*homog_code*/homogenisation_code and hmg_eng./*lang_code*/language_code='E' 
 ---------------------Сбытовая команда SD.000651-------------------------------------------- 
     left join dict_dds.map_counterparty_to_market_region2 as ctp 
    	on scm.customer_code=ctp.counterparty_code   
    left join dict_dds.country as steam 
		on scm.delivery_country_in_contract_code=steam.country_code
	left join dict_dds.market_region1_texts as sb_market 
		on steam.sales_team_code=sb_market.market_region1_code 
		and sb_market.language_code='E'	
	 ---------------------SD.000604-------------------------------------------- 	
		   left join dict_dds.map_material_to_cargo_order as mc 
		on scm.material_aggr_name=mc.material_aggregated_code
------------------576----------------------------------------------------------------		
	left join dict_dds.country c_576
	on scm.delivery_country_in_contract_code=c_576.country_code 
	 --------SD.000009----------
   left join dict_dds.location_sales ls_09
       on scm.tsw_location_code=ls_09.location_code
          left join dm_calc.transport_hub_country thc_09
          on ls_09.transport_hub_code=thc_09.transport_hub_code  	
   ------	SD.000045----
	left join dm_calc.transport_hub_country as thc_045 
		on scm.port_of_discharge_code=thc_045.transport_hub_code   
	 --------SD.001360----------        
          left join dm_calc.counterparty_country cntry_1360 
		on scm.consignee_code=cntry_1360.counterparty_code	
where scm.dt_report=scm.dt_data_sap
union ALL ---Реализованный План где дата реализации прошлый месяц
select
     scm.dt_report                                              -- Отчетная дата
	,null as delivery_number_sales                              -- Продажная поставка SD.000002
	,null as batch                                              -- Партия SD.000004
	,scm.sales_order_in_shipment                                -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
	,scm.plant_producer_name            				        -- Завод производитель SD.000007
	--,scm.tsw_location_name              				        -- Направление SD.000009
	,case
        	when ls_09.transport_hub_code is null 
        	then ls_09.location_name
        	else thc_09.transport_hub_name_eng
    end as tsw_location_name                                   -- SD.000009 Направление --Порт погрузки в МКТРЕК
	,scm.dt_shipment                    				        -- Дата отгрузки SD.000010
	,null as dt_arrival_by_railway								-- Дата прибытия по ЖД SD.000011
	,null as dt_forwarder										-- Дата экспедитора SD.000012
	,null as railcar											-- Вагон SD.000013
	,null as transport_bill									    -- Накладная SD.000014
	,null as railway_platform									-- Платформа SD.000015
	,scm.material_aggr_name			          				    -- Материал SD.000016
	,scm.material_group_code			      				  	-- Группа материалов SD.000017
	,null as forwarder_name							            -- Экспедитор SD.000021
	,null as dt_warehouse								    	-- Дата склада SD.000024
	,scm.transport_railcar_type_name	    					-- Тип вагона SD.000029
	,scm.weight_gross										    -- Вес брутто SD.000031
	,scm.weight_net											    -- Вес нетто SD.000032
	,scm.weight_net_with_wirerod							    -- Вес Н&K SD.000033
	,scm.contract_name 										    -- Контракт SD.000038
	,null as bill_of_lading_number								-- Номер коносамента SD.000041
	,null as dt_bill_of_lading									-- Дата коносамента SD.000042
	--,scm.port_of_discharge_name									-- Порт выгрузки SD.000045
	,thc_045.transport_hub_name_eng as port_of_discharge_name   --SD.000045 Порт выгрузки   
	,null as bill_of_lading_in_foreign_port			    		-- Коносамент в ин.порту SD.000048
	,null as dt_bill_of_lading_in_foreign_port					-- Дата коносамента в ин.порту SD.000049
	,null as bill_of_lading_in_foreign_port_nomination			-- Номинация коносамента в ин. порту SD.000050
	,null as port_of_discharge_in_foreign_port_name			    -- Порт выгрузки 2 SD.000055
	,null as dt_sailed_loading_port								-- Дата отплытия из порта погрузки SD.000058
	,null as dt_arrival_in_port_of_discharge					-- Дата прибытия в порт выгрузки SD.000059
	,null as dt_arrival_in_second_port_of_discharge				-- Дата прибытия в порт выгрузки 2 SD.000060
	,null as external_contract_in_lot_number					-- Контракт в лоте SD.000063
	,null as lot_customer_code									-- Покупатель в лоте (код) SD.000064
	,null as lot_delivery_basis_code							-- Базис поставки в лоте SD.000065
	,null as lot_delivery_point_name							-- Пункт доставки по инкотермс в лоте SD.000066
	,scm.delivery_basis											-- Базис поставки SD.000067
	,scm.delivery_point_name									-- Пункт доставки по инкотермс SD.000068
    ,null as receiving_plant_in_sap_system_code			    	-- Принимающий завод грузополучателя в системе SAP SD.000076
	,scm.dimensions_unit										-- Размер единицы готовой продукции SD.000079
	,null as customs_declaration_number					     	-- Номер ГТД SD.000087
	,scm.material_specification_name							-- Спецификация SD.000089
	,null as instruction_number				    				-- Номер распоряжения SD.000101
	,scm.pieces													-- PCS SD.000115
	,null as container_after_repacking							-- Контейнер после перетарки SD.000119
	,scm.sales_order										    -- Заказ ЦК SD.000123
	,null as customer_special_requirement						-- Трейдеры: спец. заказ клиента SD.000127
	,null as dt_arrival_in_port_of_discharge_plan				-- Дата прибытия в порт выгрузки план SD.000130
	,null as dt_delivery_notice									-- Дата нотиса о доставке SD.000132
	,null as delivery_notice_number						    	-- Номер нотиса о доставке SD.000133
	,null as vessel_plan_name									-- Судно план SD.000134
	,null as vessel_in_foreign_port_actual_name			    	-- Судно факт в ин. порту SD.000142
	,scm.customer_grade_name									-- Марка клиента SD.000144
	,scm.grade_name												-- Марка по спецификации SD.000145
	,scm.contract_plan_name										-- Плановый контракт SD.000148
	,null as uni												-- UNI SD.000151
	,null as uni_in_shipment									-- UNI в отгрузке SD.000152
	,null as pb_number										    -- LotWshe/PB number SD.000158
	,scm.is_plan_or_actual										-- Признак План/Факт SD.000159
	,scm.dt_expected_delivery									-- Ожидаемая дата доставки до клиента SD.000162
	,scm.end_user_for_reporting_name							-- Конечный потребитель SD.000164
	,null as invoice_provisional_number						    -- Инвойс (счет клиенту) SD.000167
	,null as release_group_name								    -- Релиз SD.000169
	,null as pledge_in_bank_name								-- Pledge Bank SD.000172
	,null as dt_storage_start_in_foreign_port					-- Дата начала хранения ин. склад SD.000175
	,null as dt_storage_end_in_foreign_port						-- Окончание хранения в ин. порту SD.000176
	,null as dt_storage_start_in_second_foreign_warehouse		-- Начало хранения склад 2 SD.000177
	,null as dt_storage_end_in_second_foreign_warehouse		    -- Окончание хранение склад 2 SD.000178
	,scm.sales_contract_code									-- Контракт сбыта (код) SD.000179
	,scm.material_shape_name_full								-- Форма SD.000180
	,null as lot_customer_name                                  -- Покупатель в лоте SD.000193                 --------------(!!!)
	,null as dt_realization_forecast 							-- Расчетная дата реализации SD.000243
	,null as pledge_in_bank_code								-- Pledge Bank (code) SD.000252
	,null as dt_expected_bill_of_lading							-- Ожидаемая дата коносамента SD.000253
	,null as delivery_instruction_code							-- Иструкция на доставку SD.000254
	,scm.incoterms_plan_code									-- Плановый базис поставки SD.000255
	,scm.incoterms_location_plan_code							-- Плановый пункт доставки по инкотермс SD.000256
	,null as dt_release_material								-- Дата ОМ SD.000259
	,null as release_material_status_code                       -- Статус ОМ SD.000260
	,scm.delivery_region_name									-- Регион поставки по контракту SD.000338
	,null as "location"                                         -- Локация SD.000339  --------------(!!!)
	,coalesce(thc_341_343.country_short_name_eng,scm.country_of_discharge_port_name) as country_of_discharge_port_name -- Страна POD SD.000341                       -------------(!!!)
	,coalesce(thc_341_343.market_region1_name,scm.region_of_destination_port_name) as region_of_destination_port_name  -- Регион POD SD.000343
	,null as dt_prepared_for_realization						-- Дата готовности к реализации SD.000344
	,scm.port_of_destination_name								-- Порт назначения SD.000376
	,null as is_consigment_warehouse_applicable					-- Признак консигнации SD.000480
	,null as dt_transfer_from_consignment_to_customer			-- Дата перехода из консигнации клиенту SD.000481
	,null as dt_final_release									-- Дата Финальный релиз SD.000482
	,null as is_shipped_via_overseas_warehouse					-- Наличие Иностранный склад SD.000483
	,null as dt_forwarder_discharge_invoice_or_cmr_documented	-- ТН/CMR: Дата выгрузки авто SD.000484
	,null as is_shipped_via_overseas_second_foreign_warehouse	-- Наличие Иностранный склад 2 SD.000485
	,null as dt_arrived_via_ul_system							-- Дата прибытия УЛ SD.000487
	,null as dt_repacked										-- Дата перетарки SD.000488
	,null as warehouse_shipment_type_name						-- СВХ SD.000489
	,null as warehouse_gross_weight						    	-- Вес брутто (с учетом склада) SD.000490
	,null as railway_movement_status_name						-- Статус движения по ЖД SD.000491
	,scm.business_location_name		    						-- Статус в Supply chain (Business) SD.000492
	,null as transportation_scenario_code						-- Сценарий маршрута SD.000550
	,c_576.country_short_name_eng as delivery_country_in_contract_name						-- Страна поставки по контракту SD.000576
	,scm.commitment_weight									    -- Объем обязательств SD.000578
	,null as total_commitment_weight						    -- Объем обязательств итого SD.000579
	,null as lot_code											-- Номер лота SD.000580
	--,scm.homogenisation_name							    	-- Гомогенизация SD.000581
	,hmg_eng./*homog_dsc*/homogenisation_full_name as homogenisation_name  --Гомогенизация SD.000581 
	,scm.port_of_discharge_country_code							-- Страна порта выгрузки 1 SD.000582
	,null as dt_warehouse_confirmation							-- Дата Storage confirmation SD.000583
	,null as dt_release											-- Дата релиза SD.000585
	,null as notice_name										-- Номер нотиса SD.000586
	,null as dt_notice											-- Дата нотиса SD.000587
	,null as final_release_code								    -- Номер Финальный релиз SD.000588
	,null as dt_final_invoice_payment							-- Дата оплаты Final Invoice SD.000589
	,null as vehicle_in_foreign_port_code						-- Тип ТС в ин. порту (код) SD.000590
	,null as vehicle_type_in_foreign_port_code					-- Тип ТС в ин. порту SD.000591
	,null as pb1_number									    	-- Номер PB 1 SD.000592                  -------------(!!!)
	,null as pb2_number									    	-- Номер PB 2 SD.000593                  -------------(!!!)
	,null as pb3_number									    	-- Номер PB 3 SD.000594                  -------------(!!!)
	,null as pb1_warehouse_name								    -- Склад PB 1 SD.000595                  -------------(!!!)
	,null as pb2_warehouse_name								    -- Склад PB 2 SD.000596                  -------------(!!!)
	,null as pb3_warehouse_name								    -- Склад PB 3 SD.000597                  -------------(!!!)
	,'No' as realization_status_name							-- Статус Реализации SD.000599	  -------------(!!!)
	,null as exporter_name										-- Экспортёр SD.000600
	,null as country_of_end_user_name							-- Страна конечного потребителя SD.000601
	,scm.buyer_plan_name 										-- Плановый покупатель SD.000602
	,scm.customer_for_scm_report_name 						    -- Клиент для отчета Металл в Цепочке Поставок SD.000603
	--,null as material_group_for_scm_report_name			    	-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	,mc.material_for_reporting_code as material_group_for_scm_report_name             --Группа материала для отчета Металл в Цепочке Поставок SD.000604  
	,null as assignment_name									-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	,null as vessel_and_voyage_plan_search_name                 -- Судно / номер рейса (план) SD.000607
    ,null as vessel_and_voyage_actual_search_name               -- Судно / номер рейса (факт) SD.000608
	,null as forwarder_in_foreign_port_name				    	-- Экспедитор в иностранном порту SD.000609
	,null as dt_storage_payed_in_foreign_port_by_rusal			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	,null as shipment_instruction_in_foreign_port_name			-- Инструкция на отгрузку Ин Порт SD.000612
	,null as shipment_instruction_in_foreign_port		    	-- Дата инструкции на отгрузку Ин Порт SD.000613
	,null as dt_shipment_instruction_date_from					-- SI: Дата с SD.000614
	,null as dt_shipment_instruction_date_to					-- SI: Дата по SD.000615
	,null as dt_barge_loading									-- Дата погрузки на баржу SD.000616
	,null as dt_barge_arrival									-- Дата доставки баржи SD.000617
	,null as shipment_instruction_in_second_foreign_port_name	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,null as dt_shipment_instruction_in_second_foreign_port		-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,null as dt_invoice_provisional								-- Дата инвойса SD.000620
	,null as provisional_invoice_payment_status_code			-- Статус оплаты инвойса SD.000621
	,null as prepared_for_realization_status_name				-- Признак ППС (код) SD.000623
	,null as mh1_storage_document_number						-- № Акта МХ-1 SD.000625
	,null as dt_mh1_storage_document							-- Дата Акта МХ-1 SD.000626
	,null as mh3_storage_document_number						-- № Акта МХ-3 SD.000627
	,null as dt_mh3_storage_document							-- Дата Акта МХ-3 SD.000628
	,null as dt_departure_from_foreigh_port						-- EXP: Load out date SD.000629
	,null as foreign_port_terminal_name                         -- EXP: Storage location SD.000630            -----------(!!!)
	,null as russian_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code SD.000632
	,null as foreign_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code 2 SD.000633
	,null as uzbekistan_cargo_declaration_73					-- EXP: ГТД ИМ73 SD.000634
	,null as business_location_sap_precalc_name				    -- Статус в Supply chain (Business) SD.000636
	,null as ready_for_realization_status_name                  -- Статус готовности к реализации SD.000639
	,null as country_of_destination_port_code					-- Страна порта назначения (код) SD.000646
	--,null as sales_team_name									-- Сбытовая команда SD.000651
	,case 
		when ctp.counterparty_code is not null then concat(sb_market.market_region1_name,'_trader') 
		else sb_market.market_region1_name 
	end as sales_team_name  -- SD.000651  Сбытовая команда   
	,null as delivery_region_code								-- Регион поставки по контракту (код) SD.000652
	,null as receiving_plant_in_sap_system_name				    -- Завод собственник SD.000655
	,null as dt_shipment_instruction 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	,null as shipment_instruction_name							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	,null as dt_quota_yyyymm									-- Квота в формате гггг.мм SD.000687
	,null as storage_duration_in_calendar_days                  -- Сроки нахождения в локации SD.000688 -----(!!!)
	,null as buyer_agent_name									-- Trading company SD.000704    -----(!!!)
	,null as dt_realization										-- Дата реализации SD.000720
	,null as internal_compound_key_code 				    	-- Внутренний уникальный идентификатор записи SD.000721
	,null as is_tolling_code                                    -- Признак толлинг SD.000749   ---------------(!!!)
	,null as location_stay_duration_category_code               -- Сроки нахождения в локации (месяц) SD.000750   ---------------(!!!)
	,scm.customer_for_reporting_code							-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
	,'SCHEDULED' as warehouse_or_responsible_customer_for_storage_name  -- SD.000919 General storage location  
	,null as customs_invoice_code								-- SD.000779 "Custom's invoice Group"
	,null as customs_invoice_number								-- SD.000780 "Custom's invoice Number"
	,null as dt_customs_invoice									-- SD.000781 "Custom's invoice Date"  
	,null AS dt_arrival_in_second_port_of_discharge_plan	    -- Дата прибытия в порт выгрузки 2 план SD.000157 
	,dt_acceptance_in_russian_port_planned             			 -- SD.000705 Плановая дата принятия в порту РФ 
	,to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm   -- SD.000893 "Месяц Дата отгрузки с завода" 
    ,sd_17_2.material_group_full_name  as material_group_name   -- Группа материала для отчета Металл в Цеп //as "material_group_report_mc" SD.000017         
    ,scm.buyer_plan_code                                        -- SD.000124 Плановый покупатель (код) 
    --272 доработка
	,null as dt_train_scheduled_arrival	 						--SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	,null as dt_bill_of_lading_in_russian_port_created            --SD.001214 Дата загрузки Коносамента РФ в САП
	,null as dt_bill_of_lading_in_foreign_port_created            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	,null as dt_bill_of_lading_in_russian_port_scan_copy_uploaded --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	,null as bill_of_lading_group_code_in_foreign_port            --SD.000047 Группа коносамента в ин.порту 
	,null as dt_bill_of_lading_in_foreign_port_scan_copy_uploaded --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	,scm.delivery_country_in_contract_code                        --SD.000577 Страна поставки по контракту (код)    
	--302
	,cntry_1360.country_code as country_of_consignee_code         --SD.001360 Код страны грузоплучателя 
	--311
	,null as storage_duration_in_russian_port_in_calendar_days    --SD.001385 Количество дней хранения в порту РФ
	,null as storage_duration_in_russian_port_category_code       --SD.001386 Категория хранения в порту РФ
	,null as dt_arrival_by_railway_planned						  --SD.001395 Плановая дата прибытия по жд (нормативная)
    from dm_calc.sales_stock_forecast_hist as scm
	inner join (
		select dt_report, max(dttm_inserted) as dttm_inserted
		from dm_calc.sales_stock_forecast_hist
		group by dt_report
	) as hist_max
		on scm.dt_report=hist_max.dt_report
		and scm.dttm_inserted=hist_max.dttm_inserted
	 --------SD.0000?? Material Group name----------
  /*left join dict_dds.material as sd_17_1
     on scm.material_code=sd_17_1.material_code*/
  left join dict_dds.material_group_texts as sd_17_2
     on scm.material_group_code=sd_17_2.material_group_code and sd_17_2.language_code='E'	
  --Страна POD SD.000341 Регион POD SD.000343	
  left join dm_calc.transport_hub_country as thc_341_343
	 on scm.port_of_discharge_code=thc_341_343.transport_hub_code  
--------------------------------SD.000581-----------------------------------------------------	
      left join dict_dds.material_specification ms
		on scm.material_code=ms.material_code 
    left join dict_dds./*homogenization_dsc*/homogenisation_texts as hmg_eng 
         on ms.homogenisation_code=hmg_eng./*homog_code*/homogenisation_code and hmg_eng./*lang_code*/language_code='E'   
---------------------Сбытовая команда SD.000651-------------------------------------------- 
     left join dict_dds.map_counterparty_to_market_region2 as ctp 
    	on scm.customer_code=ctp.counterparty_code   
    left join dict_dds.country as steam 
		on scm.delivery_country_in_contract_code=steam.country_code
	left join dict_dds.market_region1_texts as sb_market 
		on steam.sales_team_code=sb_market.market_region1_code 
		and sb_market.language_code='E'	
---------------------SD.000604-------------------------------------------- 	
	left join dict_dds.map_material_to_cargo_order as mc 
		on scm.material_aggr_name=mc.material_aggregated_code	
------------------576----------------------------------------------------------------		
	left join dict_dds.country c_576
	on scm.delivery_country_in_contract_code=c_576.country_code 	
 --------SD.000009----------
   left join dict_dds.location_sales ls_09
       on scm.tsw_location_code=ls_09.location_code
          left join dm_calc.transport_hub_country thc_09
          on ls_09.transport_hub_code=thc_09.transport_hub_code  	
   ------	SD.000045----
	left join dm_calc.transport_hub_country as thc_045 
		on scm.port_of_discharge_code=thc_045.transport_hub_code   	
	 --------SD.001360----------        
    left join dm_calc.counterparty_country cntry_1360 
		on scm.consignee_code=cntry_1360.counterparty_code	
where /*scm.weight_net<>0 and */scm.dt_report<>scm.dt_data_sap and now()::date=scm.dt_data_sap
union all
select --Остатки
     scm.dt_report                                          -- Отчетная дата
	,scm.delivery_number_sales                              -- Продажная поставка SD.000002
	,scm.batch                                              -- Партия SD.000004
	,scm.sales_order_in_shipment                            -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
	,scm.plant_manufact as plant_producer_name              -- Завод производитель SD.000007
	,scm.direction as tsw_location_name                     -- Направление SD.000009
	,scm.dt_shipment                                        -- Дата отгрузки SD.000010
	,scm.dt_arrival_by_railway								-- Дата прибытия по ЖД SD.000011
	,scm.dt_forwarder										-- Дата экспедитора SD.000012
	,scm.railcar											-- Вагон SD.000013
	,scm.transport_bill									    -- Накладная SD.000014
	,scm.railway_platform									-- Платформа SD.000015
	,scm.material_type as material_aggr_name				-- Материал SD.000016
	,scm.material_group_report_mc as material_group_code	-- Группа материалов SD.000017
	,scm.forwarder_name							        	-- Экспедитор SD.000021
	,scm.dt_warehouse										-- Дата склада SD.000024
	,scm.transport_railcar_type_name						-- Тип вагона SD.000029    
	,scm.weight_gross									    -- Вес брутто SD.000031
	,scm.weight_net										    -- Вес нетто SD.000032
	,scm.weight_nk as weight_net_with_wirerod			    -- Вес Н&K SD.000033
	,scm.contract_name 									    -- Контракт SD.000038
	,scm.bill_of_lading_number								-- Номер коносамента SD.000041
	,scm.dt_bill_of_lading									-- Дата коносамента SD.000042
	,scm.port_discharge as port_of_discharge_name			-- Порт выгрузки SD.000045
	,scm.bill_of_lading_in_foreign_port			    		-- Коносамент в ин.порту SD.000048
	,scm.dt_bill_of_lading_in_foreign_port					-- Дата коносамента в ин.порту SD.000049
	,scm.bill_of_lading_in_foreign_port_nomination			-- Номинация коносамента в ин. порту SD.000050
	,scm.port_discharge_abroad_sec as port_of_discharge_in_foreign_port_name			    -- Порт выгрузки 2 SD.000055
	,scm.dt_sailed_loading_port								-- Дата отплытия из порта погрузки SD.000058
	,scm.dt_arrival_in_port_of_discharge					-- Дата прибытия в порт выгрузки SD.000059
	,scm.dt_arrival_in_second_port_of_discharge				-- Дата прибытия в порт выгрузки 2 SD.000060
	,scm.external_contract_in_lot_number					-- Контракт в лоте SD.000063
	,scm.lot_customer_code									-- Покупатель в лоте (код) SD.000064
	,scm.lot_delivery_basis_code							-- Базис поставки в лоте SD.000065
	,scm.lot_delivery_point_name							-- Пункт доставки по инкотермс в лоте SD.000066
	,scm.delivery_basis										-- Базис поставки SD.000067
	,scm.delivery_point_name								-- Пункт доставки по инкотермс SD.000068
    ,scm.receiving_plant_in_sap_system_code			    	-- Принимающий завод грузополучателя в системе SAP SD.000076
	,scm.dimensions_unit									-- Размер единицы готовой продукции SD.000079
	,scm.customs_declaration_number					     	-- Номер ГТД SD.000087
	,scm.material_specification_name						-- Спецификация SD.000089
	,scm.instruction_number				    				-- Номер распоряжения SD.000101
	,scm.pieces												-- PCS SD.000115
	,scm.container_after_repacking							-- Контейнер после перетарки SD.000119
	,scm."ordering" as sales_order							-- Заказ ЦК SD.000123
	,scm.customer_special_requirement						-- Трейдеры: спец. заказ клиента SD.000127
	,scm.dt_arrival_in_port_of_discharge_plan				-- Дата прибытия в порт выгрузки план SD.000130
	,scm.dt_delivery_notice									-- Дата нотиса о доставке SD.000132
	,scm.delivery_notice_number						    	-- Номер нотиса о доставке SD.000133
	,scm.vessel_plan_name									-- Судно план SD.000134
	,scm.vessel_in_foreign_port_actual_name			    	-- Судно факт в ин. порту SD.000142
	,scm.customer_grade_name								-- Марка клиента SD.000144
	,scm.metal_grade as grade_name							-- Марка по спецификации SD.000145
	,scm.contract_plan_name							    	-- Плановый контракт SD.000148
	,scm.uni												-- UNI SD.000151
	,scm.uni_in_shipment									-- UNI в отгрузке SD.000152
	,scm.pb_number										    -- LotWshe/PB number SD.000158
	,scm.is_plan_or_actual									-- Признак План/Факт SD.000159
	,scm.dt_expected_delivery								-- Ожидаемая дата доставки до клиента SD.000162
	,scm.buyer_end_name as end_user_for_reporting_name		-- Конечный потребитель SD.000164
	,scm.invoice_provisional_number						    -- Инвойс (счет клиенту) SD.000167
	,scm.release_group_name								    -- Релиз SD.000169
	,scm.pledge_in_bank_name								-- Pledge Bank SD.000172
	,scm.dt_storage_start_in_foreign_port					-- Дата начала хранения ин. склад SD.000175
	,scm.dt_storage_end_in_foreign_port						-- Окончание хранения в ин. порту SD.000176
	,scm.dt_storage_start_in_second_foreign_warehouse		-- Начало хранения склад 2 SD.000177
	,scm.dt_storage_end_in_second_foreign_warehouse		    -- Окончание хранение склад 2 SD.000178
	,scm.sales_contract_code								-- Контракт сбыта (код) SD.000179
	,scm.material_shape_name_full							-- Форма SD.000180
	,scm.lot_customer_name                                  -- Покупатель в лоте SD.000193                 --------------(!!!)
	,scm.dt_realization_forecast 							-- Расчетная дата реализации SD.000243
	,null as pledge_in_bank_code							-- Pledge Bank (code) SD.000252
	,scm.dt_expected_bill_of_lading							-- Ожидаемая дата коносамента SD.000253
	,scm.delivery_instruction_code							-- Иструкция на доставку SD.000254
	,scm.incoterms_plan_code								-- Плановый базис поставки SD.000255
	,scm.incoterms_location_plan_code						-- Плановый пункт доставки по инкотермс SD.000256
	,scm.dt_release_material								-- Дата ОМ SD.000259
	,scm.release_material_status_code                       -- Статус ОМ SD.000260
	,scm.delivery_region as delivery_region_name			-- Регион поставки по контракту SD.000338
	,scm.location_from_stock                                         -- Локация SD.000339     -------------(!!!)
	,scm.country as country_of_discharge_port_name                     -- Страна POD SD.000341                       -------------(!!!)
	,scm.region as region_of_destination_port_name			-- Регион POD SD.000343
	,scm.dt_prepared_for_realization						-- Дата готовности к реализации SD.000344
	,scm.dest_port as port_of_destination_name				-- Порт назначения SD.000376
	,scm.is_consigment_warehouse_applicable					-- Признак консигнации SD.000480
	,scm.dt_transfer_from_consignment_to_customer			-- Дата перехода из консигнации клиенту SD.000481
	,scm.dt_final_release									-- Дата Финальный релиз SD.000482
	,scm.is_shipped_via_overseas_warehouse					-- Наличие Иностранный склад SD.000483
	,scm.dt_forwarder_discharge_invoice_or_cmr_documented	-- ТН/CMR: Дата выгрузки авто SD.000484
	,scm.is_shipped_via_overseas_second_foreign_warehouse	-- Наличие Иностранный склад 2 SD.000485
	,scm.dt_arrived_via_ul_system							-- Дата прибытия УЛ SD.000487
	,scm.dt_repacked										-- Дата перетарки SD.000488
	,scm.warehouse_shipment_type_name						-- СВХ SD.000489
	,scm.warehouse_gross_weight						    	-- Вес брутто (с учетом склада) SD.000490
	,scm.railway_movement_status_name						-- Статус движения по ЖД SD.000491
	,scm.business_location_sap_precalc_name						    	-- Статус в Supply chain (Business) SD.000492
	,scm.transportation_scenario_code						-- Сценарий маршрута SD.000550
	,scm.delivery_country_in_contract_name					-- Страна поставки по контракту SD.000576
	,scm.commitment_weight								    -- Объем обязательств SD.000578
	,scm.total_commitment_weight						    -- Объем обязательств итого SD.000579
	,scm.lot_code											-- Номер лота SD.000580
	,scm.homogenisation_name								-- Гомогенизация SD.000581
	,scm.port_of_discharge_country_code						-- Страна порта выгрузки 1 SD.000582
	,scm.dt_warehouse_confirmation							-- Дата Storage confirmation SD.000583
	,scm.dt_release											-- Дата релиза SD.000585
	,scm.notice_name										-- Номер нотиса SD.000586
	,scm.dt_notice											-- Дата нотиса SD.000587
	,scm.final_release_code								    -- Номер Финальный релиз SD.000588
	,scm.dt_final_invoice_payment							-- Дата оплаты Final Invoice SD.000589
	,scm.vehicle_in_foreign_port_code						-- Тип ТС в ин. порту (код) SD.000590
	,scm.vehicle_type_in_foreign_port_code					-- Тип ТС в ин. порту SD.000591
	,scm.pb1_number									    	-- Номер PB 1 SD.000592                  -------------(!!!)
	,scm.pb2_number									    	-- Номер PB 2 SD.000593                  -------------(!!!)
	,scm.pb3_number								         	-- Номер PB 3 SD.000594                  -------------(!!!)
	,scm.pb1_warehouse_name								    -- Склад PB 1 SD.000595                  -------------(!!!)
	,scm.pb2_warehouse_name								    -- Склад PB 2 SD.000596                  -------------(!!!)
	,scm.pb3_warehouse_name								    -- Склад PB 3 SD.000597                  -------------(!!!)
	,scm.realization_status as realization_status_name		-- Статус Реализации SD.000599	 -------------(!!!)
	,scm.exporter_name										-- Экспортёр SD.000600
	,scm.country_of_end_user_name							-- Страна конечного потребителя SD.000601
	,scm.buyer_plan_name 									-- Плановый покупатель SD.000602
	,scm.customer_for_scm_report_name 					    -- Клиент для отчета Металл в Цепочке Поставок SD.000603
	,scm.material_group_for_scm_report_name			    	-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	,scm.forwarder_instruction_name as assignment_name		-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	,scm.vessel_and_voyage_plan_search_name                 -- Судно / номер рейса (план) SD.000607
    ,scm.vessel_and_voyage_actual_search_name               -- Судно / номер рейса (факт) SD.000608
	,scm.forwarder_in_foreign_port_name				    	-- Экспедитор в иностранном порту SD.000609
	,scm.dt_storage_payed_in_foreign_port_by_rusal			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	,scm.shipment_instruction_in_foreign_port_name			-- Инструкция на отгрузку Ин Порт SD.000612
	,scm.dt_shipment_instruction_in_foreign_port			-- Дата инструкции на отгрузку Ин Порт SD.000613
	,scm.dt_shipment_instruction_date_from					-- SI: Дата с SD.000614
	,scm.dt_shipment_instruction_date_to					-- SI: Дата по SD.000615
	,scm.dt_barge_loading									-- Дата погрузки на баржу SD.000616
	,scm.dt_barge_arrival									-- Дата доставки баржи SD.000617
	,scm.shipment_instruction_in_second_foreign_port_name	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,scm.dt_shipment_instruction_in_second_foreign_port		-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,scm.dt_invoice_provisional								-- Дата инвойса SD.000620
	,scm.provisional_invoice_payment_status_code			-- Статус оплаты инвойса SD.000621
	,scm.prepared_for_realization_status_name				-- Признак ППС (код) SD.000623
	,null as mh1_storage_document_number					-- № Акта МХ-1 SD.000625
	,null as dt_mh1_storage_document						-- Дата Акта МХ-1 SD.000626
	,null as mh3_storage_document_number					-- № Акта МХ-3 SD.000627
	,null as dt_mh3_storage_document						-- Дата Акта МХ-3 SD.000628
	,scm.dt_departure_from_foreigh_port						-- EXP: Load out date SD.000629
	,scm.foreign_port_terminal_name                         -- EXP: Storage location SD.000630            -----------(!!!)
	,scm.russian_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code SD.000632
	,scm.foreign_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code 2 SD.000633
	,scm.uzbekistan_cargo_declaration_73					-- EXP: ГТД ИМ73 SD.000634
	,scm.business_location_sap_precalc_name as business_location_sap_precalc_name				    -- Статус в Supply chain (Business) SD.000636
	,scm.ready_for_realization_status_name                  -- Статус готовности к реализации SD.000639
	,scm.country_of_destination_port_code					-- Страна порта назначения (код) SD.000646
	,scm.sales_team_name									-- Сбытовая команда SD.000651
	,scm.delivery_region_code								-- Регион поставки по контракту (код) SD.000652
	,scm.receiving_plant_in_sap_system_name				    -- Завод собственник SD.000655
	,scm.dt_shipment_instruction_ds as dt_shipment_instruction 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	,scm.shipment_instruction_number_ds as shipment_instruction_name							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	,concat(left(scm.quota,4),'.',right(scm.quota,2)) as dt_quota_yyyymm									-- Квота в формате гггг.мм SD.000687
	,scm.storage_duration_in_calendar_days                  -- Сроки нахождения в локации SD.000688 -------(!!!)
	,scm.buyer_agent_name									-- Trading company SD.000704                                       ---(!!!)
	,case when scm.dt_report<scm.dt_realization then null else scm.dt_realization end as dt_realization	    -- Дата реализации SD.000720
	,scm.internal_compound_key_code 				    	-- Внутренний уникальный идентификатор записи SD.000721
	,scm.is_tolling_code                                    -- Признак толлинг SD.000749   ---------------(!!!)
	,case when scm.storage_duration_in_calendar_days::integer=0 then null
		when scm.storage_duration_in_calendar_days::integer between 1  and 30 then '<=1M'
		when scm.storage_duration_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
		when scm.storage_duration_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		when scm.storage_duration_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		when scm.storage_duration_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		else '>1Y' end  as location_stay_duration_category_code   --Сроки нахождения в локации (месяц) SD.000750 ---------------(!!!)
	,scm.customer_for_scm_report_code AS customer_for_reporting_code							-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
    ,scm.warehouse_or_responsible_customer_for_storage_name  -- SD.000919 General storage location  
    ,scm.customs_invoice_code								-- SD.000779 "Custom's invoice Group"
	,scm.customs_invoice_number								-- SD.000780 "Custom's invoice Number"
	,scm.dt_customs_invoice									-- SD.000781 "Custom's invoice Date"  
	,scm.dt_arrival_in_second_port_of_discharge_plan				-- Дата прибытия в порт выгрузки 2 план SD.000157
	,scm.dt_acceptance_in_russian_port_planned                -- SD.000705 Плановая дата принятия в порту РФ  
	,to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm   -- SD.000893 "Месяц Дата отгрузки с завода" 
	--236
	,scm.material_group_name                                -- SD.0000?? Группа материала название
    ,scm.buyer_plan_code                                    -- SD.000124 Плановый покупатель (код) 
    --272 доработка
	,scm.dt_train_scheduled_arrival	 						--SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	,scm.dt_bill_of_lading_in_russian_port_created            --SD.001214 Дата загрузки Коносамента РФ в САП
	,scm.dt_bill_of_lading_in_foreign_port_created            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	,scm.dt_bill_of_lading_in_russian_port_scan_copy_uploaded --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	,scm.bill_of_lading_group_code_in_foreign_port            --SD.000047 Группа коносамента в ин.порту 
	,scm.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	 --295
	,scm.delivery_country_in_contract_code                     --SD.000577 Страна поставки по контракту (код) 
	--302
	,scm.country_of_consignee_code                 --SD.001360 Код страны грузоплучателя 
	--311
	,scm.storage_duration_in_russian_port_in_calendar_days    --SD.001385 Количество дней хранения в порту РФ
	,case
   	    when scm.storage_duration_in_russian_port_in_calendar_days is not null 
        then case
	         when scm.storage_duration_in_russian_port_in_calendar_days::integer = 0 then null
   	         when scm.storage_duration_in_russian_port_in_calendar_days::integer between 1  and 30 then '<=1M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		     else '>1Y'
		    end
   	  end as storage_duration_in_russian_port_category_code      --SD.001386 Категория хранения в порту РФ
   	 ,scm.dt_arrival_by_railway_planned							 --SD.001395 Плановая дата прибытия по жд (нормативная)
	from dm_calc.sd_sales_stock_by_date scm
where /*scm.weight_net<>0 and */scm.warehouse_shipment_type_name is null  and scm.dt_report>='2024-01-01'
union all
select --СВХ: На складе. Где веса=вес на складе минус вес со склада
     scm.dt_report                                          -- Отчетная дата
	,scm.delivery_number_sales                              -- Продажная поставка SD.000002
	,scm.batch                                              -- Партия SD.000004
	,scm.sales_order_in_shipment                            -- Заказ ЦК в отгрузке SD.000005	-------------------------(!!!)
	,scm.plant_manufact as plant_producer_name              -- Завод производитель SD.000007
	,scm.direction as tsw_location_name                     -- Направление SD.000009
	,scm.dt_shipment                                        -- Дата отгрузки SD.000010
	,scm.dt_arrival_by_railway								-- Дата прибытия по ЖД SD.000011
	,scm.dt_forwarder										-- Дата экспедитора SD.000012
	,scm.railcar											-- Вагон SD.000013
	,scm.transport_bill									    -- Накладная SD.000014
	,scm.railway_platform									-- Платформа SD.000015
	,scm.material_type as material_aggr_name				-- Материал SD.000016
	,scm.material_group_report_mc as material_group_code	-- Группа материалов SD.000017
	,scm.forwarder_name							        	-- Экспедитор SD.000021
	,scm.dt_warehouse										-- Дата склада SD.000024
	,scm.transport_railcar_type_name						-- Тип вагона SD.000029  
	,scm.weight_gross									    -- Вес брутто SD.000031
	,scm.weight_net										    -- Вес нетто SD.000032
	,scm.weight_nk as weight_net_with_wirerod			    -- Вес Н&K SD.000033
	,scm.contract_name 									    -- Контракт SD.000038
	,scm.bill_of_lading_number								-- Номер коносамента SD.000041
	,scm.dt_bill_of_lading									-- Дата коносамента SD.000042
	,scm.port_discharge as port_of_discharge_name			-- Порт выгрузки SD.000045
	,scm.bill_of_lading_in_foreign_port			    		-- Коносамент в ин.порту SD.000048
	,scm.dt_bill_of_lading_in_foreign_port					-- Дата коносамента в ин.порту SD.000049
	,scm.bill_of_lading_in_foreign_port_nomination			-- Номинация коносамента в ин. порту SD.000050
	,scm.port_discharge_abroad_sec as port_of_discharge_in_foreign_port_name			    -- Порт выгрузки 2 SD.000055
	,scm.dt_sailed_loading_port								-- Дата отплытия из порта погрузки SD.000058
	,scm.dt_arrival_in_port_of_discharge					-- Дата прибытия в порт выгрузки SD.000059
	,scm.dt_arrival_in_second_port_of_discharge				-- Дата прибытия в порт выгрузки 2 SD.000060
	,scm.external_contract_in_lot_number					-- Контракт в лоте SD.000063
	,scm.lot_customer_code									-- Покупатель в лоте (код) SD.000064
	,scm.lot_delivery_basis_code							-- Базис поставки в лоте SD.000065
	,scm.lot_delivery_point_name							-- Пункт доставки по инкотермс в лоте SD.000066
	,scm.delivery_basis										-- Базис поставки SD.000067
	,scm.delivery_point_name								-- Пункт доставки по инкотермс SD.000068
    ,scm.receiving_plant_in_sap_system_code			    	-- Принимающий завод грузополучателя в системе SAP SD.000076
	,scm.dimensions_unit									-- Размер единицы готовой продукции SD.000079
	,scm.customs_declaration_number					     	-- Номер ГТД SD.000087
	,scm.material_specification_name						-- Спецификация SD.000089
	,scm.instruction_number				    				-- Номер распоряжения SD.000101
	,scm.pieces												-- PCS SD.000115
	,scm.container_after_repacking							-- Контейнер после перетарки SD.000119
	,scm."ordering" as sales_order							-- Заказ ЦК SD.000123
	,scm.customer_special_requirement						-- Трейдеры: спец. заказ клиента SD.000127
	,scm.dt_arrival_in_port_of_discharge_plan				-- Дата прибытия в порт выгрузки план SD.000130
	,scm.dt_delivery_notice									-- Дата нотиса о доставке SD.000132
	,scm.delivery_notice_number						    	-- Номер нотиса о доставке SD.000133
	,scm.vessel_plan_name									-- Судно план SD.000134
	,scm.vessel_in_foreign_port_actual_name			    	-- Судно факт в ин. порту SD.000142
	,scm.customer_grade_name								-- Марка клиента SD.000144
	,scm.metal_grade as grade_name							-- Марка по спецификации SD.000145
	,scm.contract_plan_name							    	-- Плановый контракт SD.000148
	,scm.uni												-- UNI SD.000151
	,scm.uni_in_shipment									-- UNI в отгрузке SD.000152
	,scm.pb_number										    -- LotWshe/PB number SD.000158
	,scm.is_plan_or_actual									-- Признак План/Факт SD.000159
	,scm.dt_expected_delivery								-- Ожидаемая дата доставки до клиента SD.000162
	,scm.buyer_end_name as end_user_for_reporting_name		-- Конечный потребитель SD.000164
	,scm.invoice_provisional_number						    -- Инвойс (счет клиенту) SD.000167
	,scm.release_group_name								    -- Релиз SD.000169
	,scm.pledge_in_bank_name								-- Pledge Bank SD.000172
	,scm.dt_storage_start_in_foreign_port					-- Дата начала хранения ин. склад SD.000175
	,scm.dt_storage_end_in_foreign_port						-- Окончание хранения в ин. порту SD.000176
	,scm.dt_storage_start_in_second_foreign_warehouse		-- Начало хранения склад 2 SD.000177
	,scm.dt_storage_end_in_second_foreign_warehouse		    -- Окончание хранение склад 2 SD.000178
	,scm.sales_contract_code								-- Контракт сбыта (код) SD.000179
	,scm.material_shape_name_full							-- Форма SD.000180
	,scm.lot_customer_name                                  -- Покупатель в лоте SD.000193                 --------------(!!!)
	,scm.dt_realization_forecast 							-- Расчетная дата реализации SD.000243
	,null as pledge_in_bank_code							-- Pledge Bank (code) SD.000252
	,scm.dt_expected_bill_of_lading							-- Ожидаемая дата коносамента SD.000253
	,scm.delivery_instruction_code							-- Иструкция на доставку SD.000254
	,scm.incoterms_plan_code								-- Плановый базис поставки SD.000255
	,scm.incoterms_location_plan_code						-- Плановый пункт доставки по инкотермс SD.000256
	,scm.dt_release_material								-- Дата ОМ SD.000259
	,scm.release_material_status_code                       -- Статус ОМ SD.000260
	,scm.delivery_region as delivery_region_name			-- Регион поставки по контракту SD.000338
	,scm.location_from_stock                                         -- Локация SD.000339     -------------(!!!)
	,scm.country as country_of_discharge_port_name          -- Страна POD SD.000341                       -------------(!!!)
	,scm.region as region_of_destination_port_name			-- Регион POD SD.000343
	,scm.dt_prepared_for_realization						-- Дата готовности к реализации SD.000344
	,scm.dest_port as port_of_destination_name				-- Порт назначения SD.000376
	,scm.is_consigment_warehouse_applicable					-- Признак консигнации SD.000480
	,scm.dt_transfer_from_consignment_to_customer			-- Дата перехода из консигнации клиенту SD.000481
	,scm.dt_final_release									-- Дата Финальный релиз SD.000482
	,scm.is_shipped_via_overseas_warehouse					-- Наличие Иностранный склад SD.000483
	,scm.dt_forwarder_discharge_invoice_or_cmr_documented	-- ТН/CMR: Дата выгрузки авто SD.000484
	,scm.is_shipped_via_overseas_second_foreign_warehouse	-- Наличие Иностранный склад 2 SD.000485
	,scm.dt_arrived_via_ul_system							-- Дата прибытия УЛ SD.000487
	,scm.dt_repacked										-- Дата перетарки SD.000488
	,scm.warehouse_shipment_type_name						-- СВХ SD.000489
	,scm.warehouse_gross_weight						    	-- Вес брутто (с учетом склада) SD.000490
	,scm.railway_movement_status_name						-- Статус движения по ЖД SD.000491
	,scm.business_location_sap_precalc_name						    	-- Статус в Supply chain (Business) SD.000492
	,scm.transportation_scenario_code						-- Сценарий маршрута SD.000550	
	,scm.delivery_country_in_contract_name					-- Страна поставки по контракту SD.000576
	,scm.commitment_weight								    -- Объем обязательств SD.000578
	,scm.total_commitment_weight						    -- Объем обязательств итого SD.000579
	,scm.lot_code											-- Номер лота SD.000580
	,scm.homogenisation_name								-- Гомогенизация SD.000581
	,scm.port_of_discharge_country_code						-- Страна порта выгрузки 1 SD.000582
	,scm.dt_warehouse_confirmation							-- Дата Storage confirmation SD.000583
	,scm.dt_release											-- Дата релиза SD.000585
	,scm.notice_name										-- Номер нотиса SD.000586
	,scm.dt_notice											-- Дата нотиса SD.000587
	,scm.final_release_code								    -- Номер Финальный релиз SD.000588
	,scm.dt_final_invoice_payment							-- Дата оплаты Final Invoice SD.000589
	,scm.vehicle_in_foreign_port_code						-- Тип ТС в ин. порту (код) SD.000590
	,scm.vehicle_type_in_foreign_port_code					-- Тип ТС в ин. порту SD.000591
	,scm.pb1_number									    	-- Номер PB 1 SD.000592                  -------------(!!!)
	,scm.pb2_number									    	-- Номер PB 2 SD.000593                  -------------(!!!)
	,scm.pb3_number								         	-- Номер PB 3 SD.000594                  -------------(!!!)
	,scm.pb1_warehouse_name								    -- Склад PB 1 SD.000595                  -------------(!!!)
	,scm.pb2_warehouse_name								    -- Склад PB 2 SD.000596                  -------------(!!!)
	,scm.pb3_warehouse_name								    -- Склад PB 3 SD.000597                  -------------(!!!)
	,scm.realization_status as realization_status_name		-- Статус Реализации SD.000599	   -------------(!!!)
	,scm.exporter_name										-- Экспортёр SD.000600
	,scm.country_of_end_user_name							-- Страна конечного потребителя SD.000601
	,scm.buyer_plan_name 									-- Плановый покупатель SD.000602
	,scm.customer_for_scm_report_name 					    -- Клиент для отчета Металл в Цепочке Поставок SD.000603
	,scm.material_group_for_scm_report_name			    	-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	,scm.forwarder_instruction_name as assignment_name		-- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	,scm.vessel_and_voyage_plan_search_name                 -- Судно / номер рейса (план) SD.000607
    ,scm.vessel_and_voyage_actual_search_name               -- Судно / номер рейса (факт) SD.000608
	,scm.forwarder_in_foreign_port_name				    	-- Экспедитор в иностранном порту SD.000609
	,scm.dt_storage_payed_in_foreign_port_by_rusal			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	,scm.shipment_instruction_in_foreign_port_name			-- Инструкция на отгрузку Ин Порт SD.000612
	,scm.dt_shipment_instruction_in_foreign_port			-- Дата инструкции на отгрузку Ин Порт SD.000613
	,scm.dt_shipment_instruction_date_from					-- SI: Дата с SD.000614
	,scm.dt_shipment_instruction_date_to					-- SI: Дата по SD.000615
	,scm.dt_barge_loading									-- Дата погрузки на баржу SD.000616
	,scm.dt_barge_arrival									-- Дата доставки баржи SD.000617
	,scm.shipment_instruction_in_second_foreign_port_name	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,scm.dt_shipment_instruction_in_second_foreign_port		-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,scm.dt_invoice_provisional								-- Дата инвойса SD.000620
	,scm.provisional_invoice_payment_status_code			-- Статус оплаты инвойса SD.000621
	,scm.prepared_for_realization_status_name				-- Признак ППС (код) SD.000623
	,scm.mh1_storage_document_number				    	-- № Акта МХ-1 SD.000625
	,scm.dt_mh1_storage_document							-- Дата Акта МХ-1 SD.000626
	,null as mh3_storage_document_number						-- № Акта МХ-3 SD.000627
	,null as dt_mh3_storage_document							-- Дата Акта МХ-3 SD.000628
	,scm.dt_departure_from_foreigh_port						-- EXP: Load out date SD.000629
	,scm.foreign_port_terminal_name                         -- EXP: Storage location SD.000630            -----------(!!!)
	,scm.russian_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code SD.000632
	,scm.foreign_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code 2 SD.000633
	,scm.uzbekistan_cargo_declaration_73					-- EXP: ГТД ИМ73 SD.000634
	,scm.business_location_sap_precalc_name as business_location_sap_precalc_name				    -- Статус в Supply chain (Business) SD.000636
	,scm.ready_for_realization_status_name                  -- Статус готовности к реализации SD.000639
	,scm.country_of_destination_port_code					-- Страна порта назначения (код) SD.000646
	,scm.sales_team_name									-- Сбытовая команда SD.000651
	,scm.delivery_region_code								-- Регион поставки по контракту (код) SD.000652
	,scm.receiving_plant_in_sap_system_name				    -- Завод собственник SD.000655
	,scm.dt_shipment_instruction_ds as dt_shipment_instruction 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   ----(!!!)
	,scm.shipment_instruction_number_ds as shipment_instruction_name							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) -----(!!!)
	,concat(left(scm.quota,4),'.',right(scm.quota,2)) as dt_quota_yyyymm									-- Квота в формате гггг.мм SD.000687
	,scm.storage_duration_in_calendar_days                  -- Сроки нахождения в локации SD.000688 -------(!!!)
	,scm.buyer_agent_name									-- Trading company SD.000704                                       ---(!!!)
	,case when scm.dt_report<scm.dt_realization then null else scm.dt_realization end as dt_realization	    -- Дата реализации SD.000720
	,scm.internal_compound_key_code 				    	-- Внутренний уникальный идентификатор записи SD.000721	
	,scm.is_tolling_code                                    -- Признак толлинг SD.000749   ---------------(!!!)
	,case when scm.storage_duration_in_calendar_days::integer=0 then null 
		when scm.storage_duration_in_calendar_days::integer between 1  and 30 then '<=1M'
		when scm.storage_duration_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
		when scm.storage_duration_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		when scm.storage_duration_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		when scm.storage_duration_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		else '>1Y' end  as location_stay_duration_category_code   --Сроки нахождения в локации (месяц) SD.000750 
	,scm.customer_for_scm_report_code AS customer_for_reporting_code							-- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771
    ,scm.warehouse_or_responsible_customer_for_storage_name  -- SD.000919 General storage location  
     ,null as customs_invoice_code								-- SD.000779 "Custom's invoice Group"
	,null as customs_invoice_number								-- SD.000780 "Custom's invoice Number"
	,null as dt_customs_invoice									-- SD.000781 "Custom's invoice Date"   
	,scm.dt_arrival_in_second_port_of_discharge_plan				-- Дата прибытия в порт выгрузки 2 план SD.000157 
	,scm.dt_acceptance_in_russian_port_planned                -- SD.000705 Плановая дата принятия в порту РФ
	,to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm   -- SD.000893 "Месяц Дата отгрузки с завода" 
	--236
	,scm.material_group_name                                -- SD.0000?? Группа материала название
	,scm.buyer_plan_code                                    -- SD.000124 Плановый покупатель (код) 
	--272 доработка
	,scm.dt_train_scheduled_arrival	 						--SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	,scm.dt_bill_of_lading_in_russian_port_created            --SD.001214 Дата загрузки Коносамента РФ в САП
	,scm.dt_bill_of_lading_in_foreign_port_created            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	,scm.dt_bill_of_lading_in_russian_port_scan_copy_uploaded --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	,scm.bill_of_lading_group_code_in_foreign_port            --SD.000047 Группа коносамента в ин.порту 
	,scm.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	--295
	,scm.delivery_country_in_contract_code                     --SD.000577 Страна поставки по контракту (код) 
	--302
	,scm.country_of_consignee_code                 --SD.001360 Код страны грузоплучателя  
	--311
	,scm.storage_duration_in_russian_port_in_calendar_days    --SD.001385 Количество дней хранения в порту РФ
	,case
   	    when scm.storage_duration_in_russian_port_in_calendar_days is not null 
        then case
	         when scm.storage_duration_in_russian_port_in_calendar_days::integer = 0 then null
   	         when scm.storage_duration_in_russian_port_in_calendar_days::integer between 1  and 30 then '<=1M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		     else '>1Y'
		    end
   	  end as storage_duration_in_russian_port_category_code      --SD.001386 Категория хранения в порту РФ
   	  ,scm.dt_arrival_by_railway_planned						--SD.001395 Плановая дата прибытия по жд (нормативная)
 from dm_calc.sd_sales_svh_stock_by_date scm
where /*scm.weight_net<>0 and*/ scm.dt_report>='2024-01-01'
union all 
select --СГП 
     scm.dt_report                                              -- Отчетная дата
	,null as delivery_number_sales                              -- Продажная поставка SD.000002
	,scm.batch                                                  -- Партия SD.000004                                                --ver 192
	,scm.sales_order_in_shipment                                -- Заказ ЦК в отгрузке SD.000005                                   --ver 192
	,scm.plant_manufact as plant_producer_name                  -- Завод производитель SD.000007                                   --ver 192
	,scm.direction as tsw_location_name                         -- Направление SD.000009                                           --ver 192
	,scm.dt_shipment                                            -- Дата отгрузки SD.000010                                         --ver 192
	,null as dt_arrival_by_railway								-- Дата прибытия по ЖД SD.000011
	,null as dt_forwarder										-- Дата экспедитора SD.000012
	,scm.railcar											    -- Вагон SD.000013                                                 --ver 192
	,scm.transport_bill									        -- Накладная SD.000014                                             --ver 192
	,null as railway_platform									-- Платформа SD.000015
	,scm.material_type as material_aggr_name				    -- Материал SD.000016                                              --ver 192
	,scm.material_group_report_mc as material_group_code	    -- Группа материалов SD.000017                                     --ver 192
	,null as forwarder_name							        	-- Экспедитор SD.000021
	,null as dt_warehouse										-- Дата склада SD.000024
	,null as transport_railcar_type_name						-- Тип вагона SD.000029
	,null as weight_gross									    -- Вес брутто SD.000031
	,scm.weight_net								    		    -- Вес нетто SD.000032                                             --ver 192
	,null as weight_net_with_wirerod			                -- Вес Н&K SD.000033
	,null as contract_name 									    -- Контракт SD.000038
	,null as bill_of_lading_number								-- Номер коносамента SD.000041
	,null as dt_bill_of_lading									-- Дата коносамента SD.000042
	,scm.port_discharge as port_of_discharge_name			    -- Порт выгрузки SD.000045                                         --ver 192
	,null as bill_of_lading_in_foreign_port			    		-- Коносамент в ин.порту SD.000048
	,null as dt_bill_of_lading_in_foreign_port					-- Дата коносамента в ин.порту SD.000049
	,null as bill_of_lading_in_foreign_port_nomination			-- Номинация коносамента в ин. порту SD.000050
	,null as port_of_discharge_in_foreign_port_name			    -- Порт выгрузки 2 SD.000055
	,null as dt_sailed_loading_port								-- Дата отплытия из порта погрузки SD.000058
	,null as dt_arrival_in_port_of_discharge					-- Дата прибытия в порт выгрузки SD.000059
	,null as dt_arrival_in_second_port_of_discharge				-- Дата прибытия в порт выгрузки 2 SD.000060
	,null as external_contract_in_lot_number					-- Контракт в лоте SD.000063
	,null as lot_customer_code									-- Покупатель в лоте (код) SD.000064
	,null as lot_delivery_basis_code							-- Базис поставки в лоте SD.000065
	,null as lot_delivery_point_name							-- Пункт доставки по инкотермс в лоте SD.000066
	,scm.delivery_basis			     							-- Базис поставки SD.000067                                         --ver 192
	,scm.delivery_point_name								    -- Пункт доставки по инкотермс SD.000068                            --ver 192
    ,null as receiving_plant_in_sap_system_code			    	-- Принимающий завод грузополучателя в системе SAP SD.000076
	,scm.dimensions_unit									    -- Размер единицы готовой продукции SD.000079                       --ver 192
	,null as customs_declaration_number					     	-- Номер ГТД SD.000087
	,null as material_specification_name						-- Спецификация SD.000089
	,null as instruction_number				    				-- Номер распоряжения SD.000101
	,null as pieces												-- PCS SD.000115
	,null as container_after_repacking							-- Контейнер после перетарки SD.000119
	,scm."ordering" as sales_order							    -- Заказ ЦК SD.000123                                              --ver 192
	,scm.customer_special_requirement					    	-- Трейдеры: спец. заказ клиента SD.000127                         --ver 192
	,null as dt_arrival_in_port_of_discharge_plan				-- Дата прибытия в порт выгрузки план SD.000130
	,null as dt_delivery_notice									-- Дата нотиса о доставке SD.000132
	,null as delivery_notice_number						    	-- Номер нотиса о доставке SD.000133
	,null as vessel_plan_name									-- Судно план SD.000134
	,null as vessel_in_foreign_port_actual_name			    	-- Судно факт в ин. порту SD.000142
	,scm.customer_grade_name							    	-- Марка клиента SD.000144                                         --ver 192
	,scm.metal_grade as grade_name						    	-- Марка по спецификации SD.000145                                 --ver 192
	,scm.contract_plan_name							        	-- Плановый контракт SD.000148                                     --ver 192 
	,null as uni												-- UNI SD.000151
	,null as uni_in_shipment									-- UNI в отгрузке SD.000152
	,null as pb_number										    -- LotWshe/PB number SD.000158
	,null as is_plan_or_actual									-- Признак План/Факт SD.000159
	,null as dt_expected_delivery								-- Ожидаемая дата доставки до клиента SD.000162
	,null as end_user_for_reporting_name		                -- Конечный потребитель SD.000164
	,null as invoice_provisional_number						    -- Инвойс (счет клиенту) SD.000167
	,null as release_group_name								    -- Релиз SD.000169
	,null as pledge_in_bank_name								-- Pledge Bank SD.000172
	,null as dt_storage_start_in_foreign_port					-- Дата начала хранения ин. склад SD.000175
	,null as dt_storage_end_in_foreign_port						-- Окончание хранения в ин. порту SD.000176
	,null as dt_storage_start_in_second_foreign_warehouse		-- Начало хранения склад 2 SD.000177
	,null as dt_storage_end_in_second_foreign_warehouse		    -- Окончание хранение склад 2 SD.000178
	,null as sales_contract_code								-- Контракт сбыта (код) SD.000179
	,scm.material_shape_name_full						    	-- Форма SD.000180                                                --ver 192 
	,null as lot_customer_name                                  -- Покупатель в лоте SD.000193                
	,null as dt_realization_forecast 							-- Расчетная дата реализации SD.000243
	,null as pledge_in_bank_code							    -- Pledge Bank (code) SD.000252
	,null as dt_expected_bill_of_lading							-- Ожидаемая дата коносамента SD.000253
	,null as delivery_instruction_code							-- Иструкция на доставку SD.000254
	,scm.incoterms_plan_code			    					-- Плановый базис поставки SD.000255                             --ver 192
	,scm.incoterms_location_plan_code						    -- Плановый пункт доставки по инкотермс SD.000256                --ver 192
	,null as dt_release_material							    -- Дата ОМ SD.000259 --                                          
	,null as release_material_status_code                       -- Статус ОМ SD.000260
	,scm.delivery_region_name		                        	-- Регион поставки по контракту SD.000338                        --ver 192
	,null as "location"                                         -- Локация SD.000339     
	,scm.country_of_discharge_port_name                         -- Страна POD SD.000341                                          --ver 192
	,scm.region_of_destination_port_name	             		-- Регион POD SD.000343                                          --ver 192
	,null as dt_prepared_for_realization						-- Дата готовности к реализации SD.000344
	,null as port_of_destination_name				            -- Порт назначения SD.000376
	,null as is_consigment_warehouse_applicable					-- Признак консигнации SD.000480
	,null as dt_transfer_from_consignment_to_customer			-- Дата перехода из консигнации клиенту SD.000481
	,null as dt_final_release									-- Дата Финальный релиз SD.000482
	,null as is_shipped_via_overseas_warehouse					-- Наличие Иностранный склад SD.000483
	,null as dt_forwarder_discharge_invoice_or_cmr_documented	-- ТН/CMR: Дата выгрузки авто SD.000484
	,null as is_shipped_via_overseas_second_foreign_warehouse	-- Наличие Иностранный склад 2 SD.000485
	,null as dt_arrived_via_ul_system							-- Дата прибытия УЛ SD.000487
	,null as dt_repacked										-- Дата перетарки SD.000488
	,null as warehouse_shipment_type_name						-- СВХ SD.000489
	,null as warehouse_gross_weight						    	-- Вес брутто (с учетом склада) SD.000490
	,null as railway_movement_status_name						-- Статус движения по ЖД SD.000491
	,scm.business_location_sap_precalc_name						        	-- Статус в Supply chain (Business) SD.000492
	,null as transportation_scenario_code						-- Сценарий маршрута SD.000550	
	,scm.delivery_country_in_contract_name			    		-- Страна поставки по контракту SD.000576                            --ver 192
	,null as commitment_weight								    -- Объем обязательств SD.000578
	,null as total_commitment_weight						    -- Объем обязательств итого SD.000579
	,null as lot_code											-- Номер лота SD.000580
	,null as homogenisation_name								-- Гомогенизация SD.000581
	,null as port_of_discharge_country_code						-- Страна порта выгрузки 1 SD.000582
	,null as dt_warehouse_confirmation							-- Дата Storage confirmation SD.000583
	,null as dt_release											-- Дата релиза SD.000585
	,null as notice_name										-- Номер нотиса SD.000586
	,null as dt_notice											-- Дата нотиса SD.000587
	,null as final_release_code								    -- Номер Финальный релиз SD.000588
	,null as dt_final_invoice_payment							-- Дата оплаты Final Invoice SD.000589
	,null as vehicle_in_foreign_port_code						-- Тип ТС в ин. порту (код) SD.000590
	,null as vehicle_type_in_foreign_port_code					-- Тип ТС в ин. порту SD.000591
	,null as pb1_number									    	-- Номер PB 1 SD.000592                 
	,null as pb2_number									    	-- Номер PB 2 SD.000593                  
	,null as pb3_number								         	-- Номер PB 3 SD.000594                 
	,null as pb1_warehouse_name								    -- Склад PB 1 SD.000595                 
	,null as pb2_warehouse_name								    -- Склад PB 2 SD.000596                 
	,null as pb3_warehouse_name								    -- Склад PB 3 SD.000597                 
	,'No' as realization_status_name		                    -- Статус Реализации SD.000599	
	,null as exporter_name										-- Экспортёр SD.000600
	,scm.country_of_end_user_name						    	-- Страна конечного потребителя SD.000601                           --ver 192
	,scm.buyer_plan_name    									-- Плановый покупатель SD.000602                                    --ver 192
	,scm.customer_for_scm_report_name 					        -- Клиент для отчета Металл в Цепочке Поставок SD.000603            --ver 192
	,null as material_group_for_scm_report_name			    	-- Группа материала для отчета Металл в Цепочке Поставок SD.000604
	,null as assignment_name		                            -- Поручение SD.000605 (forwarder_instruction_name у Лиды)
	,null as vessel_and_voyage_plan_search_name                 -- Судно / номер рейса (план) SD.000607
    ,null as vessel_and_voyage_actual_search_name               -- Судно / номер рейса (факт) SD.000608
	,null as forwarder_in_foreign_port_name				    	-- Экспедитор в иностранном порту SD.000609
	,null as dt_storage_payed_in_foreign_port_by_rusal			-- Дата окончания хранения на складе за счет RUSAL по Релизу SD.000611
	,null as shipment_instruction_in_foreign_port_name			-- Инструкция на отгрузку Ин Порт SD.000612
	,null as dt_shipment_instruction_in_foreign_port			-- Дата инструкции на отгрузку Ин Порт SD.000613
	,null as dt_shipment_instruction_date_from					-- SI: Дата с SD.000614
	,null as dt_shipment_instruction_date_to					-- SI: Дата по SD.000615
	,null as dt_barge_loading									-- Дата погрузки на баржу SD.000616
	,null as dt_barge_arrival									-- Дата доставки баржи SD.000617
	,null as shipment_instruction_in_second_foreign_port_name	-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,null as dt_shipment_instruction_in_second_foreign_port		-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,null as dt_invoice_provisional								-- Дата инвойса SD.000620
	,null as provisional_invoice_payment_status_code			-- Статус оплаты инвойса SD.000621
	,null as prepared_for_realization_status_name				-- Признак ППС (код) SD.000623
	,null as mh1_storage_document_number					    -- № Акта МХ-1 SD.000625
	,null as dt_mh1_storage_document							-- Дата Акта МХ-1 SD.000626
	,null as mh3_storage_document_number						-- № Акта МХ-3 SD.000627
	,null as dt_mh3_storage_document							-- Дата Акта МХ-3 SD.000628
	,null as dt_departure_from_foreigh_port						-- EXP: Load out date SD.000629
	,null as foreign_port_terminal_name                         -- EXP: Storage location SD.000630            
	,null as russian_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code SD.000632
	,null as foreign_port_bill_of_lading_forwarder_code		    -- EXP: WH Operator's code 2 SD.000633
	,null as uzbekistan_cargo_declaration_73					-- EXP: ГТД ИМ73 SD.000634
	,scm.business_location_sap_precalc_name as business_location_sap_precalc_name				    -- Статус в Supply chain (Business) SD.000636
	,null as ready_for_realization_status_name                  -- Статус готовности к реализации SD.000639
	,null as country_of_destination_port_code					-- Страна порта назначения (код) SD.000646
	,scm.sales_team_name							    		-- Сбытовая команда SD.000651                                       --ver 192
	,scm.delivery_region_code							    	-- Регион поставки по контракту (код) SD.000652                     --ver 192
	,null as receiving_plant_in_sap_system_name				    -- Завод собственник SD.000655
	,null as dt_shipment_instruction 							-- Дата инструкции ДСБ SD.000669 (dt_shipment_instruction_ds)   
	,null as shipment_instruction_name							-- Номер инструкции ДСБ SD.000670 (shipment_instruction_number_ds) 
	,scm.dt_quota_yyyymm							    		-- Квота в формате гггг.мм SD.000687                                --ver 192
	,null as storage_duration_in_calendar_days                  -- Сроки нахождения в локации SD.000688 
	,null as buyer_agent_name									-- Trading company SD.000704          
	,null as dt_realization										-- Дата реализации SD.000720
	,null as internal_compound_key_code 				    	-- Внутренний уникальный идентификатор записи SD.000721	
	,null as is_tolling_code                                    -- Признак толлинг SD.000749
    ,null as location_stay_duration_category_code               -- Сроки нахождения в локации (месяц) SD.000750
    ,scm.customer_for_scm_report_code as customer_for_reporting_code -- Код САП клиента для отчета Металл в Цепочке Поставок SD.000771   --ver 192
    ,'UNDEFINED'as warehouse_or_responsible_customer_for_storage_name    -- SD.000919 General storage location  
     ,null as customs_invoice_code								-- SD.000779 "Custom's invoice Group"
	,null as customs_invoice_number								-- SD.000780 "Custom's invoice Number"
	,null as dt_customs_invoice									-- SD.000781 "Custom's invoice Date" 
	,NULL AS dt_arrival_in_second_port_of_discharge_plan		-- Дата прибытия в порт выгрузки 2 план SD.000157 
	,NULL AS dt_acceptance_in_russian_port_planned              -- SD.000705 Плановая дата принятия в порту РФ  
	,to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm   -- SD.000893 "Месяц Дата отгрузки с завода" 
	--236
	,scm.material_group_name                                    -- SD.0000?? Группа материала название
    ,scm.buyer_plan_code                                        -- SD.000124 Плановый покупатель (код) 
    --272 доработка
	,null as dt_train_scheduled_arrival	 						--SD.000697 Плановая дата прибытия по ЖД (с фактом) 
	--274 доработка
	,null as dt_bill_of_lading_in_russian_port_created            --SD.001214 Дата загрузки Коносамента РФ в САП
	,null as dt_bill_of_lading_in_foreign_port_created            --SD.001215 Дата загрузки Коносамента ин. порта в САП
	,null as dt_bill_of_lading_in_russian_port_scan_copy_uploaded --SD.001216 Дата загрузки скан образа в САП для Коносамента РФ  
	,null as bill_of_lading_group_code_in_foreign_port            --SD.000047 Группа коносамента в ин.порту 
	,null as dt_bill_of_lading_in_foreign_port_scan_copy_uploaded  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	--295
	,scm.delivery_country_in_contract_code                     --SD.000577 Страна поставки по контракту (код) 
	--302
	,null as country_of_consignee_code                 --SD.001360 Код страны грузополучателя  
	--311
	,null as storage_duration_in_russian_port_in_calendar_days    --SD.001385 Количество дней хранения в порту РФ
	,null as storage_duration_in_russian_port_category_code      --SD.001386 Категория хранения в порту РФ 
	,null as dt_arrival_by_railway_planned						--SD.001395 Плановая дата прибытия по жд (нормативная)
	FROM dm_calc.finish_goods_warehouse_stock_plant_by_date scm
where /*scm.weight_net<>0 and*/ scm.dt_report>='2024-01-01';
