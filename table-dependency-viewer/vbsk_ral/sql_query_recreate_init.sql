DROP TABLE IF EXISTS ods.vbsk_ral CASCADE;

CREATE TABLE if not exists ods.vbsk_ral (-- ключ sammg
    sammg varchar NULL,						-- Группа
    vtext varchar NULL,						-- Название
    zzroute varchar NULL,					-- Маршрут
    smart varchar NULL,						-- Вид группы
    zzunloaddate date NULL,					-- Дата выгрузки
    zzlddat date NULL,						-- Дата отгрузки с завода
    zzlocid varchar NULL,					-- Ид. места размещения
    zzexpeditor varchar NULL,				-- Экспедитор
    zzbuyer varchar NULL,					-- Потребитель (End user)
    zzendfreedate date NULL,				-- Дата окончания бесплатного хранения на складе
    zzvbeln_va varchar NULL,				-- № Заказа
    zzvbeln varchar NULL,					-- № фактуры
    zzposnr varchar NULL,					-- Позиция заказа
    zzexped varchar NULL,					-- Экспедитор выгрузки
    zzdeliv_basis1 varchar NULL,			-- Базис поставки, часть 1
    zzdeliv_basis2 varchar NULL,			-- Базис поставки, часть 2
    zzkunnr varchar NULL,					-- Грузополучатель
    zzkunag varchar NULL,					-- Заказчик
    zzvbeln_ram varchar NULL,				-- Документ квоты
    zznomtk varchar NULL,					-- Номинация
    zztr_comp varchar NULL,					-- Trading company
    erdat date NULL,						-- Дата создания записи
    zzbank varchar NULL,					-- Банк как контрагент
    ernam varchar NULL,						-- Логин пользователя, создавшего документ
    zzarrdp date NULL,						-- Дата прихода в порт назначения
    uzeit time null,						-- Время дня
    zzimgdate date NULL,                    -- Дата загрузки образа
    zzstatus varchar NULL,					-- Статус документа
    zzkondm varchar NULL,					-- Market indicator
    zzterm varchar NULL,		    		-- Метод оплаты
    dttm_inserted timestamp NOT NULL DEFAULT now(),
    dttm_updated timestamp NOT NULL DEFAULT now(),
    job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
    deleted_flag bool NOT NULL DEFAULT FALSE
)
WITH (
    appendonly = TRUE,
    orientation = COLUMN,
    compresstype = zstd,
    compresslevel = 3
)
DISTRIBUTED BY (sammg);

COMMENT ON TABLE ods.vbsk_ral IS 'Документ сбыта: Заголовок групповой обработки';
COMMENT ON COLUMN ods.vbsk_ral.sammg IS 'Группа | Группа | stg."VBSK"."SAMMG"';
COMMENT ON COLUMN ods.vbsk_ral.vtext IS 'Название | Название | stg."VBSK"."VTEXT"';
COMMENT ON COLUMN ods.vbsk_ral.zzroute IS 'Маршрут | Маршрут | stg."VBSK"."ZZROUTE"';
COMMENT ON COLUMN ods.vbsk_ral.smart IS 'Вид группы | Вид группы | stg."VBSK"."SMART"';
COMMENT ON COLUMN ods.vbsk_ral.zzunloaddate IS 'Дата выгрузки | Дата выгрузки | stg."VBSK"."ZZUNLOADDATE"';
COMMENT ON COLUMN ods.vbsk_ral.zzlddat IS 'Дата отгрузки с завода | Дата отгрузки с завода | stg."VBSK"."ZZLDDAT"';
COMMENT ON COLUMN ods.vbsk_ral.zzlocid IS 'Ид. места размещения | Ид. места размещения | stg."VBSK"."ZZLOCID"';
COMMENT ON COLUMN ods.vbsk_ral.zzexpeditor IS 'Экспедитор | Экспедитор | stg."VBSK"."ZZEXPEDITOR"';
COMMENT ON COLUMN ods.vbsk_ral.zzbuyer IS 'Потребитель (End user) | Потребитель (End user) | stg."BSK."ZZBUYER"';
COMMENT ON COLUMN ods.vbsk_ral.zzendfreedate IS 'Дата окончания бесплатного хранения на складе | Дата окончания бесплатного хранения на складе | stg."VBSK"."ZZENDFREEDATE"';
COMMENT ON COLUMN ods.vbsk_ral.zzvbeln_va IS '№ Заказа | № Заказа | stg."VBSK"."ZZVBELN_VA"';
COMMENT ON COLUMN ods.vbsk_ral.zzvbeln IS '№ фактуры | № фактуры | stg."VBSK"."ZZVBELN"';
COMMENT ON COLUMN ods.vbsk_ral.zzposnr IS 'Позиция заказа | Позиция заказа | stg."VBSK"."ZZPOSNR"';
COMMENT ON COLUMN ods.vbsk_ral.zzexped IS 'Экспедитор выгрузки | Экспедитор выгрузки | stg."VBSK"."ZZEXPED"';
COMMENT ON COLUMN ods.vbsk_ral.zzdeliv_basis1 IS 'Базис поставки, часть 1 | Базис поставки, часть 1 | stg."VBSK"."ZZDELIV_BASIS1"';
COMMENT ON COLUMN ods.vbsk_ral.zzdeliv_basis2 IS 'Базис поставки, часть 2 | Базис поставки, часть 2 | stg."VBSK"."ZZDELIV_BASIS2"';
COMMENT ON COLUMN ods.vbsk_ral.zzkunnr IS 'Грузополучатель | Грузополучатель | stg."VBSK"."ZZKUNNR"';
COMMENT ON COLUMN ods.vbsk_ral.zzkunag IS 'Заказчик | Заказчик | stg."VBSK"."ZZKUNAG"';
COMMENT ON COLUMN ods.vbsk_ral.zzvbeln_ram IS 'Документ квоты | Документ квоты | stg."VBSK"."ZZVBELN_RAM"';
COMMENT ON COLUMN ods.vbsk_ral.zznomtk IS 'Номинация | Номинация | stg."VBSK"."ZZNOMTK"';
COMMENT ON COLUMN ods.vbsk_ral.zztr_comp IS 'Trading company | Trading company | stg."VBSK"."ZZTR_COMP"';
COMMENT ON COLUMN ods.vbsk_ral.erdat IS 'Дата создания записи | Дата создания записи | stg."VBSK"."ERDAT"';
COMMENT ON COLUMN ods.vbsk_ral.zzbank IS 'Банк как контрагент | Банк как контрагент | stg."VBSK"."ZZBANK"';
COMMENT ON COLUMN ods.vbsk_ral.ernam IS 'Логин пользователя, создавшего документ | Логин пользователя, создавшего документ | stg."VBSK"."ERNAM"';
COMMENT ON COLUMN ods.vbsk_ral.uzeit IS 'Время дня | Время дня | stg."VBSK"."UZEIT"';
COMMENT ON COLUMN ods.vbsk_ral.zzarrdp IS 'Дата прихода в порт назначения | Дата прихода в порт назначения | stg."VBSK"."ZZARRDP"';
COMMENT ON COLUMN ods.vbsk_ral.zzimgdate IS 'Дата загрузки образа | Дата загрузки образа | stg."VBSK"."ZZIMGDATE"';
COMMENT ON COLUMN ods.vbsk_ral.zzstatus IS 'Статус документа | Статус документа | stg."VBSK"."ZZSTATUS"';
COMMENT ON COLUMN ods.vbsk_ral.zzkondm IS 'Market indicator | Market indicator | stg."VBSK"."ZZKONDM"';
COMMENT ON COLUMN ods.vbsk_ral.zzterm IS 'Метод оплаты | Метод оплаты | stg."VBSK"."ZZTERM"';
