insert into dm_calc.investment_payments_actual_group_00 (
	unit_balance_code,
	fiscal_year,
	accounting_document_code,
	dt_posting,
	debit_or_credit,
	general_ledger_account_code,
	document_currency_amount,
	document_currency_code,
	customer_code,
	supplier_code,
	accounting_document_type,
	clearing_document_code,
	dt_clearing,
	position_line_item,
	tax_code,
	assignment_number,
	exchange_rate,
	wbs_element_code,
	purchase_document_code,
	purchase_document_position_code,
	earmarked_document_code,
	earmarked_document_position_code,
	fund_code,
	is_agent_payment,
	is_payment_document_optional)
with cte as (
select
	case_code ,
	range_low_value,
	max(case when saps.parameter_code = 'BL_AUGNO' or saps.parameter_code = 'SO_BLAFR' then 'X' else null end) as filt
from
	dict_dds.settings_and_parameters_sap saps
where
	saps.abap_program_code = '/RUSAL/FI1349M'
	and (saps.parameter_code = 'BL_AUGNO' or saps.parameter_code = 'SO_BLTAP' or saps.parameter_code = 'SO_BLAFR')
	and saps.range_sign_code is not null
group by
	case_code ,
	range_low_value 
)
(select
	ad.unit_balance_code,
	ad.fiscal_year,
	ad.accounting_document_code,
	ad.dt_posting,
	ad.debit_or_credit,
	ad.general_ledger_account_code ,
	ad.document_currency_amount,
	ad.document_currency_code,
	ad.customer_code,
	ad.supplier_code,
	ad.accounting_document_type,
	ad.clearing_document_code,
	ad.dt_clearing,
	ad.position_line_item,
	ad.tax_code,
	ad.assignment_number,
	ad.exchange_rate,
	ad.wbs_element_code,
	ad.purchase_document_code,
	ad.purchase_document_position_line_item_code as purchase_document_position_code,
	ad.earmarked_document_code,
	ad.earmarked_document_position_line_item_code as earmarked_document_position_code,
	ad.fund_code,
    true as is_agent_payment,
    saps.filt as is_payment_document_optional
    
from
	dds.accounting_documents ad
join dds.payment_documents pd
on
	pd.unit_balance_code = ad.unit_balance_code
	and pd.accounting_document_fiscal_year::numeric = ad.fiscal_year
	and pd.accounting_document_code = ad.accounting_document_code
	and pd.accounting_document_position_line_item_code::numeric = ad.position_line_item
	and pd.is_trial_execution is null
	and coalesce (pd.supplier_code,	'') = coalesce(ad.supplier_code ,	'')
	and pd.dt_program_execution <= ad.dt_baseline_due_date_calculation
	and pd.dt_program_execution >= ad.dt_baseline_due_date_calculation - interval '7 days'
  join (
	select
			counterparty_code,
			payment_order_code,
			statement_code,				
			statement_position_line_item_code
	from
		(
		select
			counterparty_code,
			payment_order_code,
			statement_code,
			statement_position_line_item_code,
			row_number() over ( partition by counterparty_code,
			payment_order_code
		order by
			statement_code,
			statement_position_line_item_code desc ) as row_num
		from
			dds.bank_statement_position_clearing_record) as cr
	where
		cr.row_num = 1 ) as  cr
on
	coalesce (cr.counterparty_code,'') = coalesce (pd.supplier_code,'')
	and cr.payment_order_code = pd.payment_order_code
join dds.bank_statement_documents bsd on
	bsd.statement_code = cr.statement_code
	and bsd.statement_position_line_item_code = cr.statement_position_line_item_code
	and bsd.support_accounting_document_code is not null
left join cte saps 
on
	ad.unit_balance_code = saps.case_code
	and saps.range_low_value = ad.accounting_document_type
where
	ad.is_active = true
	and ad.clearing_document_code is null
	and ad.is_blocked_by_payment_program is not null
    and ad.deleted_flag = false 
	--and ad.earmarked_document_code is not  null
	and ad.reverse_document_code is null)
	union all
	(
	select 	ad1.unit_balance_code,
	ad1.fiscal_year,
	ad1.accounting_document_code,
	ad1.dt_posting,
	ad1.debit_or_credit,
	ad1.general_ledger_account_code ,
	ad1.document_currency_amount,
	ad1.document_currency_code,
	ad1.customer_code,
	ad1.supplier_code,
	ad1.accounting_document_type,
	ad1.clearing_document_code,
	ad1.dt_clearing,
	ad1.position_line_item,
	ad1.tax_code,
	ad1.assignment_number,
	ad1.exchange_rate,
	ad1.wbs_element_code,
	ad1.purchase_document_code,
	ad1.purchase_document_position_line_item_code as purchase_document_position_code,
	ad1.earmarked_document_code,
	ad1.earmarked_document_position_line_item_code as earmarked_document_position_code,
	ad1.fund_code,
	false as is_agent_payment,
    saps.filt as is_payment_document_optional
	from dds.accounting_documents ad1
inner join cte saps 
on
	ad1.unit_balance_code = saps.case_code
	and saps.range_low_value = ad1.accounting_document_type
where
	ad1.is_active = true
	and ad1.deleted_flag = false 
	and ad1.reverse_document_code is null);