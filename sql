select count(*) as rows_total,
       count(distinct invoice_realization_code) as uniq_codes,
       count(distinct invoice_realization_group_code) as uniq_groups,
       sum(case when invoice_realization_group_code is null then 1 else 0 end) as null_group_rows
from pg_temp.vbrk
where posting_status_code in ('C','E');
-- rows_total > uniq_codes => код в vbrk дублируется
3902378	3902378	323998	3568942

-- D2. VBSS: сколько поставок на документ и есть ли точные дубли
select max(cnt) as max_per_doc, round(avg(cnt),2) as avg_per_doc,
       sum(case when cnt > 1 then 1 else 0 end) as docs_with_many
from (select logistics_document_code, count(*) cnt
      from dds.logistics_document_and_delivery_relationship group by 1) t;
     27596	5.06	2641740

select (select count(*) from dds.logistics_document_and_delivery_relationship) as rows_total,
       (select count(*) from (select distinct logistics_document_code, delivery_code
                              from dds.logistics_document_and_delivery_relationship) d) as rows_distinct;
                            54421606	54421606

-- D3. vbss_vbsk_o_prepare: строк на поставку и дубли
select max(cnt) as max_per_delivery, round(avg(cnt),2) as avg_per_delivery
from (select delivery_code, count(*) cnt from pg_temp.vbss_vbsk_o_prepare group by 1) t;
813	4.02

select (select count(*) from pg_temp.vbss_vbsk_o_prepare) as rows_total,
       (select count(*) from (select distinct delivery_code, invoice_code, "LAND1_exp04",
                                     billing_document_code, invoice_type_code
                              from pg_temp.vbss_vbsk_o_prepare) d) as rows_distinct;

                             54460748	15407523
                             
-- D4. invoice и sales_contract_header_prepare: уникальны ли ключи
select count(*) as rows_total, count(distinct billing_document_code) as uniq_keys from dds.invoice;
select count(*) as rows_total, count(distinct sales_contract_code) as uniq_keys
from pg_temp.sales_contract_header_prepare;
23360178	3332514
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
3902378	41798759	69266
