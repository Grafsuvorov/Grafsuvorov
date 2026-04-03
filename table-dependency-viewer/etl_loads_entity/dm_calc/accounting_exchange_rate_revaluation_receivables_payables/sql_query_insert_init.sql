insert	into
	 dm_calc.accounting_exchange_rate_revaluation_receivables_payables	(
	 		unit_balance_code,
			fiscal_year,
			accounting_document_code,
			position_line_item,
			counterparty_code,
			contract_number,
			plant_code,
			reference_key_internal_for_document_header_1,
			reference_key_for_line_item_3
	 )
with cte  as (select
		min(adcr.position_line_item) as position_line_item,
		adcr.unit_balance_code,
		adcr.fiscal_year,
		adcr.accounting_document_code
	from
		dm_calc.accounting_receivables_and_payables as adcr 
	group by adcr.unit_balance_code,
		     adcr.fiscal_year,
		     adcr.accounting_document_code) 
select
	rp.unit_balance_code,
	rp.fiscal_year,
	rp.accounting_document_code,
	rp.position_line_item,
	rp.counterparty_code,
	rp.contract_number,
	rp.plant_code,
	rp.reference_key_internal_for_document_header_1,
	rp.reference_key_for_line_item_3
from dm_calc.accounting_receivables_and_payables as rp
join cte as c on 
	c.position_line_item=rp.position_line_item 
	and c.unit_balance_code=rp.unit_balance_code 
	and c.fiscal_year=rp.fiscal_year 
	and c.accounting_document_code=rp.accounting_document_code;
