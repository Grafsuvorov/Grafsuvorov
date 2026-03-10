drop table if exists ods."/rusal/ekkont_ral";

create table ods."/rusal/ekkont_ral" (
	ebeln varchar(10) null,
	lifnr varchar(10) null,
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
distributed by (ebeln);

comment on table ods."/rusal/ekkont_ral" is 'Документы закупки: связь с контрактами ЦК';
comment on column ods."/rusal/ekkont_ral".ebeln is 'Номер документа закупки | Номер документа закупки | /RUSAL/EKKONT.EBELN';
comment on column ods."/rusal/ekkont_ral".lifnr is 'Номер счета поставщика | Номер счета поставщика | /RUSAL/EKKONT.LIFNR';
