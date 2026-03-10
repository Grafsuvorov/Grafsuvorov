drop table if exists dm_calc.account_balance_by_contract;
create table dm_calc.account_balance_by_contract(
	dt date not null,
	unit_balance_code varchar(4) not null,
	plant_code varchar(4) null,
	general_ledger_account_code varchar(10) not null,
	customer_code varchar(10) null,
	supplier_code varchar(10) null,
	counterparty_code varchar(10) null,
	contract_number varchar(13) null,
	balance_closing_document_currency_amount numeric(20,2) default 0,
	document_currency_code varchar(5) not null,
	balance_closing_local_currency_amount numeric(20,2) default 0,
	local_currency_code varchar(5) not null,
	balance_closing_second_local_currency_amount numeric(20,2) default 0,
	second_local_currency_code varchar(5) null,
	dttm_inserted		timestamp not null default now(),
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
distributed by (dt, unit_balance_code);

comment on table dm_calc.account_balance_by_contract is 'Бухгалтерия, остатки по счетам в разрезе договоров';
comment on column dm_calc.account_balance_by_contract.dt is 'Дата | На какую дату указан остаток | calendar.dt';
comment on column dm_calc.account_balance_by_contract.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents_balance_aggregated.unit_balance_code';
comment on column dm_calc.account_balance_by_contract.plant_code is 'Филиал | Филиал | Алгоритм';
comment on column dm_calc.account_balance_by_contract.general_ledger_account_code is 'Основной счет главной книги, код | Код основного счета главной книги | accounting_documents_balance_aggregated.general_ledger_account_code';
comment on column dm_calc.account_balance_by_contract.customer_code is 'Номер дебитора | Номер дебитора | accounting_documents_balance_aggregated.client_code';
comment on column dm_calc.account_balance_by_contract.supplier_code is 'Номер счета поставщика или кредитора | Номер поставщика или кредитора | accounting_documents_balance_aggregated.contractor_code';
comment on column dm_calc.account_balance_by_contract.counterparty_code is 'Номер контрагента | Номер контрагента | accounting_documents_balance_aggregated.counterparty_code';
comment on column dm_calc.account_balance_by_contract.balance_closing_document_currency_amount is 'Сальдо на конец в валюте документа | Сальдо на начало в валюте документа | accounting_documents_balance_aggregated.balance_closing_document_currency_amount';
comment on column dm_calc.account_balance_by_contract.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_documents_balance_aggregated.document_currency_code';
comment on column dm_calc.account_balance_by_contract.balance_closing_local_currency_amount is 'Сальдо на конец в валюте организации | Сальдо на начало в валюте организации | accounting_documents_balance_aggregated.balance_closing_local_currency_amount';
comment on column dm_calc.account_balance_by_contract.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_documents_balance_aggregated.local_currency_code';
comment on column dm_calc.account_balance_by_contract.balance_closing_second_local_currency_amount is 'Сальдо на конец во второй валюте | Сальдо на начало во второй валюте | accounting_documents_balance_aggregated.balance_closing_second_local_currency_amount';
comment on column dm_calc.account_balance_by_contract.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_documents_balance_aggregated.second_local_currency_code';
comment on column dm_calc.account_balance_by_contract.contract_number is 'Номер договора | Договор, в рамках которого возникла задолженность (номер) | accounting_documents_balance_aggregated.contract_number';