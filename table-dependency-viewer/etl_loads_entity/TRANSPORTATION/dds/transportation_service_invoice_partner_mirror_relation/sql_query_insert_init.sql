insert into dds.transportation_service_invoice_partner_mirror_relation
select
	mirr.bukrs as unit_balance_code,
	mirr.belnr as accounting_document_code,
	mirr.gjahr as accounting_document_fiscal_year,
	mirp.zbukrs as mirror_accounting_document_unit_balance_code,
	mirp.zbelnr as mirror_accounting_document_code,
	mirp.zgjahr as mirror_accounting_document_fiscal_year,
	mirr.awtyp as reference_operation_type_code,
	mirr.awkey as reference_object_key,
	mirp.zblart as mirror_accounting_document_type_code,
	mirp.zstblg	as reverse_document_of_mirror_accounting_document_code	
from ods."/rusal/mirr_ral" as mirr
	join ods."/rusal/mirp_ral" as mirp
		on mirp.awtyp = mirr.awtyp and
	   	   mirp.awkey = mirr.awkey 
where mirr.awtyp is not null
  and mirr.awkey is not null;
