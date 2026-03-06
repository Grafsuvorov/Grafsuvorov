DELETE FROM dm_calc.accounting_receivables_and_payables
WHERE
    (unit_balance_code,
    fiscal_year,
    accounting_document_code,
    position_line_item)
IN (
    SELECT
        unit_balance_code,
        fiscal_year,
        accounting_document_code,
        position_line_item
    FROM ods.accounting_documents
)
;
