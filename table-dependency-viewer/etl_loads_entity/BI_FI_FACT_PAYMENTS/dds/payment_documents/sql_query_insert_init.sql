insert into
	dds.payment_documents
select
	h.dt_program_execution,
	h.additional_identifier_code,
	h.is_trial_execution,
	h.payer_unit_balance_code,
	h.supplier_code,
	h.customer_code,
	h.payee_code,
	h.payment_document_code,
	p.unit_balance_code,
	p.accounting_document_code,
	p.accounting_document_fiscal_year,
	p.accounting_document_position_line_item_code,
	h.payment_order_code
from
	ods.payment_document_header h
left join ods.payment_document_position p on
	h.dt_program_execution = p.dt_program_execution
	and h.additional_identifier_code = p.additional_identifier_code
	and h.is_trial_execution = p.is_trial_execution
	and h.payer_unit_balance_code = p.payer_unit_balance_code
	and h.supplier_code = p.supplier_code
	and h.customer_code = p.customer_code
	and h.payee_code = p.payee_code
	and h.payment_document_code = p.payment_document_code
where
	1 = 1
;