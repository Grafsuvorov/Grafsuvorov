drop table if exists dds.accounting_document_clearing_relations;
CREATE TABLE dds.accounting_document_clearing_relations (
	clearing_document_unit_balance_code varchar(4) NOT NULL,
	clearing_document_code varchar(10) NOT NULL,
	clearing_document_fiscal_year numeric(4) NOT NULL,
	clearing_subsequent_number numeric(6) NOT NULL,
	clearing_document_line_item_code numeric(3) NOT NULL,
	document_currency_code varchar(5) NULL,
	clearing_type_code varchar(1) NULL,
	unit_balance_code varchar(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	position_line_item numeric(3) NOT NULL,
	debit_or_credit_code varchar(1) NOT NULL,
	local_currency_amount numeric(13, 2) NOT NULL,
	second_local_currency_amount numeric(13, 2) NOT NULL,
	document_currency_amount numeric(13, 2) NOT NULL,
	valuation_difference_document_currency_amount numeric(13, 2) NOT NULL,
	valuation_difference_second_local_currency_amount numeric(13, 2) NOT NULL,
	account_type_code varchar(1)  NULL,
	special_general_ledger_indicator varchar(1) NULL,
	last_status int4 NULL,
	dttm_inserted timestamp DEFAULT now() NOT NULL,
	dttm_updated timestamp DEFAULT now() NOT NULL,
	job_name varchar(60) DEFAULT 'airflow'::character varying NOT NULL,
	deleted_flag bool DEFAULT false NOT NULL
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (clearing_document_unit_balance_code, clearing_document_fiscal_year, clearing_document_code, clearing_subsequent_number);

comment on table 	dds.accounting_document_clearing_relations is 'Бухгалтерские документы: информация о выравнивании';
comment on column dds.accounting_document_clearing_relations.clearing_document_unit_balance_code is 'Балансовая единица | Балансовая единица | BSE_CLR.BUKRS_CLR';
comment on column dds.accounting_document_clearing_relations.clearing_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | BSE_CLR.BELNR_CLR';
comment on column dds.accounting_document_clearing_relations.clearing_document_fiscal_year is 'Финансовый год | Финансовый год | BSE_CLR.GJAHR_CLR';
comment on column dds.accounting_document_clearing_relations.clearing_subsequent_number is 'Текущий номер информации о выравнивании | Текущий номер информации о выравнивании | BSE_CLR.INDEX_CLR';
comment on column dds.accounting_document_clearing_relations.clearing_document_line_item_code is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | BSE_CLR.AGBUZ';
comment on column dds.accounting_document_clearing_relations.document_currency_code is 'Код валюты | Код валюты | BSE_CLR.WAERS';
comment on column dds.accounting_document_clearing_relations.clearing_type_code is 'Тип выравнивания в таблице AUSZ_CLR | Тип выравнивания в таблице AUSZ_CLR | BSE_CLR.CLRIN';
comment on column dds.accounting_document_clearing_relations.unit_balance_code is 'Балансовая единица | Балансовая единица | BSE_CLR.BUKRS';
comment on column dds.accounting_document_clearing_relations.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | BSE_CLR.BELNR';
comment on column dds.accounting_document_clearing_relations.fiscal_year is 'Финансовый год | Финансовый год | BSE_CLR.GJAHR';
comment on column dds.accounting_document_clearing_relations.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | BSE_CLR.BUZEI';
comment on column dds.accounting_document_clearing_relations.debit_or_credit_code is 'Индикатор дебета/кредита | Индикатор дебета/кредита | BSE_CLR.SHKZG';
comment on column dds.accounting_document_clearing_relations.local_currency_amount is 'Сумма во внутренней валюте | Сумма во внутренней валюте | BSE_CLR.DMBTR';
comment on column dds.accounting_document_clearing_relations.second_local_currency_amount is 'Сумма во второй ВнутрВалюте | Сумма во второй ВнутрВалюте | BSE_CLR.DMBE2';
comment on column dds.accounting_document_clearing_relations.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | BSE_CLR.WRBTR';
comment on column dds.accounting_document_clearing_relations.valuation_difference_document_currency_amount is 'Оценочная разница | Оценочная разница | BSE_CLR.BDIFF';
comment on column dds.accounting_document_clearing_relations.valuation_difference_second_local_currency_amount is 'Оценочная разница для второй внутренней валюты | Оценочная разница для второй внутренней валюты | BSE_CLR.BDIF2';
comment on column dds.accounting_document_clearing_relations.account_type_code is 'Вид счета | Вид счета | BSE_CLR.KOART';
comment on column dds.accounting_document_clearing_relations.special_general_ledger_indicator is 'Код Особой главной книги | Код Особой главной книги | BSE_CLR.UMSKZ';
