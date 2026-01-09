insert
	into
	dm_calc.investment_expenses_invoice_purchase_documents
	select
	dp2.invoice_code ,
	dp2.invoice_position_line_item_code ,
	dp2.fiscal_year,
	dp2.material_code,
	dp2.plant_code,
	dp2.reference_document_code,
	dp2.reference_document_fiscal_year,
	dp2.reference_document_position_line_item_code,
	dp2.unit_balance_code,
	dp2.valuation_type_code,
	dp2.purchase_document_code,
	dp2.purchase_document_position_line_item_code,
	dh2.purchase_contract_code ,
	dh2.payee_alternative_code,
	is_additionaly_debited_code
from
	dds.invoice_purchase_document_position dp2
left join dds.invoice_purchase_document_header dh2 on 
		dh2.invoice_code = dp2.invoice_code
	and dh2.fiscal_year = dp2.fiscal_year
	and dh2.reverse_document_code is null;
