/* ============================================================
   0. ПАРАМЕТРЫ ПЕРИОДА
   ============================================================ */
DROP TABLE IF EXISTS tmp_params;
CREATE TEMP TABLE tmp_params AS
SELECT
    (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date AS dt_from,
    (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date AS dt_to;


/* ============================================================
   1. КАЛЕНДАРЬ (СРАЗУ РЕЖЕМ ПО ДАТАМ)
   ============================================================ */
DROP TABLE IF EXISTS tmp_periods;
CREATE TEMP TABLE tmp_periods AS
SELECT
    st.dt,
    st.is_second_friday,
    st.unit_balance_code
FROM dm_calc.operating_periods_for_account_debt st
JOIN tmp_params p
  ON st.dt BETWEEN p.dt_from AND p.dt_to
WHERE st.deleted_flag = false
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   2. ДОКУМЕНТЫ ПЕРЕОЦЕНКИ (АГРЕГАЦИЯ)
   ============================================================ */
DROP TABLE IF EXISTS tmp_revaluation_documents;
CREATE TEMP TABLE tmp_revaluation_documents AS
SELECT
    taerr.unit_balance_code,
    taerr.reference_document_fiscal_year::int AS fiscal_year,
    taerr.reference_document_code,
    taerr.reference_document_position_line_item::int AS position_line_item,
    taerr.dt_posting,

    SUM(
        CASE WHEN taerr.debit_or_credit = 'H'
             THEN -taerr.local_currency_amount
             ELSE  taerr.local_currency_amount
        END
    ) AS exchange_diff_local_currency_amount,

    SUM(
        CASE WHEN taerr.debit_or_credit = 'H'
             THEN -taerr.second_local_currency_amount
             ELSE  taerr.second_local_currency_amount
        END
    ) AS exchange_diff_second_local_currency_amount

FROM dm_calc.accounting_exchange_rate_revaluation_with_document_reference taerr
WHERE taerr.deleted_flag = false
GROUP BY
    taerr.unit_balance_code,
    taerr.reference_document_fiscal_year,
    taerr.reference_document_code,
    taerr.reference_document_position_line_item,
    taerr.dt_posting
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   3. БАЗА AR/AP (НОРМАЛИЗУЕМ ЗНАКИ)
   ============================================================ */
DROP TABLE IF EXISTS tmp_arap_base;
CREATE TEMP TABLE tmp_arap_base AS
SELECT
    o.*,

    CASE WHEN o.debit_or_credit = 'H'
         THEN -o.document_currency_amount
         ELSE  o.document_currency_amount
    END AS document_currency_amount_s,

    CASE WHEN o.debit_or_credit = 'H'
         THEN -o.local_currency_amount
         ELSE  o.local_currency_amount
    END AS local_currency_amount_s,

    CASE WHEN o.debit_or_credit = 'H'
         THEN -o.second_local_currency_amount
         ELSE  o.second_local_currency_amount
    END AS second_local_currency_amount_s,

    CASE WHEN o.debit_or_credit = 'H'
         THEN -o.usd_amount
         ELSE  o.usd_amount
    END AS usd_amount_s,

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
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   4. AR/AP + ПЕРЕОЦЕНКА
   ============================================================ */
DROP TABLE IF EXISTS tmp_arap_with_reval;
CREATE TEMP TABLE tmp_arap_with_reval AS
SELECT
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,
    o.dt_posting,
    o.dt_clearing,

    o.document_currency_amount_s AS document_currency_amount,
    o.local_currency_amount_s AS local_currency_amount,
    o.second_local_currency_amount_s AS second_local_currency_amount,
    o.valuation_difference_second_local_currency_amount_s,
    o.usd_amount_s AS usd_amount,

    r.exchange_diff_local_currency_amount,
    r.exchange_diff_second_local_currency_amount,
    r.dt_posting AS dt_posting_rev

FROM tmp_arap_base o
LEFT JOIN tmp_revaluation_documents r
  ON r.unit_balance_code = o.unit_balance_code
 AND r.fiscal_year = o.fiscal_year
 AND r.reference_document_code = o.accounting_document_code
 AND r.position_line_item = o.position_line_item
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   5. OPENING KEYS (КЛЮЧЕВОЕ СХЛОПЫВАНИЕ)
   ============================================================ */
DROP TABLE IF EXISTS tmp_opening_keys;
CREATE TEMP TABLE tmp_opening_keys AS
SELECT
    p.dt,
    p.is_second_friday,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,

    MAX(o.document_currency_amount) AS document_currency_amount,
    MAX(o.local_currency_amount) AS local_currency_amount,
    MAX(o.second_local_currency_amount) AS second_local_currency_amount,
    MAX(o.valuation_difference_second_local_currency_amount_s) AS valuation_difference_second_local_currency_amount,
    MAX(o.usd_amount) AS usd_amount,

    SUM(
        CASE
            WHEN o.dt_posting_rev IS NULL OR o.dt_posting_rev <= p.dt
            THEN o.exchange_diff_local_currency_amount
        END
    ) AS exchange_diff_local_currency_amount,

    SUM(
        CASE
            WHEN o.dt_posting_rev IS NULL OR o.dt_posting_rev <= p.dt
            THEN o.exchange_diff_second_local_currency_amount
        END
    ) AS exchange_diff_second_local_currency_amount

FROM tmp_arap_with_reval o
JOIN tmp_periods p
  ON p.unit_balance_code = o.unit_balance_code
WHERE
    (o.dt_clearing IS NULL OR o.dt_clearing > p.dt)
    AND p.dt >= o.dt_posting
GROUP BY
    p.dt,
    p.is_second_friday,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   6. OPENING DOCUMENTS (ОБОГАЩЕНИЕ АНАЛИТИКОЙ)
   ============================================================ */
DROP TABLE IF EXISTS tmp_opening_documents;
CREATE TEMP TABLE tmp_opening_documents AS
SELECT
    k.dt,
    k.is_second_friday,
    o.*,

    k.document_currency_amount,
    k.local_currency_amount,
    k.second_local_currency_amount,
    k.valuation_difference_second_local_currency_amount,
    k.usd_amount,
    k.exchange_diff_local_currency_amount,
    k.exchange_diff_second_local_currency_amount,

    CASE
        WHEN cp2.document_currency_code = o.document_currency_code
         AND cp2.general_ledger_account_code = o.general_ledger_account_code
         AND cp2.debit_or_credit <> o.debit_or_credit
        THEN COALESCE(o.position_number_of_relevant_invoice, o.position_line_item)
        ELSE o.position_line_item
    END AS final_position_line_item,

    CASE
        WHEN cp2.document_currency_code = o.document_currency_code
         AND cp2.general_ledger_account_code = o.general_ledger_account_code
         AND cp2.debit_or_credit <> o.debit_or_credit
        THEN COALESCE(o.fiscal_year_of_relevant_invoice, o.fiscal_year)
        ELSE o.fiscal_year
    END AS final_fiscal_year,

    CASE
        WHEN cp2.document_currency_code = o.document_currency_code
         AND cp2.general_ledger_account_code = o.general_ledger_account_code
         AND cp2.debit_or_credit <> o.debit_or_credit
        THEN COALESCE(o.invoice_document_code, o.accounting_document_code)
        ELSE o.accounting_document_code
    END AS final_accounting_document_code,

    cp2.document_currency_code AS document_currency_code_of_relevant_invoice,
    cp2.general_ledger_account_code AS general_ledger_account_code_of_relevant_invoice,
    cp2.debit_or_credit AS debit_or_credit_code_of_relevant_invoice

FROM tmp_arap_base o
JOIN tmp_opening_keys k
  ON k.unit_balance_code = o.unit_balance_code
 AND k.fiscal_year = o.fiscal_year
 AND k.accounting_document_code = o.accounting_document_code
 AND k.position_line_item = o.position_line_item

LEFT JOIN dm_calc.accounting_receivables_and_payables cp2
  ON cp2.unit_balance_code = o.unit_balance_code
 AND cp2.fiscal_year = o.fiscal_year_of_relevant_invoice
 AND cp2.accounting_document_code = o.invoice_document_code
 AND cp2.position_line_item = o.position_number_of_relevant_invoice
 AND cp2.deleted_flag = false
DISTRIBUTED BY (unit_balance_code);


/* ============================================================
   7. ИСКЛЮЧАЕМ ДОКУМЕНТЫ СО ССЫЛОЧНЫМИ ИНВОЙСАМИ
   ============================================================ */
DROP TABLE IF EXISTS tmp_opening_no_invoices;
CREATE TEMP TABLE tmp_opening_no_invoices AS
SELECT o.*
FROM tmp_opening_documents o
WHERE NOT EXISTS (
    SELECT 1
    FROM tmp_opening_documents x
    WHERE
        x.dt = o.dt
        AND x.unit_balance_code = o.unit_balance_code
        AND x.fiscal_year = o.final_fiscal_year
        AND x.accounting_document_code = o.final_accounting_document_code
        AND x.position_line_item = o.final_position_line_item
        AND x.invoice_document_code IS NULL
        AND x.document_currency_code = o.document_currency_code_of_relevant_invoice
        AND x.general_ledger_account_code = o.general_ledger_account_code_of_relevant_invoice
        AND x.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice
);


/* ============================================================
   8. ЗАКРЫВАЮЩИЕ ДОКУМЕНТЫ
   ============================================================ */
DROP TABLE IF EXISTS tmp_closing_sum;
CREATE TEMP TABLE tmp_closing_sum AS
SELECT
    o.dt,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,

    SUM(cp.document_currency_amount) AS document_currency_amount,
    SUM(cp.local_currency_amount) AS local_currency_amount,
    SUM(cp.second_local_currency_amount) AS second_local_currency_amount,
    SUM(cp.valuation_difference_second_local_currency_amount) AS valuation_difference_second_local_currency_amount,
    SUM(cp.usd_amount) AS usd_amount,
    SUM(cp.exchange_diff_local_currency_amount) AS exchange_diff_local_currency_amount,
    SUM(cp.exchange_diff_second_local_currency_amount) AS exchange_diff_second_local_currency_amount

FROM tmp_opening_no_invoices o
JOIN tmp_opening_documents cp
  ON cp.dt = o.dt
 AND cp.unit_balance_code = o.unit_balance_code
 AND cp.fiscal_year_of_relevant_invoice = o.fiscal_year
 AND cp.invoice_document_code = o.accounting_document_code
 AND cp.position_number_of_relevant_invoice = o.position_line_item
 AND cp.debit_or_credit <> o.debit_or_credit
GROUP BY
    o.dt,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item;


/* ============================================================
   9. ФИНАЛЬНАЯ ЗАГРУЗКА В ВИТРИНУ
   ============================================================ */
INSERT INTO dm_calc.account_debt_daily_v00
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

    (o.document_currency_amount + COALESCE(cp.document_currency_amount,0))::numeric(17,2),
    o.document_currency_code,
    (o.local_currency_amount + COALESCE(cp.local_currency_amount,0))::numeric(17,2),
    o.local_currency_code,
    (o.second_local_currency_amount + COALESCE(cp.second_local_currency_amount,0))::numeric(17,2),

    (
        o.second_local_currency_amount
        + COALESCE(cp.second_local_currency_amount,0)
        + COALESCE(o.valuation_difference_second_local_currency_amount,0)
        + COALESCE(cp.valuation_difference_second_local_currency_amount,0)
    )::numeric(17,2),

    (o.usd_amount + COALESCE(cp.usd_amount,0))::numeric(17,2),
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

    o.document_currency_amount,
    o.local_currency_amount,
    o.second_local_currency_amount,
    o.usd_amount,

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

    o.reference_procedure,
    o.reference_object_key,

    o.exchange_diff_local_currency_amount,
    (o.exchange_diff_local_currency_amount + COALESCE(cp.exchange_diff_local_currency_amount,0))::numeric(17,2),
    o.exchange_diff_second_local_currency_amount,
    (o.exchange_diff_second_local_currency_amount + COALESCE(cp.exchange_diff_second_local_currency_amount,0))::numeric(17,2)

FROM tmp_opening_no_invoices o
LEFT JOIN tmp_closing_sum cp
  ON cp.dt = o.dt
 AND cp.unit_balance_code = o.unit_balance_code
 AND cp.fiscal_year = o.fiscal_year
 AND cp.accounting_document_code = o.accounting_document_code
 AND cp.position_line_item = o.position_line_item;
