drop table if exists dm_calc.accounting_exchange_rate_revaluation;

--CREATE TABLE userdata.accounting_exchange_rate_revaluation (
CREATE TABLE if not exists dm_calc.accounting_exchange_rate_revaluation (
	unit_balance_code	varchar(4) NOT NULL,
	fiscal_year	NUMERIC(4,0) NOT NULL,
	account_type	varchar(1) NULL,
	accounting_document_code	varchar(10) NOT NULL,
	position_line_item	NUMERIC(3,0) NOT NULL,
	position_line_item_text	varchar(50) NULL,
	accounting_document_type	varchar(2) NULL,
	dt_posting	date NOT NULL,
	dt_accounting_document	date NOT NULL,
	debit_or_credit	varchar(1) NULL,
	general_ledger_account_code	varchar(10) NULL,
	special_general_ledger_indicator	varchar(1) NULL,
	document_currency_code	varchar(5) NULL,
	local_currency_code	varchar(5) NULL,
	second_local_currency_code	varchar(5) NULL,
	document_currency_amount	NUMERIC(15,2) NULL,
	local_currency_amount	NUMERIC(15,2) NULL,
	second_local_currency_amount	NUMERIC(15,2) NULL,
	is_red_reverse_posting bpchar(1)	NULL,
	reference_document_code	varchar(10) NULL,
	reference_document_fiscal_year	NUMERIC(4,0) NULL,
	reference_document_position_line_item	NUMERIC(3,0) NULL,
	reverse_document_code varchar(10) NULL,
	reverse_document_fiscal_year numeric(4) NULL,	
	is_reversed_document varchar(1) NULL,
	deleted_flag bool	NOT NULL DEFAULT FALSE,
	dttm_inserted	timestamp NOT NULL DEFAULT now(),
	dttm_updated	timestamp NOT NULL DEFAULT now(),
	job_name	varchar(60) NOT NULL DEFAULT 'airflow'::CHARACTER VARYING
)
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
distributed BY (unit_balance_code, fiscal_year, accounting_document_code);



comment on table dm_calc.accounting_exchange_rate_revaluation is 'Курсовые разницы';
comment on column dm_calc.accounting_exchange_rate_revaluation.unit_balance_code is 'Балансовая единица | Балансовая единица | dds.accounting_documents.unit_balance_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | dds.accounting_documents.accounting_document_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.account_type is 'Вид счета | Вид счета | dds.accounting_documents.account_type';
comment on column dm_calc.accounting_exchange_rate_revaluation.fiscal_year is 'Финансовый год | Финансовый год | dds.accounting_documents.fiscal_year';
comment on column dm_calc.accounting_exchange_rate_revaluation.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | dds.accounting_documents.position_line_item';
comment on column dm_calc.accounting_exchange_rate_revaluation.position_line_item_text is 'Текст к позиции | Текст к позиции | dds.accounting_documents.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation.accounting_document_type is 'Вид документа | Вид документа | dds.accounting_documents.accounting_document_type';
comment on column dm_calc.accounting_exchange_rate_revaluation.dt_posting is 'Дата проводки | Дата проводки | dds.accounting_documents.dt_posting';
comment on column dm_calc.accounting_exchange_rate_revaluation.dt_accounting_document is 'Дата документа | Дата документа | dds.accounting_documents.dt_accounting_document';
comment on column dm_calc.accounting_exchange_rate_revaluation.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | dds.accounting_documents.debit_or_credit';
comment on column dm_calc.accounting_exchange_rate_revaluation.general_ledger_account_code is 'Основной счет главной книги | Основной счет главной книги | dds.accounting_documents.general_ledger_account_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.special_general_ledger_indicator is 'Код Особой главной книги | Код Особой главной книги | dds.accounting_documents.special_general_ledger_indicator';
comment on column dm_calc.accounting_exchange_rate_revaluation.document_currency_code is 'Код валюты документа | Код валюты документа | dds.accounting_documents.document_currency_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.local_currency_code is 'Код валюты организации | Код валюты организации | dds.accounting_documents.local_currency_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | dds.accounting_documents.second_local_currency_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | dds.accounting_documents.document_currency_amount';
comment on column dm_calc.accounting_exchange_rate_revaluation.local_currency_amount is 'Сумма во внутренней валюте | Сумма во внутренней валюте | dds.accounting_documents.local_currency_amount';
comment on column dm_calc.accounting_exchange_rate_revaluation.second_local_currency_amount is 'Сумма во второй внутренней валюте | Сумма во второй внутренней валюте | dds.accounting_documents.second_local_currency_amount';
comment on column dm_calc.accounting_exchange_rate_revaluation.is_red_reverse_posting is 'Индикатор: красное сторно | Индикатор: красное сторно | dds.accounting_documents.is_red_reverse_posting';
comment on column dm_calc.accounting_exchange_rate_revaluation.reference_document_code is 'Номер ссылочного документа | Номер ссылочного документа | dds.accounting_documents.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation.reference_document_fiscal_year is 'Год ссылочного документа | Год ссылочного документа | dds.accounting_documents.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation.reference_document_position_line_item is 'Позиция ссылочного документа | Позиция ссылочного документа | dds.accounting_documents.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation.reverse_document_code is '№ документа сторно | Номер документа, сторнировавшего данную позицию (если она сторнирована) | dds.accounting_documents.reverse_document_code';
comment on column dm_calc.accounting_exchange_rate_revaluation.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | dds.accounting_documents.reverse_document_fiscal_year';
comment on column dm_calc.accounting_exchange_rate_revaluation.is_reversed_document is 'Индикатор сторно | Индикатор сторно | dds.accounting_documents.is_reversed_document';