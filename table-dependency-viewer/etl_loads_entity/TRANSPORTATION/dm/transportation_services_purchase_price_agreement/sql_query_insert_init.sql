insert into dm.transportation_services_purchase_price_agreement
with counterparty_role as (
	select
		ekpa.purchase_document_code,
		ekpa.counterparty_role_code,
		ekpa.consecutive_number,
		max(ekpa.consecutive_number) over (partition by ekpa.purchase_document_code, ekpa.counterparty_role_code) as last_consecutive_number,
		ekpa.personnel_code
	from dds.purchase_document_counterparty_role as ekpa
		join dds.purchase_contract_header as ekko
			on ekpa.purchase_document_code = ekko.purchase_contract_code 
	where ekpa.counterparty_role_code in ('AU', 'ER')
  	  and ekko.purchase_document_subtype_code in ('ZDAT', 'ZDC', 'ZDE', 'ZDF', 'ZDL', 'ZDP', 'ZDPR', 'ZDS', 'ZDT', 'ZDTL', 'ZDVK')
)
select
	pc.purchase_contract_code,
	pcp.position_line_item_code as purchase_contract_position_line_item_code,	
	pc.address_code,
	pc.dt_created,
	pc.dt_purchase_contract,
	pc.purchase_document_subtype_code as purchase_contract_subtype_code,
	pdtt.document_kind_name as purchase_contract_subtype_name,
	pc.unit_balance_code,
	pc.purchase_contract_name,
	pc.purchase_group_code,
	pg.purchase_group_name,
	pc.purchase_organization_code,
	pc.created_by,
	pc.release_strategy_group_code,
	pc.release_stage_code,
	pc.is_released_code,
	bt.boolean_name as is_released_name,	
	pc.release_strategy_code,
	pc.release_status_code,
	pc.purchase_contract_registration_number,
	pc.incoterms_code,
	inco.incoterms_name_rus as incoterms_name,
	pc.incoterms_location_text as incoterms_location_code,
	pc.calculation_scheme_code,
	pc.dt_valid_from as dt_purchase_contract_valid_from,
	pc.dt_valid_to as dt_purchase_contract_valid_to,
	pc.supplier_code,
	cntr3.counterparty_full_name as supplier_name,
	pc.supplier_code||'-'||coalesce(cntr3.counterparty_full_name, '') as supplier_search_name,
	pc.appendix_number as purchase_contract_appendix_number,
	pc.external_contract_number_part1 as external_contract_number,
	pc.currency_code,
	pc.terms_of_payment_code,
	pc.legal_agreement_number,
	pc.budget_type_code,
	btt.budget_type_name,
	pc.bank_account_system_code,
	pc.cost_region_code,
	crt.cost_region_name,
	pc.paydox_contract_type_code,
	payctt.paydox_contract_type_name,	
	pc.payment_date_calculation_rule_code,
	pdcrt.payment_date_calculation_rule_name,
	pc.responsibility_center_code,
	pc.unified_purchase_contract_code,
	pc.unified_purchase_contract_name,
	pc.dt_purchase_contract_paydox as dt_paydox_document,
	pc.paydox_document_type_code,
	pc.paydox_registration_number,
	pc.paydox_document_code,
	pc.paydox_document_name,
	pc.paydox_unit_balance_code,
	pc.paydox_document_status_code,
	pdst.paydox_document_status_name,
	pc.paydox_document_status_code||'-'||pdst.paydox_document_status_name as paydox_document_status_search_name,
	pc.paydox_document_url,
	pdcr1.personnel_code as contract_supervisor_code,     	
	trim( coalesce(pa021.last_name||' ', '') ||
		  coalesce(pa021.first_name||' ', '') ||
		  coalesce(pa021.middle_name, '') ) as contract_supervisor_name,
	pdcr1.personnel_code||'-'||
		trim( coalesce(pa021.last_name||' ', '') ||
		      coalesce(pa021.first_name||' ', '') ||
		      coalesce(pa021.middle_name, '') ) as contract_supervisor_search_name,	
	pdcr2.personnel_code as responsible_person_code,
	trim( coalesce(pa022.last_name||' ', '') ||
		  coalesce(pa022.first_name||' ', '') ||
		  coalesce(pa022.middle_name, '') ) as responsible_person_name,
	pdcr2.personnel_code||'-'||
		trim( coalesce(pa022.last_name||' ', '') ||
		  	  coalesce(pa022.first_name||' ', '') ||
		      coalesce(pa022.middle_name, '') ) as responsible_person_search_name,	
	pcp.price_uom_code as purchase_contract_price_uom_code,
	pcp.financial_position_code,
	pcp.funds_center_code,
	pcp.fund_code,
	pcp.weight_uom_code,
	pcp.expense_assignment_type_code,
	pcp.base_uom_code,
	pcp.is_deleted,
	pcp.material_code,
	mt.material_name,
	pcp.uom_code as purchase_order_uom_code,
	pcp.quantity as purchase_order_quantity,
	pcp.vat_code,
	pcp.plant_code,
	pl.plant_full_name as plant_name,
	pcp.vessel_port_call_code,
	vpct.vessel_port_call_name,
	pcp.vehicle_length_type_code,
	vltt.vehicle_length_type_name,
	pcp.booking_number,
	pcp.bunker_adjustment_tariff_calculation_rule_code,
	pcp.tariff_calculation_weight_to,
	pcp.tariff_calculation_weight_from,
	pcp.package_type_code,
	ptt.package_type_name,
	pcp.tariff_calculation_weekday_type_code,
	tcwtt.tariff_calculation_weekday_type_name,
	pcp.etsng_code,
	et.etsng_name_rus as etsng_name,
	pcp.etsng_previous_code,
	et_prev.etsng_name_rus as etsng_previous_name,
	pcp.shape_code,
	mst.material_shape_full_name as shape_name,
	pcp.tariff_calculation_rule_code,
	pcp.freight_movement_method_code,
	coalesce(fmmt.freight_movement_method_name, pcp.freight_movement_method_code) as freight_movement_method_name,
	pcp.fuel_grade_code,
	pcp.counterparty_code,
	cntr1.counterparty_full_name as counterparty_name,
	pcp.counterparty_code||'-'||coalesce(cntr1.counterparty_full_name, '') as counterparty_search_name,
	pcp.vessel_crane_code,
	vct.vessel_crane_name,
	pcp.container_length_type_code,
	cltt.container_length_type_name,
	pcp.railcar_owner_code,
	cntr2.counterparty_full_name as railcar_owner_name,
	pcp.railcar_owner_code||'-'||coalesce(cntr2.counterparty_full_name, '') as railcar_owner_search_name,	
	pcp.sea_forwarder_code,
	cntr4.counterparty_full_name as sea_forwarder_name,
	pcp.sea_forwarder_code||'-'||coalesce(cntr4.counterparty_full_name, '') as sea_forwarder_search_name,
	pcp.material_reporting_group_code,
	pcp.movement_scheme_code,
	msct.movement_scheme_name,
	pcp.container_ownership_type_code,
	cott1.container_ownership_type_name,
	pcp.platform_ownership_type_code,
	cott2.container_ownership_type_name as platform_ownership_type_name,
	pcp.redirection_type_code,
	rtt.redirection_type_name,
	pcp.export_method_code,
	emt.export_method_name,
	pcp.route_code,
	tr1.transport_route_name_rus as route_name,
	pcp.sea_route_code,
	tr2.transport_route_name_rus as sea_route_name,	
	pcp.transport_type_code,
	ttt.transport_transfer_type_name_rus as transport_type_name,
	pcp.transport_previous_type_code,
	ttt_prev.transport_transfer_type_name_rus as transport_previous_type_name,
	pcp.railway_platform_completeness_type_code,
	rpctt.railway_platform_completeness_type_name,
	pcp.material_reporting_type_code,
	pcp.service_code,
	sacd.service_dsc as service_name,
	pcp.service_code||'-'||sacd.service_dsc as service_search_name,
	pcp.railway_station_code,
	thrs.transport_hub_name_rus as railway_station_name,
	pcp.container_pickup_transport_hub_code,
	thcp.transport_hub_name_rus as container_pickup_transport_hub_name,
	coalesce(pcp.terminal_code, pc.terminal_code) as terminal_code,
	case when pcp.terminal_code is not null
			then thtr1.transport_hub_name_rus 
		 else thtr2.transport_hub_name_rus
		 end as terminal_name,
	case when pcp.terminal_code is not null 
			then pcp.terminal_code||'-'||thtr1.transport_hub_name_rus 
		 else pc.terminal_code||'-'||thtr2.transport_hub_name_rus
		 end as terminal_search_name, 
	coalesce(pcp.port_code, pc.port_code) as port_code,
	case when pcp.port_code is not null
			then thpr1.transport_hub_name_rus 
		 else thpr2.transport_hub_name_rus
		 end as port_name,
	case when pcp.port_code is not null
			then pcp.port_code||'-'||thpr1.transport_hub_name_rus 
		 else pc.port_code||'-'||thpr2.transport_hub_name_rus
		 end as port_search_name,
	pcp.package_subtype_code,
	pst.package_subtype_name,
	pcp.transport_subtype_code,
	pcp.service_type_code,
	stt.service_type_name,
	pcp.service_type_code||'-'||stt.service_type_name as service_type_search_name,	
	pcp.import_method_code,
	imt.import_method_name,
	pcp.vessel_code,
	pcp.vehicle_detail_type_code,
	pcp.shipment_type_code,
	coalesce(addr1_1.country_code, addr2_1.country_code) as country_of_departure_hub_code,
	coalesce(addr2_2.country_code, addr1_2.country_code) as country_of_destination_hub_code,
	pcpc.price_condition_code as condition_record_code,
	pcpc.price_condition_uom_code as uom_code,
	pcpc.price_rate,
	pcpc.price_scale_basis_code,
	psbt.price_scale_basis_name,
	pcpc.is_price_condition_position_deleted_code as condition_deleted_flag_code,
	case when pcpc.is_price_condition_position_deleted_code is not null 
	       then 'Позиция удалена' 
	     end as condition_deleted_flag_name,
	pcpc.price_scale_limit_from_quantity as price_scale_quantity,
	pcpc.price_scale_rate,
	pc.total_purchase_contract_cost_document_currency_amount as purchase_contract_document_currency_amount,
	pc.purchase_contract_available_limit_doc_currency_amount,
	case when pc.total_purchase_contract_cost_document_currency_amount <> 0.00
	     then pc.total_purchase_contract_cost_document_currency_amount -
	          coalesce(pc.purchase_contract_available_limit_doc_currency_amount, 0)
	     else null
	end as purchase_contract_payed_document_currency_amount,
	case when pc.total_purchase_contract_cost_document_currency_amount <> 0.00
	     then (pc.total_purchase_contract_cost_document_currency_amount -
	           coalesce(pc.purchase_contract_available_limit_doc_currency_amount, 0)) * 100 /
	          pc.total_purchase_contract_cost_document_currency_amount
	     else null
	end as purchase_contract_payed_document_currency_percentage
-----------------данные из транзакционных таблиц--------------------------------------------------------------------------------------------------------------
from dds.purchase_contract_header as pc
	left join dds.purchase_contract_position as pcp
		on pcp.purchase_contract_code = pc.purchase_contract_code
	left join dds.purchase_contract_price_conditions as pcpc
		on pcpc.purchase_contract_code = pcp.purchase_contract_code and 
		   pcpc.purchase_contract_position_code = pcp.position_line_item_code and 
		   pcpc.price_condition_type_code = 'PB00'
	left join counterparty_role as pdcr1
		on pdcr1.purchase_document_code = pc.purchase_contract_code and
		   pdcr1.counterparty_role_code = 'AU' and
		   pdcr1.consecutive_number = pdcr1.last_consecutive_number
	left join counterparty_role as pdcr2
		on pdcr2.purchase_document_code = pc.purchase_contract_code and 
		   pdcr2.counterparty_role_code = 'ER' and
		   pdcr2.consecutive_number = pdcr2.last_consecutive_number
----------------справочники-----------------------------------------------------------------------------------------------------------------------------------	   
	left join dict_dds.employee_main_data as pa021
		on pa021.employee_code = pdcr1.personnel_code and 
		   pa021.dt_valid_to >= current_date and
		   pa021.dt_valid_from <= current_date
	left join dict_dds.employee_main_data as pa022
		on pa022.employee_code = pdcr2.personnel_code and
		   pa022.dt_valid_to >= current_date and
		   pa022.dt_valid_from <= current_date
	left join dict_dds.material_texts as mt 							
		on mt.material_code = pcp.material_code and 
		   mt.language_code = 'R'	   
	left join dict_dds.etsng as et 
		on et.etsng_code = pcp.etsng_code
	left join dict_dds.etsng as et_prev 
		on et_prev.etsng_code = pcp.etsng_previous_code	
	left join dict_dds.material_shape_texts as mst 
		on mst.shape_code = pcp.shape_code and 
		   mst.language_code = 'R'
	left join dict_dds.purchase_group as pg
		on pg.purchase_group_code = pc.purchase_group_code
	left join dict_dds.transport_hub as thrs
		on thrs.transport_hub_code = pcp.railway_station_code
	left join dict_dds.transport_hub as thcp
		on thcp.transport_hub_code = pcp.container_pickup_transport_hub_code
	left join dict_dds.transport_hub as thtr1
		on thtr1.transport_hub_code = pcp.terminal_code	
	left join dict_dds.transport_hub as thtr2
		on thtr2.transport_hub_code = pc.terminal_code
	left join dict_dds.transport_hub as thpr1
		on thpr1.transport_hub_code = pcp.port_code	
	left join dict_dds.transport_hub as thpr2
		on thpr2.transport_hub_code = pc.port_code		
	left join dict_dds.transport_transfer_type as ttt 
		on ttt.transport_transfer_type_code = pcp.transport_type_code		
	left join dict_dds.transport_transfer_type as ttt_prev
		on ttt_prev.transport_transfer_type_code = pcp.transport_previous_type_code
	left join dict_dds.transport_route as tr1 
		on tr1.transport_route_code = pcp.route_code
	left join dict_dds.transport_hub as th1_1
		on th1_1.transport_hub_code = tr1.transport_route_departure_hub_code 
	left join dict_dds.address as addr1_1
		on addr1_1.address_code = th1_1.address_code and 
		   addr1_1.international_display_format_code is null		
	left join dict_dds.transport_hub as th1_2
		on th1_2.transport_hub_code = tr1.transport_route_destination_hub_code
	left join dict_dds.address as addr1_2
		on addr1_2.address_code = th1_2.address_code and 
		   addr1_2.international_display_format_code is null					
	left join dict_dds.transport_route as tr2
		on tr2.transport_route_code = pcp.sea_route_code
	left join dict_dds.transport_hub as th2_1
		on th2_1.transport_hub_code = tr2.transport_route_departure_hub_code 
	left join dict_dds.address as addr2_1
		on addr2_1.address_code = th2_1.address_code and 
		   addr2_1.international_display_format_code is null		
	left join dict_dds.transport_hub as th2_2
		on th2_2.transport_hub_code = tr2.transport_route_destination_hub_code
	left join dict_dds.address as addr2_2
		on addr2_2.address_code = th2_2.address_code and 
		   addr2_2.international_display_format_code is null	
	left join dict_dds.purchase_document_type_texts as pdtt
		on pdtt.document_kind_code = pc.purchase_document_subtype_code and 
		   pdtt.document_type_code = 'K' and 
		   pdtt.language_code = 'R'
	left join dict_dds.incoterms as inco 
		on inco.incoterms_code = pc.incoterms_code
	left join dict_dds.service_assessment_class_dsc as sacd
		on sacd.service_nbr = pcp.service_code and 
		   sacd.lang_code = 'R'
	left join dict_dds.plant_and_subsidiary as pl
		on pl.plant_code = pcp.plant_code
	left join dict_dds.counterparty as cntr1
		on cntr1.counterparty_code = pcp.counterparty_code
	left join dict_dds.counterparty as cntr2
		on cntr2.counterparty_code = pcp.railcar_owner_code
	left join dict_dds.counterparty as cntr3
		on cntr3.counterparty_code = pc.supplier_code
	left join dict_dds.counterparty as cntr4
		on cntr4.counterparty_code = pcp.sea_forwarder_code
	left join dict_dds.boolean_texts as bt
		on bt.boolean_code = pc.is_released_code and
		   bt.language_code = 'R'
	left join dict_dds.budget_type_texts as btt
		on btt.budget_type_code = pc.budget_type_code and 
	       btt.language_code = 'R'	   
	left join dict_dds.cost_region_texts as crt 
		on crt.cost_region_code = pc.cost_region_code and 
		   crt.language_code = 'R'
	left join dict_dds.payment_date_calculation_rule_texts as pdcrt
		on pdcrt.payment_date_calculation_rule_code = pc.payment_date_calculation_rule_code and 
		   pdcrt.language_code = 'R'
	left join dict_dds.vessel_port_call_texts as vpct
		on vpct.vessel_port_call_code = pcp.vessel_port_call_code and 
		   vpct.language_code = 'R'
	left join dict_dds.vehicle_length_type_texts as vltt
		on vltt.vehicle_length_type_code = pcp.vehicle_length_type_code and 
		   vltt.language_code = 'R'
	left join dict_dds.package_type_texts as ptt 
		on ptt.package_type_code = pcp.package_type_code and 
		   ptt.language_code = 'R'
	left join dict_dds.tariff_calculation_weekday_type_texts as tcwtt
		on tcwtt.tariff_calculation_weekday_type_code = pcp.tariff_calculation_weekday_type_code and 
		   tcwtt.language_code = 'R'
	left join dict_dds.freight_movement_method_texts as fmmt
		on fmmt.freight_movement_method_code = pcp.freight_movement_method_code and
		   fmmt.language_code = 'R'
	left join dict_dds.vessel_crane_texts as vct
		on vct.vessel_crane_code = pcp.vessel_crane_code and 
		   vct.language_code = 'R'
	left join dict_dds.container_length_type_texts as cltt
		on cltt.container_length_type_code = pcp.container_length_type_code and 
		   cltt.language_code = 'R'
	left join dict_dds.movement_scheme_texts as msct
		on msct.movement_scheme_code = pcp.movement_scheme_code and 
		   msct.language_code = 'R'
	left join dict_dds.container_ownership_type_texts as cott1
		on cott1.container_ownership_type_code = pcp.container_ownership_type_code and 
		   cott1.language_code = 'R'
	left join dict_dds.container_ownership_type_texts as cott2
		on cott2.container_ownership_type_code = pcp.platform_ownership_type_code and 
		   cott2.language_code = 'R'
	left join dict_dds.redirection_type_texts as rtt
		on rtt.redirection_type_code = pcp.redirection_type_code and
		   rtt.language_code = 'R'
	left join dict_dds.export_method_texts as emt 
		on emt.export_method_code = pcp.export_method_code and 
		   emt.language_code = 'R'
	left join dict_dds.railway_platform_completeness_type_texts as rpctt
		on rpctt.railway_platform_completeness_type_code = pcp.railway_platform_completeness_type_code and 
		   rpctt.language_code = 'R'
	left join dict_dds.package_subtype_texts as pst
		on pst.package_subtype_code = pcp.package_subtype_code and 
		   pst.language_code = 'R'
	left join dict_dds.service_type_texts as stt
		on stt.service_type_code = pcp.service_type_code and 
		   stt.language_code = 'R'
	left join dict_dds.import_method_texts as imt
		on imt.import_method_code = pcp.import_method_code and 
		   imt.language_code = 'R'
	left join dict_dds.price_scale_basis_texts as psbt 
		on psbt.price_scale_basis_code = pcpc.price_scale_basis_code and 
		   psbt.language_code = 'R'
	left join dict_dds.paydox_contract_type_texts as payctt
		on payctt.paydox_contract_type_code = pc.paydox_contract_type_code and 
		   payctt.language_code = 'R'
	left join dict_dds.paydox_document_status_texts as pdst
		on pdst.paydox_document_status_code = pc.paydox_document_status_code and
		   pdst.language_code = 'R'
where pc.purchase_document_subtype_code in ('ZDAT', 'ZDC', 'ZDE', 'ZDF', 'ZDL', 'ZDP', 'ZDPR', 'ZDS', 'ZDT', 'ZDTL', 'ZDVK') 
  and pcp.is_deleted is null
  and pcpc.is_price_condition_position_deleted_code is null;