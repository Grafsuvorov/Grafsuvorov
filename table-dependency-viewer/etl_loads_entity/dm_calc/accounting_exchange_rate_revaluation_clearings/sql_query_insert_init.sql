insert into  dm_calc.accounting_exchange_rate_revaluation_clearings (
			clearing_document_unit_balance_code,
			clearing_document_fiscal_year,
			clearing_document_code,
			counterparty_code,
			contract_number,
			plant_code,
			reference_key_internal_for_document_header_1,
			reference_key_for_line_item_3,
			ref_unit_balance_code,
			ref_fiscal_year,
			ref_accounting_document_code,
			ref_position_line_item
)
select 
	adcr.clearing_document_unit_balance_code,
	adcr.clearing_document_fiscal_year, 
	adcr.clearing_document_code,
	arap.counterparty_code, 
	arap.contract_number, 
	arap.plant_code, 
	arap.reference_key_internal_for_document_header_1,
	arap.reference_key_for_line_item_3,
	arap.unit_balance_code as ref_unit_balance_code,
	arap.fiscal_year as ref_fiscal_year,
	arap.accounting_document_code as ref_accounting_document_code,
	arap.position_line_item as ref_position_line_item
	
from  dds.accounting_document_clearing_relations as adcr
left join dm_calc.accounting_receivables_and_payables as arap on 
	arap.unit_balance_code = adcr.unit_balance_code 
	and arap.fiscal_year = adcr.fiscal_year 
	and arap.accounting_document_code = adcr.accounting_document_code   
	and arap.position_line_item = adcr.position_line_item 
where adcr.account_type_code in ('K', 'D') 
	and adcr.last_status=1;
