insert into dm.sales_delivery_tracking_dob_dkp(
	delivery_number_sales,								-- Продажная поставка SD.000002
	plant_producer_code,								-- Завод производитель (код) SD.000006
	plant_producer_name,								-- Завод SD.000007
	tsw_location_name,									-- Направление SD.000009
	dt_shipment,										-- Дата отгрузки SD.000010
	dt_arrival_by_railway,								-- Дата прибытия по ЖД SD.000011
	dt_forwarder,										-- Дата экспедитора SD.000012
	railcar,											-- Вагон SD.000013
	transport_bill,										-- Накладная SD.000014
	material_aggr_name,									-- Материал SD.000016
	material_group_code,								-- Группа материалов SD.000017
	shipment_market_name,								-- Рынок в отгрузке SD.000019
	dt_warehouse,										-- Дата склада SD.000024
	transport_railcar_type_code,						-- Тип вагона (код) SD.000028
	transport_railcar_type_name,						-- Тип вагона SD.000029
	weight_gross,										-- Вес брутто SD.000031
	weight_net,											-- Вес нетто SD.000032
	weight_net_with_wirerod,							-- Вес Н&K SD.000033
	station_current,									-- Текущая станция SD.000034
	station_destination ,								-- Станция назначения SD.000035
	port_of_discharge_name,								-- Порт выгрузки SD.000045
	status_description,									-- Описание статуса SD.000057
	dt_arrival_in_port_of_discharge,					-- Дата прибытия в порт выгрузки SD.000059
	dimensions_unit,									-- Размер единицы готовой продукции SD.000079
	container_after_repacking,							-- Контейнер после перетарки SD.000119
	distance_remaining,									-- Оставшееся расстояние SD.000122
	sales_order,										-- Заказ ЦК SD.000123
	dt_arrival_in_port_of_discharge_plan,				-- Дата прибытия в порт выгрузки план SD.000130
	material_code,										-- Номер материала SD.000143
	grade_name,											-- Марка по спецификации SD.000145
	uni,												-- UNI SD.000151
	status_al2all,										-- Статус для портала AL2ALL SD.000161
	material_shape_name_full,							-- Форма SD.000180
	country_of_discharge_port_code,						-- Страна POD (код) SD.000340
	country_of_discharge_port_name,						-- Страна POD SD.000341
	business_location_name,								-- Статус в Supply chain (Business) SD.000492
	port_of_loading_name,								-- Порт погрузки SD.000653
	dt_arrival_to_port_of_discharge_yyyymm,				-- Месяц прибытия в порт выгрузки SD.000736
	container_after_repacking_estimated_quantity,		-- Количество контейнеров SD.000917
	transportation_scheme_name,							-- Схема перевозки SD.000918
	shipment_type_code									-- Вид отгрузки (код) LE SD.001023	
)
select 
	ssms.delivery_number_sales,																			-- Продажная поставка SD.000002
	ssms.plant_producer_code,																			-- Завод производитель (код) SD.000006
	ssms.plant_producer_name,																			-- Завод SD.000007
	ssms.tsw_location_name,																				-- Направление SD.000009
	ssms.dt_shipment,																					-- Дата отгрузки SD.000010
	ssms.dt_arrival_by_railway,																			-- Дата прибытия по ЖД SD.000011
	ssms.dt_forwarder,																					-- Дата экспедитора SD.000012
	ssms.railcar,																						-- Вагон SD.000013
	ssms.transport_bill,																				-- Накладная SD.000014
	ssms.material_aggr_name,																			-- Материал SD.000016
	ssms.material_group_code,																			-- Группа материалов SD.000017
	ssms.shipment_market_name,																			-- Рынок в отгрузке SD.000019
	ssms.dt_warehouse,																					-- Дата склада SD.000024
	ssms.transport_railcar_type_code,																	-- Тип вагона (код) SD.000028
	ssms.transport_railcar_type_name,																	-- Тип вагона SD.000029
	ssms.weight_gross,																					-- Вес брутто SD.000031
	ssms.weight_net,																					-- Вес нетто SD.000032
	ssms.weight_net_with_wirerod,																		-- Вес Н&K SD.000033
	ssms.station_current,																				-- Текущая станция SD.000034
	ssms.station_destination,																			-- Станция назначения SD.000035
	ssms.port_of_discharge_name,																		-- Порт выгрузки SD.000045
	ssms.status_description,																			-- Описание статуса SD.000057
	ssms.dt_arrival_in_port_of_discharge,																-- Дата прибытия в порт выгрузки SD.000059
	ssms.dimensions_unit,																				-- Размер единицы готовой продукции SD.000079
	ssms.container_after_repacking,																		-- Контейнер после перетарки SD.000119
	ssms.distance_remaining,																			-- Оставшееся расстояние SD.000122
	ssms.sales_order,																					-- Заказ ЦК SD.000123
	ssms.dt_arrival_in_port_of_discharge_plan,															-- Дата прибытия в порт выгрузки план SD.000130
	ssms.material_code,																					-- Номер материала SD.000143
	ssms.grade_name,																					-- Марка по спецификации SD.000145
	ssms.uni,																							-- UNI SD.000151
	ssms.status_al2all,																					-- Статус для портала AL2ALL SD.000161
	ssms.material_shape_name_full,																		-- Форма SD.000180
	ssms.country_of_discharge_port_code,																-- Страна POD (код) SD.000340
	ssms.country_of_discharge_port_name,																-- Страна POD SD.000341
	ssms.business_location_name,																		-- Статус в Supply chain (Business) SD.000492
	ssms.port_of_loading_name,																			-- Порт погрузки SD.000653
	to_char(ssms.dt_arrival_in_port_of_discharge, 'yyyy.mm') as dt_arrival_to_port_of_discharge_yyyymm,	-- Месяц прибытия в порт выгрузки SD.000736
	case 
		when ssms.transport_type_after_repackaging_code = 'TL04'
				and ssms.transport_railcar_type_code <> 'TL04'
			 	and ssms.dt_repacked is null
			then round(weight_net / 25.0, 2) 
		when ssms.transport_railcar_type_code = 'TL04'
				and ssms.dt_repacked is not null
			then 
				case
					when count(*) over(partition by ssms.container_after_repacking, ssms.dt_repacked) = 1
        				then 1.0
        			else 
						case 
        					when sum(ssms.weight_net) over(partition by ssms.container_after_repacking, ssms.dt_repacked) = 0
        						then 0
        					else round(ssms.weight_net/ (sum(ssms.weight_net) over(partition by ssms.container_after_repacking, ssms.dt_repacked)), 2)
        				end
				end
		when ssms.transport_railcar_type_code = 'TL04'
				and ssms.dt_repacked is null
			then 
				case 
					when count(*) over(partition by ssms.dt_shipment, ssms.railcar) > 1
						then 
        					case 
        						when SUM(ssms.weight_net) over(partition by ssms.dt_shipment, ssms.railcar) = 0
        							then 0
        						else round(ssms.weight_net / (SUM(ssms.weight_net) over(partition by ssms.dt_shipment, ssms.railcar)), 2)
        					end
        			when count(*) over(partition by ssms.dt_shipment, ssms.railcar) = 1
        				then 1.0
				end				
	end	as container_after_repacking_estimated_quantity,												-- Количество контейнеров SD.000917
	case
		when ssms.transport_type_after_repackaging_code = 'TL04'
				and ssms.transport_railcar_type_code <> 'TL04'
			then 'Перетарка'
		when ssms.transport_railcar_type_code = 'TL04'
				or (ssms.transport_railcar_type_code = 'TL02' 
						and k3.shipment_type_code <> 'X5')
			then 'Прямые КТК'
		when ssms.transport_railcar_type_code = 'TL02'
				and k3.shipment_type_code = 'X5'
			then 'КП'
	end as transportation_scheme_name,																	-- Схема перевозки SD.000918
	k3.shipment_type_code																				-- Вид отгрузки (код) LE SD.001023
from 
	dm_calc.sd_sales_main_scm ssms
	left join ods.map_delivery_document_attributes_keys_ral as k3
		on k3.delivery_code = ssms.delivery_number_of_producer_plant	
where 
	ssms.transport_type_after_repackaging_code = 'TL04'
	or ssms.transport_railcar_type_code = 'TL04';