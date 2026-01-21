drop table if exists dm.transportation_external_location_metal_stock cascade;

create table if not exists dm.transportation_external_location_metal_stock (
	sales_bundle_code varchar(10) null,
	plant_producer_delivery_code varchar(30) null,
	plant_producer_delivery_position_code varchar(18) null,
	initial_delivery_code varchar(30) null,
	initial_delivery_position_code varchar(2) null,
	sales_delivery_position_code varchar(2) null,
	material_code varchar(54) null,
	material_name varchar(120) null,
	material_search_name varchar(175) null,
	dt_shipment date null,
	railcar_code varchar(60) null,
	transport_bill_code varchar(105) null,
	uni varchar(180) null,
	material_shape_code varchar(9) null,
	material_shape_name varchar(90) null,
	material_shape_search_name varchar(100) null,
	port_of_discharge_code varchar(30) null,
	port_of_discharge_name varchar(90) null,
	dt_arrival_to_russian_port date null,
	dt_storage_end_in_release date null,
	port_of_discharge_search_name varchar(121) null,
	transport_type_code varchar(12) null,
	transport_type_name varchar(120) null,
	transport_type_search_name varchar(133) null,
	etsng_code varchar(10) null,
	etsng_name varchar(240) null,
	etsng_search_name varchar(251) null,
	dt_report date null,
	sales_bundle_net_weight numeric(15, 3) null,
	sales_bundle_gross_weight numeric(15, 3) null,
	batch_code varchar(30) null,
	dt_arrival date null,
	region_of_remote_warehouse_name varchar(20) null,
	receiving_plant_name varchar(61) null,
	receiving_plant_search_name varchar(66) null,
	country_of_remote_warehouse_name varchar(300) null,
	receiving_plant_code varchar(4) null,
	sales_delivery_code varchar(30) null,
	transportation_inbound_delivery_code varchar(10) null,
	delivery_for_storage_calculation_code varchar(30) null,
	transportation_inbound_delivery_position_code varchar(6) null,
	delivery_position_for_storage_calculation_code varchar(6) null,
	forwarder_code varchar(10) null,
	storage_cost_calculation_type_name varchar(20) null,
	transport_departure_hub_code varchar(10) null,
	transport_departure_hub_name varchar(90) null,
	transport_destination_hub_code varchar(10) null,
	transport_destination_hub_name varchar(90) null,
	transportation_outbound_delivery_code varchar(10) null,
	transportation_outbound_delivery_position_code varchar(6) null,
	is_final_transportation_stage_code varchar(1) null,
	transportation_stage_code varchar(2) null,
	transportation_stage_name varchar(100) null,
	transportation_stage_search_name varchar(103) null,
	storage_calculation_bundle_quantity int8 null,
	forwarder_name varchar(35) null,
	forwarder_search_name varchar(46) null,
	warehouse_code varchar(10) null,
	warehouse_name varchar(90) null,
	warehouse_search_name varchar(101) null,
	delivery_in_final_release_code varchar(30) null,
	dt_final_release date null,
	bill_of_lading_code varchar(30) null,
	bill_of_lading_number varchar(90) null,
	dt_bill_of_lading date null,
	incoterms_code varchar(9) null,
	storage_cost_special_calculation_type_code varchar(1) null,
	warehouse_storage_area_code varchar(10) null,
	warehouse_storage_area_name varchar(90) null,
	warehouse_storage_area_search_name varchar(101) null,
	plant_code varchar(4) null,
	unit_balance_code varchar(4) null,
	creditor_in_shipment_instruction_code varchar(10) null,
	dt_storage_start date null,
	dt_shipped_from_warehouse date null,
	dt_storage_end date null,
	service_number text null,
	storage_duration_total_calendar_days int4 null,
	shipment_instruction_number varchar(30) null,
	dt_for_price_search_in_purchase_contract date null,
	purchase_contract_code varchar(10) null,
	purchase_contract_position_code varchar(5) null,
	purchase_contract_position_currency_code varchar(5) null,
	service_code varchar(18) null,
	service_name varchar(40) null,
	service_search_name varchar(59) null,
	purchase_contract_position_uom_code varchar(3) null,
	creditor_in_shipment_instruction_name varchar(300) null,
	creditor_in_shipment_instruction_search_name varchar(311) null,
	storage_duration_free_by_contract_calendar_days numeric(15, 3) null,
	storage_duration_free_by_delivery_calendar_days numeric(15, 3) null,
	storage_duration_payable_calendar_days numeric(15, 3) null,
	remote_warehouse_code varchar(10) null,
	remote_warehouse_name varchar(90) null,
	country_of_remote_warehouse_code varchar(3) null,
	dt_transportation_stage_start_p date null,
	dt_transportation_stage_start_r date null,
	dt_shipment_from_foreign_warehouse date null,
	storage_cost_calculated_amount numeric(15, 2) null,
	storage_cost_calculated_amount_local numeric(15, 2) null,
	storage_payable_001_030_days_gross_weight numeric(15, 3) null,
	storage_payable_031_060_days_gross_weight numeric(15, 3) null,
	storage_payable_061_090_days_gross_weight numeric(15, 3) null,
	storage_payable_091_180_days_gross_weight numeric(15, 3) null,
	storage_payable_181_365_days_gross_weight numeric(15, 3) null,
	storage_payable_over_365_days_gross_weight numeric(15, 3) null,
	is_stored_in_russian_port_code varchar(1) null,
	type_warehouse_name varchar(14) null,
	type_freight_name varchar(13) null,
	metal_owner_for_reporting_name varchar(30) null,
	storage_calculated_cost_001_030_amount numeric(15, 2) null,
	storage_calculated_cost_031_060_amount numeric(15, 2) null,
	storage_calculated_cost_061_090_amount numeric(15, 2) null,
	storage_calculated_cost_091_180_amount numeric(15, 2) null,
	storage_calculated_cost_181_365_amount numeric(15, 2) null,
	storage_calculated_cost_over_365_amount numeric(15, 2) null,
	metal_in_china_stock_balance_closing_weight numeric(15, 3) null,
	dttm_inserted timestamp default now() not null,
	dttm_updated timestamp default now() not null,
	job_name varchar(60) default 'airflow'::character varying not null,
	deleted_flag bool default false not null
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (sales_bundle_code);


comment on table dm.transportation_external_location_metal_stock is 'Витрина хранения металла на внешних складах после отгрузки с АЗ (подробный)';
comment on column dm.transportation_external_location_metal_stock.sales_bundle_code is 'Номер плавки металла (код) | Номер плавки металла | storage_sales_bundles_amount.sales_bundle_code LE.001000';
comment on column dm.transportation_external_location_metal_stock.plant_producer_delivery_code is 'Поставка завода производителя (код) | Поставка завода производителя | storage_sales_bundles_amount.plant_producer_delivery_code LE.001001';
comment on column dm.transportation_external_location_metal_stock.plant_producer_delivery_position_code is 'Позиция поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе (код) | Номер позиции поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе | storage_sales_bundles_amount.plant_producer_delivery_position_code LE.001002';
comment on column dm.transportation_external_location_metal_stock.initial_delivery_code is 'Исходная (первая) поставка, от которой начинается оформление цепочки продаж (код) | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. | storage_sales_bundles_amount.initial_delivery_code LE.001003';
comment on column dm.transportation_external_location_metal_stock.initial_delivery_position_code is 'Позиция поставки (код) | Номер позиции исходной поставки | Расчетное поле LE.001004';
comment on column dm.transportation_external_location_metal_stock.sales_delivery_position_code is 'Позиция разделенной поставки (код) | Номер позиции продажной поставки | Расчетное поле LE.001006';
comment on column dm.transportation_external_location_metal_stock.material_code is 'Номер материала (код) | технический номер материала | storage_sales_bundles_amount.material_code LE.001012';
comment on column dm.transportation_external_location_metal_stock.material_name is 'Материал (название) | наименование материала | material_texts.material_name LE.001013';
comment on column dm.transportation_external_location_metal_stock.material_search_name is 'Материал (код + название) | Ключ для материала | Расчетное поле LE.001014';
comment on column dm.transportation_external_location_metal_stock.dt_shipment is 'Дата отгрузки поставки с завода | Дата отгрузки поставки с завода | storage_sales_bundles_amount.dt_shipment LE.001020';
comment on column dm.transportation_external_location_metal_stock.railcar_code is 'Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя (код) | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя. | storage_sales_bundles_amount.railcar_code LE.001032';
comment on column dm.transportation_external_location_metal_stock.transport_bill_code is 'Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя (код) | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя | storage_sales_bundles_amount.transport_bill_code LE.001033';
comment on column dm.transportation_external_location_metal_stock.uni is 'Если Причина деления постави = "4- Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | Если Причина деления постави = "4- Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | storage_sales_bundles_amount.uni LE.001034';
comment on column dm.transportation_external_location_metal_stock.material_shape_code is 'Форма металла (код) | Технический код формы металла | storage_sales_bundles_amount.material_shape_code LE.001036';
comment on column dm.transportation_external_location_metal_stock.material_shape_name is 'Форма металла (наименование) | Наименование формы металла | material_shape_texts.material_shape_full_name LE.001037';
comment on column dm.transportation_external_location_metal_stock.material_shape_search_name is 'Форма металла (код + наименование) | Ключ для формы металла | Расчетное поле LE.001038';
comment on column dm.transportation_external_location_metal_stock.port_of_discharge_code is 'Порт хранения (код) | Для РФ - порт погрузки, для ин. портов - порт выгрузки на дату расчета (первый или второй ин. порт) | storage_sales_bundles_amount.port_of_discharge_code LE.001044';
comment on column dm.transportation_external_location_metal_stock.port_of_discharge_name is 'Порт хранения (наименование) | Название порта выгрузки | transport_hub.transport_hub_name_eng LE.001045';
comment on column dm.transportation_external_location_metal_stock.dt_arrival_to_russian_port is 'Дата прибытия металла в порт РФ | Дата прибытия металла в порт РФ | storage_sales_bundles_amount.dt_arrival_to_russian_port LE.001059';
comment on column dm.transportation_external_location_metal_stock.dt_storage_end_in_release is 'Дата окончания хранения металла за счет РУСАЛа | Дата окончания хранения металла за счет РУСАЛа | storage_sales_bundles_amount.dt_storage_end_in_release LE.001055';
comment on column dm.transportation_external_location_metal_stock.port_of_discharge_search_name is 'Порт хранения (код + название) | Ключ для порта хранения | Расчетное поле LE.001046';
comment on column dm.transportation_external_location_metal_stock.transport_type_code is 'Тип подвижного состава, с которым груз зашел для хранения (код) | Тип подвижного состава, с которым груз зашел для хранения  | storage_sales_bundles_amount.transport_type_code LE.001050';
comment on column dm.transportation_external_location_metal_stock.transport_type_name is 'Тип ПС (наименование) | Наименование типа ПС, с которым груз зашел для хранения  | transport_transfer_type_texts.transport_transfer_type_name LE.001051';
comment on column dm.transportation_external_location_metal_stock.transport_type_search_name is 'Тип ПС (код + наименование) | Ключ для типа ПС | Расчетное поле LE.001052';
comment on column dm.transportation_external_location_metal_stock.etsng_code is 'Код ЕТ СНГ (код) | Код груза согласно справочнику РЖД | storage_sales_bundles_amount.etsng_code LE.001066';
comment on column dm.transportation_external_location_metal_stock.etsng_name is 'Код ЕТ СНГ (наименование) | Код ЕТ СНГ (наименование) | etsng_texts.etsng_name LE.001067';
comment on column dm.transportation_external_location_metal_stock.etsng_search_name is 'Код ЕТ СНГ (код + наименование) | Код ЕТ СНГ (код + наименование) | Расчетное поле LE.001068';
comment on column dm.transportation_external_location_metal_stock.dt_report is 'Дата, на которую производится расчет хранения | Дата, на которую производится расчет хранения | storage_sales_bundles_amount.dt_report LE.001069';
comment on column dm.transportation_external_location_metal_stock.sales_bundle_net_weight is 'Вес нетто пакета | Вес нетто пакета | storage_sales_bundles_amount.sales_bundle_net_weight LE.001018';
comment on column dm.transportation_external_location_metal_stock.sales_bundle_gross_weight is 'Вес брутто пакета | Вес брутто пакета | storage_sales_bundles_amount.sales_bundle_gross_weight LE.001019';
comment on column dm.transportation_external_location_metal_stock.batch_code is 'Партия (код) | номер партии материала | storage_sales_bundles_amount.batch_code LE.001015';
comment on column dm.transportation_external_location_metal_stock.dt_arrival is 'Дата прибытия металла в пункт назначения | Дата прибытия металла в пункт назначения | storage_sales_bundles_amount.dt_arrival LE.001039';
comment on column dm.transportation_external_location_metal_stock.region_of_remote_warehouse_name is 'Регион удаленного склада (наименование) | Географический регион склада или терминала хранения | Расчетное поле LE.001061';
comment on column dm.transportation_external_location_metal_stock.receiving_plant_name is 'Завод поставки (наименование) | Наименование завода продажной поставки | plant_and_subsidiary.plant_full_name LE.001030';
comment on column dm.transportation_external_location_metal_stock.receiving_plant_search_name is 'Завод поставки (код + наименование) | Ключ для завода поставки | Расчетное поле LE.001031';
comment on column dm.transportation_external_location_metal_stock.country_of_remote_warehouse_name is 'Страна удаленного склада (наименование) | Страна склада или терминала хранения | Расчетное поле LE.001060';
comment on column dm.transportation_external_location_metal_stock.receiving_plant_code is 'Завод продажной поставки (код) | Системный код завода продажной поставки | storage_sales_bundles_amount.receiving_plant_code LE.001029';
comment on column dm.transportation_external_location_metal_stock.sales_delivery_code is 'Если поставка разделена - то разделенная поставка.
Если нет - то Исходная поставка (код) | Если поставка разделена - то разделенная поставка.
Если нет - то Исходная поставка | storage_sales_bundles_amount.sales_delivery_code LE.001005';
comment on column dm.transportation_external_location_metal_stock.transportation_inbound_delivery_code is 'Техническая поставка транспортировки этапа прибытия ГП на склад (код) | Техническая поставка транспортировки этапа прибытия ГП на склад | storage_sales_bundles_amount.transportation_inbound_delivery_code LE.001007';
comment on column dm.transportation_external_location_metal_stock.delivery_for_storage_calculation_code is 'Поставка, на которой выполняется расчет (код) | поставка, на которой выполняется расчет | storage_sales_bundles_amount.delivery_for_storage_calculation_code LE.001016';
comment on column dm.transportation_external_location_metal_stock.transportation_inbound_delivery_position_code is 'Позиция технической поставки транспортировки этапа прибытия ГП на склад (код) | Номер позиции технической поставки транспортировки этапа прибытия ГП на склад | storage_sales_bundles_amount.transportation_inbound_delivery_position_code LE.001008';
comment on column dm.transportation_external_location_metal_stock.delivery_position_for_storage_calculation_code is 'Позиция поставки, на которой выполняется расчет (код) | позиция поставки, на которой выполняется расчет | storage_sales_bundles_amount.delivery_position_for_storage_calculation_code LE.001017';
comment on column dm.transportation_external_location_metal_stock.forwarder_code is 'Экспедитор (код) | Системный код экспедитора,  который примет груз, после его прибытия с завода в конечную точку по жд или авто, и который  подготовит документы для экспорта.  | storage_sales_bundles_amount.forwarder_code LE.001040';
comment on column dm.transportation_external_location_metal_stock.storage_cost_calculation_type_name is 'Регион хранения и логика, применяемая для расчета стоимости хранения (наименование) | Регион хранения и логика, применяемая для расчета стоимости хранения | storage_sales_bundles_amount.storage_cost_calculation_type_name LE.001064';
comment on column dm.transportation_external_location_metal_stock.transport_departure_hub_code is 'Начальный узел поставки (код) | Системный код начального узла поставки | storage_sales_bundles_amount.transport_departure_hub_code LE.001021';
comment on column dm.transportation_external_location_metal_stock.transport_departure_hub_name is 'Начальный узел поставки (наименование) | Наименование начального узла поставки | transport_hub_texts.transport_hub_name LE.001022';
comment on column dm.transportation_external_location_metal_stock.transport_destination_hub_code is 'Конечный узел поставки (код) | Системный код конечного узла поставки | storage_sales_bundles_amount.transport_destination_hub_code LE.001023';
comment on column dm.transportation_external_location_metal_stock.transport_destination_hub_name is 'Конечный узел поставки (наименование) | Наименование конечного узла поставки | transport_hub_texts.transport_hub_name LE.001024';
comment on column dm.transportation_external_location_metal_stock.transportation_outbound_delivery_code is 'Техническая поставка транспортировки этапа убытия ГП со склада (код) | Техническая поставка транспортировки этапа убытия ГП со склада | storage_sales_bundles_amount.transportation_outbound_delivery_code LE.001009';
comment on column dm.transportation_external_location_metal_stock.transportation_outbound_delivery_position_code is 'Позиция технической поставки транспортировки этапа убытия ГП со склада (код) | Номер позиции технической поставки транспортировки этапа убытия ГП со склада | storage_sales_bundles_amount.transportation_outbound_delivery_position_code LE.001010';
comment on column dm.transportation_external_location_metal_stock.is_final_transportation_stage_code is 'Метка "Последний этап" (код) | Признак, что текущий этап перевозки является последним в логистической цепочке | storage_sales_bundles_amount.is_final_transportation_stage_code LE.001025';
comment on column dm.transportation_external_location_metal_stock.transportation_stage_code is 'Этап перевозки (код) | Системный код этапа перевозки | storage_sales_bundles_amount.transportation_stage_code LE.001026';
comment on column dm.transportation_external_location_metal_stock.transportation_stage_name is 'Этап перевозки (наименование) | Наименование этапа перевозки | transportation_stage_texts.transportation_stage_name LE.001027';
comment on column dm.transportation_external_location_metal_stock.transportation_stage_search_name is 'Этап перевозки (код + наименование) | Ключ для этапа перевозки | Расчетное поле LE.001028';
comment on column dm.transportation_external_location_metal_stock.storage_calculation_bundle_quantity is 'Количество пакетов в поставке хранения | Количество пакетов в поставке хранения | storage_sales_bundles_amount.storage_calculation_bundle_quantity LE.001035';
comment on column dm.transportation_external_location_metal_stock.forwarder_name is 'Экспедитор (наименование) | Название экспедитора,  который примет груз, после его прибытия с завода в конечную точку по жд или авто, и который  подготовит документы для экспорта. | counterparty.counterparty_short_name LE.001041';
comment on column dm.transportation_external_location_metal_stock.forwarder_search_name is 'Экспедитор (код + наименование) | Ключ для экспедитора | Расчетное поле LE.001042';
comment on column dm.transportation_external_location_metal_stock.warehouse_code is 'Склад (код) | Системный код склада/терминала, где хранится металл. | storage_sales_bundles_amount.warehouse_code LE.001047';
comment on column dm.transportation_external_location_metal_stock.warehouse_name is 'Склад (наименование) | Системное название склада/терминала, где хранится металл. | transport_hub_texts.transport_hub_name LE.001048';
comment on column dm.transportation_external_location_metal_stock.warehouse_search_name is 'Склад (код + наименование) | Ключ для склада/терминала | Расчетное поле LE.001049';
comment on column dm.transportation_external_location_metal_stock.delivery_in_final_release_code is 'Продажная поставка, которая входит в финальный релиз (код) | Продажная поставка, которая входит в финальный релиз | storage_sales_bundles_amount.delivery_in_final_release_code LE.001053';
comment on column dm.transportation_external_location_metal_stock.dt_final_release is 'Дата оформления финального релиза | Дата оформления финального релиза | storage_sales_bundles_amount.dt_final_release LE.001054';
comment on column dm.transportation_external_location_metal_stock.bill_of_lading_code is 'Группа коносамента (код) | Системный номер коносамента, оформленного в порту РФ/иностранном  порту | storage_sales_bundles_amount.bill_of_lading_code LE.001056';
comment on column dm.transportation_external_location_metal_stock.bill_of_lading_number is 'Номер коносамента | Бумажный номер коносамента, оформленного в порту РФ/иностранном  порту | storage_sales_bundles_amount.bill_of_lading_number LE.001057';
comment on column dm.transportation_external_location_metal_stock.dt_bill_of_lading is 'Дата выпуска коносамента, оформленного в порту РФ/иностранном порту | Дата выпуска коносамента, оформленного в порту РФ/иностранном  порту | storage_sales_bundles_amount.dt_bill_of_lading LE.001058';
comment on column dm.transportation_external_location_metal_stock.incoterms_code is 'Инкотермс (код) | Базис поставки (Инкотермс 1), это правило поставки Инкотермс.  Базис обозначается тремя латинскими буквами, например EXW, CIP, DAP и пр. Инфо берем из клиентского лота, ели его нет то из заявки под план производства | storage_sales_bundles_amount.incoterms_code LE.001062';
comment on column dm.transportation_external_location_metal_stock.storage_cost_special_calculation_type_code is 'Особая логика, применяемая для расчета стоимости хранения конкретным контрагентом (код) | Особая логика, применяемая для расчета стоимости хранения конкретным контрагентом | storage_sales_bundles_amount.storage_cost_special_calculation_type_code LE.001065';
comment on column dm.transportation_external_location_metal_stock.warehouse_storage_area_code is 'Складская зона (код) | Зона хранения металла (зависит от статуса растаможивания) | storage_sales_bundles_amount.warehouse_storage_area_code LE.001073';
comment on column dm.transportation_external_location_metal_stock.warehouse_storage_area_name is 'Складская зона (наименование) | Зона склада (название) | transport_hub_texts.transport_hub_name LE.001074';
comment on column dm.transportation_external_location_metal_stock.warehouse_storage_area_search_name is 'Складская зона (код + наименование) | Зона склада (код + название) | Расчетное поле LE.001075';
comment on column dm.transportation_external_location_metal_stock.plant_code is 'Завод (код) | Завод договора | storage_sales_bundles_amount.plant_code LE.001078';
comment on column dm.transportation_external_location_metal_stock.unit_balance_code is 'Балансовая единица (код) | БЕ договора | storage_sales_bundles_amount.unit_balance_code LE.001077';
comment on column dm.transportation_external_location_metal_stock.creditor_in_shipment_instruction_code is 'Кредитор, который принимает груз на хранение в порту (код) | Код кредитора, который принимает груз на хранение в порту | storage_sales_bundles_amount.creditor_in_shipment_instruction_code LE.001092';
comment on column dm.transportation_external_location_metal_stock.dt_storage_start is 'Дата прихода металла на склад | Дата прихода металла на склад  | storage_sales_bundles_amount.dt_storage_start LE.001070';
comment on column dm.transportation_external_location_metal_stock.dt_shipped_from_warehouse is 'Дата вывоза со склада | Дата вывоза со склада | storage_sales_bundles_amount.dt_shipped_from_warehouse LE.001071';
comment on column dm.transportation_external_location_metal_stock.dt_storage_end is 'Дата вывоза металла со склада либо дата окончания хранения металла за счет Русал (берем то, то наступит раньше) | Дата вывоза металла со склада либо дата окончания хранения металла за счет Русал (берем то, то наступит раньше) | storage_sales_bundles_amount.dt_storage_end LE.001072';
comment on column dm.transportation_external_location_metal_stock.service_number is 'Услуга для поиска стоимостного приложения хранения (код) | Код услуги для поиска стоимостного приложения хранения (сужебное поле) | storage_sales_bundles_amount.service_number LE.001082';
comment on column dm.transportation_external_location_metal_stock.storage_duration_total_calendar_days is 'Количество дней хранения металла всего | количество дней хранения металла всего | storage_sales_bundles_amount.storage_duration_total_calendar_days LE.001086';
comment on column dm.transportation_external_location_metal_stock.shipment_instruction_number is 'Номер инструкции ДСБ | Бумажный номер отгрузочной инструкции | storage_sales_bundles_amount.shipment_instruction_number LE.001043';
comment on column dm.transportation_external_location_metal_stock.dt_for_price_search_in_purchase_contract is 'Дата, на которую производится поиск договора | Дата, на которую производится поиск договора | storage_sales_bundles_amount.dt_for_price_search_in_purchase_contract LE.001076';
comment on column dm.transportation_external_location_metal_stock.purchase_contract_code is 'Договор хранения (код) | Системный номер стоимостного соглашения, в рамках которого оказывается услуга хранения | storage_sales_bundles_amount.purchase_contract_code LE.001079';
comment on column dm.transportation_external_location_metal_stock.purchase_contract_position_code is 'Позиция договора хранения (код) | Позиция стоимостного соглашения, в рамках которого оказывается услуга хранения | storage_sales_bundles_amount.purchase_contract_position_code LE.001080';
comment on column dm.transportation_external_location_metal_stock.purchase_contract_position_currency_code is 'Валюта позиции договора (код) | валюта цены хранения из стоимостного соглашения | storage_sales_bundles_amount.purchase_contract_position_currency_code LE.001081';
comment on column dm.transportation_external_location_metal_stock.service_code is 'Услуга (код) | Код услуги хранения в системе SAP для поиска договора | storage_sales_bundles_amount.service_code LE.001083';
comment on column dm.transportation_external_location_metal_stock.service_name is 'Услуга (наименование) | Улуга (Наименование) | transportation_service_texts.transportation_service_name LE.001084';
comment on column dm.transportation_external_location_metal_stock.service_search_name is 'Услуга (код + наименование) | Услуга (Связка) | Расчетное поле LE.001085';
comment on column dm.transportation_external_location_metal_stock.purchase_contract_position_uom_code is 'Единица измерения позиции договора (код) | Единица измерения цены договора  | storage_sales_bundles_amount.purchase_contract_position_uom_code LE.001091';
comment on column dm.transportation_external_location_metal_stock.creditor_in_shipment_instruction_name is 'Кредитор, который принимает груз на хранение в порту (наименование) | Наименование кредитора, который принимает груз на хранение в порту | address.address_full_name LE.001093';
comment on column dm.transportation_external_location_metal_stock.creditor_in_shipment_instruction_search_name is 'Кредитор, который принимает груз на хранение в порту (код + наименование) | Кредитор из отгрузочной инструкции (код + название) | Расчетное поле LE.001094';
comment on column dm.transportation_external_location_metal_stock.storage_duration_free_by_contract_calendar_days is 'Количество дней бесплатного хранения по договору | Допустимое количество дней бесплатного хранения металла по стоимостному соглашению | storage_sales_bundles_amount.storage_duration_free_by_contract_calendar_days LE.001087';
comment on column dm.transportation_external_location_metal_stock.storage_duration_free_by_delivery_calendar_days is 'Количество дней бесплатного хранения по поставке | Количество дней бесплатного хранения металла | storage_sales_bundles_amount.storage_duration_free_by_delivery_calendar_days LE.001088';
comment on column dm.transportation_external_location_metal_stock.storage_duration_payable_calendar_days is 'Количество дней платного хранения | Количество дней платного хранения металла | storage_sales_bundles_amount.storage_duration_payable_calendar_days LE.001089';
comment on column dm.transportation_external_location_metal_stock.remote_warehouse_code is 'Удаленный склад (код) | Код склада (порта, ж/д станции) , по которому строится оборотная ведомость по складам | storage_sales_bundles_amount.remote_warehouse_code LE.001126';
comment on column dm.transportation_external_location_metal_stock.remote_warehouse_name is 'Удаленный склад (наименование) | Наименование удаленного склада порта, по которому строится оборотная ведомость по ин. складам | transport_hub_texts.transport_hub_name LE.001127';
comment on column dm.transportation_external_location_metal_stock.country_of_remote_warehouse_code is 'Страна удаленного склада (код) | Код страны удаленного склада | address.country_code LE.001129';
comment on column dm.transportation_external_location_metal_stock.dt_transportation_stage_start_p is 'Дата поступления ГП на терминал/склад | Дата поступления ГП на терминал/склад | storage_sales_bundles_amount.dt_transportation_stage_start_p LE.001130';
comment on column dm.transportation_external_location_metal_stock.dt_transportation_stage_start_r is 'Дата ухода ГП из терминала/склада | Дата ухода ГП из терминала/склада | storage_sales_bundles_amount.dt_transportation_stage_start_r LE.001131';
comment on column dm.transportation_external_location_metal_stock.dt_shipment_from_foreign_warehouse is 'Дата отгрузки поставки с иностранного склада | Дата отгрузки поставки с ин. склада | storage_sales_bundles_amount.dt_shipment_from_foreign_warehouse LE.001132';
comment on column dm.transportation_external_location_metal_stock.storage_cost_calculated_amount is 'Расчетная стоимость хранения в долларах США | Расчетная стоимость хранения металла, конвертированная в доллары США | storage_sales_bundles_amount.storage_cost_calculated_amount LE.001090';
comment on column dm.transportation_external_location_metal_stock.storage_cost_calculated_amount_local is 'Расчетная стоимость в валюте договора | Расчетная стоимость хранения металла в валюте договора | storage_sales_bundles_amount.storage_cost_calculated_amount_local LE.001125';
comment on column dm.transportation_external_location_metal_stock.storage_payable_001_030_days_gross_weight is 'Объем платного хранения 01-30 дней, тн брутто | Объем платного хранения тонн брутто за кол-во дней платного хранения от 1 до 30 дней | storage_sales_bundles_amount.storage_payable_001_030_days_gross_weight LE.001095';
comment on column dm.transportation_external_location_metal_stock.storage_payable_031_060_days_gross_weight is 'Объем платного хранения 31-60 дней, тн брутто | Объем платного хранения тонн брутто за кол-во дней платного хранения от 31 до 60 дней | storage_sales_bundles_amount.storage_payable_031_060_days_gross_weight LE.001096';
comment on column dm.transportation_external_location_metal_stock.storage_payable_061_090_days_gross_weight is 'Объем платного хранения 61-90 дней, тн брутто | Объем платного хранения тонн брутто за кол-во дней платного хранения от 61 до 90 дней | storage_sales_bundles_amount.storage_payable_061_090_days_gross_weight LE.001097';
comment on column dm.transportation_external_location_metal_stock.storage_payable_091_180_days_gross_weight is 'Объем платного хранения 91-180 дней, тн брутто | Объем платного хранения тонн брутто за кол-во дней платного хранения от 91 до 180 дней | storage_sales_bundles_amount.storage_payable_091_180_days_gross_weight LE.001098';
comment on column dm.transportation_external_location_metal_stock.storage_payable_181_365_days_gross_weight is 'Объем платного хранения 181-365 дней, тн брутто | Объем платного хранения тонн брутто за кол-во дней платного хранения от 181 до 365 дней | storage_sales_bundles_amount.storage_payable_181_365_days_gross_weight LE.001099';
comment on column dm.transportation_external_location_metal_stock.storage_payable_over_365_days_gross_weight is 'Объем платного хранения свыше 365 дней, тн брутто | Объем платного хранения тонн брутто за кол-во дней платного хранения свыше 365 дней | storage_sales_bundles_amount.storage_payable_over_365_days_gross_weight LE.001100';
comment on column dm.transportation_external_location_metal_stock.is_stored_in_russian_port_code is 'Индикатор: хранение осуществляется на терминале в порту РФ | Если хранение осуществляется на терминале в порту РФ, то признак будет заполнен | storage_sales_bundles_amount.is_stored_in_russian_port_code LE.001123';
comment on column dm.transportation_external_location_metal_stock.type_warehouse_name is 'Тип склада | Тип склада (СВХ, Терминал порта) | Расчетное поле LE.001133';
comment on column dm.transportation_external_location_metal_stock.type_freight_name is 'Тип фрахта | Тип фрахта | Расчетное поле LE.001134';
comment on column dm.transportation_external_location_metal_stock.metal_owner_for_reporting_name is 'Собственник продукции | Наименование оператора-собственника металла. Определяется по заводу поставки хранения. | Расчетное поле LE.001124';
comment on column dm.transportation_external_location_metal_stock.storage_calculated_cost_001_030_amount is 'Расчетная стоимость платного хранения 01-30 дней, в долларах США | Расчетная стоимость платного хранения в валюте договора за кол-во дней платного хранения от 1 до 30 дней | storage_sales_bundles_amount.storage_calculated_cost_001_030_amount LE.001107';
comment on column dm.transportation_external_location_metal_stock.storage_calculated_cost_031_060_amount is 'Расчетная стоимость платного хранения 31-60 дней, в долларах США | Расчетная стоимость платного хранения в валюте договора за кол-во дней платного хранения от 31 до 60 дней | storage_sales_bundles_amount.storage_calculated_cost_031_060_amount LE.001108';
comment on column dm.transportation_external_location_metal_stock.storage_calculated_cost_061_090_amount is 'Расчетная стоимость платного хранения 61-90 дней, в долларах США | Расчетная стоимость платного хранения в валюте договора за кол-во дней платного хранения от 61 до 90 дней | storage_sales_bundles_amount.storage_calculated_cost_061_090_amount LE.001109';
comment on column dm.transportation_external_location_metal_stock.storage_calculated_cost_091_180_amount is 'Расчетная стоимость платного хранения 91-180 дней, в долларах США | Расчетная стоимость платного хранения в валюте договора за кол-во дней платного хранения от 91 до 180 дней | storage_sales_bundles_amount.storage_calculated_cost_091_180_amount LE.001110';
comment on column dm.transportation_external_location_metal_stock.storage_calculated_cost_181_365_amount is 'Расчетная стоимость платного хранения 181-365 дней, в долларах США | Расчетная стоимость платного хранения в валюте договора за кол-во дней платного хранения от 181 до 365 дней | storage_sales_bundles_amount.storage_calculated_cost_181_365_amount LE.001111';
comment on column dm.transportation_external_location_metal_stock.storage_calculated_cost_over_365_amount is 'Расчетная стоимость платного хранения свыше 365 дней, в долларах США | Расчетная стоимость платного хранения в валюте договора за кол-во дней платного хранения свыше 365 дней | storage_sales_bundles_amount.storage_calculated_cost_over_365_amount LE.001112';
comment on column dm.transportation_external_location_metal_stock.metal_in_china_stock_balance_closing_weight is 'Объем металла на конец периода по складу порта Ренан | Объем металла на конец периода по складу порта Ренан | Расчетное поле LE.001063';

CREATE TEMP TABLE adrc
ON COMMIT drop
AS
SELECT
    address_code,
    MIN(country_code) AS country_code
FROM dict_dds.address
GROUP BY address_code
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_hub_geo
ON COMMIT DROP 
AS
SELECT
    th.transport_hub_code,
    a.country_code,
    ct.country_full_name,
    mr.market_region1_name
FROM dict_dds.transport_hub th
LEFT JOIN adrc a
       ON a.address_code = th.address_code
LEFT JOIN dict_dds.country_texts ct
       ON ct.country_code   = a.country_code
      AND ct.language_code  = 'R'
LEFT JOIN dict_dds.country c
       ON c.country_code = a.country_code
LEFT JOIN dict_dds.market_region1_texts mr
       ON mr.market_region1_code = c.market_region1_code
      AND mr.language_code       = 'R'
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_hub_texts_agg
ON COMMIT DROP 
AS
SELECT
    transport_hub_code,
    MAX(CASE WHEN language_code = 'R' THEN transport_hub_name END) AS name_r,
    MAX(CASE WHEN language_code = 'E' THEN transport_hub_name END) AS name_e
FROM dict_dds.transport_hub_texts
GROUP BY transport_hub_code
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_material_texts
ON COMMIT DROP 
AS
SELECT
    material_code,
    MAX(material_name) AS material_name
FROM dict_dds.material_texts
WHERE language_code = 'R'
GROUP BY material_code
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_material_shape
ON COMMIT drop
AS
SELECT
    ms.material_code,
    MAX(mf.material_shape_full_name) AS material_shape_full_name
FROM dict_dds.material_specification ms
JOIN dict_dds.material_shape_texts mf
      ON mf.shape_code    = ms.shape_code
     AND mf.language_code = 'R'
GROUP BY ms.material_code
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_transport_type
ON COMMIT DROP 
AS
SELECT
    transport_transfer_type_code,
    MAX(transport_transfer_type_name) AS transport_transfer_type_name
FROM dict_dds.transport_transfer_type_texts
WHERE language_code = 'R'
GROUP BY transport_transfer_type_code
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_service_texts
ON COMMIT drop
AS
SELECT
    transportation_service_code AS service_code,
    MAX(transportation_service_name) AS transportation_service_name
FROM dict_dds.transportation_service_texts
WHERE language_code = 'R'
GROUP BY transportation_service_code
DISTRIBUTED REPLICATED;


CREATE TEMP TABLE dim_storage_owner
ON COMMIT drop
AS
SELECT
    delivery_code,
    MIN(plant_producer_code) AS plant_code
FROM dds.delivery_document_position
WHERE delivery_position_line_item_code = '000010'
GROUP BY delivery_code
DISTRIBUTED REPLICATED;



INSERT INTO   dm.transportation_external_location_metal_stock (
    sales_bundle_code,
    plant_producer_delivery_code,
    plant_producer_delivery_position_code,
    initial_delivery_code,
    initial_delivery_position_code,
    sales_delivery_position_code,
    material_code,
    material_name,
    material_search_name,
    dt_shipment,
    railcar_code,
    transport_bill_code,
    uni,
    material_shape_code,
    material_shape_name,
    material_shape_search_name,
    port_of_discharge_code,
    port_of_discharge_name,
    dt_arrival_to_russian_port,
    dt_storage_end_in_release,
    port_of_discharge_search_name,
    transport_type_code,
    transport_type_name,
    transport_type_search_name,
    etsng_code,
    etsng_name,
    etsng_search_name,
    dt_report,
    sales_bundle_net_weight,
    sales_bundle_gross_weight,
    batch_code,
    dt_arrival,
    region_of_remote_warehouse_name,
    receiving_plant_name,
    receiving_plant_search_name,
    country_of_remote_warehouse_name,
    receiving_plant_code,
    sales_delivery_code,
    transportation_inbound_delivery_code,
    delivery_for_storage_calculation_code,
    transportation_inbound_delivery_position_code,
    delivery_position_for_storage_calculation_code,
    forwarder_code,
    storage_cost_calculation_type_name,
    transport_departure_hub_code,
    transport_departure_hub_name,
    transport_destination_hub_code,
    transport_destination_hub_name,
    transportation_outbound_delivery_code,
    transportation_outbound_delivery_position_code,
    is_final_transportation_stage_code,
    transportation_stage_code,
    transportation_stage_name,
    transportation_stage_search_name,
    storage_calculation_bundle_quantity,
    forwarder_name,
    forwarder_search_name,
    warehouse_code,
    warehouse_name,
    warehouse_search_name,
    delivery_in_final_release_code,
    dt_final_release,
    bill_of_lading_code,
    bill_of_lading_number,
    dt_bill_of_lading,
    incoterms_code,
    storage_cost_special_calculation_type_code,
    warehouse_storage_area_code,
    warehouse_storage_area_name,
    warehouse_storage_area_search_name,
    plant_code,
    unit_balance_code,
    creditor_in_shipment_instruction_code,
    dt_storage_start,
    dt_shipped_from_warehouse,
    dt_storage_end,
    service_number,
    storage_duration_total_calendar_days,
    shipment_instruction_number,
    dt_for_price_search_in_purchase_contract,
    purchase_contract_code,
    purchase_contract_position_code,
    purchase_contract_position_currency_code,
    service_code,
    service_name,
    service_search_name,
    purchase_contract_position_uom_code,
    creditor_in_shipment_instruction_name,
    creditor_in_shipment_instruction_search_name,
    storage_duration_free_by_contract_calendar_days,
    storage_duration_free_by_delivery_calendar_days,
    storage_duration_payable_calendar_days,
    remote_warehouse_code,
    remote_warehouse_name,
    country_of_remote_warehouse_code,
    dt_transportation_stage_start_p,
    dt_transportation_stage_start_r,
    dt_shipment_from_foreign_warehouse,
    storage_cost_calculated_amount,
    storage_cost_calculated_amount_local,
    storage_payable_001_030_days_gross_weight,
    storage_payable_031_060_days_gross_weight,
    storage_payable_061_090_days_gross_weight,
    storage_payable_091_180_days_gross_weight,
    storage_payable_181_365_days_gross_weight,
    storage_payable_over_365_days_gross_weight,
    is_stored_in_russian_port_code,
    type_warehouse_name,
    type_freight_name,
    metal_owner_for_reporting_name,
    storage_calculated_cost_001_030_amount,
    storage_calculated_cost_031_060_amount,
    storage_calculated_cost_061_090_amount,
    storage_calculated_cost_091_180_amount,
    storage_calculated_cost_181_365_amount,
    storage_calculated_cost_over_365_amount,
    metal_in_china_stock_balance_closing_weight
)
SELECT
    base.sales_bundle_code,
    base.plant_producer_delivery_code,
    base.plant_producer_delivery_position_code,
    base.initial_delivery_code,
    '10',
    '10',

    base.material_code,
    mat.material_name,
    base.material_code || '-' || mat.material_name,

    base.dt_shipment,
    base.railcar_code,
    base.transport_bill_code,
    base.uni,

    base.material_shape_code,
    dms.material_shape_full_name,
    base.material_shape_code || '-' || dms.material_shape_full_name,

    base.port_of_discharge_code,
    COALESCE(ht_port.name_e, ht_port.name_r),
    base.dt_arrival_to_russian_port,
    base.dt_storage_end_in_release,
    base.port_of_discharge_code || '-' || COALESCE(ht_port.name_e, ht_port.name_r),

    base.transport_type_code,
    dtt.transport_transfer_type_name,
    base.transport_type_code || '-' || dtt.transport_transfer_type_name,

    base.etsng_code,
    ette.etsng_name,
    base.etsng_code || '-' || ette.etsng_name,

    base.dt_report,
    base.sales_bundle_net_weight,
    base.sales_bundle_gross_weight,
    base.batch_code,
    base.dt_arrival,

    CASE
        WHEN hub_remote.market_region1_name = 'Турция' THEN 'Западная Азия'
        WHEN hub_remote.market_region1_name = 'Средний Восток и Афр' THEN 'Ближний Восток'
        WHEN hub_remote.market_region1_name IN ('Азия','Китай') THEN 'Восточная Азия'
        ELSE hub_remote.market_region1_name
    END,

    pas.plant_short_name || ' ' || pas.plant_full_name,
    base.receiving_plant_code || '-' || pas.plant_short_name || ' ' || pas.plant_full_name,

    CASE
        WHEN hub_remote.country_full_name = 'Корея, республика' THEN 'Южная Корея'
        WHEN hub_remote.country_full_name = 'Тайвань (Китай)' THEN 'Тайвань'
        ELSE hub_remote.country_full_name
    END,

    base.receiving_plant_code,
    base.sales_delivery_code,
    base.transportation_inbound_delivery_code,
    base.delivery_for_storage_calculation_code,
    base.transportation_inbound_delivery_position_code,
    base.delivery_position_for_storage_calculation_code,
    base.forwarder_code,
    base.storage_cost_calculation_type_name,

    base.transport_departure_hub_code,
    COALESCE(ht_dep.name_r, ht_dep.name_e),
    base.transport_destination_hub_code,
    COALESCE(ht_dest.name_r, ht_dest.name_e),

    base.transportation_outbound_delivery_code,
    base.transportation_outbound_delivery_position_code,
    base.is_final_transportation_stage_code,
    base.transportation_stage_code,

    CASE
        WHEN base.storage_cost_calculation_type_name IN ('Логика Азия','Логика Европа','Логика СВХ')
            THEN trst.transportation_stage_name
    END,
    CASE
        WHEN base.storage_cost_calculation_type_name IN ('Логика Азия','Логика Европа','Логика СВХ')
            THEN base.transportation_stage_code || '-' || trst.transportation_stage_name
    END,

    base.storage_calculation_bundle_quantity,


    COALESCE(
        CASE
            WHEN base.storage_cost_calculation_type_name
                 IN ('Логика Азия','Логика Европа','Логика СВХ')
                THEN counter_forwarder.counterparty_short_name
        END,
        'Не определено'
    ),
    COALESCE(
        CASE
            WHEN base.storage_cost_calculation_type_name
                 IN ('Логика Азия','Логика Европа','Логика СВХ')
                THEN base.forwarder_code || '-' || counter_forwarder.counterparty_short_name
        END,
        'Не определено'
    ),

    base.warehouse_code,
    CASE
        WHEN hub_wh.country_full_name = 'Россия'
            THEN COALESCE(ht_wh.name_r, ht_wh.name_e)
        ELSE COALESCE(ht_wh.name_e, ht_wh.name_r)
    END,
    base.warehouse_code || '-' ||
    CASE
        WHEN hub_wh.country_full_name = 'Россия'
            THEN COALESCE(ht_wh.name_r, ht_wh.name_e)
        ELSE COALESCE(ht_wh.name_e, ht_wh.name_r)
    END,

    base.delivery_in_final_release_code,
    base.dt_final_release,
    base.bill_of_lading_code,
    base.bill_of_lading_number,
    base.dt_bill_of_lading,

    base.incoterms_code,
    base.storage_cost_special_calculation_type_code,

    base.warehouse_storage_area_code,
    COALESCE(ht_area.name_r, ht_area.name_e),
    base.warehouse_storage_area_code || '-' || COALESCE(ht_area.name_r, ht_area.name_e),

    base.plant_code,
    base.unit_balance_code,
    base.creditor_in_shipment_instruction_code,

    base.dt_storage_start,
    base.dt_shipped_from_warehouse,
    base.dt_storage_end,

    base.service_number,
    base.storage_duration_total_calendar_days,
    base.shipment_instruction_number,
    base.dt_for_price_search_in_purchase_contract,
    base.purchase_contract_code,
    base.purchase_contract_position_code,
    base.purchase_contract_position_currency_code,

    base.service_code,
    svc.transportation_service_name,
    base.service_code || '-' || svc.transportation_service_name,

    base.purchase_contract_position_uom_code,

    addr_8.address_full_name,
    base.creditor_in_shipment_instruction_code || '-' || addr_8.address_full_name,

    base.storage_duration_free_by_contract_calendar_days,
    base.storage_duration_free_by_delivery_calendar_days,
    base.storage_duration_payable_calendar_days,

    base.remote_warehouse_code,
   trht_remote.transport_hub_name AS remote_warehouse_name,
    hub_remote.country_code,

    base.dt_transportation_stage_start_p,
    base.dt_transportation_stage_start_r,
    base.dt_shipment_from_foreign_warehouse,

    base.storage_cost_calculated_amount,
    base.storage_cost_calculated_amount_local,

    base.storage_payable_001_030_days_gross_weight,
    base.storage_payable_031_060_days_gross_weight,
    base.storage_payable_061_090_days_gross_weight,
    base.storage_payable_091_180_days_gross_weight,
    base.storage_payable_181_365_days_gross_weight,
    base.storage_payable_over_365_days_gross_weight,

    base.is_stored_in_russian_port_code,

    CASE
        WHEN base.storage_cost_calculation_type_name IN ('Логика РФ-контейнеры','Логика РФ-балк')
            THEN 'Терминал порта'
        WHEN base.storage_cost_calculation_type_name = 'Логика СВХ'
            THEN 'Склад СВХ'
        ELSE 'Не определено'
    END,
    CASE
        WHEN base.storage_cost_calculation_type_name = 'Логика РФ-контейнеры' THEN 'Контейнеры'
        WHEN base.storage_cost_calculation_type_name = 'Логика РФ-балк' THEN 'Балк'
        ELSE 'Не определено'
    END,

    pas_1124.plant_short_name || ' ' || pas_1124.plant_full_name,

    base.storage_calculated_cost_001_030_amount,
    base.storage_calculated_cost_031_060_amount,
    base.storage_calculated_cost_061_090_amount,
    base.storage_calculated_cost_091_180_amount,
    base.storage_calculated_cost_181_365_amount,
    base.storage_calculated_cost_over_365_amount,

    base.metal_in_china_stock_balance_closing_weight
FROM dm_calc.storage_sales_bundles_amount base
LEFT JOIN dim_material_texts mat ON mat.material_code = base.material_code
LEFT JOIN dim_material_shape dms ON dms.material_code = base.material_code
LEFT JOIN dict_dds.etsng_texts ette ON ette.etsng_code = base.etsng_code AND ette.language_code = 'R'
LEFT JOIN dim_transport_type dtt ON dtt.transport_transfer_type_code = base.transport_type_code
LEFT JOIN dim_service_texts svc ON svc.service_code = base.service_code
LEFT JOIN dict_dds.plant_and_subsidiary pas ON pas.plant_code = base.receiving_plant_code
LEFT JOIN dim_storage_owner so ON so.delivery_code = base.delivery_for_storage_calculation_code
LEFT JOIN dict_dds.plant_and_subsidiary pas_1124 ON pas_1124.plant_code = so.plant_code
LEFT JOIN dim_hub_geo hub_wh ON hub_wh.transport_hub_code = base.warehouse_code
LEFT JOIN dim_hub_geo hub_remote ON hub_remote.transport_hub_code = base.warehouse_code
LEFT JOIN dict_dds.transport_hub trh_remote
       ON trh_remote.transport_hub_code = base.remote_warehouse_code
LEFT JOIN adrc adrc_rw
       ON adrc_rw.address_code = trh_remote.address_code
LEFT JOIN dict_dds.country_texts cotex_rw
       ON cotex_rw.country_code = adrc_rw.country_code
      AND cotex_rw.language_code = 'R'
LEFT JOIN dict_dds.transport_hub_texts trht_remote
       ON trht_remote.transport_hub_code = base.remote_warehouse_code
      AND trht_remote.language_code =
          CASE
              WHEN cotex_rw.country_full_name = 'Россия' THEN 'R'
              ELSE 'E'
          END
LEFT JOIN dim_hub_texts_agg ht_dep ON ht_dep.transport_hub_code = base.transport_departure_hub_code
LEFT JOIN dim_hub_texts_agg ht_dest ON ht_dest.transport_hub_code = base.transport_destination_hub_code
LEFT JOIN dim_hub_texts_agg ht_wh ON ht_wh.transport_hub_code = base.warehouse_code
LEFT JOIN dim_hub_texts_agg ht_area ON ht_area.transport_hub_code = base.warehouse_storage_area_code
LEFT JOIN dim_hub_texts_agg ht_remote ON ht_remote.transport_hub_code = base.remote_warehouse_code
LEFT JOIN dim_hub_texts_agg ht_port ON ht_port.transport_hub_code = base.port_of_discharge_code
LEFT JOIN dict_dds.counterparty counter_forwarder ON counter_forwarder.counterparty_code = base.forwarder_code
LEFT JOIN dict_dds.counterparty counter_creditor ON counter_creditor.counterparty_code = base.creditor_in_shipment_instruction_code
LEFT JOIN dict_dds.address addr_8
    ON addr_8.address_code = counter_creditor.address_code
   AND addr_8.international_display_format_code IS NULL
LEFT JOIN dict_dds.transportation_stage_texts trst
    ON trst.transportation_stage_code = base.transportation_stage_code
   AND trst.language_code = 'R';

value too long for type character varying(30)  (seg5 10.66.229.205:10001 pid=131062)
