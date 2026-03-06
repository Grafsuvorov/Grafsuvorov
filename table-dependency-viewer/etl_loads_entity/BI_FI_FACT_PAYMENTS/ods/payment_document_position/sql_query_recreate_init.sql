drop table if exists ods.payment_document_position;

create table ods.payment_document_position (
	dt_program_execution date,
	additional_identifier_code varchar(6),
	is_trial_execution bpchar(1),
	payer_unit_balance_code varchar(4),
	supplier_code varchar(10),
	customer_code varchar(10),
	payee_code varchar(16),
	payment_document_code varchar(10),
	unit_balance_code varchar(4),
	accounting_document_code varchar(10),
	accounting_document_fiscal_year varchar(4),
	accounting_document_position_line_item_code varchar(3),
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
distributed randomly
;

comment on table  ods.payment_document_position is 'Позиция документа платежей';
comment on column ods.payment_document_position.dt_program_execution is 'Дата выполнения программы | Дата выполнения программы | REGUP.LAUFD';
comment on column ods.payment_document_position.additional_identifier_code is 'Дополнительный признак идентификации | Дополнительный признак идентификации | REGUP.LAUFI';
comment on column ods.payment_document_position.is_trial_execution is 'Индикатор: тлк. пробный прогон? | Индикатор: тлк. пробный прогон? | REGUP.XVORL';
comment on column ods.payment_document_position.payer_unit_balance_code is 'БЕ-плательщик | БЕ-плательщик | REGUP.ZBUKR';
comment on column ods.payment_document_position.supplier_code is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | REGUP.LIFNR';
comment on column ods.payment_document_position.customer_code is 'Номер дебитора | Номер дебитора | REGUP.KUNNR';
comment on column ods.payment_document_position.payee_code is 'Код получателя платежа | Код получателя платежа | REGUP.EMPFG';
comment on column ods.payment_document_position.payment_document_code is 'Номер платежного документа | Номер платежного документа | REGUP.VBLNR';
comment on column ods.payment_document_position.unit_balance_code is 'Балансовая единица | Балансовая единица | REGUP.BUKRS';
comment on column ods.payment_document_position.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | REGUP.BELNR';
comment on column ods.payment_document_position.accounting_document_fiscal_year is 'Финансовый год | Финансовый год | REGUP.GJAHR';
comment on column ods.payment_document_position.accounting_document_position_line_item_code is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | REGUP.BUZEI';