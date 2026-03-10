drop table if EXISTS dm_calc.account_debt_revaluation;

create table dm_calc.account_debt_revaluation (	
	dt date not null,
	is_second_friday bool null,
	unit_balance_code varchar(4) not null,
	fiscal_year numeric(4,0) not null,
 	accounting_document_code varchar(10) not null,
 	dt_debt date not null,
	debit_or_credit varchar(1) null,
	account_type varchar(1) null,	
	document_currency_code varchar(5) not null,
	local_currency_code varchar(5) null,
	second_local_currency_code varchar(5) null,
	accounting_document_type varchar(2) null,
	position_line_item numeric(3,0) null,
 	exchange_diff_local_currency_amount numeric(17,2) ,
 	debt_balance_exchange_diff_local_currency_amount numeric(17,2) ,
 	exchange_diff_second_local_currency_amount numeric(17,2) ,
 	debt_balance_exchange_diff_second_local_currency_amount  numeric(17,2) , 
 	dttm_inserted 	timestamp not null default now(),
	dttm_updated 	timestamp not null default now(),
	job_name 		varchar(60) not null default 'airflow'::character varying,
	deleted_flag	bool not null default false )
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by (dt,unit_balance_code, fiscal_year, accounting_document_code, position_line_item );

comment on table dm_calc.account_debt_revaluation is 'Переоценка к задолженности контрагента';
comment on column dm_calc.account_debt_revaluation.dt is 'Дата | На какую дату указан остаток | calendar.dt';
comment on column dm_calc.account_debt_revaluation.is_second_friday is 'Флаг:вторая пятница месяца | Флаг:вторая пятница месяца | dm_calc.operating_periods_for_account_debt.is_second_friday';
comment on column dm_calc.account_debt_revaluation.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.unit_balance_code';
comment on column dm_calc.account_debt_revaluation.fiscal_year is 'Финансовый год | Финансовый год | accounting_documents.fiscal_year';
comment on column dm_calc.account_debt_revaluation.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_documents.accounting_document_code';
comment on column dm_calc.account_debt_revaluation.dt_debt is 'Дата возникновения задолженности | Дата возникновения задолженности | accounting_documents.dt_posting';
comment on column dm_calc.account_debt_revaluation.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | v.debit_or_credit';
comment on column dm_calc.account_debt_revaluation.account_type is 'Вид счета | Вид счета | accounting_documents.account_type';
comment on column dm_calc.account_debt_revaluation.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_documents.document_currency_code';
comment on column dm_calc.account_debt_revaluation.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_documents.local_currency_code';
comment on column dm_calc.account_debt_revaluation.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_documents.second_local_currency_code';
comment on column dm_calc.account_debt_revaluation.accounting_document_type is 'Вид документа | Вид документа | accounting_documents.accounting_document_type';
comment on column dm_calc.account_debt_revaluation.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | accounting_documents.position_line_item';
comment on column dm_calc.account_debt_revaluation.exchange_diff_local_currency_amount is 'ВВ Курсовая разница позиции| ВВ Курсовая разница позиции | accounting_exchange_rate_revaluation.local_currency_amount';
comment on column dm_calc.account_debt_revaluation.debt_balance_exchange_diff_local_currency_amount is 'ВВ Курсовая разница остатка позиции | ВВ Курсовая разница остатка позиции  | accounting_exchange_rate_revaluation.local_currency_amount';
comment on column dm_calc.account_debt_revaluation.exchange_diff_second_local_currency_amount is 'ВВ2 Курсовая разница позиции | ВВ2 Курсовая разница позиции | accounting_exchange_rate_revaluation.second_local_currency_amount';
comment on column dm_calc.account_debt_revaluation.debt_balance_exchange_diff_second_local_currency_amount is 'ВВ2 Курсовая разница остатка позиции | ВВ2 Курсовая разница остатка позиции | accounting_exchange_rate_revaluation.second_local_currency_amount';
