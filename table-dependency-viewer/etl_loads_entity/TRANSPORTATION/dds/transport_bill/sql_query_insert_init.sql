create temporary table disloc on commit drop as (
	with cte1 as (
		select
			rl.numvag,
			rl.numnakl,
			rl.datd,
			rl.uzeit,
			rl.knote1,
			rl.knote2,
			rl.knote_naz,
			rl.opcode,
			rl.deliv_date,
			rl.distance_left,
			row_number() over (partition by rl.numvag, rl.numnakl order by rl.datd + rl.uzeit desc) as rwn
		from ods."/rusal/ledisloc_ral" as rl
	)
	select
		numvag,
		numnakl,
		datd,
		uzeit,
		knote1,
		knote2,
		knote_naz,
		opcode,
		deliv_date,
		distance_left
	from cte1
	where rwn = 1
)
distributed by (numvag, numnakl);

insert into dds.transport_bill (
	transport_bill_code,
	vehicle_code,
	transport_bill_and_vehicle_code,
	departure_type_code,
	departure_type_name,
	dt_shipping,
	dt_departure,
	russian_port_pier_code,
	russian_port_code,
	russian_port_terminal_code,
	supplier_code,
	producer_code,
	business_scheme_type_code,
	package_type_code,
	material_code,
	railway_station_of_departure_code,
	plant_of_departure_code,
	railway_station_of_destination_code,
	plant_of_destination_code,
	import_method_code,
	is_compound_cargo,
	etsng_code,
	transport_type_code,
	vehicle_capacity,
	redirection_type_code,
	dt_redirected,
	redirection_created_by_code,
	transport_bill_after_redirection_code,
	dt_shipment_after_redirection,
	station_of_destination_after_redirection_code,
	station_of_destination_before_redirection_code,
	plant_of_destination_before_redirection_code,
	dt_train_operation,
	dislocation_railcar_operation_code,
	dislocation_station_of_departure_code,
	dislocation_station_of_destination_code,
	dislocation_station_current_code,
	distance_left_to_destination_kilometer_quantity,
	dt_dislocation_arrival_to_destination_station,
	dt_dislocation_estimated_arrival_to_destination_station,
	dt_arrival_to_destination_station,
	dt_zdc_arrival_to_destination_station,
	dt_arrival_by_accounting,
	weight_net
)
with map1 as(
	select
		type_prod,
		werks_to,
		business_scheme_type_code
	from ( values 
				('1', '5101', 'ТОЛЛИНГ'),
				('1', '5201', 'ТОЛЛИНГ'),
				('1', '5301', 'ТОЛЛИНГ'),
				('2', '5101', 'Давальческ'),
				('2', '5201', 'Давальческ'),
				('2', '5203', 'Давальческ'),
				('2', '5301', 'Давальческ'), 
				('2', '5401', 'Давальческ'),
				('2', '6300', 'ПОКУПНОЙ'),
				('2', '6800', 'ПОКУПНОЙ'),
				('2', '5601', 'ПОКУПНОЙ'), 
				('2',' 5701', 'ПОКУПНОЙ') ) as my_t(type_prod, werks_to, business_scheme_type_code)
),
asugdc as (
	select 
		car_num,
		ndoc_gd,
		row_number() over (partition by car_num, ndoc_gd order by dt_in_gdc desc) as rwn,
		dt_in_gdc,
		rw_st,
		cargo_weight
	from ods.asugdc_arrived_cargo
),
all_table as (
	select
		lp.numnakl as transport_bill_code,
		lp.numvag as vehicle_code,
		lp.numnakl||'-'||lp.numvag as transport_bill_and_vehicle_code,	
		'01' as departure_type_code,
		'Перевалка в порту РФ' as departure_type_name,
		lp.regdate as dt_shipping,	
		lp.senddate as dt_departure,
		lp.dock_knote as russian_port_pier_code,
		lp.knote as russian_port_code,
		lp.zterminal as russian_port_terminal_code,
		null as supplier_code,
		null as producer_code,
		map1.business_scheme_type_code as business_scheme_type_code,
		lp.cartare as package_type_code,
		lp.type_vagon as transport_type_code,
		lp.matnr as material_code,
		lp.knote1 as railway_station_of_departure_code,
		lp.werks_from as plant_of_departure_code,
	    lp.knote2 as railway_station_of_destination_code,
	    null as plant_of_destination_code,
		lp.type_prod as import_method_code,
		null as dt_arrival_by_accounting,	
		case when (count() over (partition by lp.numvag, lp.numnakl)) > 1  or count() > 1 then 'X' else null end as is_compound_cargo,
		sum(lp.weightnet) as weight_net
	from ods."/rusal/lepervlka_ral" as lp
		left join map1
			on map1.type_prod = lp.type_prod and 
			   map1.werks_to = lp.werks_to  
	group by 
		lp.numnakl,
		lp.numvag,
		lp.regdate,
		lp.senddate,
		lp.dock_knote,
		lp.knote,
		lp.zterminal,
		map1.business_scheme_type_code,
		lp.cartare,
		lp.type_vagon,
		lp.matnr,
		lp.knote1,
		lp.werks_from,
	    lp.knote2,
		lp.type_prod
	-----------------------------------------------------------------------------------------------------------------------------------
	union all
	-----------------------------------------------------------------------------------------------------------------------------------
	select
		lp.numnakl as transport_bill_code,
		lp.numvag as vehicle_code,
		lp.numnakl||'-'||lp.numvag as transport_bill_and_vehicle_code,
		'02' as departure_type_code,
		'Предварительная перевалка в порту РФ' as departure_type_name,
		lp.regdate as dt_shipping,
		lp.senddate as dt_departure,
		lp.dock_knote as russian_port_pier_code,
		lp.knote as russian_port_code,
		lp.zterminal as russian_port_terminal_code,
		null as supplier_code,
		null as producer_code,
		null as business_scheme_type_code,
		lp.cartare as package_type_code,
		lp.type_vagon as transport_type_code,	
		lp.matnr as material_code,
		lp.knote1 as railway_station_of_departure_code,
		lp.werks_from as plant_of_departure_code,
	    lp.knote2 as railway_station_of_destination_code,
	    null as plant_of_destination_code,
		lp.type_prod as import_method_code,
		null as dt_arrival_by_accounting,	
		case when (count() over (partition by lp.numvag, lp.numnakl)) > 1 then 'X' else null end as is_compound_cargo,
		lp.weightnet as weight_net
	from ods."/rusal/lepervlk1_ral" as lp
		left join ods."/rusal/lepervlka_ral" as leper1
			on leper1.numvag = lp.numvag and
			   leper1.numnakl = lp.numnakl
		left join ods."/rusal/lepervlka_ral" as leper2
			on leper2.regdate = lp.regdate and
			   leper2.vehicle = lp.vehicle
	where leper1.numvag is null and leper1.numnakl is null
	  and leper2.regdate is null and leper2.vehicle is null
	-----------------------------------------------------------------------------------------------------------------------------------
	union all
	-----------------------------------------------------------------------------------------------------------------------------------
	select
		lp.numnakl as transport_bill_code,
		lp.numvag as vehicle_code,
		lp.numnakl||'-'||lp.numvag as transport_bill_and_vehicle_code,
		'03' as departure_type_code,
		'Отгрузка из стран СНГ' as departure_type_name,
		lp.dateot as dt_shipping,
		lp.dateot as dt_departure,
		null as russian_port_pier_code,
		null as russian_port_code,
		null as russian_port_terminal_code,
		lp.lifnr as supplier_code,
		lp.lifnr_pr as producer_code,
		null as business_scheme_type_code,
		coalesce(ausp.atwrt, lp.cartare_pr) as package_type_code,
		lp.type_vagon as transport_type_code,	
		lp.matnr as material_code,
		lp.sto as railway_station_of_departure_code,
		mthtp2.plant_code as plant_of_departure_code,
	    lp.stn as railway_station_of_destination_code,
	    null as plant_of_destination_code,
		null as import_method_code,
		null as dt_arrival_by_accounting,	
		case when (count() over (partition by lp.numvag, lp.numnakl)) > 1 then 'X' else null end as is_compound_cargo,
		lp.weight as weight_net
	from ods."/rusal/lemps_ral" as lp
		left join ods."/rusal/lepervlka_ral" as leper1
			on leper1.numvag = lp.numvag and
			   leper1.numnakl = lp.numnakl
		left join ods."/rusal/lepervlk1_ral" as leper2
			on leper2.numvag = lp.numvag and
			   leper2.numnakl = lp.numnakl
		left join ods."/rusal/shiptemp_ral" as shp
			on shp.vagon = lp.numvag and
			   shp.nakladn = lp.numnakl
		left join dict_dds.map_transport_hub_to_plant as mthtp2
			on mthtp2.transport_hub_code = lp.sto
		left join ods.ausp_ral as ausp
			on ausp.objek = lp.dtl_vbeln and
			   ausp.objek is not null and
		       ausp.atinn = ( select cabn.internal_characteristic_code		
							  from dict_dds.internal_characteristic as cabn
			                  where cabn.internal_characteristic_title_code = 'CARTARE_TYPE' ) and 
			   ausp.klart = 'Z18'		   
	where leper1.numvag is null and leper1.numnakl is null
	  and leper2.numvag is null and leper2.numnakl is null
	  and shp.vagon is null and shp.nakladn is null
	  and lp.matnr is not null
	-----------------------------------------------------------------------------------------------------------------------------------
	union all
	-----------------------------------------------------------------------------------------------------------------------------------
	select
		sh.nakladn as transport_bill_code,
		sh.vagon as vehicle_code,
		sh.nakladn||'-'||sh.vagon as transport_bill_and_vehicle_code,
		'04' as departure_type_code,
		'Отгрузка с ГЗ в РФ' as departure_type_name,
		sh.dateot as dt_shipping,
		sh.dateot as dt_departure,
		null as russian_port_pier_code,
		null as russian_port_code,
		null as russian_port_terminal_code,
		sh.firmaoid as supplier_code,
		sh.proizid as producer_code,
		null as business_scheme_type_code,
		trim(leading '0' from cast(sh.cartare as char(3))) as package_type_code,
		sh.traty as transport_type_code,	
		sh.gradecod as material_code,
		case when sh.stationoc is not null and length(sh.stationoc) > 0 
	    	   then (select transport_hub_code 
	    	         from dict_dds.transport_hub as th
	    	         where th.railway_station_rzd_code = lpad(left(sh.stationoc, (length(sh.stationoc) - 1)), 10, '0') 
	    	           and th.is_transport_hub_locked is null
	    	         limit 1)
	         else null end as railway_station_of_departure_code,
		sh.plant as plant_of_departure_code,
		case when sh.stationnc is not null and length(sh.stationnc) > 0 
	    	   then (select transport_hub_code 
	    	         from dict_dds.transport_hub as th
	    	         where th.railway_station_rzd_code = lpad(left(sh.stationnc, (length(sh.stationnc) - 1)), 10, '0') 
	    	           and th.is_transport_hub_locked is null
	    	         limit 1)
	         else null end as railway_station_of_destination_code,
	    null as plant_of_destination_code,
		null as import_method_code,
		null as dt_arrival_by_accounting,
		case when (count() over (partition by sh.vagon, sh.nakladn)) > 1 then 'X' else null end as is_compound_cargo,
		sh.dryweight / 1000 as weight_net
	from ods."/rusal/shiptemp_ral" as sh
	where sh.plant in ( '4101', '6500', '6600' )
	  and sh.gradecod = '000000000001000001'
	  and sh.firmap is not null
	-----------------------------------------------------------------------------------------------------------------------------------
	union all
	-----------------------------------------------------------------------------------------------------------------------------------
	select
		lp.numnakl as transport_bill_code,
		lp.numvag as vehicle_code,
		lp.numnakl||'-'||lp.numvag as transport_bill_and_vehicle_code,
		'05' as departure_type_code,
		'Отгрузка из КНР' as departure_type_name,
		lp.dateot as dt_shipping,
		lp.dateot as dt_departure,
		null as russian_port_pier_code,
		lr.port_to as russian_port_code,
		lr.terminal_rf as russian_port_terminal_code,
		lp.lifnr as supplier_code,
		lp.lifnr_pr as producer_code,
		null as business_scheme_type_code,
		null as package_type_code,
	    null as transport_type_code,	
		lp.matnr as material_code,
		lp.zdkodstfr as railway_station_of_departure_code,
		null as plant_of_departure_code,
		lp.zdkodstto as railway_station_of_destination_code,
		null as plant_of_destination_code,
		null as import_method_code,
		lp.datew as dt_arrival_by_accounting,
		case when (count() over (partition by lp.numvag, lp.numnakl)) > 1 then 'X' else null end as is_compound_cargo,
		lp.netto / 1000 as weight_net
	from ods."/rusal/lepost_ral" as lp
		left join ods."/rusal/leport_ral" as lr		
			on lr.container = lp.numvag and 
			   lr.bl = lp.numnakl
		/*left join ods."/rusal/lepervlka_ral" as leper1_full
			on leper1_full.numvag = lp.numvag and
			   leper1_full.numnakl = lp.numnakl*/
		left join ods."/rusal/lepervlka_ral" as leper1_part
			on leper1_part.numvag = split_part(lp.numvag, (case when lp.numvag like '%&%' then '&' else '$' end), 1) and
			   leper1_part.numnakl = split_part(lp.numnakl, (case when lp.numnakl like '%&%' then '&' else '$' end), 1)   
		/*left join ods."/rusal/lepervlk1_ral" as leper2_full
			on leper2_full.numvag = lp.numvag and
			   leper2_full.numnakl = lp.numnakl*/
		left join ods."/rusal/lepervlk1_ral" as leper2_part
			on leper2_part.numvag = split_part(lp.numvag, (case when lp.numvag like '%&%' then '&' else '$' end), 1) and
			   leper2_part.numnakl = split_part(lp.numnakl, (case when lp.numnakl like '%&%' then '&' else '$' end), 1)
		/*left join ods."/rusal/shiptemp_ral" as shp_full
			on shp_full.vagon = lp.numvag and
			   shp_full.nakladn = lp.numnakl*/
		left join ods."/rusal/shiptemp_ral" as shp_part
			on shp_part.vagon = split_part(lp.numvag, (case when lp.numvag like '%&%' then '&' else '$' end), 1) and
			   shp_part.nakladn = split_part(lp.numnakl, (case when lp.numnakl like '%&%' then '&' else '$' end), 1)
		/*left join ods."/rusal/lemps_ral" as mps_full
			on mps_full.numvag = lp.numvag and
			   mps_full.numnakl = lp.numnakl*/
		left join ods."/rusal/lemps_ral" as mps_part
			on mps_part.numvag = split_part(lp.numvag, (case when lp.numvag like '%&%' then '&' else '$' end), 1) and
			   mps_part.numnakl = split_part(lp.numnakl, (case when lp.numnakl like '%&%' then '&' else '$' end), 1)
	where --leper1_full.numvag is null and 
		leper1_part.numvag is null
	  --and leper2_full.numvag is null
	  and leper2_part.numvag is null
	  --and shp_full.vagon is null
	  and shp_part.vagon is null
	  --and mps_full.numvag is null
	  and mps_part.numvag is null
	-----------------------------------------------------------------------------------------------------------------------------------
	union all
	-----------------------------------------------------------------------------------------------------------------------------------
	select
		ztle.numnakl as transport_bill_code,
		ztle.container as vehicle_code,
		ztle.numnakl||'-'||ztle.container as transport_bill_and_vehicle_code,
		'06' as departure_type_code,
		'Внешние поставщики по суше в контейнерах' as departure_type_name,
		ztle.dateot as dt_shipping,
		ztle.dateot as dt_departure,
		null as russian_port_pier_code,
		null as russian_port_code,
		null as russian_port_terminal_code,
		ausp1.atwrt as supplier_code,
		ausp2.atwrt as producer_code,
		null as business_scheme_type_code,
		'6' as package_type_code,
	    'TL02' as transport_type_code,	
		'000000000001000001' as material_code,
		ztle.zdkodstfr as railway_station_of_departure_code,
		null as plant_of_departure_code,							--ztle.werks as plant_of_departure_code,
		ztle.zdkodstto as railway_station_of_destination_code,
		ztle.werks as plant_of_destination_code,
		null as import_method_code,
		null as is_compound_cargo,
		null as dt_arrival_by_accounting,
		ztle.weight as weight_net
	from ods.ztle_railcn_ral as ztle
		left join ods.lips_ral as lips
			on lips.vbeln = ztle.vbeln
		left join dict_stg."INOB" as inob
			on inob."OBJEK" = lips.matnr||lips.charg
		left join ods.ausp_ral as ausp1
			on ausp1.objek = inob."CUOBJ" and
		       ausp1.atinn = ( select cabn.internal_characteristic_code		
							   from dict_dds.internal_characteristic as cabn
			                   where cabn.internal_characteristic_title_code = 'ROH_PVAG' ) and				--0000000063
			   ausp1.klart = '023'
		left join ods.ausp_ral as ausp2
			on ausp2.objek = inob."CUOBJ" and
		       ausp2.atinn = ( select cabn.internal_characteristic_code		
						   	   from dict_dds.internal_characteristic as cabn
			               	   where cabn.internal_characteristic_title_code = 'ROH_PROIZV' ) and 			--0000001909
			   ausp2.klart = '023'
), 
all_table_with_disloc as (
	select
		coalesce(all_table.transport_bill_code, disloc.numnakl) as transport_bill_code,
		coalesce(all_table.vehicle_code, disloc.numvag) as vehicle_code,
		coalesce(all_table.transport_bill_and_vehicle_code, disloc.numnakl||'-'||disloc.numvag) as transport_bill_and_vehicle_code,
		all_table.departure_type_code,
		all_table.departure_type_name,
		all_table.dt_shipping,
		all_table.dt_departure,
		all_table.russian_port_pier_code,
		all_table.russian_port_code,
		all_table.russian_port_terminal_code,
		all_table.supplier_code,											--атрибуты партии
		all_table.producer_code,											--атрибуты партии
		all_table.business_scheme_type_code,
		all_table.package_type_code,
		all_table.material_code,
		all_table.railway_station_of_departure_code,
		all_table.plant_of_departure_code,
		all_table.railway_station_of_destination_code,
		all_table.plant_of_destination_code,
		all_table.import_method_code,
		all_table.is_compound_cargo,
		all_table.transport_type_code,
		disloc.datd as dt_train_operation,
		disloc.opcode as dislocation_railcar_operation_code,
		coalesce(disloc.knote1, dislcont.load_station) as dislocation_station_of_departure_code,
		disloc.knote_naz as dislocation_station_of_destination_code,
		disloc.knote2 as dislocation_station_current_code,
		disloc.distance_left as distance_left_to_destination_kilometer_quantity,
		case when disloc.knote2 = disloc.knote_naz then disloc.datd end as dt_dislocation_arrival_to_destination_station,
		disloc.datd + round((disloc.distance_left::numeric / 260), 0)::int as dt_dislocation_estimated_arrival_to_destination_station,
		all_table.dt_arrival_by_accounting,
		all_table.weight_net
	from all_table
		full join disloc
			on all_table.vehicle_code = disloc.numvag and
			   all_table.transport_bill_code = disloc.numnakl
		left join (	
				select
					all_table.vehicle_code,
					all_table.dt_departure,
					zdr.oper_date,
					zdr.load_station,
					row_number() over (partition by all_table.vehicle_code, all_table.dt_departure order by zdr.oper_date) as rwn
				from all_table
				join (
					select
						zdr.container,
						zdr.oper_date,
						zdr.load_station
					from ods.zle_dislcont_ral as zdr
					where zdr.oper_code like '1_'
					group by 
						zdr.container,
						zdr.oper_date,
						zdr.load_station
					) as zdr
				on 	zdr.container = all_table.vehicle_code and
					zdr.oper_date >= all_table.dt_departure	) as dislcont
			on dislcont.vehicle_code = all_table.vehicle_code and
			   dislcont.dt_departure = all_table.dt_departure and
			   dislcont.rwn = 1
)
select
	shipment.transport_bill_code,
	shipment.vehicle_code,
	shipment.transport_bill_and_vehicle_code,
	shipment.departure_type_code,
	shipment.departure_type_name as departure_type_name,
	shipment.dt_shipping,
	shipment.dt_departure,
	shipment.russian_port_pier_code,
	shipment.russian_port_code,
	shipment.russian_port_terminal_code,
	shipment.supplier_code,												--атрибуты партии
	shipment.producer_code,												--атрибуты партии
	shipment.business_scheme_type_code,
	shipment.package_type_code,
	shipment.material_code,
	shipment.railway_station_of_departure_code,
	shipment.plant_of_departure_code,
	coalesce(th2.transport_hub_code,
			 th1.transport_hub_code,
			 redir.knend2,
			 shipment.railway_station_of_destination_code) as railway_station_of_destination_code,
	case when th2.transport_hub_code is not null then mthtp2.plant_code
		 when th1.transport_hub_code is not null then mthtp3.plant_code
		 when redir.knend2 is not null then mthtp4.plant_code
		 else coalesce(shipment.plant_of_destination_code, mthtp5.plant_code)		 
		 --when shipment.railway_station_of_destination_code is not null then mthtp5.plant_code
	end as plant_of_destination_code,
	shipment.import_method_code,
	shipment.is_compound_cargo,
	matr.etsng_code,
	coalesce(le1965.railcar_type_code, shipment.transport_type_code) as transport_type_code,
	coalesce(le1965.railcar_capacity, ttt.capacity_amount) as vehicle_capacity,
	redir.change_type as redirection_type_code,
	redir.erdat as dt_redirected,
	redir.ernam as redirection_created_by,
	redir.bolnr2 as transport_bill_after_redirection_code,
	redir.lfdat2 as dt_shipment_after_redirection,
	redir.knanf2 as station_of_destination_after_redirection_code,
	coalesce(redir.knend3, case when redir.change_type = '05' then redir.knanf2 end) as station_of_destination_before_redirection_code,
	case when redir.knend3 is not null then mthtp1.plant_code
	     when redir.change_type = '05' then mthtp6.plant_code
	end as plant_of_destination_before_redirection_code,
	shipment.dt_train_operation,
	shipment.dislocation_railcar_operation_code,
	shipment.dislocation_station_of_departure_code,
	shipment.dislocation_station_of_destination_code,
	shipment.dislocation_station_current_code,
	shipment.distance_left_to_destination_kilometer_quantity,
	shipment.dt_dislocation_arrival_to_destination_station,
	shipment.dt_dislocation_estimated_arrival_to_destination_station,
	coalesce(asugdc_redir.dt_in_gdc, 
			 asugdc.dt_in_gdc,
			 shipment.dt_dislocation_arrival_to_destination_station,
			 shipment.dt_dislocation_estimated_arrival_to_destination_station) as dt_arrival_to_destination_station,
	coalesce(asugdc_redir.dt_in_gdc, asugdc.dt_in_gdc) as dt_zdc_arrival_to_destination_station,
	shipment.dt_arrival_by_accounting,
	case when shipment.is_compound_cargo is null then coalesce(asugdc.cargo_weight, shipment.weight_net)
	     else shipment.weight_net
	end as weight_net
----------------------------------------------------------------------------------------------------------------------------------------------	
from all_table_with_disloc as shipment
	/*join (select matnr from ods."/rusal/otmm_rv_ral" group by matnr) as arr_matnr
		on arr_matnr.matnr = shipment.material_code*/
	left join ods."/rusal/redirect_ral" as redir
		on redir.traid = shipment.vehicle_code and
		   redir.bolnr1 = shipment.transport_bill_code
	left join asugdc as asugdc			--ods.asugdc_arrived_cargo as asugdc
		on asugdc.car_num = shipment.vehicle_code and
		   asugdc.ndoc_gd = shipment.transport_bill_code
		   and asugdc.rwn = 1
	left join asugdc as asugdc_redir	--ods.asugdc_arrived_cargo as asugdc_redir
		on asugdc_redir.car_num = redir.traid and
		   asugdc_redir.ndoc_gd = redir.bolnr2
		   and asugdc.rwn = 1
    left join dict_dds.transport_hub as th1
    	on th1.railway_station_rzd_code = lpad(left(asugdc.rw_st, (length(asugdc.rw_st) - 1)), 10, '0') and
    	   th1.is_transport_hub_locked is null
    left join dict_dds.transport_hub as th2
    	on th2.railway_station_rzd_code = lpad(left(asugdc_redir.rw_st, (length(asugdc_redir.rw_st) - 1)), 10, '0') and
    	   th2.is_transport_hub_locked is null
	left join dict_dds.map_transport_hub_to_plant as mthtp1
		on mthtp1.transport_hub_code = redir.knend3
	left join dict_dds.map_transport_hub_to_plant as mthtp6
		on mthtp6.transport_hub_code = redir.knanf2	
	left join dict_dds.map_transport_hub_to_plant as mthtp2
		on mthtp2.transport_hub_code = th2.transport_hub_code
	left join dict_dds.map_transport_hub_to_plant as mthtp3
		on mthtp3.transport_hub_code = th1.transport_hub_code
	left join dict_dds.map_transport_hub_to_plant as mthtp4
		on mthtp4.transport_hub_code = redir.knend2
	left join dict_dds.map_transport_hub_to_plant as mthtp5
		on mthtp5.transport_hub_code = shipment.railway_station_of_destination_code
    left join dict_dds.railcar_certificate as le1965
		on le1965.railcar_code = shipment.vehicle_code
	left join dict_dds.material as matr
		on matr.material_code = shipment.material_code
	left join dict_dds.transport_transfer_type as ttt
		on ttt.transport_transfer_type_code = shipment.transport_type_code
;