insert into dds.sales_request
(dt_shipment_yyyymm, sales_request_code, sales_market_code, dt_delivered_to_customer, sales_order_version_code, sales_contract_code, payment_agent_code,
end_user_code, is_not_valid_for_reporting, buyer_agent_code, tsw_location_code, dt_quota_yyyymm, incoterms_location_code, port_of_discharge_code,
port_of_discharge_name, customer_special_requirement, contract_code, incoterms_code, delivery_country_in_contract_code, country_of_end_user_code,
plant_producer_name, transport_type_code, material_group_code, buyer_code, plant_producer_code)

select
	reg_perio as dt_shipment_yyyymm, 				-- Трейдеры: Месяц отгрузки с завода
	zakaz_kl as sales_request_code, 					-- Заказ ЦК
	market as sales_market_code, 					-- Трейдеры: рынок сбыта
	fact_date_z as dt_sales_order_delivery_actual, 	-- Фактическая дата получения заказа клиента
	numvr  as sales_order_version_code, 			-- Номер версии/корректировки заказа
	vbeln_r as sales_contract_code,					-- Контракт в заказе (код)
	zperev as payment_agent_code,					-- Кто платит перевозчику (код)
	potreb as end_user_code,						-- Потребитель (код)
	case 
		when 
			row_number () over (partition by reg_perio, zakaz_kl order by numlinevr desc, fact_date_z) <> 1 -- Индикатор: запись не применима для отчетности
		then true 
		else false
	end as is_not_valid_for_reporting,
	trader_buyer as buyer_agent_code,				-- Промежуточный покупатель (Trading company) (код)
	locid as tsw_location_code,						-- Направление (код)
	quota as dt_quota_yyyymm,						-- Квота (период)
	inco2 as incoterms_location_code,				-- Плановый пункт доставки по инкотермс (код)
	kod_end_loc as port_of_discharge_code,			-- Плановый порт выгрузки (код)
	end_loc as port_of_discharge_name,				-- Плановый порт выгрузки
	spec_order as customer_special_requirement,		-- Специальный заказ клиента
	bstkd as contract_code,							-- Контракт (код)
	inco1 as incoterms_code,						-- Плановый инкотермс (код)
	deliv_land as delivery_country_in_contract_code,-- Страна поставки по контракту (код)
	potreb_land as country_of_end_user_code,		-- Страна конечного потребителя (код)
	werks_trade as plant_producer_name,				-- Завод-производитель
	sd_peretarka as transport_type_code,			-- Тип контейнера (код)
	matkl as material_group_code,					-- Группа материала (код)
	buyer as buyer_code,							-- Покупатель (код)
	werks as plant_producer_code 					-- Завод-производитель (код)
from ods."/rusal/sd2882m_ral"
where numvr = '00'
;
