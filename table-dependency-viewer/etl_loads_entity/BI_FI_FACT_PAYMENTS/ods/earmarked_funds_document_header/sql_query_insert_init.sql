insert into ods.earmarked_funds_document_header
select
	kblk."BELNR" as earmarked_document_code,
	tech_etl.util_text_to_null_validation(kblk."XBLNR") as reference_document_code
from stg."KBLK" kblk
where 1=1
and kblk."MANDT" = '400';