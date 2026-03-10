drop table if exists dm.investment_expenses_actual cascade;

create table dm.investment_expenses_actual (
		expense_or_payment_source_type_code varchar(10) not null,
		accounting_document_unit_balance_code varchar(4)  null, -- убрано not null для того чтобы свести с 02 
		unit_balance_name varchar(75), 
		accounting_document_fiscal_year numeric(4,0) null, -- убрано not null для того чтобы свести с 02 
		accounting_document_code varchar(10)  null, -- убрано not null для того чтобы свести с 02 
		reference_document_for_reporting_code  varchar(28)  null,
		accounting_document_position_code numeric(3,0)  null, -- убрано not null для того чтобы свести с 03
		accounting_document_type_code varchar(2) null,
		controlling_area_code varchar(4)  null,
		controlling_document_code varchar(10)  null,
		controlling_document_position_code varchar(3)  null,
		reference_operation_type_code varchar(5)  null,
		dt_posting date not null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
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
		document_exchange_to_usd_rate numeric(15,5) default 0,
		vat_code varchar(2) null,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,		
		document_usd_currency_amount numeric(20,2) default 0,
		second_local_currency_amount numeric(20,2) default 0,
		second_local_currency_code varchar(5) null,	
		capitalization_code varchar(6) null,
		capitalization_percent numeric(5,2) default 0,
		budget_group_code varchar(20) null,
		budget_group_name varchar(100) null,
		plant_code varchar(4) null,
		currency_iso_code varchar(5) null,
		cost_element_name varchar(50) null,
		correspondence_general_ledger_account_name varchar(50) null,
		material_name varchar(120) null,
		creditor_name varchar(35) null,
		counterparty_truncated_code varchar(10) null,
		counterparty_search_name varchar(311) null,
		wbs_element_name varchar(120) null,
		investment_project_name varchar(120) null,
		controlling_order_name varchar(40) null,
		plant_name varchar(30) null,
		investment_activity_external_code varchar(24) null,
		investment_budget_section_code varchar(2) null,
	    investment_budget_section_name varchar(40) null,
	    investment_budget_subsection_code varchar(3) null,
	    investment_budget_subsection_name varchar(40) null,  --investment_budget_subsection_actual_name
		division_code varchar(2) null,
	    division_name varchar(40) null,
		investment_budget_section_actual_code varchar(2) null,
		investment_budget_section_actual_name varchar(40) null,
		investment_budget_subsection_actual_code varchar(3) null,
		investment_budget_subsection_actual_name varchar(40) null, 
		investment_program_code varchar(5) null,
		investment_program_name varchar(60) null,
		wbs_element_unit_balance_code varchar(4) null,
	    dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	    dttm_updated	timestamp	NOT NULL DEFAULT now(),
	    job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,	
	    deleted_flag	bool	NOT NULL DEFAULT false)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=3
)
distributed by (reference_document_for_reporting_code );





comment on table dm.investment_expenses_actual is 'Факт затрат БИЗ ERP';
comment on column dm.investment_expenses_actual.expense_or_payment_source_type_code is 'Тип записи | Тип записи | settings_and_parameters.sap.parameter_code';
comment on column dm.investment_expenses_actual.accounting_document_unit_balance_code is 'Документ FI (БЕ) | Документ FI (БЕ) | accounting_documents.unit_balance_code';
comment on column dm.investment_expenses_actual.unit_balance_name is 'БЕ название | БЕ название | dict_dds.unit_balance.unit_balance_name';
comment on column dm.investment_expenses_actual.accounting_document_fiscal_year is 'Документ FI (Год) | Документ FI (Год) | accounting_documents.fiscal_year';
comment on column dm.investment_expenses_actual.accounting_document_code is 'Документ FI (№) | Документ FI (№) | accounting_documents.accounting_document_code';
comment on column dm.investment_expenses_actual.reference_document_for_reporting_code is 'Документ расшировка |Документ расшировка | accounting_documents.reference_document_for_reporting_code';
comment on column dm.investment_expenses_actual.accounting_document_position_code is 'Документ FI (Позиция) | Документ FI (Позиция) | accounting_documents.position_line_item_text';
comment on column dm.investment_expenses_actual.accounting_document_type_code is 'Вид документа | Вид документа | accounting_documents.accounting_document_type';
comment on column dm.investment_expenses_actual.controlling_area_code is 'Контроллинговая единица | Контроллинговая единица | ';
comment on column dm.investment_expenses_actual.controlling_document_code is 'Номер документа контроллинга | Номер документа контроллинга | ';
comment on column dm.investment_expenses_actual.controlling_document_position_code is 'Строка проводки документа контроллинга | Строка проводки документа контроллинга | ';
comment on column dm.investment_expenses_actual.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | ';
comment on column dm.investment_expenses_actual.dt_posting is 'Дата затрат/платежей | Дата затрат/платежей | accounting_documents.dt_posting';
comment on column dm.investment_expenses_actual.purchase_document_code is 'Номер документа закупки | Номер документа закупки | accounting_documents.purchase_document_code';
comment on column dm.investment_expenses_actual.purchase_document_position_code is 'Позиция документа закупки | Позиция документа закупки | accounting_documents.purchase_document_position_line_item_code';
comment on column dm.investment_expenses_actual.cost_element_code is 'Вид затрат| Вид затрат | accounting_documents.general_ledger_account_code';
comment on column dm.investment_expenses_actual.correspondence_general_ledger_account_code is 'Корр счёт | Корр счёт | dm_calc.account_turnover.correspondence_general_ledger_account_code';
comment on column dm.investment_expenses_actual.material_code is 'Материал | Материал | accounting_documents.material_code';
comment on column dm.investment_expenses_actual.creditor_code is 'Кредитор | Кредитор | accounting_documents.supplier_code';
comment on column dm.investment_expenses_actual.contract_code is '№ контракта (системный) | № контракта (системный) | Алгоритм по 3 полям';
comment on column dm.investment_expenses_actual.external_contract_number is '№ контракта (бумажный) | № контракта (бумажный) | purchase_contract_position.external_contract_number';
comment on column dm.investment_expenses_actual.wbs_element_internal_code is 'СПП-элемент (внутр) | СПП-элемент (внутр) | Алгоритм по 2 полям';
comment on column dm.investment_expenses_actual.wbs_element_external_code is 'СПП-элемент (внешн) | СПП-элемент (внешн) | wbs_element_master_data_detail.wbs_element_number';
comment on column dm.investment_expenses_actual.investment_project_internal_code is 'Проект (внутр) | Проект (внутр) | wbs_element_master_data_detail.investment_project_code';
comment on column dm.investment_expenses_actual.investment_project_external_code is 'Проект (внешн) | Проект (внешн)) | investment_project.wbs_element_number';
comment on column dm.investment_expenses_actual.controlling_order_code is 'Заказ CO | Заказ CO | ';
comment on column dm.investment_expenses_actual.document_exchange_to_usd_rate is 'Курс ВД к долларам | Курс ВД к долларам | ';
comment on column dm.investment_expenses_actual.vat_code is 'Код НДС | Код НДС | accounting_documents.tax_code';
comment on column dm.investment_expenses_actual.document_currency_amount is 'Сумма в ВД | Сумма в ВД | accounting_documents.document_currency_amount';
comment on column dm.investment_expenses_actual.document_currency_code is 'Валюта документа | Валюта документа | accounting_documents.document_currency_code';
comment on column dm.investment_expenses_actual.document_usd_currency_amount is 'Сумма в приведённых долларах | Сумма в приведённых долларах';
comment on column dm.investment_expenses_actual.second_local_currency_amount is 'Сумма в ВB2 |Сумма во второй внутренней валюте | second_local_currency_amount';
comment on column dm.investment_expenses_actual.second_local_currency_code is 'Вторая внутренняя валюта | Вторая внутренняя валюта | accounting_documents.document_currency_code';
comment on column dm.investment_expenses_actual.capitalization_code is 'Код оприходования | Код оприходования | wbs_element_master_data_detail.posting_reason_code';
comment on column dm.investment_expenses_actual.capitalization_percent is 'Процент оприходования | Процент оприходования | ';
comment on column dm.investment_expenses_actual.budget_group_code is 'Код статьи бюджета | Код статьи бюджета | map_cost_element_to_budget.budget_group_code';
comment on column dm.investment_expenses_actual.budget_group_name is 'Наименование статьи бюджета | Наименование статьи бюджета | dict_dds.budget_group_texts.budget_group_name';
comment on column dm.investment_expenses_actual.plant_code is 'Завод | Завод  | accounting_documents.plant_code';
comment on column dm.investment_expenses_actual.currency_iso_code is 'Валюта-оригинал | Валюта-оригинал | general_ledger_account_chart.currency_iso_code';
comment on column dm.investment_expenses_actual.cost_element_name is 'Вид затрат (наименование) | Вид затрат (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm.investment_expenses_actual.correspondence_general_ledger_account_name is 'Корр счёт (наименование) | Корр счёт (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm.investment_expenses_actual.material_name is 'Материал (наименование) | Материал (наименование) | material_texts.material_name';
comment on column dm.investment_expenses_actual.creditor_name is 'Кредитор (наименование) | Кредитор (наименование) | counterparty.counterparty_short_name';
comment on column dm.investment_expenses_actual.counterparty_truncated_code is 'Контрагент (код для фильтрации) | Контрагент (код для фильтрации) | counterparty.counterparty_truncated_code';
comment on column dm.investment_expenses_actual.counterparty_search_name is 'Контрагент (код+имя для фильтрации) | Контрагент (код+имя для фильтрации) | counterparty.counterparty_search_name';
comment on column dm.investment_expenses_actual.wbs_element_name is 'СПП-элемент (наименование) | СПП-элемент (наименование) | wbs_element_short_name.wbs_element_short_name';
comment on column dm.investment_expenses_actual.investment_project_name is 'Проект (наименование) | Проект (наименование) | investment_project.wbs_element_short_name';
comment on column dm.investment_expenses_actual.controlling_order_name is 'Заказ CO (наименование) | Заказ CO (наименование) | order_toro.order_short_name';
comment on column dm.investment_expenses_actual.plant_name is 'Завод (наименование) | Завод (наименование) | plant_and_subsidiary.plant_short_name';
comment on column dm.investment_expenses_actual.investment_activity_external_code is 'ИМ, внешний код | ИМ, внешний код | dict_dds.investment_project.wbs_element_number'; ---уточнить
comment on column dm.investment_expenses_actual.investment_budget_section_code is 'Раздел ИБ, код | Раздел ИБ, код | dict_dds.investment_activity_td.investment_budget_section_code';
comment on column dm.investment_expenses_actual.investment_budget_section_name is 'Раздел ИБ, текст | Раздел ИБ, текст | dict_dds.investment_budget_section_texts.investment_budget_section_full_name';
comment on column dm.investment_expenses_actual.investment_budget_subsection_code is 'Подраздел ИБ, код | Подраздел ИБ, код | dict_dds.investment_activity_td.investment_budget_subsection_code';
comment on column dm.investment_expenses_actual.investment_budget_subsection_name is 'Подраздел ИБ, текст | Подраздел ИБ, текст | dict_dds.investment_budget_subsection_texts.investment_budget_subsection_full_name';
comment on column dm.investment_expenses_actual.investment_program_code is 'Инвестиционная программа, код | Инвестиционная программа, код | dict_dds.investment_activity_td.investment_program_code';
comment on column dm.investment_expenses_actual.investment_program_name is 'Инвестиционная программа, наименование | Инвестиционная программа, наименование | dict_dds.investment_program_texts.investment_program_full_name';
comment on column dm.investment_expenses_actual.division_code is 'Дивизион, код | Дивизион, код | dict_dds.investment_activity_td.division_code';
comment on column dm.investment_expenses_actual.division_name is 'Дивизион, текст | Дивизион, текст | dict_dds.division_texts.division_full_name';
comment on column dm.investment_expenses_actual.wbs_element_unit_balance_code is 'БЕ СПП-элемента (код)| БЕ СПП-элемента (код) | алгоритм по нескольким полям';