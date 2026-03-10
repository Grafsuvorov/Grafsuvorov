insert into dm_calc.unit_balance_operating_periods
select
	unit_balance_code,
	(generate_series(min(dt)::date, now()::date, '1 month'::interval) + interval '1 month - 1 day')::date as dt_end_of_month
from ods.accounting_balance
where unit_balance_code not like 'E%'
  and unit_balance_code not like 'F%'
  and unit_balance_code not like 'S%'
group by unit_balance_code;