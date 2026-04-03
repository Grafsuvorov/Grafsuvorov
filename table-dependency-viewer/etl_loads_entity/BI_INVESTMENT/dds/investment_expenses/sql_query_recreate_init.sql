drop table if exists dds.investment_expenses;
----------------------------------------------------------------------------------------------------------------CREATE
--CREATE TABLE userdata.investment_expenses (
CREATE TABLE if not exists dds.investment_expenses (
	unit_budget_code varchar(7) not null,
	measure_type_code varchar(9) not null,
	investment_budget_section_code varchar(2),
	investment_budget_subsection_code varchar(3),
	version_code varchar(3) not null,
	fiscal_year numeric(4,0),
	division_code varchar(2),
	is_additional_finance_code varchar(1),
	unit_budget_partner_code varchar(7),
	investment_activity_code varchar(24) not null,
	investment_area_code varchar(24),
	purchase_document_code varchar(14),
	investment_budget_adjustment_number varchar(12),
	investment_activity_status_code varchar(2),
	financing_status_code varchar(1),
	budget_group_code varchar(2) null,
	amount numeric(17,2),
	amount_currency_code varchar(5),
	dt_report date not null , 
	dt_investment_expense_or_payment date,
	dt_created date,
	created_by varchar(12),
	counterparty_code varchar(10),
	unit_budget_payer_code varchar(7),
	dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	dttm_updated	timestamp	NOT NULL DEFAULT now(),
	job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,	
	deleted_flag	bool	NOT NULL DEFAULT false
)
WITH (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 1
)
DISTRIBUTED by  (investment_activity_code ,dt_investment_expense_or_payment , amount_currency_code, dt_created);

----------------------------------------------------------------------------------------------------------------COMMENT
comment on table dds.investment_expenses is 'Инвестиционные показатели из SAP BI';
comment on column dds.investment_expenses.unit_budget_code is 'ПБЕ | ПБЕ | ZPBE';
comment on column dds.investment_expenses.measure_type_code is 'Вид показателя | Вид показателя | ZKF';
comment on column dds.investment_expenses.investment_budget_section_code is 'Раздел ИБ, код | Раздел ИБ, код | ZSECT_GR';
comment on column dds.investment_expenses.investment_budget_subsection_code is 'Подраздел ИБ, код | Подраздел ИБ, код | ZSECTION';
comment on column dds.investment_expenses.version_code is 'Версия данных, код | Версия данных, код | ZVERSION';
comment on column dds.investment_expenses.fiscal_year is 'Год | Год | FISCYEAR';
comment on column dds.investment_expenses.division_code is 'Дивизион, код | Дивизион, код | ZDIVISION';
comment on column dds.investment_expenses.is_additional_finance_code is 'Дофинансирование, код | Дофинансирование, код | ZADDFUNDF';
comment on column dds.investment_expenses.unit_budget_partner_code is 'Контрагент, код BI | Контрагент, код BI | ZPBE_P';
comment on column dds.investment_expenses.investment_activity_code is 'ИМ, внутренний код | ИМ, внутренний код | ZINVACTVT';
comment on column dds.investment_expenses.investment_area_code is 'Направление, код | Направление, код | ZIMINVDIR';
comment on column dds.investment_expenses.purchase_document_code is 'Номер документа | Номер документа | ZKN_DOCNO';
comment on column dds.investment_expenses.investment_budget_adjustment_number is 'Номер корректировки | Номер корректировки | ZIM_CORR';
comment on column dds.investment_expenses.investment_activity_status_code is 'Статус ИМ, код | Статус ИМ, код | ZIMSTATUS';
comment on column dds.investment_expenses.financing_status_code is 'Статус финансирования, код | Статус финансирования, код | ZIMRESERV';
comment on column dds.investment_expenses.budget_group_code is 'Статья бюджета, код | Статья бюджета, код | ZIM_ITEM';
comment on column dds.investment_expenses.amount is 'Сумма | Сумма | AMOUNT';
comment on column dds.investment_expenses.amount_currency_code is 'Валюта | Валюта | CURRENCY';
comment on column dds.investment_expenses.dt_report is 'Месяц | Месяц | FISCPER';
comment on column dds.investment_expenses.dt_investment_expense_or_payment is 'Календарный день | Календарный день | CALDAY';
comment on column dds.investment_expenses.dt_created is 'Дата изменения | Дата изменения | AEDAT';
comment on column dds.investment_expenses.created_by is 'Имя пользователя | Имя пользователя | USERNAME';
comment on column dds.investment_expenses.counterparty_code is 'Юрлицо-партнер | Юрлицо-партнер | ZCOMPANYP';
comment on column dds.investment_expenses.unit_budget_payer_code is 'ПБЕ-плательщик | ПБЕ-плательщик | ZPBE_PAY';
