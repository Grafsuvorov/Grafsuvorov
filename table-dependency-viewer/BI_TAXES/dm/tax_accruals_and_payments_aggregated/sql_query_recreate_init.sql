drop table if exists dm.tax_accruals_and_payments_aggregated cascade;

create table if not exists dm.tax_accruals_and_payments_aggregated (
	tax_code varchar(12) not null,
	tax_name varchar(60),
	tax_budget_fund_receiver_code varchar(12),
	tax_budget_fund_receiver_full_name  varchar(60) ,
	accrual_type_code varchar(3) not null,
	accrual_type_name varchar(60) ,
	unit_budget_code varchar(7) not null,
	unit_budget_name varchar (60),
	local_currency_amount numeric(17,2),
	local_currency_code varchar(5) not null,
	version_rate_usd_amount numeric(17,2),
	business_plan_rate_usd_amount numeric(17,2),
	active_plan_rate_usd_amount numeric(17,2),
	actual_rate_usd_amount numeric(17,2),
	movement_type_code varchar(15),
	movement_type_name varchar(60),
	dt_report date not null,
	fiscal_year numeric(4),
	version_code varchar(3),
	dt_report_yyyyq varchar(5),
	unit_budget_counterparty_code varchar(10),
	unit_budget_counterparty_name varchar(300),
	tax_oktmo_code varchar(12),
	tax_oktmo_name varchar(60),
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 1
)
DISTRIBUTED by  (tax_code, dt_report , unit_budget_code);
----------------------------------------------------------------------------------------------------------------COMMENT
comment on table dm.tax_accruals_and_payments_aggregated is 'Налоговые показатели из SAP BI';
comment on column dm.tax_accruals_and_payments_aggregated.tax_code is 'Налог (сбор), код | Налог (сбор), код | ztx_tax';
comment on column dm.tax_accruals_and_payments_aggregated.tax_name is 'Налог (сбор), название | Налог (сбор), название | tax_name';
comment on column dm.tax_accruals_and_payments_aggregated.tax_budget_fund_receiver_code is 'Бюджет (фонд), код | Бюджет (фонд), код | ztx_bud';
comment on column dm.tax_accruals_and_payments_aggregated.tax_budget_fund_receiver_full_name is 'Бюджет (фонд), название | Бюджет (фонд), название | tax_budget_fund_receiver_full_name';
comment on column dm.tax_accruals_and_payments_aggregated.accrual_type_code is 'Вид начисления, код | Вид начисления, код | ztx_ntype';
comment on column dm.tax_accruals_and_payments_aggregated.accrual_type_name is 'Вид начисления, название | Вид начисления, название| accrual_type_name';
comment on column dm.tax_accruals_and_payments_aggregated.unit_budget_code is 'ПБЕ, код | ПБЕ, код | zpbe';
comment on column dm.tax_accruals_and_payments_aggregated.unit_budget_name is 'ПБЕ, название | ПБЕ, название | unit_budget_name';
comment on column dm.tax_accruals_and_payments_aggregated.local_currency_amount is 'Сумма | Сумма | amount';
comment on column dm.tax_accruals_and_payments_aggregated.local_currency_code is 'Валюта | Валюта | currency';
comment on column dm.tax_accruals_and_payments_aggregated.version_rate_usd_amount is 'Сумма в USD, по курсу версии | Сумма в USD, по курсу версии | amount';
comment on column dm.tax_accruals_and_payments_aggregated.business_plan_rate_usd_amount is 'Сумма в USD, по курсу БП | Сумма в USD, по курсу БП | amount';
comment on column dm.tax_accruals_and_payments_aggregated.active_plan_rate_usd_amount is 'Сумма в USD, по курсу ТП | Сумма в USD, по курсу ТП | amount';
comment on column dm.tax_accruals_and_payments_aggregated.actual_rate_usd_amount is 'Сумма в USD, по курсу факта | Сумма в USD, по курсу факта | amount';
comment on column dm.tax_accruals_and_payments_aggregated.movement_type_code is 'Вид движения, код | Вид движения, код | zmovetype';
comment on column dm.tax_accruals_and_payments_aggregated.movement_type_name is 'Вид движения, название | Вид движения, название | movement_type_name';
comment on column dm.tax_accruals_and_payments_aggregated.dt_report is 'Год/Период | Год/Период | fiscper';
comment on column dm.tax_accruals_and_payments_aggregated.fiscal_year is 'ФГ | ФГ | fiscyear';
comment on column dm.tax_accruals_and_payments_aggregated.version_code is 'Версия | Версия | zversion';
comment on column dm.tax_accruals_and_payments_aggregated.dt_report_yyyyq is 'Год/Квартал | Год/Квартал | calquarter';
comment on column dm.tax_accruals_and_payments_aggregated.unit_budget_counterparty_code is 'Контрагент, код | Контрагент, код | unit_budget_counterparty_code';
comment on column dm.tax_accruals_and_payments_aggregated.unit_budget_counterparty_name is 'Контрагент, название| Контрагент, название | unit_budget_counterparty_name';
comment on column dm.tax_accruals_and_payments_aggregated.tax_oktmo_code is 'Территория, код | Территория, код | ztx_mbud';
comment on column dm.tax_accruals_and_payments_aggregated.tax_oktmo_name is 'Территория, название | Территория, название | tax_oktmo_name';
