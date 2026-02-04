/* ============================================================
   0) Чистим период (как у тебя)
   ============================================================ */
DELETE FROM dm_calc.account_debt
WHERE dt BETWEEN (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date
            AND (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date;

/* ============================================================
   1) Вставка (исправленный вариант с правильным порядком схлопывания)
   ============================================================ */
INSERT INTO dm_calc.account_debt_v2 (
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
WITH params AS (
    SELECT
        (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date AS dt_from,
        (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date AS dt_to
),

/* ============================================================
   A) Документы переоценки: как у тебя (важно: с dt_posting в ключе)
   ============================================================ */
revaluation_documents AS (
    SELECT
        taerr.unit_balance_code,
        taerr.reference_document_fiscal_year::numeric AS reference_document_fiscal_year,
        taerr.reference_document_code,
        taerr.reference_document_position_line_item::numeric AS reference_document_position_line_item,
        taerr.dt_posting,
        COALESCE(SUM(
            CASE WHEN taerr.debit_or_credit = 'H'
                 THEN -taerr.local_currency_amount
                 ELSE  taerr.local_currency_amount
            END
        ), 0) AS exchange_diff_local_currency_amount,
        COALESCE(SUM(
            CASE WHEN taerr.debit_or_credit = 'H'
                 THEN -taerr.second_local_currency_amount
                 ELSE  taerr.second_local_currency_amount
            END
        ), 0) AS exchange_diff_second_local_currency_amount
    FROM dm_calc.accounting_exchange_rate_revaluation_with_document_reference taerr
    WHERE taerr.deleted_flag = false
    GROUP BY
        taerr.unit_balance_code,
        taerr.reference_document_fiscal_year::numeric,
        taerr.reference_document_code,
        taerr.reference_document_position_line_item::numeric,
        taerr.dt_posting
),

/* ============================================================
   B) База документов задолженности (фильтры как у тебя)
   ============================================================ */
arap_base AS (
    SELECT
        o.*,

        -- суммы с учетом знака, как у тебя
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
),

/* ============================================================
   C) Добавляем суммы переоценки (это тот самый "раздувающий" join, как в оригинале)
   ============================================================ */
receivables_and_payables_with_reval AS (
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
        o.valuation_difference_second_local_currency_amount_s AS valuation_difference_second_local_currency_amount,
        o.usd_amount_s AS usd_amount,

        taerr.exchange_diff_local_currency_amount,
        taerr.exchange_diff_second_local_currency_amount,
        taerr.dt_posting AS dt_posting_rev

    FROM arap_base o
    LEFT JOIN revaluation_documents taerr
        ON taerr.unit_balance_code = o.unit_balance_code
       AND taerr.reference_document_fiscal_year = o.fiscal_year
       AND taerr.reference_document_code = o.accounting_document_code
       AND taerr.reference_document_position_line_item = o.position_line_item
),

/* ============================================================
   D) Календарь — режем по периоду СРАЗУ (вместо фильтра в WHERE ниже)
   ============================================================ */
periods AS (
    SELECT st.*
    FROM dm_calc.operating_periods_for_account_debt st
    JOIN params p
      ON st.dt BETWEEN p.dt_from AND p.dt_to
    WHERE st.deleted_flag = false
),

/* ============================================================
   E) Ключи открывающих документов (это критичный "схлоп" до (dt, doc, pos))
      Полностью повторяет твою логику max/sum с условием по dt_posting_rev
   ============================================================ */
opening_documents_keys AS (
    SELECT
        st.dt,
        st.is_second_friday,
        o.unit_balance_code,
        o.fiscal_year,
        o.accounting_document_code,
        o.position_line_item,

        MAX(o.document_currency_amount) AS document_currency_amount,
        MAX(o.local_currency_amount) AS local_currency_amount,
        MAX(o.second_local_currency_amount) AS second_local_currency_amount,
        MAX(o.valuation_difference_second_local_currency_amount) AS valuation_difference_second_local_currency_amount,
        MAX(o.usd_amount) AS usd_amount,

        SUM(CASE
              WHEN (o.dt_posting_rev <= st.dt OR o.dt_posting_rev IS NULL)
              THEN o.exchange_diff_local_currency_amount
              ELSE NULL
            END) AS exchange_diff_local_currency_amount,

        SUM(CASE
              WHEN (o.dt_posting_rev <= st.dt OR o.dt_posting_rev IS NULL)
              THEN o.exchange_diff_second_local_currency_amount
              ELSE NULL
            END) AS exchange_diff_second_local_currency_amount

    FROM receivables_and_payables_with_reval o
    JOIN periods st
      ON o.unit_balance_code = st.unit_balance_code
    WHERE
        COALESCE(o.dt_clearing, DATE '2299-12-31') > st.dt
        AND st.dt >= o.dt_posting
    GROUP BY
        st.dt,
        st.is_second_friday,
        o.unit_balance_code,
        o.fiscal_year,
        o.accounting_document_code,
        o.position_line_item
),

/* ============================================================
   F) Раскидываем аналитику по ключам, считаем final_* (как у тебя)
      Важно: здесь мы не возвращаемся к "сырой" таблице без фильтров —
      берем arap_base, чтобы сохранить эквивалентность твоим фильтрам.
   ============================================================ */
opening_documents AS (
    SELECT
        k.dt,
        k.is_second_friday,

        o.unit_balance_code,
        o.fiscal_year,
        o.accounting_document_code,
        o.position_line_item,

        o.dt_posting,
        o.accounting_document_type,
        o.reverse_document_code,
        o.reference_document_number,
        o.accounting_document_status_code,
        o.dt_accounting_document,
        o.document_currency_code,
        o.local_currency_code,
        o.second_local_currency_code,
        o.debit_or_credit,
        o.general_ledger_account_code,
        o.tax_code,
        o.account_type,
        o.position_line_item_text,
        o.clearing_document_code,
        o.dt_clearing,
        o.special_general_ledger_indicator,
        o.counterparty_code,
        o.contract_number,
        o.plant_code,
        o.dt_baseline_due_date_calculation,
        o.terms_of_payment_code,
        o.assignment_number,
        o.reverse_document_fiscal_year,
        o.reason_for_reversal,
        o.invoice_document_code,
        o.fiscal_year_of_relevant_invoice,
        o.position_number_of_relevant_invoice,
        o.reference_procedure,
        o.reference_object_key,

        -- суммы из ключей (уже схлопнутые)
        k.document_currency_amount,
        k.local_currency_amount,
        k.second_local_currency_amount,
        k.valuation_difference_second_local_currency_amount,
        k.usd_amount,
        k.exchange_diff_local_currency_amount,
        k.exchange_diff_second_local_currency_amount,

        -- final_* (как у тебя)
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

    FROM arap_base o
    JOIN opening_documents_keys k
      ON k.unit_balance_code = o.unit_balance_code
     AND k.fiscal_year = o.fiscal_year
     AND k.accounting_document_code = o.accounting_document_code
     AND k.position_line_item = o.position_line_item

    LEFT JOIN dm_calc.accounting_receivables_and_payables cp2
      ON cp2.unit_balance_code = o.unit_balance_code
     AND cp2.fiscal_year = o.fiscal_year_of_relevant_invoice
     AND cp2.accounting_document_code = o.invoice_document_code
     AND cp2.position_line_item = o.position_number_of_relevant_invoice
    WHERE
      (cp2.deleted_flag = false OR cp2.deleted_flag IS NULL)
),

/* ============================================================
   G) Исключаем документы, для которых есть ссылочные инвойсы
      (как у тебя, но теперь на "схлопнутом" opening_documents)
   ============================================================ */
opening_documents_no_invoices AS (
    SELECT
        o.*
    FROM opening_documents o
    WHERE NOT EXISTS (
        SELECT 1
        FROM opening_documents o2
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
),

/* ============================================================
   H) В разрезе открывающих документов группируем суммы закрывающих (как у тебя)
   ============================================================ */
closing_sum_to_opening_documents AS (
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

    FROM opening_documents_no_invoices o
    JOIN opening_documents cp
      ON cp.dt = o.dt
     AND cp.unit_balance_code = o.unit_balance_code
     AND cp.fiscal_year_of_relevant_invoice = o.fiscal_year
     AND cp.invoice_document_code = o.accounting_document_code
     AND cp.position_number_of_relevant_invoice = o.position_line_item
     AND cp.document_currency_code = o.document_currency_code
     AND cp.general_ledger_account_code = o.general_ledger_account_code
     AND cp.debit_or_credit <> o.debit_or_credit

     -- блок ограничений "только когда у opening нет релевантного инвойса" (как у тебя)
     AND o.general_ledger_account_code_of_relevant_invoice IS NULL
     AND o.document_currency_code_of_relevant_invoice IS NULL
     AND o.debit_or_credit_code_of_relevant_invoice IS NULL
     AND o.invoice_document_code IS NULL
     AND o.fiscal_year_of_relevant_invoice IS NULL
     AND o.position_number_of_relevant_invoice IS NULL

    GROUP BY
        o.dt,
        o.unit_balance_code,
        o.fiscal_year,
        o.accounting_document_code,
        o.position_line_item
)

/* ============================================================
   I) Финальный селект (как у тебя)
   ============================================================ */
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

    (o.exchange_diff_local_currency_amount)::numeric(17,2) AS exchange_diff_local_currency_amount,
    (o.exchange_diff_local_currency_amount + COALESCE(cp.exchange_diff_local_currency_amount,0))::numeric(17,2)
        AS debt_balance_exchange_diff_local_currency_amount,

    (o.exchange_diff_second_local_currency_amount)::numeric(17,2) AS exchange_diff_second_local_currency_amount,
    (o.exchange_diff_second_local_currency_amount + COALESCE(cp.exchange_diff_second_local_currency_amount,0))::numeric(17,2)
        AS debt_balance_exchange_diff_second_local_currency_amount

FROM opening_documents_no_invoices o
LEFT JOIN closing_sum_to_opening_documents cp
  ON cp.dt = o.dt
 AND cp.unit_balance_code = o.unit_balance_code
 AND cp.fiscal_year = o.fiscal_year
 AND cp.accounting_document_code = o.accounting_document_code
 AND cp.position_line_item = o.position_line_item
WHERE 1 = 1;
