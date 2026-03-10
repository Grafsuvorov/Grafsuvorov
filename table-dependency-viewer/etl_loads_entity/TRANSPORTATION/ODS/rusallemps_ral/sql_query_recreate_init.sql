drop table if exists ods."/rusal/lemps_ral";

create table ods."/rusal/lemps_ral" (
	"id" varchar(10) null,
	"pos" varchar(6) null,
	"type_load" varchar(2) null,
	"numvag" varchar(20) null,
	"numnakl" varchar(35) null,
	"weight" numeric(13, 3) null,
	"sto" varchar(50) null,
	"stn" varchar(50) null,
	"dateot" date null,
	"dtl_vbeln" varchar(10) null,
	"type_vagon" varchar(4) null,	
	"lifnr" varchar(10) null,
	"lifnr_pr" varchar(10) null,
	"matnr" varchar(18) null,
	"cartare_pr" varchar(3) null,
	"erdat" date null,
	"erzet" time null,
	"ernam" varchar(12) null,
	"aedat" date null,
	"aezet" time null,
	"aenam" varchar(12) null,
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

comment on table ods."/rusal/lemps_ral" is 'LE1158M: Данные МПС';
comment on column ods."/rusal/lemps_ral"."id" is 'ID загрузки | ID загрузки | /RUSAL/LEMPS.ID';
comment on column ods."/rusal/lemps_ral"."pos" is 'Позиция загрузки | Позиция загрузки | /RUSAL/LEMPS.POS';
comment on column ods."/rusal/lemps_ral"."type_load" is 'Тип загрузки | Тип загрузки | /RUSAL/LEMPS.TYPE_LOAD';
comment on column ods."/rusal/lemps_ral"."numvag" is 'Ид. транспортировки | Ид. транспортировки | /RUSAL/LEMPS.NUMVAG';
comment on column ods."/rusal/lemps_ral"."numnakl" is 'Транспортная накладная | Транспортная накладная | /RUSAL/LEMPS.NUMNAKL';
comment on column ods."/rusal/lemps_ral"."weight" is 'Вес | Вес | /RUSAL/LEMPS.WEIGHT';
comment on column ods."/rusal/lemps_ral"."sto" is 'Станция отправления | Станция отправления | /RUSAL/LEMPS.STO';
comment on column ods."/rusal/lemps_ral"."stn" is 'Станция назначения | Станция назначения | /RUSAL/LEMPS.STN';
comment on column ods."/rusal/lemps_ral"."dateot" is 'Дата отгрузки по ж/д накладной | Дата отгрузки по ж/д накладной | /RUSAL/LEMPS.DATEOT';
comment on column ods."/rusal/lemps_ral"."dtl_vbeln" is 'Номер поставки ДТиЛ | Номер поставки ДТиЛ | /RUSAL/LEMPS.DTL_VBELN';
comment on column ods."/rusal/lemps_ral"."type_vagon" is 'Тип ПС | Тип ПС | /RUSAL/LEMPS.TYPE_VAGON';
comment on column ods."/rusal/lemps_ral"."lifnr" is 'Поставщик | Поставщик | /RUSAL/LEMPS.LIFNR';
comment on column ods."/rusal/lemps_ral"."lifnr_pr" is 'Производитель | Производитель | /RUSAL/LEMPS.LIFNR_PR';
comment on column ods."/rusal/lemps_ral"."matnr" is 'Номер материала | Номер материала | /RUSAL/LEMPS.MATNR';
comment on column ods."/rusal/lemps_ral"."cartare_pr" is 'Расчетный тип тары | Расчетный тип тары | /RUSAL/LEMPS.CARTARE_PR';
comment on column ods."/rusal/lemps_ral"."erdat" is 'Дата создания записи | Дата создания записи | /RUSAL/LEMPS.ERDAT';
comment on column ods."/rusal/lemps_ral"."erzet" is 'Время ввода | Время ввода | /RUSAL/LEMPS.ERZET';
comment on column ods."/rusal/lemps_ral"."ernam" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | /RUSAL/LEMPS.ERNAM';
comment on column ods."/rusal/lemps_ral"."aedat" is 'Дата последнего изменения | Дата последнего изменения | /RUSAL/LEMPS.AEDAT';
comment on column ods."/rusal/lemps_ral"."aezet" is 'Время последнего изменения | Время последнего изменения | /RUSAL/LEMPS.AEZET';
comment on column ods."/rusal/lemps_ral"."aenam" is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | /RUSAL/LEMPS.AENAM';
