insert into dds.transportation_service_invoice_subposition
select
	perw.werks as plant_code,
	perw.id as transportation_service_invoice_code,
	perw.pos as transportation_service_invoice_position_code,
	perw.posv as transportation_service_invoice_subposition_code,
	perw.n_plata as subposition_document_currency_vat_excluded_amount,
	perw.nds as subposition_document_currency_vat_amount,
	perw.waers as subposition_document_currency_code,
	perw.ebeln as purchase_contract_code,
	perw.vbeln as delivery_code,
	perw.bl as bill_of_lading_code,
	perw.wwert as dt_currency_translation,
	perw.n_dmbtr as subposition_local_currency_vat_excluded_amount,
	perw.n_hwaer as local_currency_code,
	perw.n_dmbe2 as subposition_second_local_currency_vat_excluded_amount,
	perw.n_hwae2 as second_local_currency_code
from ods."/rusal/perw_ral" as perw
where perw.werks is not null
  and perw.id is not null
  and perw.pos is not null
  and perw.posv is not null
;
