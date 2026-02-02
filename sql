with vbrk as (
select
	t.unit_balance_code,
	t.asset_main_code,
	t.payee_or_payer_code as buyer_code,
	t.personnel_code as realization_supervisor_code,
	t.document_currency_vat_excluded_amount as realization_document_currency_amount,
	t.document_currency_code as realization_document_currency_code,
	t.wbs_element_code
from
	(
	select
		ir.payee_or_payer_code,
		ir.invoice_realization_code,
		sum(irp.document_currency_vat_excluded_amount) over (partition by irp.material_code, ir.invoice_realization_code) as document_currency_vat_excluded_amount,
		irp.document_currency_code,
		sdcr.personnel_code,
		rf.unit_balance_code as unit_balance_code,
		sales.wbs_element_code, 
		substring(irp.material_code, 3) as asset_main_code,
		row_number() over (partition by irp.material_code
	order by
		ir.dt_billing_document desc
	) as rnum
	from
		dds.invoice_realization as ir
	left join dds.invoice_realization_position as irp on
		ir.invoice_realization_code = irp.invoice_realization_code
	left join dds.sales_document_counterparty_role as sdcr on
		sdcr.sales_document_code = irp.sales_document_code
		and (sdcr.sales_document_position_code = irp.sales_document_position_code
			or sdcr.sales_document_position_code = '000000')
		and sdcr.counterparty_role_code = 'VE'
	left join dict_dds.unit_balance as rf on
		rf.fixed_asset_material_prefix_code = left(irp.material_code, 2)
	left join (
			select
			sales_contract_code as sales_document_code,
			sales_contract_non_liquid_wbs_element_code as wbs_element_code
		from
			dds.sales_contract_header
	union all
		select
			sales_order_code as sales_document_code,
			sales_order_non_liquid_wbs_element_code as wbs_element_code
		from
			dds.sales_order_header
	union all
		select
			sales_proposal_code as sales_document_code,
			sales_proposal_non_liquid_wbs_element_code as wbs_element_code
		from
			dds.sales_proposal_header
) sales on
		irp.sales_document_code = sales.sales_document_code
	where
		irp.sales_document_position_type_code in ('ZAOS', 'ZAKT')) as t
where
	t.rnum = 1
	and t.unit_balance_code is not null) 
select 
	fam.unit_balance_code,
	fam.unit_balance_name,
	fam.asset_main_code,
	fam.asset_sub_code,
	fam.valuation_area_code,
	fam.valuation_area_name,
	fam.valuation_area_currency_code,
	fam.valuation_area_currency_name,
	fam.asset_depreciation_rule_code,
	fam.asset_depreciation_rule_name,
	fam.asset_class_code,
	fam.asset_class_name,
	fam.asset_inventory_number,
	fam.asset_name,
	fa.dt_depreciation_posting_yyyy,
	fa.asset_position_code,
	fa.depreciation_posting_internal_code,
	fa.asset_movement_type_or_depreciation_calculation_code,
	fa.dt_posting,
	fa.depreciation_internal_order_code,
	ord.order_short_name as depreciation_internal_order_name,
	fa.dt_depreciation_posting_mmm,
	fa.dt_reference,
	fa.business_transaction_code,
	fa.reference_operation_code,
	fa.reference_organization_unit_code,
	fa.is_virtual_asset_movement,
	fa.reference_asset_main_code,
	fa.reference_asset_sub_code,
	fa.general_ledger_operation_type_code,
	fa.dt_asset_document_created,
	fa.asset_movement_type_code,
	mtt.fixed_asset_movement_type_name as asset_movement_type_name,
	fa.red_reverse_code,
	fa.red_reverse_reason_code,
	fa.dt_red_reverse,
	fa.asset_realization_revenue_amount,
	fa.proportional_cumulative_revaluation_amount,
	fam.base_uom_code,
	fam.base_uom_name,
	fam.asset_quantity,	
	fam.cost_center_code,
	fam.cost_center_name,
	fa.depreciation_cost_center_code,
	cc.cost_center_name_rus as depreciation_cost_center_name, 
	fam.plant_code,
	fam.plant_name,  
	fam.is_asset_conservated,
	fam.dt_conservated_from, 
	fam.dt_conservated_to, 
	fam.dt_conservated_actual,
	fam.document_type_code,
	fam.document_type_name,
	fam.special_order_for_conservation_number,
	fam.dt_special_order_for_conservation,
	fam.special_order_for_cancelling_conservation_number,
	fam.dt_special_order_for_cancelling_conservation,
	fam.dt_conservation_cancelled_actual,
	fam.dt_approved_of_techical_state,
	fam.non_liquid_asset_techical_state_code,
	fam.non_liquid_asset_techical_state_name,
	fam.is_non_liquid_asset_record_created_manually,
	fam.dt_asset_status_reverse_from_non_liquid,
	fa.non_liquid_asset_type_code,
	fa.non_liquid_asset_type_name,
	fam.dt_asset_recognized,
	fam.dt_asset_write_off,
	fa.disposal_type_source_name,
	fa.disposal_type_code,
	dtt.disposal_type_name,
	fa.valuation_area_currency_amount,
	fa.acquisition_cost_valuation_area_currency_amount,
	fa.depreciation_typical_amount + fa.depreciation_special_amount + fa.depreciation_unplanned_amount as depreciation_total_amount,
	fa.depreciation_typical_amount,
	fa.depreciation_special_amount,
	fa.depreciation_unplanned_amount,
	fa.cumulative_acquisition_and_production_cost_amount,
	fa.cumulative_depreciation_typical_amount,
	fa.cumulative_depreciation_special_amount,
	fa.cumulative_depreciation_unplanned_amount,
	v.buyer_code,
	c.counterparty_full_name as buyer_name,
	v.wbs_element_code,
	v.realization_supervisor_code,
	p.employee_full_name as realization_supervisor_name,
	v.realization_document_currency_amount,
	v.realization_document_currency_code
from (
	select 	
		unit_balance_code,
		dt_depreciation_posting_mmm, 
		depreciation_posting_internal_code, 
		asset_main_code,
		asset_sub_code,
		reference_asset_main_code,
		reference_asset_sub_code,
		dt_posting_yyyy as dt_depreciation_posting_yyyy,
		valuation_area_code,
		depreciation_internal_order_code,
		asset_position_code,
		dt_posting::date,
		dt_reference,
		business_transaction_code,
		reference_operation_code,
		reference_organization_unit_code,
		general_ledger_operation_type_code,
		dt_asset_document_created,
		asset_movement_type_code,		
		red_reverse_reason_code,
		dt_red_reverse,
		red_reverse_code,
		is_virtual_asset_movement,	
		depreciation_cost_center_code,
		depreciation_typical_amount,
		depreciation_special_amount,
		valuation_area_currency_amount,
		acquisition_cost_valuation_area_currency_amount,
		proportional_cumulative_revaluation_amount,
	   	asset_realization_revenue_amount,
		depreciation_unplanned_amount,  
		cumulative_acquisition_and_production_cost_amount,
		cumulative_depreciation_typical_amount,
		cumulative_depreciation_special_amount,
		cumulative_depreciation_unplanned_amount,
		valuation_area_currency_code,
		asset_movement_type_or_depreciation_calculation_code,
		case when parameter_code = 'BWASL_L' then 'Ликвидация'
		when parameter_code = 'BWASL_SE' then 'Внешняя продажа'
		when parameter_code = 'BWASL_SI' then 'Внутренняя продажа'
		when parameter_code = 'BWASL_TR' then 'Безвозмездная передача'
		end as  disposal_type_source_name,
		case when parameter_code = 'BWASL_L' then '3'
		when parameter_code = 'BWASL_SE' then '5'
		when parameter_code = 'BWASL_SI' then '8'
		when parameter_code = 'BWASL_TR' then '1'
		end as  disposal_type_code,
		'A'	as non_liquid_asset_type_code,
		'Основные средства' as non_liquid_asset_type_name
from 
	dm_calc.fixed_asset_operations
left join dict_dds.settings_and_parameters_sap sap on
	asset_movement_type_code between sap.range_low_value and coalesce(sap.range_high_value,sap.range_low_value)
	and sap.abap_program_code = 'ZFI5668M'
	and sap.range_sign_code is not null
where dt_posting >= date_trunc('year', now()- interval '1 year')::date
and is_anlc is null

union all

select 
	unit_balance_code,
	null as dt_depreciation_posting_mmm, 
	null as depreciation_posting_internal_code, 
	asset_main_code,
	asset_sub_code,
	null as reference_asset_main_code,
	null as reference_asset_sub_code,
	null  as dt_depreciation_posting_yyyy,
	valuation_area_code,
	null  as depreciation_internal_order_code,
	null  as asset_position_code,
	dt_lend_lease_posting as dt_posting,
	dt_lend_lease_posting as dt_reference,
	null  as business_transaction_code,
	null  as reference_operation_code,
	null  as reference_organization_unit_code,
	null  as general_ledger_operation_type_code,
	null  as dt_asset_document_created,
	null  as asset_movement_type_code,
	null  as red_reverse_reason_code,
	null  as dt_red_reverse,
	null  as red_reverse_code,
	null  as is_virtual_asset_movement,
	null  as depreciation_cost_center_code,
	depreciation_typical_amount,
	depreciation_special_amount,
	valuation_area_currency_amount,
	acquisition_cost_valuation_area_currency_amount,
	null as proportional_cumulative_revaluation_amount,
   	null as asset_realization_revenue_amount,
	depreciation_unplanned_amount,  
	null as cumulative_acquisition_and_production_cost_amount,
	null as cumulative_depreciation_typical_amount,
	null as cumulative_depreciation_special_amount,
	null as cumulative_depreciation_unplanned_amount,
	valuation_area_currency_code,
	'ZANLU_TRENT' as asset_movement_type_or_depreciation_calculation_code,
	'Передача в аренду' as  disposal_type_source_name,
	'7' as  disposal_type_code,
	non_liquid_asset_type_code,
	non_liquid_asset_type_name
	from 
(
select 	
	cd.unit_balance_code,
	cd.asset_main_code,
	cd.asset_sub_code,
	cd.valuation_area_code,
	ll.dt_lend_lease_posting,
	cd.depreciation_total_cumulative_amount as depreciation_typical_amount,
	cd.depreciation_special_cumulative_amount as depreciation_special_amount,
	cd.acquisition_cost_cumulative_amount as valuation_area_currency_amount,
	cd.acquisition_cost_cumulative_amount as acquisition_cost_valuation_area_currency_amount,
	depreciation_unplanned_cumulative_amount as depreciation_unplanned_amount,
	cd.valuation_area_currency_code,
	cd.non_liquid_asset_type_code,
	cd.non_liquid_asset_type_name,
	row_number() over (partition by cd.unit_balance_code,
						cd.asset_main_code,
						cd.asset_sub_code,
						cd.valuation_area_code
					order by
						dt_report desc) as rn
from
	dm.fixed_asset_cost_and_depreciation cd
join dict_dds.fixed_asset_lend_lease ll on
	ll.unit_balance_code = cd.unit_balance_code
	and ll.asset_main_code = cd.asset_main_code
	and ll.asset_sub_code = cd.asset_sub_code
	and cd.dt_report <= ll.dt_lend_lease_posting
where 
	dt_report >= date_trunc('year', now()- interval '1 year')::date	
) t	
where 
rn = 1  )fa
---встречались 15.12 с владельцем продуктаа, договорились брать inner join 
---чтобы нивелировать  раассинхрон  по  времени загрузки транзакционных и спарвочных данных
join  dm.fixed_asset_main fam on 
	fa.unit_balance_code = fam.unit_balance_code
	and fa.asset_main_code = fam.asset_main_code
	and fa.asset_sub_code = fam.asset_sub_code
	and fa.valuation_area_code = fam.valuation_area_code
	and fa.dt_posting between fam.dt_valid_from and fam.dt_valid_to
left join dict_dds.disposal_type_texts dtt on 
	fa.disposal_type_code = dtt.disposal_type_code
	and language_code = 'R'
left join vbrk v on 	
	v.unit_balance_code = fa.unit_balance_code
	and	v.asset_main_code = fa.asset_main_code 
left join dict_dds.counterparty c on 
	c.counterparty_code = v.buyer_code
left join dict_dds.personnel_main_data p on p.
	employee_code = v.realization_supervisor_code
	and fa.dt_posting between p.dt_valid_from and p.dt_valid_to
left join dict_dds.order_controlling ord on
	fa.depreciation_internal_order_code = ord.order_code
left join dict_dds.cost_center cc on		
	 fa.depreciation_cost_center_code = cc.cost_center_code
	and fa.dt_posting between cc.dt_valid_from and cc.dt_valid_to	
left join dict_dds.fixed_asset_movement_type_texts mtt on
	fa.asset_movement_type_code = mtt.fixed_asset_movement_type_code
	and mtt.language_code = 'R';



2
with vbrk as (
select
	t.unit_balance_code,
	t.asset_main_code,
	t.payee_or_payer_code as buyer_code,
	t.personnel_code as realization_supervisor_code,
	t.document_currency_vat_excluded_amount as realization_document_currency_amount,
	t.document_currency_code as realization_document_currency_code
from
	(
	select
		ir.payee_or_payer_code,
		irp.document_currency_vat_excluded_amount,
		irp.document_currency_code,
		sdcr.personnel_code,
		rf.unit_balance_code as unit_balance_code,
		substring(irp.material_code, 3) as asset_main_code,
		row_number() over (partition by irp.material_code  order by ir.invoice_realization_code desc,ir.dt_billing_document desc
	) as rnum
	from
		dds.invoice_realization as ir
	left join dds.invoice_realization_position as irp on
		ir.invoice_realization_code = irp.invoice_realization_code
	left join dds.sales_document_counterparty_role as sdcr on
		sdcr.sales_document_code = irp.sales_document_code
		and (sdcr.sales_document_position_code = irp.sales_document_position_code
			or sdcr.sales_document_position_code = '000000')
		and sdcr.counterparty_role_code = 'VE'
	left join dict_dds.unit_balance as rf on
		rf.fixed_asset_material_prefix_code = left(irp.material_code, 2)
	where
		irp.sales_document_position_type_code in ('ZAOS', 'ZAKT')) as t
where
	t.rnum = 1
	and t.unit_balance_code is not null)
select 
	fam.unit_balance_code,
	fam.unit_balance_name,
	fam.asset_main_code,
	fam.asset_sub_code,
	fam.valuation_area_code,
	fam.valuation_area_name,
	fam.valuation_area_currency_code,
	fam.valuation_area_currency_name,
	fam.asset_depreciation_rule_code,
	fam.asset_depreciation_rule_name,
	fam.asset_class_code,
	fam.asset_class_name,
	fam.asset_inventory_number,
	fam.asset_name,
	fa.dt_depreciation_posting_yyyy,
	fa.asset_position_code,
	fa.depreciation_posting_internal_code,
	fa.asset_movement_type_or_depreciation_calculation_code,
	fa.dt_posting,
	fa.depreciation_internal_order_code,
	ord.order_short_name as depreciation_internal_order_name,
	fa.dt_depreciation_posting_mmm,
	fa.dt_reference,
	fa.business_transaction_code,
	fa.reference_operation_code,
	fa.reference_organization_unit_code,
	fa.is_virtual_asset_movement,
	fa.reference_asset_main_code,
	fa.reference_asset_sub_code,
	fa.general_ledger_operation_type_code,
	fa.dt_asset_document_created,
	fa.asset_movement_type_code,
	mtt.fixed_asset_movement_type_name as asset_movement_type_name,
	fa.red_reverse_code,
	fa.red_reverse_reason_code,
	fa.dt_red_reverse,
	fa.asset_realization_revenue_amount,
	fa.proportional_cumulative_revaluation_amount,
	fam.base_uom_code,
	fam.base_uom_name,
	fam.asset_quantity,	
	fam.cost_center_code,
	fam.cost_center_name,
	fa.depreciation_cost_center_code,
	cc.cost_center_name_rus as depreciation_cost_center_name, 
	fam.plant_code,
	fam.plant_name,  
	fam.is_asset_conservated,
	fam.dt_conservated_from, 
	fam.dt_conservated_to, 
	fam.dt_conservated_actual,
	fam.document_type_code,
	fam.document_type_name,
	fam.special_order_for_conservation_number,
	fam.dt_special_order_for_conservation,
	fam.special_order_for_cancelling_conservation_number,
	fam.dt_special_order_for_cancelling_conservation,
	fam.dt_conservation_cancelled_actual,
	fam.dt_approved_of_techical_state,
	fam.non_liquid_asset_techical_state_code,
	fam.non_liquid_asset_techical_state_name,
	fam.is_non_liquid_asset_record_created_manually,
	fam.dt_asset_status_reverse_from_non_liquid,
	fa.non_liquid_asset_type_code,
	fa.non_liquid_asset_type_name,
	fam.dt_asset_recognized,
	fam.dt_asset_write_off,
	fa.disposal_type_source_name,
	fa.disposal_type_code,
	dtt.disposal_type_name,
	fa.valuation_area_currency_amount,
	fa.acquisition_cost_valuation_area_currency_amount,
	fa.depreciation_typical_amount + fa.depreciation_special_amount + fa.depreciation_unplanned_amount as depreciation_total_amount,
	fa.depreciation_typical_amount,
	fa.depreciation_special_amount,
	fa.depreciation_unplanned_amount,
	fa.cumulative_acquisition_and_production_cost_amount,
	fa.cumulative_depreciation_typical_amount,
	fa.cumulative_depreciation_special_amount,
	fa.cumulative_depreciation_unplanned_amount,
	v.buyer_code,
	c.counterparty_full_name as buyer_name,
	v.realization_supervisor_code,
	p.employee_full_name as realization_supervisor_name,
	v.realization_document_currency_amount,
	v.realization_document_currency_code
from (


	select 	
		unit_balance_code,
		dt_depreciation_posting_mmm, 
		depreciation_posting_internal_code, 
		asset_main_code,
		asset_sub_code,
		reference_asset_main_code,
		reference_asset_sub_code,
		dt_posting_yyyy as dt_depreciation_posting_yyyy,
		valuation_area_code,
		depreciation_internal_order_code,
		asset_position_code,
		dt_posting::date,
		dt_reference,
		business_transaction_code,
		reference_operation_code,
		reference_organization_unit_code,
		general_ledger_operation_type_code,
		dt_asset_document_created,
		asset_movement_type_code,		
		red_reverse_reason_code,
		dt_red_reverse,
		red_reverse_code,
		is_virtual_asset_movement,	
		depreciation_cost_center_code,
		depreciation_typical_amount,
		depreciation_special_amount,
		valuation_area_currency_amount,
		acquisition_cost_valuation_area_currency_amount,
		proportional_cumulative_revaluation_amount,
	   	asset_realization_revenue_amount,
		depreciation_unplanned_amount,  
		cumulative_acquisition_and_production_cost_amount,
		cumulative_depreciation_typical_amount,
		cumulative_depreciation_special_amount,
		cumulative_depreciation_unplanned_amount,
		valuation_area_currency_code,
		asset_movement_type_or_depreciation_calculation_code,
		case when parameter_code = 'BWASL_L' then 'Ликвидация'
		when parameter_code = 'BWASL_SE' then 'Внешняя продажа'
		when parameter_code = 'BWASL_SI' then 'Внутренняя продажа'
		when parameter_code = 'BWASL_TR' then 'Безвозмездная передача'
		end as  disposal_type_source_name,
		case when parameter_code = 'BWASL_L' then '3'
		when parameter_code = 'BWASL_SE' then '5'
		when parameter_code = 'BWASL_SI' then '8'
		when parameter_code = 'BWASL_TR' then '1'
		end as  disposal_type_code,
		'A'	as non_liquid_asset_type_code,
		'Основные средства' as non_liquid_asset_type_name
from 
	dm_calc.fixed_asset_operations
left join dict_dds.settings_and_parameters_sap sap on
	sap.range_low_value = asset_movement_type_code
	and sap.abap_program_code = 'ZFI5668M'
	and sap.range_sign_code is not null
	and is_anlc is null
where dt_posting >= date_trunc('year', now()- interval '1 year')::date

union all

select 
	unit_balance_code,
	null as dt_depreciation_posting_mmm, 
	null as depreciation_posting_internal_code, 
	asset_main_code,
	asset_sub_code,
	null as reference_asset_main_code,
	null as reference_asset_sub_code,
	null  as dt_depreciation_posting_yyyy,
	valuation_area_code,
	null  as depreciation_internal_order_code,
	null  as asset_position_code,
	dt_lend_lease_posting as dt_posting,
	dt_lend_lease_posting as dt_reference,
	null  as business_transaction_code,
	null  as reference_operation_code,
	null  as reference_organization_unit_code,
	null  as general_ledger_operation_type_code,
	null  as dt_asset_document_created,
	null  as asset_movement_type_code,
	null  as red_reverse_reason_code,
	null  as dt_red_reverse,
	null  as red_reverse_code,
	null  as is_virtual_asset_movement,
	null  as depreciation_cost_center_code,
	depreciation_typical_amount,
	depreciation_special_amount,
	valuation_area_currency_amount,
	acquisition_cost_valuation_area_currency_amount,
	null as proportional_cumulative_revaluation_amount,
   	null as asset_realization_revenue_amount,
	depreciation_unplanned_amount,  
	null as cumulative_acquisition_and_production_cost_amount,
	null as cumulative_depreciation_typical_amount,
	null as cumulative_depreciation_special_amount,
	null as cumulative_depreciation_unplanned_amount,
	valuation_area_currency_code,
	'ZANLU_TRENT' as asset_movement_type_or_depreciation_calculation_code,
	'Передача в аренду' as  disposal_type_source_name,
	'7' as  disposal_type_code,
	non_liquid_asset_type_code,
	non_liquid_asset_type_name
	from 
(
select 	
	cd.unit_balance_code,
	cd.asset_main_code,
	cd.asset_sub_code,
	cd.valuation_area_code,
	ll.dt_lend_lease_posting,
	cd.depreciation_total_cumulative_amount as depreciation_typical_amount,
	cd.depreciation_special_cumulative_amount as depreciation_special_amount,
	cd.acquisition_cost_cumulative_amount as valuation_area_currency_amount,
	cd.acquisition_cost_cumulative_amount as acquisition_cost_valuation_area_currency_amount,
	depreciation_unplanned_cumulative_amount as depreciation_unplanned_amount,
	cd.valuation_area_currency_code,
	cd.non_liquid_asset_type_code,
	cd.non_liquid_asset_type_name,
	row_number() over (partition by cd.unit_balance_code,
						cd.asset_main_code,
						cd.asset_sub_code,
						cd.valuation_area_code
					order by
						dt_report desc) as rn
from
	dm.fixed_asset_cost_and_depreciation cd
join dict_dds.fixed_asset_lend_lease ll on
	ll.unit_balance_code = cd.unit_balance_code
	and ll.asset_main_code = cd.asset_main_code
	and ll.asset_sub_code = cd.asset_sub_code
	and cd.dt_report <= ll.dt_lend_lease_posting
where 
	dt_report >= date_trunc('year', now()- interval '1 year')::date	
) t	
where 
rn = 1  )fa
left join  dm.fixed_asset_main fam on 
	fa.unit_balance_code = fam.unit_balance_code
	and fa.asset_main_code = fam.asset_main_code
	and fa.asset_sub_code = fam.asset_sub_code
	and fa.valuation_area_code = fam.valuation_area_code
	and fa.dt_posting between fam.dt_valid_from and fam.dt_valid_to
left join dict_dds.disposal_type_texts dtt on 
	fa.disposal_type_code = dtt.disposal_type_code
	and language_code = 'R'
left join vbrk v on 	
	v.unit_balance_code = fa.unit_balance_code
	and	v.asset_main_code = fa.asset_main_code 
left join dict_dds.counterparty c on 
	c.counterparty_code = v.buyer_code
left join dict_dds.personnel_main_data p on p.
	employee_code = v.realization_supervisor_code
	and fa.dt_posting between p.dt_valid_from and p.dt_valid_to
left join dict_dds.order_controlling ord on
		fa.depreciation_internal_order_code = ord.order_code
left join dict_dds.cost_center cc on		
	 fa.depreciation_cost_center_code = cc.cost_center_code
	and fa.dt_posting between cc.dt_valid_from and cc.dt_valid_to	
left join dict_dds.fixed_asset_movement_type_texts mtt on
		fa.asset_movement_type_code = mtt.fixed_asset_movement_type_code
		and mtt.language_code = 'R'
;
