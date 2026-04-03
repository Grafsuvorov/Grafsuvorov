INSERT INTO ods.vbrk_ral (
	vbeln,
	zzsammg,
	rfbsk,
	vbtyp,
	fkdat,
	kunrg,
	waerk,
	fkart,
	fksto,
	sfakn
)
SELECT
	tech_etl.util_text_to_null_validation("VBELN") as vbeln,
	tech_etl.util_text_to_null_validation("ZZSAMMG") as zzsammg,
	tech_etl.util_text_to_null_validation("RFBSK") as rfbsk,
	tech_etl.util_text_to_null_validation("VBTYP") as vbtyp,
	tech_etl.util_text_to_date_validation("FKDAT") as fkdat,
	tech_etl.util_text_to_null_validation("KUNRG") as kunrg,
	tech_etl.util_text_to_null_validation("WAERK") as waerk,
	tech_etl.util_text_to_null_validation("FKART") as fkart,
	tech_etl.util_text_to_null_validation("FKSTO") as fksto,
	tech_etl.util_text_to_null_validation("SFAKN") as sfakn
FROM 
	stg."VBRK";