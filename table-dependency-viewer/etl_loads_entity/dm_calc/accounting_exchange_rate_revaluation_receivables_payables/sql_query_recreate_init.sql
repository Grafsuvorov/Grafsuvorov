drop table if exists dm_calc.accounting_exchange_rate_revaluation_receivables_payables;
create table if not exists dm_calc.accounting_exchange_rate_revaluation_receivables_payables(
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	position_line_item numeric(3) NOT NULL,
	counterparty_code varchar(10) NULL,
	contract_number varchar(13) NULL,
	plant_code varchar(4) NULL,
	reference_key_internal_for_document_header_1 varchar(20) null,
	reference_key_for_line_item_3 varchar(20) null,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
DISTRIBUTED by (unit_balance_code,fiscal_year,accounting_document_code) ;

comment on table dm_calc.accounting_exchange_rate_revaluation_receivables_payables is 'Курсовые разницы';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.unit_balance_code is 'Балансовая единица | Балансовая единица | dm_calc.accounting_receivables_and_payables.unit_balance_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.fiscal_year is 'Финансовый год | Финансовый год | dm_calc.accounting_receivables_and_payables.fiscal_year';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | dm_calc.accounting_receivables_and_payables.accounting_document_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | dm_calc.accounting_receivables_and_payables.position_line_item';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.counterparty_code is 'Код контрагента | Код контрагента | dm_calc.accounting_receivables_and_payables.counterparty_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.contract_number is 'Код договора | Код договора | dm_calc.accounting_receivables_and_payables.contract_number';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.plant_code is 'Завод | Завод | dm_calc.accounting_receivables_and_payables.plant_code';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.reference_key_internal_for_document_header_1 is 'Внутренний ссылочный ключ 1 к заголовку документа | Внутренний ссылочный ключ 1 к заголовку документа | dm_calc.accounting_receivables_and_payables.reference_key_internal_for_document_header_1';
comment on column dm_calc.accounting_exchange_rate_revaluation_receivables_payables.reference_key_for_line_item_3 is 'Ссылочный ключ 3 к позиции документа | Ссылочный ключ 3 к позиции документа | dm_calc.accounting_receivables_and_payables.reference_key_for_line_item_3';
