drop table if exists ods."ekko_ral" cascade;

create table ods."ekko_ral" (
	"ebeln" varchar(10) null,
	"aedat" date null,
	"bedat" date null,
	"bsart" varchar(4) null,
	"bstyp" varchar(1) null,
	"bukrs" varchar(4) null,
	"ekgrp" varchar(3) null,
	"ekorg" varchar(4) null,
	"frggr" varchar(2) null,
	"frgke" varchar(1) null,
	"frgrl" varchar(1) null,
	"frgsx" varchar(2) null,
	"frgzu" varchar(8) null,
	"ihrez" varchar(12) null,
	"inco1" varchar(3) null,
	"inco2" varchar(28) null,
	"kalsm" varchar(6) null,
	"kdatb" date null,
	"kdate" date null,
	"knumv" varchar(10) null,
	"ktwrt" numeric(15, 2) null,
	"lifnr" varchar(10) null,
	"telf1" varchar(16) null,
	"unsez" varchar(12) null,
	"verkf" varchar(30) null,
	"waers" varchar(5) null,
	"zterm" varchar(4) null,
	"zurdog" varchar(60) null,
	"zzbanfn" varchar(10) null,
	"zzbizp" varchar(1) null,
	"zzbvtyp" varchar(4) null,
	"zzcomercialloan" numeric(5, 2) null,
	"zzdogkr" varchar(120) null,
	"zzdtots1" date null,
	"zzdtots2" date null,
	"zzdtots3" date null,
	"zzdtots4" date null,
	"zzebeln" varchar(10) null,
	"zzedo" varchar(1) null,
	"zzernam" varchar(12) null,
	"zzihrez" varchar(128) null,
	"zzknote" varchar(10) null,
	"zzkondm" varchar(2) null,
	"zzktwrt" numeric(15, 2) null,
	"zzkurs" varchar(1) null,
	"zzmwskz" varchar(2) null,
	"zzniokrtxt" varchar(50) null,
	"zznomore" numeric(5, 2) null,
	"zznumpr" varchar(35) null,
	"zzonepenalty" numeric(5, 2) null,
	"zzonepenalty1" numeric(13, 2) null,
	"zzpenalty" numeric(5, 2) null,
	"zzpenaltyrefrate" varchar(1) null,
	"zzppskd" varchar(3) null,
	"zzquota" varchar(6) null,
	"zzrcode" varchar(1) null,
	"zzresp" varchar(16) null,
	"zzsegrep" varchar(2) null,
	"zzsum" varchar(1) null,
	"zztariff" varchar(2) null,
	"zztempid" varchar(10) null,
	"zztzr" numeric(13, 2) null,
	"zzunidoc" varchar(25) null,
	"zzunidoc_s" varchar(128) null,
	"zzvbeln" varchar(10) null,
	"zzvbeln_zx" varchar(10) null,
	"zzzhdtarif" varchar(2) null,
	"ernam" varchar(12) null,
	"adrnr" varchar(10) null,
	"description" varchar(40) null,
	"zzcostr" varchar(2) null,
	"zzpaydox" varchar(1) null,
	"zzpaymentrule" varchar(1) null,
	"zzknanf_term" varchar(10) null,
	"zzport" varchar(10) null,
	"konnr" varchar(10) null,
	"memory" varchar(1) null,
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by ("ebeln");

comment on table ods."ekko_ral" is 'Заголовок документа закупки';
comment on column ods."ekko_ral"."ebeln" is 'Номер документа закупки | Номер документа закупки | EKKO.EBELN';
comment on column ods."ekko_ral"."aedat" is 'Дата создания записи | Дата создания записи | EKKO.AEDAT';
comment on column ods."ekko_ral"."bedat" is 'Дата документа закупки | Дата документа закупки | EKKO.BEDAT';
comment on column ods."ekko_ral"."bsart" is 'Вид документа закупки | Вид документа закупки | EKKO.BSART';
comment on column ods."ekko_ral"."bstyp" is 'Тип документа закупки | Тип документа закупки | EKKO.BSTYP';
comment on column ods."ekko_ral"."bukrs" is 'Балансовая единица | Балансовая единица | EKKO.BUKRS';
comment on column ods."ekko_ral"."ekgrp" is 'Группа закупок | Группа закупок | EKKO.EKGRP';
comment on column ods."ekko_ral"."ekorg" is 'Закупочная организация | Закупочная организация | EKKO.EKORG';
comment on column ods."ekko_ral"."frggr" is 'Группа деблокирования | Группа деблокирования | EKKO.FRGGR';
comment on column ods."ekko_ral"."frgke" is 'Инд. деблокирования документа закупки | Инд. деблокирования документа закупки | EKKO.FRGKE';
comment on column ods."ekko_ral"."frgrl" is 'Неполное деблокирование | Неполное деблокирование | EKKO.FRGRL';
comment on column ods."ekko_ral"."frgsx" is 'Стратегия деблокирования | Стратегия деблокирования | EKKO.FRGSX';
comment on column ods."ekko_ral"."frgzu" is 'Статус деблокир. | Статус деблокир. | EKKO.FRGZU';
comment on column ods."ekko_ral"."ihrez" is 'Регистр.№ | Регистр.№ | EKKO.IHREZ';
comment on column ods."ekko_ral"."inco1" is 'Инкотермс | Инкотермс | EKKO.INCO1';
comment on column ods."ekko_ral"."inco2" is 'Инкотермс | Инкотермс | EKKO.INCO2';
comment on column ods."ekko_ral"."kalsm" is 'Схема (расчет цен | Схема (расчет цен | EKKO.KALSM';
comment on column ods."ekko_ral"."kdatb" is 'Начальный срок действия | Начальный срок действия | EKKO.KDATB';
comment on column ods."ekko_ral"."kdate" is 'Конечный срок действия | Конечный срок действия | EKKO.KDATE';
comment on column ods."ekko_ral"."knumv" is 'Номер условия документа | Номер условия документа | EKKO.KNUMV';
comment on column ods."ekko_ral"."ktwrt" is 'Договорная стоимость области заголовка на кажд. распределен. | Договорная стоимость области заголовка на кажд. распределен. | EKKO.KTWRT';
comment on column ods."ekko_ral"."lifnr" is 'Номер счета поставщика | Номер счета поставщика | EKKO.LIFNR';
comment on column ods."ekko_ral"."telf1" is 'Номер телефона поставщика | Номер телефона поставщика | EKKO.TELF1';
comment on column ods."ekko_ral"."unsez" is '№ приложения | № приложения | EKKO.UNSEZ';
comment on column ods."ekko_ral"."verkf" is '№ контракта у поставщика | № контракта у поставщика | EKKO.VERKF';
comment on column ods."ekko_ral"."waers" is 'Код валюты | Код валюты | EKKO.WAERS';
comment on column ods."ekko_ral"."zterm" is 'Код условий платежа | Код условий платежа | EKKO.ZTERM';
comment on column ods."ekko_ral"."zurdog" is 'Юридический номер договора | Юридический номер договора | EKKO.ZURDOG';
comment on column ods."ekko_ral"."zzbanfn" is 'Заявка ПланПлатежей | Заявка ПланПлатежей | EKKO.ZZBANFN';
comment on column ods."ekko_ral"."zzbizp" is 'Бюджет | Бюджет | EKKO.ZZBIZP';
comment on column ods."ekko_ral"."zzbvtyp" is 'Тип банка-партнера | Тип банка-партнера | EKKO.ZZBVTYP';
comment on column ods."ekko_ral"."zzcomercialloan" is 'Плата за финансирование/коммерческий кредит | Плата за финансирование/коммерческий кредит | EKKO.ZZCOMERCIALLOAN';
comment on column ods."ekko_ral"."zzdogkr" is 'Куратор договора | Куратор договора | EKKO.ZZDOGKR';
comment on column ods."ekko_ral"."zzdtots1" is 'Дата отсрочки части платежа 1 | Дата отсрочки части платежа 1 | EKKO.ZZDTOTS1';
comment on column ods."ekko_ral"."zzdtots2" is 'Дата отсрочки части платежа 2 | Дата отсрочки части платежа 2 | EKKO.ZZDTOTS2';
comment on column ods."ekko_ral"."zzdtots3" is 'Дата отсрочки части платежа 3 | Дата отсрочки части платежа 3 | EKKO.ZZDTOTS3';
comment on column ods."ekko_ral"."zzdtots4" is 'Дата отсрочки части платежа 4 | Дата отсрочки части платежа 4 | EKKO.ZZDTOTS4';
comment on column ods."ekko_ral"."zzebeln" is 'Номер документа закупки | Номер документа закупки | EKKO.ZZEBELN';
comment on column ods."ekko_ral"."zzedo" is 'ЭДО | ЭДО | EKKO.ZZEDO';
comment on column ods."ekko_ral"."zzernam" is 'Пользователь PayDox | Пользователь PayDox | EKKO.ZZERNAM';
comment on column ods."ekko_ral"."zzihrez" is 'Регистр.№ спецификации | Регистр.№ спецификации | EKKO.ZZIHREZ';
comment on column ods."ekko_ral"."zzknote" is 'ИНКОТЕРМС2(Транспортный узел) | ИНКОТЕРМС2(Транспортный узел) | EKKO.ZZKNOTE';
comment on column ods."ekko_ral"."zzkondm" is 'Тип рыноч.индикатора | Тип рыноч.индикатора | EKKO.ZZKONDM';
comment on column ods."ekko_ral"."zzktwrt" is 'Договорная стоимость области заголовка на кажд. распределен. | Договорная стоимость области заголовка на кажд. распределен. | EKKO.ZZKTWRT';
comment on column ods."ekko_ral"."zzkurs" is 'Условие курса оплаты | Условие курса оплаты | EKKO.ZZKURS';
comment on column ods."ekko_ral"."zzmwskz" is 'Код НДС для ТЗР и Доп.расходов | Код НДС для ТЗР и Доп.расходов | EKKO.ZZMWSKZ';
comment on column ods."ekko_ral"."zzniokrtxt" is 'Название НИОКР | Название НИОКР | EKKO.ZZNIOKRTXT';
comment on column ods."ekko_ral"."zznomore" is 'Не более | Не более | EKKO.ZZNOMORE';
comment on column ods."ekko_ral"."zznumpr" is 'Номер протокола | Номер протокола | EKKO.ZZNUMPR';
comment on column ods."ekko_ral"."zzonepenalty" is 'Разовый штраф | Разовый штраф | EKKO.ZZONEPENALTY';
comment on column ods."ekko_ral"."zzonepenalty1" is 'Разовый штраф | Разовый штраф | EKKO.ZZONEPENALTY1';
comment on column ods."ekko_ral"."zzpenalty" is 'Пеня | Пеня | EKKO.ZZPENALTY';
comment on column ods."ekko_ral"."zzpenaltyrefrate" is 'Пеня по ставке рефинансирования ЦБ | Пеня по ставке рефинансирования ЦБ | EKKO.ZZPENALTYREFRATE';
comment on column ods."ekko_ral"."zzppskd" is 'Код ППС | Код ППС | EKKO.ZZPPSKD';
comment on column ods."ekko_ral"."zzquota" is 'Трейдеры: квота | Трейдеры: квота | EKKO.ZZQUOTA';
comment on column ods."ekko_ral"."zzrcode" is 'Код типа аренды | Код типа аренды | EKKO.ZZRCODE';
comment on column ods."ekko_ral"."zzresp" is 'Центр Ответств | Центр Ответств | EKKO.ZZRESP';
comment on column ods."ekko_ral"."zzsegrep" is 'Сегмент отчетности | Сегмент отчетности | EKKO.ZZSEGREP';
comment on column ods."ekko_ral"."zzsum" is 'Рассчитать от суммы | Рассчитать от суммы | EKKO.ZZSUM';
comment on column ods."ekko_ral"."zztariff" is 'Тариф | Тариф | EKKO.ZZTARIFF';
comment on column ods."ekko_ral"."zztempid" is '№ документ-черновик | № документ-черновик | EKKO.ZZTEMPID';
comment on column ods."ekko_ral"."zztzr" is 'Сумма ТЗР и Доп.расходов | Сумма ТЗР и Доп.расходов | EKKO.ZZTZR';
comment on column ods."ekko_ral"."zzunidoc" is 'Единый номер договора | Единый номер договора | EKKO.ZZUNIDOC';
comment on column ods."ekko_ral"."zzunidoc_s" is 'Ссылочный номер договора | Ссылочный номер договора | EKKO.ZZUNIDOC_S';
comment on column ods."ekko_ral"."zzvbeln" is 'Агентский контракт | Агентский контракт | EKKO.ZZVBELN';
comment on column ods."ekko_ral"."zzvbeln_zx" is 'Договор хранения | Договор хранения | EKKO.ZZVBELN_ZX';
comment on column ods."ekko_ral"."zzzhdtarif" is 'ЖД-тариф | ЖД-тариф | EKKO.ZZZHDTARIF';
comment on column ods."ekko_ral"."ernam" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | EKKO.ERNAM';
comment on column ods."ekko_ral"."adrnr" is 'Номер адреса | Номер адреса | EKKO.ADRNR';
comment on column ods."ekko_ral"."description" is 'Название контракта | Название контракта | EKKO.DESCRIPTION';
comment on column ods."ekko_ral"."zzcostr" is 'Регион затрат | Регион затрат | EKKO.ZZCOSTR';
comment on column ods."ekko_ral"."zzpaydox" is 'Статус в PayDox | Статус в PayDox | EKKO.ZZPAYDOX';
comment on column ods."ekko_ral"."zzpaymentrule" is 'Правило расчета даты оплаты | Правило расчета даты оплаты | EKKO.ZZPAYMENTRULE';
comment on column ods."ekko_ral"."zzknanf_term" is 'Терминал | Терминал | EKKO.ZZKNANF_TERM';
comment on column ods."ekko_ral"."zzport" is 'Порт | Порт | EKKO.ZZPORT';
comment on column ods."ekko_ral"."konnr" is 'Номер основного договора | Номер основного договора | EKKO.KONNR';
comment on column ods."ekko_ral"."memory" is 'Заказ на поставку не полон | Заказ на поставку не полон | EKKO.MEMORY';
