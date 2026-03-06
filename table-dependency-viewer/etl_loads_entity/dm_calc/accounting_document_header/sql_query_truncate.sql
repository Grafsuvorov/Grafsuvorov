delete
from
	dm_calc.accounting_document_header
where
	(unit_balance_code,
	fiscal_year,
	accounting_document_code)
in (
	select
		unit_balance_code,
		fiscal_year,
		accounting_document_code
	from
		ods.accounting_documents);