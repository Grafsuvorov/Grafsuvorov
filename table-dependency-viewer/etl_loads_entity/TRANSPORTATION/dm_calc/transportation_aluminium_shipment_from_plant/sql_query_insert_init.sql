insert into dm_calc.transportation_aluminium_shipment_from_plant
with param as (
	select 
		range_low_value, 
		parameter_code 
	from dict_dds.settings_and_parameters_sap 
	where abap_program_code ='/RUSAL/ZLE1431M' 
	  and range_low_value is not null
),
-- Общая таблица поставок
main_table_delivery as (
	select 
		-- общие признаки
  		s.delivery_code as initial_delivery_code,											-- Поставки завода производителя, код
 		s.delivery_position_line_item_code as initial_delivery_position_code,				-- Поставки завода производителя, позиция
 		s.batch_code as batch_code,															-- Номер партии (код)
 		s.plant_producer_code as plant_producer_code,										-- Завод производитель (код)
 		h.dt_loaded as dt_shipped,															-- Дата отгрузки
 		h.route_code as route_shipping_code,												-- Маршрут отгрузки, код       
 		h.transport_type_code as transport_railway_car_type_plan,							-- Тип ПС
 		h.vehicle_code as transport_vehicle_code,		  									-- Номер вагона
 		h.transport_bill_code as transport_bill_code,										-- Номер транспортной накладной
 		case when h.transport_bill_code != ' ' and h.vehicle_code != ' ' 
              	then h.transport_bill_code || '-' || h.vehicle_code
         	 else replace(h.transport_bill_code,' ','') || replace(h.vehicle_code,' ','') 
        end as transport_bill_and_railcar_uni_code, 										-- Склейка Ж/д Накладная - №Вагона
 		s.material_code	as material_code,													-- Материал (код)    
 		s.sales_document_code as trade_document_code,										-- Торговый документ
  		s.sales_document_position_line_item_code as trade_document_position_code,			-- Ссылка на торговый документ
		-- вспомогательные признаки, которые нужны для формирования определенного набора поставок  	
 		s.valuation_type_code,
 		h.is_delivery_returned,
 		h.delivery_type_code,
 		s.delivery_position_line_item_type_code,
 		s.material_group_code
	from dds.delivery_document_header as h
		join dds.delivery_document_position as s
			on h.delivery_code = s.delivery_code				 							
	where 1=1
      and h.dt_loaded >= '20220101'     					-- глубина обновления должна согласовываться с dds.sales_batch_delivery - ods."/rusal/shipdata_ral".dateot
),
-- Таблица поставок, релевантных для отчета Отгрузка металла с завода 
delivery_for_le0010 as (
	select 
  		initial_delivery_code,												-- Поставки завода производителя, код
 		initial_delivery_position_code,										-- Поставки завода производителя, позиция
 		case when bp.zzcustco = 'RU' then '3'
       	 	 when c.country_code is not null then '2'
         	 else '1' 
        	 end as sales_market_code,	 									-- Рынок сбыта, код
		'X' as is_relevant_transportation_aluminium_shipment_from_plant		-- Флаг, для какой витрины отображается поставка - новый подход
	from main_table_delivery as mtd
		left join ods.vbap_ral as bp 										-- Торговый документ: данные позиции
			on bp.vbeln = mtd.trade_document_code and 
		  	   bp.posnr = mtd.trade_document_position_code				
		left join dict_dds.country c 
			on c.country_code = bp.zzcustco and 
			   c.region_hfm_code = '02'										-- Страны
	where 1=1
  	  and valuation_type_code is not null									-- Вид оценки не пустой
  	  and is_delivery_returned is null										-- Возвращенные не включать
  	  and transport_railway_car_type_plan <> 'XXX'                      	-- Исключаем ненужные типы пс
  	  and exists (select 1 from param where parameter_code = 'S_LFART1' and range_low_value = delivery_type_code)
  	  and exists (select 1 from param where parameter_code = 'S_PSTYV' and range_low_value = delivery_position_line_item_type_code)
  	  and (
  	  		-- металл с АЗ
        	exists (select 1 from param where parameter_code = 'S_WERKS_' and range_low_value = mtd.plant_producer_code) or
        	-- вторичный аллюминий  
        	(exists (select 1 from param where parameter_code = 'S_WERKSV' and range_low_value = mtd.plant_producer_code) and
	 		 exists (select 1 from param where parameter_code = 'S_MATKL' and range_low_value = mtd.material_group_code))
	  	  )
)
select
	mtd.initial_delivery_code,
	mtd.initial_delivery_position_code,
	mtd.batch_code,
	mtd.plant_producer_code,
	le0010.sales_market_code,
	mtd.dt_shipped,
	mtd.route_shipping_code,
	mtd.transport_railway_car_type_plan,
	mtd.transport_vehicle_code,
	mtd.transport_bill_code,
	mtd.transport_bill_and_railcar_uni_code, 
	mtd.material_code, 
	mtd.trade_document_code,
	mtd.trade_document_position_code,
	le0010.is_relevant_transportation_aluminium_shipment_from_plant
from main_table_delivery as mtd
	left join delivery_for_le0010 as le0010
		on mtd.initial_delivery_code = le0010.initial_delivery_code and
		   mtd.initial_delivery_position_code = le0010.initial_delivery_position_code
where le0010.is_relevant_transportation_aluminium_shipment_from_plant is not null;