insert into ods."/rul/rw_docs_ral" (
	matnr,
	charg,
	werks,
	belnr,
	posnr,
	status,
	ebeln,
	ebelp,
	fvdt3,
	mblnr,
	mjahr,
	zeile,
	path,
	conosnum
)
select
	tech_etl.util_text_to_null_validation("MATNR") as matnr,
	tech_etl.util_text_to_null_validation("CHARG") as charg,
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	tech_etl.util_text_to_null_validation("BELNR") as belnr,
	tech_etl.util_text_to_null_validation("POSNR") as posnr,
	tech_etl.util_text_to_null_validation("STATUS") as status,
	tech_etl.util_text_to_null_validation("EBELN") as ebeln,
	tech_etl.util_text_to_null_validation("EBELP") as ebelp,
	tech_etl.util_text_to_date_validation("FVDT3") as fvdt3,
	tech_etl.util_text_to_null_validation("MBLNR") as mblnr,
	tech_etl.util_text_to_null_validation("MJAHR") as mjahr,
	tech_etl.util_text_to_null_validation("ZEILE") as zeile,
	tech_etl.util_text_to_null_validation("PATH") as path,
	tech_etl.util_text_to_null_validation("CONOSNUM") as conosnum
from stg."/RUL/RW_DOCS"
where "MANDT" = '400';
