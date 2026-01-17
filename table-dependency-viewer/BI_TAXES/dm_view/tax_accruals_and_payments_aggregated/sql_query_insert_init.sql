drop view if exists dm_view.tax_accruals_and_payments_aggregated;   
   
create or replace view dm_view.tax_accruals_and_payments_aggregated
as select 
	tax_code,
	tax_name,
	tax_budget_fund_receiver_code,
	tax_budget_fund_receiver_full_name,
	accrual_type_code,
	accrual_type_name,
	unit_budget_code,
	unit_budget_name,
	local_currency_amount,
	local_currency_code,
	version_rate_usd_amount,
	business_plan_rate_usd_amount,
	active_plan_rate_usd_amount,
	actual_rate_usd_amount,
	movement_type_code,
	movement_type_name,
	dt_report,
	fiscal_year,
	version_code,
	dt_report_yyyyq,
	unit_budget_counterparty_code,
	unit_budget_counterparty_name,
	tax_oktmo_code,
	tax_oktmo_name,
	dttm_inserted,
	dttm_updated,
	job_name,
	deleted_flag
from dm.tax_accruals_and_payments_aggregated;


comment on view dm_view.tax_accruals_and_payments_aggregated is 'Налоговые показатели из SAP BI';
comment on column dm_view.tax_accruals_and_payments_aggregated.tax_code is 'Налог (сбор), код | Налог (сбор), код | ztx_tax';
comment on column dm_view.tax_accruals_and_payments_aggregated.tax_name is 'Налог (сбор), название | Налог (сбор), название | tax_name';
comment on column dm_view.tax_accruals_and_payments_aggregated.tax_budget_fund_receiver_code is 'Бюджет (фонд), код | Бюджет (фонд), код | ztx_bud';
comment on column dm_view.tax_accruals_and_payments_aggregated.tax_budget_fund_receiver_full_name is 'Бюджет (фонд), название | Бюджет (фонд), название | tax_budget_fund_receiver_full_name';
comment on column dm_view.tax_accruals_and_payments_aggregated.accrual_type_code is 'Вид начисления, код | Вид начисления, код | ztx_ntype';
comment on column dm_view.tax_accruals_and_payments_aggregated.accrual_type_name is 'Вид начисления, название | Вид начисления, название| accrual_type_name';
comment on column dm_view.tax_accruals_and_payments_aggregated.unit_budget_code is 'ПБЕ, код | ПБЕ, код | zpbe';
comment on column dm_view.tax_accruals_and_payments_aggregated.unit_budget_name is 'ПБЕ, название | ПБЕ, название | unit_budget_name';
comment on column dm_view.tax_accruals_and_payments_aggregated.local_currency_amount is 'Сумма | Сумма | amount';
comment on column dm_view.tax_accruals_and_payments_aggregated.local_currency_code is 'Валюта | Валюта | currency';
comment on column dm_view.tax_accruals_and_payments_aggregated.version_rate_usd_amount is 'Сумма в USD, по курсу версии | Сумма в USD, по курсу версии | amount';
comment on column dm_view.tax_accruals_and_payments_aggregated.business_plan_rate_usd_amount is 'Сумма в USD, по курсу БП | Сумма в USD, по курсу БП | amount';
comment on column dm_view.tax_accruals_and_payments_aggregated.active_plan_rate_usd_amount is 'Сумма в USD, по курсу ТП | Сумма в USD, по курсу ТП | amount';
comment on column dm_view.tax_accruals_and_payments_aggregated.actual_rate_usd_amount is 'Сумма в USD, по курсу факта | Сумма в USD, по курсу факта | amount';
comment on column dm_view.tax_accruals_and_payments_aggregated.movement_type_code is 'Вид движения, код | Вид движения, код | zmovetype';
comment on column dm_view.tax_accruals_and_payments_aggregated.movement_type_name is 'Вид движения, название | Вид движения, название | movement_type_name';
comment on column dm_view.tax_accruals_and_payments_aggregated.dt_report is 'Год/Период | Год/Период | fiscper';
comment on column dm_view.tax_accruals_and_payments_aggregated.fiscal_year is 'ФГ | ФГ | fiscyear';
comment on column dm_view.tax_accruals_and_payments_aggregated.version_code is 'Версия | Версия | zversion';
comment on column dm_view.tax_accruals_and_payments_aggregated.dt_report_yyyyq is 'Год/Квартал | Год/Квартал | calquarter';
comment on column dm_view.tax_accruals_and_payments_aggregated.unit_budget_counterparty_code is 'Контрагент, код | Контрагент, код | unit_budget_counterparty_code';
comment on column dm_view.tax_accruals_and_payments_aggregated.unit_budget_counterparty_name is 'Контрагент, название| Контрагент, название | unit_budget_counterparty_name';
comment on column dm_view.tax_accruals_and_payments_aggregated.tax_oktmo_code is 'Территория, код | Территория, код | ztx_mbud';
comment on column dm_view.tax_accruals_and_payments_aggregated.tax_oktmo_name is 'Территория, название | Территория, название | tax_oktmo_name';
