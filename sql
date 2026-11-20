-- 1. vbrk: нужные строки и колонки
drop table if exists t_vbrk;
create temp table t_vbrk as
select invoice_realization_code, invoice_realization_group_code, counterparty_country_code
from pg_temp.vbrk
where posting_status_code in ('C','E')
distributed by (invoice_realization_code);
analyze t_vbrk;

-- 2. Ветка БЕЗ группы (3,57 млн строк): код уникален, row_number не нужен
drop table if exists t_res_nogroup;
create temp table t_res_nogroup as
select invoice_realization_code,
       counterparty_country_code as country_of_destination_code,
       null::varchar as sales_bank_account_code   -- замените varchar на тип customer_code, если он другой
from t_vbrk
where invoice_realization_group_code is null
distributed by (invoice_realization_code);

-- 3. VBSS только по нужным группам (~324 тыс. групп)
drop table if exists t_vbss;
create temp table t_vbss as
select l.logistics_document_code, l.delivery_code
from dds.logistics_document_and_delivery_relationship l
where l.logistics_document_code in (
    select invoice_realization_group_code from t_vbrk
    where invoice_realization_group_code is not null)
distributed by (delivery_code);
analyze t_vbss;

-- 4. Группа -> уникальные наборы из prepare (здесь схлопываются дубли 3,5x)
drop table if exists t_grp;
create temp table t_grp as
select distinct l.logistics_document_code as grp,
       p.invoice_code, p."LAND1_exp04", p.billing_document_code, p.invoice_type_code
from t_vbss l
left join pg_temp.vbss_vbsk_o_prepare p on p.delivery_code = l.delivery_code
distributed by (grp);
analyze t_grp;

select count(*) from t_grp;   -- контрольная точка: ожидаю порядка 10 млн (оценка: 38 млн / 3,5), не сотни миллионов

-- 5. Одна строка на контракт (убирает множитель ~7)
drop table if exists t_sch;
create temp table t_sch as
select distinct on (sales_contract_code)
       sales_contract_code, sales_partner_role_code, customer_code
from pg_temp.sales_contract_header_prepare
order by sales_contract_code, sales_partner_role_code asc, customer_code asc
distributed by (sales_contract_code);
analyze t_sch;

-- 6. Привязка к инвойсам vbrk только с группой (~333 тыс. строк)
drop table if exists t_step2;
create temp table t_step2 as
select v.invoice_realization_code,
       v.invoice_realization_group_code,
       v.counterparty_country_code,
       g.invoice_code,
       g."LAND1_exp04" as land1,
       coalesce(g.billing_document_code, v.invoice_realization_code) as inv_key,
       g.invoice_type_code
from t_vbrk v
left join t_grp g on g.grp = v.invoice_realization_group_code
where v.invoice_realization_group_code is not null
distributed by (invoice_realization_code);
analyze t_step2;

select count(*) from t_step2;   -- контрольная точка

-- 7. Ветка С группой
drop table if exists t_res_group;
create temp table t_res_group as
select invoice_realization_code, country_of_destination_code, sales_bank_account_code
from (
    select x.invoice_realization_code,
           coalesce(x.land1, x.counterparty_country_code) as country_of_destination_code,
           case
               when i.billing_document_code is not null and i.bank_as_counterparty_code is not null
                   then i.bank_as_counterparty_code
               when i.billing_document_code is not null and i.bank_as_counterparty_code is null
                    and s.sales_partner_role_code is not null
                   then s.customer_code
           end as sales_bank_account_code,
           row_number() over (
               partition by x.invoice_realization_code
               order by x.invoice_realization_group_code asc,
                        x.invoice_code asc,
                        x.counterparty_country_code asc,
                        x.land1 asc,
                        i.billing_document_code asc,
                        s.sales_partner_role_code asc,
                        i.bank_as_counterparty_code asc,   -- для детерминизма
                        s.customer_code asc                -- для детерминизма
           ) as rn
    from t_step2 x
    left join dds.invoice i
           on i.billing_document_code = x.inv_key
          and x.invoice_type_code = 'О'      -- проверьте, что 'О' кириллическая
    left join t_sch s on s.sales_contract_code = i.sales_contract_code
) q
where rn = 1
distributed by (invoice_realization_code);

-- 8. Итог
drop table if exists t_result;
create temp table t_result as
select * from t_res_group
union all
select * from t_res_nogroup
distributed by (invoice_realization_code);

select count(*) from t_result;   -- должно быть 3 902 378
