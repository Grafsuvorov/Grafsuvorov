drop table if exists ods.earmarked_funds_document_header;

create table ods.earmarked_funds_document_header (
	earmarked_document_code	varchar(10),
	reference_document_code	varchar(16),
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (earmarked_document_code);

comment on table  ods.earmarked_funds_document_header is 'Заголовок документа для выделения финансовых средств';
comment on column ods.earmarked_funds_document_header.earmarked_document_code is 'Номер документа для выделения финансовых средств | Номер документа для выделения финансовых средств | KBLK.BELNR';
comment on column ods.earmarked_funds_document_header.reference_document_code is 'Ссылочный номер документа | Ссылочный номер документа | KBLK.XBLNR';