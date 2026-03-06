insert into dm_calc.account_debt
(
    dt,
	is_second_friday,
	unit_balance_code,
	plant_code, 
	fiscal_year,
 	accounting_document_code,
 	dt_debt,
	dt_clearing,
 	contract_number,
 	counterparty_code,
	debit_or_credit,
	account_type,	
	general_ledger_account_code,
 	debt_balance_document_currency_amount,
	document_currency_code,
	debt_balance_local_currency_amount,
	local_currency_code,
	debt_balance_second_local_currency_amount,
	debt_balance_with_revaluation_diff_second_currency_amount,
	debt_balance_usd_amount,
	second_local_currency_code,
	accounting_document_type,
	position_line_item,
	reverse_document_code, 
	reference_document_number, 
	accounting_document_status_code,
	clearing_document_code,
	tax_code, 
	position_line_item_text,
	special_general_ledger_indicator,
	dt_baseline_due_date_calculation, 
	assignment_number, 
	dt_accounting_document, 
	terms_of_payment_code,
	document_currency_amount,
	local_currency_amount,
	second_local_currency_amount,
	usd_amount,
	reverse_document_fiscal_year,
	reason_for_reversal,
	invoice_document_code,
	fiscal_year_of_relevant_invoice,
	position_number_of_relevant_invoice,
	final_position_line_item,
	final_fiscal_year,	
 	final_accounting_document_code,
	document_currency_code_of_relevant_invoice,
	general_ledger_account_code_of_relevant_invoice,
	debit_or_credit_code_of_relevant_invoice,
	reference_operation_type_code,
	reference_object_key_code
)
with trn as (
	select
	-- открытие
		'O' as flg,
		o.unit_balance_code,
		o.fiscal_year,
		o.accounting_document_code,
		null  as closingdoc,
		null  as closingpos,
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
		case
			when o.debit_or_credit = 'H' then - o.usd_amount
			else o.usd_amount
		end as usd_amount,
		0 as close_dca,
		0 as close_lca,
		0 as close_sca,
		0 as close_vdsa,
		0 as close_ua,
		o.reverse_document_fiscal_year,
		o.reason_for_reversal,
		null as close_clearing_document_code,
		null as dt_close_clearing,
		o.invoice_document_code as invoice_document_code,
		o.fiscal_year_of_relevant_invoice as fiscal_year_of_relevant_invoice ,
		o.position_number_of_relevant_invoice as position_number_of_relevant_invoice,
		cp2.document_currency_code as  document_currency_code_of_relevant_invoice,
		cp2.general_ledger_account_code  as  general_ledger_account_code_of_relevant_invoice,
		cp2.debit_or_credit   as debit_or_credit_of_relevant_invoice,
		o.reference_procedure as reference_operation_type_code,
		o.reference_object_key as reference_object_key_code
	from
		dm_calc.accounting_receivables_and_payables o
		left join dm_calc.accounting_receivables_and_payables cp2 on
			cp2.unit_balance_code = o.unit_balance_code
			and o.fiscal_year_of_relevant_invoice = cp2.fiscal_year
			and o.invoice_document_code = cp2.accounting_document_code
			and o.position_number_of_relevant_invoice = cp2.position_line_item
	where
		1 = 1
			---	DWH-1734
---  and o.invoice_document_code is null			
		and o.deleted_flag = false
		and o.dt_posting  <= (now()::date - interval '1 day')
	---	and cp2.dt_posting <= (now()::date - interval '1 day')
union all
	select
		-- закрытие
'C' as flg,
		opn.unit_balance_code,
		opn.fiscal_year,
		opn.accounting_document_code,
		cp.accounting_document_code  as closingdoc,
		cp.position_line_item  as closingpos,
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
		null as usd_amount,
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
		case
			when cp.debit_or_credit = 'H' then - cp.usd_amount
			else cp.usd_amount
		end as close_ua,
		opn.reverse_document_fiscal_year,
		opn.reason_for_reversal,
		cp.clearing_document_code as close_clearing_document_code,
		cp.dt_clearing as dt_close_clearing ,
		null as invoice_document_code,
		null as fiscal_year_of_relevant_invoice ,
		null as position_number_of_relevant_invoice,
		null as document_currency_code_of_relevant_invoice,
		null as  general_ledger_account_code_of_relevant_invoice,
		null as debit_or_credit_of_relevant_invoice,
		opn.reference_procedure as reference_operation_type_code,
		opn.reference_object_key as reference_object_key_code
	from
		dm_calc.accounting_receivables_and_payables opn
	join dm_calc.accounting_receivables_and_payables cp on
		cp.unit_balance_code = opn.unit_balance_code
		and cp.fiscal_year_of_relevant_invoice = opn.fiscal_year
		and cp.invoice_document_code = opn.accounting_document_code
		and cp.position_number_of_relevant_invoice = opn.position_line_item
		--and (cp.accounting_document_status_code != 'S'
		--	or cp.accounting_document_status_code is null)
	where
		1 = 1
	---	DWH-1734
		-- and opn.invoice_document_code is null
		and opn.deleted_flag = false
		and cp.deleted_flag = false
		and cp.document_currency_code = opn.document_currency_code
		and cp.general_ledger_account_code = opn.general_ledger_account_code 
		and cp.debit_or_credit <> opn.debit_or_credit
		--- костыль убрать после согласования периодов!!!!!!!
		and opn.dt_posting <= (now()::date - interval '1 day')
		and cp.dt_posting <= (now()::date - interval '1 day')

)
select
	st.dt,
	st.is_second_friday,
	t.unit_balance_code,
	t.plant_code,
	t.fiscal_year,
	t.accounting_document_code,
	min(dt_posting) as dt_debt,
	t.dt_clearing,
	t.contract_number,
	t.counterparty_code,
	t.debit_or_credit,
	t.account_type,
	t.general_ledger_account_code,
	sum(coalesce(t.document_currency_amount, 0) + coalesce(t.close_dca, 0))::numeric(17,2) as debt_balance_document_currency_amount,
	t.document_currency_code,
	sum(coalesce(t.local_currency_amount, 0) + coalesce(t.close_lca, 0))::numeric(17,2) as debt_balance_local_currency_amount,
	t.local_currency_code,
	sum(coalesce(t.second_local_currency_amount, 0) + coalesce(t.close_sca, 0))::numeric(17,2) as debt_balance_second_local_currency_amount,
	sum(coalesce(t.second_local_currency_amount, 0) + coalesce(t.close_sca, 0)) + sum(coalesce(t.valuation_difference_second_local_currency_amount, 0) + coalesce(t.close_vdsa, 0))::numeric(17,2) as 	debt_balance_with_revaluation_diff_second_currency_amount,
	sum(coalesce(t.usd_amount, 0) + coalesce(t.close_ua, 0))::numeric(17,2) as debt_balance_usd_amount,
	t.second_local_currency_code,
	t.accounting_document_type,
	t.position_line_item,
	t.reverse_document_code,
	t.reference_document_number,
	t.accounting_document_status_code,
	t.clearing_document_code,
	t.tax_code,
	t.position_line_item_text,
	t.special_general_ledger_indicator,
	t.dt_baseline_due_date_calculation,
	t.assignment_number,
	t.dt_accounting_document,
	t.terms_of_payment_code,
	max(t.document_currency_amount) as document_currency_amount,
	max(t.local_currency_amount) as local_currency_amount,
	max(t.second_local_currency_amount) as second_local_currency_amount,
	max(t.usd_amount) as usd_amount,
	--ВОЗМОЖНО НАДО БУДЕТ ДОБАВИТЬ ПОЗЖЕ(ИЛИ УДАЛИТЬ)
--max(t.valuation_difference_second_local_currency_amount) as valuation_difference_second_local_currency_amount,
	t.reverse_document_fiscal_year,
	t.reason_for_reversal ,
	----Тут поменять на coalesce
	t.invoice_document_code,
	t.fiscal_year_of_relevant_invoice,
	t.position_number_of_relevant_invoice,
	----
	case when t.document_currency_code_of_relevant_invoice = t.document_currency_code 
	and t.general_ledger_account_code_of_relevant_invoice = t.general_ledger_account_code
	and t.debit_or_credit_of_relevant_invoice <> t.debit_or_credit then  coalesce (t.position_number_of_relevant_invoice,t.position_line_item)else t.position_line_item end  as 		final_position_line_item ,
	case when t.document_currency_code_of_relevant_invoice = t.document_currency_code 
	and t.general_ledger_account_code_of_relevant_invoice = t.general_ledger_account_code 
	and t.debit_or_credit_of_relevant_invoice <> t.debit_or_credit then  coalesce (t.fiscal_year_of_relevant_invoice, t.fiscal_year)  else t.fiscal_year end  as final_fiscal_year,
	case when t.document_currency_code_of_relevant_invoice = t.document_currency_code 
	and t.general_ledger_account_code_of_relevant_invoice = t.general_ledger_account_code
	and t.debit_or_credit_of_relevant_invoice <> t.debit_or_credit then  coalesce (t.invoice_document_code, t.accounting_document_code)else t.accounting_document_code end   as final_accounting_document_code,
	t.document_currency_code_of_relevant_invoice,
	t.general_ledger_account_code_of_relevant_invoice,
	t.debit_or_credit_of_relevant_invoice ,
	t.reference_operation_type_code,
	t.reference_object_key_code
from
	dm_calc.operating_periods_for_account_debt st
join trn t on
	t.unit_balance_code = st.unit_balance_code
left join dict_dds.settings_and_parameters_sap saps 
     on st.unit_balance_code=saps.range_low_value
    and saps.abap_program_code = '/RUSAL/FI_KHD'
    and saps.parameter_code = 'INACTBUK'	
where
	1 = 1
	and saps.range_low_value is null and  st.unit_balance_code !~'^[A-Za-z]'
	and coalesce(t.dt_clearing,'2100-12-31') > st.dt
	-- убираем закрытые в отчетном месяце
	and st.dt >= t.dt_posting
	-- DWH-1676 исключить, которые были сторнированы
	and ((t.close_clearing_document_code is null) or (t.close_clearing_document_code is not null and coalesce(t.dt_close_clearing,'2100-12-31') > st.dt))
---Вставляем удаленные за два предыдущих месяца
    and (st.dt between  (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date)
--and st.dt >= '2024-01-01'
group by
	st.dt,
	is_second_friday,
	t.document_currency_code,
	t.local_currency_code,
	t.second_local_currency_code,
	t.unit_balance_code,
	t.fiscal_year,
	t.accounting_document_type,
	t.accounting_document_code,
	t.position_line_item,
	t.reverse_document_code,
	t.reference_document_number,
	t.accounting_document_status_code,
	t.clearing_document_code,
	t.dt_clearing,
	t.general_ledger_account_code,
	t.tax_code,
	t.account_type,
	t.position_line_item_text,
	t.debit_or_credit,
	t.special_general_ledger_indicator,
	t.counterparty_code,
	t.contract_number,
	t.plant_code,
	t.dt_baseline_due_date_calculation,
	t.assignment_number,
	t.dt_accounting_document,
	t.terms_of_payment_code,
	t.reverse_document_fiscal_year,
	t.reason_for_reversal,
	t.invoice_document_code,
	t.fiscal_year_of_relevant_invoice,
	t.position_number_of_relevant_invoice,
	t.document_currency_code_of_relevant_invoice,
	t.general_ledger_account_code_of_relevant_invoice,
	t.reference_operation_type_code,
	t.reference_object_key_code,
	t.debit_or_credit_of_relevant_invoice
having
	t.document_currency_code is not null
	and	max(t.document_currency_amount) is not null;
