drop table if exists dds.bank_statement_position_clearing_record;

CREATE TABLE dds.bank_statement_position_clearing_record (
	statement_code varchar(8) not NULL,
	statement_position_line_item_code varchar(5) not NULL,
	clearing_position_code varchar(3) NULL,
	counterparty_code varchar(10) NULL,
	accounting_document_code varchar(10),	   
	accounting_document_fiscal_year varchar(4),	
	payment_order_code  varchar(10) null,   
	contract_number  varchar(20) null,
	document_currency_amount numeric(17,2),
	reference_document_code varchar(16) null,
  	assignment_number varchar(18) null,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (statement_code, statement_position_line_item_code);

comment on table  dds.bank_statement_position_clearing_record is 'Клиринговые данные позиции электронной выписки';
comment on column dds.bank_statement_position_clearing_record.statement_code is 'Краткий ключ (замещение) | Краткий ключ (замещение) | FEBCL.KUKEY';
comment on column dds.bank_statement_position_clearing_record.statement_position_line_item_code is 'Номер отдельной записи (№ записи в выписке из счета) | Номер отдельной записи (№ записи в выписке из счета) | FEBCL.ESNUM';
comment on column dds.bank_statement_position_clearing_record.clearing_position_code is '№ Клиринговой записи | Приложение, использующее память данных банка | FEBCL.CSNUM';
comment on column dds.bank_statement_position_clearing_record.counterparty_code is 'Код контрагента | Код контрагента | FEBCL.AGKON';
comment on column dds.bank_statement_position_clearing_record.accounting_document_code is 'Номер бухгалерского документа  | Номер бухгалерского документа  | FEBCL.SELVON';
comment on column dds.bank_statement_position_clearing_record.accounting_document_fiscal_year is 'Год бухгалерского документа | Год бухгалерского документа | FEBCL.SELVON';
comment on column dds.bank_statement_position_clearing_record.payment_order_code is 'Платежное поручение  | Платежное поручение | FEBCL.SELVON';
comment on column dds.bank_statement_position_clearing_record.contract_number is 'Номер контракта | Номер контракта | FEBCL.SELVON';
comment on column dds.bank_statement_position_clearing_record.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | FEBCL.SELVON';
comment on column dds.bank_statement_position_clearing_record.reference_document_code is 'Номер ссылочного документа | Номер ссылочного документа | FEBCL.SELVON';
comment on column dds.bank_statement_position_clearing_record.assignment_number is 'Номер присвоения | Номер присвоения | FEBCL.SELVON';