drop table if exists ods.payment_document_header;

create table ods.payment_document_header (
	dt_program_execution date,
	additional_identifier_code varchar(6),
	is_trial_execution bpchar(1),
	payer_unit_balance_code varchar(4),
	supplier_code varchar(10),
	customer_code varchar(10),
	payee_code varchar(10),
	payment_document_code varchar(10),
	payment_order_code varchar(10),
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
distributed randomly;

comment on table  ods.payment_document_header is 'Заголовок документа платежей';
comment on column ods.payment_document_header.dt_program_execution is 'Дата выполнения программы | Дата выполнения программы | REGUH.LAUFD';
comment on column ods.payment_document_header.additional_identifier_code is 'Дополнительный признак идентификации | Дополнительный признак идентификации | REGUH.LAUFI';
comment on column ods.payment_document_header.is_trial_execution is 'Индикатор: тлк. пробный прогон? | Индикатор: тлк. пробный прогон? | REGUH.XVORL';
comment on column ods.payment_document_header.payer_unit_balance_code is 'БЕ-плательщик | БЕ-плательщик | REGUH.ZBUKR';
comment on column ods.payment_document_header.supplier_code is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | REGUH.LIFNR';
comment on column ods.payment_document_header.customer_code is 'Номер дебитора | Номер дебитора | REGUH.KUNNR';
comment on column ods.payment_document_header.payee_code is 'Код получателя платежа | Код получателя платежа | REGUH.EMPFG';
comment on column ods.payment_document_header.payment_document_code is 'Номер платежного документа | Номер платежного документа | REGUH.VBLNR';
comment on column ods.payment_document_header.payment_order_code is 'Платежное поручение | Платежное поручение | REGUH.PYORD';