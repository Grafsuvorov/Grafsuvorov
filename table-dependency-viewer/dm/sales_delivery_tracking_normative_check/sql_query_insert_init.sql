insert into dm.sales_delivery_tracking_normative_check (
	delivery_number_sales,
	batch,
	weight_net_with_wirerod,
	delivery_basis,
	delivery_point_name,
	uni,
	customer_for_reporting_name,
	delivery_region_code,
	tsw_location_name,
	dt_business_location,
	dt_shipment,
	dt_scenario_start,
	dt_shipment_yyyy,
	business_location_name,
	port_of_discharge_name,
	material_code,
	region_name,
	time_in_stat,
	weighted_average_time_spent_in_the_status,
	the_amount_of_metal_with_a_normal_shelf_life,
	the_amount_of_metal_with_an_extended_shelf_life
)
with t_min_dt_location as (
	select 
		sales_delivery_code, 
		batch,
		dt_business_location,
		extract(year from dt_business_location) as dt_shipment_yyyy,
		business_location_name,
		time_in_stat,
		min(dt_business_location) over (partition by sales_delivery_code, batch) as dt_scenario_start
	from dm_calc.sales_delivery_actual_business_location_by_date
	where business_location_name <> 'Delivered'
		--and dt_business_location = now()::date
),
sb_wuc as ( -- Уникальные номера поставок из двух источников данных sb_wuc
	select delivery_number_sales from dm_calc.sd_sales_stock_by_date where dt_report = now()::date
	union
	select delivery_number_sales from dm_calc.sd_sales_svh_stock_by_date where dt_report = now()::date
),
sd_sales_main_scm_2023 as ( -- Информация о весе поставок 
	select 
		sd.delivery_number_sales,
		sd.batch,
		sd.weight_net_with_wirerod,
		sd.delivery_basis,
		sd.delivery_point_name,
		sd.uni,
		sd.customer_for_reporting_name,
		sd.delivery_region_code,
		sd.tsw_location_name,
		sd.dt_shipment,
		sd.port_of_discharge_name,
		sd.material_code,
		sd.delivery_region_name
	from dm_calc.sd_sales_main_scm sd
	where sd.dt_shipment >= '2023-10-01'
),
t0017 as ( -- Время нахождения поставок в различных статусах для анализа
	select distinct
		sd.delivery_number_sales,
		sd.batch,
		sd.weight_net_with_wirerod,
		sd.delivery_basis,
		sd.delivery_point_name,
		sd.uni,
		sd.customer_for_reporting_name,
		sd.delivery_region_code,
		sd.tsw_location_name,
		sds.dt_business_location,
		sd.dt_shipment,
		sds.dt_scenario_start,
		sds.dt_shipment_yyyy,
		sd.port_of_discharge_name,
		sd.material_code,
		sd.delivery_region_name,
		sds.business_location_name,
		sds.time_in_stat
	from sd_sales_main_scm_2023 sd
		join t_min_dt_location sds
			on sds.sales_delivery_code = sd.delivery_number_sales
			and sds.batch = sd.batch
		join sb_wuc
			on sd.delivery_number_sales = sb_wuc.delivery_number_sales
	where sds.dt_business_location = now()::date
		--and sd.delivery_region_code is not null
),
t0018 as ( -- Суммарный вес металла и время нахождения в каждом статусе по году
	select 
		sd.delivery_number_sales,
		sd.batch,
		extract(year from sds.dt_business_location) as dt_shipment_yyyy,
		sds.business_location_name,
		avg(sds.time_in_stat) over (partition by extract(year from sds.dt_business_location), sds.business_location_name) as time_in_stat,
		weight_net_with_wirerod,
		sum(sd.weight_net_with_wirerod) over (partition by extract(year from sds.dt_business_location), sds.business_location_name) as weight_net_with_wirerod_sum
	from sd_sales_main_scm_2023 sd 
	join dm_calc.sales_delivery_scenario sds
		on sds.delivery_number_sales = sd.delivery_number_sales
		and sds.batch = sd.batch
	where sds.time_in_stat > 1
		and sds.plan_or_actual_code = 'F'
		--and sd.delivery_region_code is not null
),
average_time_in_status as ( -- взвешенное среднее время нахождения в статусах по годам
	select
		t0018.dt_shipment_yyyy + 1 as dt_shipment_yyyy,
		t0018.business_location_name,
		sum(t0018.time_in_stat * sd.weight_net_with_wirerod) / t0018.weight_net_with_wirerod_sum as weighted_average_time_spent_in_the_status
	from t0018
	left join sd_sales_main_scm_2023 sd
		on t0018.delivery_number_sales = sd.delivery_number_sales
		and t0018.batch = sd.batch
	group by 
		t0018.dt_shipment_yyyy + 1, 
		t0018.business_location_name, 
		t0018.weight_net_with_wirerod_sum
)
select
	t0017.delivery_number_sales,
	t0017.batch,
	t0017.weight_net_with_wirerod,
	t0017.delivery_basis,
	t0017.delivery_point_name,
	t0017.uni,
	t0017.customer_for_reporting_name,
	t0017.delivery_region_code,
	t0017.tsw_location_name,
	t0017.dt_business_location,
	t0017.dt_shipment,
	t0017.dt_scenario_start,
	t0017.dt_shipment_yyyy,
	t0017.business_location_name,
	t0017.port_of_discharge_name,
	t0017.material_code,
	t0017.delivery_region_name,
	t0017.time_in_stat,
	ats.weighted_average_time_spent_in_the_status,
	sum(
		case
			when t0017.time_in_stat < ats.weighted_average_time_spent_in_the_status * 1.15 then t0017.weight_net_with_wirerod
		end
	) over (partition by t0017.dt_business_location, t0017.delivery_number_sales, t0017.business_location_name) as the_amount_of_metal_with_a_normal_shelf_life,
	sum(
		case
			when t0017.time_in_stat >= ats.weighted_average_time_spent_in_the_status * 1.15 then t0017.weight_net_with_wirerod	
		end
	) over (partition by t0017.dt_business_location, t0017.delivery_number_sales, t0017.business_location_name) as the_amount_of_metal_with_an_extended_shelf_life
from t0017
	left join average_time_in_status ats 
		on t0017.dt_shipment_yyyy = ats.dt_shipment_yyyy
		and t0017.business_location_name = ats.business_location_name;
