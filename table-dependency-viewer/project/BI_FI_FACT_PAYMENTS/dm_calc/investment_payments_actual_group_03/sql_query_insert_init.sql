insert into dm_calc.investment_payments_actual_group_03 (
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
	where op.is_order_for_capital_electrolyser_repair_code is not null) as ord),
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
		(case 
			when saps.parameter_code = 'SO_HKTP' 
		    then 'PAY_GTD'
			when saps.parameter_code = 'SO_HKTMW' 
			then 'PAY_GTDMWS'
		end
		) as expense_or_payment_source_type_code,
		ad.unit_balance_code as accounting_document_unit_balance_code,
		ad.fiscal_year as accounting_document_fiscal_year,
		ad.accounting_document_code,
		ad.position_line_item as accounting_document_position_code,
		ad.accounting_document_type as accounting_document_type_code,
		revdoc.unit_balance_code as payment_document_unit_balance_code,
		revdoc.fiscal_year as payment_document_fiscal_year,
		revdoc.accounting_document_code as payment_document_code,
		coalesce (revdoc.dt_posting,ad.dt_posting) as dt_posting,
		null  as payment_request_position_code, 
		null as purchase_document_code,
		null as purchase_document_position_code,
		null as reservation_document_code,
		null as reservation_document_position_code,
		null as reservation_document_reference_code,
		ad.general_ledger_account_code as cost_element_code,
		null as correspondence_general_ledger_account_code, 
		null as material_code,
		coalesce(ad.customer_code, ad.supplier_code) as creditor_code,
		null as contract_code,
		ad.assignment_number as external_contract_number,
		ad.wbs_element_code as wbs_element_internal_code,
		mdd.wbs_element_number as wbs_element_external_code,
		mdd.investment_project_code as investment_project_internal_code,
		--ip.wbs_element_number as investment_project_external_code,
		--ad.tax_code as vat_code,
		null as controlling_order_code ,
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
		end * ad.document_currency_amount as vat_document_currency_amount,
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
	mdd.plant_code  as plant_code,
	null as is_agent_payment	
from dds.accounting_documents ad
inner join (select saps.case_code, 
			saps.parameter_code,
			saps.abap_program_code,
			saps.range_sign_code,
			saps.range_low_value,
			dense_rank() over ( partition by saps.case_code, saps.parameter_code
		order by
			coalesce(saps.dt_valid_from, '1000-01-01')  desc ) as row_num
			from dict_dds.settings_and_parameters_sap saps
			where saps.abap_program_code = '/RUSAL/FI1349M' 
				and (saps.parameter_code = 'SO_HKTP' or saps.parameter_code = 'SO_HKTMW')
				and saps.range_sign_code is not null) as saps on
		ad.general_ledger_account_code like replace (saps.range_low_value, '*', '%') 
		and ad.unit_balance_code = saps.case_code
		and saps.row_num = 1 
left join (select saps1.case_code, 
			saps1.parameter_code,
			saps1.abap_program_code,
			saps1.range_sign_code,
			saps1.range_low_value,
			dense_rank() over ( partition by saps1.case_code, saps1.parameter_code
		order by
			coalesce(saps1.dt_valid_from, '1000-01-01')  desc ) as row_num
			from dict_dds.settings_and_parameters_sap saps1
			where saps1.abap_program_code = '/RUSAL/FI1349M' 
				and saps1.parameter_code = 'SO_BLATP'
				and saps1.range_sign_code is not null) as saps1 on
		ad.accounting_document_type like replace (saps1.range_low_value, '*', '%') 
		and ad.unit_balance_code = saps1.case_code
		and saps1.row_num = 1 
left join dm_calc.investment_payments_accounting_document_header revdoc on
	revdoc.unit_balance_code = ad.unit_balance_code
	and revdoc.fiscal_year = extract ('year'from ad.dt_clearing)
	and revdoc.accounting_document_code = ad.clearing_document_code
left join prps as mdd on
		mdd.wbs_element_code = ad.wbs_element_code 
left join dict_dds.unit_balance be on
	be.unit_balance_code = ad.unit_balance_code
left join dict_dds.country country on
	be.country_code = country.country_code
	and current_date < country.dt_valid_to
left join dict_dds.vat_rates_texts vrt on
	country.calculation_scheme_code = vrt.calculation_scheme_code
	and be.language_code = vrt.language_code
	and ad.tax_code = vrt.vat_code
where 
		1 = 1
		and ad.is_active = true
		and ad.deleted_flag = false
		and ad.wbs_element_code is not null
		and saps.abap_program_code is not null and saps1.abap_program_code is not null;