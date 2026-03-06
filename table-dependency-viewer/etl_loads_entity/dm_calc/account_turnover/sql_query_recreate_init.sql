drop table if exists dm_calc.account_turnover cascade;
create table if not exists dm_calc.account_turnover (
	unit_balance_code varchar(4) not null,
	fiscal_year numeric(4) not null, 
	accounting_document_code varchar(10) not null, 
	dt_posting date not null,
	debit_or_credit_code bpchar(1) null,
	correspondence_debit_or_credit_code varchar(1) null,
	account_type bpchar(1) null,
	general_ledger_account_code varchar(10) null, 
	correspondence_general_ledger_account_code varchar(10) null, 
	debit_turnover_document_currency_amount numeric(19,2) default 0, 
	debit_turnover_local_currency_amount numeric(19,2) default 0, 
	debit_turnover_second_local_currency_amount numeric(19,2) default 0, 
	credit_turnover_document_currency_amount numeric(19,2) default 0, 
	credit_turnover_local_currency_amount numeric(19,2) default 0, 
	credit_turnover_second_local_currency_amount numeric(19,2) default 0, 
	document_currency_code varchar(5) null,
	local_currency_code varchar(5) null, 
	second_local_currency_code varchar(5) null, 
	plant_code varchar(4) null,
	contract_number varchar(50) null, 
	counterparty_code varchar(10) null,
	accounting_document_type varchar(2) null,
	posting_period varchar(2) not null,
	accounting_document_header_text varchar(25) null, 
	reverse_document_code varchar(10) null, 
	reference_document_number varchar(16) null, 
	clearing_document_code varchar(10) null, 
	dt_clearing date null, 
	position_line_item numeric(3) null, 
	correspondence_line_item_number numeric(3) null,
	credit_line_item_number numeric(3) null,
	debit_line_item_number numeric(3) null,
	credit_item_for_new_item_number numeric(3) null,
	debit_item_for_new_item_number numeric(3) null,
	credit_item_number_from_ledger_item_split numeric(3) null,
	debit_item_number_from_ledger_item_split numeric(3) null,
	tax_code varchar(2) null, 
	invoice_document_code varchar(10) null, 
	fiscal_year_of_relevant_invoice numeric(4) null, 
	position_number_of_relevant_invoice numeric(3) null, 
	position_line_item_text varchar(50) null, 
	special_general_ledger_indicator bpchar(1) null, 
	dt_baseline_due_date_calculation date null, 
	terms_of_payment_code varchar(4) null, 
	assignment_number varchar(18) null, 
	is_red_reverse_posting bpchar(1) null, 
	dt_accounting_document date null, 
	dt_tax_reporting date null, 
	reverse_document_fiscal_year numeric(4) null, 
	dt_accounting_document_created timestamp null, 
	accounting_document_created_by varchar(12) null, 
	transaction_code varchar(20) null, 
	exchange_rate numeric(9, 5) null, 
	reference_procedure varchar(5) null, 
	reference_object_key varchar(20) null, 
	reason_for_reversal varchar(2) null, 
	reference_key_internal_for_document_header_1 varchar(20) null, 
	reference_key_internal_for_document_header_2 varchar(20) null, 
	reference_key_for_line_item_1 varchar(20) null, 
	reference_key_for_line_item_2 varchar(20) null, 
	reference_key_for_line_item_3 varchar(20) null, 
	material_code varchar(18) null, 
	cost_center_code varchar(10) null, 
	co_order_number varchar(12) null, 
	wbs_element_code varchar(8) null, 
	funds_center_code varchar(16) null,
	financial_position_internal_code varchar(14) null, 
	transaction_type_general_ledger varchar(4) null, 
	asset_main_number varchar(12) null, 
	asset_subnumber varchar(4) null, 
	asset_transaction_type varchar(3) null, 
	settlement_period bpchar(6) null, 
	payee_or_payer_code varchar(10) null,
	is_red_reverse_debit_posting bpchar(1) null, 
    is_red_reverse_credit_posting bpchar(1) null,
    document_currency_amount decimal(14,2) default 0, 
    local_currency_amount decimal(14,2) default 0, 
    second_local_currency_amount decimal(14,2) default 0, 
	dttm_inserted 	timestamp not null default now(),
	dttm_updated  	timestamp not null default now(),
	job_name 		varchar(60) not null default 'airflow'::character varying,
	deleted_flag	bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (unit_balance_code, fiscal_year, accounting_document_code);
-- comments
comment on table dm_calc.account_turnover is 'Обороты по счетам';
comment on column dm_calc.account_turnover.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_document_header.unit_balance_code';
comment on column dm_calc.account_turnover.fiscal_year is 'Финансовый год | Финансовый год бухдокумента | accounting_document_header.fiscal_year';
comment on column dm_calc.account_turnover.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_document_header.accounting_document_code';
comment on column dm_calc.account_turnover.accounting_document_type is 'Вид документа | Вид бухдокумента | accounting_document_header.accounting_document_type';
comment on column dm_calc.account_turnover.dt_posting is 'Дата проводки в документе | Дата проводки бухдокумента | accounting_document_header.dt_posting';
comment on column dm_calc.account_turnover.posting_period is 'Месяц проводки | Месяц проводки | accounting_document_header.posting_period';
comment on column dm_calc.account_turnover.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_document_header.document_currency_code';
comment on column dm_calc.account_turnover.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_document_header.local_currency_code';
comment on column dm_calc.account_turnover.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_document_header.second_local_currency_code';
comment on column dm_calc.account_turnover.accounting_document_header_text is 'Текст заголовка документа | Текст заголовка документа | accounting_document_header.document_header_text';
comment on column dm_calc.account_turnover.reverse_document_code is '№ документа сторно | Номер документа, сторнировавшего данную позицию (если она сторнирована) | accounting_document_header.reverse_document_code';
comment on column dm_calc.account_turnover.reference_document_number is 'Ссылочный номер документа | Ссылочный номер документа | accounting_document_header.reference_document_number';
comment on column dm_calc.account_turnover.clearing_document_code is 'Номер документа выравнивания |  | accounting_document_position.clearing_document_code';
comment on column dm_calc.account_turnover.dt_clearing is 'Дата выравнивания | Дата закрытия задолженности | accounting_document_position.dt_clearing';
comment on column dm_calc.account_turnover.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | accounting_document_position.position_line_item';
comment on column dm_calc.account_turnover.correspondence_line_item_number is 'Номер корреспондирующей отдельной позиции | Номер корреспондирующей отдельной позиции | accounting_document_position_correspondence.debit_line_item_number or credit_line_item_number';
comment on column dm_calc.account_turnover.credit_line_item_number is 'Номер корреспондирующей отдельной позиции по кредиту | Номер корреспондирующей отдельной позиции по кредиту | accounting_document_position_correspondence.credit_line_item_number';
comment on column dm_calc.account_turnover.debit_line_item_number is 'Номер корреспондирующей отдельной позиции по дебиту | Номер корреспондирующей отдельной позиции по дебиту | accounting_document_position_correspondence.debit_line_item_number';
comment on column dm_calc.account_turnover.credit_item_for_new_item_number is 'Номер позиции для новых позиций по кредиту | Номер позиции для новых позиций по кредиту | accounting_document_position_correspondence.credit_item_for_new_item_number';
comment on column dm_calc.account_turnover.debit_item_for_new_item_number is 'Номер позиции для новых позиций по дебиту | Номер позиции для новых позиций по дебиту | accounting_document_position_correspondence.debit_item_for_new_item_number';
comment on column dm_calc.account_turnover.credit_item_number_from_ledger_item_split is 'Item Number From Ledger Item Split Credit | Item Number From Ledger Item Split Credit | accounting_document_position_correspondence.credit_item_number_from_ledger_item_split';
comment on column dm_calc.account_turnover.debit_item_number_from_ledger_item_split is 'Item Number From Ledger Item Split Debit | Item Number From Ledger Item Split Debit | accounting_document_position_correspondence.debit_item_number_from_ledger_item_split';
comment on column dm_calc.account_turnover.general_ledger_account_code is 'Основной счет главной книги, код | Код основного счета главной книги | accounting_document_position.general_ledger_account_code';
comment on column dm_calc.account_turnover.correspondence_general_ledger_account_code is 'Корреспондирующий счет главной книги | Код корреспондирующего счета главной книги | accounting_document_position_correspondence.debit_account_code or credit_account_code';
comment on column dm_calc.account_turnover.account_type is 'Вид счета | Вид счета | accounting_document_position.account_type';
comment on column dm_calc.account_turnover.tax_code is 'Код налога с оборота | Код НДС | accounting_document_position.tax_code';
comment on column dm_calc.account_turnover.invoice_document_code is 'Номер счета-фактуры, к которому относится операция | Номер счета-фактуры, к которому относится операция | accounting_document_position.invoice_document_code';
comment on column dm_calc.account_turnover.fiscal_year_of_relevant_invoice is 'Финансовый год соответствующего счета (при кредитовом авизо) | Финансовый год соответствующего счета (при кредитовом авизо) | accounting_document_position.fiscal_year_of_relevant_invoice';
comment on column dm_calc.account_turnover.position_number_of_relevant_invoice is 'Позиция проводки в соответствующем счете | Позиция проводки в соответствующем счете | accounting_document_position.position_number_of_relevant_invoice';
comment on column dm_calc.account_turnover.position_line_item_text is 'Текст к позиции | Текст к позиции бухдокумента | accounting_document_position.position_line_item_text';
comment on column dm_calc.account_turnover.debit_or_credit_code is 'Индикатор дебета/кредита | Индикатор дебета/кредита | accounting_document_position.debit_or_credit';
comment on column dm_calc.account_turnover.correspondence_debit_or_credit_code is 'Индикатор дебета/кредита условный | Индикатор дебета/кредита условный | S/H';
comment on column dm_calc.account_turnover.special_general_ledger_indicator is 'Код Особой главной книги | Код ОГК | accounting_document_position.special_general_ledger_indicator';
comment on column dm_calc.account_turnover.contract_number is 'Номер договора | Договор, в рамках которого возникла задолженность (номер) | accounting_document_position.contract_number';
comment on column dm_calc.account_turnover.plant_code is 'Завод | Код филиала, к которому относится задолженность | Алгоритм по 3 полям';
comment on column dm_calc.account_turnover.dt_baseline_due_date_calculation is 'Базовая дата для расчета срока оплаты | Базовая дата для расчёта плановых дат платежей | accounting_document_position.dt_baseline_due_date_calculation';
comment on column dm_calc.account_turnover.terms_of_payment_code is 'Код условий платежа | Условия, фиксирующие, в какой срок, какими частями, задолженость должна быть оплачена (код условия платежа) | accounting_document_position.terms_of_payment_code';
comment on column dm_calc.account_turnover.assignment_number is 'Номер присвоения | Номер присвоения | accounting_document_position.assignment_number';
comment on column dm_calc.account_turnover.is_red_reverse_posting is 'Индикатор: красное сторно | Индикатор: красное сторно | accounting_document_position.is_red_reverse_posting';
comment on column dm_calc.account_turnover.dt_accounting_document is 'Дата документа | Дата бухдокумента | accounting_document_header.dt_accounting_document';
comment on column dm_calc.account_turnover.dt_tax_reporting is 'Дата налоговой декларации | Дата налоговой декларации | accounting_document_header.dt_tax_reporting';
comment on column dm_calc.account_turnover.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | accounting_document_header.reverse_document_fiscal_year';
comment on column dm_calc.account_turnover.dt_accounting_document_created is 'Дата-время ввода бухгалтерского документа | Дата-время ввода бухгалтерского документа | accounting_document_header.dt_accounting_document_created';
comment on column dm_calc.account_turnover.accounting_document_created_by is 'Имя пользователя | Имя пользователя | accounting_document_header.accounting_document_created_by';
comment on column dm_calc.account_turnover.transaction_code is 'Код транзакции | Код транзакции | accounting_document_header.transaction_code';
comment on column dm_calc.account_turnover.exchange_rate is 'Валютный курс | Валютный курс | accounting_document_header.exchange_rate';
comment on column dm_calc.account_turnover.reference_procedure is 'Ссылочная операция | Ссылочная операция | accounting_document_header.reference_procedure';
comment on column dm_calc.account_turnover.reference_object_key is 'Ссылочный ключ | Ссылочный ключ | accounting_document_header.reference_object_key';
comment on column dm_calc.account_turnover.reason_for_reversal is 'Причина сторно или обратной проводки | Причина сторно или обратной проводки | accounting_document_header.reason_for_reversal';
comment on column dm_calc.account_turnover.reference_key_internal_for_document_header_1 is 'Внутренний ссылочный ключ 1 к заголовку документа | Внутренний ссылочный ключ 1 к заголовку документа | accounting_document_header.reference_key_internal_for_document_header_1';
comment on column dm_calc.account_turnover.reference_key_internal_for_document_header_2 is 'Внутренний ссылочный ключ 2 к заголовку документа | Внутренний ссылочный ключ 2 к заголовку документа | accounting_document_header.reference_key_internal_for_document_header_2';
comment on column dm_calc.account_turnover.reference_key_for_line_item_1 is 'Ссылочный ключ 1 к позиции документа | Ссылочный ключ 1 к позиции документа | accounting_document_header.reference_key_for_line_item_1';
comment on column dm_calc.account_turnover.reference_key_for_line_item_2 is 'Ссылочный ключ 2 к позиции документа | Ссылочный ключ 2 к позиции документа | accounting_document_header.reference_key_for_line_item_2';
comment on column dm_calc.account_turnover.reference_key_for_line_item_3 is 'Ссылочный ключ 3 к позиции документа | Ссылочный ключ 3 к позиции документа | accounting_document_header.reference_key_for_line_item_3';
comment on column dm_calc.account_turnover.material_code is 'Номер материала | Номер материала | accounting_document_position.material_code';
comment on column dm_calc.account_turnover.cost_center_code is 'Место возникновения затрат - аналитика контроллинга | Место возникновения затрат - аналитика контроллинга | accounting_document_position.сost_сenter_code';
comment on column dm_calc.account_turnover.co_order_number is 'СО-заказ - аналитика контроллинга | СО-заказ - аналитика контроллинга | accounting_document_position.co_order_number';
comment on column dm_calc.account_turnover.wbs_element_code is 'ID элемента структурного плана проекта (СПП) | ID элемента структурного плана проекта (СПП) | accounting_document_position.wbs_element_code';
comment on column dm_calc.account_turnover.funds_center_code is 'Подразделение финансового менеджмента | Подразделение финансового менеджмента | accounting_document_position.funds_center_code';
comment on column dm_calc.account_turnover.financial_position_internal_code is 'Финансовая позиция | Финансовая позиция | accounting_document_position.financial_position_internal_code';
comment on column dm_calc.account_turnover.transaction_type_general_ledger is 'Вид операции для Главной книги | Вид операции для Главной книги | accounting_document_position.transaction_type_general_ledger';
comment on column dm_calc.account_turnover.asset_main_number is 'Основной номер основного средства | Основной номер основного средства | accounting_document_position.asset_main_number';
comment on column dm_calc.account_turnover.asset_subnumber is 'Субномер основного средства | Субномер основного средства | accounting_document_position.asset_subnumber';
comment on column dm_calc.account_turnover.asset_transaction_type is 'Вид движения основных средств | Вид движения основных средств | accounting_document_position.asset_transaction_type';
comment on column dm_calc.account_turnover.settlement_period is 'Расчетный период, в т.ч. используется как признак налогового учета | Расчетный период, в т.ч. используется как признак налогового учета | accounting_document_position.settlement_period';
comment on column dm_calc.account_turnover.counterparty_code is 'Номер контрагента | Номер контрагента | accounting_document_position.coalesce(client_code, contractor_code)';
comment on column dm_calc.account_turnover.debit_turnover_document_currency_amount is 'Оборот по дебету в валюте документа | Оборот по дебету в валюте документа | accounting_document_position_correspondence.document_currency_amount';
comment on column dm_calc.account_turnover.debit_turnover_local_currency_amount is 'Оборот по дебету в валюте организации | Оборот по дебету в валюте организации | accounting_document_position_correspondence.local_currency_amount';
comment on column dm_calc.account_turnover.debit_turnover_second_local_currency_amount is 'Оборот по дебету во второй валюте | Оборот по дебету во второй валюте | accounting_document_position_correspondence.second_local_currency_amount';
comment on column dm_calc.account_turnover.credit_turnover_document_currency_amount is 'Оборот по кредиту в валюте документа | Оборот по кредиту в валюте документа | accounting_document_position_correspondence.document_currency_amount';
comment on column dm_calc.account_turnover.credit_turnover_local_currency_amount is 'Оборот по кредиту в валюте организации | Оборот по кредиту в валюте организации | accounting_document_position_correspondence.local_currency_amount';
comment on column dm_calc.account_turnover.credit_turnover_second_local_currency_amount is 'Оборот по кредиту во второй валюте | Оборот по кредиту во второй валюте | accounting_document_position_correspondence.second_local_currency_amount';
comment on column dm_calc.account_turnover.payee_or_payer_code is 'Получатель платежа / плательщик (код) | Получатель платежа / плательщик (код) | accounting_document_position.payee_or_payer_code';
comment on column dm_calc.account_turnover.is_red_reverse_debit_posting is 'Индикатор: красное сторно дебета | Индикатор: красное сторно дебета | accounting_document_position_correspondence.is_red_reverse_debit_posting';
comment on column dm_calc.account_turnover.is_red_reverse_credit_posting is 'Индикатор: красное сторно кредита | Индикатор: красное сторно кредита | accounting_document_position_correspondence.is_red_reverse_credit_posting';
comment on column dm_calc.account_turnover.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | accounting_document_position_correspondence.document_currency_amount';
comment on column dm_calc.account_turnover.local_currency_amount is 'Сумма во внутренней валюте | Сумма во внутренней валюте | accounting_document_position_correspondence.local_currency_amount';
comment on column dm_calc.account_turnover.second_local_currency_amount is 'Сумма во второй ВнутрВалюте | Сумма во второй ВнутрВалюте | accounting_document_position_correspondence.second_local_currency_amount';