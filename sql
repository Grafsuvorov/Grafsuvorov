WITH params AS (
    SELECT
        (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date AS dt_from,
        (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date AS dt_to
),

/* ============================================================
   1. Документы переоценки — агрегируем сразу корректно
   ============================================================ */
revaluation_documents AS (
    SELECT
        unit_balance_code,
        reference_document_fiscal_year::numeric AS fiscal_year,
        reference_document_code AS accounting_document_code,
        reference_document_position_line_item::numeric AS position_line_item,
        MAX(dt_posting) AS last_dt_posting,
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
        reference_document_position_line_item
),

/* ============================================================
   2. База документов задолженности (один проход)
   ============================================================ */
arap_base AS (
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
        END AS usd_amount_s

    FROM dm_calc.accounting_receivables_and_payables o
    LEFT JOIN dict_dds.settings_and_parameters_sap s
        ON o.unit_balance_code = s.range_low_value
       AND s.abap_program_code = '/RUSAL/FI_KHD'
       AND s.parameter_code = 'INACTBUK'
    WHERE
        o.document_currency_code IS NOT NULL
        AND o.unit_balance_code !~ '^[A-Za-z]'
        AND o.deleted_flag = false
        AND s.range_low_value IS NULL
),

/* ============================================================
   3. Календарь — сразу режем по датам
   ============================================================ */
periods AS (
    SELECT st.*
    FROM dm_calc.operating_periods_for_account_debt st
    JOIN params p
        ON st.dt BETWEEN p.dt_from AND p.dt_to
    WHERE st.deleted_flag = false
),

/* ============================================================
   4. Открывающие документы + периоды + final_*
   ============================================================ */
opening_docs AS (
    SELECT
        p.dt,
        p.is_second_friday,

        a.*,

        r.exchange_diff_local_currency_amount,
        r.exchange_diff_second_local_currency_amount,

        /* ===== final_* — КРИТИЧНО ===== */
        CASE
            WHEN cp2.document_currency_code = a.document_currency_code
             AND cp2.general_ledger_account_code = a.general_ledger_account_code
             AND cp2.debit_or_credit <> a.debit_or_credit
            THEN COALESCE(a.position_number_of_relevant_invoice, a.position_line_item)
            ELSE a.position_line_item
        END AS final_position_line_item,

        CASE
            WHEN cp2.document_currency_code = a.document_currency_code
             AND cp2.general_ledger_account_code = a.general_ledger_account_code
             AND cp2.debit_or_credit <> a.debit_or_credit
            THEN COALESCE(a.fiscal_year_of_relevant_invoice, a.fiscal_year)
            ELSE a.fiscal_year
        END AS final_fiscal_year,

        CASE
            WHEN cp2.document_currency_code = a.document_currency_code
             AND cp2.general_ledger_account_code = a.general_ledger_account_code
             AND cp2.debit_or_credit <> a.debit_or_credit
            THEN COALESCE(a.invoice_document_code, a.accounting_document_code)
            ELSE a.accounting_document_code
        END AS final_accounting_document_code,

        cp2.document_currency_code AS document_currency_code_of_relevant_invoice,
        cp2.general_ledger_account_code AS general_ledger_account_code_of_relevant_invoice,
        cp2.debit_or_credit AS debit_or_credit_code_of_relevant_invoice

    FROM arap_base a
    JOIN periods p
        ON p.unit_balance_code = a.unit_balance_code
       AND p.dt >= a.dt_posting
       AND (a.dt_clearing IS NULL OR p.dt < a.dt_clearing)

    LEFT JOIN revaluation_documents r
        ON r.unit_balance_code = a.unit_balance_code
       AND r.fiscal_year = a.fiscal_year
       AND r.accounting_document_code = a.accounting_document_code
       AND r.position_line_item = a.position_line_item

    LEFT JOIN dm_calc.accounting_receivables_and_payables cp2
        ON cp2.unit_balance_code = a.unit_balance_code
       AND cp2.fiscal_year = a.fiscal_year_of_relevant_invoice
       AND cp2.accounting_document_code = a.invoice_document_code
       AND cp2.position_line_item = a.position_number_of_relevant_invoice
       AND cp2.deleted_flag = false
),

/* ============================================================
   5. Исключаем документы, для которых есть ссылочные инвойсы
   ============================================================ */
opening_no_invoice AS (
    SELECT o.*
    FROM opening_docs o
    WHERE NOT EXISTS (
        SELECT 1
        FROM opening_docs x
        WHERE
            x.dt = o.dt
            AND x.unit_balance_code = o.unit_balance_code
            AND x.final_fiscal_year = o.fiscal_year
            AND x.final_accounting_document_code = o.accounting_document_code
            AND x.final_position_line_item = o.position_line_item
            AND x.invoice_document_code IS NULL
            AND x.document_currency_code = o.document_currency_code_of_relevant_invoice
            AND x.general_ledger_account_code = o.general_ledger_account_code_of_relevant_invoice
            AND x.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice
    )
),

/* ============================================================
   6. Закрывающие суммы
   ============================================================ */
closing_sum AS (
    SELECT
        o.dt,
        o.unit_balance_code,
        o.fiscal_year,
        o.accounting_document_code,
        o.position_line_item,

        SUM(cp.document_currency_amount_s) AS document_currency_amount,
        SUM(cp.local_currency_amount_s) AS local_currency_amount,
        SUM(cp.second_local_currency_amount_s) AS second_local_currency_amount,
        SUM(cp.usd_amount_s) AS usd_amount,
        SUM(cp.exchange_diff_local_currency_amount) AS exchange_diff_local_currency_amount,
        SUM(cp.exchange_diff_second_local_currency_amount) AS exchange_diff_second_local_currency_amount

    FROM opening_no_invoice o
    JOIN opening_docs cp
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
        o.position_line_item
)

/* ============================================================
   7. Финальный INSERT
   ============================================================ */
INSERT INTO dm_calc.account_debt_v2
SELECT
    o.dt,
    o.is_second_friday,
    o.unit_balance_code,
    o.plant_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.dt_posting,
    o.dt_clearing,
    o.contract_number,
    o.counterparty_code,
    o.debit_or_credit,
    o.account_type,
    o.general_ledger_account_code,

    (o.document_currency_amount_s + COALESCE(cp.document_currency_amount, 0))::numeric(17,2)
        AS debt_balance_document_currency_amount,

    o.document_currency_code,

    (o.local_currency_amount_s + COALESCE(cp.local_currency_amount, 0))::numeric(17,2)
        AS debt_balance_local_currency_amount,

    o.local_currency_code,

    (o.second_local_currency_amount_s + COALESCE(cp.second_local_currency_amount, 0))::numeric(17,2)
        AS debt_balance_second_local_currency_amount,

    (
        o.second_local_currency_amount_s
        + COALESCE(cp.second_local_currency_amount, 0)
        + COALESCE(o.valuation_difference_second_local_currency_amount, 0)
    )::numeric(17,2) AS debt_balance_with_revaluation_diff_second_currency_amount,

    (o.usd_amount_s + COALESCE(cp.usd_amount, 0))::numeric(17,2)
        AS debt_balance_usd_amount,

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
    o.reference_procedure AS reference_operation_type_code,
    o.reference_object_key AS reference_object_key_code,
    o.exchange_diff_local_currency_amount::numeric(17,2) AS exchange_diff_local_currency_amount,
    (o.exchange_diff_local_currency_amount + COALESCE(cp.exchange_diff_local_currency_amount,0))::numeric(17,2)
        AS debt_balance_exchange_diff_local_currency_amount,
    o.exchange_diff_second_local_currency_amount::numeric(17,2) AS exchange_diff_second_local_currency_amount,
    (o.exchange_diff_second_local_currency_amount + COALESCE(cp.exchange_diff_second_local_currency_amount,0))::numeric(17,2)
        AS debt_balance_exchange_diff_second_local_currency_amount

FROM opening_no_invoice o
LEFT JOIN closing_sum cp
    ON cp.dt = o.dt
   AND cp.unit_balance_code = o.unit_balance_code
   AND cp.fiscal_year = o.fiscal_year
   AND cp.accounting_document_code = o.accounting_document_code
   AND cp.position_line_item = o.position_line_item;
