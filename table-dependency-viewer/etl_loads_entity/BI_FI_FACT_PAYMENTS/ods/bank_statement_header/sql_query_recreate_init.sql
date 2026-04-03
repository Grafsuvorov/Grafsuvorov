drop table if exists ods.bank_statement_header;

create table ods.bank_statement_header (
	statement_type_code varchar(4),
	bic_code varchar(9),
	company_account_code varchar(20),
	statement_currency_code varchar(5),
	statement_fiscal_year numeric(4,0),
	statement_number varchar(5),
	payee_code varchar(20),
	statement_code varchar(8),
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
distributed by (statement_code);

comment on table  ods.bank_statement_header is 'Заголовок электронной выписки';
comment on column ods.bank_statement_header.statement_type_code is 'Приложение, использующее память данных банка | Приложение, использующее память данных банка | FEBKO.ANWND';
comment on column ods.bank_statement_header.bic_code is 'Бик банка | Бик банка | FEBKO.ABSND';
comment on column ods.bank_statement_header.company_account_code is 'Номер счета  | Номер счета  | FEBKO.ABSND';
comment on column ods.bank_statement_header.statement_currency_code is 'Валюта выписки | Валюта выписки | FEBKO.ABSND';
comment on column ods.bank_statement_header.statement_fiscal_year is 'Год выписки | Год выписки | FEBKO.AZIDT';
comment on column ods.bank_statement_header.statement_number is 'Номер выписки | Номер выписки | FEBKO.AZIDT';
comment on column ods.bank_statement_header.payee_code is 'Ключ получателя | Ключ получателя | FEBKO.EMKEY';
comment on column ods.bank_statement_header.statement_code is 'Краткий ключ (замещение) | Краткий ключ (замещение) | FEBKO.KUKEY';