drop table if exists ods."/rusal/shiptemp_ral";

create table ods."/rusal/shiptemp_ral" (
	"ident" varchar(16) null,
	"vagon" varchar(20) null,
	"nakladn" varchar(35) null,
	"traty" varchar(4) null,
	"dateot" date null,
	"gradecod" varchar(18) null,
	"stationnc" varchar(10) null,
	"stationoc" varchar(10) null,
	"plant" varchar(4) null,	
	"dryweight" numeric(12, 2) null,	
	"proizid" varchar(10) null,	
	"firmaoid" varchar(10) null,
	"cartare" varchar(3) null,
 	"firmap" varchar(120) null,
	"aedat" date null,
	"aezet" time null,
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
distributed by ("vagon", "nakladn");

comment on table ods."/rusal/shiptemp_ral" is 'Данные об отгрузке из файла';
comment on column ods."/rusal/shiptemp_ral"."ident" is 'Идентификатор записи об отгрузке из файла | Идентификатор записи об отгрузке из файла | /RUSAL/SHIPTEMP.IDENT';
comment on column ods."/rusal/shiptemp_ral"."vagon" is 'Номер вагона | Номер вагона | /RUSAL/SHIPTEMP.VAGON';
comment on column ods."/rusal/shiptemp_ral"."nakladn" is 'Номер ж/д накладной | Номер ж/д накладной | /RUSAL/SHIPTEMP.NAKLADN';
comment on column ods."/rusal/shiptemp_ral"."traty" is 'Вид транспортного средства | Вид транспортного средства | /RUSAL/SHIPTEMP.TRATY';
comment on column ods."/rusal/shiptemp_ral"."dateot" is 'Дата отгрузки | Дата отгрузки | /RUSAL/SHIPTEMP.DATEOT';
comment on column ods."/rusal/shiptemp_ral"."gradecod" is 'Код марки металла | Код марки металла | /RUSAL/SHIPTEMP.GRADECOD';
comment on column ods."/rusal/shiptemp_ral"."stationnc" is 'Код станции назначения | Код станции назначения | /RUSAL/SHIPTEMP.STATIONNC';
comment on column ods."/rusal/shiptemp_ral"."stationoc" is 'Код станции отправления | Код станции отправления | /RUSAL/SHIPTEMP.STATIONOC';
comment on column ods."/rusal/shiptemp_ral"."plant" is 'Завод | Завод | /RUSAL/SHIPTEMP.PLANT';
comment on column ods."/rusal/shiptemp_ral"."dryweight" is 'Сухой вес | Сухой вес | /RUSAL/SHIPTEMP.DRYWEIGHT';
comment on column ods."/rusal/shiptemp_ral"."proizid" is 'Код производителя | Код производителя | /RUSAL/SHIPTEMP.PROIZID';
comment on column ods."/rusal/shiptemp_ral"."firmaoid" is 'Код грузоотправителя | Код грузоотправителя | /RUSAL/SHIPTEMP.FIRMAOID';
comment on column ods."/rusal/shiptemp_ral"."cartare" is 'Тип тары | Тип тары | /RUSAL/SHIPTEMP.CARTARE';
comment on column ods."/rusal/shiptemp_ral"."firmap" is 'Грузополучатель | Грузополучатель | /RUSAL/SHIPTEMP.FIRMAP';
comment on column ods."/rusal/shiptemp_ral"."aedat" is 'Дата изменения | Дата изменения | /RUSAL/SHIPTEMP.AEDAT';
comment on column ods."/rusal/shiptemp_ral"."aezet" is 'Время изменения | Время изменения | /RUSAL/SHIPTEMP.AEZET';
