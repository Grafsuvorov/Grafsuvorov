insert into dm_calc.account_balance_by_contract
select
	st.dt_end_of_month as dt,
	p.unit_balance_code ,
	p.plant_code ,
	p.general_ledger_account_code ,
	p.customer_code ,
	p.supplier_code ,
	p.counterparty_code ,
	p.contract_number,
	sum(p.balance_closing_document_currency_amount),
	p.document_currency_code ,
	sum(p.balance_closing_local_currency_amount),
	p.local_currency_code ,
	sum(p.balance_closing_second_local_currency_amount),
	p.second_local_currency_code
from
	dm_calc.accounting_documents_balance_aggregated p
left join dm_calc.unit_balance_operating_periods st on
	p.unit_balance_code = st.unit_balance_code
where
	p.document_currency_code is not null
	and p.general_ledger_account_code is not null
	and p.dt_posting <= st.dt_end_of_month
	and p.deleted_flag = false
	and coalesce(p.dt_clearing,'2100-12-31') > st.dt_end_of_month
group by
	st.dt_end_of_month,
	p.unit_balance_code ,
	p.plant_code ,
	p.general_ledger_account_code ,
	p.customer_code ,
	p.supplier_code ,
	p.counterparty_code ,
	p.contract_number,
	p.document_currency_code ,
	p.local_currency_code ,
	p.second_local_currency_code
	having 	sum(p.balance_closing_document_currency_amount)!=0 
	or sum(p.balance_closing_local_currency_amount)!=0
	or sum(p.balance_closing_second_local_currency_amount)!=0