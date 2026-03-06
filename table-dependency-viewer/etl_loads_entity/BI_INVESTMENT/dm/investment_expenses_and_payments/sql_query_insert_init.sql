insert into dm.investment_expenses_and_payments(
	unit_budget_code,
	unit_budget_name,
	unit_balance_code,
	measure_type_code,
	investment_budget_section_code,
	investment_budget_section_name,
	investment_budget_subsection_code,
	investment_budget_subsection_name,
	version_code,
	version_name,
	fiscal_year,
	division_code,
	division_name,
	is_additional_finance_code,
	is_additional_finance_name,
	unit_budget_partner_code,
	unit_budget_partner_name,
	unit_balance_partner_code,
	counterparty_of_unit_budget_partner_code,
	alternative_counterparty_of_unit_budget_partner_code,
	unit_budget_partner_hfm_code,
	counterparty_of_unit_budget_partner_hfm_code,
	investment_activity_internal_code,
	investment_activity_external_code,
	investment_activity_name,
	investment_area_code,
	investment_area_name,
	purchase_document_code,
	investment_budget_adjustment_number,
	investment_activity_status_code,
	investment_activity_status_name,
	financing_status_code,
	financing_status_name,
	budget_group_code,
	cost_element_code,
	budget_group_name,
	cost_element_name,
	amount,
	amount_currency_code,
	usd_amount,
	dt_report,
	dt_investment_expense_or_payment,
	dt_created,
	created_by,
	unit_budget_payer_code,
	unit_budget_payer_name,
	plant_code,
	counterparty_of_unit_budget_partner_truncated_code,
	counterparty_of_unit_budget_partner_search_name,
	unit_balance_name,
	unit_balance_partner_name,
	investment_program_code,
	investment_program_name,
	counterparty_code,
	counterparty_hfm_code,
    counterparty_truncated_code,
    counterparty_search_name,
    unit_budget_isuip_code,
    unit_budget_isuip_name,
    unit_budget_isuip_short_name,
    investment_activity_isuip_internal_code,
    investment_budget_subsection_isuip_code,
    investment_budget_subsection_isuip_name,
    investment_budget_section_isuip_name
	)
select 
	ie.unit_budget_code,
	ubt_dt.unit_budget_full_name	as unit_budget_name,
	ub.unit_balance_code	as unit_balance_code,
	ie.measure_type_code,
	ie.investment_budget_section_code,
	ibst.investment_budget_section_full_name	as investment_budget_section_name,
	ie.investment_budget_subsection_code,
	ibsst.investment_budget_subsection_full_name	as investment_budget_subsection_name,
	ie.version_code,
	dvt.version_extended_name	as version_name,
	ie.fiscal_year,
	ie.division_code,
	dt.division_full_name	as division_name,
	ie.is_additional_finance_code,
	aft.is_additional_finance_name	as is_additional_finance_name,
	ie.unit_budget_partner_code,
	ubt_dtp.unit_budget_full_name	as unit_budget_partner_name,
	ubp.unit_balance_code	as unit_balance_partner_code,
	ubp.counterparty_code	as counterparty_of_unit_budget_partner_code,
	ubp.counterparty_alternative_code	as alternative_counterparty_of_unit_budget_partner_code,
	ubp.hfm_code	as unit_budget_partner_hfm_code,
	ct.counterparty_hfm_code	as counterparty_of_unit_budget_partner_hfm_code,
	ie.investment_activity_code	as investment_activity_internal_code,
	ia_td.investment_activity_external_code	as investment_activity_external_code,		 
	ia_td.investment_activity_extented_name	as investment_activity_name,
	ie.investment_area_code,
	iafa.investment_activity_focus_area_extented_name	as investment_area_name,
	ie.purchase_document_code,
	ie.investment_budget_adjustment_number,
	ie.investment_activity_status_code,
	iast.investment_activity_status_name	as investment_activity_status_name,
	ie.financing_status_code,
	fst.financing_status_name	as financing_status_name,
	ie.budget_group_code,
	bg.cost_element_code,
	bgt.budget_group_name,
	cet.cost_element_full_name as cost_element_name,
	ie.amount,
	ie.amount_currency_code,
		(ie.amount * coalesce(cr.currency_to_multiplier,1) * case 
		when coalesce(cr.currency_rate,1) > 0 
		then coalesce(cr.currency_rate, 1) 
		else 1 
	end / (case 
		when coalesce(cr.currency_rate, 1) < 0 
		then abs(coalesce(cr.currency_rate,1)) 
		else 1 
	end * coalesce(cr.currency_from_multiplier,1))
	)::numeric(17,2) as usd_amount,
	ie.dt_report,
	ie.dt_investment_expense_or_payment,
	ie.dt_created,
	ie.created_by,
	ie.unit_budget_payer_code,
	ubt_dtpa.unit_budget_full_name as unit_budget_payer_name,
	ub.plant_code	as plant_code,
	ct.counterparty_truncated_code as counterparty_of_unit_budget_partner_truncated_code,
    ct.counterparty_search_name as counterparty_of_unit_budget_partner_search_name,
	ub2.unit_balance_name,
	ubc.unit_balance_name	as unit_balance_partner_name,
	ia_td.investment_program_code,
    ipt.investment_program_full_name as investment_program_name,
    ie.counterparty_code,
    ct2.counterparty_hfm_code as counterparty_hfm_code,
    ct2.counterparty_truncated_code,
    ct2.counterparty_search_name,
    ub.unit_budget_isuip_code,
    ubt_dt.unit_budget_isuip_full_name as unit_budget_isuip_name,
    ubt_dt.unit_budget_isuip_short_name,
    iai.investment_activity_isuip_code as investment_activity_isuip_internal_code,
    iai.investment_budget_longterm_forecast_subsection_code as investment_budget_subsection_isuip_code,
    iblfst.investment_budget_longterm_forecast_subsection_name as investment_budget_subsection_isuip_name,
    iblfst2.investment_budget_longterm_forecast_section_name as investment_budget_section_isuip_name
from dds.investment_expenses ie
left join dict_dds.document_version dv
	on	dv.version_code = ie.version_code
left join dict_dds.currency_rates cr  on
	cr.dt_currency_rate = coalesce(ie.dt_investment_expense_or_payment, dt_report)
	and cr.currency_from_code = ie.amount_currency_code
	and cr.deleted_flag = false
	and cr.currency_rate_type_code = dv.currency_rate_type_code
	and cr.currency_to_code = 'USD'

left join dict_dds.additional_finance_texts aft
	on	aft.is_additional_finance_code = ie.is_additional_finance_code
	and aft.language_code = 'R'
left join dict_dds.investment_activity_status_texts iast
	on	iast.investment_activity_status_code = ie.investment_activity_status_code
	and iast.language_code = 'R'
left join dict_dds.financing_status_texts fst
	on	fst.financing_status_code = ie.financing_status_code
	and fst.language_code = 'R'
left join dict_dds.investment_budget_section_texts ibst
	on	ibst.investment_budget_section_code = ie.investment_budget_section_code
	and ibst.language_code = 'R'
left join dict_dds.division_texts dt
	on	dt.division_code = ie.division_code
	and dt.language_code = 'R'
left join dict_dds.document_version_texts dvt
	on	dvt.version_code = ie.version_code
	and dvt.language_code = 'R'
left join dict_dds.investment_budget_subsection_texts ibsst	--
	on	ibsst.investment_budget_subsection_code = ie.investment_budget_subsection_code
	and ibsst.language_code = 'R'
left join dict_dds.unit_budget ub
	on	ub.unit_budget_code = ie.unit_budget_code
left join dict_dds.unit_budget ubp
	on	ubp.unit_budget_code = ie.unit_budget_partner_code
left join dict_dds.unit_budget_texts_td ubt_dt
	on	ubt_dt.unit_budget_code = ie.unit_budget_code
	and ubt_dt.language_code = 'R'
	and ubt_dt.dt_valid_to >= current_date			
	and ubt_dt.dt_valid_from <= current_date
--	and ubt_die.dt_valid_to >= ie.dt_report	and ubt_die.dt_valid_from <= ie.dt_report
left join dict_dds.unit_budget_texts_td ubt_dtp
	on	ubt_dtp.unit_budget_code = ie.unit_budget_partner_code
	and ubt_dtp.language_code = 'R'
	and ubt_dtp.dt_valid_to >= current_date			
	and ubt_dtp.dt_valid_from <= current_date
--	and ubt_die.dt_valid_to >= ie.dt_report	and ubt_die.dt_valid_from <= ie.dt_report
left join dict_dds.unit_budget_texts_td ubt_dtpa
	on	ubt_dtpa.unit_budget_code = ie.unit_budget_payer_code
	and ubt_dtpa.language_code = 'R'
	and ubt_dtpa.dt_valid_to >= current_date			
	and ubt_dtpa.dt_valid_from <= current_date
left join dict_dds.investment_activity_td ia_td
	on	ia_td.investment_activity_code = ie.investment_activity_code
	and ia_td.dt_valid_to >= current_date	and ia_td.dt_valid_from <= current_date
--	and ia_td.dt_valid_to >= ie.dt_report	and ia_td.dt_valid_from <= ie.dt_report
left join dict_dds.investment_activity_focus_area iafa
	--on iafa.investment_activity_external_code = ia_td.investment_activity_external_code 
--	on	iafa.investment_activity_code = ie.investment_activity_code
	on iafa.investment_activity_focus_area_code  = ie.investment_area_code
left join dict_dds.budget_group bg 
	on ie.budget_group_code = ltrim(bg.budget_group_code,'0') 
left join dict_dds.budget_group_texts bgt 
	on ie.budget_group_code = bgt.budget_group_code 
	and bgt.language_code = 'R'
left join dict_dds.unit_balance ub2
	on ub2.unit_balance_code = ub.unit_balance_code 
left join dict_dds.cost_element_texts cet 
	on bg.cost_element_code = cet.cost_element_code 
	and cet.language_code = 'R'
	and cet.account_chart_code = coalesce (ub2.account_chart_code, '1000')
left join dict_dds.counterparty ct on
	ct.counterparty_code = ubp.counterparty_code
left join dict_dds.unit_balance ubc on
	ubc.unit_balance_code = ubp.unit_balance_code
left join dict_dds.investment_program_texts ipt
	on ipt.investment_program_code  = ia_td.investment_program_code
	and ipt.language_code = 'R'
--left join dict_dds.unit_budget ubp2
--	on	ubp2.counterparty_code = ie.counterparty_code
left join dict_dds.counterparty ct2 on
	ct2.counterparty_code = ie.counterparty_code
left join dict_dds.investment_activity_isuip iai on
	iai.investment_activity_external_code = ia_td.investment_activity_external_code 
	and iai.version_name = 'Актуальная'
left join dict_dds.investment_budget_longterm_forecast_subsection_texts iblfst 
	on iblfst.investment_budget_longterm_forecast_subsection_code = iai.investment_budget_longterm_forecast_subsection_code 
left join dict_dds.investment_budget_longterm_forecast_section_texts iblfst2
	on iblfst2.investment_budget_longterm_forecast_section_code = iai.investment_budget_longterm_forecast_section_code
where 
	(ie.version_code in ('010','216','003','008') 
		or ie.version_code between '012' and '090')
	and  ie.dttm_inserted
    in (select max(dttm_inserted) from dds.investment_expenses)
;