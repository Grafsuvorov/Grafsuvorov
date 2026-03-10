drop table if exists dm_calc.accounting_exchange_rate_revaluation_with_document_reference;

--CREATE TABLE userdata.accounting_exchange_rate_revaluation_with_document_reference (
CREATE TABLE dm_calc.accounting_exchange_rate_revaluation_with_document_reference (
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
	deleted_flag bool NOT NULL DEFAULT FALSE,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::CHARACTER VARYING
)
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
distributed BY (unit_balance_code, reference_document_fiscal_year, reference_document_code, reference_document_position_line_item);


comment on table dm_calc.accounting_exchange_rate_revaluation_with_document_reference is 'Курсовые разницы со ссылочными документами';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code is 'Балансовая единица | Балансовая единица | dm_calc.accounting_exchange_rate_revaluation.unit_balance_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | dm_calc.accounting_exchange_rate_revaluation.accounting_document_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.account_type is 'Вид счета | Вид счета | dm_calc.accounting_exchange_rate_revaluation..account_type';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.fiscal_year is 'Финансовый год | Финансовый год | dm_calc.accounting_exchange_rate_revaluation.fiscal_year';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | dm_calc.accounting_exchange_rate_revaluation.position_line_item';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.position_line_item_text is 'Текст к позиции | Текст к позиции | dm_calc.accounting_exchange_rate_revaluation.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.accounting_document_type is 'Вид документа | Вид документа | dm_calc.accounting_exchange_rate_revaluation.accounting_document_type';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.dt_posting is 'Дата проводки | Дата проводки | dm_calc.accounting_exchange_rate_revaluation.dt_posting';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.dt_accounting_document is 'Дата документа | Дата документа | dm_calc.accounting_exchange_rate_revaluation.dt_accounting_document';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | dm_calc.accounting_exchange_rate_revaluation.debit_or_credit';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.general_ledger_account_code is 'Основной счет главной книги | Основной счет главной книги | dm_calc.accounting_exchange_rate_revaluation.general_ledger_account_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.special_general_ledger_indicator is 'Код Особой главной книги | Код Особой главной книги | dm_calc.accounting_exchange_rate_revaluation.special_general_ledger_indicator';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.document_currency_code is 'Код валюты документа | Код валюты документа | dm_calc.accounting_exchange_rate_revaluation.document_currency_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.local_currency_code is 'Код валюты организации | Код валюты организации | dm_calc.accounting_exchange_rate_revaluation.local_currency_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | dm_calc.accounting_exchange_rate_revaluation.second_local_currency_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | dm_calc.accounting_exchange_rate_revaluation.document_currency_amount';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.local_currency_amount is 'Сумма во внутренней валюте | Сумма во внутренней валюте | dm_calc.accounting_exchange_rate_revaluation.local_currency_amount';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.second_local_currency_amount is 'Сумма во второй внутренней валюте | Сумма во второй внутренней валюте | dm_calc.accounting_exchange_rate_revaluation.second_local_currency_amount';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.is_red_reverse_posting is 'Индикатор: красное сторно | Индикатор: красное сторно | dm_calc.accounting_exchange_rate_revaluation.is_red_reverse_posting';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.reference_document_code is 'Номер ссылочного документа | Номер ссылочного документа | dm_calc.accounting_exchange_rate_revaluation.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year is 'Год ссылочного документа | Год ссылочного документа | dm_calc.accounting_exchange_rate_revaluation.position_line_item_text';
comment on column dm_calc.accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item is 'Позиция ссылочного документа | Позиция ссылочного документа | dm_calc.accounting_exchange_rate_revaluation.position_line_item_text';