insert into dds.transportation_service_and_accounting_relation_history
select
	perf.werks as plant_code,
	perf.id as transportation_service_invoice_code,
	perf.pos as transportation_service_invoice_position_code,
	perf.bukrs as unit_balance_code,
	perf.belnr as accounting_document_code,
	perf.gjahr as accounting_document_fiscal_year,
	perf.vbeln as sales_document_code,
	perf.posnr as sales_document_position_code,
	perf.type as sales_document_type_code
from ods."/rusal/perf_ral" as perf
where perf.werks is not null
  and perf.id is not null
;
