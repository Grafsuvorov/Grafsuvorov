insert into dm.raw_materials_shipment_and_arrival (
	transport_bill_code,
	railcar_code,
	transport_bill_and_railcar_code,
	departure_type_code,
	departure_type_name,
	status_name,
	russian_port_pier_code,
	russian_port_pier_name,
	russian_port_pier_search_name,
	russian_port_code,
	russian_port_name,
	russian_port_search_name,
	russian_port_terminal_code,
	russian_port_terminal_name,
	russian_port_terminal_search_name,
	vessel_code,
	vessel_name,
	vessel_search_name,
	import_method_code,
	import_method_name,
	import_method_search_name,
	dt_general_act,
	supplier_code,
	supplier_name,
	supplier_search_name,
	producer_code,
	producer_name,
	producer_search_name,
	business_scheme_type_code,
	dt_departure,
	dt_shipping,
	dt_shipping_yyyy,
	dt_shipping_dd,
	dt_shipping_mmm,
	package_type_code,
	package_type_name,
	package_type_search_name,
	material_code,
	material_name,
	material_search_name,
	etsng_code,
	etsng_name,
	etsng_search_name,
	railway_station_of_departure_code,
	railway_station_of_departure_name,
	railway_station_of_departure_search_name,
	plant_of_departure_code,
	plant_of_departure_name,
	plant_of_departure_search_name,
	transport_type_code,
	transport_type_name,
	transport_type_search_name,
	railcar_capacity,
	redirection_type_code,
	redirection_type_name,
	redirection_type_search_name,
	dt_redirected,
	redirection_created_by_code,
	redirection_created_by_name,
	transport_bill_after_redirection_code,
	dt_shipment_after_redirection,
	station_of_destination_after_redirection_code,
	station_of_destination_after_redirection_name,
	station_of_destination_after_redirection_search_name,
	station_of_destination_before_redirection_code,
	station_of_destination_before_redirection_name,
	station_of_destination_before_redirection_search_name,
	plant_of_destination_before_redirection_code,
	plant_of_destination_before_redirection_name,
	plant_of_destination_before_redirection_search_name,
	dt_train_operation,
	dislocation_railcar_operation_code,
	dislocation_railcar_operation_name,
	dislocation_railcar_operation_search_name,
	dislocation_station_of_departure_code,
	dislocation_station_of_destination_code,
	dislocation_station_current_code,
	dislocation_station_current_name,
	dislocation_station_current_search_name,
	distance_left_to_destination_kilometer_quantity,
	dt_dislocation_arrival_to_destination_station,
	dt_dislocation_estimated_arrival_to_destination_station,
	dt_vessel_arrival_to_russian_port,
	dt_vessel_discharge_in_russian_port,
	dt_arrival_to_destination_station,
	dt_zdc_arrival_to_destination_station,
	dt_arrival_by_accounting,
	dt_arrival_yyyy,
	dt_arrival_dd,
	dt_arrival_mmm,
	dt_discharge,
	dt_posting,
	purchase_contract_code,
	railway_station_of_destination_code,
	railway_station_of_destination_name,
	railway_station_of_destination_search_name,
	plant_of_destination_code,
	plant_of_destination_name,
	plant_of_destination_search_name,
	warehouse_code,
	warehouse_name,
	warehouse_search_name,
	railway_track_at_plant_number,
	weight_net
)
select
	raw.transport_bill_code,	
	raw.railcar_code,
	raw.transport_bill_and_railcar_code,
	raw.departure_type_code,
	raw.departure_type_name,
	case when raw.departure_type_code is not null
		 then case when raw.dt_discharge is not null then 'Вагон разгружен на склад'
			 	   when raw.dt_arrival_by_accounting is not null then 'Вагон принят на баланс завода'
				   when raw.dt_zdc_arrival_to_destination_station is null and raw.dt_dislocation_arrival_to_destination_station is null
				   then case when raw.departure_type_code = '05'
							 then case when raw.dt_vessel_discharge_in_russian_port is not null and raw.distance_left_to_destination_kilometer_quantity is not null then 'На колесах по ЖД'
							 		   when raw.dt_vessel_discharge_in_russian_port is not null then 'В порту РФ'
							 		   else 'По морю из КНР'
							 	  end
							 else 'На колесах по ЖД'
						end
				   when raw.dt_zdc_arrival_to_destination_station is null and raw.dt_dislocation_arrival_to_destination_station is not null then 'Вагон на станции завода без приемки в учете'
				   when raw.dt_zdc_arrival_to_destination_station is not null then 'Вагон на станции завода и заведен в АСУ ЖДЦ'	
			   end
	end as status_name,
	raw.russian_port_pier_code,
	thrpp.transport_hub_name as russian_port_pier_name,
	raw.russian_port_pier_code||'-'||coalesce(thrpp.transport_hub_name, '') as russian_port_pier_search_name,
	raw.russian_port_code,
	thrp.transport_hub_name as russian_port_name,
	raw.russian_port_code||'-'||coalesce(thrp.transport_hub_name, '') as russian_port_search_name,
	raw.russian_port_terminal_code,
	thrpt.transport_hub_name as russian_port_terminal_name,
	raw.russian_port_terminal_code||'-'||coalesce(thrpt.transport_hub_name, '') as russian_port_terminal_search_name,
	raw.vessel_code,
	tv.vessel_name,
	raw.vessel_code||'-'||coalesce(tv.vessel_name, '') as vessel_search_name,
	raw.import_method_code,
	imt.import_method_name,
	raw.import_method_code||'-'||coalesce(imt.import_method_name, '') as import_method_search_name,
	raw.dt_general_act,
	raw.supplier_code,
	cntr1.counterparty_full_name as supplier_name,
	raw.supplier_code||'-'||coalesce(cntr1.counterparty_full_name, '') as supplier_search_name,
	raw.producer_code,
	cntr2.counterparty_full_name as producer_name,
	raw.producer_code||'-'||coalesce(cntr2.counterparty_full_name, '') as producer_search_name,
	raw.business_scheme_type_code,
	raw.dt_departure,
	raw.dt_shipping,
	date_part('year', dt_shipping)::varchar(4) as dt_shipping_yyyy,
	lpad(date_part('day', dt_shipping)::varchar, 2, '0') as dt_shipping_dd,
	case when date_part('month', dt_shipping) = 1 then '01 '||'Январь' 
		 when date_part('month', dt_shipping) = 2 then '02 '||'Февраль' 
		 when date_part('month', dt_shipping) = 3 then '03 '||'Март'
		 when date_part('month', dt_shipping) = 4 then '04 '||'Апрель' 
		 when date_part('month', dt_shipping) = 5 then '05 '||'Май' 
		 when date_part('month', dt_shipping) = 6 then '06 '||'Июнь'
		 when date_part('month', dt_shipping) = 7 then '07 '||'Июль' 
		 when date_part('month', dt_shipping) = 8 then '08 '||'Август' 
		 when date_part('month', dt_shipping) = 9 then '09 '||'Сентябрь'
		 when date_part('month', dt_shipping) = 10 then '10 '||'Октябрь' 
		 when date_part('month', dt_shipping) = 11 then '11 '||'Ноябрь' 
		 when date_part('month', dt_shipping) = 12 then '12 '||'Декабрь'
	end as dt_shipping_mmm,
	raw.package_type_code,
	ptt.package_type_name,
	raw.package_type_code||'-'||coalesce(ptt.package_type_name, '') as package_type_search_name,
	raw.material_code,
	mt.material_name,
	raw.material_code||'-'||coalesce(mt.material_name, '') as material_search_name,
	raw.etsng_code,
	et.etsng_name_rus as etsng_name,
	raw.etsng_code||'-'||coalesce(et.etsng_name_rus, '') as etsng_search_name,
	raw.railway_station_of_departure_code,
	thshdep.transport_hub_name as railway_station_of_departure_name,
	raw.railway_station_of_departure_code||'-'||coalesce(thshdep.transport_hub_name, '') as railway_station_of_departure_search_name,
	raw.plant_of_departure_code,
	plshdep.plant_full_name as plant_of_departure_name,
	raw.plant_of_departure_code||'-'||coalesce(plshdep.plant_full_name, '') as plant_of_departure_search_name,
	raw.transport_type_code,
	ttt.transport_transfer_type_name_rus as transport_type_name,
	raw.transport_type_code||'-'||coalesce(ttt.transport_transfer_type_name_rus, '') as transport_type_search_name,
	raw.railcar_capacity,
	raw.redirection_type_code,
	trtt.redirection_type_name,
	raw.redirection_type_code||'-'||coalesce(trtt.redirection_type_name, '') as redirection_type_search_name,
	raw.dt_redirected,
	raw.redirection_created_by_code,
	pmd1.person_full_name as redirection_created_by_name,
	raw.transport_bill_after_redirection_code,
	raw.dt_shipment_after_redirection,
	raw.station_of_destination_after_redirection_code,
	thsdar.transport_hub_name as station_of_destination_after_redirection_name,
	raw.station_of_destination_after_redirection_code||'-'||coalesce(thsdar.transport_hub_name, '') as station_of_destination_after_redirection_search_name,
	raw.station_of_destination_before_redirection_code,
	thsdbr.transport_hub_name as station_of_destination_before_redirection_name,
	raw.station_of_destination_before_redirection_code||'-'||coalesce(thsdbr.transport_hub_name, '') as station_of_destination_before_redirection_search_name,
	raw.plant_of_destination_before_redirection_code,
	pldbr.plant_full_name as plant_of_destination_before_redirection_name,
	raw.plant_of_destination_before_redirection_code||'-'||coalesce(pldbr.plant_full_name, '') as plant_of_destination_before_redirection_search_name,
	raw.dt_train_operation,
	raw.dislocation_railcar_operation_code,
	tot.transport_operation_full_name as dislocation_railcar_operation_name,
	raw.dislocation_railcar_operation_code||'-'||coalesce(tot.transport_operation_full_name, '') as dislocation_railcar_operation_search_name,
	raw.dislocation_station_of_departure_code,
	raw.dislocation_station_of_destination_code,
	raw.dislocation_station_current_code,
	thdsc.transport_hub_name as dislocation_station_current_name,
	raw.dislocation_station_current_code||'-'||coalesce(thdsc.transport_hub_name, '') as dislocation_station_current_search_name,
	raw.distance_left_to_destination_kilometer_quantity,
	raw.dt_dislocation_arrival_to_destination_station,
	raw.dt_dislocation_estimated_arrival_to_destination_station,
	raw.dt_vessel_arrival_to_russian_port,
	raw.dt_vessel_discharge_in_russian_port,
	raw.dt_arrival_to_destination_station,
	raw.dt_zdc_arrival_to_destination_station,
	raw.dt_arrival_by_accounting,
	date_part('year', raw.dt_arrival_to_destination_station)::varchar(4) as dt_arrival_yyyy,
	lpad(date_part('day', raw.dt_arrival_to_destination_station)::varchar, 2, '0') as dt_arrival_dd,
	case when date_part('month', raw.dt_arrival_to_destination_station) = 1 then '01 '||'Январь' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 2 then '02 '||'Февраль' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 3 then '03 '||'Март'
		 when date_part('month', raw.dt_arrival_to_destination_station) = 4 then '04 '||'Апрель' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 5 then '05 '||'Май' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 6 then '06 '||'Июнь'
		 when date_part('month', raw.dt_arrival_to_destination_station) = 7 then '07 '||'Июль' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 8 then '08 '||'Август' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 9 then '09 '||'Сентябрь'
		 when date_part('month', raw.dt_arrival_to_destination_station) = 10 then '10 '||'Октябрь' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 11 then '11 '||'Ноябрь' 
		 when date_part('month', raw.dt_arrival_to_destination_station) = 12 then '12 '||'Декабрь'
	end as dt_arrival_mmm,
	raw.dt_discharge,
	raw.dt_posting,
	raw.purchase_contract_code,
	raw.railway_station_of_destination_code,
	thshdest.transport_hub_name as railway_station_of_destination_name,
	raw.railway_station_of_destination_code||'-'||coalesce(thshdest.transport_hub_name, '') as railway_station_of_destination_search_name,
	raw.plant_of_destination_code,
	plshdest.plant_full_name as plant_of_destination_name,
	raw.plant_of_destination_code||'-'||coalesce(plshdest.plant_full_name, '') as plant_of_destination_search_name,
	raw.warehouse_code,
	wh.warehouse_name,
	raw.warehouse_code||'-'||coalesce(wh.warehouse_name, '') as warehouse_search_name,
	raw.railway_track_at_plant_number,
	raw.weight_net
from dm_calc.raw_materials_shipment_and_arrival as raw
	left join dict_dds.transport_hub_texts as thrpp
		on thrpp.transport_hub_code = raw.russian_port_pier_code and
		   thrpp.language_code = 'R'
	left join dict_dds.transport_hub_texts as thrp
		on thrp.transport_hub_code = raw.russian_port_code and
		   thrp.language_code = 'R'
	left join dict_dds.transport_hub_texts as thrpt
		on thrpt.transport_hub_code = raw.russian_port_terminal_code and
		   thrpt.language_code = 'R'
	left join dict_dds.transport_hub_texts as thshdep
		on thshdep.transport_hub_code = raw.railway_station_of_departure_code and
		   thshdep.language_code = 'R'
	left join dict_dds.transport_hub_texts as thshdest
		on thshdest.transport_hub_code = raw.railway_station_of_destination_code and
		   thshdest.language_code = 'R'
	left join dict_dds.transport_hub_texts as thsdar
		on thsdar.transport_hub_code = raw.station_of_destination_after_redirection_code and
		   thsdar.language_code = 'R'
	left join dict_dds.transport_hub_texts as thsdbr
		on thsdbr.transport_hub_code = raw.station_of_destination_before_redirection_code and
		   thsdbr.language_code = 'R'
	left join dict_dds.transport_hub_texts as thdsc
		on thdsc.transport_hub_code = raw.dislocation_station_current_code and
		   thdsc.language_code = 'R'
	left join dict_dds.plant_and_subsidiary as plshdep
		on plshdep.plant_code = raw.plant_of_departure_code
	left join dict_dds.plant_and_subsidiary as plshdest
		on plshdest.plant_code = raw.plant_of_destination_code
	left join dict_dds.plant_and_subsidiary as pldbr
		on pldbr.plant_code = raw.plant_of_destination_before_redirection_code
	left join dict_dds.transport_vessel_old as tv
		on tv.vessel_code_new = raw.vessel_code
	left join dict_dds.import_method_texts as imt
		on imt.import_method_code = raw.import_method_code and
		   imt.language_code = 'R'
	left join dict_dds.counterparty as cntr1
		on cntr1.counterparty_code = raw.supplier_code	
	left join dict_dds.counterparty as cntr2
		on cntr2.counterparty_code = raw.producer_code
	left join dict_dds.package_type_texts as ptt
		on ptt.package_type_code = raw.package_type_code and
		   ptt.language_code = 'R'
	left join dict_dds.material_texts as mt
		on mt.material_code = raw.material_code and
		   mt.language_code = 'R'
	left join dict_dds.etsng as et
		on et.etsng_code = raw.etsng_code
	left join dict_dds.transport_transfer_type as ttt
		on ttt.transport_transfer_type_code = raw.transport_type_code
	left join dict_dds.transport_redirection_type_texts as trtt
		on trtt.redirection_type_code = raw.redirection_type_code and
		   trtt.language_code = 'R'	   
	left join dict_dds.warehouse as wh
		on wh.plant_code = raw.plant_of_destination_code and
		   wh.warehouse_code = raw.warehouse_code
	left join dict_dds.map_username_to_address as muta1
		on muta1.login_username = raw.redirection_created_by_code
	left join dict_dds.person_main_data as pmd1
		on pmd1.person_code = muta1.person_code
	left join dict_dds.transport_operation_texts as tot
		on tot.transport_type_code = '2' and
		   tot.transport_operation_code = raw.dislocation_railcar_operation_code and
		   tot.language_code = 'R'
;