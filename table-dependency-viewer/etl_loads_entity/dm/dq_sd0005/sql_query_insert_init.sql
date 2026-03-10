insert into dm.dq_sd0005(
	error_code,
	error_short_name,
	error_full_name,
	business_area_code,
	error_type_code,
	severity_type_code,
	table_source_code,
	error_description_text,
	error_algorithm_text,
	change_type_code,
	total_weight_net,
	total_including_smelters_wh_weight_net,
	total_shipped_metal_in_inventory_weight_net,
	total_not_yet_delivered_metal_weight_net,
	dt_report,
	delivery_number_sales,
	batch,
	uni,
	weight_nk,
	"location",
	business_location_name,
	plant_producer_code,
	warehouse_shipment_type_name)
	
select
	'dq_sd_0005' as error_code,
	'Дельта sb_wuc' as error_short_name,
	'Дельта sb_wuc' as error_full_name,
	'SD' as business_area_code,
	'2-technical' as error_type_code,
	'3-info' as severity_type_code,
	'dm.sb_wuc, dm.sb_wuc_backup' as table_source_code,
	'Дельта sb_wuc' as error_description_text,
	'Сравнение новой загрузки со вчерашним бекапом' as error_algorithm_text,
	'3-total_weight' as change_type_code,
	SUM(weight_net) as total_weight_net, --без фильтров с дашборда
	SUM(case 
		when business_location_name in ('Scheduled',
                                        'Order issued')
			then 0
		when "location" ilike 'Scheduled%' 
			then 0
		else weight_net
		end ) as total_including_smelters_wh_weight_net, -- фильтры с дашборда
	SUM(case 
		when business_location_name in ('Scheduled',
                                        'Order issued',
                                        'Status Smelter WH', 
                                        'At station')
			then 0
		when "location" ilike 'Scheduled%' 
			then 0
		else weight_net
		end) as total_shipped_metal_in_inventory_weight_net, -- фильтры с дашборда
	SUM(case 
		when business_location_name in ('Scheduled',
                                        'Order issued',
                                        'Status Smelter WH',
                                        'At station',
                                        'Delivered')
			then 0
		when "location" ilike 'Scheduled%' 
			then 0
		else weight_net
		end) as total_not_yet_delivered_metal_weight_net,
	dt_report,
	null as delivery_number_sales,
	null as batch,
	null as uni,
	null as weight_nk,
	null as "location",
	business_location_name,
	plant_producer_code,
	warehouse_shipment_type_name
from
    dm.sb_wuc
group by dt_report, business_location_name, plant_producer_code, warehouse_shipment_type_name
union all
/*insert change_type_code '1-add'*/
--записываем в лог те строки, которые добавились по ключу из перечисленных полей витрины
select
	'dq_sd_0005' as error_code,
	'Дельта sb_wuc' as error_short_name,
	'Дельта sb_wuc' as error_full_name,
	'SD' as business_area_code,
	'2-technical' as error_type_code,
	'3-info' as severity_type_code,
	'dm.sb_wuc, dm.sb_wuc_backup' as table_source_code,
	'Дельта sb_wuc' as error_description_text,
	'Сравнение новой загрузки со вчерашним бекапом' as error_algorithm_text,
	'1-add' as change_type_code,
	0 as total_weight_net,
	0 as total_including_smelters_wh_weight_net,
	0 as total_shipped_metal_in_inventory_weight_net,
	0 as total_not_yet_delivered_metal_weight_net,
	dt_report,
	delivery_number_sales,
	batch,
	uni,
	weight_nk,
	"location",
	business_location_name,
	plant_producer_code,
	warehouse_shipment_type_name
from
--данные в витрине за сегодня
	dm.sb_wuc
where 
	(business_location_name not in ('Scheduled','Order issued')	
	or business_location_name is null)
	and ("location" not ilike 'Scheduled%'
    or "location" is null)	
except
select
	'dq_sd_0005' as error_code,
	'Дельта sb_wuc' as error_short_name,
	'Дельта sb_wuc' as error_full_name,
	'SD' as business_area_code,
	'2-technical' as error_type_code,
	'3-info' as severity_type_code,
	'dm.sb_wuc, dm.sb_wuc_backup' as table_source_code,
	'Дельта sb_wuc' as error_description_text,
	'Сравнение новой загрузки со вчерашним бекапом' as error_algorithm_text,
	'1-add' as change_type_code,
	0 as total_weight_net,
	0 as total_including_smelters_wh_weight_net,
	0 as total_shipped_metal_in_inventory_weight_net,
	0 as total_not_yet_delivered_metal_weight_net,
	dt_report,
	delivery_number_sales,
	batch,
	uni,
	weight_nk,
	"location",
	business_location_name,
	plant_producer_code,
	warehouse_shipment_type_name
from
--данные из бекапа за вчера
	dm.sb_wuc_backup
where 
	(business_location_name not in ('Scheduled','Order issued')	
	or business_location_name is null)
	and ("location" not ilike 'Scheduled%'
    or "location" is null)	
union all
/*insert change_type_code '2-delete'*/
--записываем в лог те строки, которые удалились по ключу из перечисленных полей витрины
select
	'dq_sd_0005' as error_code,
	'Дельта sb_wuc' as error_short_name,
	'Дельта sb_wuc' as error_full_name,
	'SD' as business_area_code,
	'2-technical' as error_type_code,
	'3-info' as severity_type_code,
	'dm.sb_wuc, dm.sb_wuc_backup' as table_source_code,
	'Дельта sb_wuc' as error_description_text,
	'Сравнение новой загрузки со вчерашним бекапом' as error_algorithm_text,
	'2-delete' as change_type_code,
	0 as total_weight_net,
	0 as total_including_smelters_wh_weight_net,
	0 as total_shipped_metal_in_inventory_weight_net,
	0 as total_not_yet_delivered_metal_weight_net,
	dt_report,
	delivery_number_sales,
	batch,
	uni,
	weight_nk,
	"location",
	business_location_name,
	plant_producer_code,
	warehouse_shipment_type_name
from
--данные из бекапа за вчера
	dm.sb_wuc_backup
where 
	(business_location_name not in ('Scheduled','Order issued')	
	or business_location_name is null)
	and ("location" not ilike 'Scheduled%'
    or "location" is null)	
except
select
	'dq_sd_0005' as error_code,
	'Дельта sb_wuc' as error_short_name,
	'Дельта sb_wuc' as error_full_name,
	'SD' as business_area_code,
	'2-technical' as error_type_code,
	'3-info' as severity_type_code,
	'dm.sb_wuc, dm.sb_wuc_backup' as table_source_code,
	'Дельта sb_wuc' as error_description_text,
	'Сравнение новой загрузки со вчерашним бекапом' as error_algorithm_text,
	'2-delete' as change_type_code,
	0 as total_weight_net,
	0 as total_including_smelters_wh_weight_net,
	0 as total_shipped_metal_in_inventory_weight_net,
	0 as total_not_yet_delivered_metal_weight_net,
	dt_report,
	delivery_number_sales,
	batch,
	uni,
	weight_nk,
	"location",
	business_location_name,
	plant_producer_code,
	warehouse_shipment_type_name
from
--данные в витрине за сегодня
	dm.sb_wuc
where 
	(business_location_name not in ('Scheduled','Order issued')	
	or business_location_name is null)
	and ("location" not ilike 'Scheduled%'
    or "location" is null)		
;
