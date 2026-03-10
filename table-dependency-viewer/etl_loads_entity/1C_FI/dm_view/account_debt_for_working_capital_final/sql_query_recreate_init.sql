drop view if exists dm_view.account_debt_for_working_capital_final cascade;

create or replace view dm_view.account_debt_for_working_capital_final as
select 
	concat(t.unit_balance_code, t.fiscal_year, t.accounting_document_code, t.position_line_item, t.debt_subposition_number) as debt_row_identifier_code,
	null as posting_uid_code_1c,
	t.dt,
	t.is_second_friday,
	t.unit_balance_code, 
	t.fiscal_year, 
	t.accounting_document_code,	
	t.dt_debt,
	t.dt_overdue,
	t.dt_clearing,
	t.contract_number, 
	t.counterparty_code,
	t.debit_or_credit, 
	t.account_type, 
	t.general_ledger_account_code, 
	t.debt_balance_document_currency_amount, 
	t.debt_balance_local_currency_amount, 
	t.debt_balance_second_local_currency_amount, 
	t.debt_balance_with_revaluation_diff_second_currency_amount, 
	t.debt_balance_position_usd_amount,
	t.document_currency_code, 
	t.local_currency_code, 
	t.second_local_currency_code, 
	t.accounting_document_type,
	t.accounting_document_type_name,
	t.position_line_item, 
	t.reverse_document_code, 
	t.reference_document_number, 
	t.accounting_document_status_code, 
	t.clearing_document_code, 
	t.tax_code, 
	t.position_line_item_text, 
	t.special_general_ledger_indicator,
	t.dt_baseline_due_date_calculation, 
	t.assignment_number, 
	t.dt_accounting_document, 
	t.plant_code, 
	t.plant_name,
	t.general_ledger_account_full_name,
	t.unit_balance_name, 
	t.counterparty_full_name, 
	t.external_contract_number,
	t.dt_external_contract,	
	t.contract_trader_code::text,
	t.contract_trader_name,
	t.terms_of_payment_code,
	t.terms_of_payment_name, 
	t.responsibility_center_code, 
	t.responsibility_center_name, 
	t.budget_subtype_code, 
	t.contract_supervisor_employee_number, 
	t.contract_supervisor_name, 
	t.purchase_or_sales_group_code,
	t.purchase_or_sales_group_name, 
	t.funds_center_code, 
	t.funds_center_name, 
	t.debt_subposition_number,
	t.debt_subposition_local_currency_amount,
	t.debt_subposition_document_currency_amount,
	t.debt_subposition_second_local_currency_amount,
	t.is_debt_daily_calculated,
	t.country_code,
	t.counterparty_hfm_code,
	t.counterparty_mdm_code,
	t.is_related_party_tco,
	t.is_group_company_affiliated,
	t.is_related_party_rsbo,
	t.is_bankrupt,
	t.is_lawsuit_exist,
	t.is_fns_restriction_list_exist,
	t.document_currency_amount,
	t.local_currency_amount,
	t.second_local_currency_amount,
	t.counterparty_tin_code,
	t.reverse_document_fiscal_year,
	t.reason_for_reversal,
	t.debt_balance_subposition_document_currency_amount,
	t.debt_balance_subposition_local_currency_amount,
	t.debt_balance_subposition_second_local_currency_amount,
	t.debt_balance_subposition_usd_amount,
	t.debt_balance_subposition_document_currency_to_usd_amount,
	t.debt_balance_subpos_no_revaluation_local_currency_amount,
	t.debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	t.debt_balance_subposition_no_revaluation_usd_amount,
	t.debt_balance_contract_usd_amount,
	t.debt_balance_contract_document_currency_to_usd_amount,
	t.debt_balance_contract_no_revaluation_usd_amount,
	t.paydox_credit_limit_usd_currency_amount,
	t.invoice_document_code,
	t.fiscal_year_of_relevant_invoice,
	t.position_number_of_relevant_invoice,
	t.final_position_line_item::text,
	t.final_fiscal_year,
 	t.final_accounting_document_code,
 	t.exchange_diff_local_currency_amount,
 	t.debt_balance_exchange_diff_local_currency_amount,
 	t.debt_balance_subpos_exch_diff_local_currency_amount,
 	t.exchange_diff_second_local_currency_amount,
 	t.debt_balance_exchange_diff_second_local_currency_amount, 
 	t.debt_balance_subpos_exch_diff_second_local_curr_amount, 
	t.counterparty_truncated_code,
    t.counterparty_search_name,
    t.responsibility_center_level1_code,
    t.responsibility_center_level1_name,
    t.financial_position_code,
    t.financial_position_name,
    t.usd_amount,
    t.realization_invoice_code, 
    t.realization_document_code,
    t.country_of_end_user_code,
    t.country_of_end_user_name,
    t.region_of_end_user_code,
    t.region_of_end_user_name,
    t.sales_invoice_code,
    t.material_shape_code,
    t.material_shape_name,
    t.receivable_claim_number,
    t.receivable_claim_paydox_url,
    t.dt_receivable_claim,
    t.reference_operation_type_code,
    t.reference_object_key_code,
    t.material_code,
    t.bank_as_counterparty_code,
	t.almer_bank_code,
	t.bank_as_counterparty_name,
	t.paydox_document_url,
	t.contract_list_with_paydox_url,
	t.external_contract_source_table_name,
	t.unpaid_payment_request_code,
	t.purchase_order_code,
	t.purchase_specification_compound_number,
	t.dt_edm_counterparty_electonic_signature,
	t.accounting_document_created_by,
	t.vat_rate
from 
   dm_view.account_debt_for_working_capital as t
  
   union all
  
   select 
    concat(t2.unit_balance_code, t2.posting_uid_code_1c) as debt_row_identifier_code,
    t2.posting_uid_code_1c,
	t2.dt,
	t2.is_second_friday, 
	t2.unit_balance_code, 
	t2.fiscal_year, 
	t2.accounting_document_code,	
	t2.dt_debt,
	t2.dt_overdue,
	t2.dt_clearing,
	t2.contract_number, 
	t2.counterparty_code,
	t2.debit_or_credit, 
	t2.account_type, 
	t2.general_ledger_account_code, 
	t2.debt_balance_document_currency_amount,
	t2.debt_balance_local_currency_amount, 
	t2.debt_balance_second_local_currency_amount, 
	t2.debt_balance_with_revaluation_diff_second_currency_amount, 
	t2.debt_balance_position_usd_amount,
	t2.document_currency_code, 
	t2.local_currency_code, 
	t2.second_local_currency_code, 
	t2.accounting_document_type,
	t2.accounting_document_type_name,
	t2.position_line_item, 
	t2.reverse_document_code, 
	t2.reference_document_number, 
	t2.accounting_document_status_code, 
	t2.clearing_document_code, 
	t2.tax_code, 
	t2.position_line_item_text, 
	t2.special_general_ledger_indicator,
	t2.dt_baseline_due_date_calculation, 
	t2.assignment_number, 
	t2.dt_accounting_document, 
	t2.plant_code, 
	t2.plant_name,
	t2.general_ledger_account_full_name,
	t2.unit_balance_name, 
	t2.counterparty_full_name, 
	t2.external_contract_number,
	t2.dt_external_contract,	
	t2.contract_trader_code,
	t2.contract_trader_name,
	t2.terms_of_payment_code,
	t2.terms_of_payment_name, 
	t2.responsibility_center_code, 
	t2.responsibility_center_name, 
	t2.budget_subtype_code, 
	t2.contract_supervisor_employee_number, 
	t2.contract_supervisor_name, 
	t2.purchase_or_sales_group_code,
	t2.purchase_or_sales_group_name, 
	t2.funds_center_code, 
	t2.funds_center_name, 
	t2.debt_subposition_number,
	t2.debt_subposition_local_currency_amount,
	t2.debt_subposition_document_currency_amount,
	t2.debt_subposition_second_local_currency_amount,
	t2.is_debt_daily_calculated,
	t2.country_code,
	t2.counterparty_hfm_code,
	t2.counterparty_mdm_code,
	t2.is_related_party_tco,
	t2.is_group_company_affiliated,
	t2.is_related_party_rsbo,
	t2.is_bankrupt,
	t2.is_lawsuit_exist,
	t2.is_fns_restriction_list_exist,
	t2.document_currency_amount,
	t2.local_currency_amount,
	t2.second_local_currency_amount,
	t2.counterparty_tin_code,
	t2.reverse_document_fiscal_year,
	t2.reason_for_reversal,
	t2.debt_balance_subposition_document_currency_amount,
	t2.debt_balance_subposition_local_currency_amount,
	t2.debt_balance_subposition_second_local_currency_amount,
	t2.debt_balance_subposition_usd_amount,
	t2.debt_balance_subposition_document_currency_to_usd_amount,
	t2.debt_balance_subpos_no_revaluation_local_currency_amount,
	t2.debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	t2.debt_balance_subposition_no_revaluation_usd_amount,
	t2.debt_balance_contract_usd_amount,
	t2.debt_balance_contract_document_currency_to_usd_amount,
	t2.debt_balance_contract_no_revaluation_usd_amount,
	t2.paydox_credit_limit_usd_currency_amount,
	t2.invoice_document_code,
	t2.fiscal_year_of_relevant_invoice,
	t2.position_number_of_relevant_invoice,
	t2.final_position_line_item,
	t2.final_fiscal_year,
 	t2.final_accounting_document_code,
 	t2.exchange_diff_local_currency_amount,
 	t2.debt_balance_exchange_diff_local_currency_amount,
 	t2.debt_balance_subpos_exch_diff_local_currency_amount,
 	t2.exchange_diff_second_local_currency_amount,
 	t2.debt_balance_exchange_diff_second_local_currency_amount, 
 	t2.debt_balance_subpos_exch_diff_second_local_curr_amount,
	t2.counterparty_truncated_code,
    t2.counterparty_search_name,
    t2.responsibility_center_level1_code,
    t2.responsibility_center_level1_name,
    t2.financial_position_code,
    t2.financial_position_name,
    t2.usd_amount,
    t2.realization_invoice_code, 
    t2.realization_document_code,
    t2.country_of_end_user_code,
    t2.country_of_end_user_name,
    t2.region_of_end_user_code,
    t2.region_of_end_user_name,
    t2.sales_invoice_code,
    t2.material_shape_code,
    t2.material_shape_name,
    t2.receivable_claim_number,
    t2.receivable_claim_paydox_url,
    t2.dt_receivable_claim,
    t2.reference_operation_type_code,
    t2.reference_object_key_code,
    t2.material_code,
    t2.bank_as_counterparty_code, 
	t2.almer_bank_code, 
	t2.bank_as_counterparty_name,
	t2.paydox_document_url,
	t2.contract_list_with_paydox_url,
	t2.external_contract_source_table_name,
	t2.unpaid_payment_request_code,
	t2.purchase_order_code,
	t2.purchase_specification_compound_number,
	t2.dt_edm_counterparty_electonic_signature,
	t2.accounting_document_created_by,
	t2.vat_rate
from 
   dm_view.account_debt_for_working_capital_1c as t2;
  
comment on view dm_view.account_debt_for_working_capital_final is 'Оборотный капитал - ДЗ/КЗ_объединенный';
comment on column dm_view.account_debt_for_working_capital_final.debt_row_identifier_code is 'Код идентификации | Код идентификации | ';
comment on column dm_view.account_debt_for_working_capital_final.posting_uid_code_1c is 'ID документа из 1С | ID документа из 1С | ';
comment on column dm_view.account_debt_for_working_capital_final.dt is 'Дата | На какую дату указан остаток | dm_calc.account_debt.dt';
comment on column dm_view.account_debt_for_working_capital_final.is_second_friday is 'Флаг:вторая пятница месяца | Флаг:вторая пятница месяца | dm_calc.account_debt.is_second_friday';
comment on column dm_view.account_debt_for_working_capital_final.unit_balance_code is 'Балансовая единица | Балансовая единица | dm_calc.account_debt.unit_balance_code';
comment on column dm_view.account_debt_for_working_capital_final.fiscal_year is 'Финансовый год | Финансовый год | dm_calc.account_debt.fiscal_year';
comment on column dm_view.account_debt_for_working_capital_final.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | dm_calc.account_debt.accounting_document_code';
comment on column dm_view.account_debt_for_working_capital_final.dt_debt is 'Дата возникновения задолженности | Дата возникновения задолженности | dm_calc.account_debt.dt_posting';
comment on column dm_view.account_debt_for_working_capital_final.dt_overdue is 'Дата, когда задолженность станет просроченной | Дата, когда задолженность станет просроченной | ods.map_planned_repayment_dates_keys.dt_outstanding';
comment on column dm_view.account_debt_for_working_capital_final.dt_clearing is 'Дата выравнивания | Дата выравнивания | dm_calc.account_debt.dt_clearing';
comment on column dm_view.account_debt_for_working_capital_final.contract_number is 'Номер договора | Номер договора | dm_calc.account_debt.contract_number';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_code is 'Контрагент (код) | Код кредитора, задолженность перед которым отражает позиция | dm_calc.accounting_debt.counterparty_code';
comment on column dm_view.account_debt_for_working_capital_final.debit_or_credit is 'Индикатор дебета/кредита | Индикатор дебета/кредита | dm_calc.account_debt.debit_or_credit';
comment on column dm_view.account_debt_for_working_capital_final.account_type is 'Вид счета | Вид счета | dm_calc.account_debt.account_type';
comment on column dm_view.account_debt_for_working_capital_final.general_ledger_account_code is 'Основной счет главной книги | Основной счет главной книги | dm_calc.account_debt.general_ledger_account_code';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_document_currency_amount is 'Остаток задолженности в валюте документа | Остаток задолженности в валюте документа | dm_calc.account_debt.document_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_local_currency_amount is 'Остаток задолженности в валюте организации | Остаток задолженности в валюте организации | dm_calc.account_debt.local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_second_local_currency_amount is 'Остаток задолженности во второй валюте | Остаток задолженности во второй валюте | dm_calc.account_debt.second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_with_revaluation_diff_second_currency_amount is 'Остаток задолженности, во второй валюте, с учётом последней переоценки | Остаток задолженности, во второй валюте, с учётом последней переоценки | dm_calc.account_debt.second_local_currency_amount + valuation_difference_second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_position_usd_amount is 'Остаток ДЗ/КЗ по всей позиции в USD | Остаток ДЗ/КЗ по всей позиции в USD | dm_calc.account_debt.debt_balance_usd_amount';
comment on column dm_view.account_debt_for_working_capital_final.document_currency_code is 'Код валюты документа | Код валюты документа | dm_calc.account_debt.document_currency_code';
comment on column dm_view.account_debt_for_working_capital_final.local_currency_code is 'Код внутренней валюты | Код внутренней валюты | dm_calc.account_debt.local_currency_code';
comment on column dm_view.account_debt_for_working_capital_final.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | dm_calc.account_debt.second_local_currency_code';
comment on column dm_view.account_debt_for_working_capital_final.accounting_document_type is 'Вид документа | Вид документа | dm_calc.account_debt.accounting_document_type';
comment on column dm_view.account_debt_for_working_capital_final.accounting_document_type_name is 'Вид документа, наименование | Вид документа, наименование | dm_calc.account_debt.accounting_document_type_name';
comment on column dm_view.account_debt_for_working_capital_final.position_line_item is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | dm_calc.account_debt.position_line_item';
comment on column dm_view.account_debt_for_working_capital_final.reverse_document_code is '№ документа сторно | № документа сторно | dm_calc.account_debt.reverse_document_code';
comment on column dm_view.account_debt_for_working_capital_final.reference_document_number is 'Ссылочный номер документа | Ссылочный номер документа | dm_calc.account_debt.reference_document_number';
comment on column dm_view.account_debt_for_working_capital_final.accounting_document_status_code is 'Статус документа | Статус документа | dm_calc.account_debt.accounting_document_status_code';
comment on column dm_view.account_debt_for_working_capital_final.clearing_document_code is 'Номер документа выравнивания | Номер документа выравнивания | dm_calc.account_debt.clearing_document_code';
comment on column dm_view.account_debt_for_working_capital_final.tax_code is 'Код налога с оборота | Код налога с оборота | dm_calc.account_debt.tax_code';
comment on column dm_view.account_debt_for_working_capital_final.position_line_item_text is 'Текст к позиции | Текст к позиции | dm_calc.account_debt.position_line_item_text';
comment on column dm_view.account_debt_for_working_capital_final.special_general_ledger_indicator is 'Код Особой главной книги | Код Особой главной книги | dm_calc.account_debt.special_general_ledger_indicator';
comment on column dm_view.account_debt_for_working_capital_final.dt_baseline_due_date_calculation is 'Базовая дата для расчета срока оплаты | Базовая дата для расчета срока оплаты | dm_calc.account_debt.dt_baseline_due_date_calculation';
comment on column dm_view.account_debt_for_working_capital_final.assignment_number is 'Номер присвоения | Номер присвоения | dm_calc.account_debt.assignment_number';
comment on column dm_view.account_debt_for_working_capital_final.dt_accounting_document is 'Дата документа | Дата документа | dm_calc.account_debt.dt_accounting_document';
comment on column dm_view.account_debt_for_working_capital_final.plant_code is 'Завод | Завод | Алгоритм по 3 полям';
comment on column dm_view.account_debt_for_working_capital_final.plant_name is 'Название филиала | Название филиала | dict_dds.plant_and_subsidiary.plant_full_name';
comment on column dm_view.account_debt_for_working_capital_final.general_ledger_account_full_name is 'Подробный текст к основному счету на русском | Подробный текст к основному счету на русском | dict_dds.general_ledger_account_chart.general_ledger_account_full_name_rus';
comment on column dm_view.account_debt_for_working_capital_final.unit_balance_name is 'Название БЕ  | Название БЕ  | unit_balance.unit_balance_name';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_full_name is 'Наименование контрагента | Наименование контрагента | dict_dds.counterparty.counterparty_full_name';
comment on column dm_view.account_debt_for_working_capital_final.external_contract_number is 'Внешний номер договора | Внешний номер договора | dm_calc.accounting_document_contracts.external_contract_number';
comment on column dm_view.account_debt_for_working_capital_final.dt_external_contract is 'Дата внешнего договора | Дата внешнего договора | dm_calc.accounting_document_contracts.dt_external_contract';
comment on column dm_view.account_debt_for_working_capital_final.contract_trader_code is 'Табельный номер трейдера договора | Табельный номер трейдера договора | dm_calc.accounting_document_contracts.contract_trader_code';
comment on column dm_view.account_debt_for_working_capital_final.contract_trader_name is 'ФИО трейдера договора | ФИО трейдера договора | dm_calc.accounting_document_contracts.contract_trader_name';
comment on column dm_view.account_debt_for_working_capital_final.terms_of_payment_code is 'Код условий платежа | Код условий платежа | dm_calc.account_debt.terms_of_payment_code';
comment on column dm_view.account_debt_for_working_capital_final.terms_of_payment_name is 'Наименование условия платежа | Наименование условия платежа | condition_payment_comment."comment"';
comment on column dm_view.account_debt_for_working_capital_final.responsibility_center_code is 'Центр ответственности, код | Центр ответственности, код | dm_calc.accounting_document_contracts.responsibility_center_code';
comment on column dm_view.account_debt_for_working_capital_final.responsibility_center_name is 'Центр ответственности, наименование | Центр ответственности, наименование | dict_dds.funds_center_master_data.funds_center_short_name_rus';
comment on column dm_view.account_debt_for_working_capital_final.budget_subtype_code is 'Подвид бюджета | Подвид бюджета | dict_dds.counterparty.budget_subtype_code';
comment on column dm_view.account_debt_for_working_capital_final.contract_supervisor_employee_number is 'Куратор договора, таб № | Куратор договора, таб № | dm_calc.accounting_document_contracts.contract_supervisor_employee_number';
comment on column dm_view.account_debt_for_working_capital_final.contract_supervisor_name is 'Куратор договора, ФИО | Куратор договора, ФИО | dm_calc.accounting_document_contracts.contract_supervisor_name';
comment on column dm_view.account_debt_for_working_capital_final.purchase_or_sales_group_code is 'Группа закупок/сбыта, Код | dm_calc.accounting_document_contracts.purchase_or_sales_group_code';
comment on column dm_view.account_debt_for_working_capital_final.purchase_or_sales_group_name is 'Группа закупок/сбыта, Наименование | dm_calc.accounting_document_contracts.purchase_or_sales_group_name';
comment on column dm_view.account_debt_for_working_capital_final.funds_center_code is 'Подразделение финансового менеджмента, код | Подразделение финансового менеджмента, код | ods.map_planned_repayment_dates_keys.funds_center_code';
comment on column dm_view.account_debt_for_working_capital_final.funds_center_name is 'Подразделение финансового менеджмента, название | Подразделение финансового менеджмента, название | dict_dds.funds_center_master_data.funds_center_name';
comment on column dm_view.account_debt_for_working_capital_final.debt_subposition_number is 'Номер подпозиции задолженности | Номер подпозиции задолженности | ods.map_planned_repayment_dates_keys.debt_subposition_number';
comment on column dm_view.account_debt_for_working_capital_final.debt_subposition_local_currency_amount is 'Сумма задолженности подпозиции в местной валюте | Сумма задолженности подпозиции в местной валюте | ods.map_planned_repayment_dates_keys.debt_subposition_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_subposition_document_currency_amount is 'Сумма задолженности подпозиции в валюте документа | Сумма задолженности подпозиции в валюте документа | ods.map_planned_repayment_dates_keys.debt_subposition_document_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_subposition_second_local_currency_amount is 'Сумма задолженности подпозиции во второй местной валюте | Сумма задолженности подпозиции во второй местной валюте | ods.map_planned_repayment_dates_keys.debt_subposition_second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.is_debt_daily_calculated is 'Признак текущего остатка | Признак текущего остатка | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.country_code is 'Страна регистрации контрагента | Страна регистрации контрагента | dict_dds.address.country_code';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_hfm_code is 'Код HFM | Код HFM | dict_dds.counterparty.counterparty_hfm_code';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_mdm_code is 'Код MDM | Код MDM | dict_dds.counterparty.counterparty_mdm_code';
comment on column dm_view.account_debt_for_working_capital_final.is_related_party_tco is 'Связанность по ТЦО | Связанность по ТЦО | dict_dds.counterparty.is_related_party_tco';
comment on column dm_view.account_debt_for_working_capital_final.is_group_company_affiliated is 'Входит в ОК | Входит в ОК | dict_dds.counterparty.is_group_company_affiliated';
comment on column dm_view.account_debt_for_working_capital_final.is_related_party_rsbo is 'Связанность по РСБО | Связанность по РСБО | dict_dds.counterparty.is_related_party_rsbo';
comment on column dm_view.account_debt_for_working_capital_final.is_bankrupt is 'Статус контрагента по банкротству | Статус контрагента по банкротству | dict_dds.counterparty.is_bankrupt';
comment on column dm_view.account_debt_for_working_capital_final.is_lawsuit_exist is 'Наличие у контрагента судебных исков | Наличие у контрагента судебных исков | dict_dds.counterparty.is_lawsuit_exist';
comment on column dm_view.account_debt_for_working_capital_final.is_fns_restriction_list_exist is 'Контрагент входит в негативные списки ФНС | Контрагент входит в негативные списки ФНС | dict_dds.counterparty.is_fns_restriction_list_exist';
comment on column dm_view.account_debt_for_working_capital_final.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | dm_calc.account_debt.document_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.local_currency_amount is 'Сумма во внутренней валюте | Сумма во внутренней валюте | dm_calc.account_debt.local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.second_local_currency_amount is 'Сумма во второй ВнутрВалюте | Сумма во второй ВнутрВалюте | dm_calc.account_debt.second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_tin_code is 'Идентификационный налоговый номер РФ (код) | Идентификационный налоговый номер РФ (код) | dict_dds.counterparty.counterparty_tin_code';
comment on column dm_view.account_debt_for_working_capital_final.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | dm_calc.account_debt.reverse_document_fiscal_year';
comment on column dm_view.account_debt_for_working_capital_final.reason_for_reversal is 'Причина сторно или обратной проводки | Причина сторно или обратной проводки | dm_calc.account_debt.reason_for_reversal';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subposition_document_currency_amount is 'Остаток КЗ по данной позиции, в валюте документа | Остаток КЗ по данной позиции, в валюте документа | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subposition_local_currency_amount is 'Остаток КЗ по данной позиции, в валюте БЕ | Остаток КЗ по данной позиции, в валюте БЕ | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subposition_second_local_currency_amount is 'Остаток КЗ по данной позиции, во второй валюте | Остаток КЗ по данной позиции, во второй валюте | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subposition_usd_amount is 'Остаток КЗ по данной позиции, приведенный к USD | Остаток КЗ по данной позиции, приведенный к USD | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subposition_document_currency_to_usd_amount is 'Остаток задолженности в долларах | Остаток задолженности в долларах | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subpos_no_revaluation_local_currency_amount is 'Остаток ДЗ/КЗ по данной подпозиции в валюте БЕ | Остаток ДЗ/КЗ по данной подпозиции в валюте БЕ | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subpos_no_revaluation_sec_local_curr_amount is 'Остаток ДЗ/КЗ по данной подпозиции в валюте концерна | Остаток ДЗ/КЗ по данной подпозиции в валюте концерна | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subposition_no_revaluation_usd_amount is 'Остаток ДЗ/КЗ по данной подпозиции в USD | Остаток ДЗ/КЗ по данной подпозиции в USD | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.paydox_credit_limit_usd_currency_amount is 'Суммарное значение КЛ | Суммарное значение КЛ | Алгоритм';
comment on column dm_view.account_debt_for_working_capital_final.invoice_document_code is 'Ссылочный инвойс (№) | Ссылочный инвойс (№) | dm_calc.account_debt.invoice_document_code';
comment on column dm_view.account_debt_for_working_capital_final.fiscal_year_of_relevant_invoice is 'Ссылочный инвойс (Год) | Ссылочный инвойс (Год)  | dm_calc.account_debt.fiscal_year_of_relevant_invoice';
comment on column dm_view.account_debt_for_working_capital_final.position_number_of_relevant_invoice is 'Ссылочный инвойс (Позиция) | Ссылочный инвойс (Позиция) | dm_calc.account_debt.position_number_of_relevant_invoice';
comment on column dm_view.account_debt_for_working_capital_final.final_position_line_item is 'Позиция документа задолженности | Позиция документа задолженности  | coalesce (position_number_of_relevant_invoice,position_line_item)';
comment on column dm_view.account_debt_for_working_capital_final.final_fiscal_year is 'Год документа задолженности | Год документа задолженности | coalesce (fiscal_year_of_relevant_invoice, fiscal_year)';
comment on column dm_view.account_debt_for_working_capital_final.final_accounting_document_code is 'Номер документа задолженности | Номер документа задолженности  | coalesce (invoice_document_code, accounting_document_code)';
comment on column dm_view.account_debt_for_working_capital_final.exchange_diff_local_currency_amount is 'ВВ Курсовая разница позиции| ВВ Курсовая разница позиции | dm_calc.account_debt.local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_exchange_diff_local_currency_amount is 'ВВ Курсовая разница остатка позиции | ВВ Курсовая разница остатка позиции  | dm_calc.account_debt.local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subpos_exch_diff_local_currency_amount is 'ВВ Курсовая разница остатка подпозиции | ВВ Курсовая разница остатка подпозиции  | dm_calc.account_debt.local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.exchange_diff_second_local_currency_amount is 'ВВ2 Курсовая разница позиции | ВВ2 Курсовая разница позиции | dm_calc.account_debt.second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_exchange_diff_second_local_currency_amount is 'ВВ2 Курсовая разница остатка позиции | ВВ2 Курсовая разница остатка позиции | dm_calc.account_debt.second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_subpos_exch_diff_second_local_curr_amount is 'ВВ2 Курсовая разница остатка подпозиции | ВВ2 Курсовая разница остатка подпозиции| dm_calc.account_debt.second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_truncated_code is 'Контрагент (код, без лидирующих нулей) | Контрагент (код, без лидирующих нулей) | dict_dds.counterparty.counterparty_truncated_code';
comment on column dm_view.account_debt_for_working_capital_final.counterparty_search_name is 'Название контрагента (для поиска) | Название контрагента (для поиска) |dict_dds.counterparty.counterparty_search_name';
comment on column dm_view.account_debt_for_working_capital_final.responsibility_center_level1_code is 'Центр ответственности верхнеуровневый (код) | Центр ответственности верхнеуровневый (код)  | dm_calc.accounting_document_contracts.responsibility_center_level1_code';
comment on column dm_view.account_debt_for_working_capital_final.responsibility_center_level1_name is 'Центр ответственности верхнеуровневый, название | Центр ответственности верхнеуровневый, название |dict_dds.responsibility_center_texts.responsibility_center_name';
comment on column dm_view.account_debt_for_working_capital_final.financial_position_code IS 'Расчётная ФП код | Расчётная ФП код | ods.map_planned_repayment_dates_keys.financial_position_code';
comment on column dm_view.account_debt_for_working_capital_final.financial_position_name is 'Расчётная ФП название | Расчётная ФП название |dict_dds.financial_position_master_data_texts.financial_position_full_name';
comment on column dm_view.account_debt_for_working_capital_final.usd_amount is 'Сумма задолженности в долларах | Сумма задолженности в долларах |dm_calc.accounting_receivables_and_payables.counterparty_search_name';
comment on column dm_view.account_debt_for_working_capital_final.realization_invoice_code is 'Фактура реализации | Фактура реализации | dm_calc.sales_invoice_and_invoice_realization_relation.invoice_realization_code';
comment on column dm_view.account_debt_for_working_capital_final.realization_document_code is 'Группа | Группа | dds.invoice_realization.invoice_realization_group_code';
comment on column dm_view.account_debt_for_working_capital_final.country_of_end_user_code is 'Страна конечного потребителя (код) | - | Расчетное | dm_calc.sales_invoice_and_invoice_realization_relation. country_of_destination_code';
comment on column dm_view.account_debt_for_working_capital_final.country_of_end_user_name is 'Краткое название страны на русском | - | country_texts.country_short_name';
comment on column dm_view.account_debt_for_working_capital_final.region_of_end_user_code is 'Рынок сбыта Региона сбыта (код) | Рынок сбыта Региона сбыта (код) | country.market_region1_code';
comment on column dm_view.account_debt_for_working_capital_final.region_of_end_user_name is 'Наименование региона дебитора | Наименование региона дебитора | dict_dds.market_region1_texts.market_region1_name';
comment on column dm_view.account_debt_for_working_capital_final.sales_invoice_code is 'Фактура сбыта (инвойс) | dm_calc.sales_invoice_and_invoice_realization_relation.sales_invoice_code';
comment on column dm_view.account_debt_for_working_capital_final.material_shape_code is 'Форма (код) | Форма (код) | dict_dds.material_specification.shape_code';
comment on column dm_view.account_debt_for_working_capital_final.material_shape_name is 'Название признака "Форма" | Форма  | material_shape_texts.material_shape_full_name';
comment on column dm_view.account_debt_for_working_capital_final.receivable_claim_number is 'Претензия | Претензия | dds.invoice_realization.claim_code';
comment on column dm_view.account_debt_for_working_capital_final.receivable_claim_paydox_url is 'Ссылка на документ PayDox | Ссылка на документ PayDox | dds.invoice_realization_claim.paydox_claim_url';
comment on column dm_view.account_debt_for_working_capital_final.dt_receivable_claim is 'Дата выставления претензии | Дата выставления претензии | dds.invoice_realization_claim.dt_claim';
comment on column dm_view.account_debt_for_working_capital_final.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | dm_calc.account_debt.reference_operation_type_code';
comment on column dm_view.account_debt_for_working_capital_final.reference_object_key_code is 'Ссылочный ключ | Ссылочный ключ | dm_calc.account_debt.reference_object_key';
comment on column dm_view.account_debt_for_working_capital_final.material_code is 'Номер материала | Номер материала | dm_calc.accounting_document_header.material_code';
comment on column dm_view.account_debt_for_working_capital_final.bank_as_counterparty_code is 'Банк получатель (код контрагента) | Банк получатель (код контрагента) | dm_calc.sales_invoice_and_invoice_realization_relation.sales_bank_account_code';
comment on column dm_view.account_debt_for_working_capital_final.almer_bank_code is 'Банк получатель (код almer) | Банк получатель (код almer) | dict_dds.counterparty.almer_bank_code';
comment on column dm_view.account_debt_for_working_capital_final.bank_as_counterparty_name is 'Банк получатель (наименование) | Банк получатель (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm_view.account_debt_for_working_capital_final.paydox_document_url is 'Ссылка на оригинал документа в PAYDOX | Ссылка на оригинал документа в PAYDOX | Разные таблицы';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_contract_usd_amount is 'Остаток задолженности по контракту, в USD | Остаток задолженности по контракту, в USD | Сумма debt_balance_subposition_usd_amount в рамках тех же значений dt, counterparty_code, contract_number';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_contract_document_currency_to_usd_amount is 'Остаток задолженности в долларах (пересчёт на дату отчёта) | Остаток задолженности в долларах (пересчёт на дату отчёта) | Сумма debt_balance_subposition_document_currency_to_usd_amount в рамках тех же значений dt, counterparty_code, contract_number';
comment on column dm_view.account_debt_for_working_capital_final.debt_balance_contract_no_revaluation_usd_amount is 'Остаток задолженности в долларах без переоценки | Остаток задолженности в долларах без переоценки | Сумма debt_balance_subposition_no_revaluation_usd_amount в рамках тех же значений dt, counterparty_code, contract_number';
comment on column dm_view.account_debt_for_working_capital_final.contract_list_with_paydox_url is 'Cписок контрактов  с ссылками на PAYDOX | Cписок контрактов  с ссылками на PAYDOX | on column dm_calc.accounting_document_contracts.contract_list_with_paydox_url';
comment on column dm_view.account_debt_for_working_capital_final.external_contract_source_table_name is 'Таблица-источник контракта | Таблица-источник контракта|  dm_calc.accounting_document_contracts.external_contract_source_table_name';
comment on column dm_view.account_debt_for_working_capital_final.unpaid_payment_request_code is '№ неоплаченного Требования авансового платежа (заявки на оплату) | № неоплаченного Требования авансового платежа (заявки на оплату) | dm_calc.unpaid_payment_request.unpaid_payment_request';
comment on column dm_view.account_debt_for_working_capital_final.purchase_order_code is 'Заказ на закупку| Заказ на закупку| dm_calc.accounting_document_header.purchase_order_for_reporting_code';
comment on column dm_view.account_debt_for_working_capital_final.purchase_specification_compound_number is 'Все № спецификаций | Все № спецификаций | dm_calc.accounting_document_header.purchase_specification_compound_number';
comment on column dm_view.account_debt_for_working_capital_final.dt_edm_counterparty_electonic_signature is 'Дата ЭП Подрядчика ЭДО | Дата электронной подписи подрядчика Электронного документооборота | dds.aldor_edm_document.dt_created';
comment on column dm_view.account_debt_for_working_capital_final.accounting_document_created_by is 'Имя пользователя | Логин пользователя, создавшего бух.документ | dm_calc.accounting_document_header.accounting_document_created_by';
comment on column dm_view.account_debt_for_working_capital_final.vat_rate  is 'Ставка налога | Ставка налога | dm_calc.account_debt.tax_code';
