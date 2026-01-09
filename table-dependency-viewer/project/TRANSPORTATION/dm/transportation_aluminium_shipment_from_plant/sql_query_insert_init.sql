insert into dm.transportation_aluminium_shipment_from_plant 
with fraht as ( -- Затраты
	select
		f.delivery_code, 
		f.expense_position_code,
		sum(case when f.expense_currency_code = 'RUB' then f.expense_amount 
				 else f.expense_amount * cur.currency_rate * currency_to_multiplier / currency_from_multiplier
		    end) as expense_rub_amount,
		sum(f.expense_amount) as expense_amount
	from ods.map_transportation_expenses_keys_ral f
	left join dict_dds.currency_rate as cur 
		on cur.currency_from = f.expense_currency_code and 
		   cur.currency_to = 'RUB' and 
		   cur.dt_currency_rate = to_Date(f.dt_expense_period_yyyymm||'01','yyyymmdd') and 
		   cur.currency_rate_type_code = 'M2'
	where 1=1
	  and f.expense_amount > 0
	  and f.expense_position_code in ('014', '015', '017', '018')
	group by f.delivery_code, 
	         f.expense_position_code
),
fraht_expense as ( -- Затраты через EXPENSE
	select
		f.delivery_code,
		f.expense_code,
		sum(case when f.expense_currency_code = 'RUB' then f.expense_amount
				 else f.expense_amount * cur.currency_rate * currency_to_multiplier / currency_from_multiplier
			end) as expense_rub_amount,
		sum(f.expense_amount) as expense_amount
	from ods.map_transportation_expenses_keys_ral f
	left join dict_dds.currency_rate as cur 
		on cur.currency_from = f.expense_currency_code and 
		    cur.currency_to = 'RUB' and 
		    cur.dt_currency_rate = to_Date(f.dt_expense_period_yyyymm||'01','yyyymmdd') and 
		    cur.currency_rate_type_code = 'M2'
	where 1=1
	  and f.expense_amount > 0
	  and f.expense_code in ('VOHR', 'TARIF')
	group by f.delivery_code, 
	         f.expense_code
)
select 
  	s.plant_producer_code,																	-- Завод производитель (код)
 	p.plant_short_name as plant_producer_name,												-- Завод, наименование
 	s.initial_delivery_code,																-- Номер поставки завода производителя
 	s.initial_delivery_position_code as initial_delivery_item_code, 						-- Позиция поставки
 	s.sales_market_code,																	-- Рынок сбыта, код
 	case s.sales_market_code
		when '3' then 'Вн. рынок'
		else m.market_in_sales_order_name_rus 
	end as sales_market_name,																-- Рынок сбыта, наименование
 	t.transport_transfer_type_name_rus as transport_type_name,								-- Тип ПС, наименование
 	s.transport_vehicle_code,									  							-- Номер транспортного средства
 	s.transport_bill_code,																	-- Номер накладной
 	s.transport_bill_and_railcar_uni_code, 													-- Ж/д Накладная - №Вагона
 	s.dt_shipped,																			-- Дата отгрузки
 	to_char(s.dt_shipped,'yyyy-mm') as dt_shipped_yyyymm,									-- Период отгрузки
 	s.route_shipping_code, 																	-- Маршрут отгрузки, код
 	r.transport_route_name_rus as route_shipping_name,										-- Название маршрута
 	k3.transport_departure_hub_code, 														-- Узел  отправки
 	ha.transport_hub_name_rus as transport_departure_hub_name,	 							-- Название узла отправки
 	k3.transport_destination_hub_code,														-- Узел назначения
 	he.transport_hub_name_rus as transport_destination_hub_name,							-- Название узла назначения
 	k3.port_of_destination_code,															-- Узел Порт назначения
 	prt.transport_hub_name_rus as port_of_destination_name, 								-- Порт назначения
 	k3.transport_border_cross_hub_code,														-- Узел Погранпереход, код
 	cr.transport_hub_name_rus as transport_border_cross_hub_name,							-- Узел Погранпереход, наименование
 	k3.etsng_code,																			-- Код ЕТСНГ
 	et.etsng_name_rus as etsng_name,														-- Код ЕТСНГ, наименование
 	k3.is_pickup_at_plant,																	-- Самовывоз
 	s.material_code,																		-- Материал (код) , замена k3 на s
 	mt.material_name,																		-- Материал (наименование)
 	s.batch_code,																			-- Номер партии (код)
 	ms.shape_code,																			-- Форма груза (код)
 	st.material_shape_full_name as shape_name,												-- Форма груза (наименование)
 	case when mm.sector_code = '03' then '01' 
		 else mm.sector_code
	end as sector_code,																		-- Сектор - группа материалов (код) , замена k3 на s
 	us.sector_name,																			-- Сектор - группа материалов (наименование)
 	ms.grade_rusal_code as grade_code,														-- Марка металла
	case when s.transport_railway_car_type_plan	in ('TL02', 'TL04')
		 then case when k3.complected_train_code = '03' then '02'
         		   else k3.complected_train_code
              end
	end as complected_train_code,															-- Комплектность (код)
 	case when s.transport_railway_car_type_plan	in ('TL02', 'TL04')
		 then rpctt.railway_platform_completeness_type_name
	end as complected_train_name,															-- Комплектность (наименование)
 	k3.complected_train_quantity_index_code,												-- Индекс кол-ва ПС (код)
 	rqit.railcar_quantity_index_name as complected_train_quantity_index_name,				-- Индекс кол-ва ПС (наименование)
 	null as cargo_layout_scheme_code,														-- Схема погрузки из ВПК 'VBBK'
 	fd.package_weight,																		-- Масса упаковки из ВПК SD.000090 shipdata.PACKING 
 	fd.sales_order_in_shipment as sales_order_code,					    					-- Заказ ЦК из ВПК SD.000005 shipdata.ORDER_
 	fd.fixing_holder_weight,																-- Масса реквизита из ВПК SD.000075 shipdata.REKVIZIT
 	coalesce(fd.buyer_code,fd.consignee_code) as customer_code,			    				-- Покупатель из ВПК SD.000082 ??? shipdata
 	fd.consignee_code,																		-- Грузополучатель из ВПК SD.000080 ??? shipdata.FIRMAPID
 	fd.unit_dimensions as unit_dimension_code,												-- Размеры из ВПК SD.000079  ??? shipdata.RAZMER
 	null as cargo_layout_scheme_gross_plan_weight,											-- Плановая загрузка с реквизитом Отчет ВПК
 	k3.shipment_type_code,																	-- Вид отгрузки
 	case when mp.transportation_scheme_subtype_code = '01' then 'C' 						-- (комплексное)
         when mp.transportation_scheme_subtype_code in ('02','16') then 'S' 				-- (собственное)
	     else null
	end as forward_kind_code,																-- Вид экспедирования
 	cf.counterparty_full_name as forwarder_at_railway_name,									-- Экспедитор по ж/д, наименование ошибка нейминга, там code 
 	null as transport_owner_name,															-- Собственник ПС/Морской экспедитор  -- подвис вопрос ФМ /RUSAL/LE1256M_LIFNR
 	fd.forwarder_name,																		-- Экспедитор
 	case when s.sales_market_code != '1' and 
              so.payment_agent_code = 'РТ' and 
              k3.incoterms_plan_code = 'FCA' and 
              fd.consignee_code not in ('0000007870','0000035642') 							-- грузополучатель взят по другому
         then 'X' 
         else null
    end as is_transferrable_expenses,														-- Возмещаемые/Невозмещ. X (возмещаемые) / # (невозмещаемые)
	k3.is_owned_by_rusal_code, 																-- Собственный ПС
 	k3.carrying_capacity_for_tariff_planning_weight, 										-- Грузоподъемность ПС Грузоподъёмность для определения тарифа
 	k3.load_calculated_weight,																-- Фактическая загрузка
 	k3.load_waybill_documented_weight,														-- Фактическая загрузка по накладная-вагон
 	cur.currency_rate as monthly_usd_rate,													-- Курс фактический
	coalesce(case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                  then 0
                  else fe_tarif.expense_rub_amount
             end, 0) +
  	coalesce(case when s.transport_railway_car_type_plan = 'TL04'
                  then 0 
                  else case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                            then f18.expense_rub_amount
                            else f14.expense_rub_amount
                       end
             end, 0) + 
  	coalesce(fe_vohr.expense_rub_amount, 0) as transport_total_cost_from_departure_station_rub_amount,		   		-- Общая стоимость (без участка до ст.отпр.), руб  
	coalesce(f15.expense_rub_amount, 0) + 
  	coalesce(case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                  then 0 
                  else fe_tarif.expense_rub_amount
             end, 0) + 
  	coalesce(case when s.transport_railway_car_type_plan = 'TL04'
                  then 0 
                  else case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                            then f18.expense_rub_amount
                            else f14.expense_rub_amount
                       end
             end, 0) + 
  	coalesce(fe_vohr.expense_rub_amount, 0) as transportation_total_cost_from_plant_rub_amount,			            -- Общая стоимость (с участком до ст.отпр.), руб.  
	coalesce(f15.expense_rub_amount, 0) as transportation_cost_to_departure_station_rub_amount,						-- Провозная плата повагонная до ст.отпр., руб.
	coalesce(case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                  then 0
                  else fe_tarif.expense_rub_amount
             end, 0) as transportation_cost_from_departure_station_rub_amount,										-- Провозная плата повагонная от ст.отпр., руб.         
	coalesce(case when s.transport_railway_car_type_plan = 'TL04' 
                  then 0 
                  else case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                            then f18.expense_rub_amount
                            else f14.expense_rub_amount
                       end
             end, 0) as vehicle_usage_cost_rub_amount,																-- Плата за пользование, руб.
	coalesce(case when s.transport_railway_car_type_plan = 'TL04'
                  then 0 
                  else case when s.transport_railway_car_type_plan in ('АВРТ', 'АВТ')
                            then f18.expense_amount
                            else f14.expense_amount
                       end
             end, 0) as vehicle_usage_cost_document_currency_amount,												-- Плата за пользование в вал.дог.
	coalesce(f17.expense_rub_amount, 0) as security_cost_to_departure_station_rub_amount,							-- Сбор за охрану до ст.отпр., руб RT
	coalesce(fe_vohr.expense_rub_amount, 0) as security_cost_from_departure_station_rub_amount,                     -- Сбор за охрану от ст.отпр., руб RT
	k3.dt_updated,
	s.is_relevant_transportation_aluminium_shipment_from_plant
from dm_calc.transportation_aluminium_shipment_from_plant as s														-- Документ сбыта: данные позиции
left join dds.sales_batch_delivery fd 
	on fd.delivery_number_of_plant_producer = s.initial_delivery_code and 
	   fd.delivery_item_number_of_plant_producer = s.initial_delivery_position_code and 
	   fd.batch_code = s.batch_code 
left join dict_dds.plant_and_subsidiary	as p
	on p.plant_code = s.plant_producer_code  	 																-- Заводы/филиалы
left join dict_dds.sales_order_market as m
	on m.market_in_sales_order_code = s.sales_market_code														-- Трейдеры: Рынок сбыта
left join dict_dds.transport_transfer_type as t
	on t.transport_transfer_type_code = s.transport_railway_car_type_plan										-- Индикатор специальной обработки   
left join dict_dds.transport_route as r
	on r.transport_route_code = s.route_shipping_code   			   											-- Маршруты
left join ods.map_delivery_document_attributes_keys_ral as k3
	on k3.delivery_code = s.initial_delivery_code 
left join dict_dds.transport_hub as ha
	on ha.transport_hub_code = k3.transport_departure_hub_code
left join dict_dds.transport_hub as he
	on he.transport_hub_code = k3.transport_destination_hub_code
left join dict_dds.transport_hub as prt
	on prt.transport_hub_code = k3.port_of_destination_code
left join dict_dds.transport_hub as cr
	on cr.transport_hub_code = k3.transport_border_cross_hub_code
left join dict_dds.etsng as et
	on et.etsng_code = k3.etsng_code
left join dict_dds.material_texts as mt
	on mt.material_code = s.material_code and
	   mt.language_code = 'R'
left join dict_dds.material_specification as ms
	on ms.material_code = s.material_code
left join dict_dds.material_shape_texts as st
	on st.shape_code = ms.shape_code and
	   st.language_code = 'R'
left join dict_dds.material as mm
	on mm.material_code = s.material_code
left join dict_dds.sales_sector_texts as us
	on us.sector_code = case when mm.sector_code = '03' then '01' else mm.sector_code end and
	   us.language_code = 'R'
left join dict_dds.counterparty as cf
	on cf.counterparty_code = k3.forwarder_at_plant_code
left join dict_dds.transportation_scheme as mp
	on mp.transportation_scheme_code = k3.transport_scheme_code 
left join dict_dds.currency_rate as cur
	on cur.currency_from = 'USD' and
	   cur.currency_to = 'RUB' and
	   cur.dt_currency_rate = date_trunc('month', s.dt_shipped) and
	   cur.currency_rate_type_code = 'M2'
left join fraht_expense as fe_tarif
	on fe_tarif.delivery_code = s.initial_delivery_code and 
	   fe_tarif.expense_code = 'TARIF'
left join fraht_expense as fe_vohr
	on fe_vohr.delivery_code = s.initial_delivery_code and 
	   fe_vohr.expense_code = 'VOHR'		   
left join fraht as f14
	on f14.delivery_code = s.initial_delivery_code and
	   f14.expense_position_code = '014'
left join fraht as f15
	on f15.delivery_code = s.initial_delivery_code and
	   f15.expense_position_code = '015'
left join fraht as f17
	on f17.delivery_code = s.initial_delivery_code and
	   f17.expense_position_code = '017'
left join fraht as f18
	on f18.delivery_code = s.initial_delivery_code and
	   f18.expense_position_code = '018'		   
left join dds.sales_request as so
	on so.dt_shipment_yyyymm = k3.dt_shipped_yyyymm and
	   so.sales_request_code = coalesce(k3.sales_order_code, k3.sales_order_plant_code) and
	   so.is_not_valid_for_reporting = false
left join dict_dds.railway_platform_completeness_type_texts as rpctt
	on rpctt.railway_platform_completeness_type_code = case when k3.complected_train_code = '03' then '02' else k3.complected_train_code end and
	   rpctt.language_code = 'R'	   
left join dict_dds.railcar_quantity_index_texts as rqit
	on rqit.railcar_quantity_index_code = k3.complected_train_quantity_index_code and
	   rqit.language_code = 'R'	   
where 1=1
--and s.initial_delivery_code like '0307921463'
;