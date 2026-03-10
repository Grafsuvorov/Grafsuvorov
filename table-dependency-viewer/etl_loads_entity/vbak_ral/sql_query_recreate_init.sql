DROP TABLE IF EXISTS ods.vbak_ral;

CREATE TABLE IF NOT EXISTS ods.vbak_ral (
    vbeln VARCHAR NULL,
    auart VARCHAR NULL,
    vbtyp VARCHAR NULL,
    abrvw VARCHAR NULL,
    aedat DATE NULL,
    audat DATE NULL,
    bsark VARCHAR NULL,
    bstnk VARCHAR NULL,
    erdat DATE NULL,
    ernam VARCHAR  NULL,
    erzet VARCHAR NULL,
    ihrez VARCHAR NULL,
    vkgrp VARCHAR NULL,
    zuonr VARCHAR NULL,
    zzresp VARCHAR NULL,
    kunnr VARCHAR NULL,
    ps_psp_pnr VARCHAR NULL,
    zznoi VARCHAR NULL,
    ktext VARCHAR NULL,
    zzspp VARCHAR NULL,
    guebg DATE NULL,
    gueen VARCHAR NULL,
    dttm_inserted TIMESTAMP NOT NULL DEFAULT NOW(),
    dttm_updated TIMESTAMP NOT NULL DEFAULT NOW(),
    job_name VARCHAR(60) NOT NULL DEFAULT 'airflow'::CHARACTER VARYING,
    deleted_flag BOOL NOT NULL DEFAULT FALSE
)
WITH (
    appendonly=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=3
)
DISTRIBUTED BY (vbeln);

COMMENT ON TABLE ods.vbak_ral is 'Торговый документ: данные заголовка';
COMMENT ON COLUMN ods.vbak_ral.vbeln is 'Торговый документ | Торговый документ | VBAK.VBELN';
COMMENT ON COLUMN ods.vbak_ral.auart is 'Вид торгового документа | Вид торгового документа | VBAK.AUART';
COMMENT ON COLUMN ods.vbak_ral.vbtyp is 'Тип ДокумСбыта | Тип ДокумСбыта | VBAK.VBTYP';
COMMENT ON COLUMN ods.vbak_ral.abrvw is 'Тип договора | Тип договора | VBAK.ABRVW';
COMMENT ON COLUMN ods.vbak_ral.aedat is 'Дата последнего изменения | Дата последнего изменения | VBAK.AEDAT';
COMMENT ON COLUMN ods.vbak_ral.audat is 'Дата документа (дата поступления/отпуска) | Дата документа (дата поступления/отпуска) | VBAK.AUDAT';
COMMENT ON COLUMN ods.vbak_ral.bsark is 'ВидЗаказаНаПоставку | ВидЗаказаНаПоставку | VBAK.BSARK';
COMMENT ON COLUMN ods.vbak_ral.bstnk is '№ заказа клиента на поставку | № заказа клиента на поставку | VBAK.BSTNK';
COMMENT ON COLUMN ods.vbak_ral.erdat is 'Дата создания записи | Дата создания записи | VBAK.ERDAT';
COMMENT ON COLUMN ods.vbak_ral.ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | VBAK.ERNAM';
COMMENT ON COLUMN ods.vbak_ral.erzet is 'Время ввода | Время ввода | VBAK.ERZET';
COMMENT ON COLUMN ods.vbak_ral.ihrez is 'Регистр.№ | Регистр.№ | VBAK.IHREZ';
COMMENT ON COLUMN ods.vbak_ral.kunnr is 'Заказчик | Заказчик | VBAK.KUNNR';
COMMENT ON COLUMN ods.vbak_ral.ps_psp_pnr is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | VBAK.PS_PSP_PNR';
COMMENT ON COLUMN ods.vbak_ral.vkgrp is 'Группа сбыта | Группа сбыта | VBAK.VKGRP';
COMMENT ON COLUMN ods.vbak_ral.zuonr is '№ присвоения | № присвоения | VBAK.ZUONR';
COMMENT ON COLUMN ods.vbak_ral.zzresp is 'Центр Ответств | Центр Ответств | VBAK.ZZRESP';
COMMENT ON COLUMN ods.vbak_ral.zznoi is 'Номер отгрузочной инструкции | Номер отгрузочной инструкции | VBAK.ZZNOI';
COMMENT ON COLUMN ods.vbak_ral.ktext is 'Критерий поиска ассортимента | Критерий поиска ассортимента | VBAK.KTEXT';
COMMENT ON COLUMN ods.vbak_ral.zzspp is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | VBAK.ZZSPP';
COMMENT ON COLUMN ods.vbak_ral.guebg is 'ДатаВступлСилу (ДолгосрочнДоговор/ассортимент) | ДатаВступлСилу (ДолгосрочнДоговор/ассортимент) | VBAK.GUEBG';
COMMENT ON COLUMN ods.vbak_ral.gueen is 'Срок действия (ДолгосрочнДоговор/ассортимент) | Срок действия (ДолгосрочнДоговор/ассортимент) | VBAK.GUEEN';
