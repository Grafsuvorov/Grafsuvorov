drop table if exists dds.bank_statement_documents

create table dds.bank_statement_documents (
	statement_type_code varchar(4),
	bic_code varchar(9),
	company_account_code varchar(20),
	statement_currency_code varchar(5),
	statement_fiscal_year numeric(4,0),
	statement_number varchar(5),
	statement_code varchar(8),
	statement_position_line_item_code varchar(5),
	accounting_document_code varchar(10),
	support_accounting_document_code varchar(10),
	payee_code varchar(20),
	dttm_inserted 	timestamp not null default now(),
	dttm_updated  	timestamp not null default now(),
	job_name 		varchar(60) not null default 'airflow'::character varying,
	deleted_flag	bool not null default false
)
with (
	appendonly=true,
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
distributed by ( statement_code, statement_position_line_item_code);



comment on table dds.bank_statement_documents is 'Документы электронной выписки';
comment on column dds.bank_statement_documents.statement_type_code is 'Приложение, использующее память данных банка | Приложение, использующее память данных банка | ods.bank_statement_header.statement_type_code';
comment on column dds.bank_statement_documents.bic_code is 'Бик банка | Бик банка | ods.bank_statement_header.bic_code';
comment on column dds.bank_statement_documents.company_account_code is 'Номер счета  | Номер счета  | ods.bank_statement_header.company_account_code';
comment on column dds.bank_statement_documents.statement_currency_code is 'Валюта выписки | Валюта выписки | ods.bank_statement_header.statement_currency_code';
comment on column dds.bank_statement_documents.statement_fiscal_year is 'Год выписки | Год выписки | ods.bank_statement_header.statement_fiscal_year';
comment on column dds.bank_statement_documents.statement_number is 'Номер выписки | Номер выписки | ods.bank_statement_header.statement_number';
comment on column dds.bank_statement_documents.statement_code is 'Краткий ключ (замещение) | Краткий ключ (замещение) | ods.bank_statement_header.statement_code';
comment on column dds.bank_statement_documents.statement_position_line_item_code is 'Номер отдельной записи (№ записи в выписке из счета) | Номер отдельной записи (№ записи в выписке из счета) | ods.bank_statement_position.statement_position_line_item_code';
comment on column dds.bank_statement_documents.accounting_document_code is 'Номер документа  | Номер документа  | ods.bank_statement_position.accounting_document_code';
comment on column dds.bank_statement_documents.support_accounting_document_code is 'Номер документа вспомогательной бухгалтерии | Номер документа вспомогательной бухгалтерии | ods.bank_statement_position.support_accounting_document_code';
comment on column dds.bank_statement_documents.payee_code is 'Ключ получателя | Ключ получателя | ods.bank_statement_header.payee_code';