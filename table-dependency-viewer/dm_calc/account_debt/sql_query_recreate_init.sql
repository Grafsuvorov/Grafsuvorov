drop table if exists dm_calc.account_debt cascade;

create table dm_calc.account_debt (	
	dt date not null,
	is_second_friday bool null,
	unit_balance_code varchar(4) not null,
	plant_code varchar(4) null, 
	fiscal_year numeric(4,0) not null,
 	accounting_document_code varchar(10) not null,
 	dt_debt date not null,
	dt_clearing date null,
 	contract_number varchar(13) null,
 	counterparty_code varchar(10) null,
	debit_or_credit varchar(1) null,
	account_type varchar(1) null,	
	general_ledger_account_code varchar(10) null,
 	debt_balance_document_currency_amount numeric(17,2) default 0,
	document_currency_code varchar(5) not null,
	debt_balance_local_currency_amount numeric(17,2) default 0,
	local_currency_code varchar(5) null,
	debt_balance_second_local_currency_amount numeric(17,2) default 0,
	debt_balance_with_revaluation_diff_second_currency_amount numeric(17,2) default 0,
	debt_balance_usd_amount numeric(17,2) default 0,
	second_local_currency_code varchar(5) null,
	accounting_document_type varchar(2) null,
	position_line_item numeric(3,0) null,
	reverse_document_code varchar(10) null, 
	reference_document_number varchar(16) null, 
	accounting_document_status_code varchar(1) null,
	clearing_document_code varchar(10) null,
	tax_code varchar(2) null, 
	position_line_item_text varchar(50) null,
	special_general_ledger_indicator varchar(1) null,
	dt_baseline_due_date_calculation date null, 
	assignment_number varchar(18) null, 
	dt_accounting_document date null, 
	terms_of_payment_code varchar(4) null,
	document_currency_amount numeric(17,2) default 0,     -- s2t v.4 21.05.2024
	local_currency_amount numeric(17,2) default 0,        -- s2t v.4 21.05.2024
	second_local_currency_amount numeric(17,2) default 0, -- s2t v.4 21.05.2024
	usd_amount numeric(17,2) default 0,
--ВОЗМОЖНО НАДО БУДЕТ ДОБАВИТЬ
	--valuation_difference_second_local_currency_amount numeric(13,2) default 0,
	reverse_document_fiscal_year numeric(4) null,         -- s2t v.5 21.05.2024
	reason_for_reversal varchar(2) null,                  -- s2t v.5 21.05.2024
	invoice_document_code varchar(10) null,	              --DWH-1734
	fiscal_year_of_relevant_invoice numeric(4) null,	  --DWH-1734
	position_number_of_relevant_invoice numeric(3) null ,  --DWH-1734
	final_position_line_item numeric(3,0) null,				--DWH-1734
	final_fiscal_year numeric(4,0) not null,				--DWH-1734	
 	final_accounting_document_code varchar(10) null,		--DWH-1734
	document_currency_code_of_relevant_invoice varchar(5) null, ---DWH-1864
	general_ledger_account_code_of_relevant_invoice varchar(10) null,
	debit_or_credit_code_of_relevant_invoice varchar(1) null,
	reference_operation_type_code varchar(5) null,
	reference_object_key_code varchar(20) null,
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

comment on table dm_calc.account_debt is 'Задолженность контрагентов';
comment on column dm_calc.account_debt.dt is 'Дата | На какую дату указан остаток | dm_calc.operating_periods_for_account_debt.dt';
comment on column dm_calc.account_debt.is_second_friday is 'Флаг:вторая пятница месяца | Флаг:вторая пятница месяца | dm_calc.operating_periods_for_account_debt.is_second_friday';
comment on column dm_calc.account_debt.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.unit_balance_code';
comment on column dm_calc.account_debt.fiscal_year is 'Финансовый год | Финансовый год | accounting_documents.fiscal_year';
comment on column dm_calc.account_debt.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_documents.accounting_document_code';
comment on column dm_calc.account_debt.accounting_document_type is 'Вид документа | Вид документа | accounting_documents.accounting_document_type';
comment on column dm_calc.account_debt.dt_debt is 'Дата возникновения задолженности | Дата возникновения задолженности | accounting_documents.dt_posting';
comment on column dm_calc.account_debt.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_documents.local_currency_code';
comment on column dm_calc.account_debt.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_documents.second_local_currency_code';
comment on column dm_calc.account_debt.reverse_document_code is '№ документа сторно | № документа сторно | accounting_documents.reverse_document_code';
comment on column dm_calc.account_debt.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_documents.document_currency_code';
comment on column dm_calc.account_debt.reference_document_number is 'Ссылочный номер документа | Ссылочный номер документа | v.reference_document_number';
comment on column dm_calc.account_debt.accounting_document_status_code is 'Статус документа | Статус документа | v.accounting_document_status_code';
comment on column dm_calc.account_debt.clearing_document_code is 'Номер документа выравнивания | Номер документа выравнивания | v.clearing_document_code';
comment on column dm_calc.account_debt.dt_clearing is 'Дата выравнивания | Дата выравнивания | v.dt_clearing';
comment on column dm_calc.account_debt.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | accounting_documents.position_line_item';
comment on column dm_calc.account_debt.general_ledger_account_code is 'Основной счет главной книги | Основной счет главной книги | accounting_documents.general_ledger_account_code';
comment on column dm_calc.account_debt.account_type is 'Вид счета | Вид счета | accounting_documents.account_type';
comment on column dm_calc.account_debt.position_line_item_text is 'Текст к позиции | Текст к позиции бухдокумента | v.position_line_item_text';
comment on column dm_calc.account_debt.tax_code is 'Код налога с оборота | Код налога с оборота | accounting_documents.tax_code';
comment on column dm_calc.account_debt.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | v.debit_or_credit';
comment on column dm_calc.account_debt.special_general_ledger_indicator is 'Код Особой главной книги | Код Особой главной книги | v.special_general_ledger_indicator';
comment on column dm_calc.account_debt.counterparty_code is 'Номер контрагента | Номер контрагента | v.coalesce(client_code, contractor_code)';
comment on column dm_calc.account_debt.contract_number is 'Номер договора | Номер договора | accounting_documents.contract_number';
comment on column dm_calc.account_debt.plant_code is 'Завод | Завод | accounting_documents.plant_code';
comment on column dm_calc.account_debt.dt_baseline_due_date_calculation is 'Базовая дата для расчета срока оплаты | Базовая дата для расчета срока оплаты | accounting_documents.dt_baseline_due_date_calculation';
comment on column dm_calc.account_debt.terms_of_payment_code is 'Код условий платежа | Код условий платежа | accounting_documents.terms_of_payment_code';
comment on column dm_calc.account_debt.assignment_number is 'Номер присвоения | Номер присвоения | accounting_documents.assignment_number';
comment on column dm_calc.account_debt.dt_accounting_document is 'Дата документа | Дата документа | accounting_documents.dt_accounting_document';
comment on column dm_calc.account_debt.debt_balance_document_currency_amount is 'Остаток задолженности в валюте документа | Остаток задолженности в валюте документа | accounting_documents.document_currency_amount';
comment on column dm_calc.account_debt.debt_balance_local_currency_amount is 'Остаток задолженности в валюте организации | Остаток задолженности в валюте организации | accounting_documents.local_currency_amount';
comment on column dm_calc.account_debt.debt_balance_second_local_currency_amount is 'Остаток задолженности во второй валюте | Остаток задолженности во второй валюте | accounting_documents.second_local_currency_amount';
comment on column dm_calc.account_debt.debt_balance_with_revaluation_diff_second_currency_amount is 'Остаток задолженности, во второй валюте, с учётом последней переоценки | Остаток задолженности, во второй валюте, с учётом последней переоценки | accounting_document_position.second_local_currency_amount + valuation_difference_second_local_currency_amount';	
comment on column dm_calc.account_debt.debt_balance_usd_amount is 'Остаток задолженности в долларах | Остаток задолженности в долларах | accounting_documents.document_currency_amount';
comment on column dm_calc.account_debt.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | accounting_documents.document_currency_amount';
comment on column dm_calc.account_debt.local_currency_amount is 'Сумма во внутренней валюте | Сумма во внутренней валюте | accounting_documents.local_currency_amount';
comment on column dm_calc.account_debt.second_local_currency_amount is 'Сумма во второй ВнутрВалюте | Сумма во второй ВнутрВалюте | accounting_documents.second_local_currency_amount';
comment on column dm_calc.account_debt.usd_amount is 'Сумма задолженности в долларах | Сумма задолженности в долларах | accounting_documents.document_currency_amount';
comment on column dm_calc.account_debt.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | accounting_documents.reverse_document_fiscal_year';
comment on column dm_calc.account_debt.reason_for_reversal is 'Причина сторно или обратной проводки | Причина сторно или обратной проводки | accounting_documents.reason_for_reversal';
comment on column dm_calc.account_debt.invoice_document_code is 'Ссылочный инвойс (№) | Ссылочный инвойс (№) | accounting_documents.invoice_document_code';
comment on column dm_calc.account_debt.fiscal_year_of_relevant_invoice is 'Ссылочный инвойс (Год) | Ссылочный инвойс (Год)  | accounting_documents.fiscal_year_of_relevant_invoice';
comment on column dm_calc.account_debt.position_number_of_relevant_invoice is 'Ссылочный инвойс (Позиция) | Ссылочный инвойс (Позиция) | accounting_documents.position_number_of_relevant_invoice';
comment on column dm_calc.account_debt.final_position_line_item is 'Позиция документа задолженности | Позиция документа задолженности  | coalesce (position_number_of_relevant_invoice,position_line_item)';
comment on column dm_calc.account_debt.final_fiscal_year is 'Год документа задолженности | Год документа задолженности | coalesce (fiscal_year_of_relevant_invoice, fiscal_year)';
comment on column dm_calc.account_debt.final_accounting_document_code is 'Номер документа задолженности | Номер документа задолженности  | coalesce (invoice_document_code, accounting_document_code)';
comment on column dm_calc.account_debt.document_currency_code_of_relevant_invoice is 'Ссылочный инвойс (валюта документа) | Ссылочный инвойс (валюта документа) | accounting_receivables_and_payables.document_currency_code';
comment on column dm_calc.account_debt.general_ledger_account_code_of_relevant_invoice is 'Ссылочный инвойс (основной счет ГК) | Ссылочный инвойс (основной счет ГК) | accounting_receivables_and_payables.general_ledger_account_code';
comment on column dm_calc.account_debt.debit_or_credit_code_of_relevant_invoice is 'Ссылочный инвойс (Индикатор дебета/кредита) | Ссылочный инвойс (Индикатор дебета/кредита) | accounting_receivables_and_payables.debit_or_credit';
comment on column dm_calc.account_debt.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | accounting_receivables_and_payables.reference_procedure';
comment on column dm_calc.account_debt.reference_object_key_code is 'Ссылочный ключ | Ссылочный ключ | accounting_document_header.reference_object_key';
