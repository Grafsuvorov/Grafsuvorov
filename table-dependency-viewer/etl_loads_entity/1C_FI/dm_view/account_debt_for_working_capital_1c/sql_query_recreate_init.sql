drop view if exists dm_view.account_debt_for_working_capital_1c cascade;

create or replace view dm_view.account_debt_for_working_capital_1c as
select 
	s1c.dt,
	s1c.is_second_friday,
	s1c.unit_balance_code,
	s1c.fiscal_year,
	s1c.accounting_document_code,
	s1c.dt_debt,
	s1c.dt_overdue,
	s1c.dt_clearing,
	s1c.contract_number,
	s1c.counterparty_code,
	s1c.debit_or_credit,
	s1c.account_type,
	s1c.general_ledger_account_code,
	s1c.debt_balance_document_currency_amount,
	s1c.debt_balance_local_currency_amount,
	s1c.debt_balance_second_local_currency_amount,
	s1c.debt_balance_with_revaluation_diff_second_currency_amount,
	s1c.debt_balance_position_usd_amount,
	s1c.document_currency_code,
	s1c.local_currency_code,
	s1c.second_local_currency_code,
	s1c.accounting_document_type,
	s1c.accounting_document_type_name,
	s1c.position_line_item,
	s1c.reverse_document_code,
	s1c.reference_document_number,
	s1c.accounting_document_status_code,
	s1c.clearing_document_code,
	s1c.tax_code,
	s1c.position_line_item_text,
	s1c.special_general_ledger_indicator,
	s1c.dt_baseline_due_date_calculation,
	s1c.assignment_number,
	s1c.dt_accounting_document,
	s1c.plant_code,
	s1c.plant_name,
	s1c.general_ledger_account_full_name,
	s1c.unit_balance_name,
	s1c.counterparty_full_name,
	s1c.external_contract_number,
	s1c.dt_external_contract,
	s1c.contract_trader_code,
	s1c.contract_trader_name,
	s1c.terms_of_payment_code,
	s1c.terms_of_payment_name,
	s1c.responsibility_center_code,
	s1c.responsibility_center_name,
	s1c.budget_subtype_code,
	s1c.contract_supervisor_employee_number,
	s1c.contract_supervisor_name,
	s1c.purchase_or_sales_group_code,
	s1c.purchase_or_sales_group_name,
	s1c.funds_center_code,
	s1c.funds_center_name,
	s1c.debt_subposition_number,
	s1c.debt_subposition_local_currency_amount,
	s1c.debt_subposition_document_currency_amount,
	s1c.debt_subposition_second_local_currency_amount,
	s1c.is_debt_daily_calculated,
	s1c.country_code,
	s1c.counterparty_hfm_code,
	s1c.counterparty_mdm_code,
	s1c.is_related_party_tco,
	s1c.is_group_company_affiliated,
	s1c.is_related_party_rsbo,
	s1c.is_bankrupt,
	s1c.is_lawsuit_exist,
	s1c.is_fns_restriction_list_exist,
	s1c.document_currency_amount,
	s1c.local_currency_amount,
	s1c.second_local_currency_amount,
	s1c.counterparty_tin_code,
	s1c.reverse_document_fiscal_year,
	s1c.reason_for_reversal,
	s1c.debt_balance_subposition_document_currency_amount,
	s1c.debt_balance_subposition_local_currency_amount,
	s1c.debt_balance_subposition_second_local_currency_amount,
	s1c.debt_balance_subposition_usd_amount,
	s1c.debt_balance_subposition_document_currency_to_usd_amount,
	s1c.debt_balance_subpos_no_revaluation_local_currency_amount,
	s1c.debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	s1c.debt_balance_subposition_no_revaluation_usd_amount,
	s1c.debt_balance_contract_usd_amount,
	s1c.debt_balance_contract_document_currency_to_usd_amount,
	s1c.debt_balance_contract_no_revaluation_usd_amount,
	s1c.paydox_credit_limit_usd_currency_amount,
	s1c.invoice_document_code,
	s1c.fiscal_year_of_relevant_invoice,
	s1c.position_number_of_relevant_invoice,
	s1c.final_position_line_item,
	s1c.final_fiscal_year,
	s1c.final_accounting_document_code,
	s1c.exchange_diff_local_currency_amount,
	s1c.debt_balance_exchange_diff_local_currency_amount,
	s1c.debt_balance_subpos_exch_diff_local_currency_amount,
	s1c.exchange_diff_second_local_currency_amount,
	s1c.debt_balance_exchange_diff_second_local_currency_amount,
	s1c.debt_balance_subpos_exch_diff_second_local_curr_amount,
	s1c.counterparty_truncated_code,
	s1c.counterparty_search_name,
	s1c.responsibility_center_level1_code,
	s1c.responsibility_center_level1_name,
	s1c.financial_position_code,
	s1c.financial_position_name,
	s1c.usd_amount,
	s1c.realization_invoice_code,
	s1c.realization_document_code,
	s1c.country_of_end_user_code,
	s1c.country_of_end_user_name,
	s1c.region_of_end_user_code,
	s1c.region_of_end_user_name,
	s1c.sales_invoice_code,
	s1c.material_shape_code,
	s1c.material_shape_name,
	s1c.receivable_claim_number,
	s1c.receivable_claim_paydox_url,
	s1c.dt_receivable_claim,
	s1c.reference_operation_type_code,
    s1c.reference_object_key_code,
	s1c.material_code,
	s1c.bank_as_counterparty_code,
	s1c.almer_bank_code,
	s1c.bank_as_counterparty_name,
	s1c.paydox_document_url,
	s1c.contract_list,
	s1c.contract_list_with_paydox_url,
	s1c.external_contract_source_table_name,
	s1c.unpaid_payment_request_code,
	s1c.purchase_order_code,
	s1c.purchase_specification_compound_number,
	s1c.dt_edm_counterparty_electonic_signature,
	s1c.accounting_document_created_by,
	s1c.vat_rate,
	s1c.debt_balance_subpos_second_local_currency_amount_reval,
	s1c.dt_posting,
	s1c.contract_supervisor_user_active_directory_code,
	s1c.debt_balance_subpos_exchange_diff_local_currency_amount,
	s1c.debt_balance_subpos_exchange_diff_second_local_curr_amount,
	s1c.database_code_1c,
	s1c.database_name_1c,
	s1c.posting_uid_code_1c
from 
   dm.account_debt_for_working_capital_1c as s1c;
  
comment on view dm_view.account_debt_for_working_capital_1c is 'Оборотный капитал - ДЗ/КЗ_1C';
comment on column dm_view.account_debt_for_working_capital_1c.dt is 'Дата отчёта | Дата отчёта |dm_calc.account_debt_for_working_capital_1c.dt_report';
comment on column dm_view.account_debt_for_working_capital_1c.is_second_friday is 'Флаг:вторая пятница месяца | Флаг:вторая пятница месяца | is_second_friday';
comment on column dm_view.account_debt_for_working_capital_1c.unit_balance_code is 'БЕ | БЕ |dm_calc.account_debt_for_working_capital_1c.unit_balance_code';
comment on column dm_view.account_debt_for_working_capital_1c.fiscal_year is 'Фин.год | Фин.год |dm_calc.account_debt_for_working_capital_1c.fiscal_year';
comment on column dm_view.account_debt_for_working_capital_1c.accounting_document_code is 'Документ | Документ | null';
comment on column dm_view.account_debt_for_working_capital_1c.dt_debt is 'Задолж.дата | Задолж.дата |dm_calc.account_debt_for_working_capital_1c.dt_debt';
comment on column dm_view.account_debt_for_working_capital_1c.dt_overdue is 'ДтПросрочЗдлжУсл | ДтПросрочЗдлжУсл |dm_calc.account_debt_for_working_capital_1c.dt_overdue';
comment on column dm_view.account_debt_for_working_capital_1c.dt_clearing is 'Дата выравнивания | Дата выравнивания | null';
comment on column dm_view.account_debt_for_working_capital_1c.contract_number is 'СистНомДоговора | СистНомДоговора |null';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_code is 'Контрагент | Контрагент |dm_calc.account_debt_for_working_capital_1c.counterparty_code';
comment on column dm_view.account_debt_for_working_capital_1c.debit_or_credit is 'Бух.Д/К | Бух.Д/К |dm_calc.account_debt_for_working_capital_1c.debit_or_credit_code';
comment on column dm_view.account_debt_for_working_capital_1c.account_type is 'Вид счета | Вид счета |dm_calc.account_debt_for_working_capital_1c.account_type_code';
comment on column dm_view.account_debt_for_working_capital_1c.general_ledger_account_code is 'БСч | БСч |dm_calc.account_debt_for_working_capital_1c.general_ledger_account_code';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_document_currency_amount is 'Остаток задолженности в валюте документа | Остаток задолженности в валюте документа | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_local_currency_amount is 'Остаток задолженности в валюте организации | Остаток задолженности в валюте организации | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_second_local_currency_amount is 'Остаток задолженности во второй валюте | Остаток задолженности во второй валюте | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_with_revaluation_diff_second_currency_amount is 'Остаток задолженности, во второй валюте, с учётом последней переоценки | Остаток задолженности, во второй валюте, с учётом последней переоценки | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_position_usd_amount is 'Остаток задолженности в долларах по всей позиции  без переоценки | Остаток задолженности в долларах по всей позиции  без переоценки |dm_calc.account_debt_for_working_capital_1c.debt_balance_position_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.document_currency_code is 'Валюта | Валюта |dm_calc.account_debt_for_working_capital_1c.document_currency_code';
comment on column dm_view.account_debt_for_working_capital_1c.local_currency_code is 'Код валюты организации | Код валюты организации |dm_calc.account_debt_for_working_capital_1c.local_currency_code';
comment on column dm_view.account_debt_for_working_capital_1c.second_local_currency_code is 'ВнутрВалюта 2 | ВнутрВалюта 2 | null';
comment on column dm_view.account_debt_for_working_capital_1c.accounting_document_type is 'Вид док-та | Вид док-та | null';
comment on column dm_view.account_debt_for_working_capital_1c.accounting_document_type_name is 'Вид документа, текст | Вид документа, текст | null';
comment on column dm_view.account_debt_for_working_capital_1c.position_line_item is '№строкиБухДок | №строкиБухДок | null';
comment on column dm_view.account_debt_for_working_capital_1c.reverse_document_code is 'Сторно | Сторно | null';
comment on column dm_view.account_debt_for_working_capital_1c.reference_document_number is 'Ссылка | Ссылка | dm_calc.account_debt_for_working_capital_1c.reference_document_number';
comment on column dm_view.account_debt_for_working_capital_1c.accounting_document_status_code is 'Статус документа | Статус документа | null';
comment on column dm_view.account_debt_for_working_capital_1c.clearing_document_code is 'Документ выравнивания | Документ выравнивания | null';
comment on column dm_view.account_debt_for_working_capital_1c.tax_code is 'Код налога | Код налога | null';
comment on column dm_view.account_debt_for_working_capital_1c.position_line_item_text is 'Текст позиции | Текст позиции |dm_calc.account_debt_for_working_capital_1c.position_line_item_text';
comment on column dm_view.account_debt_for_working_capital_1c.special_general_ledger_indicator is 'Код ОГК | Код ОГК | null';
comment on column dm_view.account_debt_for_working_capital_1c.dt_baseline_due_date_calculation is 'Базовая дата | Базовая дата |dm_calc.account_debt_for_working_capital_1c.dt_baseline_due_date_calculation';
comment on column dm_view.account_debt_for_working_capital_1c.assignment_number is 'Присвоение | Присвоение | null';
comment on column dm_view.account_debt_for_working_capital_1c.dt_accounting_document is 'Дата документа | Дата документа |dm_calc.account_debt_for_working_capital_1c.dt_accounting_document';
comment on column dm_view.account_debt_for_working_capital_1c.plant_code is 'Завод | Завод | null';
comment on column dm_view.account_debt_for_working_capital_1c.plant_name is 'Название филиала | Название филиала | null';
comment on column dm_view.account_debt_for_working_capital_1c.general_ledger_account_full_name is 'Наименование БСч | Наименование БСч |dm_calc.account_debt_for_working_capital_1c.general_ledger_account_full_name';
comment on column dm_view.account_debt_for_working_capital_1c.unit_balance_name is 'Наименование БЕ | Наименование БЕ |dict_dds.unit_balance.unit_balance_name';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_full_name is 'Наименование контрагента | Наименование контрагента |dict_dds.counterparty.counterparty_full_name';
comment on column dm_view.account_debt_for_working_capital_1c.external_contract_number is 'Договор | Договор |dm_calc.account_debt_for_working_capital_1c.external_contract_number';
comment on column dm_view.account_debt_for_working_capital_1c.dt_external_contract is 'Дата договора | Дата договора |dm_calc.account_debt_for_working_capital_1c.dt_external_contract';
comment on column dm_view.account_debt_for_working_capital_1c.contract_trader_code is 'Трейдер (таб№) | Трейдер (таб№) |dm_calc.account_debt_for_working_capital_1c.contract_trader_code';
comment on column dm_view.account_debt_for_working_capital_1c.contract_trader_name is 'Трейдер ФИО | Трейдер ФИО |dm_calc.account_debt_for_working_capital_1c.contract_trader_name';
comment on column dm_view.account_debt_for_working_capital_1c.terms_of_payment_code is 'КодУслПл | КодУслПл | null';
comment on column dm_view.account_debt_for_working_capital_1c.terms_of_payment_name is 'НазвУслПл | НазвУслПл |dm_calc.account_debt_for_working_capital_1c.terms_of_payment_name';
comment on column dm_view.account_debt_for_working_capital_1c.responsibility_center_code is 'Центр ответственности, код | Центр ответственности, код | null';
comment on column dm_view.account_debt_for_working_capital_1c.responsibility_center_name is 'Название ЦО | Название ЦО | null';
comment on column dm_view.account_debt_for_working_capital_1c.budget_subtype_code is 'Подвид Бюджета | Подвид Бюджета |dict_dds.counterparty.budget_subtype_code';
comment on column dm_view.account_debt_for_working_capital_1c.contract_supervisor_employee_number is 'Куратор (таб№) | Куратор (таб№) |dm_calc.account_debt_for_working_capital_1c.contract_supervisor_employee_number';
comment on column dm_view.account_debt_for_working_capital_1c.contract_supervisor_name is 'Куратор (Имя) | Куратор (Имя) |dm_calc.account_debt_for_working_capital_1c.contract_supervisor_name';
comment on column dm_view.account_debt_for_working_capital_1c.purchase_or_sales_group_code is 'ГрЗак | ГрЗак | null';
comment on column dm_view.account_debt_for_working_capital_1c.purchase_or_sales_group_name is 'ГрЗак название | ГрЗак название | null';
comment on column dm_view.account_debt_for_working_capital_1c.funds_center_code is 'Расчётный ПФМ код | Расчётный ПФМ код | null';
comment on column dm_view.account_debt_for_working_capital_1c.funds_center_name is 'Расчётный ПФМ название | Расчётный ПФМ название | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_subposition_number is 'Подпозиция задолженности | Подпозиция задолженности | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_subposition_local_currency_amount is 'Сумма ВД подпозиции задолженности | Сумма ВД подпозиции задолженности | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_subposition_document_currency_amount is 'Сумма ВВ подпозиции задолженности | Сумма ВВ подпозиции задолженности |dm_calc.account_debt_for_working_capital_1c.debt_subposition_document_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_subposition_second_local_currency_amount is 'Сумма ВВ2 подпозиции задолженности | Сумма ВВ2 подпозиции задолженности | null';
comment on column dm_view.account_debt_for_working_capital_1c.is_debt_daily_calculated is 'Признак текущего остатка | Признак текущего остатка | null';
comment on column dm_view.account_debt_for_working_capital_1c.country_code is 'Страна регистрации контрагента | Страна регистрации контрагента | dict_dds.address.country_code';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_hfm_code is 'Код HFM | Код HFM |dict_dds.counterparty.counterparty_hfm_code';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_mdm_code is 'МДМ код ЮЛ | МДМ код ЮЛ |dm_calc.account_debt_for_working_capital_1c.counterparty_mdm_code';
comment on column dm_view.account_debt_for_working_capital_1c.is_related_party_tco is 'Связанность по ТЦО | Связанность по ТЦО | dict_dds.counterparty.is_related_party_tco';
comment on column dm_view.account_debt_for_working_capital_1c.is_group_company_affiliated is 'Входит в ОК | Входит в ОК | dict_dds.counterparty.is_group_company_affiliated';
comment on column dm_view.account_debt_for_working_capital_1c.is_related_party_rsbo is 'Связанность по РСБО | Связанность по РСБО | dict_dds.counterparty.is_related_party_rsbo';
comment on column dm_view.account_debt_for_working_capital_1c.is_bankrupt is 'Статус контрагента по банкротству | Статус контрагента по банкротству | dict_dds.counterparty.is_bankrupt';
comment on column dm_view.account_debt_for_working_capital_1c.is_lawsuit_exist is 'Наличие у контрагента судебных исков | Наличие у контрагента судебных исков | dict_dds.counterparty.is_lawsuit_exist';
comment on column dm_view.account_debt_for_working_capital_1c.is_fns_restriction_list_exist is 'Контрагент входит в негативные списки ФНС | Контрагент входит в негативные списки ФНС | dict_dds.counterparty.is_fns_restriction_list_exist';
comment on column dm_view.account_debt_for_working_capital_1c.document_currency_amount is 'Сумма документа ВД | Сумма документа ВД |dm_calc.account_debt_for_working_capital_1c.document_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.local_currency_amount is 'Сумма документа ВВ | Сумма документа ВВ | null';
comment on column dm_view.account_debt_for_working_capital_1c.second_local_currency_amount is 'Сумма документа ВВ2 | Сумма документа ВВ2 | null';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_tin_code is 'ИНН | ИНН |dict_dds.counterparty.counterparty_tin_code';
comment on column dm_view.account_debt_for_working_capital_1c.reverse_document_fiscal_year is 'Год Сторно-документа | Год Сторно-документа | null';
comment on column dm_view.account_debt_for_working_capital_1c.reason_for_reversal is 'Причина сторно | Причина сторно | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subposition_document_currency_amount is 'Сумма валютная | Сумма валютная |dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_document_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subposition_local_currency_amount is 'Сумма вн.валюте | Сумма вн.валюте |dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subposition_second_local_currency_amount is 'Сумма в ВВ2 | Сумма в ВВ2 |dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_second_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subposition_usd_amount is 'Остаток задолженности в долларах | Остаток задолженности в долларах |dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subposition_document_currency_to_usd_amount is 'Остаток задолженности в долларах | Остаток задолженности в долларах |dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_document_currency_to_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_no_revaluation_local_currency_amount is 'Остаток задолженности в ВВ без переоценки | Остаток задолженности в ВВ без переоценки |dm_calc.account_debt_for_working_capital_1c.debt_balance_subpos_no_revaluation_local_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_no_revaluation_sec_local_curr_amount is 'Остаток задолженности в ВВ2 без переоценки | Остаток задолженности в ВВ2 без переоценки |dm_calc.account_debt_for_working_capital_1c.debt_balance_subpos_no_revaluation_sec_local_curr_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subposition_no_revaluation_usd_amount is 'Остаток задолженности в долларах без переоценки | Остаток задолженности в долларах без переоценки |dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_no_revaluation_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_contract_usd_amount is 'Остаток задолженности по контракту, в USD | Остаток задолженности по контракту, в USD |dm_calc.account_debt_for_working_capital_1c.debt_balance_contract_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_contract_document_currency_to_usd_amount is 'Остаток задолженности по контракту, в долларах (пересчёт на дату отчёта) | Остаток задолженности по контракту, в долларах (пересчёт на дату отчёта) |dm_calc.account_debt_for_working_capital_1c.debt_balance_contract_document_currency_to_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_contract_no_revaluation_usd_amount is 'Остаток задолженности по контракту, в долларах без переоценки | Остаток задолженности по контракту, в долларах без переоценки |dm_calc.account_debt_for_working_capital_1c.debt_balance_contract_no_revaluation_usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.paydox_credit_limit_usd_currency_amount is 'Суммарное значение КЛ | Суммарное значение КЛ |dm.paydox_credit_limits.paydox_credit_limit_usd_currency_amount';
comment on column dm_view.account_debt_for_working_capital_1c.invoice_document_code is 'Ссылочный инвойс (№) | Ссылочный инвойс (№) | null';
comment on column dm_view.account_debt_for_working_capital_1c.fiscal_year_of_relevant_invoice is 'Ссылочный инвойс (Год) | Ссылочный инвойс (Год) | null';
comment on column dm_view.account_debt_for_working_capital_1c.position_number_of_relevant_invoice is 'Ссылочный инвойс (Позиция) | Ссылочный инвойс (Позиция) | null';
comment on column dm_view.account_debt_for_working_capital_1c.final_position_line_item is 'Номер документа задолженности | Номер документа задолженности | null';
comment on column dm_view.account_debt_for_working_capital_1c.final_fiscal_year is 'Год документа задолженности | Год документа задолженности |dm_calc.account_debt_for_working_capital_1c.final_fiscal_year';
comment on column dm_view.account_debt_for_working_capital_1c.final_accounting_document_code is 'Позиция документа задолженности | Позиция документа задолженности |dm_calc.account_debt_for_working_capital_1c.final_accounting_document_code';
comment on column dm_view.account_debt_for_working_capital_1c.exchange_diff_local_currency_amount is 'ВВ Курсовая разница позиции | ВВ Курсовая разница позиции | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_exchange_diff_local_currency_amount is 'ВВ Курсовая разница остатка позиции | ВВ Курсовая разница остатка позиции | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_exch_diff_local_currency_amount is 'ВВ Курсовая разница остатка подпозиции | ВВ Курсовая разница остатка подпозиции  |  null';
comment on column dm_view.account_debt_for_working_capital_1c.exchange_diff_second_local_currency_amount is 'ВВ2 Курсовая разница позиции | ВВ2 Курсовая разница позиции | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_exchange_diff_second_local_currency_amount is 'ВВ2 Курсовая разница остатка позиции | ВВ2 Курсовая разница остатка позиции | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_exch_diff_second_local_curr_amount is 'ВВ2 Курсовая разница остатка подпозиции | ВВ2 Курсовая разница остатка подпозиции|  null';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_truncated_code is 'Контрагент (код, без лидирующих нулей) | Контрагент (код, без лидирующих нулей) | dict_dds.counterparty.counterparty_truncated_code';
comment on column dm_view.account_debt_for_working_capital_1c.counterparty_search_name is 'Контрагент (код+имя для фильтрации) | Контрагент (код+имя для фильтрации) |dict_dds.counterparty.counterparty_search_name';
comment on column dm_view.account_debt_for_working_capital_1c.responsibility_center_level1_code is 'ЦО 1го уровня, код | ЦО 1го уровня, код |dm_calc.account_debt_for_working_capital_1c.responsibility_center_level1_code';
comment on column dm_view.account_debt_for_working_capital_1c.responsibility_center_level1_name is 'ЦО 1го уровня, название | ЦО 1го уровня, название |dict_dds.responsibility_center_texts.responsibility_center_name';
comment on column dm_view.account_debt_for_working_capital_1c.financial_position_code is 'Расчётная ФП код | Расчётная ФП код | null';
comment on column dm_view.account_debt_for_working_capital_1c.financial_position_name is 'Расчётная ФП название | Расчётная ФП название | null';
comment on column dm_view.account_debt_for_working_capital_1c.usd_amount is 'Сумма задолженности в долларах | Сумма задолженности в долларах |dm_calc.account_debt_for_working_capital_1c.usd_amount';
comment on column dm_view.account_debt_for_working_capital_1c.realization_invoice_code is 'Фактура реализации | Фактура реализации | null';
comment on column dm_view.account_debt_for_working_capital_1c.realization_document_code is 'Группа реализации | Группа реализации | null';
comment on column dm_view.account_debt_for_working_capital_1c.country_of_end_user_code is 'Страна конечной поставки, код | Страна конечной поставки, код |dm_calc.account_debt_for_working_capital_1c.country_of_end_user_code';
comment on column dm_view.account_debt_for_working_capital_1c.country_of_end_user_name is 'Страна конечной поставки, название | Страна конечной поставки, название |dict_dds.country_texts.country_short_namecountry_of_end_user_name';
comment on column dm_view.account_debt_for_working_capital_1c.region_of_end_user_code is 'Регион конечной поставки, код | Регион конечной поставки, код |dict_dds.country.market_region1_code';
comment on column dm_view.account_debt_for_working_capital_1c.region_of_end_user_name is 'Регион конечной поставки, название | Регион конечной поставки, название |dict_dds.market_region1_texts.market_region1_name';
comment on column dm_view.account_debt_for_working_capital_1c.sales_invoice_code is 'Фактура сбыта (инвойс) | Фактура сбыта (инвойс) | null';
comment on column dm_view.account_debt_for_working_capital_1c.material_shape_code is 'Форма товара, код | Форма товара, код | null';
comment on column dm_view.account_debt_for_working_capital_1c.material_shape_name is 'Форма товара, описание | Форма товара, описание |dm_calc.account_debt_for_working_capital_1c.material_shape_name';
comment on column dm_view.account_debt_for_working_capital_1c.receivable_claim_number is '№ претензии | № претензии | null';
comment on column dm_view.account_debt_for_working_capital_1c.receivable_claim_paydox_url is 'Ссылка на претензию | Ссылка на претензию |dm_calc.account_debt_for_working_capital_1c.receivable_claim_paydox_url';
comment on column dm_view.account_debt_for_working_capital_1c.dt_receivable_claim is 'Дата выставления претензии | Дата выставления претензии |dm_calc.account_debt_for_working_capital_1c.dt_receivable_claim';
comment on column dm_view.account_debt_for_working_capital_1c.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | null';
comment on column dm_view.account_debt_for_working_capital_1c.reference_object_key_code is 'Ссылочный ключ | Ссылочный ключ | null';
comment on column dm_view.account_debt_for_working_capital_1c.material_code is 'Номер материала | Номер материала | null';
comment on column dm_view.account_debt_for_working_capital_1c.bank_as_counterparty_code is 'Банк получатель (код контрагента) | Банк получатель (код контрагента) | null';
comment on column dm_view.account_debt_for_working_capital_1c.almer_bank_code is 'Банк получатель (код almer) | Банк получатель (код almer) |dm_calc.account_debt_for_working_capital_1c.bank_receiver_name';
comment on column dm_view.account_debt_for_working_capital_1c.bank_as_counterparty_name is 'Банк получатель (наименование) | Банк получатель (наименование) | null';
comment on column dm_view.account_debt_for_working_capital_1c.paydox_document_url is 'Ссылка на договор в paydox | Ссылка на договор в paydox |dm_calc.account_debt_for_working_capital_1c.paydox_document_url';
comment on column dm_view.account_debt_for_working_capital_1c.contract_list is 'Cписок контрактов  | Cписок контрактов  | null';
comment on column dm_view.account_debt_for_working_capital_1c.contract_list_with_paydox_url is 'Cписок контрактов закупок с ссылками на PAYDOX | Cписок контрактов закупок с ссылками на PAYDOX | null';
comment on column dm_view.account_debt_for_working_capital_1c.external_contract_source_table_name is 'Таблица-источник контракта | Таблица-источник контракта| null ';
comment on column dm_view.account_debt_for_working_capital_1c.unpaid_payment_request_code is 'Неоплаченный ТАП - № документа | Неоплаченный ТАП - № документа | null';
comment on column dm_view.account_debt_for_working_capital_1c.purchase_order_code is 'Заказ на закупку | Заказ на закупку | null';
comment on column dm_view.account_debt_for_working_capital_1c.purchase_specification_compound_number is 'Все № спецификаций | Все № спецификаций | null';
comment on column dm_view.account_debt_for_working_capital_1c.dt_edm_counterparty_electonic_signature is 'Дата ЭП Подрядчика ЭДО | Дата ЭП Подрядчика ЭДО | null';
comment on column dm_view.account_debt_for_working_capital_1c.accounting_document_created_by is 'Имя пользователя | Логин пользователя, создавшего бух.документ | null';
comment on column dm_view.account_debt_for_working_capital_1c.vat_rate  is 'Ставка налога | Ставка налога | null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_second_local_currency_amount_reval is 'Оценочная сумма в ВВ2 | Оценочная сумма в ВВ2 |debt_balance_subpos_second_local_currency_amount_reval';
comment on column dm_view.account_debt_for_working_capital_1c.dt_posting is 'Дата проводки | Дата проводки |dm_calc.account_debt_for_working_capital_1c.dt_posting';
comment on column dm_view.account_debt_for_working_capital_1c.contract_supervisor_user_active_directory_code is 'Куратор (AD) | Куратор (AD) |dm_calc.account_debt_for_working_capital_1c.contract_supervisor_user_active_directory_code';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_exchange_diff_local_currency_amount is 'ВВ Курсовая разница остатка подпозиции | ВВ Курсовая разница остатка подпозиции |null';
comment on column dm_view.account_debt_for_working_capital_1c.debt_balance_subpos_exchange_diff_second_local_curr_amount is 'ВВ2 Курсовая разница остатка подпозиции | ВВ2 Курсовая разница остатка подпозиции |null';
comment on column dm_view.account_debt_for_working_capital_1c.database_code_1c is 'ИД БД 1С | ИД БД 1С |dm_calc.account_debt_for_working_capital_1c.database_code_1c';
comment on column dm_view.account_debt_for_working_capital_1c.database_name_1c is 'Имя БД 1С | Имя БД 1С |dm_calc.account_debt_for_working_capital_1c.database_name_1c';
comment on column dm_view.account_debt_for_working_capital_1c.posting_uid_code_1c is 'ИД проводки | ИД проводки |dm_calc.account_debt_for_working_capital_1c.posting_uid_code_1c';
