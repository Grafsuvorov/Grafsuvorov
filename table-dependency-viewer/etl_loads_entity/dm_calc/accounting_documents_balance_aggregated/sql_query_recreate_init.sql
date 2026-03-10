drop table if exists dm_calc.accounting_documents_balance_aggregated ;
CREATE TABLE dm_calc.accounting_documents_balance_aggregated (
	unit_balance_code varchar(4) NOT NULL,
	plant_code varchar(4) NULL,
	general_ledger_account_code varchar(10) NOT NULL,
	dt_posting date NULL,
	dt_clearing date null,
	customer_code varchar(10) NULL,
	supplier_code varchar(10) NULL,
	counterparty_code varchar(10) NULL,
	contract_number varchar(13) NULL,
	balance_closing_document_currency_amount numeric(19, 2) NULL DEFAULT 0,
	document_currency_code varchar(5) NOT NULL,
	balance_closing_local_currency_amount numeric(19, 2) NULL DEFAULT 0,
	local_currency_code varchar(5) NOT NULL,
	balance_closing_second_local_currency_amount numeric(19, 2) NULL DEFAULT 0,
	second_local_currency_code varchar(5) NULL,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (unit_balance_code, plant_code, general_ledger_account_code, dt_posting, counterparty_code, contract_number, document_currency_code);

comment on table dm_calc.accounting_documents_balance_aggregated is 'Агрегация по бухгалтерским документам в разрезе контракта и контрагента';
comment on column dm_calc.accounting_documents_balance_aggregated.dt_posting is 'Дата проводки | Дата проводки документа | accounting_documents.dt_posting';
comment on column dm_calc.accounting_documents_balance_aggregated.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.unit_balance_code';
comment on column dm_calc.accounting_documents_balance_aggregated.plant_code is 'Филиал | Филиал | Алгоритм';
comment on column dm_calc.accounting_documents_balance_aggregated.general_ledger_account_code is 'Основной счет главной книги, код | Код основного счета главной книги | accounting_document.general_ledger_account_code';
comment on column dm_calc.accounting_documents_balance_aggregated.customer_code is 'Номер дебитора | Номер дебитора | accounting_document.client_code';
comment on column dm_calc.accounting_documents_balance_aggregated.supplier_code is 'Номер счета поставщика или кредитора | Номер поставщика или кредитора | accounting_document.contractor_code';
comment on column dm_calc.accounting_documents_balance_aggregated.counterparty_code is 'Номер контрагента | Номер контрагента | accounting_document.coalesce(client_code,contractor_code)';
comment on column dm_calc.accounting_documents_balance_aggregated.balance_closing_document_currency_amount is 'Сальдо на конец в валюте документа | Сальдо на начало в валюте документа | accounting_document.document_currency_amount';
comment on column dm_calc.accounting_documents_balance_aggregated.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_document.document_currency_code';
comment on column dm_calc.accounting_documents_balance_aggregated.balance_closing_local_currency_amount is 'Сальдо на конец в валюте организации | Сальдо на начало в валюте организации | accounting_document.local_currency_amount';
comment on column dm_calc.accounting_documents_balance_aggregated.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_document.local_currency_code';
comment on column dm_calc.accounting_documents_balance_aggregated.balance_closing_second_local_currency_amount is 'Сальдо на конец во второй валюте | Сальдо на начало во второй валюте | accounting_document.second_local_currency_amount';
comment on column dm_calc.accounting_documents_balance_aggregated.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_document.second_local_currency_code';
comment on column dm_calc.accounting_documents_balance_aggregated.contract_number is 'Номер договора | Договор, в рамках которого возникла задолженность (номер) | accounting_document.contract_number';