INSERT INTO ods."/rusal/shipsplit_ral" (
	werks,
	vbeln_src,
	vbeln_dst,
	charg,
	vbeln_rfr,
	reason
)
SELECT
	tech_etl.util_text_to_NULL_validation(rs."WERKS") AS werks,						-- Завод (код)
	tech_etl.util_text_to_NULL_validation(rs."VBELN_SRC") AS vbeln_src,				-- Исходная поставка (код)
	tech_etl.util_text_to_NULL_validation(rs."VBELN_DST") AS vbeln_dst,				-- Разделённая поставка (код)
	tech_etl.util_text_to_NULL_validation(rs."CHARG") AS charg,						-- Партия (код)
	tech_etl.util_text_to_NULL_validation(rs."VBELN_RFR") AS vbeln_rfr,				-- Ссылочная поставка (код)	
	tech_etl.util_text_to_NULL_validation(rs."REASON") AS reason					-- Причина деления (код)
FROM 
	stg."/RUSAL/SHIPSPLIT" AS rs;

