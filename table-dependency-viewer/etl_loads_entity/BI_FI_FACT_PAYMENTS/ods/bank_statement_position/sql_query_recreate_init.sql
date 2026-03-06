drop table if exists ods.bank_statement_position;

create table ods.bank_statement_position (
	statement_code varchar(8),
	statement_position_line_item_code varchar(5),
	accounting_document_code varchar(10),
	support_accounting_document_code varchar(10),
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
distributed by (statement_code, statement_position_line_item_code);

comment on table  ods.bank_statement_position is 'Позиция электронной выписки';
comment on column ods.bank_statement_position.statement_code is 'Уникальный ключ выписки в системе | Уникальный ключ выписки в системе | FEBEP.KUKEY';
comment on column ods.bank_statement_position.statement_position_line_item_code is 'Номер отдельной записи (№ записи в выписке из счета) | Номер отдельной записи (№ записи в выписке из счета) | FEBEP.ESNUM';
comment on column ods.bank_statement_position.accounting_document_code is 'Номер документа  | Номер документа | FEBEP.BELNR';
comment on column ods.bank_statement_position.support_accounting_document_code is 'Номер документа вспомогательной бухгалтерии | Номер документа вспомогательной бухгалтерии | FEBEP.NBBLN';