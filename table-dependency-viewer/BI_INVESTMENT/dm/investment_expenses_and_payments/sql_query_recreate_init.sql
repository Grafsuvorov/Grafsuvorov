drop table if exists dm.investment_expenses_and_payments cascade;
----------------------------------------------------------------------------------------------------------------CREATE DM
--CREATE TABLE userdata.dm_investment_expenses (
CREATE TABLE dm.investment_expenses_and_payments (
	unit_budget_code	varchar(7) not null,
	unit_budget_name	varchar(40),
	unit_balance_code	varchar(4),
	measure_type_code	varchar(9) not null,
	investment_budget_section_code	varchar(2),
	investment_budget_section_name	varchar(40),
	investment_budget_subsection_code	varchar(3),
	investment_budget_subsection_name	varchar(40),
	version_code	varchar(3) not null,
	version_name	varchar(60),
	fiscal_year	numeric(4) not null,
	division_code	varchar(2),
	division_name	varchar(40),
	is_additional_finance_code	varchar(1),
	is_additional_finance_name	varchar(20),
	unit_budget_partner_code	varchar(7),
	unit_budget_partner_name	varchar(40),
	unit_balance_partner_code	varchar(4),
	counterparty_of_unit_budget_partner_code	varchar(11),
	alternative_counterparty_of_unit_budget_partner_code	varchar(11),
	unit_budget_partner_hfm_code	varchar(10),
	counterparty_of_unit_budget_partner_hfm_code	varchar(10),
	investment_activity_internal_code	varchar(24) not null,
	investment_activity_external_code	varchar(24)  null,
	investment_activity_name	varchar(360),
	investment_area_code	varchar(24),
	investment_area_name	varchar(360),
	purchase_document_code	varchar(14),
	investment_budget_adjustment_number	varchar(12),
	investment_activity_status_code	varchar(2),
	investment_activity_status_name	varchar(20),
	financing_status_code	varchar(1),
	financing_status_name	varchar(20),
	budget_group_code varchar(2) null,
	cost_element_code varchar (10),
	budget_group_name varchar(300),
	cost_element_name varchar(120),
	amount	numeric(17,2),
	amount_currency_code	varchar(5),
	usd_amount	numeric(17,2),
	dt_report	date not null,
	dt_investment_expense_or_payment date,
	dt_created date,
	created_by varchar(12),
	unit_budget_payer_code varchar(7),
	unit_budget_payer_name varchar(40),
	plant_code	varchar(4),
	counterparty_of_unit_budget_partner_truncated_code varchar(10) null,
	counterparty_of_unit_budget_partner_search_name varchar(311) null,
	unit_balance_name varchar(75) null,
	unit_balance_partner_name varchar(75) null,
	investment_program_code varchar(5) null,
	investment_program_name varchar(60) null,
	counterparty_code varchar(10),
	counterparty_hfm_code varchar(10),
    counterparty_truncated_code varchar(10) null,
    counterparty_search_name varchar(311) null,
    unit_budget_isuip_code varchar(4) null,
    unit_budget_isuip_name varchar(60) null,
    unit_budget_isuip_short_name varchar(60) null,
    investment_activity_isuip_internal_code varchar(10) null,
    investment_budget_subsection_isuip_code varchar(4) null,
    investment_budget_subsection_isuip_name varchar(30) null,
    investment_budget_section_isuip_name varchar(30) null,
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
DISTRIBUTED by  (investment_activity_internal_code ,dt_investment_expense_or_payment , amount_currency_code, dt_created);

----------------------------------------------------------------------------------------------------------------COMMENT DM
comment on table 	dm.investment_expenses_and_payments is 'Инвестиционные показатели из SAP BI';
comment on column dm.investment_expenses_and_payments.unit_budget_code is 'ПБЕ | ПБЕ | ZPBE';
comment on column dm.investment_expenses_and_payments.unit_budget_name is 'ПБЕ, текст | ПБЕ, текст | ZPBE (текст средней длины)';
comment on column dm.investment_expenses_and_payments.unit_balance_code is 'ПБЕ, SAP ERP БЕ | ПБЕ, SAP ERP БЕ | ZPBE.0COMPCODE';
comment on column dm.investment_expenses_and_payments.measure_type_code is 'Вид показателя | Вид показателя | ZKF';
comment on column dm.investment_expenses_and_payments.investment_budget_section_code is 'Раздел ИБ, код | Раздел ИБ, код | ZSECT_GR';
comment on column dm.investment_expenses_and_payments.investment_budget_section_name is 'Раздел ИБ, текст | Раздел ИБ, текст | ZSECT_GR (стандартный текст)';
comment on column dm.investment_expenses_and_payments.investment_budget_subsection_code is 'Подраздел ИБ, код | Подраздел ИБ, код | ZSECTION';
comment on column dm.investment_expenses_and_payments.investment_budget_subsection_name is 'Подраздел ИБ, текст | Подраздел ИБ, текст | ZSECTION  (стандартный текст)';
comment on column dm.investment_expenses_and_payments.version_code is 'Версия данных, код | Версия данных, код | ZVERSION';
comment on column dm.investment_expenses_and_payments.version_name is 'Версия данных, текст | Версия данных, текст | ZVERSION (подробный текст)';
comment on column dm.investment_expenses_and_payments.fiscal_year is 'Год | Год | 0FISCYEAR';
comment on column dm.investment_expenses_and_payments.division_code is 'Дивизион, код | Дивизион, код | ZDIVISION';
comment on column dm.investment_expenses_and_payments.division_name is 'Дивизион, текст | Дивизион, текст | ZDIVISION  (текст средней длины)';
comment on column dm.investment_expenses_and_payments.is_additional_finance_code is 'Дофинансирование, код | Дофинансирование, код | ZADDFUNDF';
comment on column dm.investment_expenses_and_payments.is_additional_finance_name is 'Дофинансирование, текст | Дофинансирование, текст | ZADDFUNDF (стандартный текст)';
comment on column dm.investment_expenses_and_payments.unit_budget_partner_code is 'Контрагент, код BI | Контрагент, код BI | ZPBE_P';
comment on column dm.investment_expenses_and_payments.unit_budget_partner_name is 'Контрагент, имя | Контрагент, имя | ZPBE_P (текст средней длины)';
comment on column dm.investment_expenses_and_payments.unit_balance_partner_code is 'Контрагент, SAP ERP БЕ | Контрагент, SAP ERP БЕ | ZPBE_P.0COMPCODE';
comment on column dm.investment_expenses_and_payments.counterparty_of_unit_budget_partner_code is 'Контрагент, SAP ERP код | Контрагент, SAP ERP код | ZPBE_P.zcompany';
comment on column dm.investment_expenses_and_payments.alternative_counterparty_of_unit_budget_partner_code is 'Контрагент, SAP ERP код филиала | Контрагент, SAP ERP код филиала | ZPBE_P.zcompanya';
comment on column dm.investment_expenses_and_payments.unit_budget_partner_hfm_code is 'ПБЕ-партнер, код HFM | ПБЕ-партнер, код HFM | ZPBE_P.zhfm';
comment on column dm.investment_expenses_and_payments.counterparty_of_unit_budget_partner_hfm_code is 'Контрагент, код HFM | Контрагент, код HFM | ZPBE_P.zhfm';
comment on column dm.investment_expenses_and_payments.investment_activity_internal_code is 'ИМ, внутренний код | ИМ, внутренний код | ZINVACTVT';
comment on column dm.investment_expenses_and_payments.investment_activity_external_code is 'ИМ, внешний код | ИМ, внешний код | ZIMACTCOD';
comment on column dm.investment_expenses_and_payments.investment_activity_name is 'ИМ, название | ИМ, название | ZINVACTVT.ZTXT1 + ZINVACTVT.ZTXT2 + ZINVACTVT.ZTXT3';
comment on column dm.investment_expenses_and_payments.investment_area_code is 'Направление, код | Направление, код | ZIMINVDIR';
comment on column dm.investment_expenses_and_payments.investment_area_name is 'Направление, название | Направление, название | ZIMINVDIR.ZTXT1 + ZIMINVDIR.ZTXT2 + ZIMINVDIR.ZTXT3';
comment on column dm.investment_expenses_and_payments.purchase_document_code is 'Номер документа | Номер документа | ZKN_DOCNO';
comment on column dm.investment_expenses_and_payments.investment_budget_adjustment_number is 'Номер корректировки | Номер корректировки | ZIM_CORR';
comment on column dm.investment_expenses_and_payments.investment_activity_status_code is 'Статус ИМ, код | Статус ИМ, код | ZIMSTATUS';
comment on column dm.investment_expenses_and_payments.investment_activity_status_name is 'Статус ИМ, название | Статус ИМ, название | ZIMSTATUS  (стандартный текст)';
comment on column dm.investment_expenses_and_payments.financing_status_code is 'Статус финансирования, код | Статус финансирования, код | ZIMRESERV';
comment on column dm.investment_expenses_and_payments.financing_status_name is 'Статус финансирования, название | Статус финансирования, название | ZIMRESERV (краткий текст)';
comment on column dm.investment_expenses_and_payments.budget_group_code is 'Код статьи бюджета, код | Код статьи бюджета, код | ZIM_ITEM';
comment on column dm.investment_expenses_and_payments.cost_element_code is 'Вид затрат, код | Вид затрат, код | ZCOSTELMT';
comment on column dm.investment_expenses_and_payments.budget_group_name is 'Код статьи бюджета, название | Код статьи бюджета, название  | ZIM_ITEM';
comment on column dm.investment_expenses_and_payments.cost_element_name is 'Вид затрат, название | Вид затрат, название | ZCOSTELMT';
comment on column dm.investment_expenses_and_payments.amount is 'Сумма | Сумма | 0AMOUNT';
comment on column dm.investment_expenses_and_payments.amount_currency_code is 'Валюта | Валюта | CURRENCY';
comment on column dm.investment_expenses_and_payments.usd_amount is 'Сумма в приведённых долларах | Сумма в приведённых долларах | 0AMOUNT';
comment on column dm.investment_expenses_and_payments.dt_report is 'Месяц | Месяц | 0FISCPER';
comment on column dm.investment_expenses_and_payments.dt_investment_expense_or_payment is 'Календарный день | Календарный день | CALDAY';
comment on column dm.investment_expenses_and_payments.dt_created is 'Дата изменения | Дата изменения | AEDAT';
comment on column dm.investment_expenses_and_payments.created_by is 'Имя пользователя | Имя пользователя | USERNAME';
comment on column dm.investment_expenses_and_payments.unit_budget_payer_code is 'ПБЕ-плательщик | ПБЕ-плательщик | ZPBE_PAY';
comment on column dm.investment_expenses_and_payments.unit_budget_payer_name is 'ПБЕ-плательщик, имя | ПБЕ-плательщик, имя  | ZPBE_P (текст средней длины)';
comment on column dm.investment_expenses_and_payments.plant_code is 'Завод | Завод | ZPBE.0PLANT';
comment on column dm.investment_expenses_and_payments.counterparty_of_unit_budget_partner_truncated_code is 'Контрагент (код для фильтрации)| Контрагент (код для фильтрации) | dict_dds.counterparty.counterparty_truncated_code';
comment on column dm.investment_expenses_and_payments.counterparty_of_unit_budget_partner_search_name is 'Контрагент (код+имя для фильтрации)| Контрагент (код+имя для фильтрации) | dict_dds.counterparty.counterparty_search_name';
comment on column dm.investment_expenses_and_payments.unit_balance_name is 'БЕ название| БЕ название | dict_dds.unit_balance.unit_balance_name';
comment on column dm.investment_expenses_and_payments.unit_balance_partner_name is 'БЕ-партнера название| БЕ-партнера название | dict_dds.unit_balance.unit_balance_name';
comment on column dm.investment_expenses_and_payments.investment_program_code is 'Инвестиционная программа, код | Инвестиционная программа, код | dict_dds.investment_activity_td.investment_program_code';
comment on column dm.investment_expenses_and_payments.investment_program_name is 'Инвестиционная программа, наименование | Инвестиционная программа, наименование | dict_dds.investment_program_texts.investment_program_full_name';
comment on column dm.investment_expenses_and_payments.counterparty_code is 'Юрлицо-партнер | Юрлицо-партнер | ZCOMPANYP';
comment on column dm.investment_expenses_and_payments.counterparty_hfm_code is 'Контрагент, код HFM | Контрагент, код HFM | ZPBE_P.zhfm';
comment on column dm.investment_expenses_and_payments.counterparty_truncated_code is 'Контрагент (код для фильтрации)| Контрагент (код для фильтрации) | dict_dds.counterparty.counterparty_truncated_code';
comment on column dm.investment_expenses_and_payments.counterparty_search_name is 'Контрагент (код+имя для фильтрации)| Контрагент (код+имя для фильтрации) | dict_dds.counterparty.counterparty_search_name';
comment on column dm.investment_expenses_and_payments.unit_budget_isuip_code is 'ПБЕ, ИСУИП код| ПБЕ, ИСУИП код | dict_dds.unit_budget.unit_budget_isuip_code';
comment on column dm.investment_expenses_and_payments.unit_budget_isuip_name is 'ПБЕ, ИСУИП название | ПБЕ, ИСУИП название | dict_dds.unit_budget_texts_td.unit_budget_isuip_full_name';
comment on column dm.investment_expenses_and_payments.unit_budget_isuip_short_name is 'ПБЕ, ИСУИП короткое название | ПБЕ, ИСУИП короткое название | dict_dds.unit_budget_texts_td.unit_budget_isuip_short_name';
comment on column dm.investment_expenses_and_payments.investment_activity_isuip_internal_code is 'ИМ, ИСУИП код| ИМ, ИСУИП код | dict_stg."viewForDWHIMCards".ID';
comment on column dm.investment_expenses_and_payments.investment_budget_subsection_isuip_code is 'ИМ, ИСУИП подраздел, код | ИМ, ИСУИП подраздел, код | StrategicSubsectionCode.StrategicSubsectionCode';
comment on column dm.investment_expenses_and_payments.investment_budget_subsection_isuip_name is 'ИМ, ИСУИП подраздел, название| ИМ, ИСУИП подраздел, название | StrategicSectionsSectionsSectionsLink.StrategicSectionName';
comment on column dm.investment_expenses_and_payments.investment_budget_section_isuip_name is 'ИМ, ИСУИП раздел, название | ИМ, ИСУИП раздел, название | StrategicSectionsSectionsSectionsLink.StrategicSectionName';
