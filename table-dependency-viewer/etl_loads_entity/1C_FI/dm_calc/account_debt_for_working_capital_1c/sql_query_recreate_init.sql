drop table if exists dm_calc.account_debt_for_working_capital_1c;

create table if not exists dm_calc.account_debt_for_working_capital_1c (
	dt_report date not null,
	unit_balance_mdm_code_1c text not null,
	unit_balance_code text not null,
	posting_uid_code_1c text not null,
	fiscal_year numeric(4,0) null,
	debit_or_credit_code text null,
	account_type_code text null,
	dt_accounting_document date null,
	dt_debt date null,
	dt_overdue date null,
	dt_posting date null,
	position_line_item_text text null,
	reference_document_number text null,
	dt_baseline_due_date_calculation date null,
	general_ledger_account_code text null,
	general_ledger_account_full_name text null,
	external_contract_number text null,
	dt_external_contract date null,
	counterparty_code text null,
	counterparty_mdm_code text null,
	terms_of_payment_name text null,
	contract_supervisor_employee_number text null,
	contract_supervisor_user_active_directory_code text null,
	contract_supervisor_name text null,
	final_accouning_document_code text null,
	final_fiscal_year numeric(4) null,
	contract_trader_code text null,
	contract_trader_name text null,
	responsibility_center_level1_code text null,
	country_of_end_user_code text null,
	material_shape_name text null,
	receivable_claim_paydox_url text null,
	dt_receivable_claim date null,
	bank_receiver_name text null,
	paydox_document_url text null,
	document_currency_code text null,
	local_currency_code text null,
	document_currency_amount numeric(17,2) default 0,
	debt_subposition_document_currency_amount numeric(17,2) default 0,
	debt_balance_subposition_document_currency_amount numeric(17,2) default 0,
	debt_balance_subposition_local_currency_amount numeric(17,2) default 0,
	debt_balance_subposition_second_local_currency_amount numeric(17,2) default 0,
	debt_balance_subposition_usd_amount numeric(17,2) default 0,
	debt_balance_position_usd_amount numeric(17,2) default 0,
	debt_balance_subposition_document_currency_to_usd_amount numeric(17,2) default 0,
	debt_balance_subpos_no_revaluation_local_currency_amount numeric(17,2) default 0,
	debt_balance_subpos_no_revaluation_sec_local_curr_amount numeric(17,2) default 0,
	debt_balance_subposition_no_revaluation_usd_amount numeric(17,2) default 0,
	debt_balance_contract_usd_amount numeric(17,2) default 0,
	debt_balance_contract_document_currency_to_usd_amount numeric(17,2) default 0,
	debt_balance_contract_no_revaluation_usd_amount numeric(17,2) default 0,
	usd_amount numeric(17,2) default 0,
	database_code_1c text not null,
	database_name_1c text not null,
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
distributed by (dt_report, unit_balance_code, posting_uid_code_1c);


comment on table dm_calc.account_debt_for_working_capital_1c is 'Оборотный капитал - 1C';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_report is 'Дата отчёта | Дата отчёта |ods.account_debt_for_working_capital_1c.dt';
comment on column dm_calc.account_debt_for_working_capital_1c.unit_balance_mdm_code_1c is 'MDM-код БЕ | MDM-код БЕ |ods.account_debt_for_working_capital_1c.unit_balance_mdm_code_1c';
comment on column dm_calc.account_debt_for_working_capital_1c.unit_balance_code is 'БЕ | БЕ | unit_balance_code';
comment on column dm_calc.account_debt_for_working_capital_1c.posting_uid_code_1c is 'ИД проводки | ИД проводки |ods.account_debt_for_working_capital_1c.posting_uid_code_1c';
comment on column dm_calc.account_debt_for_working_capital_1c.fiscal_year is 'Финансовый год | Финансовый год |ods.account_debt_for_working_capital_1c.dt_debt';
comment on column dm_calc.account_debt_for_working_capital_1c.debit_or_credit_code is 'Бух.Д/К | Бух.Д/К |ods.account_debt_for_working_capital_1c.debit_or_credit_name';
comment on column dm_calc.account_debt_for_working_capital_1c.account_type_code is 'Вид счета | Вид счета |ods.account_debt_for_working_capital_1c.counterparty_role_name';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_accounting_document is 'Дата документа | Дата документа |ods.account_debt_for_working_capital_1c.dt_debt';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_debt is 'Задолж.дата | Задолж.дата |ods.account_debt_for_working_capital_1c.dt_debt';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_overdue is 'ДтПросрочЗдлжУсл | ДтПросрочЗдлжУсл |ods.account_debt_for_working_capital_1c.dt_overdue';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_posting is 'Дата проводки | Дата проводки |ods.account_debt_for_working_capital_1c.dt_debt';
comment on column dm_calc.account_debt_for_working_capital_1c.position_line_item_text is 'Текст позиции | Текст позиции |ods.account_debt_for_working_capital_1c.accounting_document_descriprion_text';
comment on column dm_calc.account_debt_for_working_capital_1c.reference_document_number is 'Ссылка | Ссылка |ods.account_debt_for_working_capital_1c.invoice_registration_number';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_baseline_due_date_calculation is 'Базовая дата | Базовая дата |ods.account_debt_for_working_capital_1c.dt_overdue';
comment on column dm_calc.account_debt_for_working_capital_1c.general_ledger_account_code is 'БСч | БСч |ods.account_debt_for_working_capital_1c.general_ledger_account_code';
comment on column dm_calc.account_debt_for_working_capital_1c.general_ledger_account_full_name is 'Наименование БСч | Наименование БСч |ods.account_debt_for_working_capital_1c.general_ledger_account_name';
comment on column dm_calc.account_debt_for_working_capital_1c.external_contract_number is 'Договор | Договор |ods.account_debt_for_working_capital_1c.contract_number';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_external_contract is 'Дата договора | Дата договора |ods.account_debt_for_working_capital_1c.dt_contract_registration';
comment on column dm_calc.account_debt_for_working_capital_1c.counterparty_code is 'Контрагент | Контрагент |dict_dds.counterparty_td.counterparty_code';
comment on column dm_calc.account_debt_for_working_capital_1c.counterparty_mdm_code is 'МДМ код ЮЛ | МДМ код ЮЛ |ods.account_debt_for_working_capital_1c.unit_balance_mdm_code_1c';
comment on column dm_calc.account_debt_for_working_capital_1c.terms_of_payment_name is 'НазвУслПл | НазвУслПл |ods.account_debt_for_working_capital_1c.terms_of_payment_name';
comment on column dm_calc.account_debt_for_working_capital_1c.contract_supervisor_employee_number is 'Куратор (таб№) | Куратор (таб№) |ods.account_debt_for_working_capital_1c.contract_supervisor_employee_sap_number';
comment on column dm_calc.account_debt_for_working_capital_1c.contract_supervisor_user_active_directory_code is 'Куратор (AD) | Куратор (AD) |ods.account_debt_for_working_capital_1c.contract_supervisor_ad_login_code';
comment on column dm_calc.account_debt_for_working_capital_1c.contract_supervisor_name is 'Куратор (Имя) | Куратор (Имя) |ods.account_debt_for_working_capital_1c.contract_supervisor_name';
comment on column dm_calc.account_debt_for_working_capital_1c.final_accouning_document_code is 'Номер документа задолженности | Номер документа задолженности |ods.account_debt_for_working_capital_1c.document_1c_code';
comment on column dm_calc.account_debt_for_working_capital_1c.final_fiscal_year is 'Задолж.год | Задолж.год |ods.account_debt_for_working_capital_1c.dt_debt';
comment on column dm_calc.account_debt_for_working_capital_1c.contract_trader_code is 'Трейдер (таб№) | Трейдер (таб№) |ods.account_debt_for_working_capital_1c.contract_supervisor_employee_sap_number';
comment on column dm_calc.account_debt_for_working_capital_1c.contract_trader_name is 'Трейдер ФИО | Трейдер ФИО |ods.account_debt_for_working_capital_1c.contract_supervisor_name';
comment on column dm_calc.account_debt_for_working_capital_1c.responsibility_center_level1_code is 'ЦО 1го уровня, код | ЦО 1го уровня, код |ods.account_debt_for_working_capital_1c.responsibility_center_hfm_code';
comment on column dm_calc.account_debt_for_working_capital_1c.country_of_end_user_code is 'Страна конечной поставки, код | Страна конечной поставки, код |ods.account_debt_for_working_capital_1c.country_of_end_user_code';
comment on column dm_calc.account_debt_for_working_capital_1c.material_shape_name is 'Форма товара, описание | Форма товара, описание |ods.account_debt_for_working_capital_1c.finish_goods_group_name';
comment on column dm_calc.account_debt_for_working_capital_1c.receivable_claim_paydox_url is 'Ссылка на претензию | Ссылка на претензию |ods.account_debt_for_working_capital_1c.receivable_claim_paydox_url';
comment on column dm_calc.account_debt_for_working_capital_1c.dt_receivable_claim is 'Дата выставления претензии | Дата выставления претензии |ods.account_debt_for_working_capital_1c.dt_receivable_claim';
comment on column dm_calc.account_debt_for_working_capital_1c.bank_receiver_name is 'Банк получатель (код almer) | Банк получатель (код almer) |ods.account_debt_for_working_capital_1c.bank_receiver_name';
comment on column dm_calc.account_debt_for_working_capital_1c.paydox_document_url is 'Ссылка на договор в paydox | Ссылка на договор в paydox |ods.account_debt_for_working_capital_1c.paydox_document_url';
comment on column dm_calc.account_debt_for_working_capital_1c.document_currency_code is 'Валюта | Валюта |ods.account_debt_for_working_capital_1c.document_currency_code';
comment on column dm_calc.account_debt_for_working_capital_1c.local_currency_code is 'Код валюты организации | Код валюты организации | RUB';
comment on column dm_calc.account_debt_for_working_capital_1c.document_currency_amount is 'Сумма документа ВД | Сумма документа ВД |ods.account_debt_for_working_capital_1c.document_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_subposition_document_currency_amount is 'Сумма ВВ подпозиции задолженности | Сумма ВВ подпозиции задолженности |ods.account_debt_for_working_capital_1c.document_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_document_currency_amount is 'Сумма валютная | Сумма валютная |ods.account_debt_for_working_capital_1c.debt_balance_document_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_local_currency_amount is 'Сумма вн.валюте | Сумма вн.валюте |ods.account_debt_for_working_capital_1c.debt_balance_rub_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_second_local_currency_amount is 'Сумма в ВВ2 | Сумма в ВВ2 |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_usd_amount is 'Остаток задолженности в долларах | Остаток задолженности в долларах |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_position_usd_amount is 'Остаток задолженности в долларах по всей позиции  без переоценки | Остаток задолженности в долларах по всей позиции  без переоценки |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_document_currency_to_usd_amount is 'Остаток задолженности в долларах | Остаток задолженности в долларах |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subpos_no_revaluation_local_currency_amount is 'Остаток задолженности в ВВ без переоценки | Остаток задолженности в ВВ без переоценки |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subpos_no_revaluation_sec_local_curr_amount is 'Остаток задолженности в ВВ2 без переоценки | Остаток задолженности в ВВ2 без переоценки |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_subposition_no_revaluation_usd_amount is 'Остаток задолженности в долларах без переоценки | Остаток задолженности в долларах без переоценки |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_contract_usd_amount is 'Остаток задолженности по контракту, в USD | Остаток задолженности по контракту, в USD | Алгоритм';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_contract_document_currency_to_usd_amount is 'Остаток задолженности по контракту, в долларах (пересчёт на дату отчёта) | Остаток задолженности по контракту, в долларах (пересчёт на дату отчёта) | Алгоритм';
comment on column dm_calc.account_debt_for_working_capital_1c.debt_balance_contract_no_revaluation_usd_amount is 'Остаток задолженности по контракту, в долларах без переоценки | Остаток задолженности по контракту, в долларах без переоценки | Алгоритм';
comment on column dm_calc.account_debt_for_working_capital_1c.usd_amount is 'Сумма в долларах | Сумма в долларах |ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount';
comment on column dm_calc.account_debt_for_working_capital_1c.database_code_1c is 'ИД БД 1С | ИД БД 1С |ods.account_debt_for_working_capital_1c.database_code_1c';
comment on column dm_calc.account_debt_for_working_capital_1c.database_name_1c is 'Имя БД 1С | Имя БД 1С |ods.account_debt_for_working_capital_1c.database_name_1c';
