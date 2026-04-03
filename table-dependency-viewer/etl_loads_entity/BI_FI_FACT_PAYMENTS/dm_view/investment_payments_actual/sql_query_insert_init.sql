CREATE OR REPLACE VIEW dm_view.investment_payments_actual
AS SELECT investment_payments_actual.expense_or_payment_source_type_code,
		investment_payments_actual.accounting_document_unit_balance_code,
		investment_payments_actual.accounting_document_fiscal_year,
		investment_payments_actual.accounting_document_code,
		investment_payments_actual.accounting_document_position_code,
		investment_payments_actual.accounting_document_type_code,
		investment_payments_actual.payment_document_unit_balance_code,
		investment_payments_actual.payment_document_fiscal_year,
		investment_payments_actual.payment_document_code,
		investment_payments_actual.dt_posting,
		investment_payments_actual.payment_request_position_code,
		investment_payments_actual.purchase_document_code,
		investment_payments_actual.purchase_document_position_code,
		investment_payments_actual.reservation_document_code,
		investment_payments_actual.reservation_document_position_code,
		investment_payments_actual.reservation_document_reference_code,
		investment_payments_actual.cost_element_code,
		investment_payments_actual.correspondence_general_ledger_account_code,
		investment_payments_actual.material_code,
		investment_payments_actual.creditor_code,
		investment_payments_actual.contract_code,
		investment_payments_actual.external_contract_number,
		investment_payments_actual.wbs_element_internal_code,
		investment_payments_actual.wbs_element_external_code,
		investment_payments_actual.investment_project_internal_code,
		investment_payments_actual.investment_project_external_code,
		investment_payments_actual.controlling_order_code,
		investment_payments_actual.document_exchange_to_usd_rate,
		investment_payments_actual.vat_code,
		investment_payments_actual.vat_rate,
		investment_payments_actual.document_currency_amount,
		investment_payments_actual.document_currency_code,
		investment_payments_actual.vat_payment_document_currency_amount,
		investment_payments_actual.exclude_vat_payment_document_currency_amount,		
		investment_payments_actual.document_usd_currency_amount,
		investment_payments_actual.vat_payment_usd_currency_amount,
		investment_payments_actual.exclude_vat_payment_usd_currency_amount,
		investment_payments_actual.capitalization_code,
		investment_payments_actual.capitalization_percent,
		investment_payments_actual.budget_group_code,
		investment_payments_actual.reverse_document_code,
		investment_payments_actual.reverse_document_fiscal_year,
		investment_payments_actual.dt_posting_reverse_document,
		investment_payments_actual.plant_code,
		investment_payments_actual.is_agent_payment,
		investment_payments_actual.currency_iso_code,
		investment_payments_actual.cost_element_name,
		investment_payments_actual.correspondence_general_ledger_account_name,
		investment_payments_actual.material_name,
		investment_payments_actual.creditor_name,
		investment_payments_actual.wbs_element_name,
		investment_payments_actual.investment_project_name,
		investment_payments_actual.controlling_order_name,
		investment_payments_actual.plant_name,		
        investment_payments_actual.investment_activity_external_code,
        investment_payments_actual.investment_budget_section_code,
        investment_payments_actual.investment_budget_section_name,
        investment_payments_actual.investment_budget_subsection_code,
        investment_payments_actual.investment_budget_subsection_name,
        investment_payments_actual.division_code,
        investment_payments_actual.division_name,
		investment_payments_actual.investment_budget_section_actual_code,
		investment_payments_actual.investment_budget_section_actual_name,
		investment_payments_actual.investment_budget_subsection_actual_code,
		investment_payments_actual.investment_budget_subsection_actual_name,
		investment_payments_actual.wbs_element_unit_balance_code,
		investment_payments_actual.budget_group_name,
		investment_payments_actual.counterparty_truncated_code,
		investment_payments_actual.counterparty_search_name,
		investment_payments_actual.unit_balance_name,
		investment_payments_actual.investment_program_code,
		investment_payments_actual.investment_program_name,
		investment_payments_actual.dttm_inserted,
		investment_payments_actual.dttm_updated,
		investment_payments_actual.job_name,
		investment_payments_actual.deleted_flag
		FROM dm.investment_payments_actual
   		where deleted_flag = false;
   	
   	
comment on VIEW dm_view.investment_payments_actual is 'Факт платежей БИЗ ERP';
comment on column dm_view.investment_payments_actual.expense_or_payment_source_type_code is 'Тип затрат/платежей | Тип затрат/платежей | settings_and_parameters_sap.parameter_code';
comment on column dm_view.investment_payments_actual.accounting_document_unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.unit_balance_code';
comment on column dm_view.investment_payments_actual.accounting_document_fiscal_year is 'Финансовый год | Финансовый год бухдокумента | accounting_documents.fiscal_year';
comment on column dm_view.investment_payments_actual.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_documents.accounting_document_code';
comment on column dm_view.investment_payments_actual.accounting_document_position_code is 'Текст к позиции | Текст к позиции бухдокумента | accounting_documents.position_line_item_text';
comment on column dm_view.investment_payments_actual.accounting_document_type_code is 'Вид документа | Вид бухдокумента | accounting_documents.accounting_document_type';
comment on column dm_view.investment_payments_actual.payment_document_unit_balance_code is 'БЕ документа платежа | БЕ документа платежа | accounting_documents_header.unit_balance_code';
comment on column dm_view.investment_payments_actual.payment_document_code is 'Номер документа платежа | Номер документа платежа | accounting_documents_header.accounting_document_code';
comment on column dm_view.investment_payments_actual.payment_document_fiscal_year is 'Год документа платежа | Год документа платежа | accounting_documents_header.fiscal_year';
comment on column dm_view.investment_payments_actual.dt_posting is 'Дата проводки в документе | Дата проводки бухдокумента | accounting_documents.dt_posting';
comment on column dm_view.investment_payments_actual.payment_request_position_code is '№ позиции TAP_MM | № позиции TAP_MM | ';
comment on column dm_view.investment_payments_actual.purchase_document_code is 'Номер документа закупки | Номер документа закупки | accounting_documents.purchase_document_code';
comment on column dm_view.investment_payments_actual.purchase_document_position_code is 'Позиция документа закупки | Позиция документа закупки | accounting_documents.purchase_document_position_line_item_code';
comment on column dm_view.investment_payments_actual.reservation_document_code is '№ резервирования | № резервирования | ';
comment on column dm_view.investment_payments_actual.reservation_document_position_code is 'Позиция резервирования | Позиция резервирования | ';
comment on column dm_view.investment_payments_actual.reservation_document_reference_code is 'Резервирование затрат | Резервирование затрат | ';
comment on column dm_view.investment_payments_actual.cost_element_code is 'Основной счет главной книги, код | Код основного счета главной книги | accounting_documents.general_ledger_account_code';
comment on column dm_view.investment_payments_actual.correspondence_general_ledger_account_code is 'Корреспондирующий счет главной книги | Код корреспондирующего счета главной книги | dm_calc.account_turnover.correspondence_general_ledger_account_code';
comment on column dm_view.investment_payments_actual.material_code is 'Номер материала | Номер материала | accounting_documents.material_code';
comment on column dm_view.investment_payments_actual.creditor_code is 'Номер счета поставщика или кредитора | Номер поставщика или кредитора | accounting_documents.supplier_code';
comment on column dm_view.investment_payments_actual.contract_code is 'Номер договора | Договор, в рамках которого возникла задолженность (номер) | Алгоритм по 3 полям';
comment on column dm_view.investment_payments_actual.external_contract_number is 'Номер контракта на закупку у поставщика | Номер контракта на закупку у поставщика | purchase_contract_position.external_contract_number';
comment on column dm_view.investment_payments_actual.wbs_element_internal_code is 'ID элемента структурного плана проекта (СПП) | ID элемента структурного плана проекта (СПП) | Алгоритм по 2 полям';
comment on column dm_view.investment_payments_actual.wbs_element_external_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | wbs_element_master_data_detail.wbs_element_number';
comment on column dm_view.investment_payments_actual.investment_project_internal_code is 'Проект внутренний (код) | Проект внутренний (код) | wbs_element_master_data_detail.investment_project_code';
comment on column dm_view.investment_payments_actual.investment_project_external_code is 'Проект внешний (код) | Проект внешний (код) | investment_project.wbs_element_number';
comment on column dm_view.investment_payments_actual.controlling_order_code is 'Заказ CO | Заказ CO | ';
comment on column dm_view.investment_payments_actual.document_exchange_to_usd_rate is 'Курс ВД к долларам | Курс ВД к долларам | ';
comment on column dm_view.investment_payments_actual.vat_code is 'Код налога с оборота | Код НДС | accounting_documents.tax_code';
comment on column dm_view.investment_payments_actual.vat_rate is 'Ставка НДС | Ставка НДС | ';
comment on column dm_view.investment_payments_actual.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | accounting_documents.document_currency_amount';
comment on column dm_view.investment_payments_actual.document_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_documents.local_currency_code';
comment on column dm_view.investment_payments_actual.vat_payment_document_currency_amount is 'Сумма НДС платежа в ВД | Сумма НДС платежа в ВД | ';
comment on column dm_view.investment_payments_actual.exclude_vat_payment_document_currency_amount is 'Сумма платежа без НДС в ВД | Сумма платежа без НДС в ВД | ';
comment on column dm_view.investment_payments_actual.document_usd_currency_amount is 'Сумма в приведённых долларах | Сумма в приведённых долларах';
comment on column dm_view.investment_payments_actual.vat_payment_usd_currency_amount is 'Сумма НДС платежа в приведёных долларах | Сумма НДС платежа в приведёных долларах | ';
comment on column dm_view.investment_payments_actual.exclude_vat_payment_usd_currency_amount is 'Сумма платежа без НДС в приведёных долларах | Сумма платежа без НДС в приведёных долларах';
comment on column dm_view.investment_payments_actual.capitalization_code is 'Оприходование (код) | Оприходование (код) | wbs_element_master_data_detail.posting_reason_code';
comment on column dm_view.investment_payments_actual.capitalization_percent is 'Процент оприходования | Процент оприходования | ';
comment on column dm_view.investment_payments_actual.budget_group_code is 'Статья бюджета (код) | Статья бюджета (код) | map_cost_element_to_budget.budget_group_code';
comment on column dm_view.investment_payments_actual.reverse_document_code is 'Документ сторно платежа № | Документ сторно платежа № | ';
comment on column dm_view.investment_payments_actual.reverse_document_fiscal_year is 'Документ сторно платежа год | Документ сторно платежа год | ';
comment on column dm_view.investment_payments_actual.dt_posting_reverse_document is 'Дата проводки сторно платежа | Дата проводки сторно платежа | ';
comment on column dm_view.investment_payments_actual.plant_code is 'Завод | Код филиала, к которому относится задолженность | accounting_documents.plant_code';
comment on column dm_view.investment_payments_actual.is_agent_payment is 'Агентский платёж | Агентский платёж | ';
comment on column dm_view.investment_payments_actual.currency_iso_code is 'Валюта-оригинал | Валюта-оригинал | general_ledger_account_chart.currency_iso_code';
comment on column dm_view.investment_payments_actual.cost_element_name is 'Вид затрат (наименование) | Вид затрат (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm_view.investment_payments_actual.correspondence_general_ledger_account_name is 'Корр счёт (наименование) | Корр счёт (наименование) | general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm_view.investment_payments_actual.material_name is 'Материал (наименование) | Материал (наименование) | material_texts.material_name';
comment on column dm_view.investment_payments_actual.creditor_name is 'Кредитор (наименование) | Кредитор (наименование) | counterparty_td.counterparty_short_name';
comment on column dm_view.investment_payments_actual.wbs_element_name is 'СПП-элемент (наименование) | СПП-элемент (наименование) | wbs_element_short_name.wbs_element_short_name';
comment on column dm_view.investment_payments_actual.investment_project_name is 'Проект (наименование) | Проект (наименование) | investment_project.wbs_element_short_name';
comment on column dm_view.investment_payments_actual.controlling_order_name is 'Заказ CO (наименование) | Заказ CO (наименование) | order_toro.order_short_name';
comment on column dm_view.investment_payments_actual.plant_name is 'Завод (наименование) | Завод (наименование) | plant_and_subsidiary.plant_short_name';
comment on column dm_view.investment_payments_actual.investment_activity_external_code is 'ИМ, внешний код | ИМ, внешний код | dict_dds.investment_project.wbs_element_number'; ---уточнить
comment on column dm_view.investment_payments_actual.investment_budget_section_code is 'Раздел ИБ, код | Раздел ИБ, код | dict_dds.investment_activity_td.investment_budget_section_code';
comment on column dm_view.investment_payments_actual.investment_budget_section_name is 'Раздел ИБ, текст | Раздел ИБ, текст | dict_dds.investment_budget_section_texts.investment_budget_section_full_name';
comment on column dm_view.investment_payments_actual.investment_budget_subsection_code is 'Подраздел ИБ, код | Подраздел ИБ, код | dict_dds.investment_activity_td.investment_budget_subsection_code';
comment on column dm_view.investment_payments_actual.investment_budget_subsection_name is 'Подраздел ИБ, текст | Подраздел ИБ, текст | dict_dds.investment_budget_subsection_texts.investment_budget_subsection_full_name';
comment on column dm_view.investment_payments_actual.division_code is 'Дивизион, код | Дивизион, код | dict_dds.investment_activity_td.division_code';
comment on column dm_view.investment_payments_actual.division_name is 'Дивизион, текст | Дивизион, текст | dict_dds.division_texts.division_full_name';
comment on column dm_view.investment_payments_actual.investment_budget_section_actual_code is 'Раздел ИБ фактический, код | Раздел ИБ фактический, код | dict_dds.investment_activity_td.investment_budget_section_code';
comment on column dm_view.investment_payments_actual.investment_budget_section_actual_name is 'Раздел ИБ фактический, название | Раздел ИБ фактический, название | dict_dds.investment_budget_section_texts.investment_budget_section_full_name';
comment on column dm_view.investment_payments_actual.investment_budget_subsection_actual_code is 'Подраздел ИБ фактический, код | Подраздел ИБ фактический, код | dict_dds.investment_activity_td.investment_budget_subsection_code';
comment on column dm_view.investment_payments_actual.investment_budget_subsection_actual_name is 'Подраздел ИБ фактический, название| Подраздел ИБ фактический, название | dict_dds.investment_budget_subsection_texts.investment_budget_subsection_full_name';
comment on column dm_view.investment_payments_actual.wbs_element_unit_balance_code is 'БЕ СПП-элемента (код)| БЕ СПП-элемента (код) | dict_dds.wbs_element_master_data_detail.wbs_element_unit_balance_code';
comment on column dm_view.investment_payments_actual.budget_group_name is 'Код статьи бюджета, название| Код статьи бюджета, название | dict_dds.budget_group_texts.budget_group_name';
comment on column dm_view.investment_payments_actual.counterparty_truncated_code is 'Контрагент (код для фильтрации)| Контрагент (код для фильтрации) | dict_dds.counterparty.counterparty_truncated_code';
comment on column dm_view.investment_payments_actual.counterparty_search_name is 'Контрагент (код+имя для фильтрации)| Контрагент (код+имя для фильтрации) | dict_dds.counterparty.counterparty_search_name';
comment on column dm_view.investment_payments_actual.unit_balance_name is 'БЕ название| БЕ название | dict_dds.unit_balance.unit_balance_name';
comment on column dm_view.investment_payments_actual.investment_program_code is 'Инвестиционная программа, код | Инвестиционная программа, код | dict_dds.investment_activity_td.investment_program_code';
comment on column dm_view.investment_payments_actual.investment_program_name is 'Инвестиционная программа, наименование | Инвестиционная программа, наименование | dict_dds.investment_program_texts.investment_program_full_name';