insert into  dm_calc.investment_payments_actual_group_01(
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
	is_agent_payment)
with ord as (
select
	order_type_code,
	order_code,
	wbs_element_code,
	unit_balance_code,
	nm
from
	(
	select
		ot.order_type_code ,
		ot.order_code,
		ot.wbs_element_code,
		ot.unit_balance_code,
		'toro' as nm
	from
		dict_dds.order_toro ot
	where ot.is_order_for_capital_electrolyser_repair_code is not null 
union all
	select
		oc.order_type_code ,
		oc.order_code,
		oc.wbs_element_code,
		oc.unit_balance_code,
		'co' as nm
	from
		dict_dds.order_controlling oc
	where oc.is_order_for_capital_electrolyser_repair_code is not null
union all
	select
		op.order_type_code ,
		op.order_code,
		op.wbs_element_code,
		op.unit_balance_code,
		'pp' as nm
	from
		dict_dds.order_production op 
	where op.is_order_for_capital_electrolyser_repair_code is not null ) as ord),
prps as (
select
	mdd.wbs_element_number,
	mdd.wbs_element_code,
	mdd.investment_project_code,
	mdd.posting_reason_code,
	mdd.plant_code
from
	dict_dds.wbs_element_master_data_detail mdd
left join dict_dds.settings_and_parameters_sap ref_saps5
	on
	ref_saps5.abap_program_code = '/RUSAL/FI1349M'
	and ref_saps5.range_low_value = mdd.investment_project_profile_code 
	and (ref_saps5.parameter_code = 'S_IMPRFE' )
	and ref_saps5.range_sign_code is not null
left join ord as ref_orders on
		ref_orders.wbs_element_code = mdd.wbs_element_code
	where
		1 = 1
		and ref_saps5.range_low_value is null
		and (mdd.is_wbs_statistical is null
		or ref_orders.wbs_element_code is not null)
	group by 
		mdd.wbs_element_number,
		mdd.wbs_element_code,
		mdd.investment_project_code,
		mdd.posting_reason_code,
		mdd.plant_code
)
select
    'PAY_FM' as expense_or_payment_source_type_code,
	ad.unit_balance_code as accounting_document_unit_balance_code,
	ad.fiscal_year as accounting_document_fiscal_year,
	ad.accounting_document_code as accounting_document_code,
	ad.position_line_item as accounting_document_position_code,
	ad.accounting_document_type as accounting_document_type_code,
	revdoc.unit_balance_code as payment_document_unit_balance_code,
	revdoc.fiscal_year as payment_document_fiscal_year,
	revdoc.accounting_document_code as payment_document_code,
	coalesce (revdoc.dt_posting, ad.dt_posting) as dt_posting,
	null  as payment_request_position_code,
	null as purchase_document_code,
	null as purchase_document_position_code,
	ad.earmarked_document_code as reservation_document_code,
	ad.earmarked_document_position_code as reservation_document_position_code,
	efd.reference_document_code as reservation_document_reference_code,
	efd.general_ledger_account_code
	as cost_element_code,
	null as correspondence_general_ledger_account_code,
	null as material_code,
	coalesce(ad.customer_code,ad.supplier_code) as counterparty_code,
	null as contract_code,
	ad.assignment_number as external_contract_number,
	coalesce (
									nullif(efd.wbs_element_code ,'00000000'),
									nullif(orders.wbs_element_code,'00000000'),
									nullif(ref_efd.wbs_element_code ,'00000000'),
									nullif(ref_orders.wbs_element_code,'00000000') )
	  as wbs_element_internal_code,
	mdd.wbs_element_number as wbs_element_external_code,
	mdd.investment_project_code as investment_project_internal_code,
	efd.order_number_code as controlling_order_code,
	vrt.vat_code ,
	vrt.vat_rate,
	case
		when ad.debit_or_credit = 'S' then -1
		else 1
	end * ad.document_currency_amount  as document_currency_amount,
	ad.document_currency_code as document_currency_code,
	
	case
		when ad.debit_or_credit = 'S' then -1
		else 1
	end *
	   ad.document_currency_amount* vrt.vat_rate as vat_document_currency_amount,
	case
		when ad.debit_or_credit = 'S' then -1
		else 1
	end *
		 ad.document_currency_amount - ad.document_currency_amount * vrt.vat_rate
		as exclude_vat_payment_document_currency_amount,
	mdd.posting_reason_code as capitalization_code,
	revdoc.reverse_document_code as reverse_document_code,
	revdoc.reverse_document_fiscal_year as reverse_document_fiscal_year,
	revdoc.dt_posting_reverse_document,
	mdd.plant_code as plant_code,
	ad.is_agent_payment as is_agent_payment 
from
	dm_calc.investment_payments_actual_group_00 ad
inner join dds.earmarked_funds_documents efd on
	efd.earmarked_document_code = ad.earmarked_document_code
	and efd.earmarked_document_position_line_item_code = ad.earmarked_document_position_code
	and efd.wbs_element_code <> '00000000'
left join dict_dds.unit_balance be on
	be.unit_balance_code = ad.unit_balance_code
left join dict_dds.country country on
	be.country_code = country.country_code
	and current_date < country.dt_valid_to
left join dict_dds.vat_rates_texts vrt on
	country.calculation_scheme_code = vrt.calculation_scheme_code
	and be.language_code = vrt.language_code
	and ad.tax_code = vrt.vat_code
left join  dm_calc.investment_payments_accounting_document_header  revdoc on
	revdoc.unit_balance_code = ad.unit_balance_code
	and revdoc.fiscal_year = extract ('year' from ad.dt_clearing)
	and revdoc.accounting_document_code = ad.clearing_document_code
left join (
	select
			reference_document_code,
			earmarked_document_position_line_item_code,
			earmarked_document_code,
			wbs_element_code,
			order_number_code
	from
		(
		select
			reference_document_code,
			earmarked_document_position_line_item_code,
			earmarked_document_code,
			wbs_element_code,
			order_number_code,
			row_number() over ( partition by reference_document_code,
			earmarked_document_position_line_item_code
		order by
			earmarked_document_code asc ) as row_num
		from
			 dds.earmarked_funds_documents ) as cr
	where
		cr.row_num = 1 )
 as ref_efd 
on
	ref_efd.reference_document_code = efd.earmarked_document_code
	and ref_efd.earmarked_document_position_line_item_code = ad.earmarked_document_position_code
left join ord as orders on
	orders.order_code = efd.order_number_code
left join ord as ref_orders on
	ref_orders.order_code = ref_efd.order_number_code
inner join prps as mdd on
	mdd.wbs_element_code = coalesce (
									nullif(efd.wbs_element_code ,'00000000'),
									nullif(orders.wbs_element_code,'00000000'),
									nullif(ref_efd.wbs_element_code ,'00000000'),
									nullif(ref_orders.wbs_element_code,'00000000') )
left join
	dict_dds.settings_and_parameters_sap saps2
on
	saps2.case_code = ad.unit_balance_code
	and saps2.abap_program_code = '/RUSAL/FI1349M'
	and (saps2.parameter_code = 'GBAUGNOT')
	and saps2.range_sign_code is not null
	and saps2.range_low_value = ad.fund_code
where
	1 = 1
	and ad.earmarked_document_code is not null
	and not (ad.is_payment_document_optional <> 'X'
		and saps2.range_low_value is null
		and revdoc.accounting_document_code is null);