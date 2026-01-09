drop table if exists ods."/rusal/lepervlka_ral";

create table ods."/rusal/lepervlka_ral" (
	"id" varchar(10) null,
	"pos" varchar(6) null,
	"type_load" varchar(2) null,
	"numvag" varchar(20) null,
	"numnakl" varchar(35) null,
	"weightnet" numeric(13, 3) null,
	"regdate" date null,
	"senddate" date null,
	"cartare" varchar(3) null,
	"type_vagon" varchar(4) null,
	"zterminal" varchar(10) null,
	"genaktdate" date null,
	"arrvesdate" date null,
	"delivery_in" varchar(10) null,
	"knote" varchar(10) null,
	"knote1" varchar(10) null,
	"knote2" varchar(10) null,
	"werks_from" varchar(4) null,
	"werks_to" varchar(4) null,
	"matnr" varchar(18) null,
	"vehicle" varchar(10) null,
	"conosnum" varchar(30) null,
	"dock_knote" varchar(10) null,
	"erdat" date null,
	"erzet" time null,
	"ernam" varchar(12) null,
	"aedat" date null,
	"aezet" time null,
	"aenam" varchar(12) null,
	"type_prod" varchar(1) null,
	"bldat" date null,
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
distributed by ("numvag", "numnakl");

comment on table ods."/rusal/lepervlka_ral" is 'LE1158M: Перевалка';
comment on column ods."/rusal/lepervlka_ral"."id" is 'ID загрузки | ID загрузки | /RUSAL/LEPERVLKA.ID';
comment on column ods."/rusal/lepervlka_ral"."pos" is 'Позиция загрузки | Позиция загрузки | /RUSAL/LEPERVLKA.POS';
comment on column ods."/rusal/lepervlka_ral"."type_load" is 'Тип загрузки | Тип загрузки | /RUSAL/LEPERVLKA.TYPE_LOAD';
comment on column ods."/rusal/lepervlka_ral"."numvag" is 'Ид. транспортировки | Ид. транспортировки | /RUSAL/LEPERVLKA.NUMVAG';
comment on column ods."/rusal/lepervlka_ral"."numnakl" is 'Транспортная накладная | Транспортная накладная | /RUSAL/LEPERVLKA.NUMNAKL';
comment on column ods."/rusal/lepervlka_ral"."weightnet" is 'Вес нетто | Вес нетто | /RUSAL/LEPERVLKA.WEIGHTNET';
comment on column ods."/rusal/lepervlka_ral"."regdate" is 'Дата регистрации вагона | Дата регистрации вагона | /RUSAL/LEPERVLKA.REGDATE';
comment on column ods."/rusal/lepervlka_ral"."senddate" is 'Дата отправки вагона | Дата отправки вагона | /RUSAL/LEPERVLKA.SENDDATE';
comment on column ods."/rusal/lepervlka_ral"."cartare" is 'Тип тары | Тип тары | /RUSAL/LEPERVLKA.CARTARE';
comment on column ods."/rusal/lepervlka_ral"."type_vagon" is 'Тип ПС | Тип ПС | /RUSAL/LEPERVLKA.TYPE_VAGON';
comment on column ods."/rusal/lepervlka_ral"."zterminal" is 'Терминал порта - узел | Терминал порта - узел | /RUSAL/LEPERVLKA.ZTERMINAL';
comment on column ods."/rusal/lepervlka_ral"."genaktdate" is 'Дата генерального акта | Дата генерального акта | /RUSAL/LEPERVLKA.GENAKTDATE';
comment on column ods."/rusal/lepervlka_ral"."arrvesdate" is 'Дата прихода судна | Дата прихода судна | /RUSAL/LEPERVLKA.ARRVESDATE';
comment on column ods."/rusal/lepervlka_ral"."delivery_in" is 'Номер входящей поставки на 1511 | Номер входящей поставки на 1511 | /RUSAL/LEPERVLKA.DELIVERY_IN';
comment on column ods."/rusal/lepervlka_ral"."knote" is 'Транспортный узел порта | Транспортный узел порта | /RUSAL/LEPERVLKA.KNOTE';
comment on column ods."/rusal/lepervlka_ral"."knote1" is 'Станция отправления | Станция отправления | /RUSAL/LEPERVLKA.KNOTE1';
comment on column ods."/rusal/lepervlka_ral"."knote2" is 'Станция назначения | Станция назначения | /RUSAL/LEPERVLKA.KNOTE2';
comment on column ods."/rusal/lepervlka_ral"."werks_from" is 'Завод-отправитель | Завод-отправитель | /RUSAL/LEPERVLKA.WERKS_FROM';
comment on column ods."/rusal/lepervlka_ral"."werks_to" is 'Завод-получатель | Завод-получатель | /RUSAL/LEPERVLKA.WERKS_TO';
comment on column ods."/rusal/lepervlka_ral"."matnr" is 'Номер материала | Номер материала | /RUSAL/LEPERVLKA.MATNR';
comment on column ods."/rusal/lepervlka_ral"."vehicle" is 'Номер судна | Номер судна | /RUSAL/LEPERVLKA.VEHICLE';
comment on column ods."/rusal/lepervlka_ral"."conosnum" is 'Номер коносамента | Номер коносамента | /RUSAL/LEPERVLKA.CONOSNUM';
comment on column ods."/rusal/lepervlka_ral"."dock_knote" is 'Причалы узел | Причалы узел | /RUSAL/LEPERVLKA.DOCK_KNOTE';
comment on column ods."/rusal/lepervlka_ral"."erdat" is 'Дата создания записи | Дата создания записи | /RUSAL/LEPERVLKA.ERDAT';
comment on column ods."/rusal/lepervlka_ral"."erzet" is 'Время ввода | Время ввода | /RUSAL/LEPERVLKA.ERZET';
comment on column ods."/rusal/lepervlka_ral"."ernam" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | /RUSAL/LEPERVLKA.ERNAM';
comment on column ods."/rusal/lepervlka_ral"."aedat" is 'Дата последнего изменения | Дата последнего изменения | /RUSAL/LEPERVLKA.AEDAT';
comment on column ods."/rusal/lepervlka_ral"."aezet" is 'Время последнего изменения | Время последнего изменения | /RUSAL/LEPERVLKA.AEZET';
comment on column ods."/rusal/lepervlka_ral"."aenam" is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | /RUSAL/LEPERVLKA.AENAM';
comment on column ods."/rusal/lepervlka_ral"."type_prod" is 'Схема реализации | Схема реализации | /RUSAL/LEPERVLKA.TYPE_PROD';
comment on column ods."/rusal/lepervlka_ral"."bldat" is 'Дата коносамента | Дата коносамента | /RUSAL/LEPERVLKA.BLDAT';