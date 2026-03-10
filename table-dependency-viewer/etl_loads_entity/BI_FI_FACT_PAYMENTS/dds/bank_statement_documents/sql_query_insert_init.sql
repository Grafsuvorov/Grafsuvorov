insert into
	dds.bank_statement_documents
select
	h.statement_type_code,
	h.bic_code,
	h.company_account_code,
	h.statement_currency_code,
	h.statement_fiscal_year,
	h.statement_number,
	h.statement_code,
	p.statement_position_line_item_code,
	p.accounting_document_code,
	p.support_accounting_document_code,
	h.payee_code
from
	ods.bank_statement_header h
left join ods.bank_statement_position p on
	h.statement_code = p.statement_code
where
	1 = 1