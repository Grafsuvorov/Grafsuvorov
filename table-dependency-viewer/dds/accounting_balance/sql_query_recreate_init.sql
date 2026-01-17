drop table if exists dds.accounting_balance cascade;
create table dds.accounting_balance (
	unit_balance_code varchar(4) not null,
	fiscal_year varchar(4) not null,
	general_ledger_account_code varchar(10) not null,
	document_currency_code varchar(5) not null,
	local_currency_code varchar(5) null,
	second_local_currency_code  varchar(5)  null,
	debit_or_credit_code varchar(1) not null,
	posting_period_mm varchar(2) not null,
	balance_opening_document_currency_amount numeric(20, 2) default 0,
	balance_opening_local_currency_amount numeric(20, 2) default 0,
	balance_opening_second_local_currency_amount numeric(20, 2) default 0,
	turnover_document_currency_amount numeric(20, 2) default 0,
	turnover_local_currency_amount numeric(20, 2) default 0,
	turnover_second_local_currency_amount numeric(20, 2) default 0,
	balance_closing_document_currency_amount numeric(20, 2) default 0,
	balance_closing_local_currency_amount numeric(20, 2) default 0,
	balance_closing_second_local_currency_amount numeric(20, 2) default 0,
	dttm_inserted 		timestamp not null default now(),
	dttm_updated 		timestamp not null default now(),
	job_name 			varchar(60) not null default 'airflow'::character varying,
	deleted_flag		bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed randomly;

comment on table dds.accounting_balance IS 'Сальдо счетов ГК';
comment on column dds.accounting_balance.unit_balance_code is 'Балансовая единица | Балансовая единица | GLT0.BUKRS';
comment on column dds.accounting_balance.fiscal_year is 'Финансовый год | Финансовый год | GLT0.RYEAR';
comment on column dds.accounting_balance.posting_period_mm is 'Период | Период |';
comment on column dds.accounting_balance.general_ledger_account_code is 'Основной счет главной книги | Основной счет главной книги | GLT0.RACCT';
comment on column dds.accounting_balance.debit_or_credit_code is 'Индикатор дебета/кредита | Индикатор дебета/кредита | GLT0.DRCRK';
comment on column dds.accounting_balance.document_currency_code is 'Код валюты документа | Валюта для balance_opening_document_currency_amount | GLT0.RTCUR';
comment on column dds.accounting_balance.balance_opening_document_currency_amount is 'Сальдо на начало в валюте документа | Сальдо на начало в валюте документа |';
comment on column dds.accounting_balance.turnover_document_currency_amount is 'Оборот в валюте документа | Оборот в валюте документа |';
comment on column dds.accounting_balance.balance_closing_document_currency_amount is 'Сальдо на конец в валюте документа | Сальдо на конец в валюте документа |';
comment on column dds.accounting_balance.local_currency_code is 'Код внутренней валюты | Валюта для balance_opening_local_currency_amount |';
comment on column dds.accounting_balance.balance_opening_local_currency_amount is 'Сальдо на начало в валюте организации | Сальдо на начало в валюте организации | GLT0.KSLVT';
comment on column dds.accounting_balance.turnover_local_currency_amount is 'Оборот в валюте организации | Оборот в валюте организации |';
comment on column dds.accounting_balance.balance_closing_local_currency_amount is 'Сальдо на конец в валюте организации | Сальдо на конец в валюте организации |';
comment on column dds.accounting_balance.second_local_currency_code is 'Код второй внутренней валюты | Валюта для balance_opening_second_local_currency_amount |';
comment on column dds.accounting_balance.balance_opening_second_local_currency_amount is 'Сальдо на начало во второй валюте | Сальдо на начало во второй валюте | GLT0.HSLVT';
comment on column dds.accounting_balance.turnover_second_local_currency_amount is 'Оборот во второй валюте | Оборот во второй валюте |';
comment on column dds.accounting_balance.balance_closing_second_local_currency_amount is 'Сальдо на конец во второй валюте | Сальдо на конец во второй валюте |';