CREATE OR REPLACE VIEW dm_view.investment_expenses_actual
AS SELECT 
		iea.expense_or_payment_source_type_code,
		iea.accounting_document_unit_balance_code,
		iea.unit_balance_name,
		iea.accounting_document_fiscal_year,
		iea.accounting_document_code,
		iea.reference_document_for_reporting_code,
		iea.accounting_document_position_code,
		iea.accounting_document_type_code,
		iea.controlling_area_code,
		iea.controlling_document_code,
		iea.controlling_document_position_code,
		iea.reference_operation_type_code,
		iea.dt_posting,
		iea.purchase_document_code,
		iea.purchase_document_position_code,
		iea.cost_element_code,
		iea.correspondence_general_ledger_account_code,
		iea.material_code,
		iea.creditor_code,
		iea.contract_code,
		iea.external_contract_number,
		iea.wbs_element_internal_code,
		iea.wbs_element_external_code,
		iea.investment_project_internal_code,
		iea.investment_project_external_code,
		iea.controlling_order_code,
		iea.document_exchange_to_usd_rate,
		iea.vat_code,
		iea.document_currency_amount,
		iea.document_currency_code,		
		iea.document_usd_currency_amount,
		iea.second_local_currency_amount,
		iea.second_local_currency_code,
		iea.capitalization_code,
		iea.capitalization_percent,
		iea.budget_group_code,
		iea.budget_group_name,
		iea.plant_code,
		iea.currency_iso_code,
		iea.cost_element_name ,
		iea.correspondence_general_ledger_account_name,
		iea.material_name,
		iea.creditor_name,
		iea.counterparty_truncated_code,
		iea.counterparty_search_name,
		iea.wbs_element_name,
		iea.investment_project_name,
		iea.controlling_order_name,
		iea.plant_name,
		iea.investment_activity_external_code,
		iea.investment_budget_section_code,
	    iea.investment_budget_section_name,
	    iea.investment_budget_subsection_code,
	    iea.investment_budget_subsection_name,
		iea.division_code,
	    iea.division_name,
		iea.investment_budget_section_actual_code,
		iea.investment_budget_section_actual_name ,
		iea.investment_budget_subsection_actual_code,
		iea.investment_budget_subsection_actual_name,
		iea.wbs_element_unit_balance_code,
		iea.investment_program_code ,
		iea.investment_program_name ,
	    iea.dttm_inserted,
	    iea.dttm_updated,
	    iea.job_name,
	    iea.deleted_flag
	FROM dm.investment_expenses_actual iea
   	where deleted_flag = false;
   		
comment on view dm_view.investment_expenses_actual is 'Факт затрат БИЗ ERP';
comment on column dm_view.investment_expenses_actual.expense_or_payment_source_type_code is 'Тип записи | Тип записи | settings_and_parameters_sap.parameter_code';
comment on column dm_view.investment_expenses_actual.accounting_document_unit_balance_code is 'Документ FI (БЕ) | Документ FI (БЕ) | accounting_documents.unit_balance_code';
comment on column dm_view.investment_expenses_actual.unit_balance_name is 'БЕ название | БЕ название | dict_dds.unit_balance.unit_balance_name';
comment on column dm_view.investment_expenses_actual.accounting_document_fiscal_year is 'Документ FI (Год) | Документ FI (Год) | accounting_documents.fiscal_year';
comment on column dm_view.investment_expenses_actual.accounting_document_code is 'Документ FI (№) | Документ FI (№) | accounting_documents.accounting_document_code';
comment on column dm_view.investment_expenses_actual.reference_document_for_reporting_code is 'Документ расшировка |Документ расшировка | accounting_documents.reference_document_for_reporting_code';
comment on column dm_view.investment_expenses_actual.accounting_document_position_code is 'Документ FI (Позиция) | Документ FI (Позиция) | accounting_documents.position_line_item_text';
comment on column dm_view.investment_expenses_actual.accounting_document_type_code is 'Вид документа | Вид документа | accounting_documents.accounting_document_type';
comment on column dm_view.investment_expenses_actual.controlling_area_code is 'Контроллинговая единица | Контроллинговая единица | ';
comment on column dm_view.investment_expenses_actual.controlling_document_code is 'Номер документа контроллинга | Номер документа контроллинга | ';
comment on column dm_view.investment_expenses_actual.controlling_document_position_code is 'Строка проводки документа контроллинга | Строка проводки документа контроллинга | ';
comment on column dm_view.investment_expenses_actual.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | ';
comment on column dm_view.investment_expenses_actual.dt_posting is 'Дата затрат/платежей | Дата затрат/платежей | accounting_documents.dt_posting';
comment on column dm_view.investment_expenses_actual.purchase_document_code is 'Номер документа закупки | Номер документа закупки | accounting_documents.purchase_document_code';
comment on column dm_view.investment_expenses_actual.purchase_document_position_code is 'Позиция документа закупки | Позиция документа закупки | accounting_documents.purchase_document_position_code';
comment on column dm_view.investment_expenses_actual.cost_element_code is 'Вид затрат| Вид затрат | accounting_documents.general_ledger_account_code';
comment on column dm_view.investment_expenses_actual.correspondence_general_ledger_account_code is 'Корр счёт | Корр счёт | dm_calc.account_turnover.correspondence_general_ledger_account_code';
comment on column dm_view.investment_expenses_actual.material_code is 'Материал | Материал | accounting_documents.material_code';
comment on column dm_view.investment_expenses_actual.creditor_code is 'Кредитор | Кредитор | accounting_documents.supplier_code';
comment on column dm_view.investment_expenses_actual.counterparty_truncated_code is 'Контрагент (код для фильтрации) | Контрагент (код для фильтрации) | counterparty.counterparty_truncated_code';
comment on column dm_view.investment_expenses_actual.counterparty_search_name is 'Контрагент (код+имя для фильтрации) | Контрагент (код+имя для фильтрации) | counterparty.counterparty_search_name';
comment on column dm_view.investment_expenses_actual.contract_code is '№ контракта (системный) | № контракта (системный) | Алгоритм по 3 полям';
comment on column dm_view.investment_expenses_actual.external_contract_number is '№ контракта (бумажный) | № контракта (бумажный) | purchase_contract_position.external_contract_number';
comment on column dm_view.investment_expenses_actual.wbs_element_internal_code is 'СПП-элемент (внутр) | СПП-элемент (внутр) | Алгоритм по 2 полям';
comment on column dm_view.investment_expenses_actual.wbs_element_external_code is 'СПП-элемент (внешн) | СПП-элемент (внешн) | wbs_element_master_data_detail.wbs_element_number';
comment on column dm_view.investment_expenses_actual.investment_project_internal_code is 'Проект (внутр) | Проект (внутр) | wbs_element_master_data_detail.investment_project_code';
comment on column dm_view.investment_expenses_actual.investment_project_external_code is 'Проект (внешн) | Проект (внешн)) | investment_project.wbs_element_number';
comment on column dm_view.investment_expenses_actual.controlling_order_code is 'Заказ CO | Заказ CO | ';
comment on column dm_view.investment_expenses_actual.document_exchange_to_usd_rate is 'Курс ВД к долларам | Курс ВД к долларам | ';
comment on column dm_view.investment_expenses_actual.vat_code is 'Код НДС | Код НДС | accounting_documents.tax_code';
comment on column dm_view.investment_expenses_actual.document_currency_amount is 'Сумма в ВД | Сумма в ВД | accounting_documents.document_currency_amount';
comment on column dm_view.investment_expenses_actual.document_currency_code is 'Валюта документа | Валюта документа | accounting_documents.document_currency_code';
comment on column dm_view.investment_expenses_actual.document_usd_currency_amount is 'Сумма в приведённых долларах | Сумма в приведённых долларах';
comment on column dm_view.investment_expenses_actual.second_local_currency_amount is 'Сумма в ВB2 |Сумма во второй внутренней валюте | second_local_currency_amount';
comment on column dm_view.investment_expenses_actual.second_local_currency_code is 'Вторая внутренняя валюта | Вторая внутренняя валюта | accounting_documents.document_currency_code';
comment on column dm_view.investment_expenses_actual.capitalization_code is 'Код оприходования | Код оприходования | wbs_element_master_data_detail.posting_reason_code';
comment on column dm_view.investment_expenses_actual.capitalization_percent is 'Процент оприходования | Процент оприходования | ';
comment on column dm_view.investment_expenses_actual.budget_group_code is 'Код статьи бюджета | Код статьи бюджета | map_cost_element_to_budget.budget_group_code';
comment on column dm_view.investment_expenses_actual.budget_group_name is 'Наименование статьи бюджета | Наименование статьи бюджета | dict_dds.budget_group_texts.budget_group_name';
comment on column dm_view.investment_expenses_actual.plant_code is 'Завод | Завод  | accounting_documents.plant_code';
comment on column dm_view.investment_expenses_actual.currency_iso_code is 'Валюта-оригинал | Валюта-оригинал | general_ledger_account_chart.currency_iso_code';
comment on column dm_view.investment_expenses_actual.cost_element_name is 'Вид затрат (наименование) | Вид затрат (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm_view.investment_expenses_actual.correspondence_general_ledger_account_name is 'Корр счёт (наименование) | Корр счёт (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm_view.investment_expenses_actual.material_name is 'Материал (наименование) | Материал (наименование) | material_texts.material_name';
comment on column dm_view.investment_expenses_actual.creditor_name is 'Кредитор (наименование) | Кредитор (наименование) | counterparty_td.counterparty_short_name';
comment on column dm_view.investment_expenses_actual.wbs_element_name is 'СПП-элемент (наименование) | СПП-элемент (наименование) | wbs_element_short_name.wbs_element_short_name';
comment on column dm_view.investment_expenses_actual.investment_project_name is 'Проект (наименование) | Проект (наименование) | investment_project.wbs_element_short_name';
comment on column dm_view.investment_expenses_actual.controlling_order_name is 'Заказ CO (наименование) | Заказ CO (наименование) | order_toro.order_short_name';
comment on column dm_view.investment_expenses_actual.plant_name is 'Завод (наименование) | Завод (наименование) | plant_and_subsidiary.plant_short_name';
comment on column dm_view.investment_expenses_actual.investment_activity_external_code is 'ИМ, внешний код | ИМ, внешний код | dict_dds.investment_project.wbs_element_number'; ---уточнить
comment on column dm_view.investment_expenses_actual.investment_budget_section_code is 'Раздел ИБ, код | Раздел ИБ, код | dict_dds.investment_activity_td.investment_budget_section_code';
comment on column dm_view.investment_expenses_actual.investment_budget_section_name is 'Раздел ИБ, текст | Раздел ИБ, текст | dict_dds.investment_budget_section_texts.investment_budget_section_full_name';
comment on column dm_view.investment_expenses_actual.investment_budget_subsection_code is 'Подраздел ИБ, код | Подраздел ИБ, код | dict_dds.investment_activity_td.investment_budget_subsection_code';
comment on column dm_view.investment_expenses_actual.investment_budget_subsection_name is 'Подраздел ИБ, текст | Подраздел ИБ, текст | dict_dds.investment_budget_subsection_texts.investment_budget_subsection_full_name';
comment on column dm_view.investment_expenses_actual.division_code is 'Дивизион, код | Дивизион, код | dict_dds.investment_activity_td.division_code';
comment on column dm_view.investment_expenses_actual.division_name is 'Дивизион, текст | Дивизион, текст | dict_dds.division_texts.division_full_name';
comment on column dm_view.investment_expenses_actual.investment_program_code is 'Инвестиционная программа, код | Инвестиционная программа, код | dict_dds.investment_activity_td.investment_program_code';
comment on column dm_view.investment_expenses_actual.investment_program_name is 'Инвестиционная программа, наименование | Инвестиционная программа, наименование | dict_dds.investment_program_texts.investment_program_full_name';
comment on column dm_view.investment_expenses_actual.wbs_element_unit_balance_code is 'БЕ СПП-элемента (код)| БЕ СПП-элемента (код) | алгоритм по нескольким полям';