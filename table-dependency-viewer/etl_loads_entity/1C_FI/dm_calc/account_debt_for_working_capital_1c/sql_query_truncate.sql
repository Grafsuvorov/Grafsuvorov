delete
--select *
from
	dm_calc.account_debt_for_working_capital_1c as d
where
	(d.dt_report,
	d.unit_balance_mdm_code_1c)
in (
	select distinct
		o.dt_report,
		o.unit_balance_mdm_code_1c
	from
		ods.account_debt_for_working_capital_1c as o);