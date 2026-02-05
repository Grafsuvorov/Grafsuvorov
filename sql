DROP TABLE IF EXISTS tmp_opening_documents;
CREATE TEMP TABLE tmp_opening_documents AS
SELECT
    k.dt,
    k.is_second_friday,

    -- аналитика документа (БЕЗ сумм)
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,
    o.dt_posting,
    o.dt_clearing,
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

    -- СУММЫ ТОЛЬКО ИЗ k
    k.document_currency_amount,
    k.local_currency_amount,
    k.second_local_currency_amount,
    k.valuation_difference_second_local_currency_amount,
    k.usd_amount,
    k.exchange_diff_local_currency_amount,
    k.exchange_diff_second_local_currency_amount,

    -- final_* логика
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
