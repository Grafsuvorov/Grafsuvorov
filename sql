Циклические зависимости сущностей17
Цикл
Сущностей: 12
CYCLE
STG_LOADER
SD_STOCKS
SALES_SHIPMENT_FROM_PLANT
TRANSPORTATION
SALES_MARGIN
DICT_LOADER
…
Взаимозависимость
BI_FI ↔ BI_FI_FACT_PAYMENTS
MUTUAL
BI_FI
↔
BI_FI_FACT_PAYMENTS
Показать таблицы
9 → 0
Взаимозависимость
BI_FI ↔ SALES_MM
MUTUAL
BI_FI
↔
SALES_MM
Скрыть таблицы
4 → 10
Связующие таблицы
BI_FI
→
SALES_MM
dds.accounting_documents[BI_FI]→dm.invoice_to_act_of_completed_work[SALES_MM]
dds.accounting_documents[BI_FI]→dm.invoice_to_act_of_material_acceptence[SALES_MM]
dds.accounting_documents[BI_FI]→dm_calc.accounting_document_header_for_purchase_documents[SALES_MM]
dds.accounting_documents[BI_FI]→dm_calc.accounting_document_tax_classification[SALES_MM]
SALES_MM
→
BI_FI
dds.purchase_agreement_header[SALES_MM, TRANSPORTATION]→dm_calc.accounting_document_contracts[BI_FI]
dds.purchase_agreement_header[SALES_MM, TRANSPORTATION]→dm_calc.accounting_document_header[BI_FI]
dds.purchase_agreement_header[SALES_MM, TRANSPORTATION]→dm_calc.accounting_external_contracts[BI_FI]
dds.purchase_document_counterparty_role[SALES_MM, TRANSPORTATION]→dm_calc.accounting_document_contracts[BI_FI]
dds.purchase_document_counterparty_role[SALES_MM, TRANSPORTATION]→dm_calc.accounting_external_contracts[BI_FI]
dds.purchase_order_header[SALES_MM, TRANSPORTATION]→dm_calc.accounting_document_contracts[BI_FI]
dds.purchase_order_header[SALES_MM, TRANSPORTATION]→dm_calc.accounting_document_header[BI_FI]
dds.purchase_order_header[SALES_MM, TRANSPORTATION]→dm_calc.accounting_external_contracts[BI_FI]
ods.cdhdr_ral[SALES_MM, TRANSPORTATION]→dds.payment_request_approval_history[BI_FI]
ods.cdpos_ral[SALES_MM, TRANSPORTATION]→dds.payment_request_approval_history[BI_FI]
Показать все таблицы
Взаимозависимость
BI_FI_FACT_PAYMENTS ↔ SALES_MM
MUTUAL
BI_FI_FACT_PAYMENTS
↔
SALES_MM
Скрыть таблицы
2 → 9
Связующие таблицы
BI_FI_FACT_PAYMENTS
→
SALES_MM
dds.material_ledger_header[BI_FI_FACT_PAYMENTS, CASE_4]→dm.material_price_calculation[SALES_MM]
dds.material_ledger_header[BI_FI_FACT_PAYMENTS, CASE_4]→dm_calc.material_stock_balance[SALES_MM]
SALES_MM
→
BI_FI_FACT_PAYMENTS
dds.invoice_purchase_document_header[SALES_MM]→dm.investment_expenses_actual[BI_FI_FACT_PAYMENTS]
dds.invoice_purchase_document_header[SALES_MM]→dm_calc.investment_expenses_invoice_purchase_documents[BI_FI_FACT_PAYMENTS]
dds.invoice_purchase_document_position[SALES_MM]→dm_calc.investment_expenses_invoice_purchase_documents[BI_FI_FACT_PAYMENTS]
dds.purchase_agreement_header[SALES_MM, TRANSPORTATION]→dm_calc.investment_expenses_actual_purchase_documents[BI_FI_FACT_PAYMENTS]
dds.purchase_agreement_position[SALES_MM, TRANSPORTATION]→dm_calc.investment_expenses_actual_purchase_documents[BI_FI_FACT_PAYMENTS]
dds.purchase_document_expense_assignment[SALES_MM]→dm_calc.investment_payments_actual_group_01[BI_FI_FACT_PAYMENTS]
dds.purchase_document_revaluation[SALES_MM]→dm.investment_expenses_actual[BI_FI_FACT_PAYMENTS]
dds.purchase_order_header[SALES_MM, TRANSPORTATION]→dm_calc.investment_expenses_actual_purchase_documents[BI_FI_FACT_PAYMENTS]
dds.purchase_order_position[SALES_MM, TRANSPORTATION]→dm_calc.investment_expenses_actual_purchase_documents[BI_FI_FACT_PAYMENTS]
Показать все таблицы
Взаимозависимость
BI_SB_WUC ↔ CASE_4
MUTUAL
BI_SB_WUC
↔
CASE_4
Скрыть таблицы
2 → 1
Связующие таблицы
BI_SB_WUC
→
CASE_4
ods.mseg_ral[BI_SB_WUC]→dm.car_unfactured[CASE_4]
ods.mseg_ral[BI_SB_WUC]→ods.naklvag[CASE_4]
CASE_4
→
BI_SB_WUC
stg.mseg[CASE_4]→ods.mseg_ral[BI_SB_WUC]
