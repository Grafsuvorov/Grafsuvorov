insert into dds.transportation_service_and_accounting_relation
select
	perz.werks as plant_code,
	perz.id as transportation_service_invoice_code,
	perz.pos as transportation_service_invoice_position_code,
	perz.posv as transportation_service_invoice_subposition_code,
	perz.id_doc as payment_request_code,
	perz.pos_doc as payment_request_position_code,
	perz.bukrs as unit_balance_code,
	perz.belnr as accounting_document_code,
	perz.gjahr as accounting_document_fiscal_year,
	perz.vbeln as sales_document_code,
	perz.posnr as sales_document_position_code,
	perz.type as sales_document_type_code
from ods."/rusal/perz_ral" as perz
where perz.werks is not null
  and perz.id is not null;
