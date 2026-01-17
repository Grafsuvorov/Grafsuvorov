drop table if exists ods."/rusal/lepervlk1_ral";

create table ods."/rusal/lepervlk1_ral" (
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

comment on table ods."/rusal/lepervlk1_ral" is 'LE1158M: Перевалка (предварительная)';
comment on column ods."/rusal/lepervlk1_ral"."id" is 'ID загрузки | ID загрузки | /RUSAL/LEPERVLK1.ID';
comment on column ods."/rusal/lepervlk1_ral"."pos" is 'Позиция загрузки | Позиция загрузки | /RUSAL/LEPERVLK1.POS';
comment on column ods."/rusal/lepervlk1_ral"."type_load" is 'Тип загрузки | Тип загрузки | /RUSAL/LEPERVLK1.TYPE_LOAD';
comment on column ods."/rusal/lepervlk1_ral"."numvag" is 'Ид. транспортировки | Ид. транспортировки | /RUSAL/LEPERVLK1.NUMVAG';
comment on column ods."/rusal/lepervlk1_ral"."numnakl" is 'Транспортная накладная | Транспортная накладная | /RUSAL/LEPERVLK1.NUMNAKL';
comment on column ods."/rusal/lepervlk1_ral"."weightnet" is 'Вес нетто | Вес нетто | /RUSAL/LEPERVLK1.WEIGHTNET';
comment on column ods."/rusal/lepervlk1_ral"."regdate" is 'Дата регистрации вагона | Дата регистрации вагона | /RUSAL/LEPERVLK1.REGDATE';
comment on column ods."/rusal/lepervlk1_ral"."senddate" is 'Дата отправки вагона | Дата отправки вагона | /RUSAL/LEPERVLK1.SENDDATE';
comment on column ods."/rusal/lepervlk1_ral"."cartare" is 'Тип тары | Тип тары | /RUSAL/LEPERVLK1.CARTARE';
comment on column ods."/rusal/lepervlk1_ral"."type_vagon" is 'Тип ПС | Тип ПС | /RUSAL/LEPERVLK1.TYPE_VAGON';
comment on column ods."/rusal/lepervlk1_ral"."zterminal" is 'Терминал порта - узел | Терминал порта - узел | /RUSAL/LEPERVLK1.ZTERMINAL';
comment on column ods."/rusal/lepervlk1_ral"."genaktdate" is 'Дата генерального акта | Дата генерального акта | /RUSAL/LEPERVLK1.GENAKTDATE';
comment on column ods."/rusal/lepervlk1_ral"."delivery_in" is 'Номер входящей поставки на 1511 | Номер входящей поставки на 1511 | /RUSAL/LEPERVLK1.DELIVERY_IN';
comment on column ods."/rusal/lepervlk1_ral"."knote" is 'Транспортный узел порта | Транспортный узел порта | /RUSAL/LEPERVLK1.KNOTE';
comment on column ods."/rusal/lepervlk1_ral"."knote1" is 'Станция отправления | Станция отправления | /RUSAL/LEPERVLK1.KNOTE1';
comment on column ods."/rusal/lepervlk1_ral"."knote2" is 'Станция назначения | Станция назначения | /RUSAL/LEPERVLK1.KNOTE2';
comment on column ods."/rusal/lepervlk1_ral"."werks_from" is 'Завод-отправитель | Завод-отправитель | /RUSAL/LEPERVLK1.WERKS_FROM';
comment on column ods."/rusal/lepervlk1_ral"."werks_to" is 'Завод-получатель | Завод-получатель | /RUSAL/LEPERVLK1.WERKS_TO';
comment on column ods."/rusal/lepervlk1_ral"."matnr" is 'Номер материала | Номер материала | /RUSAL/LEPERVLK1.MATNR';
comment on column ods."/rusal/lepervlk1_ral"."vehicle" is 'Номер судна | Номер судна | /RUSAL/LEPERVLK1.VEHICLE';
comment on column ods."/rusal/lepervlk1_ral"."conosnum" is 'Номер коносамента | Номер коносамента | /RUSAL/LEPERVLK1.CONOSNUM';
comment on column ods."/rusal/lepervlk1_ral"."dock_knote" is 'Причалы узел | Причалы узел | /RUSAL/LEPERVLK1.DOCK_KNOTE';
comment on column ods."/rusal/lepervlk1_ral"."erdat" is 'Дата создания записи | Дата создания записи | /RUSAL/LEPERVLK1.ERDAT';
comment on column ods."/rusal/lepervlk1_ral"."erzet" is 'Время ввода | Время ввода | /RUSAL/LEPERVLK1.ERZET';
comment on column ods."/rusal/lepervlk1_ral"."ernam" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | /RUSAL/LEPERVLK1.ERNAM';
comment on column ods."/rusal/lepervlk1_ral"."aedat" is 'Дата последнего изменения | Дата последнего изменения | /RUSAL/LEPERVLK1.AEDAT';
comment on column ods."/rusal/lepervlk1_ral"."aezet" is 'Время последнего изменения | Время последнего изменения | /RUSAL/LEPERVLK1.AEZET';
comment on column ods."/rusal/lepervlk1_ral"."aenam" is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | /RUSAL/LEPERVLK1.AENAM';
comment on column ods."/rusal/lepervlk1_ral"."type_prod" is 'Схема реализации | Схема реализации | /RUSAL/LEPERVLK1.TYPE_PROD';
