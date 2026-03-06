DROP TABLE IF EXISTS dm_calc.accounting_receivables_and_payables;

CREATE TABLE IF NOT EXISTS dm_calc.accounting_receivables_and_payables
(
    unit_balance_code VARCHAR(4) NOT NULL,
    fiscal_year NUMERIC(4) NOT NULL,
    accounting_document_code VARCHAR(10) NOT NULL,
    dt_posting DATE NOT NULL,
    posting_period VARCHAR(2) NOT NULL,
    accounting_document_header_text VARCHAR(25) NULL,
    accounting_document_type VARCHAR(2) NULL,
    reverse_document_code VARCHAR(10) NULL,
    reference_document_number VARCHAR(16) NULL,
    accounting_document_status_code BPCHAR(1) NULL,
    dt_accounting_document DATE NULL,
    document_currency_code VARCHAR(5) NULL,
    local_currency_code VARCHAR(5) NULL,
    second_local_currency_code VARCHAR(5) NULL,
    reference_key_internal_for_document_header_1 VARCHAR(20) NULL,
    reference_key_internal_for_document_header_2 VARCHAR(20) NULL,
    dttm_accounting_document_created TIMESTAMP NULL,
    accounting_document_created_by VARCHAR(12) NULL,
    transaction_code VARCHAR(20) NULL,
    exchange_rate NUMERIC(9, 5) NULL,
    dt_currency_translation DATE NULL,
    dt_tax_reporting DATE NULL,
    reverse_document_fiscal_year NUMERIC(4) NULL,
    reason_for_reversal VARCHAR(2) NULL,
    reference_procedure VARCHAR(5) NULL,
    reference_object_key VARCHAR(20) NULL,
    position_line_item NUMERIC(3) NULL,
    debit_or_credit BPCHAR(1) NULL,
    general_ledger_account_code VARCHAR(10) NULL,
    tax_code VARCHAR(2) NULL,
    account_type BPCHAR(1) NULL,
    position_line_item_text VARCHAR(50) NULL,
    clearing_document_code VARCHAR(10) NULL,
    dt_clearing DATE NULL,
    invoice_document_code VARCHAR(10) NULL,
    fiscal_year_of_relevant_invoice NUMERIC(4) NULL,
    position_number_of_relevant_invoice NUMERIC(3) NULL,
    special_general_ledger_indicator BPCHAR(1) NULL,
    contract_number VARCHAR(13) NULL,
    plant_code VARCHAR(4) NULL,
    reference_key_for_line_item_1 VARCHAR(20) NULL,
    reference_key_for_line_item_2 VARCHAR(20) NULL,
    reference_key_for_line_item_3 VARCHAR(20) NULL,
    funds_center_code VARCHAR(16) NULL,
    financial_position_internal_code VARCHAR(24) NULL,
    counterparty_code VARCHAR(10) NULL,
    dt_baseline_due_date_calculation DATE NULL,
    terms_of_payment_code VARCHAR(4) NULL,
    assignment_number VARCHAR(18) NULL,
    payee_or_payer_code VARCHAR(10) NULL,
    is_red_reverse_posting BPCHAR(1) NULL,
    document_currency_amount NUMERIC(15,2) DEFAULT 0,
    usd_amount NUMERIC(15,2) DEFAULT 0,
    local_currency_amount NUMERIC(15,2) DEFAULT 0,
    second_local_currency_amount NUMERIC(15,2) DEFAULT 0,
    valuation_difference_second_local_currency_amount NUMERIC(15,2) DEFAULT 0,
    dttm_inserted TIMESTAMP NOT NULL DEFAULT NOW(),
    dttm_updated TIMESTAMP NOT NULL DEFAULT NOW(),
    job_name VARCHAR(60) NOT NULL DEFAULT 'airflow'::CHARACTER VARYING,
    deleted_flag BOOL NOT NULL DEFAULT FALSE
)
WITH (
    appendonly=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=3
)
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item)
;


COMMENT ON TABLE dm_calc.accounting_receivables_and_payables is 'Бухгалтерия, инициирующие задолженность документы';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_document_header.unit_balance_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.fiscal_year is 'Финансовый год | Финансовый год | accounting_document_header.fiscal_year';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_document_header.accounting_document_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.accounting_document_type is 'Вид документа | Вид документа | accounting_document_header.accounting_document_type';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_document_header.local_currency_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_document_header.second_local_currency_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reverse_document_code is '№ документа сторно | № документа сторно | accounting_document_header.reverse_document_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_document_header.document_currency_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_document_number is 'Ссылочный номер документа | Ссылочный номер документа | accounting_document_header.reference_document_number';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.accounting_document_status_code is 'Статус документа | Статус документа | accounting_document_header.accounting_document_status_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.clearing_document_code is 'Номер документа выравнивания | Номер документа выравнивания | accounting_document_position.clearing_document_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_clearing is 'Дата выравнивания | Дата выравнивания | accounting_document_position.dt_clearing';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | accounting_document_position.position_line_item';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.general_ledger_account_code is 'Основной счет главной книги | Основной счет главной книги | accounting_document_position.general_ledger_account_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.account_type is 'Вид счета | Вид счета | accounting_document_position.account_type';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.position_line_item_text is 'Текст к позиции | Текст к позиции бухдокумента | accounting_document_position.position_line_item_text';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.tax_code is 'Код налога с оборота | Код налога с оборота | accounting_document_position.tax_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | accounting_document_position.debit_or_credit';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.special_general_ledger_indicator is 'Код Особой главной книги | Код Особой главной книги | accounting_document_position.special_general_ledger_indicator';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.counterparty_code is 'Номер контрагента | Номер контрагента | accounting_document_position.coalesce(client_code, contractor_code)';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.contract_number is 'Номер договора | Номер договора | accounting_document_position.contract_number';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.plant_code is 'Завод | Завод | Алгоритм';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_baseline_due_date_calculation is 'Базовая дата для расчета срока оплаты | Базовая дата для расчета срока оплаты | accounting_document_position.dt_baseline_due_date_calculation';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.terms_of_payment_code is 'Код условий платежа | Код условий платежа | accounting_document_position.terms_of_payment_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.assignment_number is 'Номер присвоения | Номер присвоения | accounting_document_position.assignment_number';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_accounting_document is 'Дата документа | Дата документа | accounting_document_header.dt_accounting_document';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_posting is 'Дата проводки в документе | Дата проводки бухдокумента | accounting_document_header.dt_posting';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.posting_period is 'Месяц проводки | Месяц проводки | accounting_document_header.posting_period';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.accounting_document_header_text is 'Текст заголовка документа | Текст заголовка документа | accounting_document_header.document_header_text';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_key_internal_for_document_header_1 is 'Внутренний ссылочный ключ 1 к заголовку документа | Внутренний ссылочный ключ 1 к заголовку документа | accounting_document_header.reference_key_internal_for_document_header_1';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_key_internal_for_document_header_2 is 'Внутренний ссылочный ключ 2 к заголовку документа | Внутренний ссылочный ключ 2 к заголовку документа | accounting_document_header.reference_key_internal_for_document_header_2';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dttm_accounting_document_created is 'Дата-время ввода бухгалтерского документа | Дата-время ввода бухгалтерского документа | accounting_document_header.dttm_accounting_document_created';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_key_for_line_item_1 is 'Ссылочный ключ 1 к позиции документа | Ссылочный ключ 1 к позиции документа | accounting_document_header.reference_key_for_line_item_1';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_key_for_line_item_2 is 'Ссылочный ключ 2 к позиции документа | Ссылочный ключ 2 к позиции документа | accounting_document_header.reference_key_for_line_item_2';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_key_for_line_item_3 is 'Ссылочный ключ 3 к позиции документа | Ссылочный ключ 3 к позиции документа | accounting_document_header.reference_key_for_line_item_3';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.payee_or_payer_code is 'Получатель платежа / плательщик (код) | Получатель платежа / плательщик (код) | accounting_document_position.payee_or_payer_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.document_currency_code is 'Код валюты документа | Код валюты документа | accounting_document_header.document_currency_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_document_header.local_currency_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | accounting_document_header.second_local_currency_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.valuation_difference_second_local_currency_amount is 'Оценочная разница для второй внутренней валюты | Оценочная разница для второй внутренней валюты | accounting_document_position.valuation_difference_second_local_currency_amount';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.second_local_currency_amount is 'Сумма во второй ВнутрВалюте | Сумма во второй внутренней валюте | accounting_document_position.second_local_currency_amount';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.local_currency_amount is 'Сумма во внутренней валюте | Сумма в валюте организации | accounting_document_position.local_currency_amount';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | accounting_document_position.document_currency_amount';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.usd_amount is 'Сумма задолженности в долларах | Сумма задолженности в долларах | accounting_document_position.document_currency_amount';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.is_red_reverse_posting is 'Индикатор: красное сторно | Индикатор: красное сторно | accounting_document_position.is_red_reverse_posting';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.financial_position_internal_code is 'Финансовая позиция | Финансовая позиция | accounting_document_position.financial_position_internal_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.funds_center_code is 'Подразделение финансового менеджмента | Подразделение финансового менеджмента | accounting_document_position.funds_center_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.invoice_document_code is 'Номер счета-фактуры, к которому относится операция | Номер счета-фактуры, к которому относится операция | accounting_document_position.invoice_document_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.fiscal_year_of_relevant_invoice is 'Финансовый год соответствующего счета (при кредитовом авизо) | Финансовый год соответствующего счета (при кредитовом авизо) | accounting_document_position.fiscal_year_of_relevant_invoice';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.position_number_of_relevant_invoice is 'Позиция проводки в соответствующем счете | Позиция проводки в соответствующем счете | accounting_document_position.position_number_of_relevant_invoice';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_procedure is 'Ссылочная операция | Ссылочная операция | accounting_document_header.reference_procedure';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reference_object_key is 'Ссылочный ключ | Ссылочный ключ | accounting_document_header.reference_object_key';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reason_for_reversal is 'Причина сторно или обратной проводки | Причина сторно или обратной проводки | accounting_document_header.reason_for_reversal';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_tax_reporting is 'Дата налоговой декларации | Дата налоговой декларации | accounting_document_header.dt_tax_reporting';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | accounting_document_header.reverse_document_fiscal_year';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_accounting_document is 'Дата документа | Дата бухдокумента | accounting_document_header.dt_accounting_document';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.accounting_document_created_by is 'Имя пользователя | Имя пользователя | accounting_document_header.accounting_document_created_by';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.transaction_code is 'Код транзакции | Код транзакции | accounting_document_header.transaction_code';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.exchange_rate is 'Валютный курс | Валютный курс | accounting_document_header.exchange_rate';
COMMENT ON COLUMN dm_calc.accounting_receivables_and_payables.dt_currency_translation is 'Дата пересчета валюты документа в валюту БЕ | Дата пересчета валюты документа в валюту БЕ | accounting_document_header.dt_currency_translation';
