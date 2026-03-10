insert into dm_calc.account_debt_revaluation 
(
	dt,
	is_second_friday,
	unit_balance_code,
	fiscal_year,
 	accounting_document_code,
 	dt_debt,
	debit_or_credit,
	account_type,	
	document_currency_code,
	local_currency_code,
	second_local_currency_code,
	accounting_document_type,
	position_line_item,
 	exchange_diff_local_currency_amount,
 	debt_balance_exchange_diff_local_currency_amount,
 	exchange_diff_second_local_currency_amount,
 	debt_balance_exchange_diff_second_local_currency_amount 
)
with 
trn as (
select
		-- открытие
'O' as flg,
		o.unit_balance_code,
		o.fiscal_year,
		o.accounting_document_code,
		o.dt_posting,
		o.accounting_document_type,
		o.reverse_document_code,
		o.reference_document_number,
		o.accounting_document_status_code,
		o.dt_accounting_document,
		o.document_currency_code,
		o.local_currency_code,
		o.second_local_currency_code,
		o.position_line_item,
		o.debit_or_credit,
		o.general_ledger_account_code,
		o.tax_code,
		o.account_type,
		o.position_line_item_text,
		o.clearing_document_code,
		o.dt_clearing,
		o.special_general_ledger_indicator,
		o.counterparty_code,
		o.contract_number,
		o.plant_code,
		o.dt_baseline_due_date_calculation,
		o.terms_of_payment_code,
		o.assignment_number,
		case
			when o.debit_or_credit = 'H' then - o.document_currency_amount
			else o.document_currency_amount
		end as document_currency_amount,
		case
			when o.debit_or_credit = 'H' then - o.local_currency_amount
			else o.local_currency_amount
		end as local_currency_amount,
		case
			when o.debit_or_credit = 'H' then - o.second_local_currency_amount
			else o.second_local_currency_amount
		end as second_local_currency_amount,
		case
			when o.debit_or_credit = 'H' then - o.valuation_difference_second_local_currency_amount
			else o.valuation_difference_second_local_currency_amount
		end as valuation_difference_second_local_currency_amount,
		0 as close_dca,
		0 as close_lca,
		0 as close_sca,
		0 as close_vdsa,
		o.reverse_document_fiscal_year,
		o.reason_for_reversal,
		null as close_clearing_document_code,
		null as dt_close_clearing,
		o.invoice_document_code as invoice_document_code,
		o.fiscal_year_of_relevant_invoice as fiscal_year_of_relevant_invoice ,
		o.position_number_of_relevant_invoice as position_number_of_relevant_invoice,
	case
			when taerr.debit_or_credit = 'H' then - taerr.local_currency_amount
			else taerr.local_currency_amount
		end as exchange_diff_local_currency_amount,
		case
			when taerr.debit_or_credit = 'H' then - taerr.second_local_currency_amount
			else taerr.second_local_currency_amount
		end as exchange_diff_second_local_currency_amount,
		0 as debt_balance_exchange_diff_local_currency_amount,
		0 as debt_balance_exchange_diff_second_local_currency_amount,
		taerr.dt_posting as dt_posting_exchange_rate_revaluation,
		null as closing_document_code,
		null  as closing_fiscal_year,
		null as closing_line_item
	from
		dm_calc.accounting_receivables_and_payables o
	left join dm_calc.accounting_exchange_rate_revaluation_with_document_reference taerr on 
		taerr.unit_balance_code = o.unit_balance_code  and 
		taerr.reference_document_fiscal_year::numeric = o.fiscal_year  and 
		taerr.reference_document_code  = o.accounting_document_code and 
		taerr.reference_document_position_line_item::numeric = o.position_line_item 
	where
		1 = 1
		and o.deleted_flag = false
		and o.dt_posting  <= (now()::date - interval '1 day')
union all
	select
		-- закрытие
'C' as flg,
		opn.unit_balance_code,
		opn.fiscal_year,
		opn.accounting_document_code,
		cp.dt_posting,
		opn.accounting_document_type,
		opn.reverse_document_code,
		opn.reference_document_number,
		opn.accounting_document_status_code,
		opn.dt_accounting_document,
		cp.document_currency_code,
		cp.local_currency_code,
		cp.second_local_currency_code,
		opn.position_line_item,
		opn.debit_or_credit,
		opn.general_ledger_account_code,
		opn.tax_code,
		opn.account_type,
		opn.position_line_item_text,
		opn.clearing_document_code,
		opn.dt_clearing,
		opn.special_general_ledger_indicator,
		opn.counterparty_code,
		opn.contract_number,
		opn.plant_code,
		opn.dt_baseline_due_date_calculation,
		opn.terms_of_payment_code,
		opn.assignment_number,
		null as document_currency_amount,
		null as local_currency_amount,
		null as second_local_currency_amount,
		null as valuation_difference_second_local_currency_amount,
		case
			when cp.debit_or_credit = 'H' then - cp.document_currency_amount
			else cp.document_currency_amount
		end as close_dca,
		case
			when cp.debit_or_credit = 'H' then - cp.local_currency_amount
			else cp.local_currency_amount
		end as close_lca,
		case
			when cp.debit_or_credit = 'H' then - cp.second_local_currency_amount
			else cp.second_local_currency_amount
		end as close_sca,
		case
			when cp.debit_or_credit = 'H' then - cp.valuation_difference_second_local_currency_amount
			else cp.valuation_difference_second_local_currency_amount
		end as close_vdsa,
		opn.reverse_document_fiscal_year,
		opn.reason_for_reversal,
		cp.clearing_document_code as close_clearing_document_code,
		cp.dt_clearing as dt_close_clearing ,
		null as invoice_document_code,
		null as fiscal_year_of_relevant_invoice ,
		null as position_number_of_relevant_invoice,
		null as exchange_diff_local_currency_amount,
		null as exchange_diff_second_local_currency_amount,
		case
			when taerr2.debit_or_credit = 'H' then - taerr2.local_currency_amount
			else taerr2.local_currency_amount
		end as debt_balance_exchange_diff_local_currency_amount,
		case
			when taerr2.debit_or_credit = 'H' then - taerr2.second_local_currency_amount
			else taerr2.second_local_currency_amount
		end as debt_balance_exchange_diff_second_local_currency_amount,
		taerr2.dt_posting  as dt_posting_exchange_rate_revaluation,
		cp.accounting_document_code as closing_document_code,
		cp.fiscal_year  as closing_fiscal_year,
		cp.position_line_item as closing_line_item
	from
		dm_calc.accounting_receivables_and_payables opn
	join dm_calc.accounting_receivables_and_payables cp on
		cp.unit_balance_code = opn.unit_balance_code
		and cp.fiscal_year_of_relevant_invoice = opn.fiscal_year
		and cp.invoice_document_code = opn.accounting_document_code
		and cp.position_number_of_relevant_invoice = opn.position_line_item
		---and (cp.accounting_document_status_code != 'S'
	--		or cp.accounting_document_status_code is null)
	left join dm_calc.accounting_exchange_rate_revaluation_with_document_reference taerr2 on 
		taerr2.unit_balance_code = cp.unit_balance_code  and 
		taerr2.reference_document_fiscal_year::numeric = cp.fiscal_year  and 
		taerr2.reference_document_code  = cp.accounting_document_code and 
		taerr2.reference_document_position_line_item::numeric = cp.position_line_item 		
	where
		1 = 1
		-- and opn2.invoice_document_code is null
		and opn.deleted_flag = false
		and cp.deleted_flag = false
		and cp.document_currency_code = opn.document_currency_code
		and opn.dt_posting  <= (now()::date - interval '1 day')
		and cp.dt_posting  <= (now()::date - interval '1 day')
)
select
	st.dt,
	st.is_second_friday,
	t.unit_balance_code,
	t.fiscal_year,
	t.accounting_document_code,
	min(dt_posting) as dt_debt,
	t.debit_or_credit,
	t.account_type,
	t.document_currency_code,
	t.local_currency_code,
	t.second_local_currency_code,
	t.accounting_document_type,
	t.position_line_item,
	sum( coalesce (t.exchange_diff_local_currency_amount,0))::numeric(17,2) as exchange_diff_local_currency_amount,
	sum( coalesce (t.debt_balance_exchange_diff_local_currency_amount,0) + coalesce (t.exchange_diff_local_currency_amount,0))::numeric(17,2) as debt_balance_exchange_diff_local_currency_amount,
	sum( coalesce (t.exchange_diff_second_local_currency_amount,0))::numeric(17,2) as exchange_diff_second_local_currency_amount,
	sum( coalesce (t.debt_balance_exchange_diff_second_local_currency_amount,0)+coalesce (t.exchange_diff_second_local_currency_amount,0))::numeric(17,2) as debt_balance_exchange_diff_second_local_currency_amount
from
	dm_calc.operating_periods_for_account_debt st
join trn t on
	t.unit_balance_code = st.unit_balance_code
	---and date_trunc('month', st.dt) between date_trunc('month', t.dt_posting) and coalesce (t.dt_clearing,'2100-12-31')
left join dict_dds.settings_and_parameters_sap saps 
     on st.unit_balance_code=saps.range_low_value
    and saps.abap_program_code = '/RUSAL/FI_KHD'
    and saps.parameter_code = 'INACTBUK'	
where
	1 = 1
	and saps.range_low_value is null and  st.unit_balance_code !~'^[A-Za-z]'
	and coalesce(t.dt_clearing,'2100-12-31') > st.dt
	and t.dt_posting_exchange_rate_revaluation <=st.dt
	-- убираем закрытые в отчетном месяце
	and st.dt >= t.dt_posting
	--- костыль убрать после согласования дат срезов!!!!!!!
	---and t.dt_posting <= (now()::date - interval '1 day')
	and ((t.close_clearing_document_code is null) or (t.close_clearing_document_code is not null and coalesce(t.dt_close_clearing,'2100-12-31') > st.dt))
	-- DWH-1676 исключить, которые были сторнированы
	-- and st.unit_balance_code in ( '1100', '1510', '6000', '8300') -- список для dm_calc
	--вставляем за два последних месяца
	and (st.dt between  (date_trunc('month', now()) - interval '1 month'- interval '1 day')::date and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date)
group by
	st.dt,
	st.is_second_friday,
	t.document_currency_code,
	t.local_currency_code,
	t.second_local_currency_code,
	t.unit_balance_code,
	t.fiscal_year,
	t.accounting_document_code,
	t.accounting_document_type,
	t.position_line_item,
	t.account_type,
	t.debit_or_credit
having
	t.document_currency_code is not null
	and
	max(t.document_currency_amount) is not null;
	--and (debt_balance_document_currency_amount = 0 and debt_balance_local_currency_amount = 0 and debt_balance_second_local_currency_amount = 0 and debt_balance_with_revaluation_difference_second_currency_amount = 0)
;
