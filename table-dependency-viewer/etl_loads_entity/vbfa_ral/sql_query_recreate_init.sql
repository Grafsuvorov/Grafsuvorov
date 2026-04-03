drop table if exists ods.vbfa_ral cascade;

create table ods.vbfa_ral ( -- ключ vbelv, posnv, vbeln, posnn, vbtyp_n
	vbelv 				varchar(10) not null,
	posnv 				varchar(6) not null,
	vbeln 				varchar(10) not null,
	posnn 				varchar(6) not null,
	vbtyp_n 			varchar(1) not null,
	vbtyp_v 			varchar(1) null,
	dttm_inserted 		timestamp not null default now(),
	dttm_updated 		timestamp not null default now(),
	job_name 			varchar(60) not null default 'airflow'::character varying,
	deleted_flag 		bool not null default false 
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by (vbelv, posnv, vbeln, posnn, vbtyp_n);

comment on table ods.vbfa_ral is 'Поток документов сбыта';
comment on column ods.vbfa_ral.vbelv is 'Предыдущий документ сбыта | Предыдущий документ сбыта | VBFA.VBELV';
comment on column ods.vbfa_ral.posnv is 'Предыдущая позиция документа сбыта | Предыдущая позиция документа сбыта | VBFA.POSNV';
comment on column ods.vbfa_ral.vbeln is 'Следующий документ сбыта | Следующий документ сбыта | VBFA.VBELN';
comment on column ods.vbfa_ral.posnn is 'Следующая позиция документа сбыта | Следующая позиция документа сбыта | VBFA.POSNN';
comment on column ods.vbfa_ral.vbtyp_n is 'Следующий тип документа сбыта | Следующий тип документа сбыта | VBFA.VBTYP_N';
comment on column ods.vbfa_ral.vbtyp_v is 'Тип предшествующего документа сбыта | Тип предшествующего документа сбыта | VBFA.VBTYP_V';