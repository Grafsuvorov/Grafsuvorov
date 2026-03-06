DROP TABLE IF EXISTS dm.sales_alverse_mlc CASCADE;

CREATE TABLE dm.sales_alverse_mlc (
	batch varchar(10) NULL,												-- SD.000004 "Партия" 
	sales_order_in_shipment varchar(30) NULL,							-- SD.000005 "Заказ ЦК в отгрузке" 
	plant_producer_code varchar(4) NULL,								-- SD.000006 "Завод производитель (код)" 
	plant_producer_name varchar(30) NULL,								-- SD.000007 "Завод" 
	port_of_loading_name varchar(60) NULL,								-- SD.000009 "Направление" 
	dt_shipment date NULL,												-- SD.000010 "Дата отгрузки" 
	dt_arrival_by_railway date NULL,									-- SD.000011 "Дата прибытия по ЖД" 
	dt_forwarder date NULL,												-- SD.000012 "Дата экспедитора" 
	material_aggr_name varchar(70) NULL,								-- SD.000016 "Материал" 
	material_group_code varchar(9) NULL,								-- SD.000017 "Группа материалов" 
	forwarder_name varchar(100) NULL,									-- SD.000021 "Экспедитор" 
	dt_warehouse date NULL,												-- SD.000024 "Дата склада" 
	transport_railcar_type_name varchar(40) NULL,						-- SD.000029 "Тип вагона" 
	weight_gross numeric(13, 3) NULL,									-- SD.000031 "Вес брутто" 
	weight_net numeric(13, 3) NULL,										-- SD.000032 "Вес нетто" 
	weight_net_with_wirerod numeric(13, 3) NULL,						-- SD.000033 "Вес Н&K" 
	customer_name varchar(150) NULL,									-- SD.000037 "Покупатель" 
	contract_name varchar(35) NULL, 									-- SD.000038 "Контракт" 
	dt_bill_of_lading date NULL,										-- SD.000042 "Дата коносамента" 
	dt_bill_of_lading_in_foreign_port date NULL,						-- SD.000049 "Дата коносамента в ин.порту" 
	dt_sailed_loading_port date NULL,									-- SD.000058 "Дата отплытия из порта погрузки" 
	dt_arrival_in_port_of_discharge date NULL,							-- SD.000059 "Дата прибытия в порт выгрузки" 
	dt_arrival_in_second_port_of_discharge date NULL,					-- SD.000060 "Дата прибытия в порт выгрузки 2" 
	delivery_basis varchar(3) NULL,										-- SD.000067 "Базис поставки" 
	delivery_point_name varchar(28) NULL,								-- SD.000068 "Пункт доставки по инкотермс" 
	dt_stamp_railway_bill date NULL,									-- SD.000071 "Дата штемпеля по ЖДН" 
	dt_plant_arrival date NULL,											-- SD.000072 "Дата прихода на завод" 
	dt_import_export_transfer date NULL,								-- SD.000073 "Дата перехода из импорта в экспорт" 
	contract_export_number varchar(35) NULL,							-- SD.000078 "Внешнеторговый контракт завода" 
	dimensions_unit varchar(20) NULL,									-- SD.000079 "Размер единицы готовой продукции" 
	consignee_name varchar(120) NULL,									-- SD.000081 "Грузополучатель" 
	dt_customs_declaration date NULL,									-- SD.000088 "Дата ГТД"
	material_specification_name varchar(50) NULL,						-- SD.000089 "Спецификация" 
	weight_strip numeric(15, 3) NULL,									-- SD.000090 "Вес ленты" 
	dt_quarantine_certificate date NULL,								-- SD.000095 "Дата карантинного сертификата" 
	dt_first_entry_appeared date NULL,									-- SD.000103 "Дата первого появления записи в системе" 
	dt_collection date NULL,											-- SD.000112 "Дата комплектования" 
	destination_station_in_shipment_name varchar(40) NULL,				-- SD.000113 "Станция назначения в отгрузке" 
	dt_shipment_plan date NULL,											-- SD.000121 "Плановая дата отгрузки" 
	sales_order varchar(6) NULL,										-- SD.000123 "Заказ ЦК" 
	dt_discharge_in_foreign_port date NULL,								-- SD.000128 "Дата выгрузки в порту" 
	dt_discharge_in_second_foreign_port	date NULL,						-- SD.000129 "Дата выгрузки в порту 2" 	
	dt_arrival_in_port_of_discharge_plan date NULL,						-- SD.000130 "Дата прибытия в порт выгрузки план" 
	dt_delivery_notice date NULL,										-- SD.000132 "Дата нотиса о доставке" 
	material_code varchar(18) NULL,										-- SD.000143 "Номер материала" 
	grade_name varchar(30) NULL,										-- SD.000145 "Марка по спецификации" 
	dt_sales_order_delivery_actual date NULL,							-- SD.000146 "Фактическая дата получения заказа клиента" 
	dt_delivery_deadline date NULL,										-- SD.000149 "Deadline доставки" 
	shipment_period_preferred varchar(30) NULL,							-- SD.000150 "Желаемый период отгрузки" 
	uni varchar(60) NULL,												-- SD.000151 "UNI" 
	dt_arrival_in_second_port_of_discharge_plan date NULL,				-- SD.000157 "Дата прибытия в порт выгрузки 2 план" 
	dt_expected_delivery timestamp NULL,								-- SD.000162 "Ожидаемая дата доставки до клиента" 
	end_user_name	varchar(140) NULL,									-- SD.000164 "Конечный потребитель" 
	quantity_shipped numeric(13, 3) NULL,								-- SD.000165 "Отгруженное количество" 
	quantity_ordered numeric(15, 3) NULL,								-- SD.000166 "Запланированное количество" 
	invoice_provisional_number varchar(30) NULL,						-- SD.000167 "Инвойс (счет клиенту)" 
	invoice_final_number varchar(30) NULL,								-- SD.000170 "Финальный счет" 
	dt_pledge_in date NULL,												-- SD.000173 "Дата pledge in" 
	production_order varchar(30) NULL,									-- SD.000174 "Производственный заказ" 
	dt_storage_start_in_foreign_port date NULL,							-- SD.000175 "Дата начала хранения ин. склад" 
	dt_storage_end_in_foreign_port date NULL,							-- SD.000176 "Окончание хранения в ин. порту" 
	dt_storage_start_in_second_foreign_warehouse date NULL,				-- SD.000177 "Начало хранения склад 2" 
	dt_storage_end_in_second_foreign_warehouse date NULL,				-- SD.000178 "Окончание хранение склад 2" 
	material_shape_name_full varchar(90) NULL,							-- SD.000180 "Форма"
	material_name varchar(120) null,									-- SD.000200 "Наименование материала"	
	dt_realization_forecast date NULL, 									-- SD.000243 "Расчетная дата реализации" 
	realization_reason_document varchar(10) NULL, 						-- SD.000245 "Основание реализации" 
	frame_contract_code varchar(54) NULL,								-- SD.000246 "Рамочный контракт (код)" 
	dt_expected_bill_of_lading date NULL,								-- SD.000253 "Ожидаемая дата коносамента" 
	dt_release_material date NULL,										-- SD.000259 "Дата ОМ" 
	dt_etd date NULL,													-- SD.000261 "ETD Дата букинга" 
	delivery_region_name varchar(20) NULL,								-- SD.000338 "Регион поставки по контракту" 
	dt_prepared_for_realization date NULL,								-- SD.000344 "Дата готовности к реализации" 
	dt_ownership_transfer date NULL,									-- SD.000375 "Дата перехода права собственности" 
	dt_final_release date NULL,											-- SD.000482 "Дата Финальный релиз" 
	railway_movement_status_name varchar(10) NULL,						-- SD.000491 "Статус движения по ЖД" 
	business_location_name varchar(50) NULL,							-- SD.000492 "Статус в Supply chain (Business)" 
	total_commitment_weight numeric(15, 3) NULL,						-- SD.000579 "Объем обязательств итого" 
	dt_warehouse_confirmation date NULL,								-- SD.000583 "Дата Storage confirmation" 
	dt_notice date NULL,												-- SD.000587 "Дата нотиса" 
	final_release_code varchar(30) NULL,								-- SD.000588 "Номер Финальный релиз" 
	dt_final_invoice_payment date NULL,									-- SD.000589 "Дата оплаты Final Invoice" 
	country_of_end_user_name varchar(15) NULL,							-- SD.000601 "Страна конечного потребителя" 
	dt_assignment date NULL,											-- SD.000606 "Дата поручения"
	vessel_and_voyage_plan_search_name varchar(61) NULL,				-- SD.000607 "Судно / номер рейса (план)"	
	vessel_and_voyage_actual_search_name varchar(61) NULL,				-- SD.000608 'Судно / номер рейса (факт)"	
	dt_storage_payed_in_foreign_port_by_rusal date NULL,				-- SD.000611 "Дата окончания хранения на складе за счет RUSAL по Релизу" 
	dt_shipment_instruction_in_foreign_port	date NULL,					-- SD.000613 "Дата инструкции на отгрузку Ин Порт" 
	dt_shipment_instruction_date_from date NULL,						-- SD.000614 "SI: Дата с" 
	dt_shipment_instruction_date_to	date NULL,							-- SD.000615 "SI: Дата по" 
	dt_barge_loading date NULL,											-- SD.000616 "Дата погрузки на баржу" 
	dt_barge_arrival date NULL,											-- SD.000617 "Дата доставки баржи" 
	dt_shipment_instruction_in_second_foreign_port date NULL,			-- SD.000619 "Дата инструкции на отгрузку Ин Порт 2" 
	dt_invoice_provisional date NULL,									-- SD.000620 "Дата инвойса" 
	dt_mh1_storage_document date NULL,									-- SD.000626 "Дата Акта МХ-1" 
	dt_mh3_storage_document date NULL,									-- SD.000628 "Дата Акта МХ-3" 
	dt_departure_from_foreigh_port date NULL,							-- SD.000629 "EXP: Load out date" 
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
WITH (
	appendonly = TRUE,
 	orientation = COLUMN,
 	compresstype = zstd,
 	compresslevel = 3
)
DISTRIBUTED BY (
	batch
);

COMMENT ON TABLE dm.sales_alverse_mlc IS 'MLC (Alverse)';
-- SD.000004
COMMENT ON COLUMN dm.sales_alverse_mlc.batch is 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков. | dm_calc.sd_sales_main_scm.batch';
-- SD.000005
COMMENT ON COLUMN dm.sales_alverse_mlc.sales_order_in_shipment is 'Заказ ЦК в отгрузке | ЦК - центральная компания.
№ заказа центральной компании (заявки) под план производства. 
Источник поступления данных транзакция ZSD2925M - Загрузка данных об отгрузке на трейдерах. 
Изначально заказы ЦК вносятся в тразакции ZSD2882M - Регистрация заявок клиентов. 
Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК | dm_calc.sd_sales_main_scm.sales_order_in_shipment';
-- SD.000006
COMMENT ON COLUMN dm.sales_alverse_mlc.plant_producer_code is 'Завод производитель (код) | Код завода производителя | dm_calc.sd_sales_main_scm.plant_producer_code';
-- SD.000007
COMMENT ON COLUMN dm.sales_alverse_mlc.plant_producer_name is 'Завод | Название завода производителя | dm_calc.sd_sales_main_scm.plant_producer_name';
-- SD.000009
COMMENT ON COLUMN dm.sales_alverse_mlc.port_of_loading_name is 'Направление | МР - место размещения. Название порта погрузки. Например, ZARUBINO | dm_calc.sd_sales_main_scm.port_of_loading_name';
-- SD.000010
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sd_sales_main_scm.dt_shipment';
-- SD.000011
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_arrival_by_railway is 'Дата прибытия по ЖД | ЖД - железная дорога, RW - railway. Дата прибытия вагона по железной дороге на конечную станцию | dm_calc.sd_sales_main_scm.dt_arrival_by_railway';
-- SD.000012
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_forwarder is 'Дата экспедитора | Дата, когда экспедитор принял груз на склад, и подготовил документы для экспорта - готовность к вывозу | dm_calc.sd_sales_main_scm.dt_forwarder';
-- SD.000016
COMMENT ON COLUMN dm.sales_alverse_mlc.material_aggr_name is 'Материал | Код признака «Материал». Применяется для готовой алюминиевой продукции. 
Например, для кода материала APT0006ING0045, код признака Материл = COMMODITY | dm_calc.sd_sales_main_scm.material_aggr_name';
-- SD.000017
COMMENT ON COLUMN dm.sales_alverse_mlc.material_group_code is 'Группа материалов | Группа материалов. Например, для кода материала APT0006ING0045, код Группа материалов = A02-Алюминий первичный АТЧ, раскисленный. | dm_calc.sd_sales_main_scm.material_group_code';
-- SD.000021
COMMENT ON COLUMN dm.sales_alverse_mlc.forwarder_name is 'Экспедитор | Название экспедитора, который примет груз, после его прибытия с завода в конечную точку по жд или авто, 
и который подготовит документы для экспорта. | dm_calc.sd_sales_main_scm.forwarder_name';
-- SD.000024
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_warehouse is 'Дата склада | WH - warehouse. Дата прибытия на склад порта, когда экспедитор принял груз на склад | dm_calc.sd_sales_main_scm.dt_warehouse';
-- SD.000029
COMMENT ON COLUMN dm.sales_alverse_mlc.transport_railcar_type_name is 'Тип вагона | Название типа вагона на текущий момент. 
Заполняется по следующему алгоритму: = «Тип ПС после перетарки», если значение не пустое. Иначе = Тип вагона на заводе | dm_calc.sd_sales_main_scm.transport_railcar_type_name';
-- SD.000031
COMMENT ON COLUMN dm.sales_alverse_mlc.weight_gross is 'Вес брутто | Вес брутто | dm_calc.sd_sales_main_scm.weight_gross';
-- SD.000032
COMMENT ON COLUMN dm.sales_alverse_mlc.weight_net is 'Вес нетто | Вес нетто | dm_calc.sd_sales_main_scm.weight_net';
-- SD.000033
COMMENT ON COLUMN dm.sales_alverse_mlc.weight_net_with_wirerod is 'Вес Н&K | Н&К (N&K) - нетто и катанка. Вес нетто + катанки | dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
-- SD.000037
COMMENT ON COLUMN dm.sales_alverse_mlc.customer_name is 'Покупатель | Название покупателя из клиентского лота, если его нет, то Плановый покупатель из заявки под план производства. | dm_calc.sd_sales_main_scm.customer_name';
-- SD.000038
COMMENT ON COLUMN dm.sales_alverse_mlc.contract_name is 'Контракт | Номер контракта из клиентского лота, если его нет, то Плановый контракт из заявки под план производства. | dm_calc.sd_sales_main_scm.contract_name';
-- SD.000042
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_bill_of_lading is 'Дата коносамента | Дата коносамента из РФ. Документ, который используют в водных перевозках из российских портов. 
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sd_sales_main_scm.dt_bill_of_lading';
-- SD.000049
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_bill_of_lading_in_foreign_port is 'Дата коносамента в ин.порту | Дата коносамента в ин. порту, документ, который используют в водных перевозках из иностранных портов. 
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sd_sales_main_scm.dt_bill_of_lading_in_foreign_port';
-- SD.000058
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_sailed_loading_port is 'Sailed L.Port | Дата отплытия из порта погрузки. Если дата заполнена в номинации, то берем ее, иначе берем «Дата коносамента».
Источники заполнения даты в номинации следующее:
1) Ввод инфо руками в транзакции ZCARGO_ORDERS- Заявки на вывоз из портов РФ;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder | dm_calc.sd_sales_main_scm.dt_sailed_loading_port';
-- SD.000059
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_arrival_in_port_of_discharge is 'Дата прибытия в порт выгрузки | POD - port of discharge. 
Дата прибытия в порт выгрузки из коносамента. Дата из Коносамента, поля Arrived D.Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder | dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge';
-- SD.000060
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_arrival_in_second_port_of_discharge is 'Дата прибытия в порт выгрузки 2 | Дата прибытия в порт выгрузки из коносамента в ин. порту. 
Дата из Коносамента в ин. порту, поля Arrived D.Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder. | dm_calc.sd_sales_main_scm.dt_arrival_in_second_port_of_discharge';
-- SD.000067
COMMENT ON COLUMN dm.sales_alverse_mlc.delivery_basis is 'Базис поставки | Базис поставки (Инкотермс 1), это правило поставки Инкотермс. 
Базис обозначается тремя латинскими буквами, например EXW, CIP, DAP и пр. 
Инфо берем из клиентского лота, ели его нет то из заявки под план производства | dm_calc.sd_sales_main_scm.delivery_basis';
-- SD.000068
COMMENT ON COLUMN dm.sales_alverse_mlc.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс (Инкотермс 2), 
это место передачи груза, это может быть город, аэропорт, морской либо речной порт. Инфо берем из клиентского лота, ели его нет то из заявки под план производства | dm_calc.sd_sales_main_scm.delivery_point_name';
-- SD.000071
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_stamp_railway_bill is 'Дата штемпеля по ЖДН | ЖДН - железнодорожная накладная, RWB - railway bill
Дата со штемпеля на ЖД накладной со станции отправления. Инфо берем из данных об отгрузке с завода. 
Эта дата используется по-разному, в зависимости от вида перехода права собственности (далее ППС):
- при ППС 001 (отпуск материала проходит на станции продавца) это дата будет датой отпуска материала;
- при ППС 002 (отпуск материала проходит только, доехав до станции покупателя) это дата отправки вагона со станции отправителя | dm_calc.sd_sales_main_scm.dt_stamp_railway_bill';
-- SD.000072
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_plant_arrival is 'Дата прихода на завод | Дата, прибытия пустого контейнера на завод. Инфо берем из данных об отгрузке с завода | dm_calc.sd_sales_main_scm.dt_plant_arrival';
-- SD.000073
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_import_export_transfer is 'Дата перехода из импорта в экспорт | Дата, когда морской контейнер вернули в РФ из-за границы. 
Инфо берем из данных об отгрузке с завода | dm_calc.sd_sales_main_scm.dt_import_export_transfer';
-- SD.000078
COMMENT ON COLUMN dm.sales_alverse_mlc.contract_export_number is 'Внешнеторговый контракт завода (ex.Номер экспортного контракта) | 
Договор (номер на бумажном носителе) по которому выполняется экспорт продукции из РФ | dm_calc.sd_sales_main_scm.contract_export_number';
-- SD.000079
COMMENT ON COLUMN dm.sales_alverse_mlc.dimensions_unit is 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | dm_calc.sd_sales_main_scm.dimensions_unit';
-- SD.000081
COMMENT ON COLUMN dm.sales_alverse_mlc.consignee_name is 'Грузополучатель | Название получателя материала по отгрузочному документу завода - ЖД накладная/CMR/ТТН. 
Тот, в адрес кого Завод производитель отгружает продукцию. | dm_calc.sd_sales_main_scm.consignee_name';
-- SD.000088
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_customs_declaration is 'Дата ГТД | Дата грузовой таможенной декларации | dm_calc.sd_sales_main_scm.dt_customs_declaration';
-- SD.000089
COMMENT ON COLUMN dm.sales_alverse_mlc.material_specification_name is 'Спецификация | Название документа с набором требований, которым должен соответствовать разрабатываемый продукт | dm_calc.sd_sales_main_scm.material_specification_name';
-- SD.000090
COMMENT ON COLUMN dm.sales_alverse_mlc.weight_strip is 'Вес ленты | Вес упаковки, рассчитывается по формуле: «Вес брутто» - «Вес Н&K», инфо выводим в базисной единице измерения. | dm_calc.sd_sales_main_scm.weight_strip';
-- SD.000095
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_quarantine_certificate is 'Дата карантинного сертификата | Дата документа, который удостоверяет соответствие партии подкарантинной продукции 
карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, осуществляющим функции по контролю и надзору в области карантина, 
при перемещении подкарантинной продукции по территории Российской Федерации. | dm_calc.sd_sales_main_scm.dt_quarantine_certificate';
-- SD.000103
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_first_entry_appeared is 'Дата первого появления записи в системе | Дата создания записи об отгрузке, 
в транзакции ZSD2925M Загрузки данных об отгрузке на трейдерах | dm_calc.sd_sales_main_scm.dt_first_entry_appeared';
-- SD.000112
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_collection is 'Дата комплектования | Дата комплектования (подготовки груза для отгрузки) поставки завода производителя | dm_calc.sd_sales_main_scm.dt_collection';
-- SD.000113
COMMENT ON COLUMN dm.sales_alverse_mlc.destination_station_in_shipment_name is 'Станция назначения в отгрузке | Название станции, которая является конечной точкой доставки по ж\д, 
инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | dm_calc.sd_sales_main_scm.destination_station_in_shipment_name';
-- SD.000121
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_shipment_plan is 'Плановая дата отгрузки | Дата когда была запланирована отгрузка по Заказу ЦК, заполняется в графике отгрузки на стороне BI | dm_calc.sd_sales_main_scm.dt_shipment_plan';
-- SD.000123
COMMENT ON COLUMN dm.sales_alverse_mlc.sales_order is 'Заказ ЦК | Это системный номер заказаЦК в отгрузке | dm_calc.sd_sales_main_scm.sales_order';
-- SD.000128
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_discharge_in_foreign_port is 'Дата выгрузки в порту | Дата выгрузки судна в иностранном порту, по коносаменту из РФ | dm_calc.sd_sales_main_scm.dt_discharge_in_foreign_port';
-- SD.000129
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_discharge_in_second_foreign_port is 'Дата выгрузки в порту 2 | Дата выгрузки судна в иностранном порту, по коносаменту в ин. порту | dm_calc.sd_sales_main_scm.dt_discharge_in_second_foreign_port';
-- SD.000130
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_arrival_in_port_of_discharge_plan is 'Дата прибытия в порт выгрузки план | Плановая дата прибытия в порт выгрузки по коносаменту РФ. Инфо получаем из:
1) Коносамента, поля ETA D. Port;
2) Еслив коносаменте ETA D. Port не заполнено, то из Номинации, указанной в этом коносаменте. В номинацию инфо попадает при помощи: загрузочного файл Expected или автоматической загрузки инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
3) Если нет инфо в номинации, то дату берем из Данных портового экспедитора;
4) Если Коносамент еще не создан и «VF: Дата отправления из Порт погрузки» не пустая, то Дата прибытия в порт выгрузки план = «VF: ETA в Порт выгрузки»; 
5) Если Коносамент еще не создан и «VF: Дата прибытия в порт погрузки» не пустая, то Дата прибытия в порт выгрузки план = «Expected BL» + «VF: Время в пути до порта выгрузки»;
6) Если «Тип вагона (код)» = мосркой контейнер и по пунктам выше дату не нашли, то Дата прибытия в порт выгрузки план= «Дата Коносамента» + «Норма морского транзита»;
Иначе= «Booking cont» + «Норма морского транзита»;
Иначе= «Expected BL» + «Норма морского транзита»; | dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge_plan';
-- SD.000132
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_delivery_notice is 'Дата нотиса о доставке | Дата документа, который создает ДСБ (дирекция по сбыту) для базисов поставки DDP или DAP для отражения даты доставки клиенту | dm_calc.sd_sales_main_scm.dt_delivery_notice';
-- SD.000143
COMMENT ON COLUMN dm.sales_alverse_mlc.material_code is 'Номер материала | Системный номер материала. Например, APT0006ING0045. Аналог поля Код материала | dm_calc.sd_sales_main_scm.material_code';
-- SD.000145
COMMENT ON COLUMN dm.sales_alverse_mlc.grade_name is 'Марка по спецификации | Наименование марки по спецификации. Например у материала AAX0024SLB0148, Марка по спецификации= 1050 | dm_calc.sd_sales_main_scm.grade_name';
-- SD.000146
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_sales_order_delivery_actual is 'Фактическая дата получения заказа клиента | Дата, когда получили доп.информацию по заказу (данные опциона) от клиента. | dm_calc.sd_sales_main_scm.dt_sales_order_delivery_actual';
-- SD.000149
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_delivery_deadline is 'Deadline доставки | Желемый срок доставки по конрактым обязательствам (переход права собственности) в рамках заказа ЦК. 
Например, для CIF это желаемая дата прибытия в порт погрузки РФ/ ин. склада, для прочих желаемая дата доставки до клиента. | dm_calc.sd_sales_main_scm.dt_delivery_deadline';
-- SD.000150
COMMENT ON COLUMN dm.sales_alverse_mlc.shipment_period_preferred is 'Желаемый период отгрузки | Желаемый период отгрузки с завода производителя | dm_calc.sd_sales_main_scm.shipment_period_preferred';
-- SD.000151
COMMENT ON COLUMN dm.sales_alverse_mlc.uni is 'UNI | Если Причина деления постави = ""4- Перевеска"", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | dm_calc.sd_sales_main_scm.uni';
-- SD.000157
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_arrival_in_second_port_of_discharge_plan is 'Дата прибытия в порт выгрузки 2 план | Плановая дата прибытия в порт выгрузки из коносамента в ин. порту. 
Дата из Коносамента в ин. порту, поля ETA D. Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
 | dm_calc.sd_sales_main_scm.dt_arrival_in_second_port_of_discharge_plan';
-- SD.000162
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_expected_delivery is 'Expected delivery | Ожидаемая дата доставки до клиента, является расчетной. Формула рассчета зависит от «Сценарий маршрута». | dm_calc.sd_sales_main_scm.dt_expected_delivery';
-- SD.000164
COMMENT ON COLUMN dm.sales_alverse_mlc.end_user_name is 'Конечный потребитель | Имя контрагента, который является потребителем металла, т.е. будет использовальзовать метал для производства своей продукции, т.е. для собственных нужд. 
В одной сделке Потребитель и Конечный потребитель могут быть разные юр.лица, а может быть одно. | dm_calc.sd_sales_main_scm.end_user_name';
-- SD.000165
COMMENT ON COLUMN dm.sales_alverse_mlc.quantity_shipped is 'Отгруженное количество | Фактически отгруженное количество, заполняется только для строк, у которых «Признак План/Факт» = «F» | dm_calc.sd_sales_main_scm.quantity_shipped';
-- SD.000166
COMMENT ON COLUMN dm.sales_alverse_mlc.quantity_ordered is 'Запланированное количество | Запланированное количество к отгрузке по Заказу ЦК | dm_calc.sd_sales_main_scm.quantity_ordered';
-- SD.000167
COMMENT ON COLUMN dm.sales_alverse_mlc.invoice_provisional_number is 'Provisional invoice | Инвойс (счет клиенту), он может быть предварительным или окончательным. 
Предварительный - когда указывают цену, в которой ещё не уверены. | dm_calc.sd_sales_main_scm.invoice_provisional_number';
-- SD.000170
COMMENT ON COLUMN dm.sales_alverse_mlc.invoice_final_number is 'Final Invoice | Финальный счет, нужен для уточнения цены или корректировки стоимости, создается в случае необходимости, когда контировки уже корректно рассчитаны. 
Как правило оформляется со ссылкой на Provisional invoice | dm_calc.sd_sales_main_scm.invoice_final_number';
-- SD.000173
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_pledge_in is 'Дата pledge in | Дата документа залога, дата начала действия кредитного договора по залогу, т.е. когда нам открыли кредитную линию. 
Залог- это кредитная линия под проценты/комиссию, под залог метала или дебиторской задолженности, в зависимости от вида заключенного договора. | dm_calc.sd_sales_main_scm.dt_pledge_in';
-- SD.000174
COMMENT ON COLUMN dm.sales_alverse_mlc.production_order is 'Производственный заказ | Номер заказа, по которому завод выпускает производитель продукцию. 
Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. Изначально производственные заказы вносятся в тразакции ZSD2882M-Регистрация заявок клиентов | dm_calc.sd_sales_main_scm.production_order';
-- SD.000175
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_storage_start_in_foreign_port is 'Дата начала хранения ин. склад | Дата начала хранения металла на удаленном складе, после поступления груза в ин. порт из РФ | dm_calc.sd_sales_main_scm.dt_storage_start_in_foreign_port';
-- SD.000176
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_storage_end_in_foreign_port is 'Окончание хранения в ин. порту | Дата окончания хранения металла на удаленном складе, после поступления груза в ин. порт из РФ | dm_calc.sd_sales_main_scm.dt_storage_end_in_foreign_port';
-- SD.000177
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_storage_start_in_second_foreign_warehouse is 'Начало хранения склад 2 | Дата начала хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт | dm_calc.sd_sales_main_scm.dt_storage_start_in_second_foreign_warehouse';
-- SD.000178
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_storage_end_in_second_foreign_warehouse is 'Окончание хранение склад 2 | Дата окончания хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт | dm_calc.sd_sales_main_scm.dt_storage_end_in_second_foreign_warehouse';
-- SD.000180
COMMENT ON COLUMN dm.sales_alverse_mlc.material_shape_name_full is 'Форма | Форма | dm_calc.sd_sales_main_scm.material_shape_name_full';
-- SD.000200
COMMENT ON COLUMN dm.sales_alverse_mlc.material_name is 'Наименование материала | - | dm_calc.sd_sales_main_scm.material_name';
-- SD.000243
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_realization_forecast is 'Расчетная дата реализации | - | dm_calc.sd_sales_main_scm.dt_realization_forecast';
-- SD.000245
COMMENT ON COLUMN dm.sales_alverse_mlc.realization_reason_document is 'Основание реализации | Вид документа, который является основанием для реализации | dm_calc.sd_sales_main_scm.realization_reason_document';
-- SD.000246
COMMENT ON COLUMN dm.sales_alverse_mlc.frame_contract_code is 'Рамочный контракт (код) | Системный номер рамочного контракта с клиентом | dm_calc.sd_sales_main_scm.frame_contract_code';
-- SD.000253
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_expected_bill_of_lading is 'Expected BL | Ожидаемая дата коносамента | dm_calc.sd_sales_main_scm.dt_expected_bill_of_lading';
-- SD.000259
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_release_material is 'Дата ОМ | ОМ- отпуск материала
Дата проводки ОМ | dm_calc.sd_sales_main_scm.dt_release_material';
-- SD.000261
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_etd is 'ETD | - | dm_calc.sd_sales_main_scm.dt_etd';
-- SD.000338
COMMENT ON COLUMN dm.sales_alverse_mlc.delivery_region_name is 'Регион поставки по контракту | - | dm_calc.sd_sales_main_scm.delivery_region_name';
-- SD.000344
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_prepared_for_realization is 'Дата готовности к релизу | - | dm_calc.sd_sales_main_scm.dt_prepared_for_realization';
-- SD.000375
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_ownership_transfer is 'Дата перехода права собственности | - | dm_calc.sd_sales_main_scm.dt_ownership_transfer';
-- SD.000482
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_final_release is 'Дата Финальный релиз | Отображает дату созданого финального релиза | dm_calc.sd_sales_main_scm.dt_final_release';
-- SD.000491
COMMENT ON COLUMN dm.sales_alverse_mlc.railway_movement_status_name is 'Статус движения по ЖД | Статус движения по ЖД | dm_calc.sd_sales_main_scm.railway_movement_status_name';
-- SD.000492
COMMENT ON COLUMN dm.sales_alverse_mlc.business_location_name is 'Статус в Supply chain (Business) | Статус логистического этапа транспортировки/хранения | dm_calc.sd_sales_main_scm.business_location_name';
-- SD.000579
COMMENT ON COLUMN dm.sales_alverse_mlc.total_commitment_weight is 'Объем обязательств итого | Объем обязательств итого | dm_calc.sd_sales_main_scm.total_commitment_weight';
-- SD.000583
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_warehouse_confirmation is 'Дата Storage confirmation | Дата Storage confirmation | dm_calc.sd_sales_main_scm.dt_warehouse_confirmation';
-- SD.000587
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_notice is 'Дата нотиса | Дата нотиса | dm_calc.sd_sales_main_scm.dt_notice';
-- SD.000588
COMMENT ON COLUMN dm.sales_alverse_mlc.final_release_code is 'Номер Финальный релиз | Номер Финальный релиз | dm_calc.sd_sales_main_scm.final_release_code';
-- SD.000589
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_final_invoice_payment is 'Дата оплаты Final Invoice | Дата оплаты Final Invoice | dm_calc.sd_sales_main_scm.dt_final_invoice_payment';
-- SD.000601
COMMENT ON COLUMN dm.sales_alverse_mlc.country_of_end_user_name is 'Страна конечного потребителя | Страна конечного потребителя | dm_calc.sd_sales_main_scm.country_of_end_user_name';
-- SD.000606
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_assignment is 'Дата поручения | Дата поручения | dm_calc.sd_sales_main_scm.dt_assignment';
-- SD.000607
COMMENT ON COLUMN dm.sales_alverse_mlc.vessel_and_voyage_plan_search_name is 'Судно / номер рейса (план) | Судно / номер рейса (план) | dm_calc.sd_sales_main_scm.vessel_and_voyage_plan_search_name';
-- SD.000608
COMMENT ON COLUMN dm.sales_alverse_mlc.vessel_and_voyage_actual_search_name is 'Судно / номер рейса (факт) | Судно / номер рейса (факт) | dm_calc.sd_sales_main_scm.vessel_and_voyage_actual_search_name';
-- SD.000611
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_storage_payed_in_foreign_port_by_rusal is 'Дата окончания хранения на складе за счет RUSAL | Дата окончания хранения на складе за счет RUSAL по Релизу | dm_calc.sd_sales_main_scm.dt_storage_payed_in_foreign_port_by_rusal';
-- SD.000613
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_shipment_instruction_in_foreign_port is 'Дата инструкции на отгрузку Ин Порт | Дата инструкции на отгрузку Ин Порт | dm_calc.sd_sales_main_scm.dt_shipment_instruction_in_foreign_port';
-- SD.000614
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_shipment_instruction_date_from is 'SI: Дата с | Инструкция на отгрузку хранение по графику "Дата с" | dm_calc.sd_sales_main_scm.dt_shipment_instruction_date_from';
-- SD.000615
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_shipment_instruction_date_to is 'SI: Дата по | Инструкция на отгрузку хранение по графику "Дата по" | dm_calc.sd_sales_main_scm.dt_shipment_instruction_date_to';
-- SD.000616
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_barge_loading is 'Дата погрузки на баржу | Дата баржевого коносамента | dm_calc.sd_sales_main_scm.dt_barge_loading';
-- SD.000617
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_barge_arrival is 'Дата доставки баржи | Доставка по баржевому коносаменту | dm_calc.sd_sales_main_scm.dt_barge_arrival';
-- SD.000619
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_shipment_instruction_in_second_foreign_port is 'Дата инструкции на отгрузку Ин Порт 2 | Дата инструкции на отгрузку Ин Порт 2 | dm_calc.sd_sales_main_scm.dt_shipment_instruction_in_second_foreign_port';
-- SD.000620
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_invoice_provisional is 'Дата инвойса | Дата предварительного инвойса | dm_calc.sd_sales_main_scm.dt_invoice_provisional';
-- SD.000626
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_mh1_storage_document is 'Дата Акта МХ-1 | Дата акта на склад СВХ | dm_calc.sd_sales_main_scm.dt_mh1_storage_document';
-- SD.000628
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_mh3_storage_document is 'Дата Акта МХ-3 | Дата акта со склада СВХ | dm_calc.sd_sales_main_scm.dt_mh3_storage_document';
-- SD.000629
COMMENT ON COLUMN dm.sales_alverse_mlc.dt_departure_from_foreigh_port is 'EXP: Load out date | EXP: Load out date | dm_calc.sd_sales_main_scm.dt_departure_from_foreigh_port';
