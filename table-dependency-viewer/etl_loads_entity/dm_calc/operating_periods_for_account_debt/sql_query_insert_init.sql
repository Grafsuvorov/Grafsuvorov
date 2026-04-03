insert into dm_calc.operating_periods_for_account_debt
(
unit_balance_code,
dt,
is_second_friday,
is_for_account_debt_only
)
with date_series as (
select
	unit_balance_code,
	generate_series(min(dt)::date,
	now()::date,
	'1 day'::interval)::date as day_start
from
	ods.accounting_balance
where
	unit_balance_code not like 'E%'
	and unit_balance_code not like 'F%'
	and unit_balance_code not like 'S%'
group by
	unit_balance_code
),
month_series as (
select
	unit_balance_code,
	generate_series(min(dt)::date,
	now()::date,
	'1 month'::interval)::date as month_start
from
	ods.accounting_balance
where
	unit_balance_code not like 'E%'
	and unit_balance_code not like 'F%'
	and unit_balance_code not like 'S%'
group by
	unit_balance_code
),
second_friday as (
select 
	( month_start + 
       case
		when extract(dow
	from
		month_start) <= 5
            then (5 - extract(dow
	from
		month_start))::int
		else (12 - extract(dow
	from
		month_start))::int
	end + 7
       )::date as second_friday   	
from
	month_series
	group by ( month_start + 
       case
		when extract(dow
	from
		month_start) <= 5
            then (5 - extract(dow
	from
		month_start))::int
		else (12 - extract(dow
	from
		month_start))::int
	end + 7
       )::date
)
select
	unit_balance_code,
	day_start as dt,
	case when s.second_friday is not null then true else false end is_second_friday,
		case when day_start=current_date-1 
	        --  or day_start = (month_start + interval '1month - 1 day')::date
	          or day_start = (date_trunc('month', day_start) + interval '1 month' - interval '1 day') ::date 
	          or s.second_friday is not null
	     then true else false end is_for_account_debt_only
from
	date_series d
left join second_friday s on 
	d.day_start = s.second_friday	
where 
	day_start < current_date 
order by
	unit_balance_code,
	dt;
