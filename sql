SQL Error [42601]: ERROR: INSERT has more target columns than expressions
  Позиция: 514


Позиция ошибки: line: 1472 pos: 513

/* ============================================================
   1. Переоценка: агрегируем один раз
   ============================================================ */
DROP TABLE IF EXISTS tmp_revaluation_documents;
CREATE TEMP TABLE tmp_revaluation_documents AS
SELECT
    unit_balance_code,
    reference_document_fiscal_year::numeric AS fiscal_year,
    reference_document_code AS accounting_document_code,
    reference_document_position_line_item::numeric AS position_line_item,
    dt_posting,
    SUM(
        CASE WHEN debit_or_credit = 'H'
             THEN -local_currency_amount
             ELSE  local_currency_amount
        END
    ) AS exchange_diff_local_currency_amount,
    SUM(
        CASE WHEN debit_or_credit = 'H'
             THEN -second_local_currency_amount
             ELSE  second_local_currency_amount
        END
    ) AS exchange_diff_second_local_currency_amount
FROM dm_calc.accounting_exchange_rate_revaluation_with_document_reference
WHERE deleted_flag = false
GROUP BY
    unit_balance_code,
    reference_document_fiscal_year,
    reference_document_code,
    reference_document_position_line_item,
    dt_posting
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   2. Базовые документы задолженности + нормализация сумм
   ============================================================ */
DROP TABLE IF EXISTS tmp_arap;
CREATE TEMP TABLE tmp_arap AS
SELECT
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,
    o.dt_posting,
    o.dt_clearing,

    /* суммы */
    CASE WHEN o.debit_or_credit = 'H' THEN -o.document_currency_amount ELSE o.document_currency_amount END AS document_currency_amount,
    CASE WHEN o.debit_or_credit = 'H' THEN -o.local_currency_amount ELSE o.local_currency_amount END AS local_currency_amount,
    CASE WHEN o.debit_or_credit = 'H' THEN -o.second_local_currency_amount ELSE o.second_local_currency_amount END AS second_local_currency_amount,
    CASE WHEN o.debit_or_credit = 'H' THEN -o.valuation_difference_second_local_currency_amount ELSE o.valuation_difference_second_local_currency_amount END AS valuation_difference_second_local_currency_amount,
    CASE WHEN o.debit_or_credit = 'H' THEN -o.usd_amount ELSE o.usd_amount END AS usd_amount,

    /* аналитика */
    o.document_currency_code,
    o.local_currency_code,
    o.second_local_currency_code,
    o.debit_or_credit,
    o.general_ledger_account_code,
    o.account_type,
    o.counterparty_code,
    o.contract_number,
    o.plant_code,

    /* ссылки */
    o.invoice_document_code,
    o.fiscal_year_of_relevant_invoice,
    o.position_number_of_relevant_invoice,

    /* переоценка */
    r.exchange_diff_local_currency_amount,
    r.exchange_diff_second_local_currency_amount,
    r.dt_posting AS dt_posting_rev

FROM dm_calc.accounting_receivables_and_payables o
LEFT JOIN tmp_revaluation_documents r
  ON r.unit_balance_code = o.unit_balance_code
 AND r.fiscal_year = o.fiscal_year
 AND r.accounting_document_code = o.accounting_document_code
 AND r.position_line_item = o.position_line_item

LEFT JOIN dict_dds.settings_and_parameters_sap saps
  ON o.unit_balance_code = saps.range_low_value
 AND saps.abap_program_code = '/RUSAL/FI_KHD'
 AND saps.parameter_code = 'INACTBUK'

WHERE
    o.deleted_flag = false
    AND o.document_currency_code IS NOT NULL
    AND saps.range_low_value IS NULL
    AND o.unit_balance_code !~ '^[A-Za-z]'
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   3. Периоды — режем сразу по датам
   ============================================================ */
DROP TABLE IF EXISTS tmp_periods;
CREATE TEMP TABLE tmp_periods AS
SELECT *
FROM dm_calc.operating_periods_for_account_debt
WHERE
    deleted_flag = false
    AND dt BETWEEN
        (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date
        AND
        (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   4. Ключи открывающих документов + агрегация
   ============================================================ */
DROP TABLE IF EXISTS tmp_opening_keys;
CREATE TEMP TABLE tmp_opening_keys AS
SELECT
    p.dt,
    p.is_second_friday,
    a.unit_balance_code,
    a.fiscal_year,
    a.accounting_document_code,
    a.position_line_item,

    MAX(a.document_currency_amount) AS document_currency_amount,
    MAX(a.local_currency_amount) AS local_currency_amount,
    MAX(a.second_local_currency_amount) AS second_local_currency_amount,
    MAX(a.valuation_difference_second_local_currency_amount) AS valuation_difference_second_local_currency_amount,
    MAX(a.usd_amount) AS usd_amount,

    SUM(
        CASE WHEN a.dt_posting_rev IS NULL OR a.dt_posting_rev <= p.dt
             THEN a.exchange_diff_local_currency_amount
        END
    ) AS exchange_diff_local_currency_amount,

    SUM(
        CASE WHEN a.dt_posting_rev IS NULL OR a.dt_posting_rev <= p.dt
             THEN a.exchange_diff_second_local_currency_amount
        END
    ) AS exchange_diff_second_local_currency_amount

FROM tmp_arap a
JOIN tmp_periods p
  ON p.unit_balance_code = a.unit_balance_code
WHERE
    p.dt >= a.dt_posting
    AND COALESCE(a.dt_clearing, '2299-12-31') > p.dt
GROUP BY
    p.dt,
    p.is_second_friday,
    a.unit_balance_code,
    a.fiscal_year,
    a.accounting_document_code,
    a.position_line_item
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   5. Финальный расчёт остатков (closing + opening)
   ============================================================ */
INSERT INTO   dm_calc.account_debt_old (
    dt,
    is_second_friday,
    unit_balance_code,
    plant_code,
    fiscal_year,
    accounting_document_code,
    dt_debt,
    dt_clearing,
    contract_number,
    counterparty_code,
    debit_or_credit,
    account_type,
    general_ledger_account_code,
    debt_balance_document_currency_amount,
    document_currency_code,
    debt_balance_local_currency_amount,
    local_currency_code,
    debt_balance_second_local_currency_amount,
    debt_balance_with_revaluation_diff_second_currency_amount,
    debt_balance_usd_amount,
    second_local_currency_code,
    accounting_document_type,
    position_line_item,
    reverse_document_code,
    reference_document_number,
    accounting_document_status_code,
    clearing_document_code,
    tax_code,
    position_line_item_text,
    special_general_ledger_indicator,
    dt_baseline_due_date_calculation,
    assignment_number,
    dt_accounting_document,
    terms_of_payment_code,
    document_currency_amount,
    local_currency_amount,
    second_local_currency_amount,
    usd_amount,
    reverse_document_fiscal_year,
    reason_for_reversal,
    invoice_document_code,
    fiscal_year_of_relevant_invoice,
    position_number_of_relevant_invoice,
    final_position_line_item,
    final_fiscal_year,
    final_accounting_document_code,
    document_currency_code_of_relevant_invoice,
    general_ledger_account_code_of_relevant_invoice,
    debit_or_credit_code_of_relevant_invoice,
    reference_operation_type_code,
    reference_object_key_code,
    exchange_diff_local_currency_amount,
    debt_balance_exchange_diff_local_currency_amount,
    exchange_diff_second_local_currency_amount,
    debt_balance_exchange_diff_second_local_currency_amount
)
SELECT
    o.dt,
    o.is_second_friday,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,

    /* остатки */
    (o.document_currency_amount)::numeric(17,2) AS debt_balance_document_currency_amount,
    (o.local_currency_amount)::numeric(17,2) AS debt_balance_local_currency_amount,
    (o.second_local_currency_amount)::numeric(17,2) AS debt_balance_second_local_currency_amount,
    (o.second_local_currency_amount + o.valuation_difference_second_local_currency_amount)::numeric(17,2)
        AS debt_balance_with_revaluation_diff_second_currency_amount,
    (o.usd_amount)::numeric(17,2) AS debt_balance_usd_amount,

    o.exchange_diff_local_currency_amount::numeric(17,2) AS exchange_diff_local_currency_amount,
    o.exchange_diff_second_local_currency_amount::numeric(17,2) AS exchange_diff_second_local_currency_amount

FROM tmp_opening_keys o;



вот этот кусок долгий 
explain
SELECT
    p.dt,
    p.is_second_friday,
    a.unit_balance_code,
    a.fiscal_year,
    a.accounting_document_code,
    a.position_line_item,

    MAX(a.document_currency_amount) AS document_currency_amount,
    MAX(a.local_currency_amount) AS local_currency_amount,
    MAX(a.second_local_currency_amount) AS second_local_currency_amount,
    MAX(a.valuation_difference_second_local_currency_amount) AS valuation_difference_second_local_currency_amount,
    MAX(a.usd_amount) AS usd_amount,

    SUM(
        CASE WHEN a.dt_posting_rev IS NULL OR a.dt_posting_rev <= p.dt
             THEN a.exchange_diff_local_currency_amount
        END
    ) AS exchange_diff_local_currency_amount,

    SUM(
        CASE WHEN a.dt_posting_rev IS NULL OR a.dt_posting_rev <= p.dt
             THEN a.exchange_diff_second_local_currency_amount
        END
    ) AS exchange_diff_second_local_currency_amount

FROM tmp_arap a
JOIN tmp_periods p
  ON p.unit_balance_code = a.unit_balance_code
WHERE
    p.dt >= a.dt_posting
    AND COALESCE(a.dt_clearing, '2299-12-31') > p.dt
GROUP BY
    p.dt,
    p.is_second_friday,
    a.unit_balance_code,
    a.fiscal_year,
    a.accounting_document_code,
    a.position_line_item

Gather Motion 8:1  (slice2; segments: 8)  (cost=0.00..282713.81 rows=726294130 width=87)
  ->  HashAggregate  (cost=0.00..107526.22 rows=90786767 width=87)
        Group Key: tmp_periods.dt, tmp_periods.is_second_friday, tmp_arap.unit_balance_code, tmp_arap.fiscal_year, tmp_arap.accounting_document_code, tmp_arap.position_line_item
        ->  Hash Join  (cost=0.00..32420.96 rows=90786767 width=75)
              Hash Cond: ((tmp_arap.unit_balance_code)::text = (tmp_periods.unit_balance_code)::text)
              Join Filter: ((tmp_periods.dt >= tmp_arap.dt_posting) AND (COALESCE(tmp_arap.dt_clearing, '2299-12-31'::date) > tmp_periods.dt))
              ->  Seq Scan on tmp_arap  (cost=0.00..1494.54 rows=10624817 width=78)
              ->  Hash  (cost=431.19..431.19 rows=2257 width=10)
                    ->  Broadcast Motion 8:8  (slice1; segments: 8)  (cost=0.00..431.19 rows=2257 width=10)
                          ->  Seq Scan on tmp_periods  (cost=0.00..431.01 rows=283 width=10)
Optimizer: Pivotal Optimizer (GPORCA)
