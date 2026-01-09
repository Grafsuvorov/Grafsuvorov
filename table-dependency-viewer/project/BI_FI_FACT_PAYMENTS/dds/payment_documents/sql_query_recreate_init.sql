drop table if exists dds.payment_documents;

create table dds.payment_documents (
	dt_program_execution date,
	additional_identifier_code varchar(6),
	is_trial_execution bpchar(1),
	payer_unit_balance_code varchar(4),
	supplier_code varchar(10),
	customer_code varchar(10),
	payee_code varchar(10),
	payment_document_code varchar(10),
	unit_balance_code varchar(4),
	accounting_document_code varchar(10),
	accounting_document_fiscal_year varchar(4),
	accounting_document_position_line_item_code varchar(3),
	payment_order_code varchar(10),
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
distributed randomly;

comment on table dds.payment_documents is 'Документы платежей';
comment on column dds.payment_documents.dt_program_execution is 'Дата выполнения программы | Дата выполнения программы | ods.payment_document_header.dt_program_execution';
comment on column dds.payment_documents.additional_identifier_code is 'Дополнительный признак идентификации | Дополнительный признак идентификации | ods.payment_document_header.additional_identifier_code';
comment on column dds.payment_documents.is_trial_execution is 'Индикатор: тлк. пробный прогон? | Индикатор: тлк. пробный прогон? | ods.payment_document_header.is_trial_execution';
comment on column dds.payment_documents.payer_unit_balance_code is 'БЕ-плательщик | БЕ-плательщик | ods.payment_document_header.payer_unit_balance_code';
comment on column dds.payment_documents.supplier_code is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | ods.payment_document_header.supplier_code';
comment on column dds.payment_documents.customer_code is 'Номер дебитора | Номер дебитора | ods.payment_document_header.customer_code';
comment on column dds.payment_documents.payee_code is 'Код получателя платежа | Код получателя платежа | ods.payment_document_header.payee_code';
comment on column dds.payment_documents.payment_document_code is 'Номер платежного документа | Номер платежного документа | ods.payment_document_header.payment_document_code';
comment on column dds.payment_documents.unit_balance_code is 'Балансовая единица | Балансовая единица | ods.payment_document_position.unit_balance_code';
comment on column dds.payment_documents.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | ods.payment_document_position.accounting_document_code';
comment on column dds.payment_documents.accounting_document_fiscal_year is 'Финансовый год | Финансовый год | ods.payment_document_position.accounting_document_fiscal_year';
comment on column dds.payment_documents.accounting_document_position_line_item_code is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | ods.payment_document_position.accounting_document_position_line_item_code';
comment on column dds.payment_documents.payment_order_code is 'Платежное поручение | Платежное поручение | ods.payment_document_header.payment_order_code';