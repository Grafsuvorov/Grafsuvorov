insert into dds.settlement_documents_from_project_to_receiver
select
	ak.belnr as settlement_document_code,
	ak.perbz as settlement_type_code,
	ak.objnr as object_code,
	ak.gjahr::numeric(4,0) as fiscal_year, 
	ak.kokrs as controlling_area_code,
	aa.emtyp as assignment_type_code,
	aa.bukrs as accounting_document_unit_balance_code,
	aas.lfdnr as sequence_number, 
	aas.plfnr as primary_assignment_sequence_number,
	(aas."wtgbtr" *(10 ^ (2 - coalesce(dp1.decimal_place_number, 2))))::numeric(15,2) as document_currency_amount,
	ub.currency_code as document_currency_code,
	(aas."wkgbtr" *(10 ^ (2 - coalesce(dp2.decimal_place_number, 2))))::numeric(15,2) as second_local_currency_amount,
	ca.currency_code as second_local_currency_code,
	SUBSTRING(LTRIM(aas.key01), 5, 10) as controlling_document_code,
	SUBSTRING(LTRIM(aas.key01), 15, 3) as controlling_document_position_line_item_code,
	SUBSTRING(LTRIM(aas.key01), 32, 10) as cost_element_code

from
	ods."auak_ral" ak
inner join ods."auaa_ral"aa on
	ak.belnr = aa.belnr
inner join ods."auas_ral" aas on
	ak.belnr = aas.belnr
	and aa.lfdnr = aas.plfnr
left join dict_dds.unit_balance ub on  
		aa.bukrs = ub.unit_balance_code  
left join dict_dds.map_controlling_area_to_unit_balance m on
	m.unit_balance_code = ub.unit_balance_code
left join dict_dds.controlling_area ca on 
	ca.controlling_area_code = m.controlling_area_code
left join dict_dds.currency_decimal_place_ral  dp1 on 
 	dp1.currency_code = ub.currency_code
left join dict_dds.currency_decimal_place_ral dp2 on 
	dp2.currency_code = ca.currency_code

where
	1 = 1
	and ak.objnr like 'PR%'	