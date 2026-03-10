INSERT INTO dm.sales_delivery_tracking (
	delivery_number_sales,								-- SD.000002 "Продажная поставка"
	batch,												-- SD.000004 "Партия"
	plant_producer_code,								-- SD.000006 "Завод производитель (код)"
	plant_producer_name,								-- SD.000007 "Завод"
	dt_shipment,										-- SD.000010 "Дата отгрузки"
	dt_arrival_by_railway,								-- SD.000011 "Дата прибытия по ЖД"
	dt_forwarder,										-- SD.000012 "Дата экспедитора"
	railcar,											-- SD.000013 "Вагон"
	transport_bill,										-- SD.000014 "Накладная"
	material_aggr_name,									-- SD.000016 "Материал"
	material_group_code,								-- SD.000017 "Группа материалов"
	dt_warehouse,										-- SD.000024 "Дата склада"
	transport_type_after_repackaging_code,				-- SD.000027 "Тип ПС после перетарки"
	transport_railcar_type_name,						-- SD.000029 "Тип вагона"
	nomination_in_russian_port_code_plan,				-- SD.000030 "Номинация РФ (план)
	weight_gross,										-- SD.000031 "Вес брутто"
	weight_net,											-- SD.000032 "Вес нетто"
	weight_net_with_wirerod,							-- SD.000033 "Вес Н&K"
	station_current,									-- SD.000034 "Текущая станция"
	station_destination,								-- SD.000035 "Станция назначения"
	customer_for_reporting_name,						-- SD.000037 "Покупатель"
	contract_name,										-- SD.000038 "Контракт"
	quota,												-- SD.000039 "Квота (техническая)"
	bill_of_lading_number,								-- SD.000041 "Номер коносамента"
	dt_bill_of_lading,									-- SD.000042 "Дата коносамента"
	bill_of_lading_route,								-- SD.000043 "Маршрут коносамента"
	nomination_actual,									-- SD.000046 "Номинация"
	status_description,									-- SD.000057 "Описание статуса"
	dimensions_unit,									-- SD.000079 "Размер единицы готовой продукции"
	consignee_name,										-- SD.000081 "Грузополучатель"
	end_user_name,										-- SD.000097 "Потребитель"
	distance_remaining,									-- SD.000122 "Оставшееся расстояние"
	sales_order,										-- SD.000123 "Заказ ЦК"
	dt_arrival_in_port_of_discharge_plan,				-- SD.000130 "Дата прибытия в порт выгрузки план"
	vessel_actual_name,									-- SD.000138 "Судно факт"
	material_code,										-- SD.000143 "Номер материала"
	customer_grade_name,								-- SD.000144 "Марка клиента"
	grade_name,											-- SD.000145 "Марка по спецификации"
	uni,												-- SD.000151 "UNI"
	uni_in_shipment,									-- SD.000152 "UNI в отгрузке"
	status_al2all,										-- SD.000161 "Статус для портала AL2ALL"
	production_order,									-- SD.000174 "Производственный заказ"
	material_shape_name_full,							-- SD.000180 "Форма"
	material_name,										-- SD.000200 "Наименование материала"
	region_of_destination_port_name,					-- SD.000343 "Регион POD"
	business_location_name,								-- SD.000492 "Статус в Supply chain (Business)"
	forwarder_instruction_code,							-- SD.000509 "Группа поручение"
	exporter_name,										-- SD.000600 "Экспортер"
	country_of_customer_name,							-- SD.000644 "Страна покупателя"
	port_of_loading_name,								-- SD.000653 "Порт погрузки"
	dislocation_id,										-- SD.000689 "ID_LEDISLOC"
	disclocation_border_cross_railroad_code,			-- SD.000690 "Дорога сдачи (код)"
	disclocation_border_cross_railroad_name,			-- SD.000691 "Дорога сдачи"
	dislocation_railcar_operation_code,					-- SD.000692 "Код операции"
	dislocation_railcar_operation_name,					-- SD.000693 "Операция"
	dislocation_railcar_operation_short_name,			-- SD.000694 "Краткое название операции"
	dt_dislocation_railcar_operation,					-- SD.000695 "Дата операции"	
	dt_train_departure,									-- SD.000696 "Дата начала рейса"			
	dt_train_scheduled_arrival,							-- SD.000697 "Плановая дата прибытия по ЖД (с фактом)"
	dt_estimated_arrival_to_russian_port,				-- SD.000698 "Прогнозная дата приемки в порту РФ"
	tnved_code,											-- SD.000699 "Код товара ТНВЭД"
	shipment_type_name,									-- SD.000702 "Тип вывоза из РФ"
	-------------------------------------------------------------------------------------------------------------------------
	dt_updated,											-- Дата и время последнего изменения на источнике для 20-минутки
	-------------------------------------------------------------------------------------------------------------------------
	dttm_inserted,
	dttm_updated,
	job_name,
	deleted_flag
)
SELECT --dc_ssms.delivery_number_sales, dc_ssms.batch, count()
	dc_ssms.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	dc_ssms.batch,												-- SD.000004 "Партия"
	dc_ssms.plant_producer_code,								-- SD.000006 "Завод производитель (код)"
	dc_ssms.plant_producer_name,								-- SD.000007 "Завод"
	dc_ssms.dt_shipment,										-- SD.000010 "Дата отгрузки"
	dc_ssms.dt_arrival_by_railway,								-- SD.000011 "Дата прибытия по ЖД"
	dc_ssms.dt_forwarder,										-- SD.000012 "Дата экспедитора"
	dc_ssms.railcar,											-- SD.000013 "Вагон"
	dc_ssms.transport_bill,										-- SD.000014 "Накладная"
	dc_ssms.material_aggr_name,									-- SD.000016 "Материал"
	dc_ssms.material_group_code,								-- SD.000017 "Группа материалов"
	dc_ssms.dt_warehouse,										-- SD.000024 "Дата склада"
	dc_ssms.transport_type_after_repackaging_code,				-- SD.000027 "Тип ПС после перетарки"
	dc_ssms.transport_railcar_type_name,						-- SD.000029 "Тип вагона"
	dc_ssms.nomination_in_russian_port_code_plan,				-- SD.000030 "Номинация РФ (план)
	dc_ssms.weight_gross,										-- SD.000031 "Вес брутто"
	dc_ssms.weight_net,											-- SD.000032 "Вес нетто"
	dc_ssms.weight_net_with_wirerod,							-- SD.000033 "Вес Н&K"
	dc_ssms.station_current,									-- SD.000034 "Текущая станция"
	dc_ssms.station_destination,								-- SD.000035 "Станция назначения"
	dc_ssms.customer_for_reporting_name,						-- SD.000037 "Покупатель"
	dc_ssms.contract_name,										-- SD.000038 "Контракт"
	dc_ssms.quota,												-- SD.000039 "Квота (техническая)"
	dc_ssms.bill_of_lading_number,								-- SD.000041 "Номер коносамента"
	dc_ssms.dt_bill_of_lading,									-- SD.000042 "Дата коносамента"
	dc_ssms.bill_of_lading_route,								-- SD.000043 "Маршрут коносамента"
	dc_ssms.nomination_actual,									-- SD.000046 "Номинация"
	dc_ssms.status_description,									-- SD.000057 "Описание статуса"
	dc_ssms.dimensions_unit,									-- SD.000079 "Размер единицы готовой продукции"
	dc_ssms.consignee_name,										-- SD.000081 "Грузополучатель"
	dc_ssms.end_user_name,										-- SD.000097 "Потребитель"
	dc_ssms.distance_remaining,									-- SD.000122 "Оставшееся расстояние"
	dc_ssms.sales_order,										-- SD.000123 "Заказ ЦК"
	dc_ssms.dt_arrival_in_port_of_discharge_plan,				-- SD.000130 "Дата прибытия в порт выгрузки план"
	dc_ssms.vessel_actual_name,									-- SD.000138 "Судно факт"
	dc_ssms.material_code,										-- SD.000143 "Номер материала"
	dc_ssms.customer_grade_name,								-- SD.000144 "Марка клиента"
	dc_ssms.grade_name,											-- SD.000145 "Марка по спецификации"
	dc_ssms.uni,												-- SD.000151 "UNI"
	dc_ssms.uni_in_shipment,									-- SD.000152 "UNI в отгрузке"
	dc_ssms.status_al2all,										-- SD.000161 "Статус для портала AL2ALL"
	dc_ssms.production_order,									-- SD.000174 "Производственный заказ"
	dc_ssms.material_shape_name_full,							-- SD.000180 "Форма"
	dc_ssms.material_name,										-- SD.000200 "Наименование материала"
	dc_ssms.region_of_destination_port_name,					-- SD.000343 "Регион POD"
	dc_ssms.business_location_name,								-- SD.000492 "Статус в Supply chain (Business)"
	dc_ssms.forwarder_instruction_code,							-- SD.000509 "Группа поручение"
	dc_ssms.exporter_name,										-- SD.000600 "Экспортер"
	dc_ssms.country_of_customer_name,							-- SD.000644 "Страна покупателя"
	dc_ssms.port_of_loading_name,								-- SD.000653 "Порт погрузки"
	dc_ssms.dislocation_id,										-- SD.000689 "ID_LEDISLOC"
	dc_ssms.disclocation_border_cross_railroad_code,			-- SD.000690 "Дорога сдачи (код)"
	dc_ssms.disclocation_border_cross_railroad_name,			-- SD.000691 "Дорога сдачи"
	dc_ssms.dislocation_railcar_operation_code,					-- SD.000692 "Код операции"
	dc_ssms.dislocation_railcar_operation_name,					-- SD.000693 "Операция"
	dc_ssms.dislocation_railcar_operation_short_name,			-- SD.000694 "Краткое название операции"
	dc_ssms.dt_dislocation_railcar_operation,					-- SD.000695 "Дата операции"	
	dc_ssms.dt_train_departure,									-- SD.000696 "Дата начала рейса"			
	dc_ssms.dt_train_scheduled_arrival,							-- SD.000697 "Плановая дата прибытия по ЖД (с фактом)"
	dc_ssms.dt_estimated_arrival_to_russian_port,				-- SD.000698 "Прогнозная дата приемки в порту РФ"
	dc_ssms.tnved_code,											-- SD.000699 "Код товара ТНВЭД"
	dc_sda2.shipment_type_name,									-- SD.000702 "Тип вывоза из РФ"
	-------------------------------------------------------------------------------------------------------------------------
	dc_ssms.dt_updated,											-- Дата и время последнего изменения на источнике для 20-минутки
	-------------------------------------------------------------------------------------------------------------------------
	dc_ssms.dttm_inserted,
	dc_ssms.dttm_updated,
	dc_ssms.job_name,
	dc_ssms.deleted_flag
FROM 
	dm_calc.sd_sales_main_scm AS dc_ssms
LEFT JOIN 
	dm_calc.sales_delivery_actual_part_2 AS dc_sda2
	ON dc_ssms.batch = dc_sda2.batch
		AND dc_ssms.delivery_number_sales = dc_sda2.delivery_number_sales
/*GROUP BY 
	dc_ssms.delivery_number_sales, 
	dc_ssms.batch
HAVING 
	count() > 1*/
;