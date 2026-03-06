insert into
	dds.earmarked_funds_documents
select
	h.earmarked_document_code,
	p.earmarked_document_position_line_item_code,
	h.reference_document_code,
	p.order_number_code,
	p.wbs_element_code,
	p.general_ledger_account_code
from
	ods.earmarked_funds_document_header h
left join ods.earmarked_funds_document_position p on
	h.earmarked_document_code = p.earmarked_document_code
where
	1 = 1
;