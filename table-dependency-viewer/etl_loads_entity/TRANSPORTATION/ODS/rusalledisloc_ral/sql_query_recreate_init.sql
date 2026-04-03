drop table if exists ods."/rusal/ledisloc_ral";

create table if not exists ods."/rusal/ledisloc_ral" (
	"id" varchar(10) null,
	"pos" varchar(6) null,
	"type_load" varchar(2) null,
	"numvag" varchar(20) null,
	"numnakl" varchar(35) null,
	"traty" varchar(4) null,
	"daten" date null,
	"knote_naz" varchar(10) null,
	"et_tarif" varchar(6) null,
	"knote1" varchar(10) null,
	"opcode" varchar(2) null,
	"datd" date null,
	"uzeit" time null,
	"knote2" varchar(10) null,
	"strekl2" varchar(7) null,
	"trno" varchar(6) null,
	"deliv_date" date null,
	"distance_left" int8 null,
	"erdat" date null,
	"erzet" time null,
	"ernam" varchar(12) null,
	"aedat" date null,
	"aezet" time null,
	"aenam" varchar(12) null,
	"date_sh" date null,
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

comment on table ods."/rusal/ledisloc_ral" is 'LE1158M: Дислокация вагонов';
comment on column ods."/rusal/ledisloc_ral"."id" is 'ID загрузки | ID загрузки | stg."/RUSAL/LEDISLOC"."ID"';
comment on column ods."/rusal/ledisloc_ral"."pos" is 'Позиция загрузки | Позиция загрузки | stg."/RUSAL/LEDISLOC"."POS"';
comment on column ods."/rusal/ledisloc_ral"."type_load" is 'Тип загрузки | Тип загрузки | stg."/RUSAL/LEDISLOC"."TYPE_LOAD"';
comment on column ods."/rusal/ledisloc_ral"."numvag" is 'Ид. транспортировки | Ид. транспортировки | stg."/RUSAL/LEDISLOC"."NUMVAG"';
comment on column ods."/rusal/ledisloc_ral"."numnakl" is 'Транспортная накладная | Транспортная накладная | stg."/RUSAL/LEDISLOC"."NUMNAKL"';
comment on column ods."/rusal/ledisloc_ral"."traty" is 'Вид транспортного средства | Вид транспортного средства | stg."/RUSAL/LEDISLOC"."TRATY"';
comment on column ods."/rusal/ledisloc_ral"."daten" is 'Дата начала рейса | Дата начала рейса | stg."/RUSAL/LEDISLOC"."DATEN"';
comment on column ods."/rusal/ledisloc_ral"."knote_naz" is 'Станция назначения вагона | Станция назначения вагона | stg."/RUSAL/LEDISLOC"."KNOTE_NAZ"';
comment on column ods."/rusal/ledisloc_ral"."et_tarif" is 'Код груза по тарифной номенклатуре | Код груза по тарифной номенклатуре | stg."/RUSAL/LEDISLOC"."ET_TARIF"';
comment on column ods."/rusal/ledisloc_ral"."knote1" is 'Станция начала рейса | Станция начала рейса | stg."/RUSAL/LEDISLOC"."KNOTE1"';
comment on column ods."/rusal/ledisloc_ral"."opcode" is 'Код операции | Код операции | stg."/RUSAL/LEDISLOC"."OPCODE"';
comment on column ods."/rusal/ledisloc_ral"."datd" is 'Дата операции | Дата операции | stg."/RUSAL/LEDISLOC"."DATD"';
comment on column ods."/rusal/ledisloc_ral"."uzeit" is 'Время операции | Время операции | stg."/RUSAL/LEDISLOC"."UZEIT"';
comment on column ods."/rusal/ledisloc_ral"."knote2" is 'Станция совершения операции | Станция совершения операции | stg."/RUSAL/LEDISLOC"."KNOTE2"';
comment on column ods."/rusal/ledisloc_ral"."strekl2" is 'Дорога сдачи | Дорога сдачи | stg."/RUSAL/LEDISLOC"."STRELK2"';
comment on column ods."/rusal/ledisloc_ral"."trno" is 'Номер поезда | Номер поезда | stg."/RUSAL/LEDISLOC"."TRNO"';
comment on column ods."/rusal/ledisloc_ral"."deliv_date" is 'Прогнозная дата прибытия | Прогнозная дата прибытия | stg."/RUSAL/LEDISLOC"."DELIV_DATE"';
comment on column ods."/rusal/ledisloc_ral"."distance_left" is 'Расстояние до цели от текущей станции дислокации, Км | Расстояние до цели от текущей станции дислокации, Км | stg."/RUSAL/LEDISLOC"."DISTANCE_LEFT"';
comment on column ods."/rusal/ledisloc_ral"."erdat" is 'Дата создания записи | Дата создания записи | stg."/RUSAL/LEDISLOC"."ERDAT"';
comment on column ods."/rusal/ledisloc_ral"."erzet" is 'Время ввода | Время ввода | stg."/RUSAL/LEDISLOC"."ERZET"';
comment on column ods."/rusal/ledisloc_ral"."ernam" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | stg."/RUSAL/LEDISLOC"."ERNAM"';
comment on column ods."/rusal/ledisloc_ral"."aedat" is 'Дата последнего изменения | Дата последнего изменения | stg."/RUSAL/LEDISLOC"."AEDAT"';
comment on column ods."/rusal/ledisloc_ral"."aezet" is 'Время последнего изменения | Время последнего изменения | stg."/RUSAL/LEDISLOC"."AEZET"';
comment on column ods."/rusal/ledisloc_ral"."aenam" is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | stg."/RUSAL/LEDISLOC"."AENAM"';
comment on column ods."/rusal/ledisloc_ral"."date_sh" is 'Дата отгрузки с завода | Дата отгрузки с завода | stg."/RUSAL/LEDISLOC"."DATE_SH"';