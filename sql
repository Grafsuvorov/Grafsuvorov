/* ============================================================
   account_debt_old — оптимизированная сборка через TEMP
   Логика = как в старом скрипте (opening/closing, anti-join invoices, переоценка по dt_posting_rev)
   ============================================================ */

BEGIN;

/* ============================================================
   0) tmp_periods (периоды расчёта)
   ============================================================ */
DROP TABLE IF EXISTS tmp_periods;
CREATE TEMP TABLE tmp_periods AS
SELECT *
FROM dm_calc.operating_periods_for_account_debt
WHERE deleted_flag = false
  AND dt BETWEEN
        (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date
        AND
        (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   1) tmp_revaluation_documents (агрегация переоценки 1 раз)
   ============================================================ */
DROP TABLE IF EXISTS tmp_revaluation_documents;
CREATE TEMP TABLE tmp_revaluation_documents AS
SELECT
    unit_balance_code,
    reference_document_fiscal_year::numeric AS fiscal_year,
    reference_document_code AS accounting_document_code,
    reference_document_position_line_item::numeric AS position_line_item,
    dt_posting,
    SUM(CASE WHEN debit_or_credit = 'H' THEN -local_currency_amount ELSE local_currency_amount END)
        AS exchange_diff_local_currency_amount,
    SUM(CASE WHEN debit_or_credit = 'H' THEN -second_local_currency_amount ELSE second_local_currency_amount END)
        AS exchange_diff_second_local_currency_amount
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
   2) tmp_arap_base (аналог arap_base: берём ВСЮ аналитику из o + суммы со знаком)
      ВАЖНО: здесь есть accounting_document_type и всё, что нужно дальше.
   ============================================================ */
DROP TABLE IF EXISTS tmp_arap_base;
CREATE TEMP TABLE tmp_arap_base AS
SELECT
    o.*,

    /* суммы со знаком (суффикс _s, чтобы не конфликтовать с o.*) */
    COALESCE(CASE WHEN o.debit_or_credit = 'H' THEN -o.document_currency_amount ELSE o.document_currency_amount END, 0)
        AS document_currency_amount_s,
    COALESCE(CASE WHEN o.debit_or_credit = 'H' THEN -o.local_currency_amount ELSE o.local_currency_amount END, 0)
        AS local_currency_amount_s,
    COALESCE(CASE WHEN o.debit_or_credit = 'H' THEN -o.second_local_currency_amount ELSE o.second_local_currency_amount END, 0)
        AS second_local_currency_amount_s,
    COALESCE(CASE WHEN o.debit_or_credit = 'H' THEN -o.usd_amount ELSE o.usd_amount END, 0)
        AS usd_amount_s,
    CASE WHEN o.debit_or_credit = 'H'
         THEN -o.valuation_difference_second_local_currency_amount
         ELSE  o.valuation_difference_second_local_currency_amount
    END AS valuation_difference_second_local_currency_amount_s
FROM dm_calc.accounting_receivables_and_payables o
LEFT JOIN dict_dds.settings_and_parameters_sap saps
  ON o.unit_balance_code = saps.range_low_value
 AND saps.abap_program_code = '/RUSAL/FI_KHD'
 AND saps.parameter_code = 'INACTBUK'
WHERE
    o.document_currency_code IS NOT NULL
    AND saps.range_low_value IS NULL
    AND o.unit_balance_code !~ '^[A-Za-z]'
    AND o.deleted_flag = false
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   3) tmp_arap_with_reval (аналог receivables_and_payables_with_reval)
   ============================================================ */
DROP TABLE IF EXISTS tmp_arap_with_reval;
CREATE TEMP TABLE tmp_arap_with_reval AS
SELECT
    b.unit_balance_code,
    b.fiscal_year,
    b.accounting_document_code,
    b.position_line_item,
    b.dt_posting,
    b.dt_clearing,

    /* суммы (нормализованные) */
    b.document_currency_amount_s AS document_currency_amount,
    b.local_currency_amount_s AS local_currency_amount,
    b.second_local_currency_amount_s AS second_local_currency_amount,
    b.valuation_difference_second_local_currency_amount_s AS valuation_difference_second_local_currency_amount,
    b.usd_amount_s AS usd_amount,

    /* переоценка */
    r.exchange_diff_local_currency_amount,
    r.exchange_diff_second_local_currency_amount,
    r.dt_posting AS dt_posting_rev
FROM tmp_arap_base b
LEFT JOIN tmp_revaluation_documents r
  ON r.unit_balance_code = b.unit_balance_code
 AND r.fiscal_year = b.fiscal_year
 AND r.accounting_document_code = b.accounting_document_code
 AND r.position_line_item = b.position_line_item
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   4) Ускорение: диапазон периодов по БЕ + фильтр документов до join по датам
   ============================================================ */
DROP TABLE IF EXISTS tmp_periods_range;
CREATE TEMP TABLE tmp_periods_range AS
SELECT
    unit_balance_code,
    MIN(dt) AS min_dt,
    MAX(dt) AS max_dt
FROM tmp_periods
GROUP BY unit_balance_code
DISTRIBUTED BY (unit_balance_code);

DROP TABLE IF EXISTS tmp_arap_with_reval_flt;
CREATE TEMP TABLE tmp_arap_with_reval_flt AS
SELECT a.*
FROM tmp_arap_with_reval a
JOIN tmp_periods_range pr
  ON pr.unit_balance_code = a.unit_balance_code
WHERE
    a.dt_posting <= pr.max_dt
    AND COALESCE(a.dt_clearing, DATE '2299-12-31') > pr.min_dt
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   5) tmp_opening_keys (opening_documents_keys)
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

    /* если dt_posting_rev позже периода — переоценку не учитываем */
    SUM(CASE WHEN (a.dt_posting_rev <= p.dt OR a.dt_posting_rev IS NULL)
             THEN a.exchange_diff_local_currency_amount END) AS exchange_diff_local_currency_amount,
    SUM(CASE WHEN (a.dt_posting_rev <= p.dt OR a.dt_posting_rev IS NULL)
             THEN a.exchange_diff_second_local_currency_amount END) AS exchange_diff_second_local_currency_amount
FROM tmp_arap_with_reval_flt a
JOIN tmp_periods p
  ON p.unit_balance_code = a.unit_balance_code
WHERE
    COALESCE(a.dt_clearing, DATE '2299-12-31') > p.dt
    AND p.dt >= a.dt_posting
GROUP BY
    p.dt, p.is_second_friday,
    a.unit_balance_code, a.fiscal_year, a.accounting_document_code, a.position_line_item
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   6) tmp_opening_documents (opening_documents)
      Берём аналитику из tmp_arap_base, суммы — из tmp_opening_keys,
      final_* — как в старом скрипте
   ============================================================ */
DROP TABLE IF EXISTS tmp_opening_documents;
CREATE TEMP TABLE tmp_opening_documents AS
SELECT
    k.dt,
    k.is_second_friday,

    b.unit_balance_code,
    b.fiscal_year,
    b.accounting_document_code,
    b.position_line_item,

    b.dt_posting,
    b.accounting_document_type,          -- <- поле берется из tmp_arap_base (o.*)
    b.reverse_document_code,
    b.reference_document_number,
    b.accounting_document_status_code,
    b.dt_accounting_document,
    b.document_currency_code,
    b.local_currency_code,
    b.second_local_currency_code,
    b.debit_or_credit,
    b.general_ledger_account_code,
    b.tax_code,
    b.account_type,
    b.position_line_item_text,
    b.clearing_document_code,
    b.dt_clearing,
    b.special_general_ledger_indicator,
    b.counterparty_code,
    b.contract_number,
    b.plant_code,
    b.dt_baseline_due_date_calculation,
    b.terms_of_payment_code,
    b.assignment_number,
    b.reverse_document_fiscal_year,
    b.reason_for_reversal,
    b.invoice_document_code,
    b.fiscal_year_of_relevant_invoice,
    b.position_number_of_relevant_invoice,
    b.reference_procedure,
    b.reference_object_key,

    /* суммы схлопнутые */
    k.document_currency_amount,
    k.local_currency_amount,
    k.second_local_currency_amount,
    k.valuation_difference_second_local_currency_amount,
    k.usd_amount,
    k.exchange_diff_local_currency_amount,
    k.exchange_diff_second_local_currency_amount,

    /* final_* */
    CASE
        WHEN cp2.document_currency_code = b.document_currency_code
         AND cp2.general_ledger_account_code = b.general_ledger_account_code
         AND cp2.debit_or_credit <> b.debit_or_credit
        THEN COALESCE(b.position_number_of_relevant_invoice, b.position_line_item)
        ELSE b.position_line_item
    END AS final_position_line_item,

    CASE
        WHEN cp2.document_currency_code = b.document_currency_code
         AND cp2.general_ledger_account_code = b.general_ledger_account_code
         AND cp2.debit_or_credit <> b.debit_or_credit
        THEN COALESCE(b.fiscal_year_of_relevant_invoice, b.fiscal_year)
        ELSE b.fiscal_year
    END AS final_fiscal_year,

    CASE
        WHEN cp2.document_currency_code = b.document_currency_code
         AND cp2.general_ledger_account_code = b.general_ledger_account_code
         AND cp2.debit_or_credit <> b.debit_or_credit
        THEN COALESCE(b.invoice_document_code, b.accounting_document_code)
        ELSE b.accounting_document_code
    END AS final_accounting_document_code,

    cp2.document_currency_code AS document_currency_code_of_relevant_invoice,
    cp2.general_ledger_account_code AS general_ledger_account_code_of_relevant_invoice,
    cp2.debit_or_credit AS debit_or_credit_code_of_relevant_invoice
FROM tmp_arap_base b
JOIN tmp_opening_keys k
  ON k.unit_balance_code = b.unit_balance_code
 AND k.fiscal_year = b.fiscal_year
 AND k.accounting_document_code = b.accounting_document_code
 AND k.position_line_item = b.position_line_item
LEFT JOIN dm_calc.accounting_receivables_and_payables cp2
  ON cp2.unit_balance_code = b.unit_balance_code
 AND cp2.fiscal_year = b.fiscal_year_of_relevant_invoice
 AND cp2.accounting_document_code = b.invoice_document_code
 AND cp2.position_line_item = b.position_number_of_relevant_invoice
WHERE (cp2.deleted_flag = false OR cp2.deleted_flag IS NULL)
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   7) tmp_opening_documents_no_invoices (anti-join как в старом)
   ============================================================ */
DROP TABLE IF EXISTS tmp_opening_documents_no_invoices;
CREATE TEMP TABLE tmp_opening_documents_no_invoices AS
SELECT o.*
FROM tmp_opening_documents o
WHERE NOT EXISTS (
    SELECT 1
    FROM tmp_opening_documents o2
    WHERE
        o2.dt = o.dt
        AND o2.unit_balance_code = o.unit_balance_code
        AND o2.fiscal_year = o.final_fiscal_year
        AND o2.accounting_document_code = o.final_accounting_document_code
        AND o2.position_line_item = o.final_position_line_item
        AND o2.invoice_document_code IS NULL
        AND o2.document_currency_code = o.document_currency_code_of_relevant_invoice
        AND o2.general_ledger_account_code = o.general_ledger_account_code_of_relevant_invoice
        AND o2.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice
)
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   8) tmp_closing_sum (closing_sum_to_opening_documents)
   ============================================================ */
DROP TABLE IF EXISTS tmp_closing_sum;
CREATE TEMP TABLE tmp_closing_sum AS
SELECT
    o.dt,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,

    SUM(COALESCE(cp.document_currency_amount, 0))::numeric(17,2) AS document_currency_amount,
    SUM(COALESCE(cp.local_currency_amount, 0))::numeric(17,2) AS local_currency_amount,
    SUM(COALESCE(cp.second_local_currency_amount, 0))::numeric(17,2) AS second_local_currency_amount,
    SUM(COALESCE(cp.valuation_difference_second_local_currency_amount, 0))::numeric(17,2) AS valuation_difference_second_local_currency_amount,
    SUM(COALESCE(cp.usd_amount, 0))::numeric(17,2) AS usd_amount,
    SUM(COALESCE(cp.exchange_diff_local_currency_amount, 0))::numeric(17,2) AS exchange_diff_local_currency_amount,
    SUM(COALESCE(cp.exchange_diff_second_local_currency_amount, 0))::numeric(17,2) AS exchange_diff_second_local_currency_amount
FROM tmp_opening_documents_no_invoices o
JOIN tmp_opening_documents cp
  ON cp.dt = o.dt
 AND cp.unit_balance_code = o.unit_balance_code
 AND cp.fiscal_year_of_relevant_invoice = o.fiscal_year
 AND cp.invoice_document_code = o.accounting_document_code
 AND cp.position_number_of_relevant_invoice = o.position_line_item
 AND cp.document_currency_code = o.document_currency_code
 AND cp.general_ledger_account_code = o.general_ledger_account_code
 AND cp.debit_or_credit <> o.debit_or_credit
 AND o.general_ledger_account_code_of_relevant_invoice IS NULL
 AND o.document_currency_code_of_relevant_invoice IS NULL
 AND o.debit_or_credit_code_of_relevant_invoice IS NULL
 AND o.invoice_document_code IS NULL
 AND o.fiscal_year_of_relevant_invoice IS NULL
 AND o.position_number_of_relevant_invoice IS NULL
GROUP BY
    o.dt, o.unit_balance_code, o.fiscal_year, o.accounting_document_code, o.position_line_item
DISTRIBUTED BY (
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item
);


/* ============================================================
   9) INSERT (полный список полей как в старом)
   ============================================================ */
INSERT INTO dm_calc.account_debt_old (
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
    o.plant_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.dt_posting AS dt_debt,
    o.dt_clearing,
    o.contract_number,
    o.counterparty_code,
    o.debit_or_credit,
    o.account_type,
    o.general_ledger_account_code,

    (o.document_currency_amount + COALESCE(cp.document_currency_amount,0))::numeric(17,2) AS debt_balance_document_currency_amount,
    o.document_currency_code,
    (o.local_currency_amount + COALESCE(cp.local_currency_amount,0))::numeric(17,2) AS debt_balance_local_currency_amount,
    o.local_currency_code,
    (o.second_local_currency_amount + COALESCE(cp.second_local_currency_amount,0))::numeric(17,2) AS debt_balance_second_local_currency_amount,

    (
      o.second_local_currency_amount + COALESCE(cp.second_local_currency_amount,0)
      + COALESCE(o.valuation_difference_second_local_currency_amount,0)
      + COALESCE(cp.valuation_difference_second_local_currency_amount,0)
    )::numeric(17,2) AS debt_balance_with_revaluation_diff_second_currency_amount,

    (o.usd_amount + COALESCE(cp.usd_amount,0))::numeric(17,2) AS debt_balance_usd_amount,
    o.second_local_currency_code,

    o.accounting_document_type,
    o.position_line_item,
    o.reverse_document_code,
    o.reference_document_number,
    o.accounting_document_status_code,
    o.clearing_document_code,
    o.tax_code,
    o.position_line_item_text,
    o.special_general_ledger_indicator,
    o.dt_baseline_due_date_calculation,
    o.assignment_number,
    o.dt_accounting_document,
    o.terms_of_payment_code,

    o.document_currency_amount::numeric(17,2) AS document_currency_amount,
    o.local_currency_amount::numeric(17,2) AS local_currency_amount,
    o.second_local_currency_amount::numeric(17,2) AS second_local_currency_amount,
    o.usd_amount::numeric(17,2) AS usd_amount,

    o.reverse_document_fiscal_year,
    o.reason_for_reversal,
    o.invoice_document_code,
    o.fiscal_year_of_relevant_invoice,
    o.position_number_of_relevant_invoice,

    o.final_position_line_item,
    o.final_fiscal_year,
    o.final_accounting_document_code,

    o.document_currency_code_of_relevant_invoice,
    o.general_ledger_account_code_of_relevant_invoice,
    o.debit_or_credit_code_of_relevant_invoice,

    o.reference_procedure AS reference_operation_type_code,
    o.reference_object_key AS reference_object_key_code,

    o.exchange_diff_local_currency_amount::numeric(17,2) AS exchange_diff_local_currency_amount,
    (o.exchange_diff_local_currency_amount + COALESCE(cp.exchange_diff_local_currency_amount,0))::numeric(17,2)
        AS debt_balance_exchange_diff_local_currency_amount,

    o.exchange_diff_second_local_currency_amount::numeric(17,2) AS exchange_diff_second_local_currency_amount,
    (o.exchange_diff_second_local_currency_amount + COALESCE(cp.exchange_diff_second_local_currency_amount,0))::numeric(17,2)
        AS debt_balance_exchange_diff_second_local_currency_amount
FROM tmp_opening_documents_no_invoices o
LEFT JOIN tmp_closing_sum cp
  ON cp.dt = o.dt
 AND cp.unit_balance_code = o.unit_balance_code
 AND cp.fiscal_year = o.fiscal_year
 AND cp.accounting_document_code = o.accounting_document_code
 AND cp.position_line_item = o.position_line_item
WHERE 1=1;


/* ============================================================
   10) Cleanup TEMP tables
   ============================================================ */
DROP TABLE IF EXISTS tmp_closing_sum;
DROP TABLE IF EXISTS tmp_opening_documents_no_invoices;
DROP TABLE IF EXISTS tmp_opening_documents;
DROP TABLE IF EXISTS tmp_opening_keys;
DROP TABLE IF EXISTS tmp_arap_with_reval_flt;
DROP TABLE IF EXISTS tmp_periods_range;
DROP TABLE IF EXISTS tmp_arap_with_reval;
DROP TABLE IF EXISTS tmp_arap_base;
DROP TABLE IF EXISTS tmp_revaluation_documents;
DROP TABLE IF EXISTS tmp_periods;

COMMIT;
