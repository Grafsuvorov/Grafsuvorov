drop table if exists dds.sales_request;

create table dds.sales_request
(
	dt_shipment_yyyymm varchar(6) null, 				-- Трейдеры: Месяц отгрузки с завода
	sales_request_code varchar(6) null, 				-- Заказ ЦК
	sales_market_code varchar(1) null, 					-- Трейдеры: рынок сбыта
	dt_delivered_to_customer date null, 				-- Фактическая дата получения заказа клиента
	sales_order_version_code varchar(2) null, 			-- Номер версии/корректировки заказа
	sales_contract_code varchar(30) NULL,				-- Контракт в заказе (код)
	payment_agent_code varchar(2) null,					-- Кто платит перевозчику (код)
	end_user_code varchar(10) null,						-- Потребитель (код)
	is_not_valid_for_reporting bool,					-- Индикатор: запись не применима для отчетности
	buyer_agent_code varchar(10) null,          		-- Промежуточный покупатель (Trading company) (код)
	tsw_location_code varchar(10) null,         		-- Направление (код)
	dt_quota_yyyymm varchar(6) null,         			-- Квота (период)
	incoterms_location_code varchar(28) null,   		-- Плановый пункт доставки по инкотермс (код)
	port_of_discharge_code varchar(10) null,   			-- Плановый порт выгрузки (код)
	port_of_discharge_name varchar(30) null,   			-- Плановый порт выгрузки
	customer_special_requirement varchar(50) null,  	-- Специальный заказ клиента
	contract_code varchar(35) null,  					-- Контракт (код)
	incoterms_code varchar(3) null,  					-- Плановый инкотермс (код)
	delivery_country_in_contract_code varchar(3) null,  -- Страна поставки по контракту (код)
	country_of_end_user_code varchar(3) null,  			-- Страна конечного потребителя (код)
	plant_producer_name varchar(10) null,  				-- Завод-производитель
	transport_type_code varchar(2) null,  				-- Тип контейнера (код)
	material_group_code varchar(9) null,				-- Группа материала (код)
	buyer_code varchar(10) null,						-- Покупатель (код)
	plant_producer_code varchar(4) null,				-- Завод-производитель (код)
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
 appendonly=true,
 orientation=column,
 compresstype=zstd,
 compresslevel=3
)
distributed by (sales_market_code, sales_order_version_code, sales_request_code, dt_shipment_yyyymm);

comment on table dds.sales_request is 'Заявка на продажу (Заказ ЦК)';
comment on column dds.sales_request.dt_shipment_yyyymm is 'Трейдеры: Месяц отгрузки с завода | Трейдеры: Месяц отгрузки с завода | ods."/rusal/sd2882m_ral".reg_perio';
comment on column dds.sales_request.sales_request_code is 'Заказ ЦК | Это системный номер заказаЦК в отгрузке | ods."/rusal/sd2882m_ral".zakaz_kl';
comment on column dds.sales_request.sales_market_code is 'Трейдеры: рынок сбыта | Трейдеры: рынок сбыта | ods."/rusal/sd2882m_ral".market';
comment on column dds.sales_request.dt_delivered_to_customer is 'Фактическая дата получения заказа клиента | Дата, когда получили доп.информацию по заказу  (данные опциона) от клиента | ods."/rusal/sd2882m_ral".fact_date_z';
comment on column dds.sales_request.sales_order_version_code is 'Номер версии/корректировки заказа | Номер версии/корректировки заказа | ods."/rusal/sd2882m_ral".numvr';
comment on column dds.sales_request.sales_contract_code is 'Контракт в заказе | Контракт в заказе | ods."/rusal/sd2882m_ral".vbeln_r';
comment on column dds.sales_request.payment_agent_code is 'Кто платит перевозчику (код) | Кто платит перевозчику (код) | ods."/rusal/sd2882m_ral".zperev';
comment on column dds.sales_request.end_user_code is 'Потребитель (код) | Потребитель (код) | ods."/rusal/sd2882m_ral".potreb';
comment on column dds.sales_request.is_not_valid_for_reporting is 'Индикатор: запись не применима для отчетности';
comment on column dds.sales_request.buyer_agent_code is 'Промежуточный покупатель (Trading company) (код) | Промежуточный покупатель (Trading company) (код) | ods."/rusal/sd2882m_ral".trader_buyer';
comment on column dds.sales_request.tsw_location_code is 'Направление (код) | Направление (код) | ods."/rusal/sd2882m_ral".locid';
comment on column dds.sales_request.dt_quota_yyyymm is 'Квота (период) | Квота (период) | ods."/rusal/sd2882m_ral".quota';
comment on column dds.sales_request.incoterms_location_code is 'Плановый пункт доставки по инкотермс (код) | Плановый пункт доставки по инкотермс (код) | ods."/rusal/sd2882m_ral".inco2';
comment on column dds.sales_request.port_of_discharge_code is 'Плановый порт выгрузки (код) | Плановый порт выгрузки (код) | ods."/rusal/sd2882m_ral".kod_end_loc';
comment on column dds.sales_request.port_of_discharge_name is 'Плановый порт выгрузки  | Плановый порт выгрузки  | ods."/rusal/sd2882m_ral".end_loc';
comment on column dds.sales_request.customer_special_requirement is 'Специальный заказ клиента | Специальный заказ клиента | ods."/rusal/sd2882m_ral".spec_order';
comment on column dds.sales_request.contract_code is 'Контракт (код) | Контракт (код) | ods."/rusal/sd2882m_ral".bstkd';
comment on column dds.sales_request.incoterms_code is 'Плановый инкотермс (код) | Плановый инкотермс (код) | ods."/rusal/sd2882m_ral".inco1';
comment on column dds.sales_request.delivery_country_in_contract_code is 'Страна поставки по контракту (код) | Страна поставки по контракту (код) | ods."/rusal/sd2882m_ral".deliv_land';
comment on column dds.sales_request.country_of_end_user_code is 'Страна конечного потребителя (код) | Страна конечного потребителя (код) | ods."/rusal/sd2882m_ral".potreb_land';
comment on column dds.sales_request.plant_producer_name is 'Завод-производитель | Завод-производитель | ods."/rusal/sd2882m_ral".werks_trade';
comment on column dds.sales_request.transport_type_code is 'Тип контейнера (код) | Тип контейнера (код) | ods."/rusal/sd2882m_ral".trader_sd_peretarka';
comment on column dds.sales_request.material_group_code is 'Группа материала (код) | Группа материала (код) | ods."/rusal/sd2882m_ral".matkl';
comment on column dds.sales_request.buyer_code is 'Покупатель (код) | Покупатель (код) | ods."/rusal/sd2882m_ral".buyer';
comment on column dds.sales_request.plant_producer_code is 'Завод-производитель (код) | Завод-производитель (код) | ods."/rusal/sd2882m_ral".werks';