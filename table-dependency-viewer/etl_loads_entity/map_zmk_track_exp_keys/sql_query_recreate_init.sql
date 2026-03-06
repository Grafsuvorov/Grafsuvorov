DROP TABLE IF EXISTS ods.map_zmk_track_exp_keys CASCADE;

CREATE TABLE ods.map_zmk_track_exp_keys (
	"CHARG_exp01" varchar(30) NULL,						-- Партия
	"VBELN_exp01" varchar(30) NULL,						-- Исходная поставка
	"VBELN_P_exp01" varchar(30) NULL,					-- Продажная поставка
	"VBELN_LF_exp01" varchar(30) NULL,					-- Номер поставки завода производителя
	"LOCID_exp01" varchar(30) NULL,						-- Порт погрузки (код)
	"DATEOT_exp01" date NULL,							-- Дата отгрузки
	"DATAPRZD_exp01" date NULL,							-- Дата прибытия по ЖД
	"DATAPREK_exp01" date NULL,							-- Дата экспедитора
	"NAKLADN_exp01" varchar(105) NULL,					-- Накладная
	"EXPEDID_exp01" varchar(30) NULL,					-- Экспедитор (код)
	"EXPEDID_TXT_exp01" varchar(300) NULL,				-- Экспедитор
	"SDABW_WH_exp01" varchar(12) NULL,					-- Тип вагона на заводе(код)
	"SDABW_PERETARKA_exp02" varchar(12) NULL,			-- Тип ПС после перетарки
	"SDABW_exp02" varchar(12) NULL,						-- Тип вагона (код)
	"NOMTK_RA_exp01" varchar(60) NULL,					-- Плановая номинация
	"BTGEW_exp02" numeric(13, 3) NULL,					-- Вес брутто
	"LFIMG_exp02" numeric(13, 3) NULL,					-- Вес нетто
	"BRGEW_exp02" numeric(13, 3) NULL,					-- Вес Н&K
	"KNOTE_CURR_TXT_exp04" varchar(90) NULL,			-- Текущая станция(код)
	"STATIONNC_TXT_exp01" varchar(90) NULL,				-- Станция назначения
	"KUNNR_exp02" varchar(30) NULL,						-- Покупатель
	"BSTKD_exp02" varchar(105) NULL,					-- Контракт
	"QUOTA_exp02" varchar(18) NULL,						-- Квота
	"SAMMG_Y_exp02" varchar(30) NULL,					-- Группа коносамента
	"VTEXT_Y_exp02" varchar(90) NULL,					-- Номер коносамента
	"LDDAT_Y_exp02" date NULL,							-- Дата коносамента
	"ROUTE_Y_exp02" varchar(18) NULL,					-- Маршрут коносамента
	"NOMTK_exp02" varchar(60) NULL,						-- Номинация
	"SAMMG_KOP_exp02" varchar(30) NULL,					-- Группа коносамента в ин.порту
	"VTEXT_KOP_exp02" varchar(90) NULL,					-- Коносамент в ин.порту
	"LDDAT_KOP_exp02" date NULL,						-- Дата коносамента в ин.порту
	"NOMTK_KOP_exp02" varchar(60) NULL,					-- Номинация коносамента в ин. порту
	"ROUTE_KOP_exp02" varchar(18) NULL,					-- Маршрут коносамента в ин. порту
	"KNANF_KOP_exp02" varchar(30) NULL,					-- Порт погрузки 2 (код)
	"KNANF_KOP_TXT_exp02" varchar(90) NULL,				-- Порт погрузки 2
	"KNEND_KOP_exp02" varchar(30) NULL,					-- Порт выгрузки 2 (код)
	"STATUS_exp04" varchar(30) NULL,					-- Статус
	"STATUS_TXT_exp04" varchar(75) NULL,				-- Описание статуса
	"SAILED_L_PORT_exp02" date NULL,					-- Sailed L.Port
	"DATE_ARRIV_exp02" date NULL,						-- Дата прибытия в порт выгрузки
	"ARRDP_exp02" date NULL,							-- Дата прибытия в порт выгрузки 2
	"BASIS_exp02" varchar(9) NULL,						-- Базис поставки
	"BASIS2_exp02" varchar(84) NULL,					-- Пункт доставки по инкотермс
	"VSART_exp01" varchar(6) NULL,						-- Тип маршрута
	"CUST2_ID_exp01" varchar(30) NULL,					-- № конечного покупателя в SAP/CUST2_ID
	"GTD_exp01" varchar(90) NULL,						-- Номер ГТД
	"GTD_DATE_exp01" date NULL,							-- Дата ГТД
	"PACKING_SHIP_exp01" numeric(15, 3) NULL,			-- Вес ленты
	"KATANKA_exp01" numeric(13, 3) NULL,				-- Вес катанки
	"FREIGHT_exp01" numeric(13, 2) NULL,				-- Жд тариф
	"SUMPROT_exp01" numeric(13, 2) NULL,				-- Охрана
	"ANZPK_exp02" int8 NULL,							-- PCS
	"GRUZ_exp02" numeric(15, 3) NULL,					-- Грузоподъемность
	"ROUTE_exp02" varchar(18) NULL,						-- Маршрут завода
	"VAGON_PR_exp02" varchar(60) NULL,					-- Контейнер после перетарки
	"ROUTE_PERETAR_exp02" varchar(18) NULL,				-- Маршрут поставки Перетарки
	"D_WERKS_OTGR_P_exp02" date NULL,					-- Плановая дата отгрузки
	"DISTANCE_exp02" int8 NULL,							-- Оставшееся расстояние
	"ZAKAZ_KL_exp02" varchar(18) NULL,					-- Заказ ЦК
	"BUYER_exp02" varchar(30) NULL,						-- Плановый покупатель (код)
	"END_LOC_CODE_exp04" varchar(30) NULL,				-- Плановый порт выгрузки (код)
	"SPEC_ORDER_exp02" varchar(150) NULL,				-- Номер заказа клиента
	"DATE_ETADP_exp02" date NULL,						-- Дата прибытия в порт выгрузки план
	"NMVESSEL_P_exp02" varchar(54) NULL,				-- Номер рейса план
	"VEHICLE_F_exp02" varchar(30) NULL,					-- Судно факт(код)
	"VEHICLE_F_TXT_exp02" varchar(120) NULL,			-- Судно факт
	"NMVESSEL_F_exp02" varchar(54) NULL,				-- Номер рейса факт
	"MATNR_exp02" varchar(54) NULL,						-- Номер материала
	"MMCL_NAME_exp02" varchar(90) NULL,					-- Марка клиента
	"MMBS_NAME_exp02" varchar(90) NULL,					-- Марка по спецификации
	"VBELN_R_exp03" varchar(30) NULL,					-- Плановый контракт (код)
	"BSTKD_P_exp02" varchar(300) NULL,					-- Плановый контракт
	"DL_TO_exp02" date NULL,							-- Deadline доставки
	"SROK_FROMTO_exp02" varchar(90) NULL,				-- Желаемый период отгрузки
	"UNI_exp02" varchar(180) NULL,						-- UNI
	"VESSEL_IMO_exp02" varchar(21) NULL,				-- IMO судна
	"VESSEL_MMSI_exp02" varchar(30) NULL,				-- MMSI судна
	"LATITUDE_CURR_exp02" varchar(60) NULL,				-- Широта
	"LONGITUDE_CURR_exp02" varchar(60) NULL,			-- Долгота
	"ETADP_KOP_exp02" date NULL,						-- Дата прибытия в порт выгрузки 2 план
	"PBNUMBER_exp02" varchar(105) NULL,					-- LotWshe/PB number
	"PLFK_exp03" varchar(3) NULL,						-- Признак План/Факт
	"PLFK_PORTAL_exp03" varchar(3) NULL,				-- Признак План/Факт для портала
	"STATUS_AL2ALL_exp03" varchar(150) NULL,			-- Статус для портала AL2ALL
	"PROG_DATE_exp03" date NULL,						-- Expected delivery
	"KUNNR_END_exp03" varchar(30) NULL,					-- Конечный потребитель (код)
	"KUNNR_END_TXT_exp03" varchar(420) NULL,			-- Конечный потребитель
	"LFIMG_OUT_exp03" numeric(13, 3) NULL,				-- Отгруженное количество
	"VES_WAG_P_exp03" numeric(15, 3) NULL,				-- Запланированное количество
	"VTEXT_PIN_exp03" varchar(90) NULL,					-- Provisional invoice
	"SAMMG_REL_exp03" varchar(30) NULL,					-- Группа Релиз
	"VTEXT_FIN_exp03" varchar(90) NULL,					-- Final Invoice
	"PLEDGE_VTEXT_IN_exp03" varchar(90) NULL,			-- Номер документа pledge in
	"PLEDGE_CLIENT_TXT_exp03" varchar(420) NULL,		-- Pledge Bank
	"PLEDGE_LDDAT_exp03" date NULL,						-- Дата pledge in
	"ZAKAZ_KL_L_exp03" varchar(90) NULL,				-- Производственный заказ
	"WH_DATE_POD_exp03" date NULL,						-- Дата начала хранения ин. склад
	"ST_END_POD_exp03" date NULL,						-- Окончание хранения в ин. порту
	"FINISH_STORAGE2_exp03" date NULL,					-- Окончание хранение склад 2
	"BSTKD_CODE_exp03" varchar(30) NULL,				-- Контракт (код)
	"SAMMG_L_exp02" varchar(30) NULL,					-- Группа лот
	"SAMMG_ND_exp03" varchar(30) NULL,					-- Группа нотис о доставке
	"ZUONR_exp03" varchar(30) NULL,						-- Рамочный контракт (код)
	"REALIZATION_DATE_CALC_exp04" date NULL,			-- Расчетная дата реализации
	"DOCNUMBER_exp04" varchar(30) null,					-- Основание реализации
	"EXPORTER_TXT_exp04" varchar(300) null,				-- Экспортер
	"BUYER_INC_exp04" varchar(450) null,				-- Покупатель Incassa
	"EXPORTER_exp04" varchar(30) null,					-- Экспортер код
	"REASON_exp02" varchar(3) NULL,						-- Причина разделения
	"LAND1_POD_exp02" varchar(9) NULL,					-- Страна POD (код)
	"LANDX_POD_exp02" varchar(45) NULL,					-- Страна POD
	"WWGSG_POD_exp02" varchar(30) NULL,					-- Регион POD (код)
	"BEZEK_POD_exp02" varchar(60) NULL,					-- Регион POD
	"BSARK_exp04" varchar(12) NULL,						-- Вид контракта
	"VBELN_ISH_exp03" varchar(30) NULL,					-- Исходящая поставка
	"WADAT_IST_ISH_exp04" date NULL,					-- Дата ОМ
	"WBSTK_ISH_exp04" varchar(3) NULL,					-- Статус ОМ
	"DATE_CH_exp01" date NULL,							-- Дата последнего изменения
	"TIME_CH_exp01" time NULL,							-- Время последнего изменения
	"BSARK_TXT_exp04" varchar(60) NULL,					-- Название вида контракта
	"DATEPPS_exp01" date NULL,							-- Дата перехода права собственности
	"READY_TO_SHIP_DATE_exp04" date NULL,				-- Дата готовности к релизу
	"PORT_FOR_CUSTOMER_exp03" varchar(90) NULL,			-- Порт выгрузки для клиента
	"VBELN_INSTR_exp02" varchar(30) NULL,				-- Инструкция на доставку
	"INCO1_exp02" varchar(9) NULL,						-- Плановый базис поставки
	"INCO2_exp02" varchar(84) NULL,						-- Плановый Пункт доставки по инкотермс
	"GROUPS_exp03" varchar(90) NULL,					-- Группа продукции
	"BASIS2_LAND1_exp02" varchar(9) NULL,				-- Страна пункта доставки по инкотермс
	"ETD_L_PORT_ML_exp01" date NULL,					-- ETD
	"ETAR_exp02" date NULL,								-- Expected BL
	"BSTKD_LOT_exp02" varchar(35) NULL,					-- Контракт в лоте/Квотный контракт
	"TCON_TO_BUYER_DATE_exp03" date NULL,				-- Дата перехода из консигнации клиенту
	"LDDAT_FREL_exp03" date NULL,						-- Дата Финальный релиз
	"FWH_EXIST_exp04" varchar(3) NULL,					-- Наличие Иностранный склад
	"DATAUNLOAD_exp03" date NULL,						-- ТН/CMR: Дата выгрузки авто
	"RIVER_EU_exp04" varchar(3) NULL,					-- Наличие Иностранный склад 2
	"LOCID_FP2_exp03" varchar(30) NULL,					-- Иностранный порт 2 (код локации)
	"UL_ATA_DATE_exp03" date NULL,						-- Дата прибытия УЛ
	"DATE_PERETAR_exp02" date NULL,						-- Дата перетарки
	"SVH_TXT_exp03" varchar(90) NULL,					-- СВХ
	"BRUTTO_02_exp04" varchar(17) NULL,					-- Вес брутто (с учетом склада)
	"STATUS_ZHD_exp04" varchar(30) NULL,				-- Статус движения по ЖД
	"STATUS_SCB_exp04" varchar(150) NULL,				-- Статус в Supply chain (Business)
	"KNOTE_PLAN2_exp03" varchar(10) NULL,				-- Плановый порт выгрузки 2 (код)
	"KNOTE_PLAN2_TXT_exp03" varchar(30) NULL,			-- Плановый порт выгрузки 2
	"FWH_LOCID_exp04" varchar(150) NULL,				-- Иностранный порт (код локации)
	"SAMMG_P_exp02" varchar(30) NULL,					-- Группа поручение
	"LAND1_exp04" varchar(3) NULL,						-- Страна поставки по контракту (код)
	"COMMITM_exp04" numeric(15, 3) NULL,				-- Объем обязательств
	"COMMITM_TOTAL_exp04" numeric(15, 3) NULL,			-- Объем обязательств итого
	"VTEXT_L_exp02" varchar(30) NULL,					-- Номер лота
	"HMG_exp04" varchar(30) NULL,						-- HMG
	"PORT_Y_LAND1_exp02" varchar(3) NULL,				-- Страна порта выгрузки
	"STORAGE_CONFIRMATION_exp04" date NULL,				-- Дата Storage confirmation
	"SAMMG_SI2_exp03" varchar(10) NULL,					-- Группа инструкции на отгрузку Ин Порт 2
	"LDDAT_REL_exp03" date NULL,						-- Дата релиз
	"VTEXT_NOT_exp03" varchar(30) NULL,					-- Номер нотиса
	"LDDAT_NOT_exp03" date NULL,						-- Дата нотиса
	"VTEXT_FREL_exp03" varchar(30) NULL,				-- Номер Финальный релиз
	"BUDAT_FIN_exp04" date NULL,						-- Дата оплаты Final Invoice
	"CONTAINER_OUT_exp03" varchar(20) NULL,				-- Номер ТС в ин. порту
	"SDABW_PORT_exp03" varchar(4) NULL,					-- Тип ТС в ин. порту
	"MARKET_TXT_exp01" varchar(40) NULL,				-- Рынок в отгрузке
	"TCON_exp03" varchar(1) NULL,						-- Признак консигнации
	"TCON_TO_BUYER_DATE_EXP03" date NULL,				-- Дата перехода из консигнации клиенту
	"DATAUNLOAD_EXP03" date NULL,						-- ТН/CMR: Дата выгрузки авто
	"ID_WAY_exp04" varchar(2) NULL,						-- Сценарий маршрута
	"LANDX_exp04" varchar(15) NULL,						-- Страна поставки по контракту
	"REALIZATION_STATUS_exp04" varchar(8) NULL,			-- Статус Реализации
	"SVH_02_EXIST_exp01" varchar(1) NULL,				-- Есть запись с кодом СВХ 02
	"DELIV_REGION_exp04" varchar(60) NULL,				-- Регион поставки
	"DATEOT_exp01_month_year" varchar(6) NULL,			-- Месяц и год отгрузки
	"VOYAGE_exp03" varchar(20) NULL,					-- Номер рейса
	"SVH_CODE_exp03" varchar(2) NULL,					-- Тип СВХ(код)
	"CUSTOMID_exp01" varchar(10) NULL,					-- Заказчик
	"MMCL_CODE_exp01" varchar(10) NULL,					-- Код марки клиента
	"STATUS_SC_exp04" varchar(50) NULL,					-- Статус в Supply chain (Portal)
	"PLEDGE_CLIENT_exp03" varchar(10) NULL,				-- Pledge Bank (code)
	"REALIZATION_DATE_PF_exp04" date NULL,				-- Дата реализации План/Факт
	"POTREBIT_exp01" varchar(10) NULL,					-- Потребитель
	"PORT_Y_exp02" varchar(10) NULL,					-- Порт выгрузки (код)
	"LDDAT_REA_exp03" date NULL,						-- Дата Реализации
	"SYSTEMID_exp01" varchar(16) NULL,					-- Внутренний уникальный идентификатор записи
	"MATKL_exp01" varchar(9) NULL,						-- Группа материалов
	"PIMARY_exp01" varchar(70) NULL,					-- Материал
	"DATAPRZD_RF_exp02" date NULL,						-- Плановая дата принятия в порту
	"PLSTDATFR_exp03" date NULL,						-- Плановая дата отгрузки со склада ин. порта
	"PLSTDATFR2_exp03" date NULL,						-- Плановая дата отгрузки со склада ин. порта 2
	"DAYS1_exp04" int NULL,								-- Норма приемки контейнера в портy
	"FWH_DAYS1_exp04" int NULL,							-- Норма приемки терминал/склад ин. порта
	"FWH2_DAYS1_exp04" int NULL,						-- Норма приемки терминал/склад ин. порта 2
	"EXPECTED_BL_EXP_exp02" date NULL,					-- Дата коносамента план
	"LDDAT_KOP_P_exp04" date NULL,						-- Дата коносамента в ин.порту план
	"DATAPRZD_P_exp02" date NULL,						-- Плановая дата прибытия по ЖД (с фактом)
	"ORDER_exp01" varchar(30) NULL,						-- Заказ ЦК в отгрузке
	"PLATF_exp01" varchar(12) NULL,						-- Платформа
	"MAKTX_exp02" varchar(40) NULL,						-- Наименование материала
	"ROUTE_SHIP_exp01" varchar(6) NULL,					-- Маршрут в отгрузке
	"SDABW_SHIP_exp01" varchar(4) NULL,					-- Тип вагона, указанный в графике отгрузке на заводе-производ.
	"UNLOADDATE_Y_exp02" date NULL,						-- Дата выгрузки в порту
	"VAGON_P_exp02" varchar(20) NULL,					-- Контейнер
	"PLANT_exp01" varchar(4) NULL,						-- Завод (код)
	"NSERT_exp01" varchar(20) NULL,						-- Номер сертификата
	"KUNAG_L_exp02" varchar(10) NULL,					-- Покупатель в лоте
	"MIRR_STATUS_exp04" varchar(1) NULL,				-- Статус зеркалирования
	"BUYER_TXT_exp02" varchar(128) NULL,				-- Плановый покупатель 
	"LGORT_exp01" varchar NULL,							-- Принимающий склад
	is_delivery_not_exist_in_all_stg_tables bool null,	-- Индикатор: Поставка присутствует не во всех таблицах источника
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
DISTRIBUTED BY (
	"CHARG_exp01",
	"VBELN_exp01",
	"VBELN_P_exp01"
);


COMMENT ON TABLE ods.map_zmk_track_exp_keys IS 'Таблица ключей для витрины "Вагоны по контрактам""';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."CHARG_exp01" IS 'Партия | Партия | stg."ZMK_TRACK_EXP01"."CHARG"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VBELN_exp01" IS 'Исходная поставка | Исходная поставка | stg."ZMK_TRACK_EXP01"."VBELN"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VBELN_P_exp01" IS 'Продажная поставка | Продажная поставка | stg."ZMK_TRACK_EXP01"."VBELN_P"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VBELN_LF_exp01" IS 'Номер поставки завода производителя | Номер поставки завода производителя | stg."ZMK_TRACK_EXP01"."VBELN_LF"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LOCID_exp01" IS 'Порт погрузки (код) | Порт погрузки (код) | stg."ZMK_TRACK_EXP01"."LOCID"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATEOT_exp01" IS 'Дата отгрузки | Дата отгрузки | stg."ZMK_TRACK_EXP01"."DATEOT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATAPRZD_exp01" IS 'Дата прибытия по ЖД | Дата прибытия по ЖД | stg."ZMK_TRACK_EXP01"."DATAPRZD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATAPREK_exp01" IS 'Дата экспедитора | Дата экспедитора | stg."ZMK_TRACK_EXP01"."DATAPREK"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NAKLADN_exp01" IS 'Накладная | Накладная | stg."ZMK_TRACK_EXP01"."NAKLADN"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."EXPEDID_exp01" IS 'Экспедитор (код) | Экспедитор (код) | stg."ZMK_TRACK_EXP01"."EXPEDID"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."EXPEDID_TXT_exp01" IS 'Экспедитор | Экспедитор | stg."ZMK_TRACK_EXP01"."EXPEDID_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SDABW_WH_exp01" IS 'Тип вагона на заводе(код) | Тип вагона на заводе(код) | stg."ZMK_TRACK_EXP01"."SDABW_WH"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SDABW_PERETARKA_exp02" IS 'Тип ПС после перетарки | Тип ПС после перетарки | stg."ZMK_TRACK_EXP02"."SDABW_PERETARKA"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SDABW_exp02" IS 'Тип вагона (код) | Тип вагона (код) | stg."ZMK_TRACK_EXP02"."SDABW"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NOMTK_RA_exp01" IS 'Плановая номинация | Плановая номинация | stg."ZMK_TRACK_EXP01"."NOMTK_RA"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BTGEW_exp02" IS 'Вес брутто | Вес брутто | stg."ZMK_TRACK_EXP02"."BTGEW"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LFIMG_exp02" IS 'Вес нетто | Вес нетто | stg."ZMK_TRACK_EXP02"."LFIMG"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BRGEW_exp02" IS 'Вес Н&K | Вес Н&K | stg."ZMK_TRACK_EXP02"."BRGEW"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KNOTE_CURR_TXT_exp04" IS 'Текущая станция(код) | Текущая станция(код) | stg."ZMK_TRACK_EXP04"."KNOTE_CURR_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATIONNC_TXT_exp01" IS 'Станция назначения | Станция назначения | stg."ZMK_TRACK_EXP01"."STATIONNC_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KUNNR_exp02" IS 'Покупатель | Покупатель | stg."ZMK_TRACK_EXP02"."KUNNR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BSTKD_exp02" IS 'Контракт | Контракт | stg."ZMK_TRACK_EXP02"."BSTKD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."QUOTA_exp02" IS 'Квота | Квота | stg."ZMK_TRACK_EXP02"."QUOTA"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_Y_exp02" IS 'Группа коносамента | Группа коносамента | stg."ZMK_TRACK_EXP02"."SAMMG_Y"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_Y_exp02" IS 'Номер коносамента | Номер коносамента | stg."ZMK_TRACK_EXP02"."VTEXT_Y"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_Y_exp02" IS 'Дата коносамента | Дата коносамента | stg."ZMK_TRACK_EXP02"."LDDAT_Y"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ROUTE_Y_exp02" IS 'Маршрут коносамента | Маршрут коносамента | stg."ZMK_TRACK_EXP02"."ROUTE_Y"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NOMTK_exp02" IS 'Номинация | Номинация | stg."ZMK_TRACK_EXP02"."NOMTK"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_KOP_exp02" IS 'Группа коносамента в ин.порту | Группа коносамента в ин.порту | stg."ZMK_TRACK_EXP02"."SAMMG_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_KOP_exp02" IS 'Коносамент в ин.порту | Коносамент в ин.порту | stg."ZMK_TRACK_EXP02"."VTEXT_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_KOP_exp02" IS 'Дата коносамента в ин.порту | Дата коносамента в ин.порту | stg."ZMK_TRACK_EXP02"."LDDAT_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NOMTK_KOP_exp02" IS 'Номинация коносамента в ин. порту | Номинация коносамента в ин. порту | stg."ZMK_TRACK_EXP02"."NOMTK_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ROUTE_KOP_exp02" IS 'Маршрут коносамента в ин. порту | Маршрут коносамента в ин. порту | stg."ZMK_TRACK_EXP02"."ROUTE_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KNANF_KOP_exp02" IS 'Порт погрузки 2 (код) | Порт погрузки 2 (код) | stg."ZMK_TRACK_EXP02"."KNANF_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KNANF_KOP_TXT_exp02" IS 'Порт погрузки 2 | Порт погрузки 2 | stg."ZMK_TRACK_EXP02"."KNANF_KOP_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KNEND_KOP_exp02" IS 'Порт выгрузки 2 (код) | Порт выгрузки 2 (код) | stg."ZMK_TRACK_EXP02"."KNEND_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATUS_exp04" IS 'Статус | Статус | stg."ZMK_TRACK_EXP04"."STATUS"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATUS_TXT_exp04" IS 'Описание статуса | Описание статуса | stg."ZMK_TRACK_EXP04"."STATUS_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAILED_L_PORT_exp02" IS 'Sailed L.Port | Sailed L.Port | stg."ZMK_TRACK_EXP02"."SAILED_L_PORT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATE_ARRIV_exp02" IS 'Дата прибытия в порт выгрузки | Дата прибытия в порт выгрузки | stg."ZMK_TRACK_EXP02"."DATE_ARRIV"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ARRDP_exp02" IS 'Дата прибытия в порт выгрузки 2 | Дата прибытия в порт выгрузки 2 | stg."ZMK_TRACK_EXP02"."ARRDP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BASIS_exp02" IS 'Базис поставки | Базис поставки | stg."ZMK_TRACK_EXP02"."BASIS"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BASIS2_exp02" IS 'Пункт доставки по инкотермс | Пункт доставки по инкотермс | stg."ZMK_TRACK_EXP02"."BASIS2"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VSART_exp01" IS 'Тип маршрута | Тип маршрута | stg."ZMK_TRACK_EXP01"."VSART"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."CUST2_ID_exp01" IS '№ конечного покупателя в SAP/CUST2_ID | № конечного покупателя в SAP/CUST2_ID | stg."ZMK_TRACK_EXP01"."CUST2_ID"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."GTD_exp01" IS 'Номер ГТД | Номер ГТД | stg."ZMK_TRACK_EXP01"."GTD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."GTD_DATE_exp01" IS 'Дата ГТД | Дата ГТД | stg."ZMK_TRACK_EXP01"."GTD_DATE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PACKING_SHIP_exp01" IS 'Вес ленты | Вес ленты | stg."ZMK_TRACK_EXP01"."PACKING_SHIP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KATANKA_exp01" IS 'Вес катанки | Вес катанки | stg."ZMK_TRACK_EXP01"."KATANKA"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."FREIGHT_exp01" IS 'Жд тариф | Жд тариф | stg."ZMK_TRACK_EXP01"."FREIGHT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SUMPROT_exp01" IS 'Охрана | Охрана | stg."ZMK_TRACK_EXP01"."SUMPROT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ANZPK_exp02" IS 'PCS | PCS | stg."ZMK_TRACK_EXP02"."ANZPK"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."GRUZ_exp02" IS 'Грузоподъемность | Грузоподъемность | stg."ZMK_TRACK_EXP02"."GRUZ"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ROUTE_exp02" IS 'Маршрут завода | Маршрут завода | stg."ZMK_TRACK_EXP02"."ROUTE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VAGON_PR_exp02" IS 'Контейнер после перетарки | Контейнер после перетарки | stg."ZMK_TRACK_EXP02"."VAGON_PR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ROUTE_PERETAR_exp02" IS 'Маршрут поставки Перетарки | Маршрут поставки Перетарки | stg."ZMK_TRACK_EXP02"."ROUTE_PERETAR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."D_WERKS_OTGR_P_exp02" IS 'Плановая дата отгрузки | Плановая дата отгрузки | stg."ZMK_TRACK_EXP02"."D_WERKS_OTGR_P"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DISTANCE_exp02" IS 'Оставшееся расстояние | Оставшееся расстояние | stg."ZMK_TRACK_EXP02"."DISTANCE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ZAKAZ_KL_exp02" IS 'Заказ ЦК | Заказ ЦК | stg."ZMK_TRACK_EXP02"."ZAKAZ_KL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BUYER_exp02" IS 'Плановый покупатель (код) | Плановый покупатель (код) | stg."ZMK_TRACK_EXP02"."BUYER"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."END_LOC_CODE_exp04" IS 'Плановый порт выгрузки (код) | Плановый порт выгрузки (код) | stg."ZMK_TRACK_EXP04"."END_LOC_CODE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SPEC_ORDER_exp02" IS 'Номер заказа клиента | Номер заказа клиента | stg."ZMK_TRACK_EXP02"."SPEC_ORDER"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATE_ETADP_exp02" IS 'Дата прибытия в порт выгрузки план | Дата прибытия в порт выгрузки план | stg."ZMK_TRACK_EXP02"."DATE_ETADP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NMVESSEL_P_exp02" IS 'Номер рейса план | Номер рейса план | stg."ZMK_TRACK_EXP02"."NMVESSEL_P"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VEHICLE_F_exp02" IS 'Судно факт(код) | Судно факт(код) | stg."ZMK_TRACK_EXP02"."VEHICLE_F"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VEHICLE_F_TXT_exp02" IS 'Судно факт | Судно факт | stg."ZMK_TRACK_EXP02"."VEHICLE_F_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NMVESSEL_F_exp02" IS 'Номер рейса факт | Номер рейса факт | stg."ZMK_TRACK_EXP02"."NMVESSEL_F"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MATNR_exp02" IS 'Номер материала | Номер материала | stg."ZMK_TRACK_EXP02"."MATNR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MMCL_NAME_exp02" IS 'Марка клиента | Марка клиента | stg."ZMK_TRACK_EXP02"."MMCL_NAME"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MMBS_NAME_exp02" IS 'Марка по спецификации | Марка по спецификации | stg."ZMK_TRACK_EXP02"."MMBS_NAME"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VBELN_R_exp03" IS 'Плановый контракт (код) | Плановый контракт (код) | stg."ZMK_TRACK_EXP03"."VBELN_R"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BSTKD_P_exp02" IS 'Плановый контракт | Плановый контракт | stg."ZMK_TRACK_EXP02"."BSTKD_P"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DL_TO_exp02" IS 'Deadline доставки | Deadline доставки | stg."ZMK_TRACK_EXP02"."DL_TO"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SROK_FROMTO_exp02" IS 'Желаемый период отгрузки | Желаемый период отгрузки | stg."ZMK_TRACK_EXP02"."SROK_FROMTO"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."UNI_exp02" IS 'UNI | UNI | stg."ZMK_TRACK_EXP02"."UNI"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VESSEL_IMO_exp02" IS 'IMO судна | IMO судна | stg."ZMK_TRACK_EXP02"."VESSEL_IMO"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VESSEL_MMSI_exp02" IS 'MMSI судна | MMSI судна | stg."ZMK_TRACK_EXP02"."VESSEL_MMSI"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LATITUDE_CURR_exp02" IS 'Широта | Широта | stg."ZMK_TRACK_EXP02"."LATITUDE_CURR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LONGITUDE_CURR_exp02" IS 'Долгота | Долгота | stg."ZMK_TRACK_EXP02"."LONGITUDE_CURR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ETADP_KOP_exp02" IS 'Дата прибытия в порт выгрузки 2 план | Дата прибытия в порт выгрузки 2 план | stg."ZMK_TRACK_EXP02"."ETADP_KOP"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PBNUMBER_exp02" IS 'LotWshe/PB number | LotWshe/PB number | stg."ZMK_TRACK_EXP02"."PBNUMBER"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLFK_exp03" IS 'Признак План/Факт | Признак План/Факт | stg."ZMK_TRACK_EXP03"."PLFK"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLFK_PORTAL_exp03" IS 'Признак План/Факт для портала | Признак План/Факт для портала | stg."ZMK_TRACK_EXP03"."PLFK_PORTAL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATUS_AL2ALL_exp03" IS 'Статус для портала AL2ALL | Статус для портала AL2ALL | stg."ZMK_TRACK_EXP03"."STATUS_AL2ALL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PROG_DATE_exp03" IS 'Expected delivery | Expected delivery | stg."ZMK_TRACK_EXP03"."PROG_DATE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KUNNR_END_exp03" IS 'Конечный потребитель (код) | Конечный потребитель (код) | stg."ZMK_TRACK_EXP03"."KUNNR_END"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KUNNR_END_TXT_exp03" IS 'Конечный потребитель | Конечный потребитель | stg."ZMK_TRACK_EXP03"."KUNNR_END_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LFIMG_OUT_exp03" IS 'Отгруженное количество | Отгруженное количество | stg."ZMK_TRACK_EXP03"."LFIMG_OUT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VES_WAG_P_exp03" IS 'Запланированное количество | Запланированное количество | stg."ZMK_TRACK_EXP03"."VES_WAG_P"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_PIN_exp03" IS 'Provisional invoice | Provisional invoice | stg."ZMK_TRACK_EXP03"."VTEXT_PIN"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_REL_exp03" IS 'Группа Релиз | Группа Релиз | stg."ZMK_TRACK_EXP03"."SAMMG_REL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_FIN_exp03" IS 'Final Invoice | Final Invoice | stg."ZMK_TRACK_EXP03"."VTEXT_FIN"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLEDGE_VTEXT_IN_exp03" IS 'Номер документа pledge in | Номер документа pledge in | stg."ZMK_TRACK_EXP03"."PLEDGE_VTEXT_IN"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLEDGE_CLIENT_TXT_exp03" IS 'Pledge Bank | Pledge Bank | stg."ZMK_TRACK_EXP03"."PLEDGE_CLIENT_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLEDGE_LDDAT_exp03" IS 'Дата pledge in | Дата pledge in | stg."ZMK_TRACK_EXP03"."PLEDGE_LDDAT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ZAKAZ_KL_L_exp03" IS 'Производственный заказ | Производственный заказ | stg."ZMK_TRACK_EXP03"."ZAKAZ_KL_L"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."WH_DATE_POD_exp03" IS 'Дата начала хранения ин. склад | Дата начала хранения ин. склад | stg."ZMK_TRACK_EXP03"."WH_DATE_POD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ST_END_POD_exp03" IS 'Окончание хранения в ин. порту | Окончание хранения в ин. порту | stg."ZMK_TRACK_EXP03"."ST_END_POD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."FINISH_STORAGE2_exp03" IS 'Окончание хранение склад 2 | Окончание хранение склад 2 | stg."ZMK_TRACK_EXP03"."FINISH_STORAGE2"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BSTKD_CODE_exp03" IS 'Контракт (код) | Контракт (код) | stg."ZMK_TRACK_EXP03"."BSTKD_CODE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_L_exp02" IS 'Группа лот | Группа лот | stg."ZMK_TRACK_EXP02"."SAMMG_L"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_ND_exp03" IS 'Группа нотис о доставке | Группа нотис о доставке | stg."ZMK_TRACK_EXP03"."SAMMG_ND"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ZUONR_exp03" IS 'Рамочный контракт (код) | Рамочный контракт (код) | stg."ZMK_TRACK_EXP03"."ZUONR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."REALIZATION_DATE_CALC_exp04" IS 'Расчетная дата реализации | Расчетная дата реализации | stg."ZMK_TRACK_EXP04"."REALIZATION_DATE_CALC"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DOCNUMBER_exp04" IS 'Основание реализации | Основание реализации | stg."ZMK_TRACK_EXP04"."DOCNUMBER"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."EXPORTER_TXT_exp04" IS 'Экспортер | Экспортер | stg."ZMK_TRACK_EXP04"."EXPORTER_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BUYER_INC_exp04" IS 'Покупатель Incassa | Покупатель Incassa | stg."ZMK_TRACK_EXP04"."BUYER_INC"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."EXPORTER_exp04" IS 'Экспортер код | Экспортер код | stg."ZMK_TRACK_EXP04"."EXPORTER"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."REASON_exp02" IS 'Причина разделения | Причина разделения | stg."ZMK_TRACK_EXP02"."REASON"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LAND1_POD_exp02" IS 'Страна POD (код) | Страна POD (код) | stg."ZMK_TRACK_EXP02"."LAND1_POD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LANDX_POD_exp02" IS 'Страна POD | Страна POD | stg."ZMK_TRACK_EXP02"."LANDX_POD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."WWGSG_POD_exp02" IS 'Регион POD (код) | Регион POD (код) | stg."ZMK_TRACK_EXP02"."WWGSG_POD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BEZEK_POD_exp02" IS 'Регион POD | Регион POD | stg."ZMK_TRACK_EXP02"."BEZEK_POD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BSARK_exp04" IS 'Вид контракта | Вид контракта | stg."ZMK_TRACK_EXP04"."BSARK"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VBELN_ISH_exp03" IS 'Исходящая поставка | Исходящая поставка | stg."ZMK_TRACK_EXP03"."VBELN_ISH"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."WADAT_IST_ISH_exp04" IS 'Дата ОМ | Дата ОМ | stg."ZMK_TRACK_EXP04"."WADAT_IST_ISH"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."WBSTK_ISH_exp04" IS 'Статус ОМ | Статус ОМ | stg."ZMK_TRACK_EXP04"."WBSTK_ISH"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATE_CH_exp01" IS 'Дата последнего изменения | Дата последнего изменения | stg."ZMK_TRACK_EXP01"."DATE_CH"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."TIME_CH_exp01" IS 'Время последнего изменения | Время последнего изменения | stg."ZMK_TRACK_EXP01"."TIME_CH"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BSARK_TXT_exp04" IS 'Название вида контракта | Название вида контракта | stg."ZMK_TRACK_EXP04"."BSARK_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATEPPS_exp01" IS 'Дата перехода права собственности | Дата перехода права собственности | stg."ZMK_TRACK_EXP01"."DATEPPS"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."READY_TO_SHIP_DATE_exp04" IS 'Дата готовности к релизу | Дата готовности к релизу | stg."ZMK_TRACK_EXP04"."READY_TO_SHIP_DATE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PORT_FOR_CUSTOMER_exp03" IS 'Порт выгрузки для клиента | Порт выгрузки для клиента | stg."ZMK_TRACK_EXP03"."PORT_FOR_CUSTOMER"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VBELN_INSTR_exp02" IS 'Инструкция на доставку | Инструкция на доставку | stg."ZMK_TRACK_EXP02"."VBELN_INSTR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."INCO1_exp02" IS 'Плановый базис поставки | Плановый базис поставки | stg."ZMK_TRACK_EXP02"."INCO1"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."INCO2_exp02" IS 'Плановый Пункт доставки по инкотермс | Плановый Пункт доставки по инкотермс | stg."ZMK_TRACK_EXP02"."INCO2"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."GROUPS_exp03" IS 'Группа продукции | Группа продукции | stg."ZMK_TRACK_EXP03"."GROUPS"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BASIS2_LAND1_exp02" IS 'Страна пункта доставки по инкотермс | Страна пункта доставки по инкотермс | stg."ZMK_TRACK_EXP02"."BASIS2_LAND1"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ETD_L_PORT_ML_exp01" IS 'ETD | ETD | stg."ZMK_TRACK_EXP01"."ETD_L_PORT_ML"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ETAR_exp02" IS 'Expected BL | Expected BL | stg."ZMK_TRACK_EXP02"."ETAR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BSTKD_LOT_exp02" IS 'Контракт в лоте/Квотный контракт | Контракт в лоте/Квотный контракт | stg."ZMK_TRACK_EXP02"."BSTKD_LOT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."TCON_TO_BUYER_DATE_exp03" IS 'Дата перехода из консигнации клиенту | Отображает дату - «Дата Provisional Invoice» если «Признак консигнации» = X | stg."ZMK_TRACK_EXP03"."TCON_TO_BUYER_DATE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_FREL_exp03" IS 'Дата Финальный релиз | Отображает дату созданого финального релиза | stg."ZMK_TRACK_EXP03"."LDDAT_FREL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."FWH_EXIST_exp04" IS 'Наличие Иностранный склад | Отображает метку наличия промежуточного склада 1  в логистике | stg."ZMK_TRACK_EXP04"."FWH_EXIST"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATAUNLOAD_exp03" IS 'ТН/CMR: Дата выгрузки авто | Экспедиторская дата выгрузки автотранспорта | stg."ZMK_TRACK_EXP03"."DATAUNLOAD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."RIVER_EU_exp04" IS 'Наличие Иностранный склад 2 | Отображает метку наличия промежуточного склада 2  в логистике | stg."ZMK_TRACK_EXP04"."RIVER_EU"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LOCID_FP2_exp03" IS 'Иностранный порт 2 (код локации) | Отображает порт выгрузки 2 план/факт | stg."ZMK_TRACK_EXP03"."LOCID_FP2"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."UL_ATA_DATE_exp03" IS 'Дата прибытия УЛ | Отображает дату прибытия отправленную нам с интеграцией с Умной логистикой | stg."ZMK_TRACK_EXP03"."UL_ATA_DATE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATE_PERETAR_exp02" IS 'Дата перетарки | Экспедиторская дата перетарки | stg."ZMK_TRACK_EXP02"."DATE_PERETAR"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SVH_TXT_exp03" IS 'СВХ | Отображает тип СВХ: "На склад клиенту"; "Со склада клиенту" | stg."ZMK_TRACK_EXP03"."SVH_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BRUTTO_02_exp04" IS 'Вес брутто (с учетом склада) | Расчетный вес. Уменьшается с потреблением материала со склада | stg."ZMK_TRACK_EXP04"."BRUTTO_02"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATUS_ZHD_exp04" IS 'Статус движения по ЖД | Статус движения по ЖД | stg."ZMK_TRACK_EXP04"."STATUS_ZHD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATUS_SCB_exp04" IS 'Статус в Supply chain (Business) | Статус в Supply chain (Business) | stg."ZMK_TRACK_EXP04"."STATUS_SCB"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KNOTE_PLAN2_exp03" IS 'Плановый порт выгрузки 2 (код) | Плановая порт выгрузки 2 (код) | stg."ZMK_TRACK_EXP03"."KNOTE_PLAN2"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KNOTE_PLAN2_TXT_exp03" IS 'Плановый порт выгрузки 2 | Плановая порт выгрузки 2 | stg."ZMK_TRACK_EXP03"."KNOTE_PLAN2_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."FWH_LOCID_exp04" IS 'Иностранный порт (код локации) | Отображает порт выгрузки 1 план/факт | stg."ZMK_TRACK_EXP04"."FWH_LOCID"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_P_exp02" IS 'Группа поручение | Номер группы поручения | stg."ZMK_TRACK_EXP02"."SAMMG_P"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LAND1_exp04" IS 'Страна поставки по контракту (код) | Страна поставки по контракту (код) | stg."ZMK_TRACK_EXP04"."LAND1"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."COMMITM_exp04" IS 'Объем обязательств | Объем обязательств | stg."ZMK_TRACK_EXP04"."COMMITM"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."COMMITM_TOTAL_exp04" IS 'Объем обязательств итого | Объем обязательств итого | stg."ZMK_TRACK_EXP04"."COMMITM_TOTAL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_L_exp02" IS 'Номер лота | номер лота | stg."ZMK_TRACK_EXP02"."VTEXT_L"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."HMG_exp04" IS 'HMG | Гомогенизация | stg."ZMK_TRACK_EXP04"."HMG"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PORT_Y_LAND1_exp02" IS 'Страна порта выгрузки | Страна порта выгрузки 1 | stg."ZMK_TRACK_EXP02"."PORT_Y_LAND1"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STORAGE_CONFIRMATION_exp04" IS 'Дата Storage confirmation | Дата Storage confirmation | stg."ZMK_TRACK_EXP04"."STORAGE_CONFIRMATION"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SAMMG_SI2_exp03" IS 'Группа инструкции на отгрузку Ин Порт 2 | Группа инструкции на отгрузку Ин Порт 2 | stg."ZMK_TRACK_EXP02"."SAMMG_SI2"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_REL_exp03" IS 'Дата релиз | Дата релиз | stg."ZMK_TRACK_EXP03"."LDDAT_REL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_NOT_exp03" IS 'Номер нотиса | Номер нотиса | stg."ZMK_TRACK_EXP03"."VTEXT_NOT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_NOT_exp03" IS 'Дата нотиса | Дата нотиса | stg."ZMK_TRACK_EXP03"."LDDAT_NOT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VTEXT_FREL_exp03" IS 'Номер Финальный релиз | Номер Финальный релиз | stg."ZMK_TRACK_EXP03"."VTEXT_FREL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BUDAT_FIN_exp04" IS 'Дата оплаты Final Invoice | Дата оплаты Final Invoice | stg."ZMK_TRACK_EXP04"."BUDAT_FIN"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."CONTAINER_OUT_exp03" IS 'Номер ТС в ин. порту | Номер ТС в ин. порту | stg."ZMK_TRACK_EXP03"."CONTAINER_OUT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SDABW_PORT_exp03" IS 'Тип ТС в ин. порту | Тип ТС в ин. порту | stg."ZMK_TRACK_EXP03"."SDABW_PORT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MARKET_TXT_exp01" IS 'Рынок в отгрузке | Название рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) | stg."ZMK_TRACK_EXP01"."MARKET_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."TCON_exp03" IS 'Признак консигнации | Отображает "X" при налиичии в логистике Консигнационного склада | stg."ZMK_TRACK_EXP03"."TCON"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."TCON_TO_BUYER_DATE_exp03" IS 'Дата перехода из консигнации клиенту | Отображает дату - «Дата Provisional Invoice» если «Признак консигнации» = X  | stg."ZMK_TRACK_EXP03"."TCON_TO_BUYER_DATE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATAUNLOAD_exp03" IS 'ТН/CMR: Дата выгрузки авто | Экспедиторская дата выгрузки автотранспорта | stg."ZMK_TRACK_EXP03"."DATAUNLOAD"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ID_WAY_exp04" IS 'Сценарий маршрута | Сценарий маршрута | stg."ZMK_TRACK_EXP04"."ID_WAY"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LANDX_exp04" IS 'Страна поставки по контракту | Страна поставки по контракту | stg."ZMK_TRACK_EXP04"."LANDX"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."REALIZATION_STATUS_exp04" IS 'Статус Реализации | Статус готовности к реализации | stg."ZMK_TRACK_EXP04"."REALIZATION_STATUS"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SVH_02_EXIST_exp01" IS 'Есть запись с кодом СВХ 02 | Есть запись с кодом СВХ 02 | stg."ZMK_TRACK_EXP01"."SVH_02_EXIST"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DELIV_REGION_exp04" IS 'Регион поставки | Регион поставки | stg."ZMK_TRACK_EXP04"."DELIV_REGION"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATEOT_exp01_month_year" IS 'Месяц и год отгрузки | Месяц и год отгрузки | stg."ZMK_TRACK_EXP01"."DATEOT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VOYAGE_exp03" IS 'Номер рейса | Номер рейса внутренний | stg."ZMK_TRACK_EXP03"."VOYAGE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SVH_CODE_exp03" IS 'Тип СВХ(код) | Тип СВХ (код), возможные значения для текстов к этим кодам: "На склад клиенту"; "Со склада клиенту" | stg."ZMK_TRACK_EXP03"."SVH_CODE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."CUSTOMID_exp01" IS 'Заказчик | Системный номер дебитора, который является покупателем у завода производителя, т.е. тот кому отгружает продукцию Завод производитель. | stg."ZMK_TRACK_EXP01"."CUSTOMID"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MMCL_CODE_exp01" IS 'Код марки клиента | использовался для данных на RAC, более не актуален | stg."ZMK_TRACK_EXP01"."MMCL_CODE"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."STATUS_SC_exp04" IS 'Статус в Supply chain (Portal) | Статус логистического этапа транспортировки/хранения для Клиентского портала | stg."ZMK_TRACK_EXP04"."STATUS_SC"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLEDGE_CLIENT_exp03" IS 'Pledge Bank (code) | Имя кредитора, который открыл нам кредитную линию по залогу, то у кого мы взяли деньги. Залог- это кредитная линия под проценты/комиссию, под залог метала или дебиторской задолженности, в зависимости от вида заключенного договора. | stg."ZMK_TRACK_EXP03"."PLEDGE_CLIENT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."REALIZATION_DATE_PF_exp04" IS 'Дата реализации План/Факт | - | stg."ZMK_TRACK_EXP04"."REALIZATION_DATE_PF"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."POTREBIT_exp01" IS 'Потребитель | Код контрагента, который является получателем  металла. Потребитель может быть и Конечным потребителем | stg."ZMK_TRACK_EXP01"."POTREB"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PORT_Y_exp02" IS 'Порт выгрузки (код) | Системный номер порта выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, P000000034 | stg."ZMK_TRACK_EXP02"."PORT_Y"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_REA_exp03" IS 'Дата Реализации | - | stg."ZMK_TRACK_EXP03"."LDDAT_REA"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SYSTEMID_exp01" IS 'Внутренний уникальный идентификатор записи | - | stg."ZMK_TRACK_EXP01"."SYSTEMID"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MATKL_exp01" IS 'Группа материалов | - | stg."ZMK_TRACK_EXP01"."MATKL"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PIMARY_exp01" IS 'Материал | - | stg."ZMK_TRACK_EXP01"."PIMARY"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATAPRZD_RF_exp02" IS 'Плановая дата принятия в порту | - | stg."ZMK_TRACK_EXP02"."DATAPRZD_RF"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLSTDATFR_exp03" IS 'Плановая дата отгрузки со склада ин. порта | - | stg."ZMK_TRACK_EXP03"."PLSTDATFR"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLSTDATFR2_exp03" IS 'Плановая дата отгрузки со склада ин. порта 2 | - | stg."ZMK_TRACK_EXP03"."PLSTDATFR2"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DAYS1_exp04" IS 'Норма приемки контейнера в портy | - | stg."ZMK_TRACK_EXP04"."DAYS1"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."FWH_DAYS1_exp04" IS 'Норма приемки терминал/склад ин. порта | - | stg."ZMK_TRACK_EXP04"."FWH_DAYS1"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."FWH2_DAYS1_exp04" IS 'Норма приемки терминал/склад ин. порта 2 | - | stg."ZMK_TRACK_EXP04"."FWH2_DAYS1"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."EXPECTED_BL_EXP_exp02" IS 'Дата коносамента план | - | stg."ZMK_TRACK_EXP02"."EXPECTED_BL_EXP"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LDDAT_KOP_P_exp04" IS 'Дата коносамента в ин.порту план | - | stg."ZMK_TRACK_EXP04"."LDDAT_KOP_P"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."DATAPRZD_P_exp02" IS 'Плановая дата прибытия по ЖД (с фактом) | - | stg."ZMK_TRACK_EXP02"."DATAPRZD_P"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ORDER_exp01" IS 'Заказ ЦК в отгрузке | - | stg."ZMK_TRACK_EXP01"."ORDER_"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLATF_exp01" IS 'Платформа | - | stg."ZMK_TRACK_EXP01"."PLATF"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MAKTX_exp02" IS 'Наименование материала | - | stg."ZMK_TRACK_EXP02"."MAKTX"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."ROUTE_SHIP_exp01" IS 'Маршрут в отгрузке | - | stg."ZMK_TRACK_EXP01"."ROUTE_SHIP"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."SDABW_SHIP_exp01" IS 'Тип вагона, указанный в графике отгрузке на заводе-производ. | - | stg."ZMK_TRACK_EXP01"."SDABW_SHIP"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."UNLOADDATE_Y_exp02" IS 'Дата выгрузки в порту | - | stg."ZMK_TRACK_EXP02"."UNLOADDATE_Y"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."VAGON_P_exp02" IS 'Контейнер | - | stg."ZMK_TRACK_EXP02"."VAGON_P"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."PLANT_exp01" IS 'Завод (код) | - | stg."ZMK_TRACK_EXP01"."PLANT"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."NSERT_exp01" IS 'Номер сертификата | - | stg."ZMK_TRACK_EXP01"."NSERT"'; 
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."KUNAG_L_exp02" IS 'Покупатель в лоте | - | stg."ZMK_TRACK_EXP02"."KUNAG_L"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."MIRR_STATUS_exp04" IS 'Статус зеркалирования | - | stg."ZMK_TRACK_EXP04"."MIRR_STATUS"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."BUYER_TXT_exp02" IS 'Плановый покупатель | - | stg."ZMK_TRACK_EXP02"."BUYER_TXT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys."LGORT_exp01" IS 'Принимающий склад  | - | stg."ZMK_TRACK_EXP01"."LGORT"';
COMMENT ON COLUMN ods.map_zmk_track_exp_keys.is_delivery_not_exist_in_all_stg_tables IS 'Индикатор: Поставка присутствует не во всех таблицах источника | - | stg."ZMK_TRACK_EXP01-04"."VBELN_P"';
