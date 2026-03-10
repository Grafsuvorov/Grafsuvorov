drop table if exists sd2925;
--экспедитор входит в список настроечной таблицы /RUSAL/SD2925_EX-EXPEDID
create temporary table sd2925 as (
	select distinct
		 expedid
		,code_exped
		,werks
	from dict_dds.tech_rusal_sd2925_ex trse
)
distributed replicated; --справочник (до 300 тыс.строк), поэтому можно replicated

---
--ОК
drop table if exists sd3068;
create temporary table sd3068 as ( --2025.10.27: dev 96 152 | prod 103 208
select
	 average_acceptance_duration_days_quantity --тест
	,case when average_acceptance_duration_days_quantity = 0 or average_acceptance_duration_days_quantity is null then 7
	   else average_acceptance_duration_days_quantity end as average_acceptance_duration_days_quantity_with_case	--/RUSAL/SD3068M-TERM_PRIEM
	,transport_route_code							--/RUSAL/SD3068M-ROUTE
	,shipment_type_code								--/RUSAL/SD3068M-OTGR_TYPE
	,dt_normative_valid_period_yyyymm				--/RUSAL/SD3068M-Период
	,substring(dt_normative_valid_period_yyyymm,1,4) || substring(dt_normative_valid_period_yyyymm,5,2)::int as dt_normative_valid_period_yyyymm_for_join --для джойна с ОД
from dds.transport_route_trip_duration
)
distributed replicated;

---
drop table if exists ssms;
--Поля напрямую из ОД
create temporary table ssms as ( --2025.10.27: dev 54 907 | prod 55 682
select
	 ssms.delivery_number_initial 								--SD.000001 | Исходная поставка
	,ssms.plant_producer_code 									--SD.000006 | Завод производитель (код)
	,ssms.plant_producer_name									--SD.000007 | Завод							--2025.11.14 добавляю
	,ssms.dt_arrival_by_railway 									--SD.000011 | Дата прибытия по ЖД
	,ssms.dt_forwarder 											--SD.000012 | Дата экспедитора
	,ssms.railcar 												--SD.000013 | Вагон
	,ssms.transport_bill 										--SD.000014 | Накладная
	,ssms.railway_platform 										--SD.000015 | Платформа
	,ssms.forwarder_name 										--SD.000021 | Экспедитор
	,ssms.port_of_discharge_name 								--SD.000045 | Порт выгрузки
	,ssms.route_type 											--SD.000069 | Тип маршрута
	,ssms.route_plant_code 										--SD.000118 | Маршрут завода
	,ssms.sales_order 											--SD.000123 | Заказ ЦК
	,ssms.uni 													--SD.000151 | UNI
	,ssms.port_of_destination_name as port_of_destination_code 	--port_of_destination_code --SD.000376 | Порт назначения
	,ssms.dt_shipment_actual 									--SD.000976 | Дата отгрузки из Shipdata
	,extract(year from ssms.dt_shipment_actual)::text || /*'-' ||*/ extract(month from ssms.dt_shipment_actual)::text as dt_shipment_actual_yyyymm_for_join --для джойна с sd3068

	,ssms.tsw_location_code as port_of_loading_code				--SD.000008 | Направление (код) --2025.11.06 добавляю
	,sd2925.code_exped as forwarder_in_russian_port_name		--SD.001359 | Экспедитор портовый --2025.11.14 добавляю
--	,/*test*/sd2925.expedid as sd2925_expedid
--	,/*test*/ssms.forwarder_code as ssms_forwarder_code
--	,/*test*/sd2925.werks as sd2925_werks
--	,/*test*/ssms.plant_producer_code as ssms_plant_producer_code --ssms.railway_platform as ssms_railway_platform
from dm_calc.sd_sales_main_scm ssms
--/*TEST*/ from userdata.dm_calc_sd_sales_main_scm20251030_prod_copy ssms --ОД, скопированное из PROD в DEV
  /*2025.11.14 добавляю*/ left join sd2925	--Вывести значение /RUSAL/SD2925_EX-CODE_EXPED для
    on sd2925.expedid = ssms.forwarder_code		--/RUSAL/SD2925_EX-EXPEDID = SD.000020 и
    and sd2925.werks = ssms.plant_producer_code	--SD.000006 | Завод производитель (код) --/RUSAL/SD2925_EX-WERKS = SD.000006
where 1=1
  and ssms.forwarder_code in (select expedid from sd2925) 	--экспедитор входит в список настроечной таблицы /RUSAL/SD2925_EX-EXPEDID = SD.000020 
  and ssms.dt_arrival_by_railway is not null 				--заполнена дата SD.000011 (поставка уже прибыла на станцию)
  and ssms.dt_forwarder is null 							--и не заполнена дата SD.000012 (поставка еще не принята экспедитором)
)
distributed replicated;


---
drop table if exists cte1;
--Вычисления
create temporary table cte1 as ( --2025.10.28: dev  | prod 
	--left join: 54 907
	--join:		  1 507
	select
		 ssms.delivery_number_initial 						--SD.000001 | Исходная поставка
		,ssms.plant_producer_code 							--SD.000006 | Завод производитель (код)
		,ssms.plant_producer_name							--SD.000007 | Завод							--2025.11.14 добавляю
		,ssms.dt_arrival_by_railway 						--SD.000011 | Дата прибытия по ЖД
		,ssms.dt_forwarder 									--SD.000012 | Дата экспедитора
		,ssms.railcar 										--SD.000013 | Вагон
		,ssms.transport_bill 								--SD.000014 | Накладная
		,ssms.railway_platform 								--SD.000015 | Платформа
		,ssms.forwarder_name 								--SD.000021 | Экспедитор
		,ssms.port_of_discharge_name 						--SD.000045 | Порт выгрузки
		,ssms.route_type 									--SD.000069 | Тип маршрута
		,ssms.route_plant_code 								--SD.000118 | Маршрут завода
		,ssms.sales_order 									--SD.000123 | Заказ ЦК
		,ssms.uni 											--SD.000151 | UNI
		,ssms.port_of_destination_code						--SD.000376 | Порт назначения
		,ssms.dt_shipment_actual 							--SD.000976 | Дата отгрузки из Shipdata
		,ssms.port_of_loading_code							--SD.000008 | Направление (код) 			--2025.11.06 добавляю
		
--		,sd3068.dt_normative_valid_period_yyyymm_for_join		--для джойна
--		,ssms.dt_shipment_actual_yyyymm_for_join				--для джойна
--		,sd3068.average_acceptance_duration_days_quantity 		--term_priem
--		,average_acceptance_duration_days_quantity_with_case 	--term_priem с заменой
--		,now()::date as now_date								--сегодня
--		,ssms.dt_arrival_by_railway sd000011					--dt прибытия на станцию
		
		,now()::date - ssms.dt_arrival_by_railway - sd3068.average_acceptance_duration_days_quantity_with_case as forwarder_in_russian_port_accept_normative_exceed_days
		,ssms.forwarder_in_russian_port_name		--SD.001359 | Экспедитор портовый --2025.11.14 добавляю
	from ssms
	  /*left*/ join sd3068 on sd3068.transport_route_code = ssms.route_plant_code --/RUSAL/SD3068M-ROUTE = SD.000118 и 
		and sd3068.shipment_type_code = ssms.route_type --/RUSAL/SD3068M-OTGR_TYPE = SD.000069 и 
		and sd3068.dt_normative_valid_period_yyyymm_for_join = ssms.dt_shipment_actual_yyyymm_for_join --/RUSAL/SD3068M-Период = мм.гггг для даты отгрузки SD.000976
)
distributed replicated;

---
--drop table if exists cte2;
--create temporary table cte2 as ( --2025.10.28: dev  | prod
insert into dm.sales_forwarder_metal_acceptance_delays (
	delivery_number_initial	 								--SD.000001 | Исходная поставка
	,plant_producer_code									--SD.000006 | Завод производитель (код)
	,plant_producer_name									--SD.000007 | Завод							--2025.11.14 добавляю
	,port_of_loading_code									--SD.000008 | Направление (код) 			--2025.11.06 добавляю
	,dt_arrival_by_railway									--SD.000011 | Дата прибытия по ЖД
	,dt_forwarder											--SD.000012 | Дата экспедитора
	,railcar												--SD.000013 | Вагон
	,transport_bill											--SD.000014 | Накладная
	,railway_platform										--SD.000015 | Платформа
	,forwarder_name											--SD.000021 | Экспедитор
	,port_of_discharge_name									--SD.000045 | Порт выгрузки
	,route_type												--SD.000069 | Тип маршрута
	,route_plant_code										--SD.000118 | Маршрут завода
	,sales_order											--SD.000123 | Заказ ЦК
	,uni													--SD.000151 | UNI
	,port_of_destination_code				 				--SD.000376 | Порт назначения
	,dt_shipment_actual										--SD.000976 | Дата отгрузки из Shipdata
	,forwarder_metal_acceptance_delay_days_quantity			--SD.001252 | Задержка в приемке
	,forwarder_in_russian_port_accept_normative_exceed_days	--SD.001358 | Задержка в приемке дней
	,forwarder_in_russian_port_name							--SD.001359 | Экспедитор портовый
)
	select
		 delivery_number_initial 						--SD.000001 | Исходная поставка
		,plant_producer_code 							--SD.000006 | Завод производитель (код)
		,plant_producer_name							--SD.000007 | Завод						--2025.11.14 добавляю
		,port_of_loading_code							--SD.000008 | Направление (код) 		--2025.11.06 добавляю
		,dt_arrival_by_railway 							--SD.000011 | Дата прибытия по ЖД
		,dt_forwarder 									--SD.000012 | Дата экспедитора
		,railcar 										--SD.000013 | Вагон
		,transport_bill 								--SD.000014 | Накладная
		,railway_platform 								--SD.000015 | Платформа
		,forwarder_name 								--SD.000021 | Экспедитор
		,port_of_discharge_name 						--SD.000045 | Порт выгрузки
		,route_type 									--SD.000069 | Тип маршрута
		,route_plant_code 								--SD.000118 | Маршрут завода
		,sales_order 									--SD.000123 | Заказ ЦК
		,uni 											--SD.000151 | UNI
		,port_of_destination_code						--SD.000376 | Порт назначения
		,dt_shipment_actual 							--SD.000976 | Дата отгрузки из Shipdata
		,(case when forwarder_in_russian_port_accept_normative_exceed_days between 1 and 2 then 'Z1'
		    when forwarder_in_russian_port_accept_normative_exceed_days between 3 and 5 then 'Z2'
		 	when forwarder_in_russian_port_accept_normative_exceed_days > 5 then 'Z3'
		 	else '1' end) as forwarder_metal_acceptance_delay_days_quantity --SD.001252 | Задержка в приемке
		,forwarder_in_russian_port_accept_normative_exceed_days				--SD.001358 | Задержка в приемке дней	--2025.11.14 добавляю
		,forwarder_in_russian_port_name										--SD.001359 | Экспедитор портовый		--2025.11.14 добавляю
	from cte1;
