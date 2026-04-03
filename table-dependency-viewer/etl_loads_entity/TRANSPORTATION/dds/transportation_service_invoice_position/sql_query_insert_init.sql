insert into dds.transportation_service_invoice_position
select
	perp.werks as plant_code,
	perp.id as transportation_service_invoice_code,
	perp.pos as transportation_service_invoice_position_code,
	perp.srvpos as service_code,
	perp.nomd as transportation_service_invoice_position_object_code,
	perp.sums as position_document_currency_vat_excluded_amount,
	perp.nds as position_document_currency_vat_amount,
	perp.waers as document_currency_code,
	perp.akt_id as adjustment_document_code,
	perp.fistl as funds_center_code,
	perp.etsng as etsng_code,
	perp.ebelny as purchase_contract_code
from ods."/rusal/perp_ral" as perp
where perp.werks is not null
  and perp.id is not null
  and perp.pos is not null
;