drop table if exists dm_calc.investment_payments_actual_group_00;

CREATE TABLE dm_calc.investment_payments_actual_group_00 (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	dt_posting date NOT NULL,
	debit_or_credit bpchar(1) NULL,
	general_ledger_account_code varchar(10) NULL,
	document_currency_amount numeric(15, 2) NULL DEFAULT 0,
	document_currency_code varchar(5) NULL,
	customer_code varchar(10) NULL,
	supplier_code varchar(10) NULL,
	accounting_document_type varchar(2) NULL,
	clearing_document_code varchar(10) NULL,
	dt_clearing date NULL,
	position_line_item numeric(3) NULL,
	tax_code varchar(2) NULL,
	assignment_number varchar(18) NULL,
	exchange_rate numeric(9, 5) NULL,
	wbs_element_code varchar(8) NULL,
	purchase_document_code varchar(10) NULL,
	purchase_document_position_code varchar(5) NULL,
	earmarked_document_code varchar(10) NULL,
	earmarked_document_position_code varchar(3) NULL,
	fund_code varchar(10) NULL,
	is_agent_payment bool null,
	is_payment_document_optional varchar(1) null,
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
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

comment on table dm_calc.investment_payments_actual_group_00 is 'Предрасчет для факта платежей БИЗ ERP';
comment on column dm_calc.investment_payments_actual_group_00.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.unit_balance_code';
comment on column dm_calc.investment_payments_actual_group_00.fiscal_year is 'Финансовый год | Финансовый год бухдокумента | accounting_documents.fiscal_year';
comment on column dm_calc.investment_payments_actual_group_00.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_documents.accounting_document_code';
comment on column dm_calc.investment_payments_actual_group_00.dt_posting is 'Дата проводки в документе | Дата проводки бухдокумента | accounting_documents.dt_posting';
comment on column dm_calc.investment_payments_actual_group_00.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | accounting_documents.debit_or_credit';
comment on column dm_calc.investment_payments_actual_group_00.general_ledger_account_code is 'Основной счет главной книги, код | Код основного счета главной книги | accounting_documents.general_ledger_account_code';
comment on column dm_calc.investment_payments_actual_group_00.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | accounting_documents.document_currency_amount';
comment on column dm_calc.investment_payments_actual_group_00.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_documents.document_currency_code';
comment on column dm_calc.investment_payments_actual_group_00.customer_code is 'Номер дебитора | Номер дебитора | accounting_documents.client_code';
comment on column dm_calc.investment_payments_actual_group_00.supplier_code is 'Номер счета поставщика или кредитора | Номер поставщика или кредитора | accounting_documents.contractor_code';
comment on column dm_calc.investment_payments_actual_group_00.accounting_document_type is 'Вид документа | Вид бухдокумента | accounting_documents.accounting_document_type';
comment on column dm_calc.investment_payments_actual_group_00.clearing_document_code is 'Номер документа выравнивания |  | accounting_documents.clearing_document_code';
comment on column dm_calc.investment_payments_actual_group_00.dt_clearing is 'Дата выравнивания | Дата закрытия задолженности | accounting_documents.dt_clearing';
comment on column dm_calc.investment_payments_actual_group_00.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | accounting_documents.position_line_item';
comment on column dm_calc.investment_payments_actual_group_00.tax_code is 'Код налога с оборота | Код НДС | accounting_documents.tax_code';
comment on column dm_calc.investment_payments_actual_group_00.assignment_number is 'Номер присвоения | Номер присвоения | accounting_documents.assignment_number';
comment on column dm_calc.investment_payments_actual_group_00.exchange_rate is 'Валютный курс | Валютный курс | accounting_documents.exchange_rate';
comment on column dm_calc.investment_payments_actual_group_00.wbs_element_code is 'ID элемента структурного плана проекта (СПП) | ID элемента структурного плана проекта (СПП) | accounting_documents.wbs_element_code';
comment on column dm_calc.investment_payments_actual_group_00.purchase_document_code is 'Номер документа закупки | Номер документа закупки | accounting_documents.purchase_document_code';
comment on column dm_calc.investment_payments_actual_group_00.purchase_document_position_code is 'Позиция документа закупки | Позиция документа закупки | accounting_documents.purchase_document_position_line_item_code';
comment on column dm_calc.investment_payments_actual_group_00.earmarked_document_code is 'Номер документа для выделения финансовых средств | Номер документа для выделения финансовых средств | accounting_documents.earmarked_document_code';
comment on column dm_calc.investment_payments_actual_group_00.earmarked_document_position_code is 'Позиция документа резервирования | Позиция документа резервирования | accounting_documents.earmarked_document_position_line_item_code';
comment on column dm_calc.investment_payments_actual_group_00.fund_code is 'Фонд | Фонд | accounting_documents.fund_code';
comment on column dm_calc.investment_payments_actual_group_00.is_agent_payment is 'Индикатор агентского платежа | Индикатор агентского платежа |';
comment on column dm_calc.investment_payments_actual_group_00.is_payment_document_optional is 'Индикатор опциональности платежа | Индикатор опциональности платежа |';