DROP TABLE IF EXISTS dds.tax_accruals_and_payments_aggregated cascade;
create  table dds.tax_accruals_and_payments_aggregated (
	tax_code varchar(12) not null,
	tax_budget_fund_receiver_code varchar(12),
	accrual_type_code varchar(3) not null,
	unit_budget_code varchar(7) not null,
	local_currency_amount numeric(17,2),
	local_currency_code varchar(5) not null,
	movement_type_code varchar(15),
	dt_report date not null,
	fiscal_year numeric(4,0),
	version_code varchar(3),
	dt_report_yyyyq varchar(5),
	tax_oktmo_code varchar(12),
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
distributed by (tax_code,dt_report ,unit_budget_code);
----------------------------------------------------------------------------------------------------------------COMMENT
comment on
table dds.tax_accruals_and_payments_aggregated is 'Налоговые показатели из SAP BI';

comment on
column dds.tax_accruals_and_payments_aggregated.tax_code is 'Налог (сбор), код | Налог (сбор), код | ztx_tax';

comment on
column dds.tax_accruals_and_payments_aggregated.tax_budget_fund_receiver_code is 'Бюджет (фонд), код | Бюджет (фонд), код | ztx_bud';

comment on
column dds.tax_accruals_and_payments_aggregated.accrual_type_code is 'Вид начисления, код | Вид начисления, код | ztx_ntype';

comment on
column dds.tax_accruals_and_payments_aggregated.unit_budget_code is 'ПБЕ, код | ПБЕ, код | zpbe';

comment on
column dds.tax_accruals_and_payments_aggregated.local_currency_amount is 'Сумма | Сумма | amount';

comment on
column dds.tax_accruals_and_payments_aggregated.local_currency_code is 'Валюта | Валюта | currency';

comment on
column dds.tax_accruals_and_payments_aggregated.movement_type_code is 'Вид движения, код | Вид движения, код | zmovetype';

comment on
column dds.tax_accruals_and_payments_aggregated.dt_report is 'Год/Период | Год/Период | fiscper';

comment on
column dds.tax_accruals_and_payments_aggregated.fiscal_year is 'ФГ | ФГ | fiscyear';

comment on
column dds.tax_accruals_and_payments_aggregated.version_code is 'Версия | Версия | zversion';

comment on
column dds.tax_accruals_and_payments_aggregated.dt_report_yyyyq is 'Год/Квартал | Год/Квартал | calquarter';

comment on
column dds.tax_accruals_and_payments_aggregated.tax_oktmo_code is 'Территория, код | Территория, код | ztx_mbud';


