insert into dm_calc.account_for_exchange_rate_difference
select
	distinct 
	dict_aerd.local_account_for_adjustment_code,
	be.unit_balance_code
from
	dict_dds.account_for_exchange_rate_difference dict_aerd
join dict_dds.unit_balance be
	on dict_aerd.account_chart_code = be.account_chart_code
join dict_dds.general_ledger_accounts_main_data dict_glad
	on be.unit_balance_code = dict_glad.unit_balance_code
	and dict_aerd.general_ledger_account_code  = dict_glad.general_ledger_account_code
where
	1 = 1
	and dict_aerd.currency_code is null
	and dict_aerd.currency_and_valuation_type_code = '30'
	and dict_glad.account_type_code in ('D', 'K');