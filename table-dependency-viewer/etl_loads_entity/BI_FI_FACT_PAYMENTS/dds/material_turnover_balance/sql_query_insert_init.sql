insert into dds.material_turnover_balance
(
	unit_balance_code,
	posting_period_yyyy,
	posting_period_mmm,
	data_type_code,
	plant_code,
	row_code,
	general_ledger_account_code,
	calculation_code,
	movement_type_code,
	correspondence_general_ledger_account_code,
	turnover_table_account_code,
	supplier_agent_code,
	valuation_class_code,
	uom_code,
	quantity,
	local_currency_amount,
	second_local_currency_amount
)
select
	bukrs	as unit_balance_code,
	bdatj as posting_period_yyyy,
	poper	as posting_period_mmm,
	dtype	as data_type_code,
	werks	as plant_code,
	id	as row_code,
	hkont	as general_ledger_account_code,
	kalnr	as calculation_code,
	bwagr	as movement_type_code,
	saknr	as correspondence_general_ledger_account_code,
	account	as turnover_table_account_code,
	lifnrka	as supplier_agent_code,
	bklas	as valuation_class_code,
	meins	as uom_code,
	menge	as quantity,
	dmbtr	as local_currency_amount,
	dmbe2	as second_local_currency_amount
from ods.rusal_ovs_ral
where 1=1
	and bdatj  between (date_part('year',
	(now() - interval '1 year')))::varchar and (date_part('year',now()))::varchar
;
