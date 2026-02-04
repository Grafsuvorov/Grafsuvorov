with params as (
  select
    (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date as dt_from,
    (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date as dt_to
)
🔹 Шаг 1. Переоценка — агрегируем СРАЗУ корректно
, revaluation_documents as (
select
  unit_balance_code,
  reference_document_fiscal_year::numeric as fiscal_year,
  reference_document_code as accounting_document_code,
  reference_document_position_line_item::numeric as position_line_item,
  max(dt_posting) as last_dt_posting,
  sum(case when debit_or_credit = 'H' then -local_currency_amount else local_currency_amount end)
    as exchange_diff_local_currency_amount,
  sum(case when debit_or_credit = 'H' then -second_local_currency_amount else second_local_currency_amount end)
    as exchange_diff_second_local_currency_amount
from dm_calc.accounting_exchange_rate_revaluation_with_document_reference
where deleted_flag = false
group by
  unit_balance_code,
  reference_document_fiscal_year,
  reference_document_code,
  reference_document_position_line_item
)
✅ Минус раздувание по dt_posting
🔹 Шаг 2. БАЗА документов (один проход)
, arap_base as (
select
  o.*,
  case when o.debit_or_credit='H' then -o.document_currency_amount else o.document_currency_amount end as document_currency_amount_s,
  case when o.debit_or_credit='H' then -o.local_currency_amount else o.local_currency_amount end as local_currency_amount_s,
  case when o.debit_or_credit='H' then -o.second_local_currency_amount else o.second_local_currency_amount end as second_local_currency_amount_s,
  case when o.debit_or_credit='H' then -o.usd_amount else o.usd_amount end as usd_amount_s
from dm_calc.accounting_receivables_and_payables o
left join dict_dds.settings_and_parameters_sap s
  on o.unit_balance_code = s.range_low_value
 and s.abap_program_code='/RUSAL/FI_KHD'
 and s.parameter_code='INACTBUK'
where
  o.document_currency_code is not null
  and o.unit_balance_code !~ '^[A-Za-z]'
  and o.deleted_flag = false
  and s.range_low_value is null
)
🔹 Шаг 3. СРАЗУ ограничиваем календарь
, periods as (
select st.*
from dm_calc.operating_periods_for_account_debt st
join params p on st.dt between p.dt_from and p.dt_to
where st.deleted_flag = false
)
🔹 Шаг 4. Открывающие документы + период
, opening_docs as (
select
  p.dt,
  p.is_second_friday,
  a.*,
  r.exchange_diff_local_currency_amount,
  r.exchange_diff_second_local_currency_amount
from arap_base a
join periods p
  on p.unit_balance_code = a.unit_balance_code
 and p.dt >= a.dt_posting
 and (a.dt_clearing is null or p.dt < a.dt_clearing)
left join revaluation_documents r
  on r.unit_balance_code = a.unit_balance_code
 and r.fiscal_year = a.fiscal_year
 and r.accounting_document_code = a.accounting_document_code
 and r.position_line_item = a.position_line_item
)
✅ Здесь заканчивается раздувание
🔹 Шаг 5. Исключаем документы с инвойсами (БЕЗ self-scan)
, opening_no_invoice as (
select o.*
from opening_docs o
where not exists (
  select 1
  from opening_docs x
  where
    x.dt = o.dt
    and x.unit_balance_code = o.unit_balance_code
    and x.final_fiscal_year = o.fiscal_year
    and x.final_accounting_document_code = o.accounting_document_code
    and x.final_position_line_item = o.position_line_item
    and x.invoice_document_code is null
    and x.document_currency_code = o.document_currency_code_of_relevant_invoice
    and x.general_ledger_account_code = o.general_ledger_account_code_of_relevant_invoice
    and x.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice
)
)
✅ Работает по уже ограниченному набору, а не по всей CTE.
🔹 Шаг 6. Закрывающие суммы
, closing_sum as (
select
  o.dt,
  o.unit_balance_code,
  o.fiscal_year,
  o.accounting_document_code,
  o.position_line_item,
  sum(cp.document_currency_amount_s) as document_currency_amount,
  sum(cp.local_currency_amount_s) as local_currency_amount,
  sum(cp.second_local_currency_amount_s) as second_local_currency_amount,
  sum(cp.usd_amount_s) as usd_amount,
  sum(cp.exchange_diff_local_currency_amount) as exchange_diff_local_currency_amount,
  sum(cp.exchange_diff_second_local_currency_amount) as exchange_diff_second_local_currency_amount
from opening_no_invoice o
join opening_docs cp
  on cp.dt = o.dt
 and cp.unit_balance_code = o.unit_balance_code
 and cp.fiscal_year_of_relevant_invoice = o.fiscal_year
 and cp.invoice_document_code = o.accounting_document_code
 and cp.position_number_of_relevant_invoice = o.position_line_item
 and cp.debit_or_credit <> o.debit_or_credit
group by
  o.dt, o.unit_balance_code, o.fiscal_year, o.accounting_document_code, o.position_line_item
)
🔹 Финал INSERT
insert into dm_calc.account_debt
select
  o.dt,
  o.is_second_friday,
  o.unit_balance_code,
  o.plant_code,
  o.fiscal_year,
  o.accounting_document_code,
  ...
  (o.document_currency_amount_s + coalesce(c.document_currency_amount,0))::numeric(17,2),
  ...
from opening_no_invoice o
left join closing_sum c
  on c.dt = o.dt
 and c.unit_balance_code = o.unit_balance_code
 and c.fiscal_year = o.fiscal_year
 and c.accounting_document_code = o.accounting_document_code
 and c.position_line_item = o.position_line_item;
