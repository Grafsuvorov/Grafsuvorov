insert into dm.investment_payments_actual
(
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		accounting_document_position_code,
		accounting_document_type_code,
		payment_document_unit_balance_code,
		payment_document_fiscal_year,
		payment_document_code,
		dt_posting,
		payment_request_position_code,
		purchase_document_code,
		purchase_document_position_code,
		reservation_document_code,
		reservation_document_position_code,
		reservation_document_reference_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		external_contract_number,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		investment_project_external_code,
		controlling_order_code,
		document_exchange_to_usd_rate,
		vat_code,
		vat_rate,
		document_currency_amount,
		document_currency_code,
		vat_payment_document_currency_amount,
		exclude_vat_payment_document_currency_amount,		
		document_usd_currency_amount,
		vat_payment_usd_currency_amount,
		exclude_vat_payment_usd_currency_amount,
		capitalization_code,
		capitalization_percent,
		budget_group_code,
		reverse_document_code,
		reverse_document_fiscal_year,
		dt_posting_reverse_document,
		plant_code,
		is_agent_payment,
		currency_iso_code,
		cost_element_name,
		correspondence_general_ledger_account_name,
		material_name,
		creditor_name,
		wbs_element_name,
		investment_project_name,
		controlling_order_name,
		plant_name,
		investment_activity_external_code,
		investment_budget_section_code,
	    investment_budget_section_name,
	    investment_budget_subsection_code,
	    investment_budget_subsection_name,
		division_code,
	    division_name,
		investment_budget_section_actual_code,
		investment_budget_section_actual_name,
		investment_budget_subsection_actual_code,
		investment_budget_subsection_actual_name,
		investment_program_code,
		investment_program_name,	
		wbs_element_unit_balance_code,
		budget_group_name,
		counterparty_truncated_code,
		counterparty_search_name,
		unit_balance_name)
	select
	ad.expense_or_payment_source_type_code,
	ad.accounting_document_unit_balance_code,
	ad.accounting_document_fiscal_year,
	ad.accounting_document_code,
	ad.accounting_document_position_code,
	ad.accounting_document_type_code,
	ad.payment_document_unit_balance_code,
	ad.payment_document_fiscal_year,
	ad.payment_document_code,
	ad.dt_posting,
	ad.payment_request_position_code,
	ad.purchase_document_code,
	ad.purchase_document_position_code,
	ad.reservation_document_code,
	ad.reservation_document_position_code,
	ad.reservation_document_reference_code,
	ad.cost_element_code,
	ad.correspondence_general_ledger_account_code,
	ad.material_code,
	ad.creditor_code,
	ad.contract_code,
	ad.external_contract_number,
	ad.wbs_element_internal_code,
	ad.wbs_element_external_code,
	ad.investment_project_internal_code,
	ip.wbs_element_number as investment_project_external_code,
	ad.controlling_order_code,
	 coalesce(r.currency_to_multiplier,	1) * case when coalesce(r.currency_rate,1) > 0 then coalesce(r.currency_rate,1)	else 1	end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,1))else 1 end 
		* coalesce(currency_from_multiplier,1))::numeric(20,5) as document_exchange_to_usd_rate,
	ad.vat_code,
	ad.vat_rate,
	ad.document_currency_amount,
	ad.document_currency_code,
	ad.vat_payment_document_currency_amount,
	ad.exclude_vat_payment_document_currency_amount,		
	ad.document_currency_amount * coalesce(r.currency_to_multiplier,
	1) * case
		when coalesce(r.currency_rate,	1) > 0 then coalesce(r.currency_rate,	1)	else 1 end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,1))else 1 end 
		* coalesce(currency_from_multiplier,1))::numeric(20,2) as document_usd_currency_amount,
	vat_payment_document_currency_amount * coalesce(r.currency_to_multiplier,
	1) * case	when coalesce(r.currency_rate,	1) > 0 then coalesce(r.currency_rate,1)	else 1 end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,1))else 1 end 
		* coalesce(currency_from_multiplier,1))::numeric(20,2) as vat_payment_usd_currency_amount,
	ad.document_currency_amount * coalesce(r.currency_to_multiplier,1) * case	when coalesce(r.currency_rate,	1) > 0 then 
	coalesce(r.currency_rate,1)	else 1 end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,	1))	else 1 end 
		* coalesce(currency_from_multiplier,1))::numeric(20,2)- vat_payment_document_currency_amount 
		* coalesce(r.currency_to_multiplier,1) * case when coalesce(r.currency_rate,	1) > 0 then coalesce(r.currency_rate,1)
		else 1 end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,1))else 1	end 
		* coalesce(currency_from_multiplier,1))::numeric(20,2) as exclude_vat_payment_usd_currency_amount,
	ad.capitalization_code,
	case
		when coalesce (ia.capitalization_percent,
		ia2.capitalization_percent) is null then 100::numeric(5,2)
		else coalesce (ia.capitalization_percent,ia2.capitalization_percent)
	end as capitalization_percent,
	ceb.budget_group_code as budget_group_code,
	ad.reverse_document_code,
	ad.reverse_document_fiscal_year,
	ad.dt_posting_reverse_document,
	ad.plant_code,
	ad.is_agent_payment,
	c.currency_iso_code as document_currency_iso_code,
	glac.general_ledger_account_full_name_rus as cost_element_name,
	gla.general_ledger_account_full_name_rus as correspondence_general_ledger_account_name,
	mt.material_name,
	ct.counterparty_short_name as creditor_name,
	wemdd.wbs_element_short_name as wbs_element_name,
	ip.wbs_element_short_name as investment_project_name,
	ot.order_short_name as controlling_order_name,
	pas.plant_short_name as plant_name,
	case when substring(ip.wbs_element_number from 1 for 4)=ad.accounting_document_unit_balance_code 
         then substring(ip.wbs_element_number from 6) else ip.wbs_element_number end as investment_activity_external_code,
    ia_td.investment_budget_section_code,
    ibst.investment_budget_section_full_name as investment_budget_section_name,
    ia_td.investment_budget_subsection_code,
    ibsst.investment_budget_subsection_full_name	as investment_budget_subsection_name,
    ia_td.division_code,
    dt.division_full_name	as division_name,
    case when iaaf.investment_activity_code is not null
    	then '00' else ia_td.investment_budget_section_code end as investment_budget_section_actual_code,
    ibst2.investment_budget_section_full_name as investment_budget_section_actual_name,
    case when iaaf.investment_activity_code is not null
    	then '001' else  ia_td.investment_budget_subsection_code end as investment_budget_subsection_actual_code,
    ibsst2.investment_budget_subsection_full_name	as investment_budget_subsection_actual_name,
	ia_td.investment_program_code,
    ipt.investment_program_full_name as investment_program_name,
    wemdd.wbs_element_unit_balance_code,
    bgt.budget_group_name,
    ct.counterparty_truncated_code,
    ct.counterparty_search_name,
    ub.unit_balance_name

from
	(
	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		accounting_document_position_code,
		accounting_document_type_code,
		payment_document_unit_balance_code,
		payment_document_fiscal_year,
		payment_document_code,
		dt_posting,
		payment_request_position_code,
		purchase_document_code,
		purchase_document_position_code,
		reservation_document_code,
		reservation_document_position_code,
		reservation_document_reference_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		external_contract_number,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		vat_rate,
		document_currency_amount,
		document_currency_code,
		vat_payment_document_currency_amount,
		exclude_vat_payment_document_currency_amount,		
		capitalization_code,
		reverse_document_code,
		reverse_document_fiscal_year,
		dt_posting_reverse_document,
		plant_code,
		is_agent_payment
	from
		dm_calc.investment_payments_actual_group_01
union all
	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		accounting_document_position_code,
		accounting_document_type_code,
		payment_document_unit_balance_code,
		payment_document_fiscal_year,
		payment_document_code,
		dt_posting,
		payment_request_position_code,
		purchase_document_code,
		purchase_document_position_code,
		reservation_document_code,
		reservation_document_position_code,
		reservation_document_reference_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		external_contract_number,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		vat_rate,
		document_currency_amount,
		document_currency_code,
		vat_payment_document_currency_amount,
		exclude_vat_payment_document_currency_amount,		
		capitalization_code,
		reverse_document_code,
		reverse_document_fiscal_year,
		dt_posting_reverse_document,
		plant_code,
		is_agent_payment
	from
		dm_calc.investment_payments_actual_group_02
union all
	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		accounting_document_position_code,
		accounting_document_type_code,
		payment_document_unit_balance_code,
		payment_document_fiscal_year,
		payment_document_code,
		dt_posting,
		payment_request_position_code,
		purchase_document_code,
		purchase_document_position_code,
		reservation_document_code,
		reservation_document_position_code,
		reservation_document_reference_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		external_contract_number,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		vat_rate,
		document_currency_amount,
		document_currency_code,
		vat_payment_document_currency_amount,
		exclude_vat_payment_document_currency_amount,		
		capitalization_code,
		reverse_document_code,
		reverse_document_fiscal_year,
		dt_posting_reverse_document,
		plant_code,
		is_agent_payment
	from
		dm_calc.investment_payments_actual_group_03) as ad
left join dict_dds.currency c on
	c.currency_code = ad.document_currency_code
left join dict_dds.unit_balance ub on
	ub.unit_balance_code = ad.accounting_document_unit_balance_code
left join dict_dds.currency_rate  r on
		r.deleted_flag = false
	and r.currency_rate_type_code = 'M'
	and r.currency_to = 'USD'
	and r.currency_from = case
		when ad.document_currency_code like 'UE%'
	then c.currency_iso_code
		else ad.document_currency_code
	end
	and r.dt_currency_rate = ad.dt_posting
left join dict_dds.investment_project ip on
		ip.wbs_element_code = ad.investment_project_internal_code
left join dict_dds.map_cost_element_to_budget ceb 
on
	ceb.cost_element_code = ad.cost_element_code
	and (ceb.cost_element_type_code is null
		or ceb.cost_element_type_code = 'P')
left join dict_dds.allocation_of_capitalization_value_for_investment_activity ia on
	ia.capitalization_version_code = '004'
	and ia.unit_balance_code = ad.accounting_document_unit_balance_code
	and ia.posting_reason_code = ad.capitalization_code
	and ia.dt_valid_from::DATE <= now()::date
	and ia.cost_element_mask_code = ad.cost_element_code
left join dict_dds.allocation_of_capitalization_value_for_investment_activity ia2 on
	ia2.capitalization_version_code = '004'
	and ia2.unit_balance_code = ad.accounting_document_unit_balance_code
	and ia2.posting_reason_code = ad.capitalization_code
	and ia2.dt_valid_from::DATE <= now()::date
	and ad.cost_element_code like ia2.cost_element_mask_code
left join dict_dds.general_ledger_account_chart glac on
	glac.general_ledger_account_code = ad.cost_element_code
	and glac.account_chart_code = ub.account_chart_code
left join dict_dds.general_ledger_account_chart gla on
	gla.general_ledger_account_code = ad.correspondence_general_ledger_account_code
	and gla.account_chart_code = ub.account_chart_code
left join dict_dds.material_texts mt on
	mt.material_code = ad.material_code
	and mt.language_code = 'R'
left join dict_dds.counterparty ct on
	ct.counterparty_code = ad.creditor_code
left join dict_dds.wbs_element_master_data_detail wemdd on
	wemdd.wbs_element_number = ad.wbs_element_external_code
left join dict_dds.order_toro ot on
	ot.order_code = ad.controlling_order_code
left join dict_dds.plant_and_subsidiary pas on
	pas.plant_code = ad.plant_code 
left join dict_dds.investment_activity_td ia_td
	on	ia_td.investment_activity_external_code = case when substring(ip.wbs_element_number from 1 for 4)=ad.accounting_document_unit_balance_code 
     then substring(ip.wbs_element_number from 6) else ip.wbs_element_number end
     and current_date between ia_td.dt_valid_from and ia_td.dt_valid_to
left join dict_dds.investment_budget_section_texts ibst
	on	ibst.investment_budget_section_code = ia_td.investment_budget_section_code
	and ibst.language_code = 'R'
left join dict_dds.investment_budget_subsection_texts ibsst	--
	on	ibsst.investment_budget_subsection_code = ia_td.investment_budget_subsection_code
	and ibsst.language_code = 'R'
left join dict_dds.division_texts dt
	on	dt.division_code = ia_td.division_code
	and dt.language_code = 'R'	
left join dict_dds.investment_activity_additional_finance iaaf
	on iaaf.fiscal_year = date_part('year', ad.dt_posting)::varchar
	and iaaf.investment_activity_code = 	case when substring(ip.wbs_element_number from 1 for 4)=ad.accounting_document_unit_balance_code 
         then substring(ip.wbs_element_number from 6) else ip.wbs_element_number end 
left join dict_dds.investment_budget_section_texts ibst2
	on	ibst2.investment_budget_section_code = case when iaaf.investment_activity_code is not null
    	then '00' else ia_td.investment_budget_section_code end
	and ibst2.language_code = 'R'
left join dict_dds.investment_budget_subsection_texts ibsst2	
	on	ibsst2.investment_budget_subsection_code = case when iaaf.investment_activity_code is not null
    	then '001' else  ia_td.investment_budget_subsection_code end
	and ibsst2.language_code = 'R'
left join dict_dds.budget_group_texts bgt 
	on ceb.budget_group_code = bgt.budget_group_code 
	and bgt.language_code = 'R'
left join dict_dds.investment_program_texts ipt
	on ipt.investment_program_code  = ia_td.investment_program_code
	and ipt.language_code = 'R';