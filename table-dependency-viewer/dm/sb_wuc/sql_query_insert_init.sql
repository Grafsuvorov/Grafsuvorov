
--Данные ОВ
--1. Из таблицы /RUSAL/SD4798M (таблица связи поставок с химией из САП) отобрать уникальные пары поставка-пакет, поставка не должна начинаются на 5 (отсекаем LE-поставки).
drop table if exists sales_bundle_and_delivery_relationship;
create temporary table sales_bundle_and_delivery_relationship /*on commit drop*/ as ( --34 951 921
select --count(*) hhhhhhhhhhhhhhhhhhhhhgbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
 tt.sales_bundle_code
 ,tt.delivery_code
from
(select sales_bundle_code, delivery_code--, count(*) 
from dds.sales_bundle_and_delivery_relationship sd4798 
where  TRIM(LEADING '0' FROM delivery_code) not like '5%' --and delivery_code='0110181062'--'0110266538' --and sales_bundle_code='0042358923' 
group by sales_bundle_code,delivery_code)tt
)
distributed by (sales_bundle_code,delivery_code);

--2. Из таблицы SD.T0004 (ОВ реализованная в КХД см. ТЗ на SD.T0004) для каждой поставки (найденной в /RUSAL/SD4798M см п1), отобрать максимальный пакет в разрезе узла. Отбираются узлы начинающиеся на G и узлов нет 
--в dict_dds.foreign_warehouse_priority_definition(ZSD2973M_LGORT), is_terminal_code(SIGN_TERMINAL)='X' or is_foreign_warehouse_code(SIGN_FOREIGN_WH)='X' or is_temporary_warehouse_code(SIGN_TSW)='X'
drop table if exists t4_all;
create temporary table t4_all /*on commit drop*/ as ( --8 781 492 размножена т.к. в dds на одну партию несколько поставок --если применяю inner join к calculation 4 8782 74
select --count(*)
sb.delivery_code
,max(t4.sales_bundle_code) AS sales_bundle_code
,t4.knote
,max(t4.dt_transportation_stage_start_p) as dt_transportation_stage_start_p
,max(case
	    when dt_transportation_stage_start_r is null 
	         then '2999-12-31'
	         else dt_transportation_stage_start_r
    end) as dt_transportation_stage_start_r
 from  dm_calc.sales_bundle_transport_hub_turnover_sdt0004 t4 --ОВ реализованная в КХД см ТЗ на SD.T0004
   inner join 
     (select distinct transport_hub_code 
             from dict_dds.foreign_warehouse_priority_definition 
      where is_terminal_code='X' or is_foreign_warehouse_code='X' or is_temporary_warehouse_code='X') as fwp --поля is_foreign_terminal_code и is_svh_code требуют нейминга 
      on t4.knote=fwp.transport_hub_code
   inner join sales_bundle_and_delivery_relationship sb 
         on t4.sales_bundle_code =sb.sales_bundle_code 
 where t4.knote like 'G%'      
group by 
sb.delivery_code
,t4.knote
  )
distributed by (delivery_code,knote,dt_transportation_stage_start_p);

--3. беру максимальный пакет 
drop table if exists t4_all2;
create temporary table t4_all2 /*on commit drop*/ as (
select --count(*)
sb.delivery_code
,max(t4.sales_bundle_code) AS sales_bundle_code
,max(t4.dt_transportation_stage_start_p) as dt_transportation_stage_start_p
,max(case
	    when dt_transportation_stage_start_r is null 
	         then '2999-12-31'
	         else dt_transportation_stage_start_r
    end) as dt_transportation_stage_start_r
 from  dm_calc.sales_bundle_transport_hub_turnover_sdt0004 t4
   inner join 
     (select distinct transport_hub_code from dict_dds.foreign_warehouse_priority_definition where is_terminal_code='X' or is_foreign_warehouse_code='X' or is_temporary_warehouse_code='X') as fwp --поля is_foreign_terminal_code и is_svh_code требуют нейминга 
      on t4.knote=fwp.transport_hub_code
      inner join sales_bundle_and_delivery_relationship sb 
         on t4.sales_bundle_code =sb.sales_bundle_code   
group by 
sb.delivery_code
)
distributed by (delivery_code,dt_transportation_stage_start_p);

drop table if exists uzb;
create temp table uzb /*on commit drop*/ as (
	--,uzb as (
		select
			uzb.ident
			,uzb.charg
			,ls.transport_hub_code
			,ls.location_name
		from ods.ztsd5018m_uz_b_ral as uzb 
		  join dict_dds.location_sales as ls
		    on ls.location_code = uzb.locid
	)
distributed by (ident, charg);

drop table if exists eub;
create temp table eub /*on commit drop*/ as (
	--,eub as (
		select
			eub.ident
			,eub.loc_name
			,eub.charg
			,ls.transport_hub_code
		from ods.ztsd5018m_eu_b_ral as eub 
		  join dict_dds.location_sales as ls
		    on ls.location_code = eub.locid
	)
	distributed by (ident, charg);

--Данные HFM
-- поле SD.000962 Сумма в доллар ФАКТ (Сумма в долларах факт от веса поставки) рассчитывается на данных из источника HFM.
--В источнике HFM данные для расчета стоимости тонны металла хранятся в разрезе завода и даты. 
--Другие аналитики (гранулярности) детализации данных, на расчет стоимости тонны не влияют.
--Проблема 1:В источнике HFM ведутся свои коды заводов, отличные от кодов в источнике САП.
--С помощью таблицы - маппера необходимо привязать данные к кодам заводов САП. Таблица-маппер создается вручную в Excel,обновляется в КХД по требованию.(см. лист '?' Влад, вставляем в ТЗ и указываем лист)
--связь HFM с таблицей-маппером hypdb_v_hfm_pcs013_1_014_1_al-d002_code=maps-manufacturer_code, вытащить из маппера поле Smelter code. 
--Проблема 2:В HFM нет деления САЗ и ХАЗ, все суммы отражаются на САЗ. Необходимо добавить запись которая продублирует суммы на завод 5302 'ХАЗ'.
--Для расчета поля "Стоимость тонны металла производителя, USD / т" необходимы итоговые суммы Sum(TOTAL_BALANCE_TONN) и Sum(TOTAL_COST_USD) в разрезе завода Smelter code и даты CALENDAR_ID.
--"Стоимость тонны металла производителя, USD / т"=Sum(TOTAL_COST_USD)/Sum(TOTAL_BALANCE_TONN)
--связь HFM c supply chain по supply chain-Завод производитель (код)(plant_producer_code)=hfm-Smelter code и supply chain-dt_report(отчетная дата в формате'YYYYMM'=hfm-calendar_id(отчетная дата в формате'YYYYMM')
--в случае если в HFM нет данных, то брать максимальную дату, для которой есть данные по заводу 
--SD.000962 Сумма в доллар ФАКТ (Сумма в долларах факт от веса поставки)="вес нетто"*Стоимость тонны металла производителя, USD / т
drop table if exists hfm; 
CREATE TEMPORARY TABLE hfm /*on commit drop*/ AS ( 
	SELECT 
		 al.d002_code
		,maps.plant_code 
		,al.d002_name_ru
		--,to_char(al.calendar_id,'YYYYMM') AS calendar_id
		,al.calendar_id
		,sum(al.total_balance_tonn) AS total_balance_tonn
		,sum(al.total_cost_usd) AS total_cost_usd
		,sum(al.total_cost_usd) / sum(nullif(al.total_balance_tonn, 0)) AS cost_of_ton_of_metal_manufacturer_usd
	FROM 
		ods.hypdb_v_hfm_pcs013_1_014_1_al AS al
	LEFT JOIN 
		dict_dds.map_hfm_manufacturer_to_sap_smelter AS maps
		ON al.d002_code = maps.manufacturer_code
	WHERE 
		maps.plant_code IS NOT null -- and d002_code = 'MF00004'
	GROUP BY 
		al.d002_code
		,maps.plant_code 
		,al.d002_name_ru
		--,to_char(al.calendar_id,'YYYYMM')
		,al.calendar_id
		 --order by to_char(al.calendar_id,'YYYYMM') desc
		--order by al.calendar_id desc
	UNION ALL 
	SELECT
		al.d002_code
		,'5302' AS plant_code 
		,'ХАЗ' AS d002_name_ru
		--,to_char(al.calendar_id,'YYYYMM') AS calendar_id
		,al.calendar_id
		,sum(al.total_balance_tonn) AS total_balance_tonn
		,sum(al.total_cost_usd) AS total_cost_usd
		,sum(al.total_cost_usd) / sum(nullif(al.total_balance_tonn, 0)) AS cost_of_ton_of_metal_manufacturer_usd 
	FROM 
		ods.hypdb_v_hfm_pcs013_1_014_1_al AS al
	WHERE 
		al.d002_code = 'MF00006'
	GROUP BY 
		al.d002_code
		--,to_char(al.calendar_id,'YYYYMM')
		,al.calendar_id
	)
DISTRIBUTED BY (
	d002_code
	,plant_code
	,calendar_id
	);
-- данные по всем заводам на максимальную дату
drop table if exists hfm_max; 
CREATE TEMPORARY TABLE hfm_max /*on commit drop*/ AS ( 
	SELECT 
		al.d002_code
		,al.plant_code 
		,al.d002_name_ru
		,al.calendar_id
		,al.total_balance_tonn
		,al.total_cost_usd
		,al.cost_of_ton_of_metal_manufacturer_usd
	FROM 
		hfm AS al
		inner join (select d002_code
		           ,max(calendar_id) as calendar_id from hfm group by d002_code)al2
		 on al.d002_code=al2.d002_code and al.calendar_id=al2.calendar_id
	)
DISTRIBUTED BY (
	d002_code
	,plant_code
	,calendar_id
	);
--Данные витрины хранения
drop table if exists storage_indicators; 
CREATE TEMPORARY TABLE storage_indicators /*on commit drop*/ AS ( 
/*select 
dt_report
,sales_delivery_code
,sales_bundle_code
,storage_duration_total_calendar_days --SD.001037 (LE.001086)
,storage_duration_free_by_contract_calendar_days--SD.001038 (LE.001087)
,storage_duration_payable_calendar_days--SD.001039(LE.001089)
,storage_cost_calculated_amount--SD.001040(LE.001090 )
,(storage_calculated_cost_001_030_amount + storage_calculated_cost_031_060_amount + storage_calculated_cost_061_090_amount + storage_calculated_cost_091_180_amount +
  storage_calculated_cost_181_365_amount + storage_calculated_cost_over_365_amount) as storage_calculated_cost_total_amount --SD.001041(LE.001116)
,row_number() over (partition by sales_delivery_code order by sales_bundle_code desc) as rn
 from dm_calc.storage_sales_bundles_amount*/
select 
dt_report
,sales_delivery_code
,max(storage_duration_total_calendar_days) as storage_duration_total_calendar_days--SD.001037 (LE.001086)
,max(storage_duration_free_by_contract_calendar_days) as storage_duration_free_by_contract_calendar_days--SD.001038 (LE.001087)
,max(storage_duration_payable_calendar_days) as storage_duration_payable_calendar_days--SD.001039(LE.001089)
,sum(storage_cost_calculated_amount) as storage_cost_calculated_amount--SD.001040(LE.001090 )
,sum (storage_calculated_cost_001_030_amount + storage_calculated_cost_031_060_amount + storage_calculated_cost_061_090_amount + storage_calculated_cost_091_180_amount +
  storage_calculated_cost_181_365_amount + storage_calculated_cost_over_365_amount) as storage_calculated_cost_total_amount --SD.001041(LE.001116)
 from dm_calc.storage_sales_bundles_amount
-- where dt_report = '2025-11-14' and sales_delivery_code = '0110426991'
 group by dt_report
,sales_delivery_code

 	)
DISTRIBUTED BY (
	dt_report
	,sales_delivery_code
	--,sales_bundle_code
	);
--1 создаю временную таблицу из dm_calc.sd_sales_stock_by_date с dm_calc.sales_delivery_actual_business_location_by_date
drop table if exists sd_sales_stock_by_date; 
create temporary table sd_sales_stock_by_date /*on commit drop*/ as ( 
	select 
		scm.*
	   ,sde.business_location_name as business_location_for_reporting_name       -- SD.000717 Статус среза 
       ,sde.plan_or_actual_code                                                  -- SD.000718 Источник данных среза План/Факт   
	   ,case 
	   	when material_group_report_mc='A01' then 'ALLOY'
	   	else 'PRIMARY'
	   end as material_group_for_wc_reporting_name                               -- SD.000959 Группа материалов для отчета Оборотный капитал 
	     ,case 
	   	when material_group_report_mc='A01' then 'Сплав'
	   	else 'Первичный аллюминий'
	   end as material_group_for_wc_reporting_rus_name                           -- SD.000959 Группа материалов для отчета Оборотный капитал на русском     
	   ,COALESCE(hfm.cost_of_ton_of_metal_manufacturer_usd,	hfm_max.cost_of_ton_of_metal_manufacturer_usd,0) as material_cost_actual_hfm_usd_currency_amount -- HFM Себестоимость   -----Новое в структуре
	   ,scm.weight_net * COALESCE(hfm.cost_of_ton_of_metal_manufacturer_usd, hfm_max.cost_of_ton_of_metal_manufacturer_usd,0) AS material_cost_actual_usd_currency_amount
       --,weight_nk * 2300 as material_cost_actual_usd_currency_amount                       -- SD.000962 Сумма в доллар ФАКТ
	   ,scm.weight_net * 2300 + scm.weight_net * 2300/100 as material_cost_plan_usd_currency_amount  -- SD.000963 Сумма в доллар ЦЕЛЬ
	   ,sb.knote as warehouse_code                                                                   -- SD.000420 Удаленный склад (код)
	   ,thc.transport_hub_name_eng as warehouse_name                                                  -- SD.000421 Удаленный склад
	   ,thc.country_code as country_of_remote_warehouse_code                                          -- SD.000725 Страна удаленного склада (код)
	   ,thc.country_short_name_eng  as country_of_remote_warehouse_name                               -- SD.000423 Страна удаленного склада
	   ,thc.market_region1_code as region_of_remote_warehouse_code                                    -- SD.000726 Регион удаленного склада (код)
	   ,thc.market_region1_name as region_of_remote_warehouse_name                                    -- SD.000727 Регион удаленного склада 
	   ,coalesce(eub.loc_name, uzb.location_name) as fwrd_info_second_foreign_warehouse_location_name										-- EXP: Storage location 2 SD.000941 
        --Показатели витрины хранения
	   ,si.storage_duration_total_calendar_days --SD.001037 (LE.001086)
       ,si.storage_duration_free_by_contract_calendar_days--SD.001038 (LE.001087)
       ,si.storage_duration_payable_calendar_days--SD.001039(LE.001089)
       ,si.storage_cost_calculated_amount--SD.001040(LE.001090 )
       ,si.storage_calculated_cost_total_amount --SD.001041(LE.001116)
	   from dm_calc.sd_sales_stock_by_date scm
	left join dm_calc.sales_delivery_actual_business_location_by_date sde
        -- on scm.dt_report=sde.dt_business_location 
        -- and scm.delivery_number_sales=sde.sales_delivery_code
        -- and scm.transportation_scenario_code=sde.transportation_scenario_code 
        -- and scm.shipment_market_code=sde.shipment_market_code
         on scm.dt_report=sde.dt_business_location 
         and scm.delivery_number_sales=sde.sales_delivery_code
         and scm.batch=sde.batch 
    LEFT JOIN hfm
	     ON scm.plant_producer_code = hfm.plant_code 
    	 AND to_char(scm.dt_report,'YYYYMM') = to_char(hfm.calendar_id,'YYYYMM')
 --в случае если в HFM нет данных, то брать максимальную дату, для которой есть данные по заводу        
    LEFT JOIN hfm_max
	     ON scm.plant_producer_code = hfm_max.plant_code 
		 AND to_char(scm.dt_report,'YYYYMM') > to_char(hfm_max.calendar_id,'YYYYMM')      
         --where dt_report='2025-09-05'
	--данные ОВ
	left join t4_all sb 
  on TRIM(LEADING '0' FROM scm.delivery_number_sales)= TRIM(LEADING '0' FROM sb.delivery_code)
  and (scm.dt_report>=sb.dt_transportation_stage_start_p and scm.dt_report<sb.dt_transportation_stage_start_r)	
  left join dm_calc.transport_hub_country as thc
  on sb.knote=thc.transport_hub_code 
  left join t4_all2 sb2 
  on TRIM(LEADING '0' FROM scm.delivery_number_sales)= TRIM(LEADING '0' FROM sb2.delivery_code)
  and (scm.dt_report>=sb2.dt_transportation_stage_start_p and scm.dt_report<sb2.dt_transportation_stage_start_r)
  left join uzb										
	  on uzb.ident = sb2.sales_bundle_code
	  and uzb.charg = scm.batch
	  and uzb.transport_hub_code = scm.port_of_discharge_in_foreign_port_code
	left join eub										
	  on eub.ident = sb2.sales_bundle_code
	  and eub.charg = scm.batch
	  and eub.transport_hub_code = scm.port_of_discharge_in_foreign_port_code
	  --Данные витрины хранения для ОК
  left join storage_indicators as si 
on scm.dt_report=si.dt_report and scm.delivery_number_sales=si.sales_delivery_code --and si.rn=1
	  where scm.warehouse_shipment_type_name is null --and dt_report='2025-09-05'
)
DISTRIBUTED by (dt_report, delivery_number_sales,batch);
 
--2 создаю временную таблицу из dm_calc.sd_sales_stock_by_date с dm_calc.sales_delivery_actual_business_location_by_date
drop table if exists sd_sales_svh_stock_by_date; 
create temporary table sd_sales_svh_stock_by_date /*on commit drop*/ as ( 
	select 
		scm.*
	   ,sde.business_location_name as business_location_for_reporting_name       -- SD.000717 Статус среза 
       ,sde.plan_or_actual_code                                                  -- SD.000718 Источник данных среза План/Факт   
	   ,case 
	   	when material_group_report_mc='A01' then 'ALLOY'
	   	else 'PRIMARY'
	   end as material_group_for_wc_reporting_name                               -- SD.000959 Группа материалов для отчета Оборотный капитал  
	   ,case 
	   	when material_group_report_mc='A01' then 'Сплав'
	   	else 'Первичный аллюминий'
	   end as material_group_for_wc_reporting_rus_name                           -- SD.000959 Группа материалов для отчета Оборотный капитал на русском     
	   ,COALESCE(hfm.cost_of_ton_of_metal_manufacturer_usd,	hfm_max.cost_of_ton_of_metal_manufacturer_usd,0) as material_cost_actual_hfm_usd_currency_amount -- HFM Себестоимость   -----Новое в структуре
	   ,scm.weight_net * COALESCE(hfm.cost_of_ton_of_metal_manufacturer_usd, hfm_max.cost_of_ton_of_metal_manufacturer_usd,0) AS material_cost_actual_usd_currency_amount
       --,weight_nk * 2300 as material_cost_actual_usd_currency_amount                       -- SD.000962 Сумма в доллар ФАКТ
	   ,scm.weight_net * 2300 + scm.weight_net * 2300/100 as material_cost_plan_usd_currency_amount  -- SD.000963 Сумма в доллар ЦЕЛЬ
	    ,sb.knote as warehouse_code                                                                   -- SD.000420 Удаленный склад (код)
	   ,thc.transport_hub_name_eng as warehouse_name                                                  -- SD.000421 Удаленный склад
	   ,thc.country_code as country_of_remote_warehouse_code                                          -- SD.000725 Страна удаленного склада (код)
	   ,thc.country_short_name_eng  as country_of_remote_warehouse_name                               -- SD.000423 Страна удаленного склада
	   ,thc.market_region1_code as region_of_remote_warehouse_code                                    -- SD.000726 Регион удаленного склада (код)
	   ,thc.market_region1_name as region_of_remote_warehouse_name                                    -- SD.000727 Регион удаленного склада 
	   ,coalesce(eub.loc_name, uzb.location_name) as fwrd_info_second_foreign_warehouse_location_name										-- EXP: Storage location 2 SD.000941 
        --Показатели витрины хранения
	   ,si.storage_duration_total_calendar_days --SD.001037 (LE.001086)
       ,si.storage_duration_free_by_contract_calendar_days--SD.001038 (LE.001087)
       ,si.storage_duration_payable_calendar_days--SD.001039(LE.001089)
       ,si.storage_cost_calculated_amount--SD.001040(LE.001090 )
       ,si.storage_calculated_cost_total_amount --SD.001041(LE.001116)
	   from dm_calc.sd_sales_svh_stock_by_date scm
	left join dm_calc./*sales_delivery_estimated_business_location_by_date*/sales_delivery_actual_business_location_by_date sde
         --on scm.dt_report=sde.dt_business_location 
         --and scm.delivery_number_sales=sde.sales_delivery_code
         --and scm.transportation_scenario_code=sde.transportation_scenario_code 
         --and scm.shipment_market_code=sde.shipment_market_code 
	 on scm.dt_report=sde.dt_business_location 
         and scm.delivery_number_sales=sde.sales_delivery_code
         and scm.batch=sde.batch
     LEFT JOIN hfm
	     ON scm.plant_producer_code = hfm.plant_code 
    	 AND to_char(scm.dt_report,'YYYYMM') = to_char(hfm.calendar_id,'YYYYMM')
 --в случае если в HFM нет данных, то брать максимальную дату, для которой есть данные по заводу        
    LEFT JOIN hfm_max
	     ON scm.plant_producer_code = hfm_max.plant_code 
		 AND to_char(scm.dt_report,'YYYYMM') > to_char(hfm_max.calendar_id,'YYYYMM')   
		 --данные ОВ
	left join t4_all sb 
  on TRIM(LEADING '0' FROM scm.delivery_number_sales)= TRIM(LEADING '0' FROM sb.delivery_code)
  and (scm.dt_report>=sb.dt_transportation_stage_start_p and scm.dt_report<sb.dt_transportation_stage_start_r)	
  left join dm_calc.transport_hub_country as thc
  on sb.knote=thc.transport_hub_code 
  left join t4_all2 sb2 
  on TRIM(LEADING '0' FROM scm.delivery_number_sales)= TRIM(LEADING '0' FROM sb2.delivery_code)
  and (scm.dt_report>=sb2.dt_transportation_stage_start_p and scm.dt_report<sb2.dt_transportation_stage_start_r)
  left join uzb										
	  on uzb.ident = sb2.sales_bundle_code
	  and uzb.charg = scm.batch
	  and uzb.transport_hub_code = scm.port_of_discharge_in_foreign_port_code
	left join eub										
	  on eub.ident = sb2.sales_bundle_code
	  and eub.charg = scm.batch
	  and eub.transport_hub_code = scm.port_of_discharge_in_foreign_port_code
  --Данные витрины хранения для ОК
  left join storage_indicators as si 
    on scm.dt_report=si.dt_report and scm.delivery_number_sales=si.sales_delivery_code --and si.rn=1 	  
         --where dt_report='2025-09-05'
)
DISTRIBUTED by (dt_report, delivery_number_sales,batch);
--select * from dm.sb_wuc sw 

drop table if exists business_location_for_wc; 
create temporary table business_location_for_wc /*on commit drop*/ as ( 
	select 
		business_location_for_reporting_name      
       ,business_location_for_wc_reporting_name   
    from dds.sales_location_stay_normative   
	group by
	    business_location_for_reporting_name      
       ,business_location_for_wc_reporting_name 
)
DISTRIBUTED by (business_location_for_reporting_name      
       ,business_location_for_wc_reporting_name );

drop table if exists business_location_allocated; 
create temporary table business_location_allocated /*on commit drop*/ as ( 
	select 
		dt_report      
       ,business_location_for_reporting_name
       ,sum(weight_nk) as weight_nk_bla
    from sd_sales_stock_by_date   
	group by
	    dt_report      
       ,business_location_for_reporting_name 
)
DISTRIBUTED by (dt_report      
       ,business_location_for_reporting_name);  

-- Группируем 17 целей в 5 групп для расчёта Пропорциональной цели для озера
-- 1 группа "Завод"
drop table if exists business_location_allocated_plant; 
create temporary table business_location_allocated_plant /*on commit drop*/ as ( 
	select 
		dt_report 
		,plant_producer_code
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_stock_by_date   
	group by
		dt_report 									-- Дата баланса на дату
	    ,plant_producer_code						-- Завод
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	plant_producer_code, 
	business_location_for_reporting_name
); 

-- 2 группа "Направление"
drop table if exists business_location_allocated_location; 
create temporary table business_location_allocated_location /*on commit drop*/ as ( 
	select 
		dt_report 
		,tsw_location_code
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_stock_by_date   
	group by
		dt_report 									-- Дата баланса на дату
	    ,tsw_location_code							-- Направление
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	tsw_location_code, 
	business_location_for_reporting_name
); 

-- 3 группа "Склад РФ"
drop table if exists business_location_allocated_warehouse; 
create temporary table business_location_allocated_warehouse /*on commit drop*/ as ( 
	select 
		dt_report 
		,receiving_warehouse_code
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_stock_by_date  
    where shipment_market_code = '3'
	group by
		dt_report 									-- Дата баланса на дату
	    ,receiving_warehouse_code					-- Склад РФ
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	receiving_warehouse_code, 
	business_location_for_reporting_name
); 

-- 4 группа "Регион"
drop table if exists business_location_allocated_region; 
create temporary table business_location_allocated_region /*on commit drop*/ as ( 
	select 
		dt_report 
		,region_of_remote_warehouse_code
		--,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_stock_by_date   
    where shipment_market_code <> '3'
    	and business_location_for_reporting_name in ('In transit warehouse', 
    												   'In warehouse (not ready for release)', 
          											   'In warehouse (ready for release)', 
          											   'At Consignment stock')
	group by
		dt_report 									-- Дата баланса на дату
	    ,region_of_remote_warehouse_code			-- Регион складской экспорт
  		--,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	region_of_remote_warehouse_code 
	--business_location_for_reporting_name
); 

-- 5 группа "Регион+Направление"
drop table if exists business_location_allocated_region_location; 
create temporary table business_location_allocated_region_location /*on commit drop*/ as ( 
	select 
		dt_report 
		,delivery_region_code
		,tsw_location_code							
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_stock_by_date   
	group by
		dt_report 									-- Дата баланса на дату
	    ,delivery_region_code						-- Регион
	    ,tsw_location_code							-- Направление
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	delivery_region_code,
	tsw_location_code,							
	business_location_for_reporting_name
); 

-- Группируем 17 целей в 5 групп для расчёта Пропорциональной цели для СВХ
-- 1 группа "Завод"
drop table if exists business_location_allocated_svh_plant; 
create temporary table business_location_allocated_svh_plant /*on commit drop*/ as ( 
	select 
		dt_report 
		,plant_producer_code
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_svh_stock_by_date   
	group by
		dt_report 									-- Дата баланса на дату
	    ,plant_producer_code						-- Завод
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	plant_producer_code, 
	business_location_for_reporting_name
); 

-- 2 группа "Направление"
drop table if exists business_location_allocated_svh_location; 
create temporary table business_location_allocated_svh_location /*on commit drop*/ as ( 
	select 
		dt_report 
		,tsw_location_code
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_svh_stock_by_date   
	group by
		dt_report 									-- Дата баланса на дату
	    ,tsw_location_code							-- Направление
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	tsw_location_code, 
	business_location_for_reporting_name
); 

-- 3 группа "Склад РФ"
drop table if exists business_location_allocated_svh_warehouse; 
create temporary table business_location_allocated_svh_warehouse /*on commit drop*/ as ( 
	select 
		dt_report 
		,receiving_warehouse_code
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_svh_stock_by_date  
    where shipment_market_code = '3'
	group by
		dt_report 									-- Дата баланса на дату
	    ,receiving_warehouse_code					-- Склад РФ
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	receiving_warehouse_code, 
	business_location_for_reporting_name
); 

-- 4 группа "Регион"
drop table if exists business_location_allocated_svh_region; 
create temporary table business_location_allocated_svh_region /*on commit drop*/ as ( 
	select 
		dt_report 
		,delivery_region_code
		--,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_svh_stock_by_date 
    where shipment_market_code = '3'
    	and business_location_for_reporting_name in ('In transit warehouse', 
    												   'In warehouse (not ready for release)', 
          											   'In warehouse (ready for release)', 
          											   'At Consignment stock')
	group by
		dt_report 									-- Дата баланса на дату
	    ,delivery_region_code						-- Регион
  		--,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	delivery_region_code 
	--business_location_for_reporting_name
); 

-- 5 группа "Регион+Направление"
drop table if exists business_location_allocated_svh_region_location; 
create temporary table business_location_allocated_svh_region_location /*on commit drop*/ as ( 
	select 
		dt_report 
		,delivery_region_code
		,tsw_location_code							
		,business_location_for_reporting_name
		,sum(weight_nk) as weight_nk_bla
    from sd_sales_svh_stock_by_date   
	group by
		dt_report 									-- Дата баланса на дату
	    ,delivery_region_code						-- Регион
	    ,tsw_location_code							-- Направление
  		,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	delivery_region_code,
	tsw_location_code,							
	business_location_for_reporting_name
); 

-- Группируем цели для расчёта Пропорциональной цели для СГП
-- 1 группа "Завод"
drop table if exists business_location_allocated_plant_sgp; 
create temporary table business_location_allocated_plant_sgp /*on commit drop*/ as ( 
	select 
		dt_report 
		,plant_producer_code
		--,business_location_for_reporting_name
		,sum(weight_net) as weight_nk_bla
    from dm_calc.finish_goods_warehouse_stock_plant_by_date    
	group by
		dt_report 									-- Дата баланса на дату
	    ,plant_producer_code						-- Завод
  		--,business_location_for_reporting_name 		-- Локация
)
DISTRIBUTED by (
	dt_report, 
	plant_producer_code 
	--business_location_for_reporting_name
); 

insert into /*dm.sb_wuc_08_09*/ dm.sb_wuc(
	dt_report,                                --Отчетная дата
	realization_status,                       --Статус реализации 
	plant_producer_code,                      --Завод производитель (код)
	plant_manufact,                           --Завод производитель
	plant_manufact_rus_name,                  --Завод производитель на русском
	direction,                    		     -- Направление --Порт погрузки в МКТРЕК
	direction_rus,                           --SD.000009 Направление на русском --Порт погрузки в МКТРЕК
	tsw_location_code,                     --Порт погрузки(код) в МКТРЕК
	material_type,                            --Тип материала
	material_rus_type,                            --Тип материала
	material_group_report_mc,                 --Группа материала для отчета Металл в Цеп 
	shipment_market_code,                     --Рынок в отгрузке (код)!!!!
	ovk_market_text,                          --Рынок в отгрузке
	weight_net,                               --Вес нетто
	weight_nk,                                --Вес НК
	weight_gross,                             --Вес брутто!!!!
	quota,                                    --Quota 
	port_of_discharge_code,                   --SD.000044 Порт выгрузки (код) 
	port_discharge,                           --SD.000045 Порт выгрузки
	port_discharge_rus,                       --SD.000045 Порт выгрузки на русском
	port_of_discharge_in_foreign_port_code,   --Второй иностранный порт(код)
	port_discharge_abroad_sec,                --SD.000055 Второй иностранный порт
	port_discharge_abroad_sec_rus,            --SD.000055 Второй иностранный порт на русском
	delivery_point_name,                      --Пункт доставки по инкотермс
	"ordering",                               --Order              --Заказ ЦK в МКТРЕК 
	metal_grade,                              --Марка --Марка по спецификации в МКТРЕК
	buyer_end_name,                           --End Buyer ----Конечный потребитель
	delivery_split_reason_code,               --Причина деления (код)!!!!
	delivery_split_reason_name,               --Причина деления 
	"location",
	location_from_stock,                               --Локация
	country_of_discharge_port_code,         --Страна POD (код)!!!!
	country,                                  --Страна POD
	country_rus_name,                         --Страна POD на русском
	region_of_destination_port_code,          --Регион POD (код)!!!!
	region,                                   --Регион POD 
	region_rus_name,                          --Регион POD 
	dest_port,                                --Порт назначения
	delivery_number_initial,                  --Исходная поставка!!!!
	delivery_number_sales,                    --Продажная поставка!!!!
	delivery_number_outbound,                 --Исходящая поставка !!!!
	delivery_number_of_producer_plant,        --Заводская поставка !!!!
	batch,                                    --Партия!!!!
	uni,
	dt_release_material,                      --Дата ОМ !!!!
	release_material_status_code,             --Статус ОМ!!!!
	ovk_port_vigruz_group,                    --Порт выгрузки группа 
	receiving_plant_in_sap_system_code,       --Принимающий завод грузополучателя в системе SAP!!!! 
	dt_bill_of_lading,                        --Дата коносамента!!!!
	material_code,                            --Номер материала
	material_name,                            --Наименование материала
	delivery_basis,                           --Базис поставки!!!!
	customer_code,                            --Покупатель!!!!
	customer_name,
	dt_ownership_transfer,                    --Дата ППС
	dt_shipment,                              --Дата отгрузки!!!!
	--delivery_country,                         --Страна поставки!!!!
	--delivery_region_code,                     --Регион поставки(код)!!!!
	delivery_region,                          --Регион поставки
	delivery_region_rus_name,                 --Регион поставки на русском
	dt_prepared_for_realization,                --Дата готовности в релизу SD.000344
	dt_updated,                                 --дата изменения на источнике
	material_group_for_scm_report_name,      --Группа материала для отчета Металл в Цепочке Поставок
	dt_realization_forecast,                   --Расчетная дата реализации
	vessel_and_voyage_plan_search_name,      --Судно / номер рейса (план)
	vessel_and_voyage_actual_search_name,     --Судно / номер рейса (факт)
	dt_barge_loading,                                --Дата погрузки на баржу
	dt_barge_arrival                                --Дата доставки баржи
	,delivery_country_in_contract_code        --SD.000577 Страна поставки по контракту (код)
	,commitment_weight
	,total_commitment_weight
	,lot_code
	,homogenisation_name
	,homogenisation_rus_name
	,port_of_discharge_country_code
	,dt_warehouse_confirmation
	,second_shipping_instruction_code
	,dt_release
	,notice_name
	,dt_notice
	,final_release_code
	,dt_final_invoice_payment
	,vehicle_in_foreign_port_code
	,vehicle_type_in_foreign_port_code
	--,shipment_market_name
	,is_consigment_warehouse_applicable
	,dt_transfer_from_consignment_to_customer
	,dt_forwarder_discharge_invoice_or_cmr_documented
	,transportation_scenario_code
	,delivery_country_in_contract_name             --SD.000576 Страна поставки по контракту 
	,delivery_country_in_contract_rus_name         --SD.000576 Страна поставки по контракту 
	,prepared_for_realization_status_name,
	bill_of_lading_in_foreign_port,
	bill_of_lading_in_foreign_port_nomination,
	bill_of_lading_number,
	business_location_name,    -- Статус в Supply chain (Business) SD.000492
	container_after_repacking,
	contract_name,
	contract_plan_code,
	contract_plan_name,
	customer_grade_name,
	delivery_instruction_code,
	delivery_notice_number,
	dimensions_unit,
	dt_arrival_by_railway,
	dt_arrival_in_port_of_discharge,
	dt_arrival_in_port_of_discharge_plan,
	dt_arrived_via_ul_system,
	dt_delivery_notice,
	dt_discharge_in_foreign_port,
	dt_expected_bill_of_lading,
	dt_expected_delivery,
	dt_final_release,
	dt_forwarder,
	dt_repacked,
	dt_sailed_loading_port,
	dt_storage_end_in_foreign_port,
	dt_storage_start_in_foreign_port, --"Дата начала хранения ин. склад" SD.000175
	dt_storage_start_in_second_foreign_warehouse,
	dt_warehouse,
	external_contract_in_lot_number,
	finish_good_group_code,
	finish_good_unit_diameter,
	finish_good_unit_height,
	finish_good_unit_length,
	finish_good_unit_width,
	foreign_port_of_discharge_location_code,
	forwarder_name,
	incoterms_location_plan_code,
	incoterms_plan_code,
	instruction_number,
	invoice_final_number,
	invoice_provisional_number,
	is_plan_or_actual,
	is_shipped_via_overseas_second_foreign_warehouse,
	is_shipped_via_overseas_warehouse,
	lot_contract_code,
	lot_customer_code,
	lot_customer_name,
	lot_delivery_basis_code,
	lot_delivery_point_name,
	material_shape_name_full,
	material_shape_rus_name_full,
	material_specification_name,
	pb_number,
	pieces,
	plant_owner_code,
	pledge_in_bank_name,
	port_of_loading_in_foreign_port_name,     --SD.000053 Порт погрузки 2
	port_of_loading_in_foreign_port_rus_name, --SD.000053 Порт погрузки 2 на русском
	railcar,
	railway_movement_status_name,
	railway_platform,
	release_group_name,
	sales_contract_code,
	second_foreign_port_of_discharge_location_code,
	shipment_period_preferred,
	station_destination,
	transport_bill,
	transport_railcar_type_name,           --SD.000029 Тип вагона
	transport_railcar_type_rus_name,       --SD.000029 Тип вагона на русском
	uni_in_shipment,
	vessel_in_foreign_port_actual_name,
	warehouse_gross_weight,
	warehouse_shipment_type_name,
	exporter_name,                           --Экспортер (код)
	country_of_end_user_name,                  --Страна конечного потребителя
	country_of_end_user_rus_name,             -- SD.000601 Страна конечного потребителя на русском
	buyer_plan_name,                          --Плановый покупатель
	customer_for_scm_report_name,             --Клиент для отчета Металл в Цепочке Поставок
	forwarder_instruction_name,                --Поручение
	dt_forwarder_instruction,                         --Дата поручения
	forwarder_in_foreign_port_name,           --Экспедитор в иностранном порту
	dt_storage_payed_in_foreign_port_by_rusal,        --Дата окончания хранения на складе за счет RUSAL по Релизу
	shipment_instruction_in_foreign_port_name, --Инструкция на отгрузку Ин Порт
	dt_shipment_instruction_in_foreign_port,          --Дата инструкции на отгрузку Ин Порт
	dt_shipment_instruction_date_from,                --Инструкция на отгрузку хранение по графику 'Дата с'
	dt_shipment_instruction_date_to,                  --Инструкция на отгрузку хранение по графику 'Дата по'
	shipment_instruction_in_second_foreign_port_name, --Инструкция на отгрузку Ин Порт 2
	dt_shipment_instruction_in_second_foreign_port,   --Дата инструкции на отгрузку Ин Порт 2
	dt_invoice_provisional,                           --Дата предварительного инвойса
	provisional_invoice_payment_status_code,    --Статус оплаты предварительного инвойса
	invoice_provisional_code,                  --Фактура предварительного инвойса
	mh1_storage_document_number,               --Акт на склад СВХ
	dt_mh1_storage_document,                          --Дата акта на склад СВХ
	--mh3_storage_document_number,               --Акт со склада СВХ
	--dt_mh3_storage_document,                          --Дата акта со склада СВХ
	dt_departure_from_foreigh_port,                 --EXP: Load out date -- Данчик вытаскивал
	foreign_port_terminal_name,                                --Данчик вытаскивал
	russian_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code
	foreign_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code 2
	uzbekistan_cargo_declaration_73,             --EXP: ГТД ИМ73
	shipment_instruction_in_foreign_port_code,   --Группа инструкции на отгрузку Ин Порт
	customer_special_requirement,                   --Номер заказа клиента
	plant_producer_name,                           --Завод производитель
	vessel_plan_name,                              --Судно план
	dt_bill_of_lading_in_foreign_port,                 --Дата коносамента в ин.порту
	dt_arrival_in_second_port_of_discharge,            --Дата прибытия в порт выгрузки 2
	port_of_discharge_in_foreign_port_name,        --Второй иностранный порт
	dt_storage_end_in_second_foreign_warehouse,        --Окончание хранение склад 2
	railway_train_number,                        --Номер поезда
	customs_declaration_number,                  --Номер ГТД (код)
	sales_team_code,                             --Сбытовая команда (код) 
	sales_team_name,                              --Сбытовая команда 
	ready_for_realization_status_name,           --Статус готовности к реализации
	receiving_plant_in_sap_system_name,           --Принимающий завод грузополучателя в системе SAP
	port_of_discharge_plan_code,                             --Плановый порт выгрузки (код)
	port_of_discharge_plan_name,                              --Плановый порт выгрузки
	second_foreign_port_of_discharge_plan_code,              --Плановый порт выгрузки 2 (код)
	second_foreign_port_of_discharge_plan_name,               --Плановый порт выгрузки 2
	dt_arrival_in_port_of_destination,                   --Дата прибытия в порт назначения
	voyage_number_internal,                      --Номер рейса внутренний
	vessel_and_voyage_number_reporting_name,    --Судно / Номер рейса / Номер рейса поставщика
	shipment_instruction_group_ds,              --Группа инструкции ДСБ (код)
	dt_shipment_instruction_ds,                        --Дата инструкции ДСБ
	shipment_instruction_number_ds,                    --Номер инструкции ДСБ 
	shipment_instruction_nomination_code_ds,                    --Номинация инструкции ДСБ 
	--ver 108
	end_buyer_code,                              --Конечный покупатель (код) SD.000640
	country_of_end_user_code,                     --Страна конечного потребителя (код) SD.000641    
	country_of_customer_code,                    --Страна покупателя (код) SD.000643         
	country_of_customer_name,                    --Страна покупателя SD.000644  
	country_of_destination_port_code,            --Страна порта назначения (код) SD.000646    
	country_of_destination_port_name,            --Страна порта назначения  SD.000647
	is_mirrored_resale_code,                     --Зеркало SD.000648    
	delivery_region_code,                        --Регион поставки по контракту (код) SD.000652      
	supply_chain_customer_portal_status_name,    --Статус в Supply chain (Portal) SD.000656  
	port_of_destination_code,                    --Порт назначения (код) SD.000645  
	--ver 125
	dt_realization_for_reporting,                 --Дата реализации План/Факт SD.000683
	dt_realization_for_reporting_mmyyyy,          --Месяц реализации SD.000684 
	--ver 132
	dt_quota_yyyymm,                             --Quota для бизнеса SD.000687 
	storage_duration_in_calendar_days,                      --Сроки нахождения в локации SD.000688
	--ver 136
	is_vehicle_allocated_name,				    -- Признак Распределенный вагон SD.000664
	--ver 108 new
	sap_shipdata_reference_code,						-- ID_SHIPDATA SD.000654
	--129
	dt_realization,											-- Дата реализации SD.000687
	internal_compound_key_code,						-- Внутренний уникальный идентификатор записи SD.000688
	--108
	bill_of_lading_group_code,							-- Группа коносамента SD.000040
	bill_of_lading_route,								-- Маршрут коносамента SD.000043
	lot_group,											-- Группа лот SD.000061
	port_of_loading_code,								-- Порт погрузки (код) SD.000649
	port_of_loading_name,								-- Порт погрузки SD.000653
	port_of_loading_rus_name,				 			-- SD.000653 Порт погрузки ru
	--137
	buyer_agent_code,									-- Trading company (код) SD.000703
	buyer_agent_name,									-- Trading company SD.000704
	--146
	pb1_number,										-- Номер PB 1 SD.000592
	pb2_number,										-- Номер PB 2 SD.000593
	pb3_number,										-- Номер PB 3 SD.000594
	pb1_warehouse_name,								-- Склад PB 1 SD.000595
	pb2_warehouse_name,								-- Склад PB 2 SD.000596
	pb3_warehouse_name,								-- Склад PB 3 SD.000597
	----153
    sales_order_in_shipment,                         -- Заказ ЦК в отгрузке SD.000005
    is_tolling_code,                                 -- Признак толлинг SD.000749
    location_stay_duration_category_code,            -- Сроки нахождения в локации (месяц) SD.000750
	----154
    dt_pb1_number,                                            -- Date PB 1 SD.000751
	dt_pb2_number,                                            -- Date PB 2 SD.000752
	dt_pb3_number,                                            -- Date PB 3 SD.000753    
	---Оборотный капитал     
	transport_railcar_type_code,						-- Тип вагона (код) SD.000028
    dt_arrival_in_second_port_of_discharge_plan,             -- Дата прибытия в порт выгрузки 2 план SD.000157
    dt_train_scheduled_arrival,	 							-- Плановая дата прибытия по ЖД (с фактом) SD.000697
    second_port_of_discharge_country_code,              -- Код страны порта выгрузки 2 SD.000768
    second_port_of_discharge_region_code,               -- Код региона порта выгрузки 2 SD.000769
    second_port_of_discharge_region_name,             -- Регион порт выгрузки 2 SD.000770
    second_port_of_discharge_region_rus_name,         -- Регион порт выгрузки 2 SD.000770 на русском
    customer_for_scm_report_code,                      -- Клиент для отчета Металл в Цепочке Поставок (код) SD.000771  
    country_of_customer_for_reporting_code,            -- Код страны Клиент для отчета Металл в Цепочке Поставок SD.000772 
    country_of_customer_for_reporting_name,            -- Cтрана Клиент для отчета Металл в Цепочке Поставок SD.000773 
  ------
	----данные срезов
    business_location_for_reporting_name,                      -- Статус среза SD.000717
    plan_or_actual_code,                          -- Источник данных среза План/Факт SD.000718
 ---------новые
    normative_railway_trip_duration_days_quantity,     -- SD.000774 Норма движения по жд (дни) 
    normative_route_trip_duration_days_quantity,       -- SD.000775 Норма доставки по маршруту завода    --------        
	normative_marine_transit1_duration_days_quantity,  -- SD.000776 Норма морского транзита  
    normative_marine_transit2_duration_days_quantity,   -- SD.000777 Норма морского транзита 2  
     ----166
    consignee_code,									   -- Получатель материала (код) SD.000080
	consignee_name,									   -- Грузополучатель SD.000081
	customs_invoice_code,                              -- SD.000779 Custom's invoice Group 
	customs_invoice_number,                            -- SD.000780 Custom's invoice Number 
	dt_customs_invoice,                                -- SD.000781 Custom's invoice Date 
	--------177
    tolling_scheme_name,                                -- SD.000908 Толлинг 
     ---
    receiving_warehouse_code,							-- Принимающий склад SD.000098
   -- business_location_stay_normative_weight,
    business_location_stay_normative_average_allocated_weight,
  ------новые для ОК
    material_group_for_wc_reporting_name,              -- SD.000959 Группа материалов для отчета Оборотный капитал
    material_group_for_wc_reporting_rus_name,              -- SD.000959 Группа материалов для отчета Оборотный капитал
    business_location_for_wc_reporting_name,           -- SD.000960 Локация для отчета Оборотный капитал
    business_location_plan_weight,                     -- SD.000961 Цель для Локации отчета Оборотный капитал
    material_cost_actual_hfm_usd_currency_amount,      -- HFM стоимоть
    material_cost_actual_usd_currency_amount,          -- SD.000962 Сумма в доллар ФАКТ
    material_cost_plan_usd_currency_amount,            -- SD.000963 Сумма в доллар ЦЕЛЬ
    business_location_allocated_plan_weight,           -- SD.000964 Цель пропорциональная
    report_comment1_text,                              -- SD.000965 Комментарий 1
    report_comment2_text,                              -- SD.000966 Комментарий 2
    report_comment3_text,                              -- SD.000967 Комментарий 3
     ---DWH-6803
	warehouse_or_responsible_customer_for_storage_name/*calculated_location_name*/,
	---215
	dt_shipment_actual,										-- SD.000976 "Дата отгрузки из Shipdata"
	---236
	dt_acceptance_in_russian_port_planned,                  -- SD.000705 Плановая дата принятия в порту РФ 
	---241
	vessel_load_daily_plan_weight,                           -- SD.001045 Цель погрузки на судно 
    vessel_load_daily_allocated_plan_weight,                  -- SD.001046 Цель пропорциональная погрузки на судно 
    ---237
	forwarder_in_foreign_port_code,                      -- SD.000950 Экспедитор в иностранном порту (код)  
	--247
	warehouse_code,                                                 -- SD.000420 Удаленный склад (код)
	warehouse_name,                                                 -- SD.000421 Удаленный склад
	country_of_remote_warehouse_code,                               -- SD.000725 Страна удаленного склада (код)
	country_of_remote_warehouse_name,                               -- SD.000423 Страна удаленного склада
	region_of_remote_warehouse_code,                                -- SD.000726 Регион удаленного склада (код)
	region_of_remote_warehouse_name,                                 -- SD.000727 Регион удаленного склада 
	--237
	fwrd_info_second_foreign_warehouse_location_name,										-- EXP: Storage location 2 SD.000941 
	receiving_warehouse_name, 										-- Принимающий склад SD.001036	
	--236
	material_group_name,                                             --SD.0000?? Группа материала название
	buyer_plan_code,                                                 -- SD.000124 Плановый покупатель (код)
	dt_shipment_yyyymm,            					       			-- SD.000893 "Месяц Дата отгрузки с завода"   
	--274
	dt_bill_of_lading_in_russian_port_created,         -- SD.001214 Дата загрузки Коносамента РФ в САП
	dt_bill_of_lading_in_foreign_port_created,         --SD.001215 Дата загрузки Коносамента ин. порта в САП
	dt_bill_of_lading_in_russian_port_scan_copy_uploaded, -- SD.001216 Дата загрузки скан образа в САП для Коносамента РФ 
	bill_of_lading_group_code_in_foreign_port,         --SD.000047 Группа коносамента в ин.порту
	dt_bill_of_lading_in_foreign_port_scan_copy_uploaded,  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта    
	-----237 DWH-8015
	storage_duration_total_calendar_days,                --SD.001037 (LE.001086) Количество дней хранения
    storage_duration_free_by_contract_calendar_days,     --SD.001038 (LE.001087) Количество дней бесплатного хранения по договору
    storage_duration_payable_calendar_days,              --SD.001039(LE.001089) Количество дней платного хранения
    storage_cost_calculated_amount,                      --SD.001040(LE.001090 ) Расчетная стоимость
    storage_calculated_cost_total_amount,                 --SD.001041(LE.001116) Сумма платного хранения 
     --302
	country_of_consignee_code,                            --SD.001360 Код страны грузоплучателя 
	--311
	storage_duration_in_russian_port_in_calendar_days,    --SD.001385 Количество дней хранения в порту РФ
	storage_duration_in_russian_port_category_code,        --SD.001386 Категория хранения в порту РФ
	dt_arrival_by_railway_planned							--SD.001395 Плановая дата прибытия по жд (нормативная)
) 
-- Данные из озера
select --count(*)
	scm.dt_report,                                --Отчетная дата
	scm.realization_status,                       --Статус реализации 
	scm.plant_producer_code,                      --Завод производитель (код)
	scm.plant_manufact,                           --Завод производитель
	plant_manufact_rus_name,                      --Завод производитель на русском
	scm.direction,                    		     -- Направление --Порт погрузки в МКТРЕК
	scm.direction_rus,                           --SD.000009 Направление на русском --Порт погрузки в МКТРЕК
	scm.tsw_location_code,                        --Порт погрузки(код) в МКТРЕК
	scm.material_type,                            --Тип материала
	scm.material_rus_type,                        --Тип материала на русском
	scm.material_group_report_mc,                 --Группа материала для отчета Металл в Цеп 
	scm.shipment_market_code,                     --Рынок в отгрузке (код)!!!!
	scm.ovk_market_text,                          --Рынок в отгрузке
	scm.weight_net,                               --Вес нетто
	scm.weight_nk,                                --Вес НК
	scm.weight_gross,                             --Вес брутто!!!!
	scm.quota,                                    --Quota 
	scm.port_of_discharge_code,                   --SD.000044 Порт выгрузки (код) 
	scm.port_discharge,                           --SD.000045 Порт выгрузки
	scm.port_discharge_rus,                       --SD.000045 Порт выгрузки на русском
	scm.port_of_discharge_in_foreign_port_code,   --Второй иностранный порт(код)
	scm.port_discharge_abroad_sec,                --SD.000055 Второй иностранный порт
	scm.port_discharge_abroad_sec_rus,            --SD.000055 Второй иностранный порт на русском
	scm.delivery_point_name,                      --Пункт доставки по инкотермс
	scm."ordering",                               --Order              --Заказ ЦK в МКТРЕК 
	scm.metal_grade,                              --Марка --Марка по спецификации в МКТРЕК
	scm.buyer_end_name,                           --End Buyer ----Конечный потребитель
	scm.delivery_split_reason_code,               --Причина деления (код)!!!!
	scm.delivery_split_reason_name,               --Причина деления 
	scm.location_from_stock as"location",
	scm.location_from_stock,                               --Локация
	scm.country_of_discharge_port_code,         --Страна POD (код)!!!!
	scm.country,                                  --Страна POD
	scm.country_rus_name,                         --Страна POD на русском
	scm.region_of_destination_port_code,          --Регион POD (код)!!!!
	scm.region,                                   --Регион POD 
	scm.region_rus_name,                              --Регион POD 
	scm.dest_port,                                --Порт назначения
	scm.delivery_number_initial,                  --Исходная поставка!!!!
	scm.delivery_number_sales,                    --Продажная поставка!!!!
	scm.delivery_number_outbound,                 --Исходящая поставка !!!!
	scm.delivery_number_of_producer_plant,        --Заводская поставка !!!!
	scm.batch,                                    --Партия!!!!
	scm.uni,
	scm.dt_release_material,                      --Дата ОМ !!!!
	scm.release_material_status_code,             --Статус ОМ!!!!
	scm.ovk_port_vigruz_group,                    --Порт выгрузки группа 
	scm.receiving_plant_in_sap_system_code,       --Принимающий завод грузополучателя в системе SAP!!!! 
	scm.dt_bill_of_lading,                        --Дата коносамента!!!!
	scm.material_code,                            --Номер материала
	scm.material_name,                            --Наименование материала
	scm.delivery_basis,                           --Базис поставки!!!!
	scm.customer_code,                            --Покупатель!!!!
	scm.customer_name,
	scm.dt_ownership_transfer,                    --Дата ППС
	scm.dt_shipment,                              --Дата отгрузки!!!!
	--scm.delivery_country,                         --Страна поставки!!!!
	--scm.delivery_region_code,                     --Регион поставки(код)!!!!
	scm.delivery_region,                          --Регион поставки
	scm.delivery_region_rus_name,                 --Регион поставки
	scm.dt_prepared_for_realization,               --Дата готовности в релизу
	scm.dt_updated,                                 --дата изменения на источнике
	scm.material_group_for_scm_report_name,      --Группа материала для отчета Металл в Цепочке Поставок
	scm.dt_realization_forecast,                   --Расчетная дата реализации
	scm.vessel_and_voyage_plan_search_name,      --Судно / номер рейса (план)
	scm.vessel_and_voyage_actual_search_name,     --Судно / номер рейса (факт)
	scm.dt_barge_loading,                                --Дата погрузки на баржу
	scm.dt_barge_arrival                                --Дата доставки баржи
	-----
	,scm.delivery_country_in_contract_code      --SD.000577 Страна поставки по контракту (код)
	,scm.commitment_weight
	,scm.total_commitment_weight
	,scm.lot_code
	,scm.homogenisation_name
	,scm.homogenisation_rus_name
	,scm.port_of_discharge_country_code
	,scm.dt_warehouse_confirmation
	,scm.second_shipping_instruction_code
	,scm.dt_release
	,scm.notice_name
	,scm.dt_notice
	,scm.final_release_code
	,scm.dt_final_invoice_payment
	,scm.vehicle_in_foreign_port_code
	,scm.vehicle_type_in_foreign_port_code
	--,scm.shipment_market_name
	,scm.is_consigment_warehouse_applicable
	,scm.dt_transfer_from_consignment_to_customer
	,scm.dt_forwarder_discharge_invoice_or_cmr_documented
	,scm.transportation_scenario_code
	,scm.delivery_country_in_contract_name          --SD.000576 Страна поставки по контракту 
	,scm.delivery_country_in_contract_rus_name      --SD.000576 Страна поставки по контракту 
	,scm.prepared_for_realization_status_name,
	scm.bill_of_lading_in_foreign_port,
	scm.bill_of_lading_in_foreign_port_nomination,
	scm.bill_of_lading_number,
	scm.business_location_sap_precalc_name as business_location_name,  -- Статус в Supply chain (Business) SD.000492
	scm.container_after_repacking,
	scm.contract_name,
	scm.contract_plan_code,
	scm.contract_plan_name,
	scm.customer_grade_name,
	scm.delivery_instruction_code,
	scm.delivery_notice_number,
	scm.dimensions_unit,
	scm.dt_arrival_by_railway,
	scm.dt_arrival_in_port_of_discharge,
	scm.dt_arrival_in_port_of_discharge_plan,
	scm.dt_arrived_via_ul_system,
	scm.dt_delivery_notice,
	scm.dt_discharge_in_foreign_port,
	scm.dt_expected_bill_of_lading,
	scm.dt_expected_delivery,
	scm.dt_final_release,
	scm.dt_forwarder,
	scm.dt_repacked,
	scm.dt_sailed_loading_port,
	scm.dt_storage_end_in_foreign_port,
	scm.dt_storage_start_in_foreign_port,
	scm.dt_storage_start_in_second_foreign_warehouse,
	scm.dt_warehouse,
	scm.external_contract_in_lot_number,
	scm.finish_good_group_code,
	scm.finish_good_unit_diameter,
	scm.finish_good_unit_height,
	scm.finish_good_unit_length,
	scm.finish_good_unit_width,
	scm.foreign_port_of_discharge_location_code,
	scm.forwarder_name,
	scm.incoterms_location_plan_code,
	scm.incoterms_plan_code,
	scm.instruction_number,
	scm.invoice_final_number,
	scm.invoice_provisional_number,
	scm.is_plan_or_actual,
	scm.is_shipped_via_overseas_second_foreign_warehouse,
	scm.is_shipped_via_overseas_warehouse,
	scm.lot_contract_code,
	scm.lot_customer_code,
	scm.lot_customer_name,
	scm.lot_delivery_basis_code,
	scm.lot_delivery_point_name,
	scm.material_shape_name_full,
	scm.material_shape_rus_name_full,
	scm.material_specification_name,
	scm.pb_number,
	scm.pieces,
	scm.plant_owner_code,
	scm.pledge_in_bank_name,
	scm.port_of_loading_in_foreign_port_name,     --SD.000053 Порт погрузки 2
	scm.port_of_loading_in_foreign_port_rus_name, --SD.000053 Порт погрузки 2 на русском
	scm.railcar,
	scm.railway_movement_status_name,
	scm.railway_platform,
	scm.release_group_name,
	scm.sales_contract_code,
	scm.second_foreign_port_of_discharge_location_code,
	scm.shipment_period_preferred,
	scm.station_destination,
	scm.transport_bill,
	scm.transport_railcar_type_name,           --SD.000029 Тип вагона
	scm.transport_railcar_type_rus_name,       --SD.000029 Тип вагона на русском
	scm.uni_in_shipment,
	scm.vessel_in_foreign_port_actual_name,
	scm.warehouse_gross_weight,
	scm.warehouse_shipment_type_name,
	scm.exporter_name,                           --Экспортер (код)
	scm.country_of_end_user_name,                  --Страна конечного потребителя
	scm.country_of_end_user_rus_name,            -- SD.000601 Страна конечного потребителя на русском
	scm.buyer_plan_name,                          --Плановый покупатель
	scm.customer_for_scm_report_name,             --Клиент для отчета Металл в Цепочке Поставок
	scm.forwarder_instruction_name,                --Поручение
	scm.dt_forwarder_instruction,                         --Дата поручения
	scm.forwarder_in_foreign_port_name,           --Экспедитор в иностранном порту
    scm.dt_storage_payed_in_foreign_port_by_rusal,        --Дата окончания хранения на складе за счет RUSAL по Релизу
	scm.shipment_instruction_in_foreign_port_name, --Инструкция на отгрузку Ин Порт
	scm.dt_shipment_instruction_in_foreign_port,          --Дата инструкции на отгрузку Ин Порт
	scm.dt_shipment_instruction_date_from,                --Инструкция на отгрузку хранение по графику 'Дата с'
	scm.dt_shipment_instruction_date_to,                  --Инструкция на отгрузку хранение по графику 'Дата по'
	scm.shipment_instruction_in_second_foreign_port_name, --Инструкция на отгрузку Ин Порт 2
	scm.dt_shipment_instruction_in_second_foreign_port,   --Дата инструкции на отгрузку Ин Порт 2
	scm.dt_invoice_provisional,                           --Дата предварительного инвойса
	scm.provisional_invoice_payment_status_code,    --Статус оплаты предварительного инвойса
	scm.invoice_provisional_code,                  --Фактура предварительного инвойса
	null as mh1_storage_document_number,               --Акт на склад СВХ
	null as dt_mh1_storage_document,                          --Дата акта на склад СВХ
	--null as mh3_storage_document_number,               --Акт со склада СВХ
	--null as dt_mh3_storage_document,                          --Дата акта со склада СВХ
	scm.dt_departure_from_foreigh_port,                 --EXP: Load out date -- Данчик вытаскивал
	scm.foreign_port_terminal_name,                                --Данчик вытаскивал
	scm.russian_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code
	scm.foreign_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code 2
	scm.uzbekistan_cargo_declaration_73,             --EXP: ГТД ИМ73
	scm.shipment_instruction_in_foreign_port_code,   --Группа инструкции на отгрузку Ин Порт
	scm.customer_special_requirement,                   --Номер заказа клиента
	scm.plant_producer_name,                           --Завод производитель
	scm.vessel_plan_name,                              --Судно план
	scm.dt_bill_of_lading_in_foreign_port,                 --Дата коносамента в ин.порту
	scm.dt_arrival_in_second_port_of_discharge,            --Дата прибытия в порт выгрузки 2
	scm.port_of_discharge_in_foreign_port_name,        --Второй иностранный порт
	scm.dt_storage_end_in_second_foreign_warehouse,        --Окончание хранение склад 2
	scm.railway_train_number,                        --Номер поезда
	scm.customs_declaration_number,                  --Номер ГТД (код)
	scm.sales_team_code,                             --Сбытовая команда (код) 
	scm.sales_team_name,                              --Сбытовая команда 
	scm.ready_for_realization_status_name,         --Статус готовности к реализации
	scm.receiving_plant_in_sap_system_name, --Принимающий завод грузополучателя в системе SAP
	scm.port_of_discharge_plan_code,                             --Плановый порт выгрузки (код)
	scm.port_of_discharge_plan_name,                              --Плановый порт выгрузки
	scm.second_foreign_port_of_discharge_plan_code,              --Плановый порт выгрузки 2 (код)
	scm.second_foreign_port_of_discharge_plan_name,               --Плановый порт выгрузки 2
	scm.dt_arrival_in_port_of_destination,                   --Дата прибытия в порт назначения
	scm.voyage_number_internal,                      --Номер рейса внутренний
	scm.vessel_and_voyage_number_reporting_name,    --Судно / Номер рейса / Номер рейса поставщика
	scm.shipment_instruction_group_ds,              --Группа инструкции ДСБ (код)
	scm.dt_shipment_instruction_ds,                        --Дата инструкции ДСБ
	scm.shipment_instruction_number_ds,                    --Номер инструкции ДСБ 
	scm.shipment_instruction_nomination_code_ds,           --Номинация инструкции ДСБ 
	--ver 108
	scm.end_buyer_code,                              --Конечный покупатель (код) SD.000640
	scm.country_of_end_user_code,                     --Страна конечного потребителя (код) SD.000641    
	scm.country_of_customer_code,                    --Страна покупателя (код) SD.000643         
	scm.country_of_customer_name,                    --Страна покупателя SD.000644  
	scm.country_of_destination_port_code,            --Страна порта назначения (код) SD.000646    
	scm.country_of_destination_port_name,            --Страна порта назначения  SD.000647
	scm.is_mirrored_resale_code,                     --Зеркало SD.000648    
	scm.delivery_region_code,                        --Регион поставки по контракту (код) SD.000652      
	scm.supply_chain_customer_portal_status_name,    --Статус в Supply chain (Portal) SD.000656  
	scm.port_of_destination_code,                     --Порт назначения (код) SD.000645  
	--ver 125
	scm.dt_realization_for_reporting,                 --Дата реализации План/Факт SD.000683
	scm.dt_realization_for_reporting_mmyyyy,           --Месяц реализации SD.000684 
	--ver 132
	concat(left(scm.quota,4),'.',right(scm.quota,2)) dt_quota_yyyymm,     --Quota для бизнеса SD.000687 
	scm.storage_duration_in_calendar_days, --Сроки нахождения в локации SD.000688
	--ver 136
	scm.is_vehicle_allocated_name,				    -- Признак Распределенный вагон SD.000664
	--ver 108 new
	scm.sap_shipdata_reference_code,						-- ID_SHIPDATA SD.000654
	--129
	scm.dt_realization,											-- Дата реализации SD.000687
	scm.internal_compound_key_code,						-- Внутренний уникальный идентификатор записи SD.000688
	--108
	scm.bill_of_lading_group_code,							-- Группа коносамента SD.000040
	scm.bill_of_lading_route,								-- Маршрут коносамента SD.000043
	scm.lot_group,											-- Группа лот SD.000061  
	scm.port_of_loading_code,								-- Порт погрузки (код) SD.000649
	scm.port_of_loading_name,								-- Порт погрузки SD.000653
	scm.port_of_loading_rus_name,				 			-- SD.000653 Порт погрузки ru
	--137
	scm.buyer_agent_code,									-- Trading company (код) SD.000703
	scm.buyer_agent_name,									-- Trading company SD.000704
	--146
	scm.pb1_number,										-- Номер PB 1 SD.000592
	scm.pb2_number,										-- Номер PB 2 SD.000593
	scm.pb3_number,										-- Номер PB 3 SD.000594
	scm.pb1_warehouse_name,								-- Склад PB 1 SD.000595
	scm.pb2_warehouse_name,								-- Склад PB 2 SD.000596
	scm.pb3_warehouse_name,								-- Склад PB 3 SD.000597
	----	153
	scm.sales_order_in_shipment,                         -- Заказ ЦК в отгрузке SD.000005
	scm.is_tolling_code,                                 -- Признак толлинг SD.000749
	case when scm.storage_duration_in_calendar_days::integer=0 then null 
		when scm.storage_duration_in_calendar_days::integer between 1  and 30 then '<=1M'
		when scm.storage_duration_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		when scm.storage_duration_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		when scm.storage_duration_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		when scm.storage_duration_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		else '>1Y' end  as location_stay_duration_category_code,   --Сроки нахождения в локации (месяц) SD.000750 ---------------(!!!)
	----    154
	scm.dt_pb1_number,                                            -- Date PB 1 SD.000751
	scm.dt_pb2_number,                                            -- Date PB 2 SD.000752
	scm.dt_pb3_number,                                            -- Date PB 3 SD.000753
	---Оборотный капитал     
	scm.transport_railcar_type_code,						-- Тип вагона (код) SD.000028
    scm.dt_arrival_in_second_port_of_discharge_plan,             -- Дата прибытия в порт выгрузки 2 план SD.000157
    scm.dt_train_scheduled_arrival,	 							-- Плановая дата прибытия по ЖД (с фактом) SD.000697
    scm.second_port_of_discharge_country_code,              -- Код страны порта выгрузки 2 SD.000768
    scm.second_port_of_discharge_region_code,               -- Код региона порта выгрузки 2 SD.000769
    scm.second_port_of_discharge_region_name,             -- Регион порт выгрузки 2 SD.000770
    scm.second_port_of_discharge_region_rus_name,         -- Регион порт выгрузки 2 SD.000770 на русском
    scm.customer_for_scm_report_code,                      -- Клиент для отчета Металл в Цепочке Поставок (код) SD.000771  
    scm.country_of_customer_for_reporting_code,            -- Код страны Клиент для отчета Металл в Цепочке Поставок SD.000772 
    scm.country_of_customer_for_reporting_name,            -- Cтрана Клиент для отчета Металл в Цепочке Поставок SD.000773 
  ------  
	----данные срезов 164   
    scm.business_location_for_reporting_name,                    -- Статус среза SD.000717
    scm.plan_or_actual_code,                               -- Источник данных среза План/Факт SD.000718    
    ---------новые
    scm.normative_railway_trip_duration_days_quantity,     -- SD.000774 Норма движения по жд (дни) 
    scm.normative_route_trip_duration_days_quantity,       -- SD.000775 Норма доставки по маршруту завода    --------        
	scm.normative_marine_transit1_duration_days_quantity,  -- SD.000776 Норма морского транзита  
    scm.normative_marine_transit2_duration_days_quantity,   -- SD.000777 Норма морского транзита 2  
      ----166
    scm.consignee_code,									   -- Получатель материала (код) SD.000080
	scm.consignee_name,									   -- Грузополучатель SD.000081
	scm.customs_invoice_code,                              -- SD.000779 Custom's invoice Group 
	scm.customs_invoice_number,                            -- SD.000780 Custom's invoice Number 
	scm.dt_customs_invoice,                                -- SD.000781 Custom's invoice Date 
	--------177
    scm.tolling_scheme_name,                                -- SD.000908 Толлинг 
     ---
    scm.receiving_warehouse_code,							-- Принимающий склад SD.000098
    --650 as business_location_stay_normative_weight,  
    0 as business_location_stay_normative_average_allocated_weight,
   scm.material_group_for_wc_reporting_name,              -- SD.000959 Группа материалов для отчета Оборотный капитал
   scm.material_group_for_wc_reporting_rus_name,          -- SD.000959 Группа материалов для отчета Оборотный капитал на русском
   case 
      when scm.business_location_for_reporting_name='Delivered'   
	    then 'Оформление реализации'
	  when scm.business_location_for_reporting_name is null
	    then 'Прочее'
	  else wc.business_location_for_wc_reporting_name
   end as business_location_for_wc_reporting_name,               -- SD.000960 Локация для отчета Оборотный капитал
    case
	   when scm.business_location_for_reporting_name='At station' and n1_1.location_type_code='2'
	    then n1_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='Status Smelter WH' and n1_2.location_type_code='1'
	    then n1_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit Russia' and n2_1.location_type_code='1'
	    then n2_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='In transit Russia' and n2_1_1.location_type_code='2'
	    then n2_1_1.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit Kubal' 
	    then n2_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='On way to customers premises' 
	    then n2_3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
	   		and scm.receiving_warehouse_code=n3.warehouse_code
	   		and scm.shipment_market_code = '3'
	    then n3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='At Russian Port' 
	    then n4.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Marine transit'
	    then n5_1.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Marine transit 2' 
	    then n5_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Barging'
	    then n5_3.normative_days_quantity  
	   when scm.business_location_for_reporting_name='Inland transit to foreign WH' 
	    then n5_4.normative_days_quantity
	   when scm.business_location_for_reporting_name='Tracking to warehouse 2' 
	    then n5_5.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit warehouse'  
	    and scm.region_of_remote_warehouse_code=n6_1.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='In warehouse (not ready for release)'  
	    and scm.region_of_remote_warehouse_code=n6_2.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_2.normative_days_quantity
	   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
	    and scm.region_of_remote_warehouse_code=n6_3.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='At Consignment stock'  
	    and scm.region_of_remote_warehouse_code=n6_4.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_4.normative_days_quantity 
    end as business_location_plan_weight,                        -- SD.000961 Цель для Локации отчета Оборотный капитал
    scm.material_cost_actual_hfm_usd_currency_amount,          --HFM стоимость
    scm.material_cost_actual_usd_currency_amount,          -- SD.000962 Сумма в доллар ФАКТ
    scm.material_cost_plan_usd_currency_amount,             -- SD.000963 Сумма в доллар ЦЕЛЬ
    scm.weight_nk/
    (CASE 
	     WHEN scm.business_location_for_reporting_name IN ('At station', 'Status Smelter WH' )
	    	AND scm.plant_producer_code = bla_plant.plant_producer_code
	    	THEN nullif(bla_plant.weight_nk_bla,0) 
	    WHEN scm.business_location_for_reporting_name IN ('In transit Russia', 'In transit Kubal', 'On way to customers premises', 'At Russian Port')
	    	and scm.tsw_location_code=bla_loc.tsw_location_code
	    	THEN nullif(bla_loc.weight_nk_bla,0) 
	    WHEN scm.business_location_for_reporting_name IN ('In warehouse (ready for release)')
	    	AND scm.business_location_for_reporting_name = bla_wh.business_location_for_reporting_name
	    	and scm.receiving_warehouse_code=bla_wh.receiving_warehouse_code
	    	AND scm.shipment_market_code = '3'
	    	THEN nullif(bla_wh.weight_nk_bla,0) 
	    WHEN scm.business_location_for_reporting_name IN ('In transit warehouse', 'In warehouse (not ready for release)', 'In warehouse (ready for release)', 'At Consignment stock')
	    	--AND scm.business_location_for_reporting_name = bla_reg.business_location_for_reporting_name
	    	and scm.region_of_remote_warehouse_code=bla_reg.region_of_remote_warehouse_code
	    	AND scm.shipment_market_code <> '3'
	    	THEN nullif(bla_reg.weight_nk_bla,0) 
	    WHEN scm.business_location_for_reporting_name IN ('Marine transit', 'Marine transit 2', 'Barging', 'Inland transit to foreign WH', 'Tracking to warehouse 2')
	    	AND scm.business_location_for_reporting_name = bla_reg_loc.business_location_for_reporting_name
	    	and scm.tsw_location_code=bla_reg_loc.tsw_location_code
	    	and scm.delivery_region_code=bla_reg_loc.delivery_region_code
	    	THEN nullif(bla_reg_loc.weight_nk_bla,0) 
	END)*				
    (case
	   when scm.business_location_for_reporting_name='At station' -- завод
	    then n1_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='Status Smelter WH' -- завод
	    then n1_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit Russia' and n2_1.location_type_code='1' -- направление
	    then n2_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='In transit Russia' and n2_1_1.location_type_code='2'	-- направление
	    then n2_1_1.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit Kubal' -- направление
	    then n2_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='On way to customers premises' -- направление
	    then n2_3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
	   		and scm.receiving_warehouse_code=n3.warehouse_code --СкладРФ
	   		and scm.shipment_market_code = '3'
	    then n3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='At Russian Port' -- Направление
	    then n4.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Marine transit'	-- регион+направление
	    then n5_1.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Marine transit 2' -- регион+направление
	    then n5_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Barging'	-- регион+направление
	    then n5_3.normative_days_quantity  
	   when scm.business_location_for_reporting_name='Inland transit to foreign WH' -- регион+направлеине
	    then n5_4.normative_days_quantity
	   when scm.business_location_for_reporting_name='Tracking to warehouse 2' -- регион+направление
	    then n5_5.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit warehouse'  -- регион
	    and scm.region_of_remote_warehouse_code=n6_1.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='In warehouse (not ready for release)'  -- Регион
	    and scm.region_of_remote_warehouse_code=n6_2.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_2.normative_days_quantity
	   when scm.business_location_for_reporting_name='In warehouse (ready for release)' -- Регион
	    and scm.region_of_remote_warehouse_code=n6_3.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='At Consignment stock'  -- регион
	    and scm.region_of_remote_warehouse_code=n6_4.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_4.normative_days_quantity 
    END) as business_location_allocated_plan_weight,             -- SD.000964 Цель пропорциональная
    'Текст комментария 1' as report_comment1_text,               -- SD.000965 Комментарий 1
    'Текст комментария 2' as report_comment2_text,               -- SD.000966 Комментарий 2
    'Текст комментария 3' as report_comment3_text,                -- SD.000967 Комментарий 3   
    ---DWH-6803
	scm.warehouse_or_responsible_customer_for_storage_name,/*calculated_location_name*/
	scm.dt_shipment_actual,
	---236
	scm.dt_acceptance_in_russian_port_planned,                    -- SD.000705 Плановая дата принятия в порту РФ 
	---241
	n4_2.normative_days_quantity as vessel_load_daily_plan_weight, -- SD.001045 Цель погрузки на судно 
	scm.weight_nk*n4_2.normative_days_quantity/(case
                                                  WHEN scm.business_location_for_reporting_name='At Russian Port'
	    	                                           and scm.tsw_location_code=bla_loc.tsw_location_code
	    	                                      THEN nullif(bla_loc.weight_nk_bla,0)
	    	                                      ELSE 0 
	    	                                      end) as vessel_load_daily_allocated_plan_weight, -- SD.001046 Цель пропорциональная погрузки на судно 
    ---237
	scm.forwarder_in_foreign_port_code,                      -- SD.000950 Экспедитор в иностранном порту (код)
	--247
	scm.warehouse_code,                                                 -- SD.000420 Удаленный склад (код)
	scm.warehouse_name,                                                 -- SD.000421 Удаленный склад
	scm.country_of_remote_warehouse_code,                               -- SD.000725 Страна удаленного склада (код)
	scm.country_of_remote_warehouse_name,                               -- SD.000423 Страна удаленного склада
	scm.region_of_remote_warehouse_code,                                -- SD.000726 Регион удаленного склада (код)
	scm.region_of_remote_warehouse_name,                                 -- SD.000727 Регион удаленного склада 	
	scm.fwrd_info_second_foreign_warehouse_location_name,										-- EXP: Storage location 2 SD.000941 
	scm.receiving_warehouse_name, 										-- Принимающий склад SD.0010036	
	--236
	scm.material_group_name,                                            -- SD.0000?? Группа материала название
	scm.buyer_plan_code,                                                -- SD.000124 Плановый покупатель (код)
	to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm, 	        -- SD.000893 "Месяц Дата отгрузки с завода"   
	--274
	scm.dt_bill_of_lading_in_russian_port_created,         -- SD.001214 Дата загрузки Коносамента РФ в САП
	scm.dt_bill_of_lading_in_foreign_port_created,         --SD.001215 Дата загрузки Коносамента ин. порта в САП
	scm.dt_bill_of_lading_in_russian_port_scan_copy_uploaded, -- SD.001216 Дата загрузки скан образа в САП для Коносамента РФ 
	scm.bill_of_lading_group_code_in_foreign_port,         --SD.000047 Группа коносамента в ин.порту
	scm.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded,  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта 
	-----237 DWH-8015
	scm.storage_duration_total_calendar_days,                --SD.001037 (LE.001086) Количество дней хранения
    scm.storage_duration_free_by_contract_calendar_days,     --SD.001038 (LE.001087) Количество дней бесплатного хранения по договору
    scm.storage_duration_payable_calendar_days,              --SD.001039(LE.001089) Количество дней платного хранения
    scm.storage_cost_calculated_amount,                      --SD.001040(LE.001090 ) Расчетная стоимость
    scm.storage_calculated_cost_total_amount,                 --SD.001041(LE.001116) Сумма платного хранения   
     --302
	scm.country_of_consignee_code,                            --SD.001360 Код страны грузоплучателя 
	--311
	scm.storage_duration_in_russian_port_in_calendar_days,    --SD.001385 Количество дней хранения в порту РФ
	 case
   	    when scm.storage_duration_in_russian_port_in_calendar_days is not null 
        then case
	         when scm.storage_duration_in_russian_port_in_calendar_days::integer=0 then null
   	         when scm.storage_duration_in_russian_port_in_calendar_days::integer between 1  and 30 then '<=1M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		     else '>1Y'
		    end
   	  end as storage_duration_in_russian_port_category_code,      --SD.001386 Категория хранения в порту РФ
   	  scm.dt_arrival_by_railway_planned							--SD.001395 Плановая дата прибытия по жд (нормативная)
from sd_sales_stock_by_date scm	
----связи с ZTSD8787M_1	
left join dds.sales_location_stay_normative  as n1_1 --ОК
         on scm.business_location_for_reporting_name=n1_1.business_location_for_reporting_name  
         and scm.plant_producer_code=n1_1.plant_code 
         and to_char(scm.dt_report,'YYYYMM')=concat(n1_1.dt_normative_yyyy,n1_1.dt_normative_mm) 
         and n1_1.source_table_name='ZTSD8787M_1'
         and n1_1.business_location_for_reporting_name='At station'
         and n1_1.location_type_code='2'
left join dds.sales_location_stay_normative  as n1_2 --ОК
         on scm.business_location_for_reporting_name=n1_2.business_location_for_reporting_name  
         and scm.plant_producer_code=n1_2.plant_code 
         and to_char(scm.dt_report,'YYYYMM')=concat(n1_2.dt_normative_yyyy,n1_2.dt_normative_mm) 
         and n1_2.source_table_name='ZTSD8787M_1'
         and n1_2.business_location_for_reporting_name='Status Smelter WH'
         and n1_2.location_type_code='1'
left join dds.sales_location_stay_normative  as n2_1 --ОК
         on scm.business_location_for_reporting_name=n2_1.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_1.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_1.dt_normative_yyyy,n2_1.dt_normative_mm)
          and n2_1.source_table_name='ZTSD8787M_2'
          and n2_1.business_location_for_reporting_name='In transit Russia'
          and n2_1.location_type_code='1'
left join dds.sales_location_stay_normative  as n2_1_1 --ОК
         on scm.business_location_for_reporting_name=n2_1_1.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_1_1.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_1_1.dt_normative_yyyy,n2_1_1.dt_normative_mm)
          and n2_1_1.source_table_name='ZTSD8787M_2'
          and n2_1_1.business_location_for_reporting_name='In transit Russia'
          and n2_1_1.location_type_code='2'          
left join dds.sales_location_stay_normative  as n2_2 --ОК
         on scm.business_location_for_reporting_name=n2_2.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_2.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_2.dt_normative_yyyy,n2_2.dt_normative_mm)
          and n2_2.source_table_name='ZTSD8787M_2'
          and n2_2.business_location_for_reporting_name='In transit Kubal'
          and n2_2.location_type_code='3'          
left join dds.sales_location_stay_normative  as n2_3 --ОК
         on scm.business_location_for_reporting_name=n2_3.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_3.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_3.dt_normative_yyyy,n2_3.dt_normative_mm)
          and n2_3.source_table_name='ZTSD8787M_2'
          and n2_3.business_location_for_reporting_name='On way to customers premises'  
          and n2_3.location_type_code='4'
----связи с ZTSD8787M_3          
left join dds.sales_location_stay_normative  as n3 --ОК
         on scm.business_location_for_reporting_name=n3.business_location_for_reporting_name  
         and scm.receiving_warehouse_code=n3.warehouse_code 
           and to_char(scm.dt_report,'YYYYMM')=concat(n3.dt_normative_yyyy,n3.dt_normative_mm)  
         and n3.source_table_name='ZTSD8787M_3'
         and n3.business_location_for_reporting_name='In warehouse (ready for release)' 
----связи с ZTSD8787M_4   для  location_type_code='1'       
left join dds.sales_location_stay_normative  as n4 --ОК
         on scm.business_location_for_reporting_name=n4.business_location_for_reporting_name 
          and scm.tsw_location_code=n4.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n4.dt_normative_yyyy,n4.dt_normative_mm) 
          and n4.source_table_name='ZTSD8787M_4'  
          and n4.business_location_for_reporting_name='At Russian Port'
          and n4.location_type_code='1' 
----связи с ZTSD8787M_5            
left join dds.sales_location_stay_normative  as n5_1 --ОК
         on scm.business_location_for_reporting_name=n5_1.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_1.transport_hub_code
          and scm.delivery_region_code=n5_1.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_1.dt_normative_yyyy,n5_1.dt_normative_mm)  
          and n5_1.business_location_for_reporting_name='Marine transit'
          and n5_1.location_type_code='1' 
left join dds.sales_location_stay_normative  as n5_2 --ОК
         on scm.business_location_for_reporting_name=n5_2.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_2.transport_hub_code
          and scm.delivery_region_code=n5_2.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_2.dt_normative_yyyy,n5_2.dt_normative_mm)  
          and n5_2.business_location_for_reporting_name='Marine transit 2'
          and n5_2.location_type_code='1'  
left join dds.sales_location_stay_normative  as n5_3 --ОК
         on scm.business_location_for_reporting_name=n5_3.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_3.transport_hub_code
          and scm.delivery_region_code=n5_3.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_3.dt_normative_yyyy,n5_3.dt_normative_mm)  
          and n5_3.business_location_for_reporting_name='Barging'
          and n5_3.location_type_code='1'         
left join dds.sales_location_stay_normative  as n5_4 --ОК
         on scm.business_location_for_reporting_name=n5_4.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_4.transport_hub_code
          and scm.delivery_region_code=n5_4.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_4.dt_normative_yyyy,n5_4.dt_normative_mm)  
          and n5_4.business_location_for_reporting_name='Inland transit to foreign WH'
          and n5_4.location_type_code='2'        
left join dds.sales_location_stay_normative  as n5_5 --ОК
         on scm.business_location_for_reporting_name=n5_5.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_5.transport_hub_code
          and scm.delivery_region_code=n5_5.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_5.dt_normative_yyyy,n5_5.dt_normative_mm)  
          and n5_5.business_location_for_reporting_name='Tracking to warehouse 2'
          and n5_5.location_type_code='2'     
----связи с ZTSD8787M_6             
left join dds.sales_location_stay_normative  as n6_1 --ОК
         on scm.business_location_for_reporting_name=n6_1.business_location_for_reporting_name 
          and scm.region_of_remote_warehouse_code=n6_1.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_1.dt_normative_yyyy,n6_1.dt_normative_mm)  
          and n6_1.source_table_name='ZTSD8787M_6' 
          and n6_1.business_location_for_reporting_name='In transit warehouse' 
left join dds.sales_location_stay_normative  as n6_2 --ОК
         on scm.business_location_for_reporting_name=n6_2.business_location_for_reporting_name 
          and scm.region_of_remote_warehouse_code=n6_2.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_2.dt_normative_yyyy,n6_2.dt_normative_mm)  
          and n6_2.source_table_name='ZTSD8787M_6' 
          and n6_2.business_location_for_reporting_name='In warehouse (not ready for release)'    
left join dds.sales_location_stay_normative  as n6_3 --ОК
         on scm.business_location_for_reporting_name=n6_3.business_location_for_reporting_name 
          and scm.region_of_remote_warehouse_code=n6_3.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_3.dt_normative_yyyy,n6_3.dt_normative_mm)  
          and n6_3.source_table_name='ZTSD8787M_6' 
          and n6_3.business_location_for_reporting_name='In warehouse (ready for release)' 
left join dds.sales_location_stay_normative  as n6_4 --ОК
         on scm.business_location_for_reporting_name=n6_4.business_location_for_reporting_name 
          and scm.region_of_remote_warehouse_code=n6_4.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_4.dt_normative_yyyy,n6_4.dt_normative_mm)  
          and n6_4.source_table_name='ZTSD8787M_6' 
          and n6_4.business_location_for_reporting_name='At Consignment stock'           
left join business_location_for_wc as wc
         on scm.business_location_for_reporting_name=wc.business_location_for_reporting_name
/*left join business_location_allocated_svh as bla     
         on scm.business_location_for_reporting_name=bla.business_location_for_reporting_name
         and scm.dt_report=bla.dt_report*/
left join business_location_allocated_plant as bla_plant    
         on scm.business_location_for_reporting_name = bla_plant.business_location_for_reporting_name
         and scm.dt_report = bla_plant.dt_report
         AND scm.plant_producer_code = bla_plant.plant_producer_code
left join business_location_allocated_location as bla_loc    
         on scm.business_location_for_reporting_name = bla_loc.business_location_for_reporting_name
         and scm.dt_report = bla_loc.dt_report
         AND scm.tsw_location_code = bla_loc.tsw_location_code
left join business_location_allocated_warehouse as bla_wh    
         on scm.business_location_for_reporting_name = bla_wh.business_location_for_reporting_name
         and scm.dt_report = bla_wh.dt_report
         AND scm.receiving_warehouse_code = bla_wh.receiving_warehouse_code
left join business_location_allocated_region as bla_reg    
         --on scm.business_location_for_reporting_name = bla_reg.business_location_for_reporting_name
         on scm.dt_report = bla_reg.dt_report
         AND scm.region_of_remote_warehouse_code = bla_reg.region_of_remote_warehouse_code
left join business_location_allocated_region_location as bla_reg_loc   
         on scm.business_location_for_reporting_name = bla_reg_loc.business_location_for_reporting_name
         and scm.dt_report = bla_reg_loc.dt_report
         AND scm.delivery_region_code = bla_reg_loc.delivery_region_code
         AND scm.tsw_location_code = bla_reg_loc.tsw_location_code
----связи с ZTSD8787M_4   для  location_type_code='2'    поля 1045 и 1046   
left join dds.sales_location_stay_normative  as n4_2 --ОК
         on scm.business_location_for_reporting_name=n4_2.business_location_for_reporting_name 
          and scm.tsw_location_code=n4_2.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n4_2.dt_normative_yyyy,n4_2.dt_normative_mm) 
          and n4_2.source_table_name='ZTSD8787M_4'  
          and n4_2.business_location_for_reporting_name='At Russian Port'
          and n4_2.location_type_code='2'          
union all 
-- Данные СВХ
select --count(*)
scm.dt_report,                                --Отчетная дата
	scm.realization_status,                       --Статус реализации 
	scm.plant_producer_code,                      --Завод производитель (код)
	scm.plant_manufact,                           --Завод производитель
	scm.plant_manufact_rus_name,                  --Завод производитель на русском
	scm.direction,                    		     -- Направление --Порт погрузки в МКТРЕК
	scm.direction_rus,                           --SD.000009 Направление на русском --Порт погрузки в МКТРЕК
	scm.tsw_location_code,                        --Порт погрузки(код) в МКТРЕК
	scm.material_type,                            --Тип материала
	scm.material_rus_type,                        --Тип материала на русском
	scm.material_group_report_mc,                 --Группа материала для отчета Металл в Цеп 
	scm.shipment_market_code,                     --Рынок в отгрузке (код)!!!!
	scm.ovk_market_text,                          --Рынок в отгрузке
	scm.weight_net,                               --Вес нетто
	scm.weight_nk,                                --Вес НК
	scm.weight_gross,                             --Вес брутто!!!!
	scm.quota,                                    --Quota 
	scm.port_of_discharge_code,                   --SD.000044 Порт выгрузки (код) 
	scm.port_discharge,                           --SD.000045 Порт выгрузки
	scm.port_discharge_rus,                       --SD.000045 Порт выгрузки на русском
	scm.port_of_discharge_in_foreign_port_code,   --Второй иностранный порт(код)
	scm.port_discharge_abroad_sec,                --SD.000055 Второй иностранный порт
	scm.port_discharge_abroad_sec_rus,            --SD.000055 Второй иностранный порт на русском
	scm.delivery_point_name,                      --Пункт доставки по инкотермс
	scm."ordering",                               --Order              --Заказ ЦK в МКТРЕК 
	scm.metal_grade,                              --Марка --Марка по спецификации в МКТРЕК
	scm.buyer_end_name,                           --End Buyer ----Конечный потребитель
	scm.delivery_split_reason_code,               --Причина деления (код)!!!!
	scm.delivery_split_reason_name,               --Причина деления 
	scm.location_from_stock as"location",
	scm.location_from_stock,                               --Локация
	scm.country_of_discharge_port_code,         --Страна POD (код)!!!!
	scm.country,                                  --Страна POD
	scm.country_rus_name,                         --Страна POD на русском
	scm.region_of_destination_port_code,          --Регион POD (код)!!!!
	scm.region,                                   --Регион POD 
	scm.region_rus_name,                          --Регион POD 
	scm.dest_port,                                --Порт назначения
	scm.delivery_number_initial,                  --Исходная поставка!!!!
	scm.delivery_number_sales,                    --Продажная поставка!!!!
	scm.delivery_number_outbound,                 --Исходящая поставка !!!!
	scm.delivery_number_of_producer_plant,        --Заводская поставка !!!!
	scm.batch,                                    --Партия!!!!
	scm.uni,
	scm.dt_release_material,                      --Дата ОМ !!!!
	scm.release_material_status_code,             --Статус ОМ!!!!
	scm.ovk_port_vigruz_group,                    --Порт выгрузки группа 
	scm.receiving_plant_in_sap_system_code,       --Принимающий завод грузополучателя в системе SAP!!!! 
	scm.dt_bill_of_lading,                        --Дата коносамента!!!!
	scm.material_code,                            --Номер материала
	scm.material_name,                            --Наименование материала
	scm.delivery_basis,                           --Базис поставки!!!!
	scm.customer_code,                            --Покупатель!!!!
	scm.customer_name,
	scm.dt_ownership_transfer,                    --Дата ППС
	scm.dt_shipment,                              --Дата отгрузки!!!!
	--scm.delivery_country,                         --Страна поставки!!!!
	--scm.delivery_region_code,                     --Регион поставки(код)!!!!
	scm.delivery_region,                          --Регион поставки
	scm.delivery_region_rus_name,                 --Регион поставки на русском
	scm.dt_prepared_for_realization,               --Дата готовности в релизу
	scm.dt_updated,                                 --дата изменения на источнике
	scm.material_group_for_scm_report_name,      --Группа материала для отчета Металл в Цепочке Поставок
	scm.dt_realization_forecast,                   --Расчетная дата реализации
	scm.vessel_and_voyage_plan_search_name,      --Судно / номер рейса (план)
	scm.vessel_and_voyage_actual_search_name,     --Судно / номер рейса (факт)
	scm.dt_barge_loading,                                --Дата погрузки на баржу
	scm.dt_barge_arrival                                --Дата доставки баржи
	-----
	,scm.delivery_country_in_contract_code       --SD.000577 Страна поставки по контракту (код)
	,scm.commitment_weight
	,scm.total_commitment_weight
	,scm.lot_code
	,scm.homogenisation_name
	,scm.homogenisation_rus_name
	,scm.port_of_discharge_country_code
	,scm.dt_warehouse_confirmation
	,scm.second_shipping_instruction_code
	,scm.dt_release
	,scm.notice_name
	,scm.dt_notice
	,scm.final_release_code
	,scm.dt_final_invoice_payment
	,scm.vehicle_in_foreign_port_code
	,scm.vehicle_type_in_foreign_port_code
	--,scm.shipment_market_name
	,scm.is_consigment_warehouse_applicable
	,scm.dt_transfer_from_consignment_to_customer
	,scm.dt_forwarder_discharge_invoice_or_cmr_documented
	,scm.transportation_scenario_code
	,scm.delivery_country_in_contract_name           --SD.000576 Страна поставки по контракту 
	,scm.delivery_country_in_contract_rus_name       --SD.000576 Страна поставки по контракту 
	,scm.prepared_for_realization_status_name,
	scm.bill_of_lading_in_foreign_port,
	scm.bill_of_lading_in_foreign_port_nomination,
	scm.bill_of_lading_number,
	scm.business_location_sap_precalc_name as business_location_name,  -- Статус в Supply chain (Business) SD.000492
	scm.container_after_repacking,
	scm.contract_name,
	scm.contract_plan_code,
	scm.contract_plan_name,
	scm.customer_grade_name,
	scm.delivery_instruction_code,
	scm.delivery_notice_number,
	scm.dimensions_unit,
	scm.dt_arrival_by_railway,
	scm.dt_arrival_in_port_of_discharge,
	scm.dt_arrival_in_port_of_discharge_plan,
	scm.dt_arrived_via_ul_system,
	scm.dt_delivery_notice,
	scm.dt_discharge_in_foreign_port,
	scm.dt_expected_bill_of_lading,
	scm.dt_expected_delivery,
	scm.dt_final_release,
	scm.dt_forwarder,
	scm.dt_repacked,
	scm.dt_sailed_loading_port,
	scm.dt_storage_end_in_foreign_port,
	scm.dt_storage_start_in_foreign_port,
	scm.dt_storage_start_in_second_foreign_warehouse,
	scm.dt_warehouse,
	scm.external_contract_in_lot_number,
	scm.finish_good_group_code,
	scm.finish_good_unit_diameter,
	scm.finish_good_unit_height,
	scm.finish_good_unit_length,
	scm.finish_good_unit_width,
	scm.foreign_port_of_discharge_location_code,
	scm.forwarder_name,
	scm.incoterms_location_plan_code,
	scm.incoterms_plan_code,
	scm.instruction_number,
	scm.invoice_final_number,
	scm.invoice_provisional_number,
	scm.is_plan_or_actual,
	scm.is_shipped_via_overseas_second_foreign_warehouse,
	scm.is_shipped_via_overseas_warehouse,
	scm.lot_contract_code,
	scm.lot_customer_code,
	scm.lot_customer_name,
	scm.lot_delivery_basis_code,
	scm.lot_delivery_point_name,
	scm.material_shape_name_full,
	scm.material_shape_rus_name_full,
	scm.material_specification_name,
	scm.pb_number,
	scm.pieces,
	scm.plant_owner_code,
	scm.pledge_in_bank_name,
	scm.port_of_loading_in_foreign_port_name,     --SD.000053 Порт погрузки 2
	scm.port_of_loading_in_foreign_port_rus_name, --SD.000053 Порт погрузки 2 на русском
	scm.railcar,
	scm.railway_movement_status_name,
	scm.railway_platform,
	scm.release_group_name,
	scm.sales_contract_code,
	scm.second_foreign_port_of_discharge_location_code,
	scm.shipment_period_preferred,
	scm.station_destination,
	scm.transport_bill,
	scm.transport_railcar_type_name,           --SD.000029 Тип вагона
	scm.transport_railcar_type_rus_name,       --SD.000029 Тип вагона на русском
	scm.uni_in_shipment,
	scm.vessel_in_foreign_port_actual_name,
	scm.warehouse_gross_weight,
	scm.warehouse_shipment_type_name,
	scm.exporter_name,                           --Экспортер (код)
	scm.country_of_end_user_name,                  --Страна конечного потребителя
	scm.country_of_end_user_rus_name,        -- SD.000601 Страна конечного потребителя на русском
	scm.buyer_plan_name,                          --Плановый покупатель
	scm.customer_for_scm_report_name,             --Клиент для отчета Металл в Цепочке Поставок
	scm.forwarder_instruction_name,                --Поручение
	scm.dt_forwarder_instruction,                         --Дата поручения
	scm.forwarder_in_foreign_port_name,           --Экспедитор в иностранном порту
    scm.dt_storage_payed_in_foreign_port_by_rusal,        --Дата окончания хранения на складе за счет RUSAL по Релизу
	scm.shipment_instruction_in_foreign_port_name, --Инструкция на отгрузку Ин Порт
	scm.dt_shipment_instruction_in_foreign_port,          --Дата инструкции на отгрузку Ин Порт
	scm.dt_shipment_instruction_date_from,                --Инструкция на отгрузку хранение по графику 'Дата с'
	scm.dt_shipment_instruction_date_to,                  --Инструкция на отгрузку хранение по графику 'Дата по'
	scm.shipment_instruction_in_second_foreign_port_name, --Инструкция на отгрузку Ин Порт 2
	scm.dt_shipment_instruction_in_second_foreign_port,   --Дата инструкции на отгрузку Ин Порт 2
	scm.dt_invoice_provisional,                           --Дата предварительного инвойса
	scm.provisional_invoice_payment_status_code,    --Статус оплаты предварительного инвойса
	scm.invoice_provisional_code,                  --Фактура предварительного инвойса
	scm.mh1_storage_document_number,               --Акт на склад СВХ
	scm.dt_mh1_storage_document,                          --Дата акта на склад СВХ
	--null as mh3_storage_document_number,               --Акт со склада СВХ
	--null as dt_mh3_storage_document,                          --Дата акта со склада СВХ
	scm.dt_departure_from_foreigh_port,                 --EXP: Load out date -- Данчик вытаскивал
	scm.foreign_port_terminal_name,                                --Данчик вытаскивал
	scm.russian_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code
	scm.foreign_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code 2
	scm.uzbekistan_cargo_declaration_73,             --EXP: ГТД ИМ73
	scm.shipment_instruction_in_foreign_port_code,   --Группа инструкции на отгрузку Ин Порт
	scm.customer_special_requirement,                   --Номер заказа клиента
	scm.plant_producer_name,                           --Завод производитель
	scm.vessel_plan_name,                              --Судно план
	scm.dt_bill_of_lading_in_foreign_port,                 --Дата коносамента в ин.порту
	scm.dt_arrival_in_second_port_of_discharge,            --Дата прибытия в порт выгрузки 2
	scm.port_of_discharge_in_foreign_port_name,        --Второй иностранный порт
	scm.dt_storage_end_in_second_foreign_warehouse,        --Окончание хранение склад 2
	scm.railway_train_number,                        --Номер поезда
	scm.customs_declaration_number,                  --Номер ГТД (код)
	scm.sales_team_code,                             --Сбытовая команда (код) 
	scm.sales_team_name,                              --Сбытовая команда 
	scm.ready_for_realization_status_name,         --Статус готовности к реализации
	scm.receiving_plant_in_sap_system_name, --Принимающий завод грузополучателя в системе SAP
	scm.port_of_discharge_plan_code,                             --Плановый порт выгрузки (код)
	scm.port_of_discharge_plan_name,                              --Плановый порт выгрузки
	scm.second_foreign_port_of_discharge_plan_code,              --Плановый порт выгрузки 2 (код)
	scm.second_foreign_port_of_discharge_plan_name,               --Плановый порт выгрузки 2
	scm.dt_arrival_in_port_of_destination,                   --Дата прибытия в порт назначения
	scm.voyage_number_internal,                      --Номер рейса внутренний
	scm.vessel_and_voyage_number_reporting_name,    --Судно / Номер рейса / Номер рейса поставщика
	scm.shipment_instruction_group_ds,              --Группа инструкции ДСБ (код)
	scm.dt_shipment_instruction_ds,                        --Дата инструкции ДСБ
	scm.shipment_instruction_number_ds,                    --Номер инструкции ДСБ 
	scm.shipment_instruction_nomination_code_ds,           --Номинация инструкции ДСБ 
	--ver 108
	scm.end_buyer_code,                              --Конечный покупатель (код) SD.000640
	scm.country_of_end_user_code,                     --Страна конечного потребителя (код) SD.000641    
	scm.country_of_customer_code,                    --Страна покупателя (код) SD.000643         
	scm.country_of_customer_name,                    --Страна покупателя SD.000644  
	scm.country_of_destination_port_code,            --Страна порта назначения (код) SD.000646    
	scm.country_of_destination_port_name,            --Страна порта назначения  SD.000647
	scm.is_mirrored_resale_code,                     --Зеркало SD.000648    
	scm.delivery_region_code,                        --Регион поставки по контракту (код) SD.000652      
	scm.supply_chain_customer_portal_status_name,    --Статус в Supply chain (Portal) SD.000656  
	scm.port_of_destination_code,                     --Порт назначения (код) SD.000645  
	--ver 125
	scm.dt_realization_for_reporting,                 --Дата реализации План/Факт SD.000683
	scm.dt_realization_for_reporting_mmyyyy,           --Месяц реализации SD.000684 
	--ver 132
	concat(left(scm.quota,4),'.',right(scm.quota,2)) dt_quota_yyyymm,     --Quota для бизнеса SD.000687 
	scm.storage_duration_in_calendar_days, --Сроки нахождения в локации SD.000688
	--ver 136
	scm.is_vehicle_allocated_name,				    -- Признак Распределенный вагон SD.000664
	--ver 108 new
	scm.sap_shipdata_reference_code,						-- ID_SHIPDATA SD.000654
	--129
	scm.dt_realization,											-- Дата реализации SD.000687
	scm.internal_compound_key_code,						-- Внутренний уникальный идентификатор записи SD.000688
	--108
	scm.bill_of_lading_group_code,							-- Группа коносамента SD.000040
	scm.bill_of_lading_route,								-- Маршрут коносамента SD.000043
	scm.lot_group,											-- Группа лот SD.000061  
	scm.port_of_loading_code,								-- Порт погрузки (код) SD.000649
	scm.port_of_loading_name,								-- Порт погрузки SD.000653
	scm.port_of_loading_rus_name,				 			-- SD.000653 Порт погрузки ru
	--137
	scm.buyer_agent_code,									-- Trading company (код) SD.000703
	scm.buyer_agent_name,									-- Trading company SD.000704
	--146
	scm.pb1_number,										-- Номер PB 1 SD.000592
	scm.pb2_number,										-- Номер PB 2 SD.000593
	scm.pb3_number,										-- Номер PB 3 SD.000594
	scm.pb1_warehouse_name,								-- Склад PB 1 SD.000595
	scm.pb2_warehouse_name,								-- Склад PB 2 SD.000596
	scm.pb3_warehouse_name,								-- Склад PB 3 SD.000597
	----	153
	scm.sales_order_in_shipment,                         -- Заказ ЦК в отгрузке SD.000005
	scm.is_tolling_code,                                 -- Признак толлинг SD.000749
	case when scm.storage_duration_in_calendar_days::integer=0 then null 
		when scm.storage_duration_in_calendar_days::integer between 1  and 30 then '<=1M'
		when scm.storage_duration_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		when scm.storage_duration_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		when scm.storage_duration_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		when scm.storage_duration_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		else '>1Y' end  as location_stay_duration_category_code,   --Сроки нахождения в локации (месяц) SD.000750 ---------------(!!!)
	----    154
	scm.dt_pb1_number,                                            -- Date PB 1 SD.000751
	scm.dt_pb2_number,                                            -- Date PB 2 SD.000752
	scm.dt_pb3_number,                                            -- Date PB 3 SD.000753
	---Оборотный капитал     
	scm.transport_railcar_type_code,						-- Тип вагона (код) SD.000028
    scm.dt_arrival_in_second_port_of_discharge_plan,             -- Дата прибытия в порт выгрузки 2 план SD.000157
    scm.dt_train_scheduled_arrival,	 							-- Плановая дата прибытия по ЖД (с фактом) SD.000697
    scm.second_port_of_discharge_country_code,              -- Код страны порта выгрузки 2 SD.000768
    scm.second_port_of_discharge_region_code,               -- Код региона порта выгрузки 2 SD.000769
    scm.second_port_of_discharge_region_name,              -- Регион порт выгрузки 2 SD.000770
    scm.second_port_of_discharge_region_rus_name,          -- Регион порт выгрузки 2 SD.000770 на русском
    scm.customer_for_scm_report_code,                      -- Клиент для отчета Металл в Цепочке Поставок (код) SD.000771  
    scm.country_of_customer_for_reporting_code,            -- Код страны Клиент для отчета Металл в Цепочке Поставок SD.000772 
    scm.country_of_customer_for_reporting_name,            -- Cтрана Клиент для отчета Металл в Цепочке Поставок SD.000773 
  ------  
	----данные срезов 164   
    scm.business_location_for_reporting_name,                    -- Статус среза SD.000717
    scm.plan_or_actual_code,                               -- Источник данных среза План/Факт SD.000718    
    ---------новые
    scm.normative_railway_trip_duration_days_quantity,     -- SD.000774 Норма движения по жд (дни) 
    scm.normative_route_trip_duration_days_quantity,       -- SD.000775 Норма доставки по маршруту завода    --------        
	scm.normative_marine_transit1_duration_days_quantity,  -- SD.000776 Норма морского транзита  
    scm.normative_marine_transit2_duration_days_quantity,   -- SD.000777 Норма морского транзита 2  
      ----166
    scm.consignee_code,									   -- Получатель материала (код) SD.000080
	scm.consignee_name,									   -- Грузополучатель SD.000081
	scm.customs_invoice_code,                              -- SD.000779 Custom's invoice Group 
	scm.customs_invoice_number,                            -- SD.000780 Custom's invoice Number 
	scm.dt_customs_invoice,                                -- SD.000781 Custom's invoice Date 
	--------177
    scm.tolling_scheme_name,                                -- SD.000908 Толлинг 
     ---
    scm.receiving_warehouse_code,							-- Принимающий склад SD.000098
    --650 as business_location_stay_normative_weight,  
    0 as business_location_stay_normative_average_allocated_weight,
   scm.material_group_for_wc_reporting_name,              -- SD.000959 Группа материалов для отчета Оборотный капитал
   scm.material_group_for_wc_reporting_rus_name,          -- SD.000959 Группа материалов для отчета Оборотный капитал на русском
   case 
      when scm.business_location_for_reporting_name='Delivered'   
	    then 'Оформление реализации'
	  when scm.business_location_for_reporting_name is null
	    then 'Прочее'
	  else wc.business_location_for_wc_reporting_name
   end as business_location_for_wc_reporting_name,               -- SD.000960 Локация для отчета Оборотный капитал
    case
	   when scm.business_location_for_reporting_name='At station' and n1_1.location_type_code='2'
	    then n1_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='Status Smelter WH' and n1_2.location_type_code='1' 
	    then n1_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit Russia'  and n2_1.location_type_code='1'
	    then n2_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='In transit Russia' and n2_1_1.location_type_code='2'
	    then n2_1_1.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit Kubal' 
	    then n2_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='On way to customers premises' 
	    then n2_3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
	   		and scm.receiving_warehouse_code=n3.warehouse_code
	   		and scm.shipment_market_code = '3'
	    then n3.normative_days_quantity 
	   /*when scm.business_location_for_reporting_name='At Russian Port' 
	    then n4.normative_days_quantity*/ 
	   when scm.business_location_for_reporting_name='Marine transit'
	    then n5_1.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Marine transit 2' 
	    then n5_2.normative_days_quantity 
	   when scm.business_location_for_reporting_name='Barging'
	    then n5_3.normative_days_quantity  
	   when scm.business_location_for_reporting_name='Inland transit to foreign WH' 
	    then n5_4.normative_days_quantity
	   when scm.business_location_for_reporting_name='Tracking to warehouse 2' 
	    then n5_5.normative_days_quantity 
	   when scm.business_location_for_reporting_name='In transit warehouse'  
	    and scm.delivery_region_code=n6_1.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_1.normative_days_quantity
	   when scm.business_location_for_reporting_name='In warehouse (not ready for release)'  
	    and scm.delivery_region_code=n6_2.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_2.normative_days_quantity
	   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
	    and scm.delivery_region_code=n6_3.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_3.normative_days_quantity 
	   when scm.business_location_for_reporting_name='At Consignment stock'  
	    and scm.delivery_region_code=n6_4.region_code
	    and scm.shipment_market_code <> '3'
	    then n6_4.normative_days_quantity 
    end as business_location_plan_weight,                        -- SD.000961 Цель для Локации отчета Оборотный капитал
    scm.material_cost_actual_hfm_usd_currency_amount,        -- HFM стоимость
    scm.material_cost_actual_usd_currency_amount,           -- SD.000962 Сумма в доллар ФАКТ
    scm.material_cost_plan_usd_currency_amount,             -- SD.000963 Сумма в доллар ЦЕЛЬ
    case 
    	when scm.business_location_for_reporting_name <> 'At Russian Port'
    		then
			    (scm.weight_nk/
			    (CASE 
				   WHEN scm.business_location_for_reporting_name IN ('At station', 'Status Smelter WH' )
				    	AND scm.plant_producer_code = bla_plant.plant_producer_code
				    	THEN nullif(bla_plant.weight_nk_bla,0) 
				    WHEN scm.business_location_for_reporting_name IN ('In transit Russia', 'In transit Kubal', 'On way to customers premises', 'At Russian Port')
				    	and scm.tsw_location_code=bla_loc.tsw_location_code
				    	THEN nullif(bla_loc.weight_nk_bla,0) 
				    WHEN scm.business_location_for_reporting_name IN ('In warehouse (ready for release)')
				    	AND scm.business_location_for_reporting_name = bla_wh.business_location_for_reporting_name
				    	and scm.receiving_warehouse_code=bla_wh.receiving_warehouse_code
				    	AND scm.shipment_market_code = '3'
				    	THEN nullif(bla_wh.weight_nk_bla,0) 
				    WHEN scm.business_location_for_reporting_name IN ('In transit warehouse', 'In warehouse (not ready for release)', 'In warehouse (ready for release)', 'At Consignment stock')
				    	--AND scm.business_location_for_reporting_name = bla_reg.business_location_for_reporting_name
				    	and scm.delivery_region_code=bla_reg.delivery_region_code
				    	AND scm.shipment_market_code = '3'
				    	THEN nullif(bla_reg.weight_nk_bla,0) 
				    WHEN scm.business_location_for_reporting_name IN ('Marine transit', 'Marine transit 2', 'Barging', 'Inland transit to foreign WH', 'Tracking to warehouse 2')
				    	AND scm.business_location_for_reporting_name = bla_reg_loc.business_location_for_reporting_name
				    	and scm.tsw_location_code=bla_reg_loc.tsw_location_code
				    	and scm.delivery_region_code=bla_reg_loc.delivery_region_code
				    	THEN nullif(bla_reg_loc.weight_nk_bla,0) 
				END)*				
			    (case
				   when scm.business_location_for_reporting_name='At station'
				    then n1_1.normative_days_quantity
				   when scm.business_location_for_reporting_name='Status Smelter WH' 
				    then n1_2.normative_days_quantity 
				   when scm.business_location_for_reporting_name='In transit Russia' and n2_1.location_type_code='1'
				    then n2_1.normative_days_quantity
				   when scm.business_location_for_reporting_name='In transit Russia' and n2_1_1.location_type_code='2'
				    then n2_1_1.normative_days_quantity 
				   when scm.business_location_for_reporting_name='In transit Kubal' 
				    then n2_2.normative_days_quantity 
				   when scm.business_location_for_reporting_name='On way to customers premises' 
				    then n2_3.normative_days_quantity 
				   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
				   		and scm.receiving_warehouse_code=n3.warehouse_code
				   		and scm.shipment_market_code = '3'
				    then n3.normative_days_quantity 
				   /*when scm.business_location_for_reporting_name='At Russian Port' 
				    then n4.normative_days_quantity*/ 
				   when scm.business_location_for_reporting_name='Marine transit'
				    then n5_1.normative_days_quantity 
				   when scm.business_location_for_reporting_name='Marine transit 2' 
				    then n5_2.normative_days_quantity 
				   when scm.business_location_for_reporting_name='Barging'
				    then n5_3.normative_days_quantity  
				   when scm.business_location_for_reporting_name='Inland transit to foreign WH' 
				    then n5_4.normative_days_quantity
				   when scm.business_location_for_reporting_name='Tracking to warehouse 2' 
				    then n5_5.normative_days_quantity 
				   when scm.business_location_for_reporting_name='In transit warehouse'  
				    and scm.delivery_region_code=n6_1.region_code
				    and scm.shipment_market_code <> '3'
				    then n6_1.normative_days_quantity
				   when scm.business_location_for_reporting_name='In warehouse (not ready for release)'  
				    and scm.delivery_region_code=n6_2.region_code
				    and scm.shipment_market_code <> '3'
				    then n6_2.normative_days_quantity
				   when scm.business_location_for_reporting_name='In warehouse (ready for release)' 
				    and scm.delivery_region_code=n6_3.region_code
				    and scm.shipment_market_code <> '3'
				    then n6_3.normative_days_quantity 
				   when scm.business_location_for_reporting_name='At Consignment stock'  
				    and scm.delivery_region_code=n6_4.region_code
				    and scm.shipment_market_code <> '3'
				    then n6_4.normative_days_quantity 
			    end)) 
	end as business_location_allocated_plan_weight,             -- SD.000964 Цель пропорциональная
    'Текст комментария 1' as report_comment1_text,               -- SD.000965 Комментарий 1
    'Текст комментария 2' as report_comment2_text,               -- SD.000966 Комментарий 2
    'Текст комментария 3' as report_comment3_text,                -- SD.000967 Комментарий 3   
    ---DWH-6803
	scm.warehouse_or_responsible_customer_for_storage_name,/*calculated_location_name*/
	scm.dt_shipment_actual,
	---236
	scm.dt_acceptance_in_russian_port_planned,                    -- SD.000705 Плановая дата принятия в порту РФ 
	---241
	n4_2.normative_days_quantity as vessel_load_daily_plan_weight, -- SD.001045 Цель погрузки на судно 
	scm.weight_nk*n4_2.normative_days_quantity/(case
                                                  WHEN scm.business_location_for_reporting_name='At Russian Port'
	    	                                           and scm.tsw_location_code=bla_loc.tsw_location_code
	    	                                      THEN nullif(bla_loc.weight_nk_bla,0)
	    	                                      ELSE 0 
	    	                                      end) as vessel_load_daily_allocated_plan_weight, -- SD.001046 Цель пропорциональная погрузки на судно 
	---237
	scm.forwarder_in_foreign_port_code,                      -- SD.000950 Экспедитор в иностранном порту (код)
	--247
	scm.warehouse_code,                                                 -- SD.000420 Удаленный склад (код)
	scm.warehouse_name,                                                 -- SD.000421 Удаленный склад
	scm.country_of_remote_warehouse_code,                               -- SD.000725 Страна удаленного склада (код)
	scm.country_of_remote_warehouse_name,                               -- SD.000423 Страна удаленного склада
	scm.region_of_remote_warehouse_code,                                -- SD.000726 Регион удаленного склада (код)
	scm.region_of_remote_warehouse_name,                                 -- SD.000727 Регион удаленного склада 
	scm.fwrd_info_second_foreign_warehouse_location_name,										-- EXP: Storage location 2 SD.000941 
	scm.receiving_warehouse_name, 										-- Принимающий склад SD.0010036	
	--236
	scm.material_group_name,                                            -- SD.0000?? Группа материала название
	scm.buyer_plan_code,                                                -- SD.000124 Плановый покупатель (код)
	to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm, 	        -- SD.000893 "Месяц Дата отгрузки с завода"   
	--274
	scm.dt_bill_of_lading_in_russian_port_created,         -- SD.001214 Дата загрузки Коносамента РФ в САП
	scm.dt_bill_of_lading_in_foreign_port_created,         --SD.001215 Дата загрузки Коносамента ин. порта в САП
	scm.dt_bill_of_lading_in_russian_port_scan_copy_uploaded, -- SD.001216 Дата загрузки скан образа в САП для Коносамента РФ 
	scm.bill_of_lading_group_code_in_foreign_port,         --SD.000047 Группа коносамента в ин.порту
	scm.dt_bill_of_lading_in_foreign_port_scan_copy_uploaded,  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта   
	-----237 DWH-8015
	scm.storage_duration_total_calendar_days,                --SD.001037 (LE.001086) Количество дней хранения
    scm.storage_duration_free_by_contract_calendar_days,     --SD.001038 (LE.001087) Количество дней бесплатного хранения по договору
    scm.storage_duration_payable_calendar_days,              --SD.001039(LE.001089) Количество дней платного хранения
    scm.storage_cost_calculated_amount,                      --SD.001040(LE.001090 ) Расчетная стоимость
    scm.storage_calculated_cost_total_amount,                 --SD.001041(LE.001116) Сумма платного хранения 
     --302
	 scm.country_of_consignee_code,                            --SD.001360 Код страны грузоплучателя 
	 --311
	scm.storage_duration_in_russian_port_in_calendar_days,    --SD.001385 Количество дней хранения в порту РФ
	case
   	    when scm.storage_duration_in_russian_port_in_calendar_days is not null 
        then case
	         when scm.storage_duration_in_russian_port_in_calendar_days::integer=0 then null
   	         when scm.storage_duration_in_russian_port_in_calendar_days::integer between 1  and 30 then '<=1M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 31 and 60 then '>1M<=2M'
 		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 61 and 90 then '>2M<=3M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 91 and 180 then '>3M<=6M'
		     when scm.storage_duration_in_russian_port_in_calendar_days::integer between 181 and 365 then '>6M<=1Y'
		     else '>1Y'
		    end
   	end as storage_duration_in_russian_port_category_code,      --SD.001386 Категория хранения в порту РФ
   	scm.dt_arrival_by_railway_planned							--SD.001395 Плановая дата прибытия по жд (нормативная)
from sd_sales_svh_stock_by_date scm	
----связи с ZTSD8787M_1	
left join dds.sales_location_stay_normative  as n1_1 --ОК
         on scm.business_location_for_reporting_name=n1_1.business_location_for_reporting_name  
         and scm.plant_producer_code=n1_1.plant_code 
         and to_char(scm.dt_report,'YYYYMM')=concat(n1_1.dt_normative_yyyy,n1_1.dt_normative_mm) 
         and n1_1.source_table_name='ZTSD8787M_1'
         and n1_1.business_location_for_reporting_name='At station'
         and n1_1.location_type_code='2'
left join dds.sales_location_stay_normative  as n1_2 --ОК
         on scm.business_location_for_reporting_name=n1_2.business_location_for_reporting_name  
         and scm.plant_producer_code=n1_2.plant_code 
         and to_char(scm.dt_report,'YYYYMM')=concat(n1_2.dt_normative_yyyy,n1_2.dt_normative_mm) 
         and n1_2.source_table_name='ZTSD8787M_1'
         and n1_2.business_location_for_reporting_name='Status Smelter WH'
         and n1_2.location_type_code='1'
left join dds.sales_location_stay_normative  as n2_1 --ОК
         on scm.business_location_for_reporting_name=n2_1.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_1.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_1.dt_normative_yyyy,n2_1.dt_normative_mm)
          and n2_1.source_table_name='ZTSD8787M_2'
          and n2_1.business_location_for_reporting_name='In transit Russia'
          and n2_1.location_type_code='1'
left join dds.sales_location_stay_normative  as n2_1_1 --ОК
         on scm.business_location_for_reporting_name=n2_1_1.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_1_1.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_1_1.dt_normative_yyyy,n2_1_1.dt_normative_mm)
          and n2_1_1.source_table_name='ZTSD8787M_2'
          and n2_1_1.business_location_for_reporting_name='In transit Russia'
          and n2_1_1.location_type_code='2'          
left join dds.sales_location_stay_normative  as n2_2 --ОК
         on scm.business_location_for_reporting_name=n2_2.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_2.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_2.dt_normative_yyyy,n2_2.dt_normative_mm)
          and n2_2.source_table_name='ZTSD8787M_2'
          and n2_2.business_location_for_reporting_name='In transit Kubal'
          and n2_2.location_type_code='3'          
left join dds.sales_location_stay_normative  as n2_3 --ОК
         on scm.business_location_for_reporting_name=n2_3.business_location_for_reporting_name 
          and scm.tsw_location_code=n2_3.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n2_3.dt_normative_yyyy,n2_3.dt_normative_mm)
          and n2_3.source_table_name='ZTSD8787M_2'
          and n2_3.business_location_for_reporting_name='On way to customers premises'  
          and n2_3.location_type_code='4'
----связи с ZTSD8787M_3          
left join dds.sales_location_stay_normative  as n3 --ОК
         on scm.business_location_for_reporting_name=n3.business_location_for_reporting_name  
         and scm.receiving_warehouse_code=n3.warehouse_code 
           and to_char(scm.dt_report,'YYYYMM')=concat(n3.dt_normative_yyyy,n3.dt_normative_mm)  
         and n3.source_table_name='ZTSD8787M_3'
         and n3.business_location_for_reporting_name='In warehouse (ready for release)' 
----связи с ZTSD8787M_4  для location_type_code='1'       
left join dds.sales_location_stay_normative  as n4 --ОК
         on scm.business_location_for_reporting_name=n4.business_location_for_reporting_name 
          and scm.tsw_location_code=n4.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n4.dt_normative_yyyy,n4.dt_normative_mm) 
          and n4.source_table_name='ZTSD8787M_4'  
          and n4.business_location_for_reporting_name='At Russian Port'
----связи с ZTSD8787M_5            
left join dds.sales_location_stay_normative  as n5_1 --ОК
         on scm.business_location_for_reporting_name=n5_1.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_1.transport_hub_code
          and scm.delivery_region_code=n5_1.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_1.dt_normative_yyyy,n5_1.dt_normative_mm)  
          and n5_1.business_location_for_reporting_name='Marine transit'
          and n5_1.location_type_code='1' 
left join dds.sales_location_stay_normative  as n5_2 --ОК
         on scm.business_location_for_reporting_name=n5_2.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_2.transport_hub_code
          and scm.delivery_region_code=n5_2.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_2.dt_normative_yyyy,n5_2.dt_normative_mm)  
          and n5_2.business_location_for_reporting_name='Marine transit 2'
          and n5_2.location_type_code='1'  
left join dds.sales_location_stay_normative  as n5_3 --ОК
         on scm.business_location_for_reporting_name=n5_3.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_3.transport_hub_code
          and scm.delivery_region_code=n5_3.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_3.dt_normative_yyyy,n5_3.dt_normative_mm)  
          and n5_3.business_location_for_reporting_name='Barging'
          and n5_3.location_type_code='1'         
left join dds.sales_location_stay_normative  as n5_4 --ОК
         on scm.business_location_for_reporting_name=n5_4.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_4.transport_hub_code
          and scm.delivery_region_code=n5_4.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_4.dt_normative_yyyy,n5_4.dt_normative_mm)  
          and n5_4.business_location_for_reporting_name='Inland transit to foreign WH'
          and n5_4.location_type_code='2'        
left join dds.sales_location_stay_normative  as n5_5 --ОК
         on scm.business_location_for_reporting_name=n5_5.business_location_for_reporting_name 
          and scm.tsw_location_code=n5_5.transport_hub_code
          and scm.delivery_region_code=n5_5.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n5_5.dt_normative_yyyy,n5_5.dt_normative_mm)  
          and n5_5.business_location_for_reporting_name='Tracking to warehouse 2'
          and n5_5.location_type_code='2'     
----связи с ZTSD8787M_6             
left join dds.sales_location_stay_normative  as n6_1 --ОК
         on scm.business_location_for_reporting_name=n6_1.business_location_for_reporting_name 
          and scm.delivery_region_code=n6_1.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_1.dt_normative_yyyy,n6_1.dt_normative_mm)  
          and n6_1.source_table_name='ZTSD8787M_6' 
          and n6_1.business_location_for_reporting_name='In transit warehouse' 
left join dds.sales_location_stay_normative  as n6_2 --ОК
         on scm.business_location_for_reporting_name=n6_2.business_location_for_reporting_name 
          and scm.delivery_region_code=n6_2.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_2.dt_normative_yyyy,n6_2.dt_normative_mm)  
          and n6_2.source_table_name='ZTSD8787M_6' 
          and n6_2.business_location_for_reporting_name='In warehouse (not ready for release)'    
left join dds.sales_location_stay_normative  as n6_3 --ОК
         on scm.business_location_for_reporting_name=n6_3.business_location_for_reporting_name 
          and scm.delivery_region_code=n6_3.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_3.dt_normative_yyyy,n6_3.dt_normative_mm)  
          and n6_3.source_table_name='ZTSD8787M_6' 
          and n6_3.business_location_for_reporting_name='In warehouse (ready for release)' 
left join dds.sales_location_stay_normative  as n6_4 --ОК
         on scm.business_location_for_reporting_name=n6_4.business_location_for_reporting_name 
          and scm.delivery_region_code=n6_4.region_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n6_4.dt_normative_yyyy,n6_4.dt_normative_mm)  
          and n6_4.source_table_name='ZTSD8787M_6' 
          and n6_4.business_location_for_reporting_name='At Consignment stock'           
left join business_location_for_wc as wc
         on scm.business_location_for_reporting_name=wc.business_location_for_reporting_name
/*left join business_location_allocated_svh as bla     
         on scm.business_location_for_reporting_name=bla.business_location_for_reporting_name
         and scm.dt_report=bla.dt_report*/
left join business_location_allocated_svh_plant as bla_plant    
         on scm.business_location_for_reporting_name = bla_plant.business_location_for_reporting_name
         and scm.dt_report = bla_plant.dt_report
         AND scm.plant_producer_code = bla_plant.plant_producer_code
left join business_location_allocated_svh_location as bla_loc    
         on scm.business_location_for_reporting_name = bla_loc.business_location_for_reporting_name
         and scm.dt_report = bla_loc.dt_report
         AND scm.tsw_location_code = bla_loc.tsw_location_code
left join business_location_allocated_svh_warehouse as bla_wh    
         on scm.business_location_for_reporting_name = bla_wh.business_location_for_reporting_name
         and scm.dt_report = bla_wh.dt_report
         AND scm.receiving_warehouse_code = bla_wh.receiving_warehouse_code
left join business_location_allocated_svh_region as bla_reg    
         --on scm.business_location_for_reporting_name = bla_reg.business_location_for_reporting_name
         on scm.dt_report = bla_reg.dt_report
         AND scm.delivery_region_code = bla_reg.delivery_region_code
left join business_location_allocated_svh_region_location as bla_reg_loc   
         on scm.business_location_for_reporting_name = bla_reg_loc.business_location_for_reporting_name
         and scm.dt_report = bla_reg_loc.dt_report
         AND scm.delivery_region_code = bla_reg_loc.delivery_region_code
         AND scm.tsw_location_code = bla_reg_loc.tsw_location_code
----связи с ZTSD8787M_4   для  location_type_code='2'    поля 1045 и 1046   
left join dds.sales_location_stay_normative  as n4_2 --ОК
         on scm.business_location_for_reporting_name=n4_2.business_location_for_reporting_name 
          and scm.tsw_location_code=n4_2.transport_hub_code
          and to_char(scm.dt_report,'YYYYMM')=concat(n4_2.dt_normative_yyyy,n4_2.dt_normative_mm) 
          and n4_2.source_table_name='ZTSD8787M_4'  
          and n4_2.business_location_for_reporting_name='At Russian Port'
          and n4_2.location_type_code='2'          
union all --СГП
select 
	scm.dt_report,                                      --Отчетная дата
	'No' as realization_status,                       --Статус реализации 
	scm.plant_producer_code,                       -- Завод производитель (код) SD.000006
	plant_manufact,                            -- Завод производитель SD.000007
    plant_manufact_rus_name,                   -- Завод производитель на русском
	scm.direction,                    		     -- Направление --Порт погрузки в МКТРЕК
	scm.direction_rus,                           --SD.000009 Направление на русском --Порт погрузки в МКТРЕК
	tsw_location_code,                         -- Направление (код) SD.000008
	material_type,                             -- SD.000016 "Материал" 
	material_rus_type,                         -- SD.000016 "Материал" на русском
	material_group_report_mc,                  -- Группа материала SD.000017 
	null as shipment_market_code,
	ovk_market_text,                 -- Рынок в отгрузке SD.000019
	weight_net,                            -- Вес нетто -- SD.000032 "Вес нетто"
	null as weight_nk,               --Вес НК
	null as weight_gross,                          --Вес брутто!!!!
	quota,                                    -- SD.000039 "Квота" 
	scm.port_of_discharge_code,                   --SD.000044 Порт выгрузки (код) 
	scm.port_discharge,                           --SD.000045 Порт выгрузки
	scm.port_discharge_rus,                       --SD.000045 Порт выгрузки на русском
	null as port_of_discharge_in_foreign_port_code,   --Второй иностранный порт (код)--чтобы вытащить английское название
	null as port_discharge_abroad_sec,          --SD.000055 Второй иностранный порт
	null as port_discharge_abroad_sec_rus,      --SD.000055 Второй иностранный порт на русском
	delivery_point_name,                       -- SD.000068 Пункт доставки по инкотермс 
	"ordering" ,                               -- SD.000123 " --Заказ ЦK в МКТРЕК  
	metal_grade,                               -- SD.000145 "Марка по спецификации" Марка 
	null as buyer_end_name,                           --Конечный потребитель
	null as delivery_split_reason_code,               --Причина деления (код)!!!!
	null as delivery_split_reason_name,              --Причина деления 
	null as "location",
	null as location_from_stock,                                --Локация
	country_of_discharge_port_code,                    -- SD.000340 Страна POD (код)
	country_of_discharge_port_name as country,         -- SD.000341 Страна POD
	country_of_discharge_port_rus_name as country_rus_name,         -- SD.000341 Страна POD на русском
	region_of_destination_port_code,                   -- SD.000342 Регион POD (код)
	region_of_destination_port_name as region,         -- SD.000343 Регион POD 
	region_of_destination_port_rus_name as region_rus_name,
	null as dest_port,                 --Порт назначения
	null as delivery_number_initial,                  --Исходная поставка!!!!
	null as delivery_number_sales,                    --Продажная поставка!!!!
	null as delivery_number_outbound,                 --Исходящая поставка !!!!
	null as delivery_number_of_producer_plant,        --Заводская поставка !!!!
	batch,                                    -- Партия SD.000004     
	null as uni, 
	null as dt_release_material,                        --Дата ОМ !!!!
	null as release_material_status_code,              --Статус ОМ!!!!
	null as ovk_port_vigruz_group,                    --Порт выгрузки группа 
	null as receiving_plant_in_sap_system_code,       --Принимающий завод грузополучателя в системе SAP!!!! 
	null as dt_bill_of_lading,                          --Дата коносамента!!!!
	material_code,                            -- SD.000143 "Номер материала"
	null as material_name,                           --Наименование материала
	delivery_basis,                            -- SD.000067 Плановый базис поставки
	customer_code,                            -- SD.000036 "Покупатель (код)"
	customer_name,                            -- SD.000037 "Покупатель
	null as dt_ownership_transfer,                           --Дата ППС 
	dt_shipment,                                -- Дата отгрузки!!!! SD.000010
	--null as delivery_country,                         --Страна поставки!!!!
	delivery_region_name as delivery_region,                     -- SD.000338 Регион поставки по контракту
    delivery_region_rus_name,                      --Регион поставки
	null as dt_prepared_for_realization,                     --Дата готовности в релизу
	null as dt_updated,								   --Дата и время последнего изменения на источнике 
	null as  material_group_for_scm_report_name,       --Группа материала для отчета Металл в Цепочке Поставок
	null as dt_realization_forecast,                         --Расчетная дата реализации
	null as vessel_and_voyage_plan_search_name,      --Судно / номер рейса (план)
	null as vessel_and_voyage_actual_search_name,    --Судно / номер рейса (факт)
	null as dt_barge_loading,                                --Дата погрузки на баржу
	null as dt_barge_arrival,                                --Дата доставки баржи
	delivery_country_in_contract_code,               -- SD.000577 "Страна поставки по контракту (код)
	null as commitment_weight,
	null as total_commitment_weight,
	null as lot_code,
	null as homogenisation_name,
	null as homogenisation_rus_name,
	null as port_of_discharge_country_code,
	null as dt_warehouse_confirmation,
	null as second_shipping_instruction_code,
	null as dt_release,
	null as notice_name,
	null as dt_notice,
	null as final_release_code,
	null as dt_final_invoice_payment,
	null as vehicle_in_foreign_port_code,
	null as vehicle_type_in_foreign_port_code,
	--	null as shipment_market_name,
	null as is_consigment_warehouse_applicable,
	null as dt_transfer_from_consignment_to_customer,
	null as dt_forwarder_discharge_invoice_or_cmr_documented,
	null as transportation_scenario_code,
	delivery_country_in_contract_name,       -- SD.000576 Страна поставки по контракту
	delivery_country_in_contract_rus_name,       -- SD.000576 Страна поставки по контракту
	null as prepared_for_realization_status_name,
	null as bill_of_lading_in_foreign_port,
	null as bill_of_lading_in_foreign_port_nomination,
	null as bill_of_lading_number,
	business_location_sap_precalc_name as business_location_name,                -- SD.000492 "Статус в Supply chain (Business)"	
	null as container_after_repacking,
	null as contract_name,
	null as contract_plan_code,
	contract_plan_name,                    -- SD.000148 Плановый контрак
	customer_grade_name,                   -- SD.000144 "Марка клиента"
	null as delivery_instruction_code,
	null as delivery_notice_number,
	dimensions_unit,                         -- SD.000079 "Размер единицы готовой продукции"
	null as dt_arrival_by_railway,
	null as dt_arrival_in_port_of_discharge,
	null as dt_arrival_in_port_of_discharge_plan,
	null as dt_arrived_via_ul_system,
	null as dt_delivery_notice,
	null as dt_discharge_in_foreign_port, --Дата разгрузки в ин. порту
	null as dt_expected_bill_of_lading,
	null as dt_expected_delivery,
	null as dt_final_release,
	null as dt_forwarder,
	null as dt_repacked,
	null as dt_sailed_loading_port,
	null as dt_storage_end_in_foreign_port,
	null as dt_storage_start_in_foreign_port,
	null as dt_storage_start_in_second_foreign_warehouse,
	null as dt_warehouse,
	null as external_contract_in_lot_number,
	finish_good_group_code,         -- SD.000257 "Группа продукции" 
	finish_good_unit_diameter,      -- SD.000108 "Диаметр единицы готовой продукции"
	finish_good_unit_height,        -- SD.000107 "Высота единицы готовой продукции"
	finish_good_unit_length,        -- SD.000105 "Длина единицы готовой продукции"
	finish_good_unit_width,			-- SD.000106 "Ширина единицы готовой продукции"
	null as foreign_port_of_discharge_location_code,
	null as forwarder_name,
	incoterms_location_plan_code,   -- SD.000256 Плановый базис поставки 2
	incoterms_plan_code,            -- SD.000255 Плановый базис поставки 1
	null as instruction_number,
	null as invoice_final_number,
	null as invoice_provisional_number,
	null as is_plan_or_actual,
	null as is_shipped_via_overseas_second_foreign_warehouse,
	null as is_shipped_via_overseas_warehouse,
	null as lot_contract_code,
	null as lot_customer_code,
	null as lot_customer_name,
	null as lot_delivery_basis_code,
	null as lot_delivery_point_name,
	material_shape_name_full,                      -- SD.000180 "Форма"
	material_shape_rus_name_full,                      -- SD.000180 "Форма"
	null as material_specification_name,
	null as pb_number,
	null as pieces,
	null as plant_owner_code,
	null as pledge_in_bank_name,
	null as port_of_loading_in_foreign_port_name,     --SD.000053 Порт погрузки 2
	null as port_of_loading_in_foreign_port_rus_name, --SD.000053 Порт погрузки 2 на русском
	railcar,                                         -- SD.000013 "Вагон"
	null as railway_movement_status_name,
	null as railway_platform,
	null as release_group_name,
	null as sales_contract_code,
	null as second_foreign_port_of_discharge_location_code,
	shipment_period_preferred,                    -- SD.000150 "Желаемый период отгрузки"	
	station_destination,                          -- SD.000035 "Станция назначения" = 'СГП'; 
	transport_bill,                               -- SD.000014 "Накладная"
	null as transport_railcar_type_name,           --SD.000029 Тип вагона на русском
	null as transport_railcar_type_rus_name,       --SD.000029 Тип вагона на русском
	null as uni_in_shipment,
	null as vessel_in_foreign_port_actual_name,
	null as warehouse_gross_weight,
	null as warehouse_shipment_type_name,
	null as exporter_name,                           --Экспортер (код)
	country_of_end_user_name ,                       -- SD.000601 Страна конечного потребителя 
	country_of_end_user_rus_name,        -- SD.000601 Страна конечного потребителя на русском
	null as buyer_plan_name,                          -- SD.000602 "Плановый покупатель
	customer_for_scm_report_name,             -- SD.000603 "Клиент для отчета Металл в Цепочке Поставок
	null as forwarder_instruction_name,                --Поручение
	null as dt_forwarder_instruction,                         --Дата поручения
	null as forwarder_in_foreign_port_name,           --Экспедитор в иностранном порту
	null as dt_storage_payed_in_foreign_port_by_rusal,        --Дата окончания хранения на складе за счет RUSAL по Релизу
	null as shipment_instruction_in_foreign_port_name, --Инструкция на отгрузку Ин Порт
	null as dt_shipment_instruction_in_foreign_port,          --Дата инструкции на отгрузку Ин Порт
	null as dt_shipment_instruction_date_from,                --Инструкция на отгрузку хранение по графику 'Дата с'
	null as dt_shipment_instruction_date_to,                  --Инструкция на отгрузку хранение по графику 'Дата по'
	null as shipment_instruction_in_second_foreign_port_name, --Инструкция на отгрузку Ин Порт 2
	null as dt_shipment_instruction_in_second_foreign_port,   --Дата инструкции на отгрузку Ин Порт 2
	null as dt_invoice_provisional,                           --Дата предварительного инвойса
	null as provisional_invoice_payment_status_code,    --Статус оплаты предварительного инвойса
	null as invoice_provisional_code,                  --Фактура предварительного инвойса
	null as mh1_storage_document_number,               --Акт на склад СВХ
	null as dt_mh1_storage_document,                          --Дата акта на склад СВХ
	--null as mh3_storage_document_number,               --Акт со склада СВХ
	--null as dt_mh3_storage_document,                          --Дата акта со склада СВХ
	null as dt_departure_from_foreigh_port,                 --EXP: Load out date -- Данчик вытаскивал
	null as foreign_port_terminal_name,                                --Данчик вытаскивал
	null as russian_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code
	null as foreign_port_bill_of_lading_forwarder_code,  --EXP: WH Operator's code 2
	null as uzbekistan_cargo_declaration_73,             --EXP: ГТД ИМ73
	null as shipment_instruction_in_foreign_port_code,   --Группа инструкции на отгрузку Ин Порт
	customer_special_requirement,                       -- SD.000127 Трейдеры: спец. заказ клиента
	null as plant_producer_name,                        --Завод производитель
	null as vessel_plan_name,                          --Судно план
	null as dt_bill_of_lading_in_foreign_port,                 --Дата коносамента в ин.порту
	null as dt_arrival_in_second_port_of_discharge,            --Дата прибытия в порт выгрузки 2
	null as port_of_discharge_in_foreign_port_name,     --Второй иностранный порт
	null as dt_storage_end_in_second_foreign_warehouse,        --Окончание хранение склад 2
	null as railway_train_number,                        --Номер поезда
	null as  customs_declaration_number,                  --Номер ГТД (код)
	sales_team_code,                   -- SD.000650 Сбытовая команда (код)
    sales_team_name,                   -- SD.000651  Сбытовая команда 
	null as ready_for_realization_status_name,           --Статус готовности к реализации
	null as receiving_plant_in_sap_system_name,          --Принимающий завод грузополучателя в системе SAP
	port_of_discharge_plan_code,                             -- SD.000125 Плановый порт выгрузки (код)
	port_of_discharge_plan_name,                             -- SD.000126 Плановый порт выгрузки
	null as second_foreign_port_of_discharge_plan_code,              --Плановый порт выгрузки 2 (код)
	null as second_foreign_port_of_discharge_plan_name,               --Плановый порт выгрузки 2
	null as dt_arrival_in_port_of_destination,                   --Дата прибытия в порт назначения
	null as voyage_number_internal,                      --Номер рейса внутренний
	null as vessel_and_voyage_number_reporting_name,    --Судно / Номер рейса / Номер рейса поставщика
	null as shipment_instruction_group_ds,              --Группа инструкции ДСБ (код)
	null as dt_shipment_instruction_ds,                        --Дата инструкции ДСБ
	null as shipment_instruction_number_ds,                    --Номер инструкции ДСБ 
	null as shipment_instruction_nomination_code_ds,                    --Номинация инструкции ДСБ
	--ver 108
	null as end_buyer_code,                              --Конечный покупатель (код) SD.000640
	country_of_end_user_code,                     -- SD.000641 Страна конечного потребителя (код)   
	null as country_of_customer_code,                    --Страна покупателя (код) SD.000643         
	null as country_of_customer_name,                    --Страна покупателя SD.000644  
	null as country_of_destination_port_code,            --Страна порта назначения (код) SD.000646    
	null as country_of_destination_port_name,            --Страна порта назначения  SD.000647
	null as is_mirrored_resale_code,                     --Зеркало SD.000648    
	delivery_region_code,                        --Регион поставки по контракту (код) SD.000652      
	null as supply_chain_customer_portal_status_name,    --Статус в Supply chain (Portal) SD.000656  
	null as port_of_destination_code,                     --Порт назначения (код) SD.000645  
	--ver 125
	null as dt_realization_for_reporting,                 --Дата реализации План/Факт SD.000683
	null as dt_realization_for_reporting_mmyyyy,           --Месяц реализации SD.000684  
	--ver 132
	dt_quota_yyyymm,                              --Quota для бизнеса SD.000687 
	null as storage_duration_in_calendar_days, --Сроки нахождения в локации SD.000688
	--ver 136
	'No' as is_vehicle_allocated_name,				    -- Признак Распределенный вагон SD.000664
	--ver 108 new
	null as sap_shipdata_reference_code,						-- ID_SHIPDATA SD.000654
	--129
	null as dt_realization,											-- Дата реализации SD.000687
	null as internal_compound_key_code,						-- Внутренний уникальный идентификатор записи SD.000688
	--108
	null as bill_of_lading_group_code,							-- Группа коносамента SD.000040
	null as bill_of_lading_route,								-- Маршрут коносамента SD.000043
	null as lot_group,											-- Группа лот SD.000061  
	null as port_of_loading_code,								-- Порт погрузки (код) SD.000649
	null as port_of_loading_name,								-- Порт погрузки SD.000653
	null as port_of_loading_rus_name,				 			-- SD.000653 Порт погрузки ru
	--137
	null as buyer_agent_code,									-- Trading company (код) SD.000703
	null as buyer_agent_name,									-- Trading company SD.000704
	--146
	null as pb1_number,										-- Номер PB 1 SD.000592
	null as pb2_number,										-- Номер PB 2 SD.000593
	null as pb3_number,										-- Номер PB 3 SD.000594
	null as pb1_warehouse_name,								-- Склад PB 1 SD.000595
	null as pb2_warehouse_name,								-- Склад PB 2 SD.000596
	null as pb3_warehouse_name,								-- Склад PB 3 SD.000597
	----	153
	sales_order_in_shipment,                         -- Заказ ЦК в отгрузке SD.000005
	null as is_tolling_code,                                 -- Признак толлинг SD.000749
	null as location_stay_duration_category_code,   --Сроки нахождения в локации (месяц) SD.000750
	----    154
	null as dt_pb1_number,                                            -- Date PB 1 SD.000751
	null as dt_pb2_number,                                            -- Date PB 2 SD.000752
	null as dt_pb3_number,                                            -- Date PB 3 SD.000753    
	---Оборотный капитал     
	null as transport_railcar_type_code,						-- Тип вагона (код) SD.000028
    null as dt_arrival_in_second_port_of_discharge_plan,             -- Дата прибытия в порт выгрузки 2 план SD.000157
    null as dt_train_scheduled_arrival,	 							-- Плановая дата прибытия по ЖД (с фактом) SD.000697
    null as second_port_of_discharge_country_code,              -- Код страны порта выгрузки 2 SD.000768
    null as second_port_of_discharge_region_code,               -- Код региона порта выгрузки 2 SD.000769
    null as second_port_of_discharge_region_name,             -- Регион порт выгрузки 2 SD.000770
    null as second_port_of_discharge_region_rus_name,         -- Регион порт выгрузки 2 SD.000770 на русском
    customer_for_scm_report_code,                      -- Клиент для отчета Металл в Цепочке Поставок (код) SD.000771  
    null as country_of_customer_for_reporting_code,            -- Код страны Клиент для отчета Металл в Цепочке Поставок SD.000772 
    null as country_of_customer_for_reporting_name,            -- Cтрана Клиент для отчета Металл в Цепочке Поставок SD.000773 
	----данные срезов 164   
    'Status Smelter WH' as business_location_for_reporting_name,                    -- Статус среза SD.000717
     'P' as plan_or_actual_code,                -- Источник данных среза План/Факт SD.000718    	
      ---------новые
    null as normative_railway_trip_duration_days_quantity,     -- SD.000774 Норма движения по жд (дни) 
    null as normative_route_trip_duration_days_quantity,       -- SD.000775 Норма доставки по маршруту завода    --------        
	null as normative_marine_transit1_duration_days_quantity,  -- SD.000776 Норма морского транзита  sb2
    null as normative_marine_transit2_duration_days_quantity,  -- SD.000777 Норма морского транзита 2  
     ----166
    null as consignee_code,									   -- Получатель материала (код) SD.000080
	null as consignee_name,									   -- Грузополучатель SD.000081
	null as customs_invoice_code,                              -- SD.000779 Custom's invoice Group 
	null as customs_invoice_number,                            -- SD.000780 Custom's invoice Number 
	null as dt_customs_invoice,                                -- SD.000781 Custom's invoice Date 
	--------177
    null as tolling_scheme_name,                                -- SD.000908 Толлинг 
    null as receiving_warehouse_code,							-- Принимающий склад SD.000098
	--null as business_location_stay_normative_weight,
	0 as business_location_stay_normative_average_allocated_weight,
	case 
	   	when material_group_report_mc='A01' then 'ALLOY'
	   	else 'PRIMARY'
	end as material_group_for_wc_reporting_name,              -- SD.000959 Группа материалов для отчета Оборотный капитал
	case 
	   	when material_group_report_mc='A01' then 'Сплав'
	   	else 'Первичный аллюминий'
	   end as material_group_for_wc_reporting_rus_name,                           -- SD.000959 Группа материалов для отчета Оборотный капитал на русском      
    'Склад ГП на АЗ' as business_location_for_wc_reporting_name,  -- SD.000960 Локация для отчета Оборотный капитал
    n1.normative_days_quantity as business_location_plan_weight,    -- SD.000961 Цель для Локации отчета Оборотный капитал
   COALESCE(hfm.cost_of_ton_of_metal_manufacturer_usd,hfm_max.cost_of_ton_of_metal_manufacturer_usd,0) as material_cost_actual_hfm_usd_currency_amount, -- HFM Себестоимость   -----Новое в структуре
   scm.weight_net * COALESCE(hfm.cost_of_ton_of_metal_manufacturer_usd, hfm_max.cost_of_ton_of_metal_manufacturer_usd,0) AS material_cost_actual_usd_currency_amount,
    --,weight_nk * 2300 as material_cost_actual_usd_currency_amount                       -- SD.000962 Сумма в доллар ФАКТ
   weight_net * 2300 + weight_net * 2300/100 as material_cost_plan_usd_currency_amount,  -- SD.000963 Сумма в доллар ЦЕЛЬ
   scm.weight_net/nullif(bla_plant_sgp.weight_nk_bla,0)*n1.normative_days_quantity as business_location_allocated_plan_weight,             -- SD.000964 Цель пропорциональная
    'Текст комментария 1' as report_comment1_text,               -- SD.000965 Комментарий 1
    'Текст комментария 2' as report_comment2_text,               -- SD.000966 Комментарий 2
    'Текст комментария 3' as report_comment3_text,                -- SD.000967 Комментарий 3
    ---DWH-6803
	'UNDEFINED' as warehouse_or_responsible_customer_for_storage_name, /*calculated_location_name*/
    ---
	scm.dt_shipment_actual,
	---236
	null as dt_acceptance_in_russian_port_planned,                -- SD.000705 Плановая дата принятия в порту РФ 
	---241
	null as vessel_load_daily_plan_weight,              -- SD.001045 Цель погрузки на судно 
	null as vessel_load_daily_allocated_plan_weight,    -- SD.001046 Цель пропорциональная погрузки на судно 
	---237
	null as forwarder_in_foreign_port_code,                      -- SD.000950 Экспедитор в иностранном порту (код)
	--247
	null as warehouse_code,                                                 -- SD.000420 Удаленный склад (код)
	null as warehouse_name,                                                 -- SD.000421 Удаленный склад
	null as country_of_remote_warehouse_code,                               -- SD.000725 Страна удаленного склада (код)
	null as country_of_remote_warehouse_name,                               -- SD.000423 Страна удаленного склада
	null as region_of_remote_warehouse_code,                                -- SD.000726 Регион удаленного склада (код)
	null as region_of_remote_warehouse_name,                                -- SD.000727 Регион удаленного склада
	NULL AS fwrd_info_second_foreign_warehouse_location_name,										-- EXP: Storage location 2 SD.000941 
	NULL AS receiving_warehouse_name, 										-- Принимающий склад SD.0010036	
	--236
	scm.material_group_name,                                                -- SD.0000?? Группа материала название
	scm.buyer_plan_code,                                                    -- SD.000124 Плановый покупатель (код)
	to_char(scm.dt_shipment, 'YYYY.MM') AS dt_shipment_yyyymm, 	            -- SD.000893 "Месяц Дата отгрузки с завода" 
	--274
	NULL AS dt_bill_of_lading_in_russian_port_created,         -- SD.001214 Дата загрузки Коносамента РФ в САП
	NULL AS dt_bill_of_lading_in_foreign_port_created,         --SD.001215 Дата загрузки Коносамента ин. порта в САП
	NULL AS dt_bill_of_lading_in_russian_port_scan_copy_uploaded, -- SD.001216 Дата загрузки скан образа в САП для Коносамента РФ 
	NULL AS bill_of_lading_group_code_in_foreign_port,         --SD.000047 Группа коносамента в ин.порту
	NULL AS dt_bill_of_lading_in_foreign_port_scan_copy_uploaded,  --SD.001217 Дата загрузки скан образа в САП для Коносамента ин. порта  
	-----237 DWH-8015
	NULL AS storage_duration_total_calendar_days,                --SD.001037 (LE.001086) Количество дней хранения
    NULL AS storage_duration_free_by_contract_calendar_days,     --SD.001038 (LE.001087) Количество дней бесплатного хранения по договору
    NULL AS storage_duration_payable_calendar_days,              --SD.001039(LE.001089) Количество дней платного хранения
    NULL AS storage_cost_calculated_amount,                      --SD.001040(LE.001090 ) Расчетная стоимость
    NULL AS storage_calculated_cost_total_amount,                 --SD.001041(LE.001116) Сумма платного хранения    
     --302
	NULL AS country_of_consignee_code,                            --SD.001360 Код страны грузоплучателя 
	--311
	NULL AS storage_duration_in_russian_port_in_calendar_days,    --SD.001385 Количество дней хранения в порту РФ
	NULL AS storage_duration_in_russian_port_category_code,      --SD.001386 Категория хранения в порту РФ
	NULL AS dt_arrival_by_railway_planned							--SD.001395 Плановая дата прибытия по жд (нормативная)
FROM dm_calc.finish_goods_warehouse_stock_plant_by_date scm
	left join dds.sales_location_stay_normative  as n1 --ОК
         --on scm.business_location_for_reporting_name=n1.business_location_for_reporting_name  
         on scm.plant_producer_code=n1.plant_code 
         and to_char(scm.dt_report,'YYYYMM')=concat(n1.dt_normative_yyyy,n1.dt_normative_mm) 
         and n1.source_table_name='ZTSD8787M_1'
         and n1.business_location_for_reporting_name='Status Smelter WH'   
         and n1.location_type_code='1'
   left join business_location_allocated_plant_sgp as bla_plant_sgp    
        -- on scm.business_location_for_reporting_name = bla_plant.business_location_for_reporting_name
         on scm.dt_report = bla_plant_sgp.dt_report
         AND scm.plant_producer_code = bla_plant_sgp.plant_producer_code    
     LEFT JOIN 
	hfm
	ON scm.plant_producer_code = hfm.plant_code 
    	AND to_char(scm.dt_report,'YYYYMM') = to_char(hfm.calendar_id,'YYYYMM')
 --в случае если в HFM нет данных, то брать максимальную дату, для которой есть данные по заводу        
LEFT JOIN 
	hfm_max
	ON scm.plant_producer_code = hfm_max.plant_code 
		AND to_char(scm.dt_report,'YYYYMM') > to_char(hfm_max.calendar_id,'YYYYMM')           
where weight_net<>0; 
