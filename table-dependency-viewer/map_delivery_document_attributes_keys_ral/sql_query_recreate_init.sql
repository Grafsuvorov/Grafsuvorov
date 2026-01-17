drop table if exists ods.map_delivery_document_attributes_keys_ral;

create table ods.map_delivery_document_attributes_keys_ral (  -- ключ dt_shipped_yyyymm, delivery_code
	delivery_code 									varchar(10) not null,  
	dt_shipped_yyyymm 								varchar(6) not null,  
	transport_departure_hub_code 					varchar(10) null,  
	transport_destination_hub_code 					varchar(10) null,  
	port_of_destination_code 						varchar(10) null,  
	transport_border_cross_hub_code 				varchar(10) null,  
	etsng_code 										varchar(6) null,  
	is_pickup_at_plant 								varchar(1) null,  
	material_code 									varchar(18) null,  
	sector_code 									varchar(2) null,  
	complected_train_code 							varchar(2) null,  
	shipment_type_code 								varchar(2) null,  
	transport_scheme_code 							varchar(7) null,  
	forwarder_at_plant_code 						varchar(10) null,  
	is_transferrable_expenses 						varchar(1) null,  
	incoterms_plan_code 							varchar(3) null,
	is_owned_by_rusal_code							varchar(1) null,
	load_waybill_documented_weight 					numeric(13,3) default 0,  
	load_calculated_weight 							numeric(13,3) default 0,  
	carrying_capacity_for_tariff_planning_weight 	numeric(2,0) default 0,
	complected_train_quantity_index_code 			varchar(1) null,
	sales_order_code								varchar(30) null, 
	sales_order_plant_code							varchar(10) null, 
	dt_updated 										timestamp null,	--Дата и время последнего изменения на источнике
	is_container_owned_by_forwarder_code 			varchar(2) null,				-- Принадлежность контейнера (код)
	is_platform_owned_by_forwarder_code				varchar(2) null,				-- Принадлежность платформы (код)
	container_length_type_code						varchar(1) null,				-- Футовость контейнера (код)
	forwarder_at_railway_code 						varchar(10) null,				-- Экспедитор ЖД (код)
	port_of_departure_code 							varchar(10) null,				-- Порт погрузки (код)
	transport_subtype_code 							varchar(4) null,
	transport_capacity_amount 						numeric(13, 3) null,
	dttm_inserted 		timestamp not null default now(),
	dttm_updated 		timestamp not null default now(),
	job_name 			varchar(60) not null default 'airflow'::character varying,
	deleted_flag 		bool not null default false 
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by(delivery_code);

comment on table ods.map_delivery_document_attributes_keys_ral is 'Параметры отгрузки';
comment on column ods.map_delivery_document_attributes_keys_ral.delivery_code is 'Поставка | Поставка | ZLE_SD3332M_DATA.VBELN';
comment on column ods.map_delivery_document_attributes_keys_ral.dt_shipped_yyyymm is 'Период (годмесяц) | Период (годмесяц) | ZLE_SD3332M_DATA.PERIOD';
comment on column ods.map_delivery_document_attributes_keys_ral.transport_departure_hub_code is 'Узел  отправки | Узел  отправки | ZLE_SD3332M_DATA.ZZKNOTA';
comment on column ods.map_delivery_document_attributes_keys_ral.transport_destination_hub_code is 'Узел назначения | Узел назначения | ZLE_SD3332M_DATA.ZZKNOTZ3';
comment on column ods.map_delivery_document_attributes_keys_ral.port_of_destination_code is 'Узел Порт назначения | Узел Порт назначения | ZLE_SD3332M_DATA.ZZPORTNOTRF';
comment on column ods.map_delivery_document_attributes_keys_ral.transport_border_cross_hub_code is 'Узел Погранпереход | Узел Погранпереход | ZLE_SD3332M_DATA.ZZKNOTE_BRD';
comment on column ods.map_delivery_document_attributes_keys_ral.etsng_code is 'Код ЕТСНГ | Код ЕТСНГ | ZLE_SD3332M_DATA.ZZETSNG';
comment on column ods.map_delivery_document_attributes_keys_ral.is_pickup_at_plant is 'Самовывоз | Самовывоз | ZLE_SD3332M_DATA.PICKUP';
comment on column ods.map_delivery_document_attributes_keys_ral.material_code is 'Материал (код) | Материал (код) | ZLE_SD3332M_DATA.MATNR';
comment on column ods.map_delivery_document_attributes_keys_ral.sector_code is 'Сектор - группа материала (код) | Сектор - группа материала (код) | ZLE_SD3332M_DATA.ZZSPART';
comment on column ods.map_delivery_document_attributes_keys_ral.complected_train_code is 'Комплектность | Комплектность | ZLE_SD3332M_DATA.ZZSET';
comment on column ods.map_delivery_document_attributes_keys_ral.shipment_type_code is 'Вид отгрузки | Вид отгрузки | ZLE_SD3332M_DATA.ZZVSART';
comment on column ods.map_delivery_document_attributes_keys_ral.transport_scheme_code is 'Схема перевозки | Схема перевозки | ZLE_SD3332M_DATA.SCHEME';
comment on column ods.map_delivery_document_attributes_keys_ral.forwarder_at_plant_code is 'Экспедитор по ж/д | Экспедитор по ж/д | ZLE_SD3332M_DATA.LIFNR_ZHD';
comment on column ods.map_delivery_document_attributes_keys_ral.is_transferrable_expenses is 'Возмещаемые расходы | Возмещаемые расходы | ZLE_SD3332M_DATA.ZTR_RECOV';
comment on column ods.map_delivery_document_attributes_keys_ral.incoterms_plan_code is 'Инкотермс, часть 1 | Инкотермс, часть 1 | ZLE_SD3332M_DATA.INCO1';
comment on column ods.map_delivery_document_attributes_keys_ral.load_waybill_documented_weight is 'Фактическая загрузка по накладная-вагон | Фактическая загрузка по накладная-вагон | ZLE_SD3332M_DATA.VES_NAT';
comment on column ods.map_delivery_document_attributes_keys_ral.load_calculated_weight is 'Фактическая загрузка | Фактическая загрузка | ZLE_SD3332M_DATA.VES_RAS';
comment on column ods.map_delivery_document_attributes_keys_ral.carrying_capacity_for_tariff_planning_weight is 'Грузоподъёмность для определения тарифа | Грузоподъёмность для определения тарифа | ZLE_SD3332M_DATA.ZZGRUZ';
comment on column ods.map_delivery_document_attributes_keys_ral.complected_train_quantity_index_code is 'Индекс кол-ва ПС | Индекс кол-ва ПС | ZLE_SD3332M_DATA.ZZINDEX';
comment on column ods.map_delivery_document_attributes_keys_ral.sales_order_code is '№ заказа ЦК | № заказа ЦК | ZLE_SD3332M_DATA.ZAKAZ_KL';
comment on column ods.map_delivery_document_attributes_keys_ral.sales_order_plant_code is 'Заказ завода | Заказ завода | ZLE_SD3332M_DATA.ZAKAZ_KL_L';
comment on column ods.map_delivery_document_attributes_keys_ral.dt_updated is 'Дата и время последнего изменения на источнике | Дата и время последнего изменения на источнике | ZLE_SD3332M_DATA.CRDATE, CRTIME';
comment on column ods.map_delivery_document_attributes_keys_ral.is_owned_by_rusal_code is 'Собственный ПС | Да, если ПС стоит на балансе компании | ZLE_SD3332M_DATA.HOME_VAGON';
comment on column ods.map_delivery_document_attributes_keys_ral.is_container_owned_by_forwarder_code is 'Принадлежность контейнера (код) | Принадлежность контейнера (код) | ZLE_SD3332M_DATA.ZZPR_CONT';
comment on column ods.map_delivery_document_attributes_keys_ral.is_platform_owned_by_forwarder_code is 'Принадлежность платформы (код) | Принадлежность платформы (код) | ZLE_SD3332M_DATA.ZZPR_PL';
comment on column ods.map_delivery_document_attributes_keys_ral.container_length_type_code is 'Футовость контейнера (код) | Футовость контейнера (код) | ZLE_SD3332M_DATA.ZZLENGTH';
comment on column ods.map_delivery_document_attributes_keys_ral.forwarder_at_railway_code is 'Экспедитор ЖД (код) | Экспедитор ЖД (код) | ZLE_SD3332M_DATA.LIFNR_ZHD';
comment on column ods.map_delivery_document_attributes_keys_ral.port_of_departure_code is 'Порт погрузки (код) | Порт погрузки (код) | ZLE_SD3332M_DATA.ZZPORTRF';
comment on column ods.map_delivery_document_attributes_keys_ral.transport_subtype_code is 'Вид транспортного средства | Вид транспортного средства | ZLE_SD3332M_DATA.ZZTRATY';
comment on column ods.map_delivery_document_attributes_keys_ral.transport_capacity_amount is 'Полная Грузоподъемность ПС | Полная Грузоподъемность ПС | ZLE_SD3332M_DATA.ZZGRUZ_F';
