delete
from
	dm_calc.account_turnover
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