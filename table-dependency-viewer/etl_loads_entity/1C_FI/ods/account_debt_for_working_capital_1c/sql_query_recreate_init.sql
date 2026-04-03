drop table if exists ods.account_debt_for_working_capital_1c;

create table if not exists ods.account_debt_for_working_capital_1c (
	sender text not null,
	receiver text not null,
	create_date_time timestamp not null,
	dt_report date not null,
	database_code_1c text not null,
	database_name_1c text not null,
	unit_balance_mdm_code_1c text not null,
	posting_uid_code_1c text not null,
	invoice_registration_number text null,
	counterparty_role_name text null,
	debit_or_credit_name text null,
	accounting_document_descriprion_text text null,
	document_1c_code text null,
	responsibility_center_hfm_code text null,
	region_of_end_user_code text null,
	country_of_end_user_code text null,
	counterparty_mdm_code text null,
	counterparty_annual_turnover_amount numeric(17,2) default 0,
	finish_goods_group_name text null,
	contract_number text null,
	paydox_document_url text null,
	contract_type_name text null,
	contract_amount numeric(17,2) default 0,
	contract_currency_code text null,
	dt_contract_start date null,
	dt_contract_end date null,
	terms_of_payment_name text null,
	dt_overdue date null,
	debt_coverage_type_name text null,
	coverage_amount numeric(17,2) default 0,
	coverage_currency_code text null,
	dt_debt date null,
	document_currency_code text null,
	debt_balance_document_currency_amount numeric(17,2) default 0,
	debt_balance_rub_currency_amount numeric(17,2) default 0,
	debt_balance_usd_currency_amount numeric(17,2) default 0,
	debt_overdue_document_currency_amount numeric(17,2) default 0,
	debt_overdue_rub_currency_amount numeric(17,2) default 0,
	debt_overdue_usd_currency_amount numeric(17,2) default 0,
	bank_receiver_name text null,
	receivable_claim_paydox_url text null,
	dt_receivable_claim date null,
	dt_claim_send_to_law_court date null,
	contract_supervisor_name text null,
	contract_supervisor_ad_login_code text null,
	general_ledger_account_code text null,
	general_ledger_account_name text null,
	dt_contract_registration date null,
	document_currency_amount numeric(17,2) default 0,
	contract_supervisor_employee_1c_number text null,
	contract_supervisor_employee_sap_number text null,
	sales_market_code text null,
	sales_market_name text null,
	bad_debt_provision_amount numeric(17,2) default 0,
	bad_debt_provision_currency_code text null,
	credit_limit_rub_currency_amount numeric(17,2) default 0,
	dt_credit_limit_valid_to date null,
	paydox_credit_limit_url text null,
	insured_amount numeric(17,2) default 0,
	insurance_currency_code text null,
	dt_insurance_valid_to date null,
	insurance_company_mdm_code text null,
	bank_guarantee_amount numeric(17,2) default 0,
	bank_guarantee_currency_code text null,
	dt_bank_guarantee_valid_to date null,
	bank_guarantee_mdm_code text null,
	third_party_guarantee_amount numeric(17,2) default 0,
	third_party_guarantee_currency_code text null,
	dt_third_party_guarantee_valid_to date null,
	third_party_guarantee_mdm_code text null,
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
distributed by (dt_report, unit_balance_mdm_code_1c, posting_uid_code_1c);


comment on table ods.account_debt_for_working_capital_1c is 'Оборотный капитал - 1C';
comment on column ods.account_debt_for_working_capital_1c.sender is 'Отправитель | Отправитель  |stg.s1c_debt_for_working_capital.sender';
comment on column ods.account_debt_for_working_capital_1c.receiver is 'Получатель | Получатель |stg.s1c_debt_for_working_capital.receiver';
comment on column ods.account_debt_for_working_capital_1c.create_date_time is 'Дата и время создания | Дата и время создания |stg.s1c_debt_for_working_capital.create_date_time';
comment on column ods.account_debt_for_working_capital_1c.dt_report is 'Дата подачи информации | Дата подачи информации |stg.s1c_debt_for_working_capital.dt_report';
comment on column ods.account_debt_for_working_capital_1c.database_code_1c is 'ID 1С-БД | ID 1С-БД |stg.s1c_debt_for_working_capital.database_code_1c';
comment on column ods.account_debt_for_working_capital_1c.database_name_1c is 'ID 1С-БД, название | ID 1С-БД, название |stg.s1c_debt_for_working_capital.database_name_1c';
comment on column ods.account_debt_for_working_capital_1c.unit_balance_mdm_code_1c is '1С - Балансовая единица (организация) | 1С - Балансовая единица (организация) |stg.s1c_debt_for_working_capital.unit_balance_mdm_code_1c';
comment on column ods.account_debt_for_working_capital_1c.posting_uid_code_1c is '1c-ID проводки | 1c-ID проводки |stg.s1c_debt_for_working_capital.posting_uid_code_1c';
comment on column ods.account_debt_for_working_capital_1c.invoice_registration_number is 'Регистрационный номер инвойса | Регистрационный номер инвойса |stg.s1c_debt_for_working_capital.invoice_registration_number';
comment on column ods.account_debt_for_working_capital_1c.counterparty_role_name is 'Вид контрагента | Вид контрагента |stg.s1c_debt_for_working_capital.counterparty_role_name';
comment on column ods.account_debt_for_working_capital_1c.debit_or_credit_name is 'Направление задолженности | Направление задолженности |stg.s1c_debt_for_working_capital.debit_or_credit_name';
comment on column ods.account_debt_for_working_capital_1c.accounting_document_descriprion_text is 'Описание документа | Описание документа |stg.s1c_debt_for_working_capital.accounting_document_descriprion_text';
comment on column ods.account_debt_for_working_capital_1c.document_1c_code is 'Номер документа | Номер документа |stg.s1c_debt_for_working_capital.document_1с_code';
comment on column ods.account_debt_for_working_capital_1c.responsibility_center_hfm_code is 'ЦО | ЦО |stg.s1c_debt_for_working_capital.responsibility_center_hfm_code';
comment on column ods.account_debt_for_working_capital_1c.region_of_end_user_code is 'Регион поставки | Регион поставки |stg.s1c_debt_for_working_capital.region_of_end_user_code';
comment on column ods.account_debt_for_working_capital_1c.country_of_end_user_code is 'Страна поставки | Страна поставки |stg.s1c_debt_for_working_capital.country_of_end_user_code';
comment on column ods.account_debt_for_working_capital_1c.counterparty_mdm_code is 'Контрагент | Контрагент |stg.s1c_debt_for_working_capital.counterparty_mdm_code';
comment on column ods.account_debt_for_working_capital_1c.counterparty_annual_turnover_amount is 'Среднегодовой оборот | Среднегодовой оборот |stg.s1c_debt_for_working_capital.counterparty_annual_turnover_amount';
comment on column ods.account_debt_for_working_capital_1c.finish_goods_group_name is 'Вид сплава | Вид сплава |stg.s1c_debt_for_working_capital.finish_goods_group_name';
comment on column ods.account_debt_for_working_capital_1c.contract_number is 'Номер контракта | Номер контракта |stg.s1c_debt_for_working_capital.contract_number';
comment on column ods.account_debt_for_working_capital_1c.paydox_document_url is 'Ссылка на контракт в paydox | Ссылка на контракт в paydox |stg.s1c_debt_for_working_capital.paydox_document_url';
comment on column ods.account_debt_for_working_capital_1c.contract_type_name is 'Тип контракта | Тип контракта |stg.s1c_debt_for_working_capital.contract_type_name';
comment on column ods.account_debt_for_working_capital_1c.contract_amount is 'Сумма контракта в валюте контракта | Сумма контракта в валюте контракта |stg.s1c_debt_for_working_capital.contract_amount';
comment on column ods.account_debt_for_working_capital_1c.contract_currency_code is 'Валюта контракта | Валюта контракта |stg.s1c_debt_for_working_capital.contract_currency_code';
comment on column ods.account_debt_for_working_capital_1c.dt_contract_start is 'Дата начала действия контракта | Дата начала действия контракта |stg.s1c_debt_for_working_capital.dt_contract_start';
comment on column ods.account_debt_for_working_capital_1c.dt_contract_end is 'Дата конца действия контракта | Дата конца действия контракта |stg.s1c_debt_for_working_capital.dt_contract_end';
comment on column ods.account_debt_for_working_capital_1c.terms_of_payment_name is 'Условия оплаты | Условия оплаты |stg.s1c_debt_for_working_capital.terms_of_payment_name';
comment on column ods.account_debt_for_working_capital_1c.dt_overdue is 'Плановая дата погашения задолженности | Плановая дата погашения задолженности |stg.s1c_debt_for_working_capital.dt_overdue';
comment on column ods.account_debt_for_working_capital_1c.debt_coverage_type_name is 'Обеспечение задолженности | Обеспечение задолженности |stg.s1c_debt_for_working_capital.debt_coverage_type_name';
comment on column ods.account_debt_for_working_capital_1c.coverage_amount is 'Сумма обеспечения | Сумма обеспечения |stg.s1c_debt_for_working_capital.coverage_amount';
comment on column ods.account_debt_for_working_capital_1c.coverage_currency_code is 'Валюта обеспечения | Валюта обеспечения |stg.s1c_debt_for_working_capital.coverage_currency_code';
comment on column ods.account_debt_for_working_capital_1c.dt_debt is 'Дата проводки задолженности | Дата проводки задолженности |stg.s1c_debt_for_working_capital.dt_debt';
comment on column ods.account_debt_for_working_capital_1c.document_currency_code is 'Валюта счета | Валюта счета |stg.s1c_debt_for_working_capital.document_currency_code';
comment on column ods.account_debt_for_working_capital_1c.debt_balance_document_currency_amount is 'Сумма задолженности, вал | Сумма задолженности, вал |stg.s1c_debt_for_working_capital.debt_balance_document_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.debt_balance_rub_currency_amount is 'Сумма задолженности, руб | Сумма задолженности, руб |stg.s1c_debt_for_working_capital.debt_balance_rub_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.debt_balance_usd_currency_amount is 'Сумма задолженности, USD | Сумма задолженности, USD |stg.s1c_debt_for_working_capital.debt_balance_usd_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.debt_overdue_document_currency_amount is 'Сумма просроченной задолженности, вал | Сумма просроченной задолженности, вал |stg.s1c_debt_for_working_capital.debt_overdue_document_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.debt_overdue_rub_currency_amount is 'Сумма просроченной задолженности, руб | Сумма просроченной задолженности, руб |stg.s1c_debt_for_working_capital.debt_overdue_rub_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.debt_overdue_usd_currency_amount is 'Сумма просроченной задолженности, USD | Сумма просроченной задолженности, USD |stg.s1c_debt_for_working_capital.debt_overdue_usd_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.bank_receiver_name is 'Банк получения денежных средств | Банк получения денежных средств |stg.s1c_debt_for_working_capital.bank_receiver_name';
comment on column ods.account_debt_for_working_capital_1c.receivable_claim_paydox_url is 'Ссылка на претензию | Ссылка на претензию |stg.s1c_debt_for_working_capital.receivable_claim_paydox_url';
comment on column ods.account_debt_for_working_capital_1c.dt_receivable_claim is 'Дата выставления претензии | Дата выставления претензии |stg.s1c_debt_for_working_capital.dt_receivable_claim';
comment on column ods.account_debt_for_working_capital_1c.dt_claim_send_to_law_court is 'Дата передачи в суд | Дата передачи в суд |stg.s1c_debt_for_working_capital.dt_claim_send_to_law_court';
comment on column ods.account_debt_for_working_capital_1c.contract_supervisor_name is 'Куратор (ФИО, телефон) | Куратор (ФИО, телефон) |stg.s1c_debt_for_working_capital.contract_supervisor_name';
comment on column ods.account_debt_for_working_capital_1c.contract_supervisor_ad_login_code is 'УЗКуратораДоговора | УЗКуратораДоговора |stg.s1c_debt_for_working_capital.contract_supervisor_ad_login_code';
comment on column ods.account_debt_for_working_capital_1c.general_ledger_account_code is 'Номер счета ГК | Номер счета ГК |stg.s1c_debt_for_working_capital.general_ledger_account_code';
comment on column ods.account_debt_for_working_capital_1c.general_ledger_account_name is 'Название счета ГК | Название счета ГК |stg.s1c_debt_for_working_capital.general_ledger_account_name';
comment on column ods.account_debt_for_working_capital_1c.dt_contract_registration is 'Дата договора | Дата договора |stg.s1c_debt_for_working_capital.dt_contract_registration';
comment on column ods.account_debt_for_working_capital_1c.document_currency_amount is 'Сумма документа | Сумма документа |stg.s1c_debt_for_working_capital.document_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.contract_supervisor_employee_1c_number is 'Табельный номер куратора договора в кодировке 1С | Табельный номер куратора договора в кодировке 1С |stg.s1c_debt_for_working_capital.contract_supervisor_employee_1c_number';
comment on column ods.account_debt_for_working_capital_1c.contract_supervisor_employee_sap_number is 'Табельный номер куратора договора в кодировке SAP ERP | Табельный номер куратора договора в кодировке SAP ERP |stg.s1c_debt_for_working_capital.contract_supervisor_employee_sap_number';
comment on column ods.account_debt_for_working_capital_1c.sales_market_code is 'Рынок сбыта, код | Рынок сбыта, код |stg.s1c_debt_for_working_capital.sales_market_code';
comment on column ods.account_debt_for_working_capital_1c.sales_market_name is 'Рынок сбыта, название | Рынок сбыта, название |stg.s1c_debt_for_working_capital.sales_market_name';
comment on column ods.account_debt_for_working_capital_1c.bad_debt_provision_amount is 'Резерв, сумма | Резерв, сумма |stg.s1c_debt_for_working_capital.bad_debt_provision_amount';
comment on column ods.account_debt_for_working_capital_1c.bad_debt_provision_currency_code is 'Резерв, валюта | Резерв, валюта |stg.s1c_debt_for_working_capital.bad_debt_provision_currency_code';
comment on column ods.account_debt_for_working_capital_1c.credit_limit_rub_currency_amount is 'Кредитный лимит (Сумма, руб) | Кредитный лимит (Сумма, руб) |stg.s1c_debt_for_working_capital.credit_limit_rub_currency_amount';
comment on column ods.account_debt_for_working_capital_1c.dt_credit_limit_valid_to is 'Кредитный лимит (Дата окончания) | Кредитный лимит (Дата окончания) |stg.s1c_debt_for_working_capital.dt_credit_limit_valid_to';
comment on column ods.account_debt_for_working_capital_1c.paydox_credit_limit_url is 'Кредитный лимит (Карточка PD) | Кредитный лимит (Карточка PD) |stg.s1c_debt_for_working_capital.paydox_credit_limit_url';
comment on column ods.account_debt_for_working_capital_1c.insured_amount is 'Страхование, сумма | Страхование, сумма |stg.s1c_debt_for_working_capital.insured_amount';
comment on column ods.account_debt_for_working_capital_1c.insurance_currency_code is 'Страхование, валюта | Страхование, валюта |stg.s1c_debt_for_working_capital.insurance_currency_code';
comment on column ods.account_debt_for_working_capital_1c.dt_insurance_valid_to is 'Страхование, дата окончания | Страхование, дата окончания |stg.s1c_debt_for_working_capital.dt_insurance_valid_to';
comment on column ods.account_debt_for_working_capital_1c.insurance_company_mdm_code is 'Страхование, партнёр (МДМ-ID) | Страхование, партнёр (МДМ-ID) |stg.s1c_debt_for_working_capital.insurance_company_mdm_code';
comment on column ods.account_debt_for_working_capital_1c.bank_guarantee_amount is 'Банковская гарантия, сумма | Банковская гарантия, сумма |stg.s1c_debt_for_working_capital.bank_guarantee_amount';
comment on column ods.account_debt_for_working_capital_1c.bank_guarantee_currency_code is 'Банковская гарантия, валюта | Банковская гарантия, валюта |stg.s1c_debt_for_working_capital.bank_guarantee_currency_code';
comment on column ods.account_debt_for_working_capital_1c.dt_bank_guarantee_valid_to is 'Банковская гарантия, дата окончания | Банковская гарантия, дата окончания |stg.s1c_debt_for_working_capital.dt_bank_guarantee_valid_to';
comment on column ods.account_debt_for_working_capital_1c.bank_guarantee_mdm_code is 'Банковская гарантия, партнер (MDM-ID) | Банковская гарантия, партнер (MDM-ID) |stg.s1c_debt_for_working_capital.bank_guarantee_mdm_code';
comment on column ods.account_debt_for_working_capital_1c.third_party_guarantee_amount is 'Поручительство, сумма | Поручительство, сумма |stg.s1c_debt_for_working_capital.third_party_guarantee_amount';
comment on column ods.account_debt_for_working_capital_1c.third_party_guarantee_currency_code is 'Поручительство, валюта | Поручительство, валюта |stg.s1c_debt_for_working_capital.third_party_guarantee_currency_code';
comment on column ods.account_debt_for_working_capital_1c.dt_third_party_guarantee_valid_to is 'Поручительство, дата окончания | Поручительство, дата окончания |stg.s1c_debt_for_working_capital.dt_third_party_guarantee_valid_to';
comment on column ods.account_debt_for_working_capital_1c.third_party_guarantee_mdm_code is 'Поручительство, партнер (MDM-ID) | Поручительство, партнер (MDM-ID) |stg.s1c_debt_for_working_capital.third_party_guarantee_mdm_code';
