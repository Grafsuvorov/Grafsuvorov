delete
from
	dm_calc.accounting_exchange_rate_revaluation
where
	(unit_balance_code,
	fiscal_year,
	accounting_document_code,
	position_line_item) 
in (
	select
		unit_balance_code,
		fiscal_year,
		accounting_document_code,
		position_line_item
	from
		ods.accounting_documents);