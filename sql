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
