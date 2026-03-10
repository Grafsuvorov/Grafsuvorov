INSERT INTO dm_calc.accounting_receivables_and_payables
(
    unit_balance_code,
    fiscal_year,
    accounting_document_code,
    dt_posting,
    posting_period,
    accounting_document_header_text,
    accounting_document_type,
    reverse_document_code,
    reference_document_number,
    accounting_document_status_code,
    dt_accounting_document,
    document_currency_code,
    local_currency_code,
    second_local_currency_code,
    reference_key_internal_for_document_header_1,
    reference_key_internal_for_document_header_2,
    dttm_accounting_document_created,
    accounting_document_created_by,
    transaction_code,
    exchange_rate,
    dt_currency_translation,
    dt_tax_reporting,
    reverse_document_fiscal_year,
    reason_for_reversal,
    reference_procedure,
    reference_object_key,
    position_line_item,
    debit_or_credit,
    general_ledger_account_code,
    tax_code,
    account_type,
    position_line_item_text,
    clearing_document_code,
    dt_clearing,
    invoice_document_code,
    fiscal_year_of_relevant_invoice,
    position_number_of_relevant_invoice,
    special_general_ledger_indicator,
    contract_number,
    plant_code,
    reference_key_for_line_item_1,
    reference_key_for_line_item_2,
    reference_key_for_line_item_3,
    funds_center_code,
    financial_position_internal_code,
    counterparty_code,
    dt_baseline_due_date_calculation,
    terms_of_payment_code,
    assignment_number,
    payee_or_payer_code,
    is_red_reverse_posting,
    document_currency_amount,
    usd_amount,
    local_currency_amount,
    second_local_currency_amount,
    valuation_difference_second_local_currency_amount
)
WITH cte AS (
    SELECT
        ta.unit_balance_code,
        COALESCE(ccf.currency_rate_type_alternative_code, ta.currency_rate_type_code) AS currency_rate_type_code,
        ccf.currency_from_code,
        ccf.dt_currency_rate_from,
        ccf.dt_currency_rate_to
    FROM dict_dds.unit_balance ta
    LEFT JOIN dict_dds.currency_conversion_factors ccf
        ON ccf.currency_rate_type_code = ta.currency_rate_type_code
            AND ta.additional_local_currency_control_code = '30'
            AND ccf.currency_to_code = 'USD'
    GROUP BY ta.unit_balance_code,
        COALESCE(ccf.currency_rate_type_alternative_code, ta.currency_rate_type_code),
        ccf.currency_from_code,
        ccf.dt_currency_rate_from,
        ccf.dt_currency_rate_to
)
SELECT
    p.unit_balance_code,
    p.fiscal_year,
    p.accounting_document_code,
    p.dt_posting,
    p.posting_period,
    p.accounting_document_header_text,
    p.accounting_document_type,
    p.reverse_document_code,
    p.reference_document_number,
    p.accounting_document_status_code,
    p.dt_accounting_document,
    p.document_currency_code,
    p.local_currency_code,
    p.second_local_currency_code,
    p.reference_key_internal_for_document_header_1,
    p.reference_key_internal_for_document_header_2,
    p.dttm_accounting_document_created,
    p.accounting_document_created_by,
    p.transaction_code,
    p.exchange_rate,
    p.dt_currency_translation,
    p.dt_tax_reporting,
    p.reverse_document_fiscal_year,
    p.reason_for_reversal,
    p.reference_procedure,
    p.reference_object_key,
    p.position_line_item,
    p.debit_or_credit,
    p.general_ledger_account_code,
    p.tax_code,
    p.account_type,
    p.position_line_item_text,
    p.clearing_document_code,
    p.dt_clearing,
    p.invoice_document_code,
    p.fiscal_year_of_relevant_invoice,
    p.position_number_of_relevant_invoice,
    p.special_general_ledger_indicator,
    ltrim(p.contract_number,'0') AS contract_number,
    COALESCE(p.plant_code,wr1.plant_code,wr3.plant_code) AS plant_code,
    p.reference_key_for_line_item_1,
    p.reference_key_for_line_item_2,
    p.reference_key_for_line_item_3,
    p.funds_center_code,
    p.financial_position_internal_code,
    CASE
        WHEN p.account_type = 'D' THEN COALESCE(p.customer_code, p.supplier_code)
        WHEN p.account_type = 'K' THEN COALESCE(p.supplier_code,p.customer_code)
        ELSE NULL
    END AS counterparty_code,
    p.dt_baseline_due_date_calculation,
    p.terms_of_payment_code,
    p.assignment_number,
    p.payee_or_payer_code,
    p.is_red_reverse_posting,
    p.document_currency_amount,
    (p.document_currency_amount
        * COALESCE(r.currency_to_multiplier,1) *
                        CASE
                            WHEN COALESCE(r.currency_rate,1) > 0 THEN COALESCE(r.currency_rate, 1)
                            ELSE 1
                        END
                        /
                        (CASE
                             WHEN COALESCE(r.currency_rate, 1) < 0 THEN ABS(COALESCE(r.currency_rate,1))
                             ELSE 1
                        END * COALESCE(r.currency_from_multiplier, 1)
                        )
    )::NUMERIC(15,2) AS usd_amount,
    p.local_currency_amount,
    p.second_local_currency_amount,
    p.valuation_difference_second_local_currency_amount
FROM ods.accounting_documents AS p
LEFT JOIN dm_calc.plant_by_unit_balance AS wr1
    ON wr1.plant_count > 1
        AND wr1.plant_code = p.reference_key_internal_for_document_header_1
LEFT JOIN dm_calc.plant_by_unit_balance AS wr3
    ON wr3.plant_count > 1
        AND wr3.plant_code = p.reference_key_for_line_item_3
LEFT JOIN cte AS rate_type
    ON rate_type.unit_balance_code = p.unit_balance_code
        AND rate_type.currency_from_code = p.document_currency_code
        AND (rate_type.dt_currency_rate_from <= p.dt_currency_translation
        AND rate_type.dt_currency_rate_to >= p.dt_currency_translation)
LEFT JOIN dict_dds.currency_rates r
    ON r.dt_currency_rate = COALESCE(p.dt_currency_translation, p.dt_posting)
        AND r.currency_from_code = p.document_currency_code
        AND r.deleted_flag = FALSE
        AND r.currency_rate_type_code = COALESCE(rate_type.currency_rate_type_code, 'M')
        AND r.currency_to_code = 'USD'
WHERE 1 = 1
    AND p.deleted_flag = FALSE
    AND p.is_active = TRUE
    AND p.account_type in ('D', 'K')
    AND (p.accounting_document_status_code IS NULL
        OR p.accounting_document_status_code = 'A'
    )
;
