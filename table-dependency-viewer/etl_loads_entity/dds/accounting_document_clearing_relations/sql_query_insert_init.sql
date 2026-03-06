insert into dds.accounting_document_clearing_relations
with cte as (
select  max(clearing_subsequent_number) as clearing_subsequent_number, adcr.clearing_document_unit_balance_code,
		            adcr.clearing_document_fiscal_year,
		            adcr.clearing_document_code
from ods.accounting_document_clearing_relations adcr group by adcr.clearing_document_unit_balance_code,
		            adcr.clearing_document_fiscal_year,
		            adcr.clearing_document_code)
SELECT
	 bc.clearing_document_unit_balance_code,
	bc.clearing_document_code,
	bc.clearing_document_fiscal_year,
	bc.clearing_subsequent_number,
	bc.clearing_document_line_item_code,
	bc.document_currency_code,
	bc.clearing_type_code,
	bc.unit_balance_code,
	bc.accounting_document_code,
	bc.fiscal_year,
	bc.position_line_item,
	bc.debit_or_credit_code, 
	(bc.local_currency_amount*(10 ^ (2 - coalesce(dp2.decimal_place_number,2))))::numeric(15,2) as local_currency_amount,
	(bc.second_local_currency_amount*(10 ^ (2 - coalesce(dp3.decimal_place_number,2))))::numeric(15,2) as second_local_currency_amount,
	(bc.document_currency_amount*(10 ^ (2 - coalesce(dp.decimal_place_number,2))))::numeric(15,2) as document_currency_amount,
	(bc.valuation_difference_document_currency_amount*(10 ^ (2 - coalesce(dp2.decimal_place_number,2))))::numeric(15,2) as valuation_difference_local_currency_amount,
	(bc.valuation_difference_second_local_currency_amount*(10 ^ (2 - coalesce(dp3.decimal_place_number,2))))::numeric(15,2) as valuation_difference_second_local_currency_amount,
	bc.account_type_code,
	bc.special_general_ledger_indicator  ,
	case when c.clearing_document_unit_balance_code is not null then 1 else 0 end latest_status
FROM 
	ods.accounting_document_clearing_relations bc
left join cte c on 
	c.clearing_document_unit_balance_code=bc.clearing_document_unit_balance_code 
	and c.clearing_document_fiscal_year=bc.clearing_document_fiscal_year 
	and c.clearing_document_code=bc.clearing_document_code 
	and c.clearing_subsequent_number=bc.clearing_subsequent_number
left join dict_dds.unit_balance ub on
	ub.unit_balance_code = bc.clearing_document_unit_balance_code
left join dict_dds.map_controlling_area_to_unit_balance m on 
 m.unit_balance_code = ub.unit_balance_code 
left join dict_dds.controlling_area ca on 
	ca.controlling_area_code = m.controlling_area_code
left join dict_dds.currency_decimal_place_ral dp on 
	dp.currency_code = bc.document_currency_code
left join dict_dds.currency_decimal_place_ral  dp2 on 
 	dp2.currency_code = ub.currency_code
left join dict_dds.currency_decimal_place_ral  dp3 on 
	dp3.currency_code = ca.currency_code
WHERE 1=1;
