drop table if exists dm.investment_payments_actual cascade;

create table dm.investment_payments_actual (
		expense_or_payment_source_type_code varchar(10) not null,
		accounting_document_unit_balance_code varchar(4) not null,
		accounting_document_fiscal_year numeric(4,0) not null,
		accounting_document_code varchar(10) not null,
		accounting_document_position_code numeric(3,0) not null,
		accounting_document_type_code varchar(2) null,
		payment_document_unit_balance_code varchar(4) null,
		payment_document_fiscal_year numeric(4,0)  null,
		payment_document_code varchar(10) null,
		dt_posting date not null,
		payment_request_position_code varchar(5) null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		reservation_document_code varchar(10) null,
		reservation_document_position_code varchar(3) null,
		reservation_document_reference_code varchar(16) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		external_contract_number varchar(60) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		investment_project_external_code varchar(72) null,
		controlling_order_code varchar(12) null,
		document_exchange_to_usd_rate numeric(20,5) default 0,
		vat_code varchar(2) null,
		vat_rate numeric(4,2) default 0,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,
		vat_payment_document_currency_amount numeric(20,2) default 0,
		exclude_vat_payment_document_currency_amount numeric(20,2) default 0,		
		document_usd_currency_amount numeric(20,2) default 0,
		vat_payment_usd_currency_amount numeric(20,2) default 0,
		exclude_vat_payment_usd_currency_amount numeric(20,2) default 0,
		capitalization_code varchar(6) null,
		capitalization_percent numeric(5,2) default 0,
		budget_group_code varchar(20) null,
		reverse_document_code varchar(10) null,
		reverse_document_fiscal_year numeric(4) null,
		dt_posting_reverse_document date null,
		plant_code varchar(4) null,
		is_agent_payment bool null,
		currency_iso_code varchar(5) null,
		cost_element_name varchar(50) null,
		correspondence_general_ledger_account_name varchar(50) null,
		material_name varchar(120) null,
		creditor_name varchar(35) null,
		wbs_element_name varchar(120) null,
		investment_project_name varchar(120) null,
		controlling_order_name varchar(40) null,
		plant_name varchar(30) null,
		investment_activity_external_code varchar(24) null,
		investment_budget_section_code varchar(2) null,
	    investment_budget_section_name varchar(40) null,
	    investment_budget_subsection_code varchar(3) null,
	    investment_budget_subsection_name varchar(40) null,
		division_code varchar(2) null,
	    division_name varchar(40) null,
		investment_budget_section_actual_code varchar(2) null,
		investment_budget_section_actual_name varchar(40) null,
		investment_budget_subsection_actual_code varchar(3) null,
		investment_budget_subsection_actual_name varchar(40) null,
		investment_program_code varchar(5) null,
		investment_program_name varchar(60) null,		
		wbs_element_unit_balance_code varchar(12) null,
		budget_group_name varchar(40) null,
		counterparty_truncated_code varchar(10) null,
		counterparty_search_name varchar(311) null,
		unit_balance_name varchar(75) null,
	    dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	    dttm_updated	timestamp	NOT NULL DEFAULT now(),
	    job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,	
	    deleted_flag	bool	NOT NULL DEFAULT false
		)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=3
)
distributed by (accounting_document_unit_balance_code, accounting_document_fiscal_year, accounting_document_code);

comment on table dm.investment_payments_actual is 'Факт платежей БИЗ ERP';
comment on column dm.investment_payments_actual.expense_or_payment_source_type_code is 'Тип записи | Тип записи | settings_and_parameters_sap.parameter_code';
comment on column dm.investment_payments_actual.accounting_document_unit_balance_code is 'Документ FI (БЕ) | Документ FI (БЕ) | accounting_documents.unit_balance_code';
comment on column dm.investment_payments_actual.accounting_document_fiscal_year is 'Документ FI (Год) | Документ FI (Год) | accounting_documents.fiscal_year';
comment on column dm.investment_payments_actual.accounting_document_code is 'Документ FI (№) | Документ FI (№) | accounting_documents.accounting_document_code';
comment on column dm.investment_payments_actual.accounting_document_position_code is 'Документ FI (Позиция) | Документ FI (Позиция) | accounting_documents.position_line_item_text';
comment on column dm.investment_payments_actual.accounting_document_type_code is 'Вид документа | Вид документа | accounting_documents.accounting_document_type';
comment on column dm.investment_payments_actual.payment_document_unit_balance_code is 'Платёж (БЕ) | Платёж (БЕ) | accounting_documents_header.unit_balance_code';
comment on column dm.investment_payments_actual.payment_document_code is 'Платёж (№) | Платёж (№) | accounting_documents_header.accounting_document_code';
comment on column dm.investment_payments_actual.payment_document_fiscal_year is 'Платёж (Год) | Платёж (Год) | accounting_documents_header.fiscal_year';
comment on column dm.investment_payments_actual.dt_posting is 'Дата затрат/платежей | Дата затрат/платежей | accounting_documents.dt_posting';
comment on column dm.investment_payments_actual.payment_request_position_code is '№ позиции TAP_MM | № позиции TAP_MM | ';
comment on column dm.investment_payments_actual.purchase_document_code is '№ заказа ММ | № заказа ММ | accounting_documents.purchase_document_code';
comment on column dm.investment_payments_actual.purchase_document_position_code is 'Позиция заказа ММ | Позиция заказа ММ | accounting_documents.purchase_document_position_line_item_code';
comment on column dm.investment_payments_actual.reservation_document_code is '№ резервирования | № резервирования | ';
comment on column dm.investment_payments_actual.reservation_document_position_code is 'Позиция резервирования | Позиция резервирования | ';
comment on column dm.investment_payments_actual.reservation_document_reference_code is 'Ссылочное резервирование | Ссылочное резервирование | ';
comment on column dm.investment_payments_actual.cost_element_code is 'Вид затрат | Вид затрат | accounting_documents.general_ledger_account_code';
comment on column dm.investment_payments_actual.correspondence_general_ledger_account_code is 'Корр счёт | Корр счёт | dm_calc.account_turnover.correspondence_general_ledger_account_code';
comment on column dm.investment_payments_actual.material_code is 'Материал | Материал | accounting_documents.material_code';
comment on column dm.investment_payments_actual.creditor_code is 'Кредитор | Кредитор | accounting_documents.supplier_code';
comment on column dm.investment_payments_actual.contract_code is '№ контракта (системный) | № контракта (системный) | Алгоритм по 3 полям';
comment on column dm.investment_payments_actual.external_contract_number is '№ контракта (бумажный) | № контракта (бумажный) | purchase_contract_position.external_contract_number';
comment on column dm.investment_payments_actual.wbs_element_internal_code is 'СПП-элемент (внутр) | СПП-элемент (внутр) | Алгоритм по 2 полям';
comment on column dm.investment_payments_actual.wbs_element_external_code is 'СПП-элемент (внешн) | СПП-элемент (внешн) | wbs_element_master_data_detail.wbs_element_number';
comment on column dm.investment_payments_actual.investment_project_internal_code is 'Проект (внутр) | Проект (внутр) | wbs_element_master_data_detail.investment_project_code';
comment on column dm.investment_payments_actual.investment_project_external_code is 'Проект (внешн) | Проект (внешн) | investment_project.wbs_element_number';
comment on column dm.investment_payments_actual.controlling_order_code is 'Заказ CO | Заказ CO | ';
comment on column dm.investment_payments_actual.document_exchange_to_usd_rate is 'Курс ВД к долларам | Курс ВД к долларам | ';
comment on column dm.investment_payments_actual.vat_code is 'Код НДС | Код НДС | accounting_documents.tax_code';
comment on column dm.investment_payments_actual.vat_rate is 'Ставка НДС | Ставка НДС | ';
comment on column dm.investment_payments_actual.document_currency_amount is 'Сумма в ВД | Сумма в ВД | accounting_documents.document_currency_amount';
comment on column dm.investment_payments_actual.document_currency_code is 'Валюта документа | Валюта документа | accounting_documents.local_currency_code';
comment on column dm.investment_payments_actual.vat_payment_document_currency_amount is 'Сумма НДС платежа в ВД | Сумма НДС платежа в ВД | ';
comment on column dm.investment_payments_actual.exclude_vat_payment_document_currency_amount is 'Сумма платежа без НДС в ВД | Сумма платежа без НДС в ВД | ';
comment on column dm.investment_payments_actual.document_usd_currency_amount is 'Сумма в приведённых долларах | Сумма в приведённых долларах';
comment on column dm.investment_payments_actual.vat_payment_usd_currency_amount is 'Сумма НДС платежа в приведёных долларах | Сумма НДС платежа в приведёных долларах | ';
comment on column dm.investment_payments_actual.exclude_vat_payment_usd_currency_amount is 'Сумма платежа без НДС в приведёных долларах | Сумма платежа без НДС в приведёных долларах';
comment on column dm.investment_payments_actual.capitalization_code is 'Код оприходования | Код оприходования | wbs_element_master_data_detail.posting_reason_code';
comment on column dm.investment_payments_actual.capitalization_percent is 'Процент оприходования | Процент оприходования | ';
comment on column dm.investment_payments_actual.budget_group_code is 'Код статьи бюджета | Код статьи бюджета | map_cost_element_to_budget.budget_group_code';
comment on column dm.investment_payments_actual.reverse_document_code is 'Документ сторно платежа № | Документ сторно платежа № | ';
comment on column dm.investment_payments_actual.reverse_document_fiscal_year is 'Документ сторно платежа год | Документ сторно платежа год | ';
comment on column dm.investment_payments_actual.dt_posting_reverse_document is 'Дата проводки сторно платежа | Дата проводки сторно платежа | ';
comment on column dm.investment_payments_actual.plant_code is 'Завод | Завод | accounting_documents.plant_code';
comment on column dm.investment_payments_actual.is_agent_payment is 'Агентский платёж | Агентский платёж | ';
comment on column dm.investment_payments_actual.currency_iso_code is 'Валюта-оригинал | Валюта-оригинал | general_ledger_account_chart.currency_iso_code';
comment on column dm.investment_payments_actual.cost_element_name is 'Вид затрат (наименование) | Вид затрат (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm.investment_payments_actual.correspondence_general_ledger_account_name is 'Корр счёт (наименование) | Корр счёт (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm.investment_payments_actual.material_name is 'Материал (наименование) | Материал (наименование) | material_texts.material_name';
comment on column dm.investment_payments_actual.creditor_name is 'Кредитор (наименование) | Кредитор (наименование) | counterparty_td.counterparty_short_name';
comment on column dm.investment_payments_actual.wbs_element_name is 'СПП-элемент (наименование) | СПП-элемент (наименование) | wbs_element_master_data_detail.wbs_element_short_name';
comment on column dm.investment_payments_actual.investment_project_name is 'Проект (наименование) | Проект (наименование) | investment_project.wbs_element_short_name';
comment on column dm.investment_payments_actual.controlling_order_name is 'Заказ CO (наименование) | Заказ CO (наименование) | order_toro.order_short_name';
comment on column dm.investment_payments_actual.plant_name is 'Завод (наименование) | Завод (наименование) | plant_and_subsidiary.plant_short_name';
comment on column dm.investment_payments_actual.investment_activity_external_code is 'ИМ, внешний код | ИМ, внешний код | dict_dds.investment_project.wbs_element_number'; ---уточнить
comment on column dm.investment_payments_actual.investment_budget_section_code is 'Раздел ИБ, код | Раздел ИБ, код | dict_dds.investment_activity_td.investment_budget_section_code';
comment on column dm.investment_payments_actual.investment_budget_section_name is 'Раздел ИБ, текст | Раздел ИБ, текст | dict_dds.investment_budget_section_texts.investment_budget_section_full_name';
comment on column dm.investment_payments_actual.investment_budget_subsection_code is 'Подраздел ИБ, код | Подраздел ИБ, код | dict_dds.investment_activity_td.investment_budget_subsection_code';
comment on column dm.investment_payments_actual.investment_budget_subsection_name is 'Подраздел ИБ, текст | Подраздел ИБ, текст | dict_dds.investment_budget_subsection_texts.investment_budget_subsection_full_name';
comment on column dm.investment_payments_actual.division_code is 'Дивизион, код | Дивизион, код | dict_dds.investment_activity_td.division_code';
comment on column dm.investment_payments_actual.division_name is 'Дивизион, текст | Дивизион, текст | dict_dds.division_texts.division_full_name';
comment on column dm.investment_payments_actual.investment_budget_section_actual_code is 'Раздел ИБ фактический, код | Раздел ИБ фактический, код | dict_dds.investment_activity_td.investment_budget_section_code';
comment on column dm.investment_payments_actual.investment_budget_section_actual_name is 'Раздел ИБ фактический, название | Раздел ИБ фактический, название | dict_dds.investment_budget_section_texts.investment_budget_section_full_name';
comment on column dm.investment_payments_actual.investment_budget_subsection_actual_code is 'Подраздел ИБ фактический, код | Подраздел ИБ фактический, код | dict_dds.investment_activity_td.investment_budget_subsection_code';
comment on column dm.investment_payments_actual.investment_budget_subsection_actual_name is 'Подраздел ИБ фактический, название| Подраздел ИБ фактический, название | dict_dds.investment_budget_subsection_texts.investment_budget_subsection_full_name';
comment on column dm.investment_payments_actual.investment_program_code is 'Инвестиционная программа, код | Инвестиционная программа, код | dict_dds.investment_activity_td.investment_program_code';
comment on column dm.investment_payments_actual.investment_program_name is 'Инвестиционная программа, наименование | Инвестиционная программа, наименование | dict_dds.investment_program_texts.investment_program_full_name';
comment on column dm.investment_payments_actual.wbs_element_unit_balance_code is 'БЕ СПП-элемента (код)| БЕ СПП-элемента (код) | dict_dds.wbs_element_master_data_detail.wbs_element_unit_balance_code';
comment on column dm.investment_payments_actual.budget_group_name is 'Код статьи бюджета, название| Код статьи бюджета, название | dict_dds.budget_group_texts.budget_group_name';
comment on column dm.investment_payments_actual.counterparty_truncated_code is 'Контрагент (код для фильтрации)| Контрагент (код для фильтрации) | dict_dds.counterparty.counterparty_truncated_code';
comment on column dm.investment_payments_actual.counterparty_search_name is 'Контрагент (код+имя для фильтрации)| Контрагент (код+имя для фильтрации) | dict_dds.counterparty.counterparty_search_name';
comment on column dm.investment_payments_actual.unit_balance_name is 'БЕ название| БЕ название | dict_dds.unit_balance.unit_balance_name';