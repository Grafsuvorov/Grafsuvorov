INSERT INTO ods.vbsk_ral (
    sammg,					-- Группа
    vtext,					-- Название
    zzroute,				-- Маршрут
    smart,					-- Вид группы
    zzunloaddate,			-- Дата выгрузки
    zzlddat,				-- Дата отгрузки с завода
    zzlocid,				-- Ид. места размещения
    zzexpeditor,			-- Экспедитор
    zzbuyer,				-- Потребитель (End user)
    zzendfreedate,			-- Дата окончания бесплатного хранения на складе
    zzvbeln_va,				-- № Заказа
    zzvbeln,				-- № фактуры
    zzposnr,				-- Позиция заказа
    zzexped,				-- Экспедитор выгрузки
    zzdeliv_basis1,			-- Базис поставки, часть 1
    zzdeliv_basis2,			-- Базис поставки, часть 2
    zzkunnr,				-- Грузополучатель
    zzkunag,				-- Заказчик
    zzvbeln_ram,			-- Документ квоты
    zznomtk,				-- Номинация
    zztr_comp,				-- Trading company
    erdat,					-- Дата создания записи
    zzbank,					-- Банк как контрагент
    ernam,					-- Логин пользователя, создавшего документ
    uzeit,					-- Время дня
    zzarrdp,				-- Дата прихода в порт назначения
    zzimgdate,              -- Дата загрузки образа
    zzstatus,				-- Статус документа
    zzkondm,			    -- Market indicator
    zzterm			    	-- Метод оплаты
)
SELECT
    tech_etl.util_text_to_null_validation(l."SAMMG") AS sammg,						-- Группа
    tech_etl.util_text_to_null_validation(l."VTEXT") AS vtext,						-- Название
    tech_etl.util_text_to_null_validation(l."ZZROUTE") AS zzroute,					-- Маршрут
    tech_etl.util_text_to_null_validation(l."SMART") AS smart,						-- Вид группы
    tech_etl.util_text_to_date_validation(l."ZZUNLOADDATE") AS zzunloaddate,		-- Дата выгрузки
    tech_etl.util_text_to_date_validation(l."ZZLDDAT") AS zzlddat,					-- Дата отгрузки с завода
    tech_etl.util_text_to_null_validation(l."ZZLOCID") AS zzlocid,					-- Ид. места размещения
    tech_etl.util_text_to_null_validation(l."ZZEXPEDITOR") AS zzexpeditor,			-- Экспедитор
    tech_etl.util_text_to_null_validation(l."ZZBUYER") AS zzbuyer,					-- Потребитель (End user)
    tech_etl.util_text_to_date_validation(l."ZZENDFREEDATE") AS zzendfreedate,		-- Дата окончания бесплатного хранения на складе
    tech_etl.util_text_to_null_validation(l."ZZVBELN_VA") AS zzvbeln_va,			-- № Заказа
    tech_etl.util_text_to_null_validation(l."ZZVBELN") AS zzvbeln,					-- № фактуры
    tech_etl.util_text_to_null_validation(l."ZZPOSNR") AS zzposnr,					-- Позиция заказа
    tech_etl.util_text_to_null_validation(l."ZZEXPED") AS zzexped,					-- Экспедитор выгрузки
    tech_etl.util_text_to_null_validation(l."ZZDELIV_BASIS1") AS zzdeliv_basis1,	-- Базис поставки, часть 1
    tech_etl.util_text_to_null_validation(l."ZZDELIV_BASIS2") AS zzdeliv_basis2,	-- Базис поставки, часть 2
    tech_etl.util_text_to_null_validation(l."ZZKUNNR") AS zzkunnr,					-- Грузополучатель
    tech_etl.util_text_to_null_validation(l."ZZKUNAG") AS zzkunag,					-- Заказчик
    tech_etl.util_text_to_null_validation(l."ZZVBELN_RAM") AS zzvbeln_ram,			-- Документ квоты
    tech_etl.util_text_to_null_validation(l."ZZNOMTK") AS zznomtk,					-- Номинация
    tech_etl.util_text_to_null_validation(l."ZZTR_COMP") AS zztr_comp,				-- Trading company
    tech_etl.util_text_to_date_validation(l."ERDAT") AS erdat,				        -- Дата создания записи
    tech_etl.util_text_to_null_validation(l."ZZBANK") AS zzbank,			        -- Банк как контрагент
    tech_etl.util_text_to_null_validation(l."ERNAM") AS ernam,						-- Логин пользователя, создавшего документ
    tech_etl.util_text_to_time_validation(l."UZEIT") as uzeit,						-- Время дня
    tech_etl.util_text_to_date_validation(l."ZZARRDP") AS zzarrdp,					-- Дата прихода в порт назначения
    tech_etl.util_text_to_date_validation(l."ZZIMGDATE") as zzimgdate,			    -- Дата загрузки образа
    tech_etl.util_text_to_null_validation(l."ZZSTATUS") as zzstatus,			    -- Статус документа
    tech_etl.util_text_to_null_validation(l."ZZKONDM") as zzkondm,			    	-- Market indicator
    tech_etl.util_text_to_null_validation(l."ZZTERM") as zzterm			    		-- Метод оплаты
FROM stg."VBSK" AS l
;
