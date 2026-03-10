insert into ods."/rusal/sd2882m_ral"
select
	tech_etl.util_text_to_null_validation(rs."MARKET") as market, 				-- Трейдеры: рынок сбыта  
	tech_etl.util_text_to_null_validation(rs."REG_PERIO") as reg_perio,												-- Трейдеры: Месяц отгрузки с завода
	tech_etl.util_text_to_null_validation(rs."MATKL") as matkl, 				-- Группа материалов
	tech_etl.util_text_to_null_validation(rs."NUMVR") as numvr, 														-- Номер версии/корректировки заказа
	trim(tech_etl.util_text_to_null_validation(rs."NUMLINEVR")) as numlinevr,	-- Трейдеры: Номер строки версии
	tech_etl.util_text_to_null_validation(rs."ZAKAZ_KL") as zakaz_kl, 													-- Заказ ЦК
	tech_etl.util_text_to_null_validation(rs."WERKS") as werks,
	tech_etl.util_text_to_null_validation(rs."VBELN_R") as vbeln_r, 			-- Трейдеры: Документ квоты
	tech_etl.util_text_to_null_validation(rs."ZPEREV") as zperev, 				-- ПлатитПеревозчику ( Плательщик тарифа )
	tech_etl.util_text_to_date_validation(rs."FACT_DATE_Z") as fact_date_z,		-- Фактическая дата получения заказа
	tech_etl.util_text_to_null_validation(rs."POTREB") as potreb,               -- Потребитель
	tech_etl.util_text_to_null_validation(rs."BUYER") as buyer,                 -- Покупатель
	tech_etl.util_text_to_null_validation(rs."VBELN_EXT") as vbeln_ext,  		-- Внешний номер заказа для AL
	tech_etl.util_text_to_null_validation(rs."TRADER_BUYER") as trader_buyer,	-- Номер дебитора
	tech_etl.util_text_to_null_validation(rs."LOCID") as locid,					-- Трейдеры: Пограничный порт
	tech_etl.util_text_to_null_validation(rs."QUOTA") as quota,					-- Трейдеры: квота
	tech_etl.util_text_to_null_validation(rs."INCO2") as inco2,					-- Пункт поставки по контракту
	tech_etl.util_text_to_null_validation(rs."KOD_END_LOC") as kod_end_loc,		-- Код порта выгрузки / перев. вне РФ
	tech_etl.util_text_to_null_validation(rs."END_LOC") as end_loc,				-- Трейдеры: Порт выгрузки/перевалки вне РФ
	tech_etl.util_text_to_null_validation(rs."SPEC_ORDER") as spec_order,		-- Трейдеры: спец. заказ клиента
	tech_etl.util_text_to_null_validation(rs."BSTKD") as bstkd,					-- Трейдеры: Контракт
	tech_etl.util_text_to_null_validation(rs."INCO1") as inco1,					-- Трейдеры: Базис поставки (Incoterms)
	tech_etl.util_text_to_null_validation(rs."DELIV_LAND") as deliv_land,		-- Страна поставки по контракту
	tech_etl.util_text_to_null_validation(rs."POTREB_LAND") as potreb_land,		-- Страна конечного потребителя
	tech_etl.util_text_to_null_validation(rs1."WERKS_TRADE") as werks_trade,	-- Завод в файле
	tech_etl.util_text_to_null_validation(rs."SD_PERETARKA") as sd_peretarka	-- Вид транспортного средства (Тип контейнера) Перетарка
from stg."/RUSAL/SD2882M" as rs
left join stg."/RUSAL/SD2882M_1" rs1
on rs."MANDT"=rs1."MANDT"
and rs."WERKS"=rs1."WERKS"
where 1=1
--	and "REG_PERIO">='202201'  -- Инкремент обновления, по месяцу. После инициирующей, обновлять на согласованную глубину
;
