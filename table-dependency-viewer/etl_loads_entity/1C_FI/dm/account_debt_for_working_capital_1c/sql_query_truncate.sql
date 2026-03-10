delete
--select * 
 from dm.account_debt_for_working_capital_1c
where ----мы пересчитываем только за 2 предыдущих месяца
	dt >= (date_trunc('day', now()) - interval '60 days')::date and dt <= now();