DROP TABLE IF EXISTS dds.sales_batch_delivery;

CREATE TABLE dds.sales_batch_delivery(
	batch_code varchar(10) NULL,								-- Партия 
	delivery_number_initial varchar(10) NULL, 					-- Исходная поставка
	shipment_entry_from_file_code varchar(16) NULL,				-- Идентификатор записи об отгрузке из файла
	delivery_number_of_plant_producer varchar(10) NULL, 		-- Номер поставки завода производителя
	sales_order_in_shipment varchar(30) NULL,					-- Заказ ЦК в отгрузке
	plant_producer_code varchar(4) NULL,						-- Завод производитель (код)
	railcar_code varchar(20) NULL,								-- Вагон
	railway_platform_code varchar(12) NULL,						-- Платформа
	material_code varchar(18) NULL, 							-- Код материала
	market_in_shipment_code varchar(1) NULL,					-- Рынок в отгрузке (код)
	forwarder_in_contract_code varchar(10) NULL,				-- Экспедитор Договорной (код)
	dt_stamp_railway_bill date NULL,							-- Дата штемпеля по ЖДН
	dt_arrival_to_plant date NULL,								-- Дата прихода на завод
	dt_conversion_from_import_to_export date NULL,				-- Дата перехода из импорта в экспорт
	seal_number varchar(150) NULL,								-- Номера пломб
	fixing_holder_weight numeric(13, 3) NULL,					-- Реквизит/Вес крепления груза
	receiving_plant_in_sap_system_code varchar(4) NULL,			-- Принимающий завод грузополучателя в системе SAP
	customer_code varchar(10) NULL, 							-- Заказчик
	contract_export_number varchar(35) NULL,					-- Номер экспортного контракта
	unit_dimensions varchar(20) NULL,							-- Размер единицы готовой продукции
	consignee_code varchar(10) NULL,							-- Код грузополучателя материала
	consignee_name varchar(120) NULL,							-- Наименование грузополучателя материала
	railcar_internal_code varchar(10) NULL,						-- Idw1
	route_in_shipment_code varchar(6) NULL,						-- Маршрут в отгрузке
	discharge_terminal_code varchar(10) NULL,					-- Код терминала разгрузки
	destination_station_code varchar(10) NULL,					-- Код станции назначения
	quarantine_certificate_number varchar(18) NULL,				-- Карантинный сертификат
	dt_quarantine_certificate timestamp NULL,					-- Дата карантинного сертификата
	cargo_package_quantity int8 NULL,							-- Количество грузовых мест
	receiving_warehouse_code varchar(4) NULL,					-- Принимающий склад
	weight_net_with_wirerod numeric(13, 3) NULL, 				-- Вес нетто + катанка
	plant_owner_code varchar(4) NULL,							-- Завод собственник (код)
	station_of_departure_code varchar(40) NULL,					-- Станция отправления
	instruction_number varchar(10) NULL,						-- Номер распоряжения
	delivery_number_of_plant_owner varchar(10) NULL,			-- Номер поставки завода собственника
	dt_created date NULL,										-- Дата первого появления записи в системе
	finish_good_unit_length varchar(10) NULL,					-- Длина единицы готовой продукции
	finish_good_unit_width varchar(10) NULL,					-- Ширина единицы готовой продукции
	finish_good_unit_height varchar(10) NULL,					-- Высота единицы готовой продукции
	finish_good_unit_diameter varchar(20) NULL,					-- Диаметр единицы готовой продукции
	quality_certificate_number varchar(20) NULL,				-- Номер сертификата
	delivery_item_number_of_plant_producer varchar(6) NULL,		-- Позиция поставки завода производителя
	dt_order_picking date NULL,									-- Дата комплектования
	station_of_destination_name varchar(40) NULL,				-- Станция назначения в отгрузке
	foil_box_number varchar(3) NULL,							-- Ящик
	route_code varchar(17) NULL, 								-- Номер маршрута
	dt_forwarder date NULL,										-- Дата экспедитора
	plant_name varchar(40) NULL, 								-- Завод
	gtd_number varchar(30) NULL, 								-- Номер ГТД
	dt_storage_start_in_warehouse timestamp NULL, 				-- Начало хранения на складе
	package_weight numeric(13, 3) NULL, 						-- Масса упаковки
	buyer_code varchar(10) NULL, 								-- Покупатель (код)
	forwarder_name varchar(120) NULL, 							-- Экспедитор
	end_user_code varchar(10) NULL, 							-- Потребитель (код)
	shipment_entry_identifier_from_file varchar(16) NULL,		-- Идентификатор записи об отгрузке из файла
	exporter_code varchar(10) NULL,								-- Экспортер (код)
	tsw_location_code varchar(10) NULL, 						-- Порт (код)
	dt_shipment date NULL,										-- Дата отгрузки
	shipment_type_code varchar(2) NULL, 						-- Вид отгрузки (код)
	dt_border_cross date null, 									-- Дата пересечения границы
	sales_plant_contract_code varchar(10) null,					-- Договор завода-производителя (код)
	weight_gross numeric(13, 3) NULL,							-- Вес брутто
	weight_net numeric(13, 3) NULL,								-- Вес нетто
	is_plant_not_in_sap_system varchar(1) NULL, 				-- Завод не в САП (код)
	temporary_warehouse_movement_type_code varchar(1) NULL,		-- Технический вид движения на/со склада (код)
	is_not_valid_for_reporting bool,							-- Индикатор: запись не применима для отчетности
	"dttm_inserted" timestamp NOT NULL DEFAULT now(),
	"dttm_updated" timestamp NOT NULL DEFAULT now(),
	"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (delivery_number_initial, shipment_entry_from_file_code, batch_code, delivery_number_of_plant_owner);

comment on table dds.sales_batch_delivery IS 'Партия-поставка';
comment on column dds.sales_batch_delivery.batch_code is 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков | ods."/rusal/shipdata_ral".CHARG';
comment on column dds.sales_batch_delivery.delivery_number_initial is 'Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах | ods."/rusal/shipdata_ral".VBELN';
comment on column dds.sales_batch_delivery.shipment_entry_from_file_code is 'Идентификатор записи об отгрузке из файла | Идентификатор записи об отгрузке из файла | ods."/rusal/shipdata_ral".VBELN';
comment on column dds.sales_batch_delivery.delivery_number_of_plant_producer is 'Номер поставки завода производителя | Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе | ods."/rusal/shipdata_ral".VBELN_LF';
comment on column dds.sales_batch_delivery.sales_order_in_shipment is 'Заказ ЦК в отгрузке | № заказа центральной компании (заявки) под план производства. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. Изначально заказы ЦК вносятся в тразакции ZSD2882M-Регистрация заявок клиентов. Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК | ods."/rusal/shipdata_ral".ORDER_';
comment on column dds.sales_batch_delivery.plant_producer_code is 'Завод производитель (код) | Код завода производителя | ods."/rusal/shipdata_ral".PLANT';
comment on column dds.sales_batch_delivery.railcar_code is 'Вагон | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя | ods."/rusal/shipdata_ral".VAGON';
comment on column dds.sales_batch_delivery.railway_platform_code is 'Платформа | Номер платформы, на которой передвигается контейнер, по жд от Завода производителя | ods."/rusal/shipdata_ral".PLATF';
comment on column dds.sales_batch_delivery.material_code is 'Код материала | Системный номер материала. Например, APT0006ING0045. Аналог поля Номер материала | ods."/rusal/shipdata_ral".GRADECOD';
comment on column dds.sales_batch_delivery.market_in_shipment_code is 'Рынок в отгрузке (код) | Код рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | ods."/rusal/shipdata_ral".MARKET';
comment on column dds.sales_batch_delivery.forwarder_in_contract_code is 'Экспедитор Договорной (код) | Системный код экпедитора, это тот с кем заключен договор экспедирования груза. Заполняется заводом производителем при оформлении отгрузки металла с завода до конечной точки. | ods."/rusal/shipdata_ral".EXPEDIDSUB';
comment on column dds.sales_batch_delivery.dt_stamp_railway_bill is 'Дата штемпеля по ЖДН | "Дата со штемпеля на ЖД накладной со станции отправления. Инфо берем из данных об отгрузке с завода. Эта дата используется по-разному, в зависимости от вида перехода права собственности (далее ППС):
- при ППС 001 (отпуск материала проходит на станции продавца) это дата будет датой отпуска материала;
- при ППС 002 (отпуск материала проходит только, доехав до станции покупателя) это дата отправки вагона со станции отправителя" | ods."/rusal/shipdata_ral".SHTEMPEL_DATE';
comment on column dds.sales_batch_delivery.dt_arrival_to_plant is 'Дата прихода на завод | Дата, прибытия пустого контейнера на завод. Инфо берем из данных об отгрузке с завода | ods."/rusal/shipdata_ral".PRIH_ZAVOD_DATE';
comment on column dds.sales_batch_delivery.dt_conversion_from_import_to_export is 'Дата перехода из импорта в экспорт | Дата, когда морской контейнер вернули в РФ из-за границы. Инфо берем из данных об отгрузке с завода | ods."/rusal/shipdata_ral".IMPEXP_DATE';
comment on column dds.sales_batch_delivery.seal_number is 'Номера пломб | Номер пломбы, навешиваемой на кузова транспортных средств (вагоны, фургоны, контейнеры, их секции и отдельные грузовые места), которая не должна допускать возможности доступа к грузу и снятия пломбы без нарушения их целостности. Инфо берем из данных об отгрузке с завода | ods."/rusal/shipdata_ral".NSTAMP';
comment on column dds.sales_batch_delivery.fixing_holder_weight is 'Реквизит | Вес крепления товара в транспортном средстве в КГ. Инфо берем из данных об отгрузке с завода | ods."/rusal/shipdata_ral".REKVIZIT';
comment on column dds.sales_batch_delivery.receiving_plant_in_sap_system_code is 'Принимающий завод грузополучателя в системе SAP | Системный номер завода оператора, собственника продукции при реализации клиенту | ods."/rusal/shipdata_ral".WERKS';
comment on column dds.sales_batch_delivery.customer_code is 'Заказчик | Системный номер дебитора, который является покупателем у завода производителя, т.е. тот кому отгружает продукцию Завод производитель. | ods."/rusal/shipdata_ral".CUSTOMID';
comment on column dds.sales_batch_delivery.contract_export_number is 'Номер экспортного контракта | Договор (номер на бумажном носителе) по которому выполняется экспорт продукции из РФ | ods."/rusal/shipdata_ral".CONTREXP';
comment on column dds.sales_batch_delivery.unit_dimensions is 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | ods."/rusal/shipdata_ral".RAZMER';
comment on column dds.sales_batch_delivery.consignee_code is 'Получатель материала | Системный код дебитора, который является получателем продукции по отгрузочному документу завода - ЖД накладная/CMR/ТТН. Тот, в адрес кого Завод производитель отгружает продукцию. | ods."/rusal/shipdata_ral".FIRMAPID';
comment on column dds.sales_batch_delivery.consignee_name is 'Грузополучатель | Название получателя материала по отгрузочному документу завода - ЖД накладная/CMR/ТТН. Тот, в адрес кого Завод производитель отгружает продукцию. | ods."/rusal/shipdata_ral".FIRMAP';
comment on column dds.sales_batch_delivery.railcar_internal_code is 'Idw1 | Внутренний идентификатор вагона при взаимодействии с портовыми экспедиторами по сути равен номеру первой партии вагона | ods."/rusal/shipdata_ral".IDW1';
comment on column dds.sales_batch_delivery.route_in_shipment_code is 'Маршрут в отгрузке | Системный номер маршрута из поставки завода производителя. Инфо берем из данных об отгрузке с завода | ods."/rusal/shipdata_ral".ROUTE';
comment on column dds.sales_batch_delivery.discharge_terminal_code is 'Код терминала разгрузки | Источник данных /RUSAL/SHIPDATA-UNL_TERM, вегда = пусто | ods."/rusal/shipdata_ral".UNL_TERM';
comment on column dds.sales_batch_delivery.destination_station_code is 'Код станции назначения | Системный код станции назначения, которая является конечной точкой доставки по ж\д, инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | ods."/rusal/shipdata_ral".STATIONNC';
comment on column dds.sales_batch_delivery.quarantine_certificate_number is 'Карантинный сертификат | Номер документа, который удостоверяет соответствие партии подкарантинной продукции карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, осуществляющим функции по контролю и надзору в области карантина, при перемещении подкарантинной продукции по территории Российской Федерации. | ods."/rusal/shipdata_ral".QUAR_SERT';
comment on column dds.sales_batch_delivery.dt_quarantine_certificate is 'Дата карантинного сертификата | Дата документа, который удостоверяет соответствие партии подкарантинной продукции карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, осуществляющим функции по контролю и надзору в области карантина, при перемещении подкарантинной продукции по территории Российской Федерации. | ods."/rusal/shipdata_ral".QUAR_DATE';
comment on column dds.sales_batch_delivery.cargo_package_quantity is 'Количество грузовых мест | Количество грузовых мест в вагоне | ods."/rusal/shipdata_ral".MEST';
comment on column dds.sales_batch_delivery.receiving_warehouse_code is 'Принимающий склад | Код склада Завода- оператора (собственника продукции при реализации клиенту), на который будет принята продукция и в дальнейшем с которого будет производиться отгрузка Клиенту | ods."/rusal/shipdata_ral".LGORT';
comment on column dds.sales_batch_delivery.weight_net_with_wirerod is 'Вес нетто + катанка | Сумма веса нетто и веса катанки | ods."/rusal/shipdata_ral".NK';
comment on column dds.sales_batch_delivery.plant_owner_code is 'Завод собственник (код) | Системный номер завода собственника сырья, он передает свое сырье на переработку Заводу производителю | ods."/rusal/shipdata_ral".PLANT1';
comment on column dds.sales_batch_delivery.station_of_departure_code is 'Станция отправления | Название станции, которая является отправной точкой груза по ж\д, инфо выводится из начального узла Маршрута завода | ods."/rusal/shipdata_ral".STATIONO';
comment on column dds.sales_batch_delivery.instruction_number is 'Номер распоряжения | Номер распоряжения на отгрузку (номер заказа в системе), создается только для отгрузок на внутренний рынок и СНГ, этот документ является указанием к отгрузке Заводу производителю, в нем указано кому, что и сколько нужно отгрузить. Распоряжение на отгрузку создается ДСБ по контракту с клиентом из Заказа ЦК в отгрузке (в тразакции ZSD2882M-Регистрация заявок клиентов) и выдается производителю. | ods."/rusal/shipdata_ral".RASPOR';
comment on column dds.sales_batch_delivery.delivery_number_of_plant_owner is 'Номер поставки завода собственника | Поставка завода собственника сырья, по которой формируется цепочка продаж на заводе собственнике | ods."/rusal/shipdata_ral".VBELN_LFS';
comment on column dds.sales_batch_delivery.dt_created is 'Дата первого появления записи в системе | Дата создания записи об отгрузке, в транзакции ZSD2925M Загрузки данных об отгрузке на трейдерах | ods."/rusal/shipdata_ral".DATEADD';
comment on column dds.sales_batch_delivery.shipment_entry_identifier_from_file is 'Идентификатор записи об отгрузке из файла | Идентификатор записи (уникальный номер) об отгрузке | ods."/rusal/shipdata_ral".IDENT';
comment on column dds.sales_batch_delivery.finish_good_unit_length is 'Длина единицы готовой продукции | Длина единицы готовой продукции | ods."/rusal/shipdata_ral".LENGTH';
comment on column dds.sales_batch_delivery.finish_good_unit_width is 'Ширина единицы готовой продукции | Ширина единицы готовой продукции | ods."/rusal/shipdata_ral".WIDTH';
comment on column dds.sales_batch_delivery.finish_good_unit_height is 'Высота единицы готовой продукции | Высота единицы готовой продукции | ods."/rusal/shipdata_ral".HEIGHT';
comment on column dds.sales_batch_delivery.finish_good_unit_diameter is 'Диаметр единицы готовой продукции | Диаметр единицы готовой продукции | ods."/rusal/shipdata_ral".DIAMETER';
comment on column dds.sales_batch_delivery.quality_certificate_number is 'Номер сертификата | Официальный документ, подтверждающий высокое качество продукции и соответствие установленным требованиям государственных стандартов и технических регламентов. | ods."/rusal/shipdata_ral".NSERT';
comment on column dds.sales_batch_delivery.delivery_item_number_of_plant_producer is 'Позиция поставки завода производителя | Номер позиции поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе | ods."/rusal/shipdata_ral".POSNR_LF';
comment on column dds.sales_batch_delivery.dt_order_picking is 'Дата комплектования | Дата комплектования (подготовки груза для отгрузки) поставки завода производителя | ods."/rusal/shipdata_ral".KODAT';
comment on column dds.sales_batch_delivery.station_of_destination_name is 'Станция назначения в отгрузке | Название станции, которая является конечной точкой доставки по ж\д, инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | ods."/rusal/shipdata_ral".STATIONN';
comment on column dds.sales_batch_delivery.foil_box_number is 'Ящик | Номер ящика фольги | ods."/rusal/shipdata_ral".BOX';
comment on column dds.sales_batch_delivery.route_code is 'Номер маршрута | "Это номер, который объединяет в себе значение нескольких полей из группы поставок, которая создается на заводе и используется для группировки поставок в составе вагонов. Где, 
1) первый символ (буква), это вид группы, обозначает вид отгрузки; 
2) номер между символами ""-"", это системный номер группы;
3) последние цифры, после символа ""-"", это количество поставок, включенных в группу. По этому значению мы понимаем, что это одиночная отправка или целый состав.
Например, Номер маршрута A-8000055482-65, обозначает: вид группы A-ЖД маршрут, номер группы 8000055482, количество поставок, включенных в группу 65." | ods."/rusal/shipdata_ral".MARSHR';
comment on column dds.sales_batch_delivery.dt_forwarder is 'Дата экспедитора | Дата экспедитора | ods."/rusal/shipdata_ral".DATAPREK';
comment on column dds.sales_batch_delivery.plant_name is 'Завод | Завод | ods."/rusal/shipdata_ral".ZAVOD';
comment on column dds.sales_batch_delivery.gtd_number is 'Номер грузовой таможенной декларации (ГТД) | Номер грузовой таможенной декларации (ГТД) | ods."/rusal/shipdata_ral".GTD';
comment on column dds.sales_batch_delivery.dt_storage_start_in_warehouse is 'Начало хранения на складе | Дата прибытия на склад порта, когда экспедитор принял груз на склад | ods."/rusal/shipdata_ral".DATASKL';
comment on column dds.sales_batch_delivery.package_weight is 'Масса упаковки | Масса упаковки | ods."/rusal/shipdata_ral".PACKING';
comment on column dds.sales_batch_delivery.buyer_code is 'Покупатель | Покупатель | ods."/rusal/shipdata_ral".CUST2_ID';
comment on column dds.sales_batch_delivery.forwarder_name is 'Экспедитор, наименование | Экспедитор, наименование | ods."/rusal/shipdata_ral".EXPED';
comment on column dds.sales_batch_delivery.end_user_code is 'Покупатель (код) | Контрагент, который является получателем металла. Потребитель может быть и Конечным потребителем. | ods."/rusal/shipdata_ral".POTREBIT';
comment on column dds.sales_batch_delivery.exporter_code is 'Экспортер (код) | - | ods."/rusal/shipdata_ral".EXPORTER';
comment on column dds.sales_batch_delivery.tsw_location_code is '"Порт (код) | - | ods."/rusal/shipdata_ral".LOCID';
comment on column dds.sales_batch_delivery.dt_shipment is 'Дата отгрузки | Дата отгрузки | ods."/rusal/shipdata_ral".dateot';
comment on column dds.sales_batch_delivery.shipment_type_code is 'Вид отгрузки (код) | Вид отгрузки (код) | ods."/rusal/shipdata_ral".vsart';
comment on column dds.sales_batch_delivery.dt_border_cross is 'Дата пересечения границы | Дата пересечения границы | ods."/rusal/shipdata_ral".datapgp';
comment on column dds.sales_batch_delivery.sales_plant_contract_code is 'Договор завода-производителя (код) | Договор завода-производителя (код) | ods."/rusal/shipdata_ral".contr_id';
comment on column dds.sales_batch_delivery.weight_gross is 'Вес брутто | Вес брутто | ods."/rusal/shipdata_ral".brutto';
comment on column dds.sales_batch_delivery.weight_net is 'Вес нетто | Вес нетто | ods."/rusal/shipdata_ral".netto';
comment on column dds.sales_batch_delivery.is_plant_not_in_sap_system is 'Завод не в САП (код) | Завод не в САП (код) | ods."/rusal/shipdata_ral".werks_nosap';
comment on column dds.sales_batch_delivery.temporary_warehouse_movement_type_code is 'Технический вид движения на/со склада (код) | Технический вид движения на/со склада (код) | ods."/rusal/shipdata_ral".svh';
comment on column dds.sales_batch_delivery.is_not_valid_for_reporting is 'Индикатор: запись не применима для отчетности';