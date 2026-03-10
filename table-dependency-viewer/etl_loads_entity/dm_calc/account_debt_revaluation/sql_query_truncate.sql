delete from dm_calc.account_debt_revaluation
where  ---мы пересчитываем за последние два месяца
dt between  (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date 
        and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date;