INSERT INTO ods.vbpa_ral
(
	kunnr,		-- Номер дебитора
	parvw,		-- Роль партнера
	pernr,		-- Табельный номер
	posnr,		-- Номер позиции документа сбыта	
	vbeln,		-- Номер документа сбыта
	lifnr,		-- Номер счета поставщика или кредитора
	land1		-- Страна партнёра (код)
)
SELECT 
	tech_etl.util_text_to_null_validation ("KUNNR") AS kunnr,		-- Номер дебитора
	tech_etl.util_text_to_null_validation ("PARVW") AS parvw,		-- Роль партнера
	tech_etl.util_text_to_null_validation ("PERNR") AS pernr,		-- Табельный номер
	tech_etl.util_text_to_null_validation ("POSNR") AS posnr,		-- Номер позиции документа сбыта	
	tech_etl.util_text_to_null_validation ("VBELN") AS vbeln,		-- Номер документа сбыта
	tech_etl.util_text_to_null_validation ("LIFNR") AS lifnr,		-- Номер счета поставщика или кредитора
	tech_etl.util_text_to_null_validation ("LAND1") AS land1		-- Страна партнёра (код)
FROM stg."VBPA" 
WHERE tech_etl.util_text_to_null_validation("VBELN") IS NOT NULL 
	AND tech_etl.util_text_to_null_validation("PARVW") IS NOT NULL
	AND "MANDT" = '400';
