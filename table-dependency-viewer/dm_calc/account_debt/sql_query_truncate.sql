delete from dm_calc.account_debt
where ---мы пересчитываем только за два предыдущих месяца
dt between   (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date 
         and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date;