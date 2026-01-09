insert into ods.vbap_ral 
select
    --"ZWERT" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as zwert,				-- преобразовываем сумму по формуле
	--"NETWR" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as netwr,				-- преобразовываем сумму по формуле
	--"NETPR" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as netpr,				-- преобразовываем сумму по формуле
	--"WAVWR" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as wavwr,				-- преобразовываем сумму по формуле
	--"KZWI1" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as kzwi1,				-- преобразовываем сумму по формуле
	--"KZWI2" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as kzwi2,				-- преобразовываем сумму по формуле
	--"KZWI3" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as kzwi3,				-- преобразовываем сумму по формуле
	--"KZWI4" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as kzwi4,				-- преобразовываем сумму по формуле
	--"KZWI5" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as kzwi5,				-- преобразовываем сумму по формуле
	--"KZWI6" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as kzwi6,				-- преобразовываем сумму по формуле
	--"CMPRE" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as cmpre,				-- преобразовываем сумму по формуле
	--"CMPRE_FLT" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as cmpre_flt,		-- преобразовываем сумму по формуле
	--"MWSBP" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as mwsbp,				-- преобразовываем сумму по формуле
	--"OIFEETOT" * (10 ^ (2 - coalesce(cdpr.decimal_place_number,2))) as oifeetot,			-- преобразовываем сумму по формуле
    tech_etl.util_text_to_null_validation("VBELN") as vbeln,								-- Поставка
    tech_etl.util_text_to_null_validation("POSNR") as posnr,								-- Позиция поставки
    tech_etl.util_text_to_null_validation("ZZCUSTCO") as zzcustco,							-- Страна потребителя
    tech_etl.util_text_to_null_validation("PS_PSP_PNR") as ps_psp_pnr,						-- Элемент структурного плана проекта (СПП-элемент)
    tech_etl.util_text_to_date_validation("AEDAT") as aedat,								-- Дата последнего изменения
    tech_etl.util_text_to_date_validation("ERDAT") as erdat,								-- Дата создания записи
    tech_etl.util_text_to_null_validation("ZZZAKAZ2") as zzzakaz2,							-- Номер заказа клиента
    tech_etl.util_text_to_null_validation("PSTYV") as pstyv									-- Тип позиции документа сбыта
from stg."VBAP" v
--left join dict_dds.currency_decimal_place_ral cdpr						 				--джойн с TCURX RAL (таблица курсов, по которым просиходит преобразование)
--on cdpr.currency_code = v."WAERK"
where "MANDT" = '400';
