insert into ods.earmarked_funds_document_position
select
	kblp."BELNR" as earmarked_document_code,
	tech_etl.util_text_to_null_validation(kblp."BLPOS") as earmarked_document_position_line_item_code,
	tech_etl.util_text_to_null_validation(kblp."AUFNR") as order_number_code,
	tech_etl.util_text_to_null_validation(kblp."PSPNR") as wbs_element_code,
	tech_etl.util_text_to_null_validation(kblp."SAKNR") as general_ledger_account_code
from stg."KBLP" kblp
where 1=1
and kblp."MANDT" = '400';