drop table if exists dm.sd_sales_main_scm cascade;

create table if not exists dm.sd_sales_main_scm (
	delivery_number_initial varchar(30) NULL,
	delivery_number_sales varchar(30) NULL,
	delivery_number_of_producer_plant varchar(30) NULL,
	batch varchar(30) NULL,
	sales_order_in_shipment varchar(90) NULL,
	plant_producer_code varchar(12) NULL,
	plant_producer_name varchar(90) NULL,
	tsw_location_code varchar(30) NULL,
	tsw_location_name varchar(180) NULL,
	dt_shipment timestamp NULL,
	dt_arrival_by_railway timestamp NULL,
	dt_forwarder timestamp NULL,
	railcar varchar(60) NULL,
	transport_bill varchar(105) NULL,
	railway_platform varchar(36) NULL,
	material_aggr_name varchar(210) NULL,
	material_group_code varchar(27) NULL,
	shipment_market_code varchar(3) NULL,
	shipment_market_name varchar(120) NULL,
	forwarder_code varchar(30) NULL,
	forwarder_name varchar(300) NULL,
	forwarder_contract_code varchar(30) NULL,
	forwarder_contract_name varchar(300) NULL,
	dt_warehouse date NULL,
	transport_type_at_plant_code varchar(12) NULL,
	transport_type_at_plant_name varchar(120) NULL,
	transport_type_after_repackaging_code varchar(12) NULL,
	transport_railcar_type_code varchar(12) NULL,
	transport_railcar_type_name varchar(120) NULL,
	nomination_in_russian_port_code_plan varchar(60) NULL,
	weight_gross numeric(13, 3) NULL,
	weight_net numeric(13, 3) NULL,
	weight_net_with_wirerod numeric(13, 3) NULL,
	station_current varchar(90) NULL,
	station_destination varchar(90) NULL,
	customer_for_reporting_code varchar(30) NULL,
	customer_for_reporting_name varchar(450) NULL,
	contract_name varchar(105) NULL, --переименовано
	quota varchar(18) NULL,
	bill_of_lading_group_code varchar(30) NULL,
	bill_of_lading_number varchar(90) NULL,
	dt_bill_of_lading timestamp NULL,
	bill_of_lading_route varchar(18) NULL,
	port_of_discharge_code varchar(30) NULL,
	port_of_discharge_name varchar(90) NULL,
	nomination_actual varchar(60) NULL,
	bill_of_lading_group_code_in_foreign_port varchar(30) NULL,
	bill_of_lading_in_foreign_port varchar(90) NULL,
	dt_bill_of_lading_in_foreign_port timestamp NULL,
	bill_of_lading_in_foreign_port_nomination varchar(60) NULL,
	bill_of_lading_in_foreign_port_route varchar(18) NULL,
	port_of_loading_in_foreign_port_code varchar(30) NULL,
	port_of_loading_in_foreign_port_name varchar(90) NULL,
	port_of_discharge_in_foreign_port_code varchar(30) NULL,
	port_of_discharge_in_foreign_port_name varchar(90) NULL,
	status varchar(30) NULL,
	status_description varchar(75) NULL,
	dt_sailed_loading_port timestamp NULL,
	dt_arrival_in_port_of_discharge timestamp NULL,
	dt_arrival_in_port_of_discharge_plan timestamp NULL,
	lot_group varchar(30) NULL,
	lot_contract_code varchar(30) NULL,
	lot_customer_code varchar(30) NULL,
	lot_delivery_basis_code varchar(9) NULL,
	lot_delivery_point_name varchar(84) NULL,
	delivery_basis varchar(9) NULL,
	delivery_point_name varchar(84) NULL,
	route_type varchar(6) NULL,
	route_number varchar(51) NULL,
	dt_stamp_railway_bill date NULL,
	dt_plant_arrival date NULL,
	dt_import_export_transfer date NULL,
	seal_number varchar(450) NULL,
	requisite numeric(13, 3) NULL,
	receiving_plant_in_sap_system_code varchar(12) NULL,
	contract_export_number varchar(105) NULL,
	dimensions_unit varchar(60) NULL,
	consignee_code varchar(30) NULL,
	consignee_name varchar(360) NULL,
	end_buyer_for_reporting_code varchar(30) NULL,
	transport_railway_car_type_plan varchar(12) NULL,
	id_railcar varchar(30) NULL,
	shipment_route_code varchar(18) NULL,
	discharge_terminal_code varchar(30) NULL,
	destination_station_code varchar(30) NULL,
	customs_declaration_number varchar(90) NULL,
	dt_customs_declaration timestamp NULL,
	material_specification_name varchar(150) NULL,
	weight_strip numeric(15, 3) NULL,
	weight_wirerod numeric(13, 3) NULL,
	tariff_freight numeric(13, 2) NULL,
	tariff_security numeric(13, 2) NULL,
	quarantine_certificate_number varchar(54) NULL,
	dt_quarantine_certificate date NULL,
	end_user_for_reporting_code varchar(30) NULL,
	end_user_for_reporting_name varchar(420) NULL,
	cargo_package_quantity int8 NULL,
	receiving_warehouse_code varchar(12) NULL,
	plant_owner_code varchar(12) NULL,
	station_of_departure_code varchar(120) NULL,
	instruction_number varchar(30) NULL,
	delivery_number_of_plant_owner varchar(30) NULL,
	dt_first_entry_appeared date NULL,
	shipment_entry_identifier_from_file varchar(48) NULL,
	finish_good_unit_length varchar(30) NULL,
	finish_good_unit_width varchar(30) NULL,
	finish_good_unit_height varchar(30) NULL,
	finish_good_unit_diameter varchar(60) NULL,
	quality_certificate_number varchar(60) NULL,
	delivery_item_of_plant varchar(18) NULL,
	customer_grade_code varchar(30) NULL,
	dt_collection date NULL,
	destination_station_in_shipment_name varchar(120) NULL,
	box_foil varchar(9) NULL,
	pieces int8 NULL,
	transport_capacity numeric(15, 3) NULL,
	weight_uom_code varchar(9) NULL,
	route_plant_code varchar(18) NULL,
	container_after_repacking varchar(60) NULL,
	route_delivery_repacking varchar(18) NULL,
	dt_shipment_plan timestamp NULL,
	distance_remaining int8 NULL,
	sales_order varchar(18) NULL,
	buyer_plan_code varchar(30) NULL,
	port_of_discharge_plan_code varchar(30) NULL,
	port_of_discharge_plan_name varchar(90) NULL,
	customer_special_requirement varchar(150) NULL,
	dt_discharge_in_foreign_port date NULL,
	dt_discharge_in_second_foreign_port date NULL,
	dt_arrival_in_second_port_of_discharge timestamp NULL,
	delivery_notice_group_code varchar(30) NULL,
	dt_delivery_notice date NULL,
	delivery_notice_number varchar(90) NULL,
	vessel_plan_name varchar(120) NULL,
	vessel_plan_code varchar(30) NULL,
	voyage_number_plan varchar(54) NULL,
	vessel_actual_code varchar(30) NULL,
	vessel_actual_name varchar(120) NULL,
	voyage_number_actual varchar(54) NULL,
	voyage_number_in_foreign_port_actual varchar(54) NULL,
	vessel_in_foreign_port_actual_code varchar(30) NULL,
	vessel_in_foreign_port_actual_name varchar(120) NULL,
	material_code varchar(54) NULL,
	customer_grade_name varchar(90) NULL,
	grade_name varchar(90) NULL,
	dt_sales_order_delivery_actual date NULL,
	contract_plan_code varchar(30) NULL,
	contract_plan_name varchar(300) NULL,
	dt_delivery_deadline timestamp NULL,
	shipment_period_preferred varchar(90) NULL,
	uni varchar(180) NULL,
	uni_in_shipment varchar(180) NULL,
	vessel_imo varchar(21) NULL,
	vessel_mmsi varchar(30) NULL,
	geo_latitude numeric NULL,
	geo_longitude numeric NULL,
	dt_arrival_in_second_port_of_discharge_plan timestamp NULL,
	pb_number varchar(105) NULL,
	is_plan_or_actual varchar(3) NULL,
	is_plan_or_actual_al2all varchar(3) NULL,
	status_al2all varchar(150) NULL,
	dt_expected_delivery timestamp NULL,
	quantity_shipped numeric(13, 3) NULL,
	quantity_ordered numeric(15, 3) NULL,
	invoice_provisional_number varchar(90) NULL,
	release_group_code varchar(30) NULL,
	release_group_name varchar(90) NULL,
	invoice_final_number varchar(90) NULL,
	pledge_in_document_number varchar(90) NULL,
	pledge_in_bank_code varchar(420) NULL,
	dt_pledge_in timestamp NULL,
	production_order varchar(90) NULL,
	dt_storage_start_in_foreign_port timestamp NULL,
	dt_storage_end_in_foreign_port timestamp NULL,
	dt_storage_start_in_second_foreign_warehouse timestamp NULL,
	dt_storage_end_in_second_foreign_warehouse date NULL,
	sales_contract_code varchar(30) NULL,
	frame_contract_code varchar(54) NULL,
	material_name varchar(120) null,
	dt_realization_forecast date null, 
    realization_reason_document varchar(30) NULL, 
    export_organization_name varchar(300) NULL, 
    material_shape_name_full varchar(90) NULL,
    buyer_incassa_extended_name varchar(450) NULL,
    export_organization_code varchar(30) null,
    delivery_split_reason_name varchar(180) null,
    country_of_discharge_port_code varchar(9) NULL,
    country_of_discharge_port_name varchar(45) NULL,
    region_of_destination_port_code varchar(30) NULL,
    region_of_destination_port_name varchar(60) null,
    contract_type_code varchar(12) NULL,
    delivery_number_outbound varchar(30) null,
    dt_release_material timestamp NULL,
    release_material_status_code varchar(3) null,
    dt_updated timestamp NULL, --Дата и время последнего изменения на источнике
    delivery_split_reason_code varchar(30) NULL,
    contract_type varchar(60) null, --Вид контракта
    dt_ownership_transfer date null,
    dt_prepared_for_realization date NULL,
	port_of_discharge_for_reporting_code varchar(90) NULL,
    port_of_destination_name varchar(90) NULL,
    delivery_instruction_code varchar(30) NULL,
    incoterms_plan_code varchar(9) NULL,
    incoterms_location_plan_code varchar(84) NULL,
    finish_good_group_code varchar(90) NULL,
    delivery_country_incoterms_code varchar(9) NULL,
    dt_etd date null,
    dt_expected_bill_of_lading date null,
	external_contract_in_lot_number varchar(35) null,
	dt_transfer_from_consignment_to_customer date NULL,
	dt_final_release date NULL,
	is_shipped_via_overseas_warehouse varchar(3) NULL,
	dt_forwarder_discharge_invoice_or_cmr_documented date NULL,
	is_shipped_via_overseas_second_foreign_warehouse varchar(3) NULL,
	second_foreign_port_of_discharge_location_code varchar(30) NULL,
	dt_arrived_via_ul_system date NULL,
	dt_repacked date NULL,
	warehouse_shipment_type_name varchar(90) NULL,
	warehouse_gross_weight varchar(17) NULL,
	railway_movement_status_name varchar(30) NULL,
	business_location_sap_precalc_name varchar(150) NULL,
	second_foreign_port_of_discharge_plan_code varchar(10) NULL,
	second_foreign_port_of_discharge_plan_name varchar(90) NULL,
	foreign_port_of_discharge_location_code varchar(150) NULL,
	forwarder_instruction_code varchar(30) NULL,
	shipment_type_for_reporting_name varchar(12) NULL,
	sales_team_code varchar(10) NULL,									-- Сбытовая команда (код) SD.000650
	sales_team_name varchar(20) NULL,									-- Сбытовая команда SD.000651
	pb1_number varchar(35) NULL,										-- Номер PB 1 SD.000592
	pb2_number varchar(35) NULL,										-- Номер PB 2 SD.000593
	pb3_number varchar(35) NULL,										-- Номер PB 3 SD.000594
	pb1_warehouse_name varchar(30) NULL,								-- Склад PB 1 SD.000595
	pb2_warehouse_name varchar(30) NULL,								-- Склад PB 2 SD.000596
	pb3_warehouse_name varchar(30) NULL,								-- Склад PB 3 SD.000597
	buyer_agent_code varchar(10) NULL,									-- Trading company (код) SD.000703
	buyer_agent_name varchar(35) NULL,									-- Trading company SD.000704
	bis_license_number varchar(30) NULL,								-- № лицензии BIS SD.000729
	dislocation_id varchar(10) NULL,									-- ID_LEDISLOC	SD.000689
	disclocation_border_cross_railroad_code varchar(7) NULL,			-- Дорога сдачи (код) SD.000690
	disclocation_border_cross_railroad_name varchar(50) NULL,			-- Дорога сдачи SD.000691
	dislocation_railcar_operation_code varchar(2) NULL,					-- Код операции SD.000692
	dislocation_railcar_operation_name varchar(80) NULL,				-- Операции SD.000693
	dislocation_railcar_operation_short_name varchar(4) NULL,			-- Краткое название операции SD.000694
	dt_dislocation_railcar_operation date NULL,							-- Дата операции SD.000695
	dt_train_departure date NULL,										-- Дата начала рейса SD.000696
	dt_train_scheduled_arrival date NULL,	 							-- Плановая дата прибытия по ЖД (с фактом) SD.000697
	tnved_code varchar(17) NULL,										-- Код товара ТНВЭД SD.000699
	cargo_arrangement_scheme_registration_code varchar(10) NULL,		-- SD.001049 "Рег. № схемы погрузки"
	dt_cargo_arrangement_scheme date NULL,								-- SD.001050 "Дата схем погрузки"
	cargo_arrangement_scheme_name varchar(40) NULL,						-- SD.001051 "№ схемы погрузки"
    sales_request_created_by varchar null,  -- Автор заказа ЦК из заявки
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
) 
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (delivery_number_sales, batch);


comment on table dm.sd_sales_main_scm is 'Витрина sd_sales_main_scm';
comment on column dm.sd_sales_main_scm.delivery_number_initial is 'Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах | dm_calc.sd_sales_main_scm.VBELN_exp01';
comment on column dm.sd_sales_main_scm.delivery_number_sales is 'Продажная поставка | Если поставка разделена, то деленная поставка, если нет, то Исходная поставка. Если отгрузка через агента (РТД) - выводится поставка завода производителя | dm_calc.sd_sales_main_scm.VBELN_P_exp01';
comment on column dm.sd_sales_main_scm.delivery_number_of_producer_plant is 'Номер поставки завода производителя | Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе | dm_calc.sd_sales_main_scm.VBELN_LF_exp01';
comment on column dm.sd_sales_main_scm.batch is 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков. | dm_calc.sd_sales_main_scm.CHARG_exp01';
comment on column dm.sd_sales_main_scm.sales_order_in_shipment is 'Заказ ЦК в отгрузке | № заказа центральной компании (заявки) под план производства. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. Изначально заказы ЦК вносятся в тразакции ZSD2882M-Регистрация заявок клиентов.  Если отгрузка не выполняется по внешнему номеру (вносится вручную) - то Заказ ЦК в отгрузке = Заказ ЦК | sales_batch_delivery.sales_order_in_shipment';
comment on column dm.sd_sales_main_scm.plant_producer_code is 'Завод производитель (код) | Код завода производителя | sales_batch_delivery.plant_producer_code';
comment on column dm.sd_sales_main_scm.plant_producer_name is 'Завод | Название завода производителя | sales_batch_delivery.plant_name';
comment on column dm.sd_sales_main_scm.tsw_location_code is 'Порт погрузки (код) | Системный номер  порта погрузки. Например, RTI-ZARUBI | dm_calc.sd_sales_main_scm.LOCID_exp01';
comment on column dm.sd_sales_main_scm.tsw_location_name is 'Порт погрузки | Название порта погрузки. Например, ZARUBINO | location_sales.location_name';
comment on column dm.sd_sales_main_scm.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sd_sales_main_scm.DATEOT_exp01';
comment on column dm.sd_sales_main_scm.dt_arrival_by_railway is 'Дата прибытия по ЖД | Дата прибытия вагона по железной дороге на конечную станцию | dm_calc.sd_sales_main_scm.DATAPRZD_exp01';
comment on column dm.sd_sales_main_scm.dt_forwarder is 'Дата экспедитора | Дата, когда экспедитор принял груз на склад, и подготовил документы для экспорта - готовность к вывозу | dm_calc.sd_sales_main_scm.DATAPREK_exp01';
comment on column dm.sd_sales_main_scm.railcar is 'Вагон | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя. | sales_batch_delivery.railcar_code';
comment on column dm.sd_sales_main_scm.transport_bill is 'Накладная | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя | dm_calc.sd_sales_main_scm.NAKLADN_exp01';
comment on column dm.sd_sales_main_scm.railway_platform is 'Платформа | Номер платформы, на которой передвигается контейнер, по  жд  от Завода производителя. | sales_batch_delivery.railway_platform_code';
comment on column dm.sd_sales_main_scm.material_aggr_name is 'Материал | Код признака «Материал». Применяется для готовой алюминиевой продукции. Например, для кода материала APT0006ING0045, код признака Материл = COMMODITY | material_specification.material_subgroup_code';
comment on column dm.sd_sales_main_scm.material_group_code is 'Группа материалов | Группа материалов. Например, для кода материала APT0006ING0045, код Группа материалов = A02-Алюминий первичный АТЧ, раскисленный. | material.material_group_code';
comment on column dm.sd_sales_main_scm.shipment_market_code is 'Рынок в отгрузке (код) | Код рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | sales_batch_delivery.market_in_shipment_code';
comment on column dm.sd_sales_main_scm.shipment_market_name is 'Рынок в отгрузке | Название рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | sales_market_in_shipment_texts.market_in_shipment_name';
comment on column dm.sd_sales_main_scm.forwarder_code is 'Экспедитор (код) | Системный код экспедитора,  который примет груз, после его прибытия с завода в конечную точку по жд или авто, и который  подготовит документы для экспорта.  | dm_calc.sd_sales_main_scm.EXPEDID_exp01';
comment on column dm.sd_sales_main_scm.forwarder_name is 'Экспедитор | Название экспедитора,  который примет груз, после его прибытия с завода в конечную точку по жд или авто, и который  подготовит документы для экспорта. | dm_calc.sd_sales_main_scm.EXPEDID_TXT_exp01';
comment on column dm.sd_sales_main_scm.forwarder_contract_code is 'Экспедитор Договорной (код) | Системный код экпедитора,  это тот с кем заключен договор экспедирования груза. Заполняется заводом производителем при оформлении отгрузки металла с завода до конечной точки. | sales_batch_delivery.forwarder_in_contract_code';
comment on column dm.sd_sales_main_scm.forwarder_contract_name is 'Экспедитор Договорной | Название экпедитора,  это тот с кем заключен договор экспедирования груза. Заполняется заводом производителем при оформлении отгрузки металла с завода до конечной точки. | counterparty.counterparty_short_name';
comment on column dm.sd_sales_main_scm.dt_warehouse is 'Дата склада | Дата прибытия на склад порта, когда экспедитор принял груз на склад | sales_delivery.dt_warehouse';
comment on column dm.sd_sales_main_scm.transport_type_at_plant_code is 'Тип вагона на заводе(код) | Системный код типа вагона, указанный в исходной поставке или графике отгрузке на заводе производителе | dm_calc.sd_sales_main_scm.SDABW_WH_exp01';
comment on column dm.sd_sales_main_scm.transport_type_at_plant_name is 'Тип вагона на заводе | Название типа вагона, указанный в исходной поставке или графике отгрузке на заводе производителе | transport_transfer_type_texts.transport_transfer_type_name';
comment on column dm.sd_sales_main_scm.transport_type_after_repackaging_code is 'Тип ПС после перетарки | Тип транспортного средства после перегрузки металла на другое транспортное средство. Заполняется, только если была перетарка. Например, метал ехал сначала на ж\д, после перегрузили в морской контейнер. | dm_calc.sd_sales_main_scm.SDABW_PERETARKA_exp02';
comment on column dm.sd_sales_main_scm.transport_railcar_type_code is 'Тип вагона (код) | Код типа вагона на текущий момент.  Заполняется по следующему алгоритму:
= «Тип ПС после перетарки», если значение не пустое. Иначе = Тип вагона на заводе(код) | dm_calc.sd_sales_main_scm.SDABW_exp02';
comment on column dm.sd_sales_main_scm.transport_railcar_type_name is 'Тип вагона | Название  типа вагона на текущий момент.  Заполняется по следующему алгоритму:
= «Тип ПС после перетарки», если значение не пустое. Иначе = Тип вагона на заводе | transport_transfer_type_texts.transport_transfer_type_name';
comment on column dm.sd_sales_main_scm.nomination_in_russian_port_code_plan is 'Номинация РФ | Определеется по следующему алгоритму:
Для не  Морских контейнеров («Тип вагона (код)» не равному TL04 -Морской контейнер)  берем Номинацию Инструкции ДСБ, если  пусто, то берем Номинацию  из таблицы распределения.
Для  Морских контейнеров  ( «Тип вагона (код)» равен  TL04 -Морской контейнер) берем номинацию из  данных  портового экспедитора (заполняем на основании загрузочного файла Excpected) , инфо получаем по следующим значениям:
Если не заполнено поле  Контейнер после перетарки, т.е. не было перетарки, то инфо получаем по 
•  «Заказ ЦК в отгрузке»
•  «Вагон»
•  «Накладная»
•  «Дата отгрузки»
Если  заполнено поле  Контейнер после перетарки, т.е. была перетарка, то инфо получаем по 
• «Заказ ЦК в отгрузке»
•«Контейнер после перетарки»
Если получили пустые значения, то  берем Номинацию Инструкции ДС, при условии, что у нее есть дата Sailed L.Port, если этой даты нет, то берем Номинацию  из таблицы распределения | dm_calc.sd_sales_main_scm.NOMTK_RA_exp01';
comment on column dm.sd_sales_main_scm.weight_gross is 'Вес брутто | Вес брутто | dm_calc.sd_sales_main_scm.BTGEW_exp02';
comment on column dm.sd_sales_main_scm.weight_net is 'Вес нетто | Вес нетто | dm_calc.sd_sales_main_scm.LFIMG_exp02';
comment on column dm.sd_sales_main_scm.weight_net_with_wirerod is 'Вес Н&K | Вес нетто + катанки | dm_calc.sd_sales_main_scm.BRGEW_exp02';
comment on column dm.sd_sales_main_scm.station_current is 'Текущая станция | Заполняется только для ж\д отгрузки.  Если «Дата прибытия по ЖД» заполнено , то выводим  «ПРИБЫЛ». Если вагон находится в движении, то указываем текущую  станцию из Дислокации вагонов. | dm_calc.sd_sales_main_scm.KNOTE_CURR_TXT_exp04';
comment on column dm.sd_sales_main_scm.station_destination is 'Станция назначения | Конечная точка доставки по ж\д, инфо выводится из конечного узла Маршрута завода | dm_calc.sd_sales_main_scm.STATIONNC_TXT_exp01';
comment on column dm.sd_sales_main_scm.customer_for_reporting_code is 'Покупатель  (код)| Системный код покупателя из клиентского лота, если его нет то Плановый покупатель из заявки под план производства.  | dm_calc.sd_sales_main_scm.KUNNR_exp02';
comment on column dm.sd_sales_main_scm.customer_for_reporting_name is 'Покупатель | Название покупателя из клиентского лота, если его нет, то Плановый покупатель из заявки под план производства.  | counterparty.counterparty_short_name';
comment on column dm.sd_sales_main_scm.contract_name is 'Контракт | Номер контракта из клиентского лота, если его нет, то  Плановый контракт  из заявки под план производства | dm_calc.sd_sales_main_scm.BSTKD_exp02';
comment on column dm.sd_sales_main_scm.quota is 'Квота | Квота из клиентского лота, если его нет, то Квота  из заявки под план производства | dm_calc.sd_sales_main_scm.QUOTA_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_group_code is 'Группа коносамента | Системный номер коносамента из РФ | dm_calc.sd_sales_main_scm.SAMMG_Y_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_number is 'Номер коносамента | Номер коносамента из РФ, номер на бумажном носителе. Документ, который используют в водных перевозках. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sd_sales_main_scm.VTEXT_Y_exp02';
comment on column dm.sd_sales_main_scm.dt_bill_of_lading is 'Дата коносамента | Дата коносамента из РФ. Документ, который используют в водных перевозках из российских портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sd_sales_main_scm.LDDAT_Y_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_route is 'Маршрут коносамента | Системный номер маршрута коносамента из РФ, который содерит в себе   информацию  о порте погрузки и порте выгрузки | dm_calc.sd_sales_main_scm.ROUTE_Y_exp02';
comment on column dm.sd_sales_main_scm.port_of_discharge_code is 'Порт выгрузки (код) | Системный номер порта выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, P000000034 | transport_route.transport_route_destination_hub_code';
comment on column dm.sd_sales_main_scm.port_of_discharge_name is 'Порт выгрузки | Порт выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, BUSAN | transport_hub.transport_hub_name_eng';
comment on column dm.sd_sales_main_scm.nomination_actual is 'Номинация | Номинация (номер документа) из коносамента из РФ, если пусто то это номер Номинации  поручения. | dm_calc.sd_sales_main_scm.NOMTK_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_group_code_in_foreign_port is 'Группа коносамента в ин.порту | Номинация,  это процесс назначения судна на выполнение определенного вида работ. Этот процесс происходит между клиентом и агентом, который занимается организацией перевозки грузов. Номинация сообщает владельцу или управляющей компании судна о предстоящих заданиях и условиях работы. В одну номинацию могут быть включены несколько коносаментов | dm_calc.sd_sales_main_scm.SAMMG_KOP_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_in_foreign_port is 'Коносамент в ин.порту | Номер коносамента в ин. порту, номер на бумажном носителе. Документ, который используют в водных перевозках из иностранных портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sd_sales_main_scm.VTEXT_KOP_exp02';
comment on column dm.sd_sales_main_scm.dt_bill_of_lading_in_foreign_port is 'Дата коносамента в ин.порту | Дата коносамента в ин. порту,  документ, который используют в водных перевозках из иностранных портов. Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения. | dm_calc.sd_sales_main_scm.LDDAT_KOP_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_in_foreign_port_nomination is 'Номинация коносамента в ин. порту | Номинация (номер документа) коносамента в ин. порту. Номинация  это процесс назначения судна на выполнение определенного вида работ. Этот процесс происходит между клиентом и агентом, который занимается организацией перевозки грузов. Номинация сообщает владельцу или управляющей компании судна о предстоящих заданиях и условиях работы. В одну номинацию могут быть включены несколько коносаментов | dm_calc.sd_sales_main_scm.NOMTK_KOP_exp02';
comment on column dm.sd_sales_main_scm.bill_of_lading_in_foreign_port_route is 'Маршрут коносамента в ин. порту | Системный номер маршрута коносамента в ин. порту, который содерит в себе  информацию  о порте погрузки и порте выгрузки | dm_calc.sd_sales_main_scm.ROUTE_KOP_exp02';
comment on column dm.sd_sales_main_scm.port_of_loading_in_foreign_port_code is 'Порт погрузки 2 (код) | Системный номер порта погрузки (место отправления) из Маршрута коносамента в ин. порту. | dm_calc.sd_sales_main_scm.KNANF_KOP_exp02';
comment on column dm.sd_sales_main_scm.port_of_loading_in_foreign_port_name is 'Порт погрузки 2 | Порт погрузки  (место отправления) из Маршрута коносамента в ин. порту. | dm_calc.sd_sales_main_scm.KNANF_KOP_TXT_exp02';
comment on column dm.sd_sales_main_scm.port_of_discharge_in_foreign_port_code is 'Порт выгрузки 2 (код) | Системный номер порта выгрузки (место назначения) из Маршрута коносамента в ин. порту. | dm_calc.sd_sales_main_scm.KNEND_KOP_exp02';
comment on column dm.sd_sales_main_scm.port_of_discharge_in_foreign_port_name is 'Порт выгрузки 2 | Порт погрузки  (место назначения из Маршрута коносамента в ин. порту.) | transport_hub.transport_hub_name_rus';
comment on column dm.sd_sales_main_scm.status is 'Статус | Значок статуса движения метала | dm_calc.sd_sales_main_scm.STATUS_exp04';
comment on column dm.sd_sales_main_scm.status_description is 'Описание статуса | Описание значка статуса движения метала. Возможны следующие варианты:
Возврат поставщику, определяется в случае если партию вернули поставщику (значение в поле «Причина деления» = 9);
Конечный порт, определяется в случае, если «Дата прибытия в порт выгрузки 2» <= дата построения отчета и «Дата прибытия в порт выгрузки 2» не пустая;
В море 2, определяется в случае, если «Дата прибытия в порт выгрузки 2»> дата построения отчета или «Дата прибытия в порт выгрузки 2» пустая и «Группа коносамента в ин.порту» не пустая;
В иностранном порту, определяется в случае, если «Дата прибытия в порт выгрузки» <= дата построения отчета и «Дата прибытия в порт выгрузки» не пустая и «Признак перетарки в ин.порту» = ‘X’;
В порту выгрузки, определяется в случае, если «Дата прибытия в порт выгрузки» <= дата построения отчета и «Дата прибытия в порт выгрузки» не пустая;
В море, определяется в случае, если «Sailed L.Port» <= дата построения отчета и
«Sailed L.Port» не пустая и «Дата прибытия в порт выгрузки»> дата построения отчета или 
«Дата прибытия в порт выгрузки» - пустая;
В порту, определяется в случае, если «Дата прибытия по ЖД» <= дата построения отчета и «Дата прибытия по ЖД» не пустая и «Sailed L.Port»> дата построения отчета или
«Sailed L.Port» - пусто;
По ЖД, определяется в случае, если «Дата отгрузки» <= дата построения отчета и «Дата отгрузки» не пустая и «Дата прибытия по ЖД»> дата построения отчета или «Дата прибытия по ЖД» - пусто; | dm_calc.sd_sales_main_scm.STATUS_TXT_exp04';
comment on column dm.sd_sales_main_scm.dt_sailed_loading_port is 'Sailed L.Port | Дата отплытия из порта погрузки. Если дата заполнена в номинации, то берем ее, иначе берем «Дата коносамента».
Источники заполнения даты в номинации следующее:
1) Ввод инфо руками в транзакции ZCARGO_ORDERS- Заявки на вывоз из портов РФ;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder | dm_calc.sd_sales_main_scm.SAILED_L_PORT_exp02';
comment on column dm.sd_sales_main_scm.dt_arrival_in_port_of_discharge is 'Дата прибытия в порт выгрузки | Дата прибытия в порт выгрузки из коносамента. Дата из Коносамента, поля Arrived D.Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder | dm_calc.sd_sales_main_scm.DATE_ARRIV_exp02';
comment on column dm.sd_sales_main_scm.dt_arrival_in_port_of_discharge_plan is 'Дата прибытия в порт выгрузки план | Плановая дата прибытия в порт выгрузки по коносаменту РФ.  Инфо получаем из:
1) Коносамента, поля ETA D. Port;
2) Еслив коносаменте ETA D. Port не заполнено, то из Номинации, указанной в этом коносаменте. В номинацию инфо попадает при помощи: загрузочного файл Expected или автоматической загрузки инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
3) Если нет инфо в номинации, то дату берем из Данных портового экспедитора;
4) Если Коносамент еще не создан и «VF: Дата отправления из Порт погрузки» не пустая, то Дата прибытия в порт выгрузки план = «VF: ETA в Порт выгрузки»; 
5) Если Коносамент еще не создан и «VF: Дата прибытия в порт погрузки» не пустая, то Дата прибытия в порт выгрузки план = «Expected BL» + «VF: Время в пути до порта выгрузки»;
6) Если «Тип вагона (код)» = мосркой контейнер и по пунктам выше дату не нашли, то Дата прибытия в порт выгрузки план= «Дата Коносамента» + «Норма морского транзита»;
Иначе= «Booking cont» + «Норма морского транзита»;
Иначе= «Expected BL» + «Норма морского транзита»; | dm_calc.sd_sales_main_scm.DATE_ETADP_exp02';
comment on column dm.sd_sales_main_scm.lot_group is 'Группа лот | Системный номер документа ЛОТ (Клиентский лот),  это совокупность поставок клиенту, привязанная к определённому номеру сбытового контракта и месяцу квоты | dm_calc.sd_sales_main_scm.SAMMG_L_exp02';
comment on column dm.sd_sales_main_scm.lot_contract_code is 'Контракт в лоте (код) | Контракт из группы Лот | delivery_lot.lot_contract_code';
comment on column dm.sd_sales_main_scm.lot_customer_code is 'Покупатель в лоте | Покупатель  из группы Лот. | delivery_lot.lot_customer_code';
comment on column dm.sd_sales_main_scm.lot_delivery_basis_code is 'Базис поставки в лоте | Базис поставки (Инкотермс 1) из группы Лот | delivery_lot.lot_delivery_basis_code';
comment on column dm.sd_sales_main_scm.lot_delivery_point_name is 'Пункт доставки по инкотермс в лоте | Пункт доставки по инкотермс  из группы Лот | delivery_lot.lot_delivery_point_name';
comment on column dm.sd_sales_main_scm.delivery_basis is 'Базис поставки | Базис поставки (Инкотермс 1), это правило поставки Инкотермс.  Базис обозначается тремя латинскими буквами, например EXW, CIP, DAP и пр. Инфо берем из клиентского лота, ели его нет то из заявки под план производства | dm_calc.sd_sales_main_scm.BASIS_exp02';
comment on column dm.sd_sales_main_scm.delivery_point_name is 'Пункт доставки по инкотермс | Пункт доставки по инкотермс (Инкотермс 2), это место передачи груза, это может быть город, аэропорт, морской либо речной порт.  Инфо берем из клиентского лота, ели его нет то из заявки под план производства | dm_calc.sd_sales_main_scm.BASIS2_exp02';
comment on column dm.sd_sales_main_scm.route_type is 'Тип маршрута | Вид отгрузки, определяется по маршруту завода. Допустимые значения: 
01- Автотранспорт
X3- Маршрут вагоны
X5- Маршрут контейнеры | dm_calc.sd_sales_main_scm.VSART_exp01';
comment on column dm.sd_sales_main_scm.route_number is 'Номер маршрута | Это номер, который объединяет в себе значение нескольких полей из группы поставок, которая создается на заводе и используется для группировки поставок в составе вагонов. Где, 
1) первый символ (буква), это вид группы, обозначает вид отгрузки;  
2) номер между символами ""-"", это системный номер группы;
3) последние цифры, после символа ""-"", это количество поставок, включенных в группу.  По этому значению мы  понимаем, что это одиночная отправка или целый состав.
Например, Номер маршрута A-8000055482-65, обозначает: вид группы A-ЖД маршрут, номер группы 8000055482, количество поставок, включенных в группу 65. | sales_batch_delivery.route_code';
comment on column dm.sd_sales_main_scm.route_number is 'Номер маршрута | Это номер, который объединяет в себе значение нескольких полей из группы поставок, которая создается на заводе и используется для группировки поставок в составе вагонов. Где, 
1) первый символ (буква), это вид группы, обозначает вид отгрузки;  
2) номер между символами ""-"", это системный номер группы;
3) последние цифры, после символа ""-"", это количество поставок, включенных в группу.  По этому значению мы  понимаем, что это одиночная отправка или целый состав.
Например, Номер маршрута A-8000055482-65, обозначает: вид группы A-ЖД маршрут, номер группы 8000055482, количество поставок, включенных в группу 65. | sales_batch_delivery.route_code';
comment on column dm.sd_sales_main_scm.dt_stamp_railway_bill is 'Дата штемпеля по ЖДН | Дата со штемпеля на ЖД накладной со станции отправления. Инфо берем из данных об отгрузке с завода. Эта дата используется по-разному, в зависимости от вида перехода права собственности (далее ППС):
- при ППС 001 (отпуск материала проходит на станции продавца) это дата будет датой отпуска материала;
- при ППС 002 (отпуск материала проходит только, доехав до станции покупателя) это дата отправки вагона со станции отправителя | sales_batch_delivery.dt_stamp_railway_bill';
comment on column dm.sd_sales_main_scm.dt_plant_arrival is 'Дата прихода на завод | Дата, прибытия пустого  контейнера на завод. Инфо берем из данных об отгрузке с завода | sales_batch_delivery.dt_arrival_to_plant';
comment on column dm.sd_sales_main_scm.dt_import_export_transfer is 'Дата перехода из импорта в экспорт | Дата, когда морской контейнер вернули в РФ из-за границы. Инфо берем из данных об отгрузке с завода | sales_batch_delivery.dt_conversion_from_import_to_export';
comment on column dm.sd_sales_main_scm.seal_number is 'Номера пломб | Номер пломбы, навешиваемой на кузова транспортных средств (вагоны, фургоны,  контейнеры, их секции и отдельные грузовые места), которая не должна допускать возможности доступа к грузу и снятия пломбы без нарушения их целостности.  Инфо берем из данных об отгрузке с завода | sales_batch_delivery.seal_number';
comment on column dm.sd_sales_main_scm.requisite is 'Реквизит | Вес крепления товара в транспортном средстве в КГ. Инфо берем из данных об отгрузке с завода | sales_batch_delivery.fixing_holder_weight';
comment on column dm.sd_sales_main_scm.receiving_plant_in_sap_system_code is 'Принимающий завод грузополучателя в системе SAP | Системный номер завода оператора, собственника продукции при реализации клиенту | sales_batch_delivery.receiving_plant_in_sap_system_code';
comment on column dm.sd_sales_main_scm.contract_export_number is 'Внешнеторговый контракт завода | Договор (номер на бумажном носителе) по которому выполняется экспорт продукции из РФ | sales_batch_delivery.contract_export_number';
comment on column dm.sd_sales_main_scm.dimensions_unit is 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | sales_batch_delivery.unit_dimensions';
comment on column dm.sd_sales_main_scm.consignee_code is 'Получатель материала | Системный код дебитора, который является получателем продукции по отгрузочному документу завода - ЖД накладная/CMR/ТТН.  Тот, в адрес кого Завод производитель отгружает продукцию.  | sales_batch_delivery.consignee_code';
comment on column dm.sd_sales_main_scm.consignee_name is 'Грузополучатель | Название получателя материала по отгрузочному документу завода - ЖД накладная/CMR/ТТН.  Тот, в адрес кого Завод производитель отгружает продукцию.  | sales_batch_delivery.consignee_name';
comment on column dm.sd_sales_main_scm.end_buyer_for_reporting_code is '№ конечного покупателя в SAP/CUST2_ID | Системный номер конечного покупателя в случае продажи по агенской схеме. Тот кому будет продавать Агент | dm_calc.sd_sales_main_scm.CUST2_ID_exp01';
comment on column dm.sd_sales_main_scm.transport_railway_car_type_plan is 'Тип вагона, указанный в графике отгрузке на заводе-производеле | Системный код типа вагона, указанный в графике отгрузке на заводе производителе | plant_delivery.transport_railway_car_type_plan';
comment on column dm.sd_sales_main_scm.id_railcar is 'Idw1 | Внутренний идентификатор вагона при взаимодействии с портовыми экспедиторами по сути равен номеру первой партии вагона | sales_batch_delivery.railcar_internal_code';
comment on column dm.sd_sales_main_scm.shipment_route_code is 'Маршрут в отгрузке | Системный номер маршрута из поставки завода производителя. Инфо берем из данных об отгрузке с завода | sales_batch_delivery.route_in_shipment_code';
comment on column dm.sd_sales_main_scm.discharge_terminal_code is 'Код терминала разгрузки | Источник данных /RUSAL/SHIPDATA-UNL_TERM, вегда = пусто | sales_batch_delivery.discharge_terminal_code';
comment on column dm.sd_sales_main_scm.destination_station_code is 'Код станции назначения | Системный код станции назначения, которая является конечной точкой доставки по ж\д, инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | sales_batch_delivery.destination_station_code';
comment on column dm.sd_sales_main_scm.customs_declaration_number is 'Номер ГТД | Номер грузовой таможенной декларации | dm_calc.sd_sales_main_scm.GTD_exp01';
comment on column dm.sd_sales_main_scm.dt_customs_declaration is 'Дата ГТД | Дата грузовой таможенной декларации | dm_calc.sd_sales_main_scm.GTD_DATE_exp01';
comment on column dm.sd_sales_main_scm.material_specification_name is 'Спецификация | Название документа с набором требований, которым должен соответствовать разрабатываемый продукт | specification.specification_name';
comment on column dm.sd_sales_main_scm.weight_strip is 'Вес ленты | Вес упаковки, рассчитывается по формуле:  «Вес брутто» - «Вес Н&K», инфо выводим в базисной единице измерения
 | dm_calc.sd_sales_main_scm.PACKING_SHIP_exp01';
comment on column dm.sd_sales_main_scm.weight_wirerod is 'Вес катанки | Вес упаковки, рассчитывается по формуле:  «Вес Н&K» - «Вес нетто», инфо выводим в базисной единице измерения
 | dm_calc.sd_sales_main_scm.KATANKA_exp01';
comment on column dm.sd_sales_main_scm.tariff_freight is 'Жд тариф | Стоимость железнодорожного тарифа за ж/д перевозку от Завода производителя до станции назначения. Жд-тариф из РейлТарифа (справочник 10.01 РЖД) | dm_calc.sd_sales_main_scm.FREIGHT_exp01';
comment on column dm.sd_sales_main_scm.tariff_security is 'Охрана | Стоимость охраны груза за ж/д перевозку от Завода производителя до станции назначения. Тариф по охране из РейлТарифа (справочник 10.01 РЖД) | dm_calc.sd_sales_main_scm.SUMPROT_exp01';
comment on column dm.sd_sales_main_scm.quarantine_certificate_number is 'Карантинный сертификат | Номер документа, который удостоверяет соответствие партии подкарантинной продукции карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, осуществляющим функции по контролю и надзору в области карантина, при перемещении подкарантинной продукции по территории Российской Федерации. | sales_batch_delivery.quarantine_certificate_number';
comment on column dm.sd_sales_main_scm.dt_quarantine_certificate is 'Дата карантинного сертификата | Дата документа, который удостоверяет соответствие партии подкарантинной продукции карантинным фитосанитарным требованиям и выдан федеральным органом исполнительной власти, осуществляющим функции по контролю и надзору в области карантина, при перемещении подкарантинной продукции по территории Российской Федерации. | sales_batch_delivery.dt_quarantine_certificate';
comment on column dm.sd_sales_main_scm.end_user_for_reporting_code is 'Потребитель (код) | Код контрагента, который является получателем  металла. Потребитель может быть и Конечным потребителем. | dm_calc.sd_sales_main_scm.KUNNR_END_exp03';
comment on column dm.sd_sales_main_scm.end_user_for_reporting_name is 'Потребитель | Имя контрагента, который является получателем  металла. Потребитель может быть и Конечным потребителем. | dm_calc.sd_sales_main_scm.KUNNR_END_TXT_exp03';
comment on column dm.sd_sales_main_scm.cargo_package_quantity is 'Количество грузовых мест | Количество грузовых мест в вагоне | sales_batch_delivery.cargo_package_quantity';
comment on column dm.sd_sales_main_scm.receiving_warehouse_code is 'Принимающий склад | Код склада Завода- оператора (собственника продукции при реализации клиенту), на который будет принята продукция и в дальнейшем с которого будет производиться отгрузка Клиенту | sales_batch_delivery.receiving_warehouse_code';
comment on column dm.sd_sales_main_scm.plant_owner_code is 'Завод собственник (код) | Системный номер завода собственника сырья, он передает свое сырье на переработку Заводу производителю  | sales_batch_delivery.plant_owner_code';
comment on column dm.sd_sales_main_scm.station_of_departure_code is 'Станция отправления | Название станции, которая является отправной точкой груза по ж\д, инфо выводится из начального узла Маршрута завода | sales_batch_delivery.station_of_departure_code';
comment on column dm.sd_sales_main_scm.instruction_number is 'Номер распоряжения | Номер распоряжения на отгрузку (номер заказа в системе), создается только для отгрузок на внутренний рынок и СНГ, этот документ является указанием к отгрузке Заводу производителю, в нем указано кому, что и сколько нужно отгрузить. Распоряжение на отгрузку создается ДСБ по контракту с клиентом из Заказа ЦК в отгрузке (в тразакции ZSD2882M-Регистрация заявок клиентов) и выдается производителю.  | sales_batch_delivery.instruction_number';
comment on column dm.sd_sales_main_scm.delivery_number_of_plant_owner is 'Номер поставки завода собственника | Поставка завода собственника сырья, по которой формируется цепочка продаж на заводе собственнике | sales_batch_delivery.delivery_number_of_plant_owner';
comment on column dm.sd_sales_main_scm.dt_first_entry_appeared is 'Дата первого появления записи в системе | Дата создания записи об отгрузке, в транзакции ZSD2925M Загрузки данных об отгрузке на трейдерах | sales_batch_delivery.dt_created';
comment on column dm.sd_sales_main_scm.shipment_entry_identifier_from_file is 'Идентификатор записи об отгрузке из файла | Идентификатор  записи (уникальный номер) об отгрузке | sales_batch_delivery.shipment_entry_identifier_from_file';
comment on column dm.sd_sales_main_scm.finish_good_unit_length is 'Длина единицы готовой продукции | Длина единицы готовой продукции | sales_batch_delivery.finish_good_unit_length';
comment on column dm.sd_sales_main_scm.finish_good_unit_width is 'Ширина единицы готовой продукции | Ширина единицы готовой продукции | sales_batch_delivery.finish_good_unit_width';
comment on column dm.sd_sales_main_scm.finish_good_unit_height is 'Высота единицы готовой продукции | Высота единицы готовой продукции | sales_batch_delivery.finish_good_unit_height';
comment on column dm.sd_sales_main_scm.finish_good_unit_diameter is 'Диаметр единицы готовой продукции | Диаметр единицы готовой продукции | sales_batch_delivery.finish_good_unit_diameter';
comment on column dm.sd_sales_main_scm.quality_certificate_number is 'Номер сертификата | Официальный документ, подтверждающий высокое качество продукции и соответствие установленным требованиям государственных стандартов и технических регламентов. | sales_batch_delivery.quality_certificate_number';
comment on column dm.sd_sales_main_scm.delivery_item_of_plant is 'Позиция поставки завода производителя | Номер позиции поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе | sales_batch_delivery.delivery_item_number_of_plant_producer';
comment on column dm.sd_sales_main_scm.customer_grade_code is 'Код марки клиента | использовался для данных на RAC, более не актуален | -';
comment on column dm.sd_sales_main_scm.dt_collection is 'Дата комплектования | Дата комплектования (подготовки груза для отгрузки) поставки завода производителя  | sales_batch_delivery.dt_order_picking';
comment on column dm.sd_sales_main_scm.destination_station_in_shipment_name is 'Станция назначения в отгрузке | Название станции, которая является конечной точкой доставки по ж\д, инфо выводится из Загрузки данных об отгрузке на трейдерах (транзакция ZSD2925M) | sales_batch_delivery.station_of_destination_name';
comment on column dm.sd_sales_main_scm.box_foil is 'Ящик | Номер ящика фольги | sales_batch_delivery.foil_box_number';
comment on column dm.sd_sales_main_scm.pieces is 'PCS | Количество грузовых мест в поставке | dm_calc.sd_sales_main_scm.ANZPK_exp02';
comment on column dm.sd_sales_main_scm.transport_capacity is 'Грузоподъемность | Грузоподъемность вагона/ контейнера, указывается в тексте заголовка поставки завода производителя | dm_calc.sd_sales_main_scm.GRUZ_exp02';
comment on column dm.sd_sales_main_scm.weight_uom_code is 'Единица измерения веса | Базовая единица изменения, указанная для материала | material.weight_uom_code';
comment on column dm.sd_sales_main_scm.route_plant_code is 'Маршрут завода | Системный номер маршрута завода, который указывается в поставке завода производителя | dm_calc.sd_sales_main_scm.ROUTE_exp02';
comment on column dm.sd_sales_main_scm.container_after_repacking is 'Контейнер после перетарки | Номер транспортного средства после перетарки | dm_calc.sd_sales_main_scm.VAGON_PR_exp02';
comment on column dm.sd_sales_main_scm.route_delivery_repacking is 'Маршрут поставки Перетарки | Системный номер маршрута, по которому будет двигаться транпсортное средство после перетарки. Инфо выводим из:
-для «Сценарий маршрута» = 58. От Завода ж/д в Китай с/без перетарки не RTC (DAP, DDP), маршрут определяем по последнему этапу Маршрута завода; 
- маршрута поставки перетарки, для случаев если перетарка уже произошла и создана эта поставка;
- маршрут определяем по Порту погрузки (кпак начальная точка) и Пункту доставки по инкотерм (как конечная точка); | dm_calc.sd_sales_main_scm.ROUTE_PERETAR_exp02';
comment on column dm.sd_sales_main_scm.dt_shipment_plan is 'Плановая дата отгрузки | Дата когда была запланирована отгрузка по Заказу ЦК, заполняется в графике отгрузки на стороне BI | dm_calc.sd_sales_main_scm.D_WERKS_OTGR_P_exp02';
comment on column dm.sd_sales_main_scm.distance_remaining is 'Оставшееся расстояние | Оставшееся расстояние до прибытия вагона на конечную станцию назначения.  Источник информации Дислокация вагонов | dm_calc.sd_sales_main_scm.DISTANCE_exp02';
comment on column dm.sd_sales_main_scm.sales_order is 'Заказ ЦК | Это системный номер заказаЦК в отгрузке | dm_calc.sd_sales_main_scm.ZAKAZ_KL_exp02';
comment on column dm.sd_sales_main_scm.buyer_plan_code is 'Плановый покупатель (код) | Системный номер заказчика из:
- планового контракта;
- если плановый контракт не определен, то Потребитель введенный для Продажной поставки;
- если Продажной поставки нет, то отражается Покупатель из транзакции ZSD2882M-Регистрация заявок клиентов | dm_calc.sd_sales_main_scm.BUYER_exp02';
comment on column dm.sd_sales_main_scm.port_of_discharge_plan_code is 'Плановый порт выгрузки (код) | Системный номер порта выгрузки (Конечный узел доставки), который является плановым и выводится из доп. данных к Продажной поставке, если поставки еще нет, то выводим Порт выгрузки/перевалки вне РФ из транзакции ZSD2882M-Регистрация заявок клиентов. Например, Плановый порт выгрузки (код) = P000000135, а Плановый порт выгрузки= ROTTERDAM | dm_calc.sd_sales_main_scm.END_LOC_CODE_exp04';
comment on column dm.sd_sales_main_scm.port_of_discharge_plan_name is 'Плановый порт выгрузки | Порт выгрузки (Конечный узел доставки), который является плановым и выводится из доп. данных к Продажной поставке, если поставки еще нет, то выводим Порт выгрузки/перевалки вне РФ из транзакции ZSD2882M-Регистрация заявок клиентов. Например, Плановый порт выгрузки (код) = P000000135, а Плановый порт выгрузки= ROTTERDAM | transport_hub_texts.transport_hub_name';
comment on column dm.sd_sales_main_scm.customer_special_requirement is 'Трейдеры: спец. заказ клиента | Номер заказа клиента, инфо берем из клиентского лота, еслти лота нет то из транзакции ZSD2882M-Регистрация заявок клиентов | dm_calc.sd_sales_main_scm.SPEC_ORDER_exp02';
comment on column dm.sd_sales_main_scm.dt_discharge_in_foreign_port is 'Дата выгрузки в порту | Дата выгрузки судна в иностранном порту, по коносаменту из РФ | bill_of_lading_in_russian_port.dt_discharge_in_foreign_port';
comment on column dm.sd_sales_main_scm.dt_discharge_in_second_foreign_port is 'Дата выгрузки в порту 2 | Дата выгрузки судна в иностранном порту, по коносаменту в ин. порту | bill_of_lading_in_foreign_port.dt_discharge_in_second_foreign_port';
comment on column dm.sd_sales_main_scm.dt_arrival_in_second_port_of_discharge is 'Дата прибытия в порт выгрузки 2 | Дата прибытия в порт выгрузки из коносамента в ин. порту. Дата из Коносамента в ин. порту, поля Arrived D.Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
 | dm_calc.sd_sales_main_scm.ARRDP_exp02';
comment on column dm.sd_sales_main_scm.delivery_notice_group_code is 'Группа нотис о доставке | Системный номер документа, который создает ДСБ (дирекция по сбыту) для базисов поставки  DDP или DAP для отражения даты доставки клиенту | dm_calc.sd_sales_main_scm.SAMMG_ND_exp03';
comment on column dm.sd_sales_main_scm.dt_delivery_notice is 'Дата нотиса о доставке | Дата документа, который создает ДСБ (дирекция по сбыту) для базисов поставки  DDP или DAP для отражения даты доставки клиенту | delivery_notice.dt_delivery_notice';
comment on column dm.sd_sales_main_scm.delivery_notice_number is 'Номер нотиса о доставке | Номер документа (на бумажном носителе), который создает ДСБ (дирекция по сбыту) для базисов поставки  DDP или DAP для отражения даты доставки клиенту | delivery_notice.delivery_notice_number';
comment on column dm.sd_sales_main_scm.vessel_plan_name is 'Судно план | Название судна согласно справочнику OIGVT из плановой номинации | transport_vessel_old.vessel_name';
comment on column dm.sd_sales_main_scm.vessel_plan_code is 'Судно план (код) | Номер судна согласно справочнику OIGVT из плановой номинации | nomination_in_russian_port.vessel_plan_code';
comment on column dm.sd_sales_main_scm.voyage_number_plan is 'Номер рейса план | Номер рейса по данным портового экспедитора | dm_calc.sd_sales_main_scm.NMVESSEL_P_exp02.VEHICLE_F_exp02';
comment on column dm.sd_sales_main_scm.vessel_actual_code is 'Судно факт (код) | Код судна из Номинации коносамента РФ, если его еще нет то из Поручения | dm_calc.sd_sales_main_scm.VEHICLE_F_TXT_exp02';
comment on column dm.sd_sales_main_scm.vessel_actual_name is 'Судно факт | Название судна из Номинации коносамента РФ, если его еще нет то из Поручения | dm_calc.sd_sales_main_scm.VEHICLE_F_TXT_exp02';
comment on column dm.sd_sales_main_scm.voyage_number_actual is 'Номер рейса факт | Номер рейса из Номинации коносамента РФ, если его еще нет то из Поручения | dm_calc.sd_sales_main_scm.NMVESSEL_F_exp02';
comment on column dm.sd_sales_main_scm.voyage_number_in_foreign_port_actual is 'Номер рейса факт в ин. порту | Номер рейса из Номинации коносамента в ин. порту | nomination_in_foreign_port.voyage_number_in_foreign_port_actual';
comment on column dm.sd_sales_main_scm.vessel_in_foreign_port_actual_code is 'Судно факт в ин. порту(код) | Код судна из Номинации коносамента в ин. порту | nomination_in_foreign_port.vessel_in_foreign_port_actual_code';
comment on column dm.sd_sales_main_scm.vessel_in_foreign_port_actual_name is 'Судно факт в ин. порту | Название судна из Номинации коносамента в ин. порту | transport_vessel_old.vessel_name';
comment on column dm.sd_sales_main_scm.material_code is 'Код материала | Системный номер материала. Например, APT0006ING0045. Аналог поля  Номер материала | dm_calc.sd_sales_main_scm.MATNR_exp02';
comment on column dm.sd_sales_main_scm.customer_grade_name is 'Марка клиента | Код марки материала клиента. Например у материала AAX0024SLB0148, Марка клиента= A30  | dm_calc.sd_sales_main_scm.MMCL_NAME_exp02';
comment on column dm.sd_sales_main_scm.grade_name is 'Марка по спецификации | Наименование марки по спецификации.  Например у материала AAX0024SLB0148, Марка по спецификации= 1050 | dm_calc.sd_sales_main_scm.MMBS_NAME_exp02';
comment on column dm.sd_sales_main_scm.dt_sales_order_delivery_actual is 'Фактическая дата получения заказа клиента | Дата, когда получили доп.информацию по заказу  (данные опциона) от клиента. | sales_orders.dt_sales_order_delivery_actual';
comment on column dm.sd_sales_main_scm.contract_plan_code is 'Плановый контракт (код) | Системный номер договора с клиентом, по которому предполагется продажа, поэтому это плановый контракт | dm_calc.sd_sales_main_scm.VBELN_R_exp03';
comment on column dm.sd_sales_main_scm.contract_plan_name is 'Плановый контракт | Номер договора с клиентом, по которому предполагется продажа, поэтому это плановый контракт | dm_calc.sd_sales_main_scm.BSTKD_P_exp02';
comment on column dm.sd_sales_main_scm.dt_delivery_deadline is 'Deadline доставки | Желемый срок доставки по конрактым обязательствам (переход права собственности) в рамках заказа ЦК. Например, для CIF это  желаемая дата прибытия в порт погрузки РФ/ ин. склада, для прочих желаемая дата доставки до клиента. | dm_calc.sd_sales_main_scm.DL_TO_exp02';
comment on column dm.sd_sales_main_scm.shipment_period_preferred is 'Желаемый период отгрузки | Желаемый период отгрузки с завода производителя | dm_calc.sd_sales_main_scm.SROK_FROMTO_exp02';
comment on column dm.sd_sales_main_scm.uni is 'UNI | Если Причина деления постави = ""4- Перевеска"", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | dm_calc.sd_sales_main_scm.UNI_exp02';
comment on column dm.sd_sales_main_scm.uni_in_shipment is 'UNI в отгрузке | «Накладная» и «Вагон» разделенные знаком‘-’.  | dm_calc.sd_sales_main_scm';
comment on column dm.sd_sales_main_scm.vessel_imo is 'IMO судна | Это уникальный идентификатор судна, инфо берем  по "Судно факт в ин. порту", если пусто то по "Судно факт", если пусто то по "Судно план(код)". Если IMO судна по морскому трекингу отличается, от значений полученных выше, то инфо берем из морского трекинга. | dm_calc.sd_sales_main_scm.VESSEL_IMO_exp02';
comment on column dm.sd_sales_main_scm.vessel_mmsi is 'MMSI судна | Это идентификационный номер в морской мобильной службе, присваиваемый суднам и другим объектам морского транспорта. В нашем отчете используется только для барж. Инфо берем по "Судно факт в ин. порту", если пусто то по "Судно факт", если пусто то по "Судно план(код)". Если MMSI судна по морскому трекингу отличается, от значений полученных выше, то инфо берем из морского трекинга. | dm_calc.sd_sales_main_scm.VESSEL_MMSI_exp02';
comment on column dm.sd_sales_main_scm.geo_latitude is 'Широта | Текущие координаты транспортного средства (вагона/судна и пр.), широта | dm_calc.sd_sales_main_scm.LATITUDE_CURR_exp02';
comment on column dm.sd_sales_main_scm.geo_longitude is 'Долгота | Текущие координаты транспортного средства (вагона/судна и пр.), долгота | dm_calc.sd_sales_main_scm.LONGITUDE_CURR_exp02';
comment on column dm.sd_sales_main_scm.dt_arrival_in_second_port_of_discharge_plan is 'Дата прибытия в порт выгрузки 2 план | Плановая дата прибытия в порт выгрузки из коносамента в ин. порту. Дата из Коносамента в ин. порту, поля ETA D. Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
 | dm_calc.sd_sales_main_scm.ETADP_KOP_exp02';
comment on column dm.sd_sales_main_scm.pb_number is 'LotWshe/PB number | Внешняя идентификация накладной | dm_calc.sd_sales_main_scm.PBNUMBER_exp02';
comment on column dm.sd_sales_main_scm.is_plan_or_actual is 'Признак План/Факт | Идентификатор отгрузки от завода производителя,  возможные варианты: 
F- факт, уже есть инфо от завода производителя;
P-план, еще нет инфо от завода производителя, инфо взяли из таблицы распределения
 | dm_calc.sd_sales_main_scm.PLFK_exp03';
comment on column dm.sd_sales_main_scm.is_plan_or_actual_al2all is 'Признак План/Факт для портала | Техническое поле обозначает идентификатор отгрузки от завода производителя,  возможные варианты: 
P, если «Признак План/Факт»= «P» или /RUSAL/SHIPDATA- DATEOT= «пусто»; 
F , если «Признак План/Факт» = «F» и /RUSAL/SHIPDATA- DATEOT <> «пусто» | dm_calc.sd_sales_main_scm.PLFK_PORTAL_exp03';
comment on column dm.sd_sales_main_scm.status_al2all is 'Статус для портала AL2ALL | Статус, который передаем на клиентский портал, набор статусов определется для «Сценарий маршрута». Возможные значения:
«Arrived at destination»
«Called off»
«Out for delivery»
«On stock»
«In warehouse»
«Consumed»
«At Consignment stock»
«In transit to CS»
«On vessel»
«In the port»
«Barging»
«Ready for reloading»
«In transit to WH»
«In transit China»
«Arrived to POL»
«In rw transit Russia»
«Plan»
«Доставлено»
«Брошено»
«В транзите»
«На станции»
«Выдано распоряжение»
«Отгружено»
«План ЕАЛ» | dm_calc.sd_sales_main_scm.STATUS_AL2ALL_exp03';
comment on column dm.sd_sales_main_scm.dt_expected_delivery is 'Expected delivery | Ожидаемая дата доставки до клиента, является расчетной. Формула рассчета зависит от «Сценарий маршрута». | dm_calc.sd_sales_main_scm.PROG_DATE_exp03';
comment on column dm.sd_sales_main_scm.quantity_shipped is 'Отгруженное количество | Фактически отгруженное количество, заполняется только для строк, у которых «Признак План/Факт» = «F» | dm_calc.sd_sales_main_scm.LFIMG_OUT_exp03';
comment on column dm.sd_sales_main_scm.quantity_ordered is 'Запланированное количество | Запланированное количество к отгрузке по Заказу ЦК | dm_calc.sd_sales_main_scm.VES_WAG_P_exp03';
comment on column dm.sd_sales_main_scm.invoice_provisional_number is 'Provisional invoice | Инвойс (счет клиенту), он может быть предварительным или окончательным. Предварительный - когда указывают цену, в которой ещё не уверены.  | dm_calc.sd_sales_main_scm.VTEXT_PIN_exp03';
comment on column dm.sd_sales_main_scm.release_group_code is 'Группа Релиз | Системный номер документа, который дает право распоряжения грузом, один из документов перехода права собственности.
 | dm_calc.sd_sales_main_scm.SAMMG_REL_exp03';
comment on column dm.sd_sales_main_scm.release_group_name is 'Релиз | Документ, который дает право распоряжения грузом, один из документов перехода права собственности.
 | release_delivery_group.release_group_name';
comment on column dm.sd_sales_main_scm.invoice_final_number is 'Final Invoice | Финальный счет,  нужен для уточнения цены или корректировки стоимости, создается в случае необходимости, когда контировки уже корректно рассчитаны. Как правило оформляется со ссылкой на Provisional invoice | dm_calc.sd_sales_main_scm.VTEXT_FIN_exp03';
comment on column dm.sd_sales_main_scm.pledge_in_document_number is 'Номер документа pledge in | Номер документа залога. Залог- это кредитная линия под проценты/комиссию, под залог метала или дебиторской задолженности, в зависимости от вида заключенного договора. | dm_calc.sd_sales_main_scm.PLEDGE_VTEXT_IN_exp03';
comment on column dm.sd_sales_main_scm.pledge_in_bank_code is 'Pledge Bank | Имя кредитора, который открыл нам кредитную линию по залогу, то у кого мы взяли деньги. Залог- это кредитная линия под проценты/комиссию, под залог метала или дебиторской задолженности, в зависимости от вида заключенного договора. | dm_calc.sd_sales_main_scm.PLEDGE_CLIENT_TXT_exp03';
comment on column dm.sd_sales_main_scm.dt_pledge_in is 'Дата pledge in | Дата документа залога, дата начала действия кредитного договора по залогу, т.е. когда нам открыли кредитную линию. Залог- это кредитная линия под проценты/комиссию, под залог метала или дебиторской задолженности, в зависимости от вида заключенного договора. | dm_calc.sd_sales_main_scm.PLEDGE_LDDAT_exp03';
comment on column dm.sd_sales_main_scm.production_order is 'Производственный заказ | Номер заказа, по которому завод выпускает производитель продукцию. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах. Изначально производственные заказы вносятся в тразакции ZSD2882M-Регистрация заявок клиентов | dm_calc.sd_sales_main_scm.ZAKAZ_KL_L_exp03';
comment on column dm.sd_sales_main_scm.dt_storage_start_in_foreign_port is 'Дата начала хранения ин. склад | Дата начала хранения металла на удаленном складе, после поступления груза в ин. порт из РФ  | dm_calc.sd_sales_main_scm.WH_DATE_POD_exp03';
comment on column dm.sd_sales_main_scm.dt_storage_end_in_foreign_port is 'Окончание хранения в ин. порту | Дата окончания хранения металла на удаленном складе, после поступления груза в ин. порт из РФ  | dm_calc.sd_sales_main_scm.ST_END_POD_exp03';
comment on column dm.sd_sales_main_scm.dt_storage_start_in_second_foreign_warehouse is 'Начало хранения склад 2 | Дата начала хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт | release_delivery_group.dt_storage_start_in_second_foreign_warehouse';
comment on column dm.sd_sales_main_scm.dt_storage_end_in_second_foreign_warehouse is 'Окончание хранение склад 2 | Дата окончания хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт | dm_calc.sd_sales_main_scm.FINISH_STORAGE2_exp03';
comment on column dm.sd_sales_main_scm.sales_contract_code is 'Контракт (код) | - | sales_contract.sales_contract_code';
comment on column dm.sd_sales_main_scm.frame_contract_code is 'Рамочный контракт (код) | - | sales_contract.frame_contract_code';
comment on column dm.sd_sales_main_scm.material_name is '- | - | material_texts.material_name';
comment on column dm.sd_sales_main_scm.dt_realization_forecast is 'Расчетная дата реализации | - | dm_calc.sd_sales_main_scm.REALIZATION_DATE_CALC_exp04';
comment on column dm.sd_sales_main_scm.realization_reason_document is 'Основание реализации | Вид документа, который является основанием для реализации | dm_calc.sd_sales_main_scm.DOCNUMBER_exp04';
comment on column dm.sd_sales_main_scm.export_organization_name is 'Экпортер | - | dm_calc.sd_sales_main_scm.EXPORTER_TXT_exp04';
comment on column dm.sd_sales_main_scm.material_shape_name_full is 'Форма | Форма  | material_shape_texts.material_shape_full_name';
comment on column dm.sd_sales_main_scm.buyer_incassa_extended_name is 'Покупатель Incassa | - | dm_calc.sd_sales_main_scm.BUYER_INC_exp04';
comment on column dm.sd_sales_main_scm.export_organization_code is 'Экпортер (код) | - | dm_calc.sd_sales_main_scm.EXPORTER_exp04';
comment on column dm.sd_sales_main_scm.delivery_split_reason_name is 'Причина деления | - | delivery_split_reason_texts.delivery_split_reason_name';
comment on column dm.sd_sales_main_scm.country_of_discharge_port_code is 'Страна POD (код) | - | dm_calc.sd_sales_main_scm.LAND1_POD_exp02';
comment on column dm.sd_sales_main_scm.country_of_discharge_port_name is 'Страна POD | - | dm_calc.sd_sales_main_scm.LANDX_POD_exp02';
comment on column dm.sd_sales_main_scm.region_of_destination_port_code is 'Регион POD (код) | - | dm_calc.sd_sales_main_scm.WWGSG_POD_exp02';
comment on column dm.sd_sales_main_scm.region_of_destination_port_name is 'Регион POD | - | dm_calc.sd_sales_main_scm.BEZEK_POD_exp02';
comment on column dm.sd_sales_main_scm.contract_type_code is 'Вид контракта (код) | - | dm_calc.sd_sales_main_scm.BSARK_exp04';
comment on column dm.sd_sales_main_scm.delivery_number_outbound is 'Исходящая поставка | - | dm_calc.sd_sales_main_scm.VBELN_ISH_exp03';
comment on column dm.sd_sales_main_scm.dt_release_material is 'Дата ОМ | Дата проводки ОМ | dm_calc.sd_sales_main_scm.WADAT_IST_ISH_exp04';
comment on column dm.sd_sales_main_scm.release_material_status_code is 'Статус ОМ | Статус проводки ОМ | dm_calc.sd_sales_main_scm.WBSTK_ISH_exp04';
comment on column dm.sd_sales_main_scm.dt_updated is 'Дата и время последнего изменения | Дата и время последнего изменения на источнике | dm_calc.sd_sales_main_scm.DATE_CH_exp01 + dm_calc.sd_sales_main_scm.TIME_CH_exp01';
comment on column dm.sd_sales_main_scm.delivery_split_reason_code is 'Причина деления (код) | Причина разделения партии на разные поставки. Допустимы значения из домена /RUSAL/SD2925M_SPLIT_REASON | dm_calc.sd_sales_main_scm.REASON_exp02';
comment on column dm.sd_sales_main_scm.contract_type is 'Вид контракта | - | dm_calc.sd_sales_main_scm.BSARK_TXT_exp04';
comment on column dm.sd_sales_main_scm.dt_ownership_transfer is 'Дата перехода права собственности | - | dm_calc.sd_sales_main_scm.DATEPPS_exp01';
comment on column dm.sd_sales_main_scm.dt_prepared_for_realization is 'Дата готовности к реализации | - | dm_calc.sd_sales_main_scm.READY_TO_SHIP_DATE_exp04';
comment on column dm.sd_sales_main_scm.port_of_discharge_for_reporting_code is 'Порт выгрузки (группа) | - | ';
comment on column dm.sd_sales_main_scm.port_of_destination_name is 'Порт назначения | - | dm_calc.sd_sales_main_scm.PORT_FOR_CUSTOMER_exp03';
comment on column dm.sd_sales_main_scm.delivery_instruction_code is 'Инструкция на доставку | - | dm_calc.sd_sales_main_scm.VBELN_INSTR_exp02';
comment on column dm.sd_sales_main_scm.incoterms_plan_code is 'Плановый базис поставки | - | dm_calc.sd_sales_main_scm.INCO1_exp02';
comment on column dm.sd_sales_main_scm.incoterms_location_plan_code is 'Плановый пункт доставки по инкотермс | - | dm_calc.sd_sales_main_scm.INCO2_exp02';
comment on column dm.sd_sales_main_scm.finish_good_group_code is 'Группа продукции | - | dm_calc.sd_sales_main_scm.GROUPS_exp03';
comment on column dm.sd_sales_main_scm.delivery_country_incoterms_code is 'Страна доставки по инкотермс | - | dm_calc.sd_sales_main_scm.BASIS2_LAND1_exp02';
comment on column dm.sd_sales_main_scm.dt_etd is 'Дата букинга | - | dm_calc.sd_sales_main_scm.ETD_L_PORT_ML_exp01';
comment on column dm.sd_sales_main_scm.dt_expected_bill_of_lading is 'Ожидаемая дата коносамента | Ожидаемая дата коносамента | dm_calc.sd_sales_main_scm.ETAR_exp02';
comment on column dm.sd_sales_main_scm.external_contract_in_lot_number is 'Контракт в лоте/Квотный контракт | Контракт в лоте/Квотный контракт | dm_calc.sd_sales_main_scm.BSTKD_LOT_exp02';
comment on column dm.sd_sales_main_scm.dt_transfer_from_consignment_to_customer is 'Дата перехода из консигнации клиенту | Отображает дату - «Дата Provisional Invoice» если «Признак консигнации» = X | dm_calc.sd_sales_main_scm.TCON_TO_BUYER_DATE_exp03';
comment on column dm.sd_sales_main_scm.dt_final_release is 'Дата Финальный релиз | Отображает дату созданого финального релиза | dm_calc.sd_sales_main_scm.LDDAT_FREL_exp03';
comment on column dm.sd_sales_main_scm.is_shipped_via_overseas_warehouse is 'Наличие Иностранный склад | Отображает метку наличия промежуточного склада 1  в логистике | dm_calc.sd_sales_main_scm.FWH_EXIST_exp04';
comment on column dm.sd_sales_main_scm.dt_forwarder_discharge_invoice_or_cmr_documented is 'ТН/CMR: Дата выгрузки авто | Экспедиторская дата выгрузки автотранспорта | dm_calc.sd_sales_main_scm.DATAUNLOAD_exp03';
comment on column dm.sd_sales_main_scm.is_shipped_via_overseas_second_foreign_warehouse is 'Наличие Иностранный склад 2 | Отображает метку наличия промежуточного склада 2  в логистике | dm_calc.sd_sales_main_scm.RIVER_EU_exp04';
comment on column dm.sd_sales_main_scm.second_foreign_port_of_discharge_location_code is 'Иностранный порт 2 (код локации) | Отображает порт выгрузки 2 план/факт | dm_calc.sd_sales_main_scm.LOCID_FP2_exp03';
comment on column dm.sd_sales_main_scm.dt_arrived_via_ul_system is 'Дата прибытия УЛ | Отображает дату прибытия отправленную нам с интеграцией с Умной логистикой | dm_calc.sd_sales_main_scm.UL_ATA_DATE_exp03';
comment on column dm.sd_sales_main_scm.dt_repacked is 'Дата перетарки | Экспедиторская дата перетарки | dm_calc.sd_sales_main_scm.DATE_PERETAR_exp02';
comment on column dm.sd_sales_main_scm.warehouse_shipment_type_name is 'СВХ | Отображает тип СВХ: "На склад клиенту"; "Со склада клиенту" | dm_calc.sd_sales_main_scm.SVH_TXT_exp03';
comment on column dm.sd_sales_main_scm.warehouse_gross_weight is 'Вес брутто (с учетом склада) | Расчетный вес. Уменьшается с потреблением материала со склада | dm_calc.sd_sales_main_scm.BRUTTO_02_exp04';
comment on column dm.sd_sales_main_scm.railway_movement_status_name is 'Статус движения по ЖД | Статус движения по ЖД | dm_calc.sd_sales_main_scm.STATUS_ZHD_exp04';
comment on column dm.sd_sales_main_scm.business_location_sap_precalc_name is 'Статус в Supply chain (Business) | Статус в Supply chain (Business) | dm_calc.sd_sales_main_scm.STATUS_SCB_exp04';
comment on column dm.sd_sales_main_scm.second_foreign_port_of_discharge_plan_code is 'Плановый порт выгрузки 2 (код) | Плановая порт выгрузки 2 (код) | dm_calc.sd_sales_main_scm.KNOTE_PLAN2_exp03';
comment on column dm.sd_sales_main_scm.second_foreign_port_of_discharge_plan_name is 'Плановый порт выгрузки 2 | Плановая порт выгрузки 2 | dm_calc.sd_sales_main_scm.KNOTE_PLAN2_TXT_exp03';
comment on column dm.sd_sales_main_scm.foreign_port_of_discharge_location_code is 'Иностранный порт (код локации) | Отображает порт выгрузки 1 план/факт | dm_calc.sd_sales_main_scm.FWH_LOCID_exp04';
comment on column dm.sd_sales_main_scm.forwarder_instruction_code is 'Группа поручение | Номер группы поручения | dm_calc.sd_sales_main_scm.SAMMG_P_exp02';
comment on column dm.sd_sales_main_scm.shipment_type_for_reporting_name is 'Тип отгрузки | Тип отгрузки | "Container", если найден SDABW (тип транспортного средства) = TL04 (морской контейнер), иначе "Bulk"';
comment on column dm.sd_sales_main_scm.sales_team_code is 'Сбытовая команда (код) | Код сбытовой команды | dm_calc.sd_sales_main_scm.sales_team_code';
comment on column dm.sd_sales_main_scm.sales_team_name is 'Сбытовая команда | Наименование сбытовой команды | dm_calc.sd_sales_main_scm.sales_team_name';
comment on column dm.sd_sales_main_scm.pb1_number is 'Номер PB 1 | Внешняя идентификация 1-й накладной | dm_calc.sd_sales_main_scm.pb1_number';				
comment on column dm.sd_sales_main_scm.pb2_number is 'Номер PB 2 | Внешняя идентификация 2-й накладной | dm_calc.sd_sales_main_scm.pb2_number';				
comment on column dm.sd_sales_main_scm.pb3_number is 'Номер PB 3 | Внешняя идентификация 3-й накладной | dm_calc.sd_sales_main_scm.pb3_number';
comment on column dm.sd_sales_main_scm.pb1_warehouse_name is 'Склад PB 1 | Склад 1-й накладной | dm_calc.sd_sales_main_scm.pb1_warehouse_name';	
comment on column dm.sd_sales_main_scm.pb2_warehouse_name is 'Склад PB 2 | Склад 2-й накладной | dm_calc.sd_sales_main_scm.pb2_warehouse_name';	
comment on column dm.sd_sales_main_scm.pb3_warehouse_name is 'Склад PB 3 | Склад 3-й накладной | dm_calc.sd_sales_main_scm.pb3_warehouse_name';	
comment on column dm.sd_sales_main_scm.buyer_agent_code is 'Trading company (код) | Системный код промежуточного покупателя из клиентского лота | dm_calc.sd_sales_main_scm.buyer_agent_code';
comment on column dm.sd_sales_main_scm.buyer_agent_name is 'Trading company | Наименование промежуточного покупателя из клиентского лота | dm_calc.sd_sales_main_scm.buyer_agent_name';	
COMMENT ON COLUMN dm.sd_sales_main_scm.bis_license_number is '№ лицензии BIS | Лицензия BIS для поставок в Индию | dm_calc.sd_sales_main_scm.bis_license_number';
COMMENT ON COLUMN dm.sd_sales_main_scm.dislocation_id is 'ID_LEDISLOC | ID актуального события на пусти по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_id';									
COMMENT ON COLUMN dm.sd_sales_main_scm.disclocation_border_cross_railroad_code  is 'Дорога сдачи (код)	| Дорога сдачи Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.disclocation_border_cross_railroad_code';
COMMENT ON COLUMN dm.sd_sales_main_scm.disclocation_border_cross_railroad_name  is 'Дорога сдачи | Дорога сдачи Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.disclocation_border_cross_railroad_name';			
COMMENT ON COLUMN dm.sd_sales_main_scm.dislocation_railcar_operation_code  is 'Код операции | Код операции Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_railcar_operation_code';					
COMMENT ON COLUMN dm.sd_sales_main_scm.dislocation_railcar_operation_name  is 'Операции | Операции Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_railcar_operation_name';				
COMMENT ON COLUMN dm.sd_sales_main_scm.dislocation_railcar_operation_short_name  is 'Краткое название операции | Краткое название операции Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_railcar_operation_short_name';			
COMMENT ON COLUMN dm.sd_sales_main_scm.dt_dislocation_railcar_operation  is 'Дата операции | Дата операции Актуальное событие на пусти по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dt_dislocation_railcar_operation';							
COMMENT ON COLUMN dm.sd_sales_main_scm.dt_train_departure  is 'Дата начала рейса | Плановая дата начала отправления по ЖД с фактом | dm_calc.sd_sales_main_scm.dt_train_departure';										
COMMENT ON COLUMN dm.sd_sales_main_scm.dt_train_scheduled_arrival  is 'Плановая дата прибытия по ЖД (с фактом) | Плановая дата прибытия по ЖД (с фактом) | dm_calc.sd_sales_main_scm.dt_train_scheduled_arrival';			
COMMENT ON COLUMN dm.sd_sales_main_scm.tnved_code  is 'Код товара ТНВЭД | Код товара ТНВЭД | dm_calc.sd_sales_main_scm.tnved_code';
COMMENT ON COLUMN dm.sd_sales_main_scm.cargo_arrangement_scheme_registration_code is 'Рег. № схемы погрузки | Рег. № схемы погрузки | dm_calc.sd_sales_main_scm.cargo_arrangement_scheme_registration_code';
COMMENT ON COLUMN dm.sd_sales_main_scm.dt_cargo_arrangement_scheme is 'Дата схем погрузки | Дата схем погрузки | dm_calc.sd_sales_main_scm.dt_cargo_arrangement_scheme';
COMMENT ON COLUMN dm.sd_sales_main_scm.cargo_arrangement_scheme_name is '№ схемы погрузки | № схемы погрузки | dm_calc.sd_sales_main_scm.cargo_arrangement_scheme_name';
COMMENT ON COLUMN dm.sd_sales_main_scm.sales_request_created_by is 'Автор заказа ЦК из заявки (сотрудник Департамента сбыта, который отвечает за заявку клиента) | Автор заказа ЦК из заявки (сотрудник Департамента сбыта, который отвечает за заявку клиента) | dds.sales_request.sales_request_created_by';
