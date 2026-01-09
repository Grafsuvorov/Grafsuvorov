drop table if exists ods.mch1_ral;

create table ods.mch1_ral
(
	"matnr" varchar(18) not null,	
	"charg" varchar(10) not null,
	"cuobj_bm" varchar(18) null,
	"fvdt3" date null,
	"fvdt6" date null,
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by ("matnr", "charg");

comment on table ods.mch1_ral is 'Партии (при межзаводском управлении партиями)';
comment on column ods.mch1_ral."matnr" is 'Номер материала | Номер материала | MCH1.MATNR';
comment on column ods.mch1_ral."charg" is 'Номер партии | Номер партии | MCH1.CHARG';
comment on column ods.mch1_ral."cuobj_bm" is 'Внутренний номер объекта: классификация партий | Внутренний номер объекта: классификация партий | MCH1.CUOBJ_BM';
comment on column ods.mch1_ral."fvdt3" is 'Дата доставки | Дата доставки | MCH1.FVDT3';
comment on column ods.mch1_ral."fvdt6" is 'Дата разгрузки | Дата разгрузки | MCH1.FVDT6';
