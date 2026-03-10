insert into dm_calc.unpaid_payment_request (
	unit_balance_code,
    fiscal_year,
    invoice_document_code,
    invoice_document_position_code,
    unpaid_payment_request_code
		)
SELECT
	ad.unit_balance_code,
	ad.fiscal_year_of_relevant_invoice as fiscal_year,
    ad.invoice_document_code,
    ad.position_number_of_relevant_invoice as invoice_document_position_code,
    case
	    when min(ad.accounting_document_code)= max(ad.accounting_document_code)
	    then min(ad.accounting_document_code)
	    else null
	end as unpaid_payment_request_code
from
   dds.accounting_documents	ad
where
    ad.is_active = true
    and ad.deleted_flag = false
    and ad.clearing_document_code is null
    and ad.accounting_document_status_code = 'S'
group by
	ad.unit_balance_code,
	ad.fiscal_year_of_relevant_invoice,
    ad.invoice_document_code,
    ad.position_number_of_relevant_invoice;