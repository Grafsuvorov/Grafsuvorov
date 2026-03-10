drop table if exists dm.sales_material_turnover_detailed cascade;
create table dm.sales_material_turnover_detailed (
	 delivery_number_initial varchar NULL /*SD.000001 | Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах*/
	,port_of_discharge_code varchar NULL /*SD.000044 | Порт выгрузки (код)*/
	,port_of_discharge_name varchar NULL /*SD.000045 | Порт выгрузки | Порт выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, BUSAN*/
	,bill_of_lading_in_foreign_port varchar NULL /*SD.000048 | Коносамент в ин.порту | Номер коносамента в ин. порту, номер на бумажном носителе. Документ, который используют в водных перевозках из иностранных портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения.*/
	,dt_storage_start /*lddat_p*/ date NULL /*SD.000418 | Дата начала хранения ин. склад*/
	,dt_storage_end /*lddat_r*/ date NULL /*SD.000419 | Дата окончания хранения ин. склад*/
	,warehouse_code /*sklad_porta*/ varchar NULL /*SD.000420 | Удаленный склад (код)*/
	,warehouse_name /*sklad_port*/ varchar NULL /*SD.000421 | Удаленный склад*/
	,country_of_remote_warehouse_name varchar NULL /*SD.000423 | Страна удаленного склада*/
	,sales_bundle_code /*id_him*/ varchar NULL /*SD.000511 | ID химии*/
	,dt_storage_end_in_release /*end_date_of_storage_in_the_warehouse*/ date NULL /*SD.000546 | Дата окончания хранения на складе за счет RUSAL*/
	,sales_delivery_code /*supply*/ varchar NULL /*SD.000548 | Поставка*/
	,receiving_plant_code /*receiving_plant*/ varchar NULL /*SD.000549 | Принимающий завод*/
	,forwarder_in_foreign_port_name varchar NULL /*SD.000609 | Экспедитор в иностранном порту*/
	,sales_bundle_gross_weight /*weight_sf*/ numeric(13, 3) NULL /*SD.000722 | Вес брутто пакета | Вес брутто металла для одного пакета, в тоннах*/
	,sales_bundle_net_weight /*weight_n*/ numeric(13, 3) NULL /*SD.000723 | Вес нетто пакета | Вес нетто металла для одного пакета, в тоннах*/
	,sales_bundle_net_weight_with_wirerod numeric(13, 3) NULL /*SD.000724 | Вес Н&К пакета | Вес нетто + катанка металла для одного пакета, в тоннах*/
	,country_of_remote_warehouse_code varchar NULL /*SD.000725 | Страна удаленного склада (код)*/
	,region_of_remote_warehouse_code varchar NULL /*SD.000726 | Регион удаленного склада (код) | Код региона удаленного склада*/
	,region_of_remote_warehouse_name varchar NULL /*SD.000727 | Регион удаленного склада | Регион удаленного склада*/
	,location_of_remote_warehouse_name varchar NULL /*SD.000728 | Локация удаленного склада | Наименование локации/города, где находится склад*/
	,batch_code varchar NULL /*SD.000737 | Партия | Номер партии металла (для детальной витрины)*/
	,uni varchar NULL /*SD.000151 | UNI | UNI*/												--2025.05.28 добавила
 	,metal_owner_for_reporting_name varchar NULL /*SD.000544 | Собственник | Собственник*/		--2025.05.28 добавила
 	,forwarder_name varchar NULL /*SD.000021 | Экспедитор | Экспедитор*/						--2025.05.28 добавила
 	,bill_of_lading_number varchar NULL /*SD.000041 | Номер коносамента | Номер коносамента*/	--2025.05.28 добавила
/*2025.07.23 новые поля из ОД*/
 	,pb1_number varchar NULL /*SD.000592 | Номер PB 1 | Внешняя идентификация 1-й накладной*/
	,pb2_number varchar NULL /*SD.000593 | Номер PB 2 | Внешняя идентификация 2-й накладной*/
	,pb3_number varchar NULL /*SD.000594 | Номер PB 3 | Внешняя идентификация 3-й накладной*/
	,pb1_warehouse_name varchar NULL /*SD.000595 | Склад PB 1 | Склад 1-й накладной*/
	,pb2_warehouse_name varchar NULL /*SD.000596 | Склад PB 2 | Склад 2-й накладной*/
	,pb3_warehouse_name varchar NULL /*SD.000597 | Склад PB 3 | Склад 3-й накладной*/
	,dt_pb1_number date NULL /*SD.000751 | Дата PB 1 | Дата создания 1-й внешней накладной (PB)*/
	,dt_pb2_number date NULL /*SD.000752 | Дата PB 2 | Дата создания 2-й внешней накладной (PB)*/
	,dt_pb3_number date NULL /*SD.000753 | Дата PB 3 | Дата создания 3-й внешней накладной (PB)*/
/*2025.08.13 новое поле*/
	,dt_shipment_from_foreign_warehouse date NULL /*SD.000547 | Дата ухода со склада*/ --2025.08.13 добавляю
	,delivery_code_le_p	varchar NULL																-- LE поставка прихода SD.000513				
    ,delivery_code_le_r	varchar NULL																-- LE поставка расхода SD.000516				
    ,barcode_ean_code varchar NULL																	-- Штриховой код SD.000929						
    ,fwrd_info_mh1_storage_document_number varchar NULL												-- EXP: № Акта МХ-1	SD.000930					
    ,fwrd_info_mh3_storage_document_number varchar NULL												-- EXP: № Акта МХ-3	SD.000931					
    ,dt_fwrd_info_discharge_in_foreign_port	date NULL												-- EXP: Дата выгрузки в порту SD.000932			
    ,dt_fwrd_info_storage_start_in_foreign_port	date NULL 											-- EXP: Начало хранения ин. склад 1 SD.000933
    ,dt_fwrd_info_storage_end_in_foreign_port date NULL												-- EXP: Окончание хранение ин. склад 1 SD.000934 
    ,fwrd_info_shipment_instruction_number varchar NULL												-- EXP: Инструкция на отгрузку Ин Порт SD.000935	
	,fwrd_info_shipment_instruction_code varchar NULL												-- EXP: Группа инструкции на отгрузку Ин Порт SD.000936 
	,fwrd_info_transport_bill_external_number varchar NULL											-- EXP: Номер накладной SD.000937 				
	,fwrd_info_delivery_notice_number varchar NULL													-- EXP: Номер нотиса о доставке	SD.000938		
	,fwrd_info_transport_vehicle_in_foreign_port_code varchar NULL									-- EXP: Номер ТС в ин. Порту SD.000939 			
	,fwrd_info_transport_capacity_amount varchar NULL												-- EXP: Грузоподъемность SD.000940
	,fwrd_info_second_foreign_warehouse_location_name varchar NULL									-- EXP: Storage location 2 SD.000941 				
	,dt_fwrd_info_storage_start_in_second_foreign_warehouse	date NULL								-- EXP: Начало хранения ин. склад 2 SD.000942
	,dt_fwrd_info_storage_end_in_second_foreign_warehouse date NULL									-- EXP: Окончание хранение ин. склад 2 SD.000943
	,fwrd_info_shipment_instruction_in_second_foreign_port_number varchar NULL						-- EXP: Инструкция на отгрузку Ин Порт 2 SD.000944 -- УДАЛИТЬ
	,fwrd_info_shipment_instruction_in_2nd_foreign_port_number varchar NULL							-- EXP: Инструкция на отгрузку Ин Порт 2 SD.000944
	,fwrd_info_shipment_instruction_in_second_foreign_port_code varchar NULL						-- EXP: Группа инструкции на отгрузку Ин Порт 2 SD.000945
	,fwrd_info_shipment_instruction_in_2nd_foreign_port_code varchar NULL							-- EXP: Группа инструкции на отгрузку Ин Порт 2 SD.000945  -- УДАЛИТЬ
	,pledge_contract_external_number varchar NULL													-- Номер контракта Pledge reserve SD.000946
	,final_pledge_in_bank_code varchar NULL															-- Банк Pledge reserve (код) SD.000947
	,final_pledge_in_bank_name varchar NULL															-- Название Банка Pledge reserve SD.000948											
	,scm_pledge_status_name	varchar	NULL															-- Признак ЦП SD.000949	
	,transportation_stage35_delivery_code varchar NULL												-- LE поставка Этап 35 SD.000953	  			
	,transportation_stage40_delivery_code varchar NULL												-- LE поставка Этап 40 SD.000954	  				
	,transportation_stage42_delivery_code varchar NULL												-- LE поставка Этап 42 SD.000955	  			
	,transportation_stage55_delivery_code varchar NULL												-- LE поставка Этап 55 SD.000956	  			
	,transportation_stage60_delivery_code varchar NULL												-- LE поставка Этап 60 SD.000957	  			
	,transportation_stage_final_delivery_code varchar NULL											-- LE поставка последней операции SD.000958     
	,sales_order_in_shipment varchar NULL															-- Заказ ЦК в отгрузке SD.000005
	,dt_final_release date NULL																		-- Дата Финальный релиз SD.000482
	,final_release_code varchar	NULL																-- Номер Финальный релиз SD.000588
	,dt_shipment_instruction_in_foreign_port date NULL												-- Дата инструкции на отгрузку Ин Порт SD.000613
	,dt_shipment_instruction_in_second_foreign_port	date NULL										-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,final_release_internal_code varchar NULL														-- Группа Финальный релиз SD.000952      
	,vehicle_in_transportation_delivery_code varchar NULL											-- Транспортное средство LE-поставки расхода SD.001042 
    ,forwarder_departure_transportation_stage_code /*transportation_stage_code*/ varchar NULL		-- Этап расхода (код) SD.001043 УДАЛИТЬ! 
	,transportation_stage_code varchar NULL															-- Этап перевозки SD.000529 УДАЛИТЬ! 
	,transportation_outbound_stage_code varchar NULL												-- Код этапа расхода SD.001043
	,transportation_inbound_stage_code varchar NULL													-- Код этапа прихода SD.000529 
	,dt_transportation_delivery_created	timestamp NULL												-- Дата создания LE-поставки расхода SD.001044 
	,delivery_basis varchar NULL																	-- Базис поставки SD.000067
	,delivery_point_name varchar NULL																-- Пункт доставки по инкотермс SD.000068 
	,pb_number varchar	NULL																		-- LotWshe/PB number SD.000158
	,russian_port_bill_of_lading_forwarder_code varchar	NULL										-- EXP: WH Operator's code SD.000632 -- НА УДАЛЕНИЕ ПОСЛЕ ЗАМЕНЫ В SS
	,forwarder_storing_in_foreign_1st_warehouse_code varchar NULL									-- EXP: WH Operator's code SD.000632
	,owner_plant_name varchar NULL																	-- Завод собственник SD.000655
	,forwarder_in_foreign_port_code	varchar NULL													-- Экспедитор в иностранном порту (код) SD.000950
	,bill_of_lading_created_by_name	varchar NULL													-- Создатель коносамента в ин. Порту SD.000951
	,railway_train_number varchar NULL	 															-- Номер поезда SD.000637 
	,shipment_instruction_in_foreign_port_name varchar NULL											-- Инструкция на отгрузку Ин Порт SD.000612
	,shipment_instruction_in_second_foreign_port_name varchar NULL									-- Инструкция на отгрузку Ин Порт 2 SD.000618 
	,dt_vehicle_loaded date NULL   																	-- EXP: Load out date SD.000629
	,location_comment varchar NULL																	-- EXP: Storage location SD.000630 
	,plant_producer_name varchar NULL																-- Завод SD.000007
	,plant_owner_code varchar NULL																	-- Завод собственник (код) SD.000099
	,sales_order varchar NULL																		-- Заказ ЦК SD.000123
	,dt_delivery_notice date NULL																	-- Дата нотиса о доставке SD.000132
	,delivery_notice_number	varchar	NULL															-- Номер нотиса о доставке SD.000133
	,pledge_in_bank_name varchar NULL																-- Pledge Bank SD.000172
	,material_shape_name_full varchar NULL															-- Форма SD.000180
	,incoterms_plan_code varchar NULL																-- Плановый базис поставки 1 SD.000255
	,uzbekistan_cargo_declaration_73 varchar NULL													-- EXP: ГТД ИМ73 SD.000634
	,port_of_loading_name varchar NULL																-- Порт погрузки SD.000653 
	,location_type_of_remote_warehouse_name	varchar NULL											-- Признак (Ин.склад/СВХ/Терминал/Порт РФ) SD.001218
	,transportation_delivery_to_foreign_1st_warehouse_code varchar NULL								-- LE поставка хранения SD.000241 
	,transportation_delivery_to_foreign_2nd_warehouse_code varchar NULL								-- LE поставка хранения 2 SD.001278
	,transportation_stage66_delivery_code varchar NULL												-- LE поставка Этап 66 SD.001273
	,transportation_stage77_delivery_code varchar NULL												-- LE поставка Этап 77 SD.001274
	,transportation_stage49_delivery_code varchar NULL												-- LE поставка Этап 49 SD.001275
	,forwarder_storing_in_foreign_2nd_warehouse_code varchar NULL									-- EXP: WH Operator's code 2 SD.000633
	,forwarder_delivering_to_foreign_1st_warehouse_code	varchar NULL								-- EXP: Inb.carrier's code SD.001276
	,forwarder_delivering_to_foreign_2nd_warehouse_code	varchar NULL								-- EXP: Inb.carrier's code 2 SD.001279
	,forwarder_delivering_to_foreign_1st_warehouse_name	varchar NULL								-- EXP: Inb.carrier SD.001277
	,forwarder_delivering_to_foreign_2nd_warehouse_name	varchar NULL								-- EXP: Inb.carrier 2 SD.001280
	,forwarder_storing_in_foreign_1st_warehouse_name varchar NULL									-- EXP: WH Operator's SD.001281
	,forwarder_storing_in_foreign_2nd_warehouse_name varchar NULL									-- EXP: WH Operator's 2 SD.001282
	,delivery_number_of_producer_plant varchar NULL													-- Номер поставки завода производителя SD.000003
	,tsw_location_name varchar NULL																	-- 
	,dt_arrival_by_railway date NULL																-- Дата прибытия по ЖД SD.000011
	,dt_forwarder date NULL																			-- Дата экспедитора SD.000012
	,dt_warehouse date NULL																			-- Дата склада SD.000024
	,transport_type_after_repackaging_code varchar NULL												-- Тип ПС после перетарки SD.000027
	,transport_railcar_type_code varchar NULL														-- Тип вагона (код) SD.000028
	,transport_railcar_type_name varchar NULL														-- Тип вагона SD.000029
	,dt_bill_of_lading date NULL																	-- Дата коносамента SD.000042
	,delivery_region_name varchar NULL																-- Регион поставки по контракту SD.000338
	,dt_shipment date NULL																			-- Дата отгрузки SD.000010
	,port_of_loading_code varchar NULL																-- Порт погрузки (код) SD.000649
 	--4 тех поля
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
	 --sales_bundle_code
	 warehouse_name /*sklad_port*/
	,dt_storage_start /*lddat_p*/
	,dt_storage_end /*lddat_r*/
);


COMMENT ON TABLE dm.sales_material_turnover_detailed IS 'Версии отчета по стокам: ин.порты/склады (детальная)';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_number_initial IS 'Исходная поставка | Исходная поставка | dm_calc.sd_sales_main_scm.delivery_number_initial';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.port_of_discharge_code IS 'Порт выгрузки (код) | Порт выгрузки (код) | dm_calc.sd_sales_main_scm.port_of_discharge_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.port_of_discharge_name IS 'Порт выгрузки | Порт выгрузки | dm_calc.sd_sales_main_scm.port_of_discharge_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.bill_of_lading_in_foreign_port IS 'Коносамент в ин.порту | Коносамент в ин.порту | dm_calc.sd_sales_main_scm.bill_of_lading_in_foreign_port';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_storage_start IS 'Дата начала хранения ин. склад | Дата начала хранения ин. склад | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_p';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_storage_end IS 'Дата окончания хранения ин. склад | Дата окончания хранения ин. склад | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_r';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.warehouse_code IS 'Удаленный склад (код) | Удаленный склад (код) | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.knote';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.warehouse_name IS 'Удаленный склад  | Удаленный склад  | dict_dds.transport_hub_texts.transport_hub_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.country_of_remote_warehouse_name IS 'Страна удаленного склада | Страна удаленного склада | dict_dds.country_texts.country_full_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_bundle_code IS 'ID химии | ID химии | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.sales_bundle_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_storage_end_in_release IS 'Дата окончания хранения на складе за счет RUSAL | Дата окончания хранения на складе за счет RUSAL | dds.release.dt_end_of_free_storage';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_delivery_code IS 'Поставка | Поставка | dm_calc.sales_bundle_and_sales_delivery_sdt0005.vbeln';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.receiving_plant_code IS 'Принимающий завод | Принимающий завод | ods.lips_ral.werks';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_in_foreign_port_name IS 'Экспедитор в иностранном порту | Экспедитор в иностранном порту | dm_calc.sales_delivery_actual_part_2.forwarder_in_foreign_port_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_bundle_gross_weight IS 'Вес брутто пакета | Вес брутто пакета | dds.sales_bundle.sales_bundle_gross_weight';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_bundle_net_weight IS 'Вес нетто пакета | Вес нетто пакета | dds.sales_bundle.sales_bundle_net_weight';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_bundle_net_weight_with_wirerod IS 'Вес Н&К пакета | Вес Н&К пакета | dds.sales_bundle.sales_bundle_net_weight_with_wirerod';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.country_of_remote_warehouse_code IS 'Страна удаленного склада (код) | Страна удаленного склада (код) | dict_dds.address.country_code.';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.region_of_remote_warehouse_code IS 'Регион удаленного склада (код) | Регион удаленного склада (код) | dict_dds.country.market_region1_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.region_of_remote_warehouse_name IS 'Регион удаленного склада | Регион удаленного склада | dict_dds.market_region1_texts.market_region1_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.location_of_remote_warehouse_name IS 'Локация удаленного склада | Локация удаленного склада | dict_dds.location_sales.location_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.batch_code IS 'Партия | Партия | dm_calc.sales_bundle_and_sales_delivery_sdt0005.charg';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.uni is 'UNI | UNI | dm_calc.sd_sales_main_scm.uni';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.metal_owner_for_reporting_name is 'Собственник | Собственник | ods.lips_ral.werks';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_name is 'Экспедитор | Экспедитор | dm_calc.sd_sales_main_scm.forwarder_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.bill_of_lading_number is 'Номер коносамента | Номер коносамента | dm_calc.sd_sales_main_scm.bill_of_lading_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb1_number is 'Номер PB 1 | Внешняя идентификация 1-й накладной | dm_calc.sd_sales_main_scm.pb1_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb2_number is 'Номер PB 2 | Внешняя идентификация 2-й накладной | dm_calc.sd_sales_main_scm.pb2_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb3_number is 'Номер PB 3 | Внешняя идентификация 3-й накладной | dm_calc.sd_sales_main_scm.pb3_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb1_warehouse_name is 'Склад PB 1 | Склад 1-й накладной | dm_calc.sd_sales_main_scm.pb1_warehouse_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb2_warehouse_name is 'Склад PB 2 | Склад 2-й накладной | dm_calc.sd_sales_main_scm.pb2_warehouse_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb3_warehouse_name is 'Склад PB 3 | Склад 3-й накладной | dm_calc.sd_sales_main_scm.pb3_warehouse_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_pb1_number is 'Дата PB 1 | Дата создания 1-й внешней накладной (PB) | dm_calc.sd_sales_main_scm.dt_pb1_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_pb2_number is 'Дата PB 2 | Дата создания 2-й внешней накладной (PB) | dm_calc.sd_sales_main_scm.dt_pb2_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_pb3_number is 'Дата PB 3 | Дата создания 3-й внешней накладной (PB) | dm_calc.sd_sales_main_scm.dt_pb3_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_shipment_from_foreign_warehouse is 'Дата ухода со склада | Дата ухода со склада | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_p, dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_r, dds.release.dt_end_of_free_storage';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_code_le_p is 'LE поставка прихода | Техническая поставка транспортировки этапа прибытия ГП на склад | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.delivery_code_le_p';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_code_le_r is 'LE поставка расхода | Техническая поставка транспортировки этапа убытия ГП со склада | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.delivery_code_le_r';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.barcode_ean_code is 'Штриховой код | Номер штрихового кода на упаковке готовой продукции | dds.sales_bundle.barcode_ean_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_mh1_storage_document_number is 'EXP: № Акта МХ-1 | Номер акта поступления готовой продукции на склад СВХ | ods.ztsd5018m_uz_b_ral.num_mh1, dds.delivery_document_header.mh1_storage_document_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_mh3_storage_document_number is 'EXP: № Акта МХ-3 | Номер акта списания готовой продукции со склада СВХ | ods.ztsd5018m_uz_b_ral.num_mh3, dds.delivery_document_header.mh3_storage_document_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_fwrd_info_discharge_in_foreign_port is 'EXP: Дата выгрузки в порту | Дата выгрузки судна в иностранном порту, по коносаменту из РФ | ods.ztsd5018m_eu_b_ral.ship_unload_date, dds.bill_of_lading.dt_discharge';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_fwrd_info_storage_start_in_foreign_port is 'EXP: Начало хранения ин. склад 1 | Дата начала хранения металла на удаленном складе, после поступления груза в ин. порт из РФ | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_p';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_fwrd_info_storage_end_in_foreign_port is 'EXP: Окончание хранение ин. склад 1 | Дата окончания хранения металла на удаленном складе, после поступления груза в ин. порт из РФ  | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_r';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_shipment_instruction_number is 'EXP: Инструкция на отгрузку Ин Порт | Бумажный номер инструкции на отгрузку Ин Порт | ods.ztsd5018m_eu_b_ral.notification, ods.ztsd5018m_uz_b_ral.notification,  dds.shipment_instruction.shipment_instruction_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_shipment_instruction_code is 'EXP: Группа инструкции на отгрузку Ин Порт | Технический номер инструкции на отгрузку Ин Порт | ods.ztsd5018m_uz_b_ral.sammg_n, ods.ztsd5018m_eu_b_ral.sammg_n, dds.shipment_instruction.shipment_instruction_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_transport_bill_external_number is 'EXP: Номер накладной | Бумажный номер накладной | dds.delivery_document_header.transport_bill_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_delivery_notice_number is 'EXP: Номер нотиса о доставке | Номер документа (на бумажном носителе), который создает ДСБ (дирекция по сбыту) для базисов поставки  DDP или DAP для отражения даты доставки клиенту | ods.ztsd5018m_eu_b_ral.dlv_note';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_transport_vehicle_in_foreign_port_code is 'EXP: Номер ТС в ин. Порту | Номер транспортного средства в ин. порту | ods.ztsd5018m_eu_b_ral.container_out, ods.ztsd5018m_uz_b_ral.traid_out, dds.delivery_document_header.vehicle_in_foreign_port_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_transport_capacity_amount is 'EXP: Грузоподъемность | Грузоподъемность вагона/ контейнера, указывается в тексте заголовка поставки завода производителя | ods.ztsd5018m_eu_b_ral.capacity, ods.ztsd5018m_outb_b_ral.capacity';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_second_foreign_warehouse_location_name is 'EXP: Storage location 2 | Город склада хранения для (после поступления груза из одного ин. порта в другой ин. порт) | ods.ztsd5018m_eu_b_ral.loc_name, ods.ztsd5018m_uz_b_ral.location_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_fwrd_info_storage_start_in_second_foreign_warehouse is 'EXP: Начало хранения ин. склад 2 | Дата начала хранения металла на удаленном складе, после поступления груза из одного ин. порта в другой ин. порт | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_p';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_fwrd_info_storage_end_in_second_foreign_warehouse is 'EXP: Окончание хранения ин. склад 2 | Дата окончания хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. Порт | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_r';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_shipment_instruction_in_second_foreign_port_number is 'УДАЛИТЬ';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_shipment_instruction_in_2nd_foreign_port_number is 'EXP: Инструкция на отгрузку Ин Порт 2 | Инструкция на отгрузку в ин. порту (после поступления груза из одного ин. порта в другой ин. порт) | ods.ztsd5018m_eu_b_ral.notification, ods.ztsd5018m_outb_b_ral.notification, dds.shipment_instruction.shipment_instruction_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_shipment_instruction_in_second_foreign_port_code is 'УДАЛИТЬ';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.fwrd_info_shipment_instruction_in_2nd_foreign_port_code is 'EXP: Группа инструкции на отгрузку Ин Порт 2 | Системный номер группы инструкции на отгрузку в ин. порту (после поступления груза из одного ин. порта в другой ин. порт) | ods.ztsd5018m_eu_b_ral.sammg_n, ods.ztsd5018m_outb_b_ral.sammg_n, dds.shipment_instruction.shipment_instruction_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pledge_contract_external_number is 'Номер контракта Pledge reserve | Бумажный номер контракта по залоговому резерву | dds.sales_contract_header.sales_order_external_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.final_pledge_in_bank_code is 'Банк Pledge reserve (код) | Системный код банка по залоговому резерву | ods.vbsk_ral.zzkunag';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.final_pledge_in_bank_name is 'Название Банка Pledge reserve | Наименование банка по залоговому резерву | dict_dds.counterparty.counterparty_full_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.scm_pledge_status_name is 'Признак ЦП | Признак цепочки поставок | dict_dds.scm_pledge_status_texts.scm_pledge_status_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage35_delivery_code is 'LE поставка Этап 35 | Номер LE поставки этапа разгрузки в иностранном порту | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage40_delivery_code is 'LE поставка Этап 40 | Номер LE поставки этапа перемещения с терминала ин.порта на удаленный склад | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage42_delivery_code is 'LE поставка Этап 42 | Номер LE поставки этапа архивного деления по РВ | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage55_delivery_code is 'LE поставка Этап 55 | Номер LE поставки этапа отгрузки с терминала/уд.склада ин.порта | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage60_delivery_code is 'LE поставка Этап 60 | Номер LE поставки этапа погрузки на судно в ин.порту | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage_final_delivery_code is 'LE поставка последней операции | Номер LE поставки, последней в логистической цепочки операции  | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.delivery_code_le_p';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_order_in_shipment is 'Заказ ЦК в отгрузке | Заказ ЦК в отгрузке  | dm_calc.sd_sales_main_scm.sales_order_in_shipment';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_final_release is 'Дата Финальный релиз| Отображает дату созданого финального релиза | dm_calc.sd_sales_main_scm.dt_final_release';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.final_release_code is 'Номер Финальный релиз | Номер Финальный релиз | dm_calc.sd_sales_main_scm.final_release_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_shipment_instruction_in_foreign_port is 'Дата инструкции на отгрузку Ин Порт | Дата инструкции на отгрузку Ин Порт | dm_calc.sd_sales_main_scm.dt_shipment_instruction_in_foreign_port';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_shipment_instruction_in_second_foreign_port is 'Дата инструкции на отгрузку Ин Порт 2 | Дата инструкции на отгрузку Ин Порт 2 | dm_calc.sd_sales_main_scm.dt_shipment_instruction_in_second_foreign_port';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.final_release_internal_code is 'Группа Финальный релиз | Группа Финальный релиз | dm_calc.sd_sales_main_scm.final_release_internal_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.vehicle_in_transportation_delivery_code is 'Транспортное средство LE-поставки расхода | Транспортное средство LE-поставки расхода | dds.delivery_document_header.vehicle_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_departure_transportation_stage_code is 'УДАЛИТЬ!';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage_code is 'УДАЛИТЬ!';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_outbound_stage_code is 'Код этапа расхода | Код этапа расхода | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.transportation_outbound_stage_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_inbound_stage_code is 'Код этапа прихода | Код этапа прихода | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.transportation_inbound_stage_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_transportation_delivery_created is 'Дата создания LE-поставки расхода | Дата создания LE-поставки расхода | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_created_r';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_basis is 'Базис поставки | Базис поставки | dm_calc.sd_sales_main_scm.delivery_basis';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс | dm_calc.sd_sales_main_scm.delivery_point_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pb_number is 'LotWshe/PB number | LotWshe/PB number | dm_calc.sd_sales_main_scm.pb_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_storing_in_foreign_1st_warehouse_code is 'EXP: WH Operators code | Системный код экспедитора, осуществляющего хранение ГП на 1-м складе | dds.sales_document_counterparty_role.supplier_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.owner_plant_name is 'Завод собственник | Завод собственник | dm_calc.sd_sales_main_scm.receiving_plant_in_sap_system_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_in_foreign_port_code is 'Экспедитор в иностранном порту (код) | Экспедитор в иностранном порту (код) | dm_calc.sd_sales_main_scm.forwarder_in_foreign_port_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.bill_of_lading_created_by_name is 'Создатель коносамента в ин. Порту | Создатель коносамента в ин. Порту | dm_calc.sd_sales_main_scm.bill_of_lading_created_by_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.railway_train_number is 'Номер поезда | Номер поезда | dm_calc.sd_sales_main_scm.bill_of_lading_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.shipment_instruction_in_foreign_port_name is 'Инструкция на отгрузку Ин Порт | Инструкция на отгрузку Ин Порт | dds.shipment_instruction.shipment_instruction_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.shipment_instruction_in_second_foreign_port_name is 'Инструкция на отгрузку Ин Порт 2 | Инструкция на отгрузку Ин Порт 2 | dds.shipment_instruction.shipment_instruction_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_vehicle_loaded is 'EXP: Load out date | EXP: Load out date | dds.delivery_document_header.dt_vehicle_loaded';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.location_comment is 'EXP: Storage location | EXP: Storage location | dds.delivery_document_header.location_comment';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.plant_producer_name is 'Завод | Завод | dm_calc.sd_sales_main_scm.plant_producer_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.plant_owner_code is 'Завод собственник (код) | Завод собственник (код) | dm_calc.sd_sales_main_scm.plant_owner_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.sales_order is 'Заказ ЦК | Заказ ЦК | dm_calc.sd_sales_main_scm.sales_order';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_delivery_notice is 'Дата нотиса о доставке | Дата нотиса о доставке | dm_calc.sd_sales_main_scm.dt_delivery_notice';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_notice_number is 'Номер нотиса о доставке | Номер нотиса о доставке | dm_calc.sd_sales_main_scm.delivery_notice_number';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.pledge_in_bank_name is 'Pledge Bank | Pledge Bank | dm_calc.sd_sales_main_scm.pledge_in_bank_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.material_shape_name_full is 'Форма | Форма | dm_calc.sd_sales_main_scm.material_shape_name_full';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.incoterms_plan_code is 'Плановый базис поставки 1 | Плановый базис поставки 1 | dm_calc.sd_sales_main_scm.incoterms_plan_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.uzbekistan_cargo_declaration_73 is 'EXP: ГТД ИМ73 | EXP: ГТД ИМ73 | dm_calc.sd_sales_main_scm.uzbekistan_cargo_declaration_73';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.port_of_loading_name is 'Порт погрузки | Порт погрузки | dm_calc.sd_sales_main_scm.port_of_loading_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.location_type_of_remote_warehouse_name is 'Признак (Ин.склад/СВХ/Терминал/Порт РФ) | Отображает признак принадлежности узла удаленного склада к иностранному складу, СВХ, терминалу или порту РФ | dict_dds.foreign_warehouse_priority_definition';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_delivery_to_foreign_1st_warehouse_code is 'LE поставка хранения | Номер поставки LE поставка этапа прихода на 1-й склад хранения ГП | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_delivery_to_foreign_2nd_warehouse_code is 'LE поставка хранения 2 | Номер поставки LE поставка этапа прихода на 2-й склад хранения ГП | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage66_delivery_code is 'LE поставка Этап 66 | Номер LE поставки этапа возврата от покупателя | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage77_delivery_code is 'LE поставка Этап 77 | Номер LE поставки этапа закупки у 3-х лиц | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transportation_stage49_delivery_code is 'LE поставка Этап 49 | Номер LE поставки этапа разгрузка с ЖД станции ин.гос-ва на ЖД терминал/уд.склад ин.гос-ва | dds.delivery_document_header.delivery_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_storing_in_foreign_2nd_warehouse_code is 'EXP: WH Operators code 2 | Системный код экспедитора, осуществляющего хранение ГП на 2-м складе | dds.sales_document_counterparty_role.supplier_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_delivering_to_foreign_1st_warehouse_code is 'EXP: Inb.carriers code | Системный код экспедитора, осуществляющего доставку ГП до 1-го склада | dds.sales_document_counterparty_role.supplier_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_delivering_to_foreign_2nd_warehouse_code is 'EXP: Inb.carriers code 2 | Системный код экспедитора, осуществляющего доставку ГП до 2-го склада | dds.sales_document_counterparty_role.supplier_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_delivering_to_foreign_1st_warehouse_name is 'EXP: Inb.carrier | Наименование экспедитора, осуществляющего доставку ГП до 1-го склада | dict_dds.counterparty.counterparty_short_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_delivering_to_foreign_2nd_warehouse_name is 'EXP: Inb.carrier 2 | Наименование экспедитора, осуществляющего доставку ГП до 2-го склада | dict_dds.counterparty.counterparty_short_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_storing_in_foreign_1st_warehouse_name is 'EXP: WH Operators | Наименование экспедитора, осуществляющего хранение ГП на 1-м складе | dict_dds.counterparty.counterparty_short_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.forwarder_storing_in_foreign_2nd_warehouse_name is 'EXP: WH Operators 2 | Наименование экспедитора, осуществляющего хранение ГП на 2-м складе | dict_dds.counterparty.counterparty_short_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_number_of_producer_plant is 'Номер поставки завода производителя | Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе | dm_calc.sd_sales_main_scm.delivery_number_of_producer_plant';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.tsw_location_name is 'Направление | Название порта погрузки | dm_calc.sd_sales_main_scm.tsw_location_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_arrival_by_railway is 'Дата прибытия по ЖД | Дата прибытия вагона по железной дороге на конечную станцию | dm_calc.sd_sales_main_scm.dt_arrival_by_railway';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_forwarder is 'Дата экспедитора | Дата, когда экспедитор принял груз на склад, и подготовил документы для экспорта - готовность к вывозу | dm_calc.sd_sales_main_scm.dt_forwarder';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_warehouse is 'Дата склада | Дата прибытия на склад порта, когда экспедитор принял груз на склад | dm_calc.sd_sales_main_scm.dt_warehouse';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transport_type_after_repackaging_code is 'Тип ПС после перетарки | Тип транспортного средства после перегрузки металла на другое транспортное средство | dm_calc.sd_sales_main_scm.transport_type_after_repackaging_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transport_railcar_type_code is 'Тип вагона (код) | Код типа вагона на текущий момент | dm_calc.sd_sales_main_scm.transport_railcar_type_code';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.transport_railcar_type_name is 'Тип вагона | Название типа вагона на текущий момент | dm_calc.sd_sales_main_scm.transport_railcar_type_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_bill_of_lading is 'Дата коносамента | Дата коносамента из РФ. Документ, который используют в водных перевозках из российских портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения | dm_calc.sd_sales_main_scm.dt_bill_of_lading';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.delivery_region_name is 'Регион поставки по контракту | - | dm_calc.sd_sales_main_scm.delivery_region_name';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sd_sales_main_scm.dt_shipment';
COMMENT ON COLUMN dm.sales_material_turnover_detailed.port_of_loading_code is 'Порт погрузки (код) | Порт погрузки (код) | dm_calc.sd_sales_main_scm.port_of_loading_code';
