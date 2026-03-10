drop table if exists ods.vbup_ral;

create table ods.vbup_ral (
	vbeln varchar(30) not null,
	posnr varchar(18) null,
	kosta varchar(5) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by (vbeln);

comment on table ods.vbup_ral is 'Статус документов сбыта';
comment on column ods.vbup_ral.vbeln is 'Номер документа сбыта | Номер документа сбыта | VBUK.VBELN';
comment on column ods.vbup_ral.posnr is 'Номер позиции | Номер позиции | VBUK.POSNR';
comment on column ods.vbup_ral.kosta is 'Статус калькуляции на уровне позиции | Статус калькуляции на уровне позиции | VBUK.KOSTA';
