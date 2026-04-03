drop table if exists ods.vbuk_ral;

create table ods.vbuk_ral (
	vbeln varchar(30) not null,
	kostk varchar(5) null,
	saprl varchar(5) null,
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

comment on table ods.vbuk_ral is 'Статус документов сбыта';
comment on column ods.vbuk_ral.vbeln is 'Номер документа сбыта | Номер документа сбыта | VBUK.VBELN';
comment on column ods.vbuk_ral.kostk is 'Статус калькуляции стоимости | Статус калькуляции стоимости | VBUK.KOSTK';
comment on column ods.vbuk_ral.saprl is 'Статус проверки кредитного лимита | Статус проверки кредитного лимита | VBUK.SAPRL';