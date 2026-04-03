INSERT INTO dds.sales_batch_delivery(
	batch_code,
	delivery_number_initial,
	shipment_entry_from_file_code,
	delivery_number_of_plant_producer,
	sales_order_in_shipment,
	plant_producer_code, 
	railcar_code,
	railway_platform_code,
	material_code,
	market_in_shipment_code,
	forwarder_in_contract_code,
	dt_stamp_railway_bill,
	dt_arrival_to_plant,
	dt_conversion_from_import_to_export,
	seal_number,
	fixing_holder_weight,
	receiving_plant_in_sap_system_code,
	customer_code,
	contract_export_number,
	unit_dimensions,
	consignee_code,
	consignee_name,
	railcar_internal_code,
	route_in_shipment_code,
	discharge_terminal_code,
	destination_station_code,
	quarantine_certificate_number,
	dt_quarantine_certificate,
	cargo_package_quantity,
	receiving_warehouse_code,
	weight_net_with_wirerod,
	plant_owner_code,
	station_of_departure_code,
	instruction_number,
	delivery_number_of_plant_owner,
	dt_created,
	finish_good_unit_length,finish_good_unit_width,
	finish_good_unit_height,
	finish_good_unit_diameter,
	quality_certificate_number,
	delivery_item_number_of_plant_producer,
	dt_order_picking,
	station_of_destination_name,
	foil_box_number,
	route_code,
	dt_forwarder,
	plant_name,
	gtd_number,
	dt_storage_start_in_warehouse,
	package_weight,
	buyer_code,
	forwarder_name,
	end_user_code,
	shipment_entry_identifier_from_file,
	exporter_code,
	tsw_location_code,
	dt_shipment,
	shipment_type_code,
	dt_border_cross,
	sales_plant_contract_code,
	weight_gross,
	weight_net,
	is_plant_not_in_sap_system,
	temporary_warehouse_movement_type_code,
	is_not_valid_for_reporting
)
select 
	rs.charg as batch_code,									-- Партия 
	rs.vbeln as delivery_number_initial, 					-- Исходная поставка
	rs.ident as shipment_entry_from_file_code, 				-- Идентификатор записи об отгрузке из файла
	rs.vbeln_lf as delivery_number_of_plant_producer, 		-- Номер поставки завода производителя
	rs.order_ as sales_order_in_shipment,					-- Заказ ЦК в отгрузке
	rs.plant as plant_producer_code,						-- Завод производитель (код)
	rs.vagon as railcar_code,								-- Вагон
	rs.platf as railway_platform_code,						-- Платформа
	rs.gradecod as material_code, 							-- Код материала
	rs.market as market_in_shipment_code,					-- Рынок в отгрузке (код)
	rs.expedidsub as forwarder_in_contract_code,			-- Экспедитор Договорной (код) 
	rs.shtempel_date as dt_stamp_railway_bill, 				-- Дата штемпеля по ЖДН 
	rs.prih_zavod_date as dt_arrival_to_plant, 				-- Дата прихода на завод 
	rs.impexp_date as dt_conversion_from_import_to_export, 	-- Дата перехода из импорта в экспорт
	rs.nstamp as seal_number,								-- Номера пломб
	rs.rekvizit as fixing_holder_weight,					-- Реквизит/Вес крепления груза
	rs.werks as receiving_plant_in_sap_system_code,			-- Принимающий завод грузополучателя в системе SAP
	rs.customid as customer_code, 							-- Заказчик
	rs.contrexp as contract_export_number,					-- Номер экспортного контракта
	rs.razmer as unit_dimensions,							-- Размер единицы готовой продукции
	rs.firmapid as consignee_code,							-- Код грузополучателя материала
	rs.firmap as consignee_name,							-- Наименование грузополучателя материала
	rs.idw1 as railcar_internal_code,						-- Idw1
	rs.route as route_in_shipment_code,						-- Маршрут в отгрузке
	rs.unl_term as discharge_terminal_code,					-- Код терминала разгрузки
	rs.stationnc as destination_station_code,				-- Код станции назначения
	rs.quar_sert as quarantine_certificate_number,			-- Карантинный сертификат 
	rs.quar_date as dt_quarantine_certificate, 				-- Дата карантинного сертификата
	rs.mest as cargo_package_quantity,						-- Количество грузовых мест
	rs.lgort as receiving_warehouse_code,					-- Принимающий склад
	rs.nk as weight_net_with_wirerod, 						-- Вес нетто + катанка
	rs.plant1 as plant_owner_code,							-- Завод собственник (код)
	rs.stationo as station_of_departure_code,				-- Станция отправления
	rs.raspor as instruction_number,						-- Номер распоряжения
	rs.vbeln_lfs as delivery_number_of_plant_owner,			-- Номер поставки завода собственника 
	rs.dateadd as dt_created, 								-- Дата первого появления записи в системе
	rs."length" as finish_good_unit_length,					-- Длина единицы готовой продукции
	rs."width" as finish_good_unit_width,					-- Ширина единицы готовой продукции
	rs."height" as finish_good_unit_height,					-- Высота единицы готовой продукции
	rs."diameter" as finish_good_unit_diameter,				-- Диаметр единицы готовой продукции
	rs.nsert as quality_certificate_number,					-- Номер сертификата
	rs.posnr_lf as delivery_item_number_of_plant_producer,	-- Позиция поставки завода производителя
	rs.kodat as dt_order_picking, 							-- Дата комплектования
	rs.stationn as station_of_destination_name,				-- Станция назначения в отгрузке
	rs."box" as foil_box_number,							-- Ящик
	rs.marshr as route_code,								-- Номер маршрута
	rs.dataprek as dt_forwarder,							-- Дата экспедитора
	rs.zavod as plant_name,									-- Завод
	rs.gtd as gtd_number,									-- Номер грузовой таможенной декларации (ГТД)
	rs.dataskl as dt_storage_start_in_warehouse,			-- Дата склада
	rs.packing as package_weight,							-- Масса упаковки
	rs.cust2_id as buyer_code,								-- Покупатель (код)
	rs.exped as forwarder_name,								-- Экспедитор, наименование
	rs.potrebit as end_user_code,							-- Потребитель (код)
	rs.ident as shipment_entry_identifier_from_file,		-- Идентификатор записи об отгрузке из файла
	rs.exporter as exporter_code,							-- Экспортер (код)
	rs.locid as tsw_location_code,							-- Порт (код)
	rs.dateot as dt_shipment,								-- Дата отгрузки
	rs.vsart as shipment_type_code,							-- Вид отгрузки (код)
	rs.datapgp as dt_border_crossing,						-- Дата пересечения границы
	rs.contr_id as sales_plant_contract_code,				-- Договор завода-производителя (код)
	rs.brutto as weight_gross,								-- Вес брутто
	rs.netto as weight_net,									-- Вес нетто
	rs.werks_nosap as is_plant_not_in_sap_system,			-- Завод не в САП (код)
	rs.svh as temporary_warehouse_movement_type_code,		-- Технический вид движения на/со склада (код)
	case 
		when row_number () over (partition by rs.vbeln, rs.charg, rs.vbeln_lfs order by rs.ident desc) <> 1
    	then true
    	else false
	end as is_not_valid_for_reporting						-- Индикатор: запись не применима для отчетности
from ods."/rusal/shipdata_ral" rs
where 
	rs.charg not like ' %'
	and rs.charg is not null;