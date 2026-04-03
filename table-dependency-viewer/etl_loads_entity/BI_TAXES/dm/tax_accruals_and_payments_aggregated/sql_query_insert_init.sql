insert
	into
	dm.tax_accruals_and_payments_aggregated(
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
	tax_oktmo_name) 
select
	ta.tax_code,
	tht.tax_full_name as tax_name,
	ta.tax_budget_fund_receiver_code,
	tbfrt.tax_budget_fund_receiver_full_name as tax_budget_fund_receiver_name,
	ta.accrual_type_code,
	att.accrual_type_full_name as accrual_type_name,
	ta.unit_budget_code,
	ubtt.unit_budget_extended_name as unit_budget_name,
	ta.local_currency_amount,
	ta.local_currency_code,
	
	(ta.local_currency_amount * coalesce(cr.currency_to_multiplier,1) * case 
		when coalesce(cr.currency_rate, 1) > 0 
		then coalesce(cr.currency_rate, 1) 
		else 1 
	end / (case 
		when coalesce(cr.currency_rate, 1) < 0 
		then abs(coalesce(cr.currency_rate,1)) 
		else 1 
	end * coalesce(cr.currency_from_multiplier,1))
	)::numeric(17,2) as version_rate_usd_amount,	
	
	(ta.local_currency_amount * coalesce(cr_bp.currency_to_multiplier,1) * case 
		when coalesce(cr_bp.currency_rate, 1) > 0 
		then coalesce(cr_bp.currency_rate, 1) 
		else 1 
	end / (case 
		when coalesce(cr_bp.currency_rate, 1) < 0 
		then abs(coalesce(cr_bp.currency_rate,1)) 
		else 1 
	end * coalesce(cr_bp.currency_from_multiplier,1))
	)::numeric(17,2) as business_plan_rate_usd_amount,
	
	(ta.local_currency_amount * coalesce(cr_plan.currency_to_multiplier,1) * case 
		when coalesce(cr_plan.currency_rate, 1) > 0 
		then coalesce(cr_plan.currency_rate, 1) 
		else 1 
	end / (case 
		when coalesce(cr_plan.currency_rate, 1) < 0 
		then abs(coalesce(cr_plan.currency_rate,1)) 
		else 1 
	end * coalesce(cr_plan.currency_from_multiplier,1))
	)::numeric(17,2) as active_plan_rate_usd_amount,
	
	(ta.local_currency_amount * coalesce(cr_fact.currency_to_multiplier,1) * case 
		when coalesce(cr_fact.currency_rate, 1) > 0 
		then coalesce(cr_fact.currency_rate, 1) 
		else 1 
	end / (case 
		when coalesce(cr_fact.currency_rate, 1) < 0 
		then abs(coalesce(cr_fact.currency_rate,1)) 
		else 1 
	end * coalesce(cr_fact.currency_from_multiplier,1))
	)::numeric(17,2) as actual_rate_usd_amount,
	
	ta.movement_type_code,
	tvt.tax_movement_type_full_name as movement_type_name,
	ta.dt_report,
	ta.fiscal_year,
	ta.version_code,
	ta.dt_report_yyyyq,
	ub.counterparty_code as unit_budget_counterparty_code,
	c.counterparty_full_name as unit_budget_counterparty_name,
	ta.tax_oktmo_code,
	tot.tax_oktmo_full_name as tax_oktmo_name
from
	dds.tax_accruals_and_payments_aggregated ta
left join dict_dds.document_version dv
	on	dv.version_code = ta.version_code
left join dict_dds.currency_rates cr
	on	cr.currency_from_code = ta.local_currency_code
--		and cr.dt_currency_rate <=  ta.dt_report
		and cr.dt_currency_rate = (
				case when ta.version_code = '003'
				then ta.dt_report
				when ta.version_code = '002'
				then ta.dt_report
				when ta.version_code = '010'
				then (to_date(ta.fiscal_year::varchar, 'YYYY') + interval '1 year' - interval '1 day')::date
				else to_date(ta.fiscal_year::varchar, 'YYYY')
				end) 
		and cr.currency_rate_type_code = dv.currency_rate_type_code
		and cr.deleted_flag = false
		and cr.currency_to_code = 'USD'
left join dict_dds.currency_rates as cr_fact on
		cr_fact.deleted_flag = false
	and cr_fact.currency_rate_type_code = 'M2'
	and cr_fact.currency_to_code = 'USD'
	and cr_fact.currency_from_code = ta.local_currency_code
	and cr_fact.dt_currency_rate = ta.dt_report
left join dict_dds.currency_rates as cr_plan on
		cr_plan.deleted_flag = false
	and cr_plan.currency_rate_type_code = 'P'
	and cr_plan.currency_to_code = 'USD'
	and cr_plan.currency_from_code = ta.local_currency_code
	and cr_plan.dt_currency_rate = ta.dt_report
left join dict_dds.currency_rates as cr_bp on
		cr_bp.deleted_flag = false
	and cr_bp.currency_rate_type_code = 'F10'
	and cr_bp.currency_to_code = 'USD'
	and cr_bp.currency_from_code = ta.local_currency_code
	and cr_bp.dt_currency_rate = (to_date(ta.fiscal_year::varchar, 'YYYY') + interval '1 year' - interval '1 day')::date
left join dict_dds.unit_budget ub on
	ub.unit_budget_code = ta.unit_budget_code
left join dict_dds.unit_budget_texts_td ubtt on
	ta.unit_budget_code = ubtt.unit_budget_code
	and  ubtt.dt_valid_from <= ta.dt_report
	and ubtt.dt_valid_to >= ta.dt_report
	and ubtt.language_code = 'R'
left join dict_dds.tax_oktmo_texts tot on
	tot.tax_oktmo_code = ta.tax_oktmo_code
	and tot.language_code = 'R'
left join dict_dds.counterparty c on
	c.counterparty_code = ub.counterparty_code
left join dict_dds.tax_movement_type_texts tvt on
	tvt.tax_movement_type_code = ta.movement_type_code
	and tvt.language_code = 'R'
	and tvt.tax_movement_type_category_code = 'TX'
left join dict_dds.tax_budget_fund_receiver_texts tbfrt on
	tbfrt.tax_budget_fund_receiver_code = ta.tax_budget_fund_receiver_code
	and tbfrt.language_code = 'R'
left join dict_dds.tax_hierarchy_texts_td tht on
	tht.tax_code = ta.tax_code
	and tht.language_code = 'R'
	and tht.dt_valid_from <= ta.dt_report
	and tht.dt_valid_to >= ta.dt_report
left join dict_dds.accrual_type_texts att on
	att.accrual_type_code = ta.accrual_type_code
	and att.language_code = 'R'
where ta.dttm_inserted
    in (select max(dttm_inserted) from dds.tax_accruals_and_payments_aggregated);