sql
-- D1. vbrk: уникальность кода, доля строк без группы
select count(*) as rows_total,
       count(distinct invoice_realization_code) as uniq_codes,
       count(distinct invoice_realization_group_code) as uniq_groups,
       sum(case when invoice_realization_group_code is null then 1 else 0 end) as null_group_rows
from pg_temp.vbrk
where posting_status_code in ('C','E');
-- rows_total > uniq_codes => код в vbrk дублируется

-- D2. VBSS: сколько поставок на документ и есть ли точные дубли
select max(cnt) as max_per_doc, round(avg(cnt),2) as avg_per_doc,
       sum(case when cnt > 1 then 1 else 0 end) as docs_with_many
from (select logistics_document_code, count(*) cnt
      from dds.logistics_document_and_delivery_relationship group by 1) t;

select (select count(*) from dds.logistics_document_and_delivery_relationship) as rows_total,
       (select count(*) from (select distinct logistics_document_code, delivery_code
                              from dds.logistics_document_and_delivery_relationship) d) as rows_distinct;

-- D3. vbss_vbsk_o_prepare: строк на поставку и дубли
select max(cnt) as max_per_delivery, round(avg(cnt),2) as avg_per_delivery
from (select delivery_code, count(*) cnt from pg_temp.vbss_vbsk_o_prepare group by 1) t;

select (select count(*) from pg_temp.vbss_vbsk_o_prepare) as rows_total,
       (select count(*) from (select distinct delivery_code, invoice_code, "LAND1_exp04",
                                     billing_document_code, invoice_type_code
                              from pg_temp.vbss_vbsk_o_prepare) d) as rows_distinct;

-- D4. invoice и sales_contract_header_prepare: уникальны ли ключи
select count(*) as rows_total, count(distinct billing_document_code) as uniq_keys from dds.invoice;
select count(*) as rows_total, count(distinct sales_contract_code) as uniq_keys
from pg_temp.sales_contract_header_prepare;

-- D5. Реальный размер результата после джойнов vbrk -> VBSS -> prepare (без материализации)
with pc as (
    select delivery_code, count(*) as cnt
    from pg_temp.vbss_vbsk_o_prepare group by 1
), g as (
    select l.logistics_document_code, sum(coalesce(pc.cnt, 1)) as exp_rows
    from dds.logistics_document_and_delivery_relationship l
    left join pc on pc.delivery_code = l.delivery_code
    group by 1
)
select count(*) as vbrk_rows,
       sum(coalesce(g.exp_rows, 1))::bigint as rows_after_vbss_prepare,
       max(g.exp_rows) as worst_group
from pg_temp.vbrk v
left join g on g.logistics_document_code = v.invoice_realization_group_code
where v.posting_status_code in ('C','E');

-- D6. Перекос по сегментам
select gp_segment_id, count(*) from pg_temp.vbrk group by 1 order by 2 desc;
select gp_segment_id, count(*) from pg_temp.vbss_vbsk_o_prepare group by 1 order by 2 desc;

Как читать результаты:

D5 показывает настоящий размер взрыва. План обещает 3 млрд строк после этого шага, но это оценка без статистики. Если реально там миллионы, проблема в оценках и промежуточных данных, а не в самой логике.
D1–D4: если rows_total больше rows_distinct или uniq_keys, то в справочниках есть дубли, они и размножают строки.
D6: если один сегмент сильно больше остальных, виноват перекос по ключу распределения.
Шаг 2. Скрипт по шагам

Идея: схлопывать данные до джойнов, считать «взрыв» один раз на группу (а не на каждый инвойс) и разделить ветки с группой и без неё. Семантика сохранена, кроме двух мест, помеченных комментариями.

sql
-- 1. Только нужные строки и колонки vbrk
drop table if exists t_vbrk;
create temp table t_vbrk as
select invoice_realization_code, invoice_realization_group_code,
       counterparty_country_code
from pg_temp.vbrk
where posting_status_code in ('C','E')
distributed by (invoice_realization_code);
analyze t_vbrk;

-- 2. Ветка БЕЗ группы: p/i/s не присоединяются, страна = страна контрагента
--    (в оригинале условие invoice_type_code = 'О' для этих строк ложно, банк всегда NULL)
drop table if exists t_res_nogroup;
create temp table t_res_nogroup as
select invoice_realization_code,
       counterparty_country_code as country_of_destination_code,
       null::varchar as sales_bank_account_code      -- приведите к типу customer_code, если он другой
from (
    select invoice_realization_code, counterparty_country_code,
           row_number() over (partition by invoice_realization_code
                              order by counterparty_country_code asc) as rn
    from t_vbrk
    where invoice_realization_group_code is null
) x
where rn = 1
distributed by (invoice_realization_code);

-- 3. Справочники без дублей
drop table if exists t_vbss;
create temp table t_vbss as
select distinct logistics_document_code, delivery_code
from dds.logistics_document_and_delivery_relationship
where logistics_document_code in (
    select distinct invoice_realization_group_code
    from t_vbrk where invoice_realization_group_code is not null)
distributed by (delivery_code);
analyze t_vbss;

drop table if exists t_p;
create temp table t_p as
select distinct delivery_code, invoice_code, "LAND1_exp04",
       billing_document_code, invoice_type_code
from pg_temp.vbss_vbsk_o_prepare
distributed by (delivery_code);
analyze t_p;

-- 4. Контракты: на каждый sales_contract_code нужна одна строка с минимальной ролью
--    (именно её выбирает row_number при сортировке по sales_partner_role_code asc)
drop table if exists t_sch;
create temp table t_sch as
select distinct on (sales_contract_code)
       sales_contract_code, sales_partner_role_code, customer_code
from pg_temp.sales_contract_header_prepare
order by sales_contract_code, sales_partner_role_code asc, customer_code asc
distributed by (sales_contract_code);
analyze t_sch;

-- 5. «Взрыв» считаем на уровне группы, а не каждого инвойса
drop table if exists t_grp;
create temp table t_grp as
select distinct l.logistics_document_code as grp,
       p.invoice_code, p."LAND1_exp04", p.billing_document_code, p.invoice_type_code
from t_vbss l
left join t_p p on p.delivery_code = l.delivery_code
distributed by (grp);
analyze t_grp;

-- 6. Привязываем к инвойсам vbrk и считаем ключ для invoice
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

-- 7. Ветка С группой: финальные джойны и выбор одной строки
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
                        i.bank_as_counterparty_code asc,   -- добавлено для детерминизма
                        s.customer_code asc                -- добавлено для детерминизма
           ) as rn
    from t_step2 x
    left join dds.invoice i
           on i.billing_document_code = x.inv_key
          and x.invoice_type_code = 'О'
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

Если dds.invoice содержит дубли по billing_document_code (проверка D4), шаг 7 их размножит, и тогда на таких дублях нужен отдельный разбор.

Шаг 3. Проверка, что результат совпадает с оригиналом
sql
-- Количество строк должно совпасть с числом уникальных кодов
select (select count(*) from t_result) as new_rows,
       (select count(distinct invoice_realization_code) from t_vbrk) as expected_rows;

-- Выборка для сравнения
drop table if exists t_sample;
create temp table t_sample as
select distinct invoice_realization_code from t_vbrk limit 5000
distributed by (invoice_realization_code);

Затем запустите оригинальный запрос с добавленным в where условием and d_ir.invoice_realization_code in (select invoice_realization_code from t_sample), сохранив результат в t_orig (через create temp table t_orig as ...). Сравнение:

sql
select 'only_orig' as src, * from (
    select * from t_orig
    except
    select * from t_result where invoice_realization_code in (select invoice_realization_code from t_sample)
) a
union all
select 'only_new', * from (
    select * from t_result where invoice_realization_code in (select invoice_realization_code from t_sample)
    except
    select * from t_orig
) b;

Расхождения возможны там, где в оригинале порядок строк не был детерминирован (одинаковые значения всех ключей сортировки). Остальные расхождения означают, что семантика потеряна, и их нужно разбирать.

Два места, где я изменил логику (проверьте)
Условие invoice_type_code = 'О' в ON. Для строк без группы оно всегда ложно, поэтому ветка vgtyp = 'U' → vgbel в оригинале не работает, а банк всегда NULL. Я оставил так же. Если вы хотели другое поведение, скажите, перепишем. Заодно проверьте, что 'О' везде кириллическая.
Дубли кода в vbrk (D1). Если один код встречается и с группой, и без, оригинал выбирал одну строку из двух, а мой union all вернёт две. Для этого и стоит проверка количества строк.

Пришлите результаты D1–D5, особенно D5 и rows_distinct из D2–D3, и я скажу, где реально узкое место и нужно ли что-то ещё менять.

Claude Code входит в состав этого приложения
Как Claude справляется в этой сессии?
