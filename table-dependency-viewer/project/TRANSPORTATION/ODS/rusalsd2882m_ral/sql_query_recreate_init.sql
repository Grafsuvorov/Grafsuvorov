drop table if exists ods."/rusal/sd2882m_ral";

create table ods."/rusal/sd2882m_ral" ( -- ключ: market, reg_perio, matkl, numvr, numlinevr
	market bpchar(1),
	reg_perio varchar(6),
	matkl varchar(9),
	numvr varchar(2),
	numlinevr varchar(6),
	zakaz_kl varchar(6),
	werks varchar(4),
	vbeln_r varchar(10),
	zperev varchar(2),
	fact_date_z date,
	potreb varchar(10),
	buyer varchar(10),
	vbeln_ext varchar(20),
	trader_buyer varchar(10),
	locid varchar(10),
	quota varchar(6),
	inco2 varchar(28),
	kod_end_loc varchar(10),
	end_loc varchar(30),
	spec_order varchar(50),
	bstkd varchar(35),
	inco1 varchar(3),
	deliv_land varchar(3),
	potreb_land varchar(3),
	werks_trade varchar(10),
	sd_peretarka varchar(2),
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (market, reg_perio, matkl, numvr, numlinevr);

comment on table ods."/rusal/sd2882m_ral" is 'Таблица версий отчета';
comment on column ods."/rusal/sd2882m_ral".market is 'Трейдеры: рынок сбыта | Трейдеры: рынок сбыта | stg."/RUSAL/SD2882M"."MARKET"';
comment on column ods."/rusal/sd2882m_ral".reg_perio is 'Трейдеры: Месяц отгрузки с завода | Трейдеры: Месяц отгрузки с завода | stg."/RUSAL/SD2882M"."REG_PERIO"';
comment on column ods."/rusal/sd2882m_ral".matkl is 'Группа материалов | Группа материалов | stg."/RUSAL/SD2882M"."MATKL"';
comment on column ods."/rusal/sd2882m_ral".numvr is 'Номер версии/корректировки заказа | Номер версии/корректировки заказа | stg."/RUSAL/SD2882M"."NUMVR"';
comment on column ods."/rusal/sd2882m_ral".numlinevr is 'Трейдеры: Номер строки версии | Трейдеры: Номер строки версии | stg."/RUSAL/SD2882M"."NUMLINEVR"';
comment on column ods."/rusal/sd2882m_ral".zakaz_kl is 'Заказ ЦК | Заказ ЦК | stg."/RUSAL/SD2882M"."ZAKAZ_KL"';
comment on column ods."/rusal/sd2882m_ral".werks is 'Завод | Завод | stg."/RUSAL/SD2882M"."WERKS"';
comment on column ods."/rusal/sd2882m_ral".vbeln_r is 'Трейдеры: Документ квоты | Трейдеры: Документ квоты | stg."/RUSAL/SD2882M"."VBELN_R"';
comment on column ods."/rusal/sd2882m_ral".zperev is 'ПлатитПеревозчику ( Плательщик тарифа ) | ПлатитПеревозчику ( Плательщик тарифа ) | stg."/RUSAL/SD2882M"."ZPEREV"';
comment on column ods."/rusal/sd2882m_ral".fact_date_z is 'Фактическая дата получения заказа | Фактическая дата получения заказа | stg."/RUSAL/SD2882M"."FACT_DATE_Z"';
comment on column ods."/rusal/sd2882m_ral".potreb is 'Потребитель | Потребитель | stg."/RUSAL/SD2882M"."POTREB"';
comment on column ods."/rusal/sd2882m_ral".buyer is 'Покупатель | Покупатель | stg."/RUSAL/SD2882M"."BUYER"';
comment on column ods."/rusal/sd2882m_ral".vbeln_ext is 'Внешний номер заказа для AL | Трейдеры: Внешний номер заказа для AL | stg."/RUSAL/SD2882M"."VBELN_EXT"';
comment on column ods."/rusal/sd2882m_ral".trader_buyer is 'Номер дебитора | Номер дебитора | stg."/RUSAL/SD2882M"."TRADER_BUYER"';
comment on column ods."/rusal/sd2882m_ral".locid is 'Трейдеры: Пограничный порт | Трейдеры: Пограничный порт | stg."/RUSAL/SD2882M"."LOCID"';
comment on column ods."/rusal/sd2882m_ral".quota is 'Трейдеры: квота | Трейдеры: квота | stg."/RUSAL/SD2882M"."QUOTA"';
comment on column ods."/rusal/sd2882m_ral".inco2 is 'Пункт поставки по контракту | Пункт поставки по контракту | stg."/RUSAL/SD2882M"."INCO2"';
comment on column ods."/rusal/sd2882m_ral".kod_end_loc is 'Код порта выгрузки / перев. вне РФ | Код порта выгрузки / перев. вне РФ | stg."/RUSAL/SD2882M"."KOD_END_LOC';
comment on column ods."/rusal/sd2882m_ral".end_loc is 'Трейдеры: Порт выгрузки/перевалки вне РФ | Трейдеры: Порт выгрузки/перевалки вне РФ | stg."/RUSAL/SD2882M"."END_LOC"';
comment on column ods."/rusal/sd2882m_ral".spec_order is 'Трейдеры: спец. заказ клиента | Трейдеры: спец. заказ клиента | stg."/RUSAL/SD2882M"."SPEC_ORDER"';
comment on column ods."/rusal/sd2882m_ral".bstkd is 'Трейдеры: Контракт | Трейдеры: Контракт | stg."/RUSAL/SD2882M"."BSTKD"';
comment on column ods."/rusal/sd2882m_ral".inco1 is 'Трейдеры: Базис поставки (Incoterms) | Трейдеры: Базис поставки (Incoterms) | stg."/RUSAL/SD2882M"."INCO1"';
comment on column ods."/rusal/sd2882m_ral".deliv_land is 'Страна поставки по контракту | Страна поставки по контракту | stg."/RUSAL/SD2882M"."DELIV_LAND"';
comment on column ods."/rusal/sd2882m_ral".potreb_land is 'Страна конечного потребителя | Страна конечного потребителя | stg."/RUSAL/SD2882M"."POTREB_LAND"';
comment on column ods."/rusal/sd2882m_ral".werks_trade is 'Завод в файле | Завод в файле | stg."/RUSAL/SD2882M_1"."WERKS_TRADE"';
comment on column ods."/rusal/sd2882m_ral".sd_peretarka is 'Вид транспортного средства (Тип контейнера) Перетарка | Вид транспортного средства (Тип контейнера) Перетарка | stg."/RUSAL/SD2882M"."SD_PERETARKA"';