insert into dm_calc.accounting_exchange_rate_revaluation_with_document_reference
select
	err.unit_balance_code,
	err.fiscal_year,
	err.account_type ,
	err.accounting_document_code,
	err.position_line_item,
	err.position_line_item_text,
	err.accounting_document_type,
	err.dt_posting,
	err.dt_accounting_document,
	err.debit_or_credit,
	err.general_ledger_account_code,
	err.special_general_ledger_indicator,
	err.document_currency_code,
	err.local_currency_code,
	err.second_local_currency_code,
	err.document_currency_amount,
	err.local_currency_amount,
	err.second_local_currency_amount,
	err.is_red_reverse_posting,
	err.reference_document_code, 
	err.reference_document_fiscal_year,
	err.reference_document_position_line_item
from 
	dm_calc.accounting_exchange_rate_revaluation err
where 
	1 = 1
	and err.reference_document_code is not null
	and err.reference_document_fiscal_year is not null
	and err.reference_document_position_line_item is not null;