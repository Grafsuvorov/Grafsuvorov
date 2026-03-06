INSERT INTO dm.sd_sales_to_india_scm (
	delivery_number_sales,									-- SD.000002 "Продажная поставка"
	plant_producer_name,									-- SD.000007 "Завод"
	port_of_loading_code,									-- SD.000008 "Направление (код)"
	dt_shipment,											-- SD.000010 "Дата отгрузки"
	material_aggr_name,										-- SD.000016 "Материал"
	weight_net,												-- SD.000032 "Вес нетто"
	customer_for_reporting_name,							-- SD.000037 "Покупатель"
	contract_name,											-- SD.000038 "Контракт"
	bill_of_lading_number,									-- SD.000041 "Номер коносамента"
	dimensions_unit,										-- SD.000079 "Размер единицы готовой продукции"
	material_specification_name,							-- SD.000089 "Спецификация"
	sales_order,											-- SD.000123 "Заказ ЦК"
	customer_grade_name,									-- SD.000144 "Марка клиента"
	end_user_name,											-- SD.000164 "Конечный потребитель"
	invoice_provisional_number,								-- SD.000167 "Инвойс (счет клиенту)"
	material_shape_name_full,								-- SD.000180 "Форма"
	port_of_destination_name,								-- SD.000376 "Порт назначения"
	country_of_customer_name,								-- SD.000644 "Страна покупателя"
	port_of_destination_code,								-- SD.000645 "Порт назначения (код)"
	dt_port_of_destination_arrival,							-- SD.000659 "Дата прибытия в порт назначения"
	bis_license_number,										-- SD.000729 "№ лицензии BIS"
	postal_code_of_buyer_code,								-- SD.000730 "Почтовый индекс покупателя"
	bill_of_lading_in_delivery_country_code,				-- SD.001054 "Группа коносамента страны поставки"
	bill_of_lading_in_delivery_country_number,				-- SD.001055 "Коносамент страны поставки"
	dt_bill_of_lading_in_delivery_country, 					-- SD.001056 "Дата коносамента страны поставки"
	dt_vessel_arrived_to_delivery_country,					-- SD.001057 "Дата прихода в порт выгрузки страны поставки"
	bill_of_lading_in_delivery_country_nomination_code,		-- SD.001058 "Номинация коносамента в страну поставки"
	vessel_in_delivery_country_actual_code,					-- SD.001059 "Судно факт страны поставки (код)"
	vessel_in_delivery_country_actual_name					-- SD.001060 "Судно факт страны поставки"
	)
WITH dc_sda AS (
	SELECT
		dc_sda.delivery_number_sales,							-- SD.000002 "Продажная поставка"
		dc_sda.plant_producer_name,								-- SD.000007 "Завод"
		dc_sda.tsw_location_code AS port_of_loading_code,		-- SD.000008 "Направление (код)"
		dc_sda.dt_shipment,										-- SD.000010 "Дата отгрузки"
		dc_sda.material_aggr_name,								-- SD.000016 "Материал"
		dc_sda.weight_net,										-- SD.000032 "Вес нетто"
		dc_sda.customer_for_reporting_name,						-- SD.000037 "Покупатель"
		dc_sda.contract_name,									-- SD.000038 "Контракт"
		dc_sda.bill_of_lading_number,							-- SD.000041 "Номер коносамента"
		dc_sda.dimensions_unit,									-- SD.000079 "Размер единицы готовой продукции"
		dc_sda.material_specification_name,						-- SD.000089 "Спецификация"
		dc_sda.sales_order,										-- SD.000123 "Заказ ЦК"
		dc_sda.customer_grade_name,								-- SD.000144 "Марка клиента"
		dc_sda.end_user_for_reporting_name AS end_user_name,	-- SD.000164 "Конечный потребитель"
		dc_sda.invoice_provisional_number,						-- SD.000167 "Инвойс (счет клиенту)"
		dc_sda.material_shape_name_full,						-- SD.000180 "Форма"
		dc_sda.port_of_destination_name,						-- SD.000376 "Порт назначения"
		dc_sda.country_of_customer_name,						-- SD.000644 "Страна покупателя"
		dc_sda.port_of_destination_code,						-- SD.000645 "Порт назначения (код)"
		dc_sda.dt_port_of_destination_arrival,					-- SD.000659 "Дата прибытия в порт назначения"
		dc_sda.bis_license_number,								-- SD.000729 "№ лицензии BIS"
		dc_sda.postal_code_of_buyer_code,						-- SD.000730 "Почтовый индекс покупателя"
		CASE
			WHEN dc_sda.country_of_discharge_port_code = 				-- Если SD.000340 "Страна POD (код)" =
				dc_sda.delivery_country_in_contract_code				-- SD.000577 "Страна поставки по контракту (код)",
				THEN dc_sda.bill_of_lading_group_code					-- то SD.000040 "Группа коносамента"
			WHEN dc_sda.second_port_of_discharge_country_code = 		-- Если SD.000768 Страна порт выгрузки 2 (код)" =
				dc_sda.delivery_country_in_contract_code				-- SD.000577 "Страна поставки по контракту (код)",
				THEN dc_sda.bill_of_lading_group_code_in_foreign_port	-- то SD.000047 "Группа коносамента в ин.порту"
			ELSE NULL													-- иначе пусто
		END AS bill_of_lading_in_delivery_country_code			-- SD.001054 "Группа коносамента страны поставки"
	FROM
		dm_calc.sd_sales_main_scm AS dc_sda
	WHERE
		dc_sda.country_of_destination_port_code	= 'IN'
	)
SELECT
	dc_sda.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	dc_sda.plant_producer_name,									-- SD.000007 "Завод"
	dc_sda.port_of_loading_code,								-- SD.000008 "Направление (код)"
	dc_sda.dt_shipment,											-- SD.000010 "Дата отгрузки"
	dc_sda.material_aggr_name,									-- SD.000016 "Материал"
	dc_sda.weight_net,											-- SD.000032 "Вес нетто"
	dc_sda.customer_for_reporting_name,							-- SD.000037 "Покупатель"
	dc_sda.contract_name,										-- SD.000038 "Контракт"
	dc_sda.bill_of_lading_number,								-- SD.000041 "Номер коносамента"
	dc_sda.dimensions_unit,										-- SD.000079 "Размер единицы готовой продукции"
	dc_sda.material_specification_name,							-- SD.000089 "Спецификация"
	dc_sda.sales_order,											-- SD.000123 "Заказ ЦК"
	dc_sda.customer_grade_name,									-- SD.000144 "Марка клиента"
	dc_sda.end_user_name,										-- SD.000164 "Конечный потребитель"
	dc_sda.invoice_provisional_number,							-- SD.000167 "Инвойс (счет клиенту)"
	dc_sda.material_shape_name_full,							-- SD.000180 "Форма"
	dc_sda.port_of_destination_name,							-- SD.000376 "Порт назначения"
	dc_sda.country_of_customer_name,							-- SD.000644 "Страна покупателя"
	dc_sda.port_of_destination_code,							-- SD.000645 "Порт назначения (код)"
	dc_sda.dt_port_of_destination_arrival,						-- SD.000659 "Дата прибытия в порт назначения"
	dc_sda.bis_license_number,									-- SD.000729 "№ лицензии BIS"
	dc_sda.postal_code_of_buyer_code,							-- SD.000730 "Почтовый индекс покупателя"
	dc_sda.bill_of_lading_in_delivery_country_code,				-- SD.001054 "Группа коносамента страны поставки"
	d_bol.bill_of_lading_number 						-- VBSK-VTEXT
		AS bill_of_lading_in_delivery_country_number,			-- SD.001055 "Коносамент страны поставки"
	d_bol.dt_bill_of_lading 							-- VBSK-ZZLDDAT
		AS dt_bill_of_lading_in_delivery_country, 				-- SD.001056 "Дата коносамента страны поставки"
	d_bol.dt_vessel_arrival_to_destination_port 		-- VBSK-ZZARRDP
		AS dt_vessel_arrived_to_delivery_country,				-- SD.001057 "Дата прихода в порт выгрузки страны поставки"
	d_bol.nomination_code 								-- VBSK-ZZNOMTK
		AS bill_of_lading_in_delivery_country_nomination_code,	-- SD.001058 "Номинация коносамента в страну поставки"
	d_n.vessel_code 									-- OIJNOMH-NMVEHICLE
		AS vessel_in_delivery_country_actual_code,				-- SD.001059 "Судно факт страны поставки (код)"
	dd_tvt.vessel_name									-- OIGVT-VEH_TEXT
		AS vessel_in_delivery_country_actual_name				-- SD.001060 "Судно факт страны поставки"
FROM
	dc_sda
-- SD.001055 "Коносамент страны поставки" -- SD.001056 "Дата коносамента страны поставки"
-- SD.001057 "Дата прихода в порт выгрузки страны поставки" -- SD.001058 "Номинация коносамента в страну поставки"
LEFT JOIN
	dds.bill_of_lading AS d_bol														-- VBSK
	ON d_bol.bill_of_lading_code = dc_sda.bill_of_lading_in_delivery_country_code	-- по VBSK-SAMMG = SD.001054 "Группа коносамента страны поставки"
-- SD.001059 "Судно факт страны поставки (код)"
LEFT JOIN
	dds.nomination AS d_n 															-- OIJNOMH
	ON d_n.nomination_code = d_bol.nomination_code									-- по OIJNOMH-NOMTK = SD.001058 "Номинация коносамента в страну поставки"
-- SD.001060 "Судно факт страны поставки"
LEFT JOIN
	dict_dds.transport_vehicle_texts AS dd_tvt 										-- OIGVT
	ON dd_tvt.vessel_code = d_n.vessel_code 										-- по OIGVT-VEHICLE = SD.001059 "Судно факт страны поставки (код)"
		AND dd_tvt.language_code = 'E'												-- и OIGVT-LANGUAGE = 'RU'
WHERE
	dc_sda.dt_shipment >= '2023-10-01'
;