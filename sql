explain
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


Gather Motion 8:1  (slice7; segments: 8)  (cost=0.00..13319247.66 rows=4365914784 width=413)
  ->  Sequence  (cost=0.00..8320089.68 rows=545739348 width=413)
        ->  Shared Scan (share slice:id 7:2)  (cost=0.00..18240.95 rows=4097847 width=1)
              ->  Materialize  (cost=0.00..18240.95 rows=4097847 width=1)
                    ->  Result  (cost=0.00..18236.85 rows=4097847 width=489)
                          ->  Result  (cost=0.00..16233.01 rows=4097847 width=435)
                                Filter: (settings_and_parameters_sap.range_low_value IS NULL)
                                ->  Hash Left Join  (cost=0.00..16096.87 rows=4137875 width=443)
                                      Hash Cond: ((accounting_receivables_and_payables_1.unit_balance_code)::text = (settings_and_parameters_sap.range_low_value)::text)
                                      ->  Seq Scan on accounting_receivables_and_payables accounting_receivables_and_payables_1  (cost=0.00..7354.60 rows=4137875 width=435)
                                            Filter: ((NOT (document_currency_code IS NULL)) AND ((unit_balance_code)::text !~ '^[A-Za-z]'::text) AND (NOT deleted_flag))
                                      ->  Hash  (cost=511.15..511.15 rows=1 width=8)
                                            ->  Seq Scan on settings_and_parameters_sap  (cost=0.00..511.15 rows=1 width=8)
                                                  Filter: (((abap_program_code)::text = '/RUSAL/FI_KHD'::text) AND ((parameter_code)::text = 'INACTBUK'::text))
        ->  Sequence  (cost=0.00..8076458.38 rows=545739348 width=413)
              ->  Shared Scan (share slice:id 7:6)  (cost=0.00..2396472.29 rows=545739348 width=1)
                    ->  Materialize  (cost=0.00..2396472.29 rows=545739348 width=1)
                          ->  Result  (cost=0.00..2395926.55 rows=545739348 width=365)
                                ->  Result  (cost=0.00..2196731.69 rows=545739348 width=318)
                                      Filter: ((NOT accounting_receivables_and_payables.deleted_flag) OR (accounting_receivables_and_payables.deleted_flag IS NULL))
                                      ->  Hash Left Join  (cost=0.00..2178776.87 rows=545739348 width=319)
                                            Hash Cond: (((share2_ref2.unit_balance_code)::text = (accounting_receivables_and_payables.unit_balance_code)::text) AND (share2_ref2.fiscal_year_of_relevant_invoice = accounting_receivables_and_payables.fiscal_year) AND ((share2_ref2.invoice_document_code)::text = (accounting_receivables_and_payables.accounting_document_code)::text) AND (share2_ref2.position_number_of_relevant_invoice = accounting_receivables_and_payables.position_line_item))
                                            ->  Redistribute Motion 8:8  (slice6; segments: 8)  (cost=0.00..1538995.90 rows=4097847 width=301)
                                                  Hash Key: share2_ref2.unit_balance_code, share2_ref2.fiscal_year_of_relevant_invoice, share2_ref2.invoice_document_code, share2_ref2.position_number_of_relevant_invoice
                                                  ->  Hash Join  (cost=0.00..1535135.19 rows=4097847 width=301)
                                                        Hash Cond: (((share2_ref3.unit_balance_code)::text = (share2_ref2.unit_balance_code)::text) AND (share2_ref3.fiscal_year = share2_ref2.fiscal_year) AND ((share2_ref3.accounting_document_code)::text = (share2_ref2.accounting_document_code)::text) AND (share2_ref3.position_line_item = share2_ref2.position_line_item))
                                                        ->  HashAggregate  (cost=0.00..1197060.75 rows=165077013 width=87)
                                                              Group Key: operating_periods_for_account_debt.dt, operating_periods_for_account_debt.is_second_friday, share2_ref3.unit_balance_code, share2_ref3.fiscal_year, share2_ref3.accounting_document_code, share2_ref3.position_line_item
                                                              ->  Hash Join  (cost=0.00..1060497.32 rows=165077013 width=91)
                                                                    Hash Cond: ((share2_ref3.unit_balance_code)::text = (operating_periods_for_account_debt.unit_balance_code)::text)
                                                                    Join Filter: ((COALESCE(share2_ref3.dt_clearing, '2299-12-31'::date) > operating_periods_for_account_debt.dt) AND (operating_periods_for_account_debt.dt >= share2_ref3.dt_posting))
                                                                    ->  Hash Left Join  (cost=0.00..16349.09 rows=4097847 width=94)
                                                                          Hash Cond: (((share2_ref3.unit_balance_code)::text = (accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code)::text) AND (share2_ref3.fiscal_year = accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year) AND ((share2_ref3.accounting_document_code)::text = (accounting_exchange_rate_revaluation_with_document_reference.reference_document_code)::text) AND (share2_ref3.position_line_item = accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item))
                                                                          ->  Shared Scan (share slice:id 6:2)  (cost=0.00..1161.81 rows=4097847 width=74)
                                                                          ->  Hash  (cost=2430.05..2430.05 rows=2218738 width=46)
                                                                                ->  Result  (cost=0.00..2430.05 rows=2218738 width=46)
                                                                                      ->  HashAggregate  (cost=0.00..2327.99 rows=2218738 width=46)
                                                                                            Group Key: accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code, accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year, accounting_exchange_rate_revaluation_with_document_reference.reference_document_code, accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item, accounting_exchange_rate_revaluation_with_document_reference.dt_posting
                                                                                            ->  Seq Scan on accounting_exchange_rate_revaluation_with_document_reference  (cost=0.00..882.34 rows=2218738 width=41)
                                                                                                  Filter: (NOT deleted_flag)
                                                                    ->  Hash  (cost=989540.80..989540.80 rows=32096 width=10)
                                                                          ->  Broadcast Motion 8:8  (slice5; segments: 8)  (cost=0.00..989540.80 rows=32096 width=10)
                                                                                ->  Nested Loop  (cost=0.00..989538.37 rows=4012 width=10)
                                                                                      Join Filter: ((operating_periods_for_account_debt.dt >= "outer".dt_from) AND (operating_periods_for_account_debt.dt <= "outer".dt_to))
                                                                                      ->  Seq Scan on operating_periods_for_account_debt  (cost=0.00..454.36 rows=288863 width=10)
                                                                                            Filter: (NOT deleted_flag)
                                                                                      ->  Materialize  (cost=0.00..0.00 rows=1 width=8)
                                                                                            ->  Result  (cost=0.00..0.00 rows=1 width=8)
                                                                                                  ->  Result  (cost=0.00..0.00 rows=1 width=1)
                                                                                                        One-Time Filter: (gp_execution_segment() = 7)
                                                                                                        ->  Result  (cost=0.00..0.00 rows=1 width=1)
                                                                                                              ->  Result  (cost=0.00..0.00 rows=1 width=1)
                                                        ->  Hash  (cost=2801.19..2801.19 rows=4097847 width=240)
                                                              ->  Shared Scan (share slice:id 6:2)  (cost=0.00..2801.19 rows=4097847 width=240)
                                            ->  Hash  (cost=2985.62..2985.62 rows=10344687 width=44)
                                                  ->  Seq Scan on accounting_receivables_and_payables  (cost=0.00..2985.62 rows=10344687 width=44)
              ->  Sequence  (cost=0.00..5454595.74 rows=545739348 width=413)
                    ->  Shared Scan (share slice:id 7:7)  (cost=0.00..2001989.79 rows=18 width=1)
                          ->  Materialize  (cost=0.00..2001989.79 rows=18 width=1)
                                ->  Hash Anti Join  (cost=0.00..2001989.79 rows=18 width=342)
                                      Hash Cond: ((share6_ref3.dt = share6_ref2.dt) AND ((share6_ref3.unit_balance_code)::text = (share6_ref2.unit_balance_code)::text) AND (share6_ref3.final_fiscal_year = share6_ref2.fiscal_year) AND ((share6_ref3.final_accounting_document_code)::text = (share6_ref2.accounting_document_code)::text) AND (share6_ref3.final_position_line_item = share6_ref2.position_line_item) AND ((share6_ref3.document_currency_code_1)::text = (share6_ref2.document_currency_code)::text) AND ((share6_ref3.general_ledger_account_code_1)::text = (share6_ref2.general_ledger_account_code)::text) AND (share6_ref3.debit_or_credit_1 = share6_ref2.debit_or_credit))
                                      ->  Redistribute Motion 8:8  (slice3; segments: 8)  (cost=0.00..1034432.43 rows=545739348 width=342)
                                            Hash Key: share6_ref3.dt, share6_ref3.unit_balance_code, share6_ref3.final_fiscal_year, share6_ref3.final_accounting_document_code, share6_ref3.final_position_line_item, share6_ref3.document_currency_code_1, share6_ref3.general_ledger_account_code_1, share6_ref3.debit_or_credit_1
                                            ->  Shared Scan (share slice:id 3:6)  (cost=0.00..450240.29 rows=545739348 width=342)
                                      ->  Hash  (cost=94709.45..94709.45 rows=206977 width=47)
                                            ->  Result  (cost=0.00..94709.45 rows=206977 width=47)
                                                  ->  Redistribute Motion 8:8  (slice4; segments: 8)  (cost=0.00..94699.72 rows=206977 width=47)
                                                        Hash Key: share6_ref2.dt, share6_ref2.unit_balance_code, share6_ref2.fiscal_year, share6_ref2.accounting_document_code, share6_ref2.position_line_item, share6_ref2.document_currency_code, share6_ref2.general_ledger_account_code, share6_ref2.debit_or_credit
                                                        ->  Result  (cost=0.00..94669.27 rows=206977 width=47)
                                                              Filter: (share6_ref2.invoice_document_code IS NULL)
                                                              ->  Shared Scan (share slice:id 4:6)  (cost=0.00..76714.45 rows=545739348 width=58)
                    ->  Result  (cost=0.00..3227215.60 rows=545739348 width=413)
                          ->  Hash Left Join  (cost=0.00..2947251.31 rows=545739348 width=398)
                                Hash Cond: ((share7_ref3.dt = share7_ref2.dt) AND ((share7_ref3.unit_balance_code)::text = (share7_ref2.unit_balance_code)::text) AND (share7_ref3.fiscal_year = share7_ref2.fiscal_year) AND ((share7_ref3.accounting_document_code)::text = (share7_ref2.accounting_document_code)::text) AND (share7_ref3.position_line_item = share7_ref2.position_line_item))
                                ->  Shared Scan (share slice:id 7:7)  (cost=0.00..450240.29 rows=545739348 width=342)
                                ->  Hash  (cost=1148883.12..1148883.12 rows=2 width=86)
                                      ->  Broadcast Motion 8:8  (slice2; segments: 8)  (cost=0.00..1148883.12 rows=2 width=86)
                                            ->  Result  (cost=0.00..1148883.12 rows=1 width=86)
                                                  ->  Result  (cost=0.00..1148883.12 rows=1 width=86)
                                                        ->  GroupAggregate  (cost=0.00..1148883.11 rows=1 width=86)
                                                              Group Key: share7_ref2.dt, share7_ref2.unit_balance_code, share7_ref2.fiscal_year, share7_ref2.accounting_document_code, share7_ref2.position_line_item
                                                              ->  Sort  (cost=0.00..1148883.11 rows=1 width=86)
                                                                    Sort Key: share7_ref2.dt, share7_ref2.unit_balance_code, share7_ref2.fiscal_year, share7_ref2.accounting_document_code, share7_ref2.position_line_item
                                                                    ->  Hash Join  (cost=0.00..1148883.11 rows=1 width=86)
                                                                          Hash Cond: ((share6_ref4.dt = share7_ref2.dt) AND ((share6_ref4.unit_balance_code)::text = (share7_ref2.unit_balance_code)::text) AND (share6_ref4.fiscal_year_of_relevant_invoice = share7_ref2.fiscal_year) AND ((share6_ref4.invoice_document_code)::text = (share7_ref2.accounting_document_code)::text) AND (share6_ref4.position_number_of_relevant_invoice = share7_ref2.position_line_item) AND ((share6_ref4.document_currency_code)::text = (share7_ref2.document_currency_code)::text) AND ((share6_ref4.general_ledger_account_code)::text = (share7_ref2.general_ledger_account_code)::text))
                                                                          Join Filter: (share6_ref4.debit_or_credit <> share7_ref2.debit_or_credit)
                                                                          ->  Shared Scan (share slice:id 2:6)  (cost=0.00..135899.88 rows=545739348 width=103)
                                                                          ->  Hash  (cost=219954.65..219954.65 rows=1 width=47)
                                                                                ->  Redistribute Motion 8:8  (slice1; segments: 8)  (cost=0.00..219954.65 rows=1 width=47)
                                                                                      Hash Key: share7_ref2.unit_balance_code, share7_ref2.fiscal_year, share7_ref2.accounting_document_code, share7_ref2.position_line_item
                                                                                      ->  Result  (cost=0.00..219954.65 rows=1 width=47)
                                                                                            Filter: ((share7_ref2.general_ledger_account_code_1 IS NULL) AND (share7_ref2.document_currency_code_1 IS NULL) AND (share7_ref2.debit_or_credit_1 IS NULL) AND (share7_ref2.invoice_document_code IS NULL) AND (share7_ref2.fiscal_year_of_relevant_invoice IS NULL) AND (share7_ref2.position_number_of_relevant_invoice IS NULL))
                                                                                            ->  Shared Scan (share slice:id 1:7)  (cost=0.00..112225.71 rows=545739348 width=85)
Optimizer: Pivotal Optimizer (GPORCA)


старый 
explain
with revaluation_documents as(
---тк при расчете суммы переоценки на дату нужна дата проводки, то агрегируем  и по ней
select
	taerr.unit_balance_code,
	taerr.reference_document_fiscal_year::numeric,
	taerr.reference_document_code,
	taerr.reference_document_position_line_item::numeric,
	taerr.dt_posting,
	coalesce(sum(case
		when taerr.debit_or_credit = 'H' then - taerr.local_currency_amount
		else taerr.local_currency_amount
	 end),0) as exchange_diff_local_currency_amount,
	 coalesce( sum(case
		when taerr.debit_or_credit = 'H' then - taerr.second_local_currency_amount
		 else taerr.second_local_currency_amount
	end),0) as exchange_diff_second_local_currency_amount
from 
	dm_calc.accounting_exchange_rate_revaluation_with_document_reference taerr 
where 
	taerr.deleted_flag = false
group by 
	taerr.unit_balance_code,
	taerr.reference_document_fiscal_year::numeric,
	taerr.reference_document_code,
	taerr.reference_document_position_line_item::numeric,
	taerr.dt_posting),
---готовим связанные данные для последующей агрегации, оставляем только нужные поля
receivables_and_payables_with_reval as (
select 
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
	o.dt_posting,
	o.dt_clearing,
---добавляем суммы
	coalesce(case
		when o.debit_or_credit = 'H' then - o.document_currency_amount
		else o.document_currency_amount
	end,0) as document_currency_amount,
	coalesce(case
		when o.debit_or_credit = 'H' then - o.local_currency_amount
		else o.local_currency_amount
	end,0) as local_currency_amount,
	coalesce(case
		when o.debit_or_credit = 'H' then - o.second_local_currency_amount
		else o.second_local_currency_amount
	end,0) as second_local_currency_amount,
	case
		when o.debit_or_credit = 'H' then - o.valuation_difference_second_local_currency_amount
		else o.valuation_difference_second_local_currency_amount
	end as valuation_difference_second_local_currency_amount,
	coalesce(case
		when o.debit_or_credit = 'H' then - o.usd_amount
		else o.usd_amount
	end,0) as usd_amount,
	----суммы из документов переоценки
	taerr.exchange_diff_local_currency_amount,
	taerr.exchange_diff_second_local_currency_amount,
	taerr.dt_posting as dt_posting_rev
from --документы задолженности
	dm_calc.accounting_receivables_and_payables o
left join revaluation_documents taerr on 
	---документы переоценки
	taerr.unit_balance_code = o.unit_balance_code  and 
	taerr.reference_document_fiscal_year = o.fiscal_year  and 
	taerr.reference_document_code  = o.accounting_document_code and 
	taerr.reference_document_position_line_item = o.position_line_item 
left join dict_dds.settings_and_parameters_sap saps on 
	----перечень БЕ, которые считаются неактивными  и для которых расчеты не нужны
	o.unit_balance_code=saps.range_low_value
	and saps.abap_program_code = '/RUSAL/FI_KHD'
	and saps.parameter_code = 'INACTBUK'
where
---документы с пустой валютой документа - битые
	o.document_currency_code is not null
	and saps.range_low_value is null 
	and o.unit_balance_code !~'^[A-Za-z]'
	and o.deleted_flag = false),
---документы, открывающие задолженность, ключи по дням +агрегированные суммы
opening_documents_keys as (
select 
	st.dt as dt,	
	st.is_second_friday,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
---добавляем суммы для документов из dm_calcберем max, тк они замножены на документы переоценки, переоценку суммируем
	max(o.document_currency_amount) as document_currency_amount ,
	max(o.local_currency_amount) as local_currency_amount,
	max(o.second_local_currency_amount) as second_local_currency_amount,
	max(o.valuation_difference_second_local_currency_amount) as valuation_difference_second_local_currency_amount,
	max(o.usd_amount) as usd_amount,
	---если в переоценке неподходящая дата проводки документа переоценки, то это не повод не брать сумму по документу, но в сумме переоценки тогда не учитываем
	sum(case when (o.dt_posting_rev <=st.dt or o.dt_posting_rev is null) then o.exchange_diff_local_currency_amount else null end) as exchange_diff_local_currency_amount,
	sum(case when (o.dt_posting_rev <=st.dt or o.dt_posting_rev is null) then o.exchange_diff_second_local_currency_amount else null end) as exchange_diff_second_local_currency_amount	
from 
 	receivables_and_payables_with_reval as o	
join dm_calc.operating_periods_for_account_debt st on 
	o.unit_balance_code = st.unit_balance_code 
where
	1 = 1			
	---документы с пустой валютой документа - битые
	and coalesce(o.dt_clearing,'2299-12-31') > st.dt
	and st.dt >= o.dt_posting
	and (st.dt >= (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date
     and st.dt <=  (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date)
	and st.deleted_flag = false
group by 
	st.dt,
	st.is_second_friday,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item
),
opening_documents  as (
select 
	o2.dt as dt,
	o2.is_second_friday,
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
---добавляем суммы
	o2.document_currency_amount,
	o2.local_currency_amount,
	o2.second_local_currency_amount,
	o2.valuation_difference_second_local_currency_amount,
	o2.usd_amount,
	o2.exchange_diff_local_currency_amount,
	o2.exchange_diff_second_local_currency_amount,
	case 
		when cp2.document_currency_code = o.document_currency_code 
			and cp2.general_ledger_account_code = o.general_ledger_account_code
			and cp2.debit_or_credit <> o.debit_or_credit 
		then  coalesce (o.position_number_of_relevant_invoice, o.position_line_item)
		else o.position_line_item end as final_position_line_item ,
	
	case 
		when cp2.document_currency_code = o.document_currency_code 
			and cp2.general_ledger_account_code = o.general_ledger_account_code 
			and cp2.debit_or_credit <> o.debit_or_credit 
		then  coalesce (o.fiscal_year_of_relevant_invoice, o.fiscal_year)  
		else o.fiscal_year end  as final_fiscal_year,
	
	case 
		when cp2.document_currency_code = o.document_currency_code 
			and cp2.general_ledger_account_code = o.general_ledger_account_code
			and cp2.debit_or_credit <> o.debit_or_credit 
		then  coalesce (o.invoice_document_code, o.accounting_document_code) 
		else o.accounting_document_code end as final_accounting_document_code,
			
	cp2.document_currency_code as document_currency_code_of_relevant_invoice,
	cp2.general_ledger_account_code as general_ledger_account_code_of_relevant_invoice,
	cp2.debit_or_credit as debit_or_credit_code_of_relevant_invoice
from 
---раскидываем все аналатики документов задолженности по ключам, доопределяем финальные реквизиты документов
 	dm_calc.accounting_receivables_and_payables as o	
join opening_documents_keys as o2 on 
	o2.unit_balance_code = o.unit_balance_code 
	and o2.fiscal_year = o.fiscal_year
	and  o2.accounting_document_code = o.accounting_document_code
	and  o2.position_line_item = o.position_line_item 
left join dm_calc.accounting_receivables_and_payables cp2 on
	cp2.unit_balance_code = o.unit_balance_code
	and cp2.fiscal_year = o.fiscal_year_of_relevant_invoice 
	and  cp2.accounting_document_code = o.invoice_document_code 
	and  cp2.position_line_item = o.position_number_of_relevant_invoice 
where
	1 = 1		
	and (cp2.deleted_flag = false or cp2.deleted_flag  is null)
),
----исключаем документы, для которых есть ссылочные инвойсы
opening_documents_no_invoices as (
select 
	o.dt,
	o.is_second_friday,
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
	o.document_currency_amount,
	o.local_currency_amount,
	o.second_local_currency_amount,
	o.valuation_difference_second_local_currency_amount,
	o.usd_amount,
	o.exchange_diff_local_currency_amount,
	o.exchange_diff_second_local_currency_amount,
	o.final_position_line_item ,
	o.final_fiscal_year,
	o.final_accounting_document_code,		
	o.document_currency_code_of_relevant_invoice,
	o.general_ledger_account_code_of_relevant_invoice,
	o.debit_or_credit_code_of_relevant_invoice
from opening_documents o
----по плану запроса как будто джойн потребит больше памяти, хотя нет loop
----по времени работают одинаково
/*left join opening_documents o2 on 
	o2.dt = o.dt
	and o2.unit_balance_code =   o.unit_balance_code 
	and o2.fiscal_year = o.final_fiscal_year
	and o2.accounting_document_code =o.final_accounting_document_code 
	and o2.position_line_item = o.final_position_line_item 
	and o2.invoice_document_code is null
	and o2.document_currency_code = o.document_currency_code_of_relevant_invoice 	  
	and o2.general_ledger_account_code  = o.general_ledger_account_code_of_relevant_invoice 
	and o2.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice
where o2.dt is  null*/
where 1=1
	and (not  exists(
		  select  1
		  from 
		  	opening_documents   o2
		  where 1 = 1
			  and o2.dt = o.dt
			  and o2.unit_balance_code =   o.unit_balance_code 
			  and o2.fiscal_year = o.final_fiscal_year
			  and o2.accounting_document_code =o.final_accounting_document_code 
			  and o2.position_line_item = o.final_position_line_item 
			  and o2.invoice_document_code is null
			  and o2.document_currency_code = o.document_currency_code_of_relevant_invoice 	  
			  and o2.general_ledger_account_code  = o.general_ledger_account_code_of_relevant_invoice 
		      and o2.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice))),
--в разрезе открывающих документов группируем суммы закрывающих документов
closing_sum_to_opening_documents as (
select
	o.dt,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
	sum(coalesce(cp.document_currency_amount, 0))::numeric(17,2) as document_currency_amount,
	sum(coalesce(cp.local_currency_amount, 0))::numeric(17,2) as local_currency_amount, 
	sum(coalesce(cp.second_local_currency_amount, 0))::numeric(17,2) as second_local_currency_amount,
	sum(coalesce(cp.valuation_difference_second_local_currency_amount, 0))::numeric(17,2) as valuation_difference_second_local_currency_amount,
	sum(coalesce(cp.usd_amount, 0))::numeric(17,2) as usd_amount,
	sum(coalesce (cp.exchange_diff_local_currency_amount,0))::numeric(17,2) as exchange_diff_local_currency_amount,
	sum(coalesce (cp.exchange_diff_second_local_currency_amount ,0))::numeric(17,2) as exchange_diff_second_local_currency_amount
from 
	opening_documents_no_invoices o
join opening_documents cp on
	cp.dt = o.dt
	and cp.unit_balance_code = o.unit_balance_code
	and cp.fiscal_year_of_relevant_invoice = o.fiscal_year
	and cp.invoice_document_code = o.accounting_document_code
	and cp.position_number_of_relevant_invoice = o.position_line_item
	and cp.document_currency_code = o.document_currency_code
	and cp.general_ledger_account_code = o.general_ledger_account_code 
	and cp.debit_or_credit <> o.debit_or_credit
	and o.general_ledger_account_code_of_relevant_invoice is null 
	and o.document_currency_code_of_relevant_invoice is null 
	and o.debit_or_credit_code_of_relevant_invoice is null
	and o.invoice_document_code is  null
	and o.fiscal_year_of_relevant_invoice is   null
	and	o.position_number_of_relevant_invoice is  null
where
	1 = 1		
group by
	o.dt,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item
)
---джойним открывающие с закрывающими, считаем сумму непогашенной задолженности и переоценки
 select
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
	(o.document_currency_amount + coalesce(cp.document_currency_amount,0))::numeric(17,2) as debt_balance_document_currency_amount,
	o.document_currency_code,
	(o.local_currency_amount + coalesce(cp.local_currency_amount,0))::numeric(17,2) as debt_balance_local_currency_amount,	
	o.local_currency_code,
	(o.second_local_currency_amount + coalesce(cp.second_local_currency_amount,0))::numeric(17,2) as debt_balance_second_local_currency_amount,
	(o.second_local_currency_amount + coalesce(cp.second_local_currency_amount,0) +
	coalesce(o.valuation_difference_second_local_currency_amount, 0) +coalesce(cp.valuation_difference_second_local_currency_amount,0))::numeric(17,2) as debt_balance_with_revaluation_diff_second_currency_amount,
	(o.usd_amount + coalesce(cp.usd_amount,0))::numeric(17,2) as debt_balance_usd_amount,
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
	o.final_position_line_item ,
	o.final_fiscal_year,
	o.final_accounting_document_code,
	o.document_currency_code_of_relevant_invoice,
	o.general_ledger_account_code_of_relevant_invoice,
	o.debit_or_credit_code_of_relevant_invoice,
	o.reference_procedure as reference_operation_type_code,
	o.reference_object_key as reference_object_key_code,
	(o.exchange_diff_local_currency_amount)::numeric(17,2) as exchange_diff_local_currency_amount,
	(o.exchange_diff_local_currency_amount + coalesce(cp.exchange_diff_local_currency_amount,0))::numeric(17,2) as debt_balance_exchange_diff_local_currency_amount,
	(o.exchange_diff_second_local_currency_amount)::numeric(17,2) as exchange_diff_second_local_currency_amount,
	(o.exchange_diff_second_local_currency_amount + coalesce(cp.exchange_diff_second_local_currency_amount,0) )::numeric(17,2) as debt_balance_exchange_diff_second_local_currency_amount
from 
	opening_documents_no_invoices o
left join closing_sum_to_opening_documents cp on
	cp.dt = o.dt
	and cp.unit_balance_code = o.unit_balance_code
	and cp.fiscal_year = o.fiscal_year
	and cp.accounting_document_code = o.accounting_document_code
	and cp.position_line_item = o.position_line_item
where
	1 = 1;


Gather Motion 8:1  (slice6; segments: 8)  (cost=0.00..29426611.07 rows=11019337106 width=413)
  ->  Sequence  (cost=0.00..16809001.76 rows=1377417139 width=413)
        ->  Shared Scan (share slice:id 6:3)  (cost=0.00..2340792.64 rows=1377417139 width=1)
              ->  Materialize  (cost=0.00..2340792.64 rows=1377417139 width=1)
                    ->  Result  (cost=0.00..2339415.22 rows=1377417139 width=365)
                          ->  Result  (cost=0.00..1836657.96 rows=1377417139 width=335)
                                Filter: ((NOT accounting_receivables_and_payables_2.deleted_flag) OR (accounting_receivables_and_payables_2.deleted_flag IS NULL))
                                ->  Hash Left Join  (cost=0.00..1791340.94 rows=1377417139 width=336)
                                      Hash Cond: (((accounting_receivables_and_payables.unit_balance_code)::text = (accounting_receivables_and_payables_2.unit_balance_code)::text) AND (accounting_receivables_and_payables.fiscal_year_of_relevant_invoice = accounting_receivables_and_payables_2.fiscal_year) AND ((accounting_receivables_and_payables.invoice_document_code)::text = (accounting_receivables_and_payables_2.accounting_document_code)::text) AND (accounting_receivables_and_payables.position_number_of_relevant_invoice = accounting_receivables_and_payables_2.position_line_item))
                                      ->  Redistribute Motion 8:8  (slice5; segments: 8)  (cost=0.00..125021.90 rows=10344687 width=318)
                                            Hash Key: accounting_receivables_and_payables.unit_balance_code, accounting_receivables_and_payables.fiscal_year_of_relevant_invoice, accounting_receivables_and_payables.invoice_document_code, accounting_receivables_and_payables.position_number_of_relevant_invoice
                                            ->  Hash Join  (cost=0.00..114725.42 rows=10344687 width=318)
                                                  Hash Cond: (((accounting_receivables_and_payables.unit_balance_code)::text = (accounting_receivables_and_payables_1.unit_balance_code)::text) AND (accounting_receivables_and_payables.fiscal_year = accounting_receivables_and_payables_1.fiscal_year) AND ((accounting_receivables_and_payables.accounting_document_code)::text = (accounting_receivables_and_payables_1.accounting_document_code)::text) AND (accounting_receivables_and_payables.position_line_item = accounting_receivables_and_payables_1.position_line_item))
                                                  ->  Seq Scan on accounting_receivables_and_payables  (cost=0.00..2985.62 rows=10344687 width=257)
                                                  ->  Hash  (cost=39015.78..39015.78 rows=11828115 width=87)
                                                        ->  HashAggregate  (cost=0.00..39015.78 rows=11828115 width=87)
                                                              Group Key: operating_periods_for_account_debt.dt, operating_periods_for_account_debt.is_second_friday, accounting_receivables_and_payables_1.unit_balance_code, accounting_receivables_and_payables_1.fiscal_year, accounting_receivables_and_payables_1.accounting_document_code, accounting_receivables_and_payables_1.position_line_item
                                                              ->  Hash Join  (cost=0.00..29230.72 rows=11828115 width=91)
                                                                    Hash Cond: ((accounting_receivables_and_payables_1.unit_balance_code)::text = (operating_periods_for_account_debt.unit_balance_code)::text)
                                                                    Join Filter: ((COALESCE(accounting_receivables_and_payables_1.dt_clearing, '2299-12-31'::date) > operating_periods_for_account_debt.dt) AND (operating_periods_for_account_debt.dt >= accounting_receivables_and_payables_1.dt_posting))
                                                                    ->  Result  (cost=0.00..22991.27 rows=4093770 width=94)
                                                                          ->  Result  (cost=0.00..22606.46 rows=4093770 width=87)
                                                                                Filter: (settings_and_parameters_sap.range_low_value IS NULL)
                                                                                ->  Hash Left Join  (cost=0.00..22470.32 rows=4137875 width=95)
                                                                                      Hash Cond: ((accounting_receivables_and_payables_1.unit_balance_code)::text = (settings_and_parameters_sap.range_low_value)::text)
                                                                                      ->  Hash Left Join  (cost=0.00..19644.93 rows=4137875 width=87)
                                                                                            Hash Cond: (((accounting_receivables_and_payables_1.unit_balance_code)::text = (accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code)::text) AND (accounting_receivables_and_payables_1.fiscal_year = accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year) AND ((accounting_receivables_and_payables_1.accounting_document_code)::text = (accounting_exchange_rate_revaluation_with_document_reference.reference_document_code)::text) AND (accounting_receivables_and_payables_1.position_line_item = accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item))
                                                                                            ->  Seq Scan on accounting_receivables_and_payables accounting_receivables_and_payables_1  (cost=0.00..4560.79 rows=4137875 width=67)
                                                                                                  Filter: ((NOT (document_currency_code IS NULL)) AND ((unit_balance_code)::text !~ '^[A-Za-z]'::text) AND (NOT deleted_flag))
                                                                                            ->  Hash  (cost=2430.05..2430.05 rows=2218738 width=46)
                                                                                                  ->  Result  (cost=0.00..2430.05 rows=2218738 width=46)
                                                                                                        ->  HashAggregate  (cost=0.00..2327.99 rows=2218738 width=46)
                                                                                                              Group Key: accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code, accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year, accounting_exchange_rate_revaluation_with_document_reference.reference_document_code, accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item, accounting_exchange_rate_revaluation_with_document_reference.dt_posting
                                                                                                              ->  Seq Scan on accounting_exchange_rate_revaluation_with_document_reference  (cost=0.00..882.34 rows=2218738 width=41)
                                                                                                                    Filter: (NOT deleted_flag)
                                                                                      ->  Hash  (cost=511.15..511.15 rows=1 width=8)
                                                                                            ->  Seq Scan on settings_and_parameters_sap  (cost=0.00..511.15 rows=1 width=8)
                                                                                                  Filter: (((abap_program_code)::text = '/RUSAL/FI_KHD'::text) AND ((parameter_code)::text = 'INACTBUK'::text))
                                                                    ->  Hash  (cost=458.00..458.00 rows=2303 width=10)
                                                                          ->  Seq Scan on operating_periods_for_account_debt  (cost=0.00..458.00 rows=2303 width=10)
                                                                                Filter: ((dt >= '2025-12-31'::date) AND (dt <= '2026-02-28'::date) AND (NOT deleted_flag))
                                      ->  Hash  (cost=2985.62..2985.62 rows=10344687 width=44)
                                            ->  Seq Scan on accounting_receivables_and_payables accounting_receivables_and_payables_2  (cost=0.00..2985.62 rows=10344687 width=44)
        ->  Sequence  (cost=0.00..13899335.85 rows=1377417139 width=413)
              ->  Shared Scan (share slice:id 6:4)  (cost=0.00..5096477.90 rows=45 width=1)
                    ->  Materialize  (cost=0.00..5096477.90 rows=45 width=1)
                          ->  Hash Anti Join  (cost=0.00..5096477.90 rows=45 width=342)
                                Hash Cond: ((share3_ref3.dt = share3_ref2.dt) AND ((share3_ref3.unit_balance_code)::text = (share3_ref2.unit_balance_code)::text) AND (share3_ref3.final_fiscal_year = share3_ref2.fiscal_year) AND ((share3_ref3.final_accounting_document_code)::text = (share3_ref2.accounting_document_code)::text) AND (share3_ref3.final_position_line_item = share3_ref2.position_line_item) AND ((share3_ref3.document_currency_code_1)::text = (share3_ref2.document_currency_code)::text) AND ((share3_ref3.general_ledger_account_code_1)::text = (share3_ref2.general_ledger_account_code)::text) AND (share3_ref3.debit_or_credit_1 = share3_ref2.debit_or_credit))
                                ->  Redistribute Motion 8:8  (slice3; segments: 8)  (cost=0.00..2610195.70 rows=1377417139 width=342)
                                      Hash Key: share3_ref3.dt, share3_ref3.unit_balance_code, share3_ref3.final_fiscal_year, share3_ref3.final_accounting_document_code, share3_ref3.final_position_line_item, share3_ref3.document_currency_code_1, share3_ref3.general_ledger_account_code_1, share3_ref3.debit_or_credit_1
                                      ->  Shared Scan (share slice:id 3:3)  (cost=0.00..1135725.75 rows=1377417139 width=342)
                                ->  Hash  (cost=283660.24..283660.24 rows=308224 width=47)
                                      ->  Result  (cost=0.00..283660.24 rows=308224 width=47)
                                            ->  Redistribute Motion 8:8  (slice4; segments: 8)  (cost=0.00..283645.76 rows=308224 width=47)
                                                  Hash Key: share3_ref2.dt, share3_ref2.unit_balance_code, share3_ref2.fiscal_year, share3_ref2.accounting_document_code, share3_ref2.position_line_item, share3_ref2.document_currency_code, share3_ref2.general_ledger_account_code, share3_ref2.debit_or_credit
                                                  ->  Result  (cost=0.00..283600.42 rows=308224 width=47)
                                                        Filter: ((share3_ref2.invoice_document_code IS NULL) AND (share3_ref2.dt >= '2025-12-31'::date) AND (share3_ref2.dt <= '2026-02-28'::date))
                                                        ->  Shared Scan (share slice:id 4:3)  (cost=0.00..192966.37 rows=1377417139 width=58)
              ->  Result  (cost=0.00..8233984.67 rows=1377417139 width=413)
                    ->  Hash Left Join  (cost=0.00..7527369.68 rows=1377417139 width=398)
                          Hash Cond: ((share4_ref3.dt = share4_ref2.dt) AND ((share4_ref3.unit_balance_code)::text = (share4_ref2.unit_balance_code)::text) AND (share4_ref3.fiscal_year = share4_ref2.fiscal_year) AND ((share4_ref3.accounting_document_code)::text = (share4_ref2.accounting_document_code)::text) AND (share4_ref3.position_line_item = share4_ref2.position_line_item))
                          ->  Shared Scan (share slice:id 6:4)  (cost=0.00..1135725.75 rows=1377417139 width=342)
                          ->  Hash  (cost=2989040.49..2989040.49 rows=74 width=86)
                                ->  Broadcast Motion 8:8  (slice2; segments: 8)  (cost=0.00..2989040.49 rows=74 width=86)
                                      ->  Result  (cost=0.00..2989040.44 rows=10 width=86)
                                            ->  Result  (cost=0.00..2989040.44 rows=10 width=86)
                                                  ->  HashAggregate  (cost=0.00..2989040.44 rows=58 width=86)
                                                        Group Key: share4_ref2.dt, share4_ref2.unit_balance_code, share4_ref2.fiscal_year, share4_ref2.accounting_document_code, share4_ref2.position_line_item
                                                        ->  Hash Join  (cost=0.00..2989040.40 rows=58 width=86)
                                                              Hash Cond: ((share3_ref4.dt = share4_ref2.dt) AND ((share3_ref4.unit_balance_code)::text = (share4_ref2.unit_balance_code)::text) AND (share3_ref4.fiscal_year_of_relevant_invoice = share4_ref2.fiscal_year) AND ((share3_ref4.invoice_document_code)::text = (share4_ref2.accounting_document_code)::text) AND (share3_ref4.position_number_of_relevant_invoice = share4_ref2.position_line_item) AND ((share3_ref4.document_currency_code)::text = (share4_ref2.document_currency_code)::text) AND ((share3_ref4.general_ledger_account_code)::text = (share4_ref2.general_ledger_account_code)::text))
                                                              Join Filter: (share3_ref4.debit_or_credit <> share4_ref2.debit_or_credit)
                                                              ->  Result  (cost=0.00..387664.28 rows=1377417139 width=103)
                                                                    Filter: ((share3_ref4.dt >= '2025-12-31'::date) AND (share3_ref4.dt <= '2026-02-28'::date))
                                                                    ->  Shared Scan (share slice:id 2:3)  (cost=0.00..342347.26 rows=1377417139 width=103)
                                                              ->  Hash  (cost=599814.07..599814.07 rows=1 width=47)
                                                                    ->  Redistribute Motion 8:8  (slice1; segments: 8)  (cost=0.00..599814.07 rows=1 width=47)
                                                                          Hash Key: share4_ref2.unit_balance_code, share4_ref2.fiscal_year, share4_ref2.accounting_document_code, share4_ref2.position_line_item
                                                                          ->  Result  (cost=0.00..599814.07 rows=1 width=47)
                                                                                Filter: ((share4_ref2.general_ledger_account_code_1 IS NULL) AND (share4_ref2.document_currency_code_1 IS NULL) AND (share4_ref2.debit_or_credit_1 IS NULL) AND (share4_ref2.invoice_document_code IS NULL) AND (share4_ref2.fiscal_year_of_relevant_invoice IS NULL) AND (share4_ref2.position_number_of_relevant_invoice IS NULL) AND (share4_ref2.dt >= '2025-12-31'::date) AND (share4_ref2.dt <= '2026-02-28'::date) AND (share4_ref2.dt >= '2025-12-31'::date) AND (share4_ref2.dt <= '2026-02-28'::date))
                                                                                ->  Shared Scan (share slice:id 1:4)  (cost=0.00..282594.90 rows=1377417139 width=85)
Optimizer: Pivotal Optimizer (GPORCA)
