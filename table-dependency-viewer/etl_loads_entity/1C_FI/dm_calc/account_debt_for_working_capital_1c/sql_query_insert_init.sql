insert into dm_calc.account_debt_for_working_capital_1c (
	dt_report,
	unit_balance_mdm_code_1c,
	unit_balance_code,
	posting_uid_code_1c,
	fiscal_year,
	debit_or_credit_code,
	account_type_code,
	dt_accounting_document,
	dt_debt,
	dt_overdue,
	dt_posting,
	position_line_item_text,
	reference_document_number,
	dt_baseline_due_date_calculation,
	general_ledger_account_code,
	general_ledger_account_full_name,
	external_contract_number,
	dt_external_contract,
	counterparty_code,
	counterparty_mdm_code,
	terms_of_payment_name,
	contract_supervisor_employee_number,
	contract_supervisor_user_active_directory_code,	
	contract_supervisor_name,
	final_accouning_document_code,
	final_fiscal_year,
	contract_trader_code,
	contract_trader_name,
	responsibility_center_level1_code,
	country_of_end_user_code,
	material_shape_name,
	receivable_claim_paydox_url,
	dt_receivable_claim,
	bank_receiver_name,
	paydox_document_url,
	document_currency_code,
	local_currency_code,
	document_currency_amount,
	debt_subposition_document_currency_amount,
	debt_balance_subposition_document_currency_amount,
	debt_balance_subposition_local_currency_amount,
	debt_balance_subposition_second_local_currency_amount,
	debt_balance_subposition_usd_amount,
	debt_balance_position_usd_amount,
	debt_balance_subposition_document_currency_to_usd_amount,
	debt_balance_subpos_no_revaluation_local_currency_amount,
	debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	debt_balance_subposition_no_revaluation_usd_amount,
	debt_balance_contract_usd_amount,
	debt_balance_contract_document_currency_to_usd_amount,
	debt_balance_contract_no_revaluation_usd_amount,
	usd_amount,
	database_code_1c,
	database_name_1c
)

with cc as (select 
	c.counterparty_mdm_code,
	c.counterparty_code,
	c.is_deleted,
	DENSE_RANK () OVER (partition by c.counterparty_mdm_code order by c.is_deleted desc, c.counterparty_account_group_code asc) as ranks
from dict_dds.counterparty c)

select
	c.dt_report,
	c.unit_balance_mdm_code_1c,
	case when ubc.unit_balance_code is null then c.sender
	else ubc.unit_balance_code end as unit_balance_code,
	c.posting_uid_code_1c,
	extract(YEAR from c.dt_debt) as fiscal_year,
	case when c.debit_or_credit_name = 'КЗ' then 'H'
		 when c.debit_or_credit_name = 'ДЗ' then 'S'
	end as debit_or_credit_code,
	case when c.counterparty_role_name = 'Поставщик' then 'K'
		 when c.counterparty_role_name = 'Клиент' then 'D'
	else null end as account_type_code,
	c.dt_debt as dt_accounting_document,
	c.dt_debt, 
	c.dt_overdue,
	c.dt_debt as dt_posting,
	c.accounting_document_descriprion_text as position_line_item_text,
	c.invoice_registration_number as reference_document_number,
	c.dt_overdue as dt_baseline_due_date_calculation,
	c.general_ledger_account_code,
	c.general_ledger_account_name as general_ledger_account_full_name,
	c.contract_number as external_contract_number,
	c.dt_contract_registration as dt_external_contract,
	ct.counterparty_code,
	c.counterparty_mdm_code,
	c.terms_of_payment_name,
	c.contract_supervisor_employee_sap_number as contract_supervisor_employee_number,
	c.contract_supervisor_ad_login_code,
	c.contract_supervisor_name,
	c.document_1c_code as final_accouning_document_code,
	extract(YEAR from c.dt_debt) as final_fiscal_year,
	c.contract_supervisor_employee_sap_number as contract_trader_code,
	c.contract_supervisor_name as contract_trader_name,
	c.responsibility_center_hfm_code as responsibility_center_level1_code,
	c.country_of_end_user_code,
	c.finish_goods_group_name as material_shape_name,
	c.receivable_claim_paydox_url,
	c.dt_receivable_claim,
	c.bank_receiver_name,
	c.paydox_document_url,
	c.document_currency_code,
	case when coalesce(c.debt_balance_rub_currency_amount,0) = 0 then null
	else 'RUB' end as local_currency_code,
	case when c.debit_or_credit_name = 'КЗ' then - c.document_currency_amount
		 else c.document_currency_amount
	end as document_currency_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.document_currency_amount
		 else c.document_currency_amount
	end as debt_subposition_document_currency_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_document_currency_amount
		 else c.debt_balance_document_currency_amount
	end as debt_balance_subposition_document_currency_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_rub_currency_amount
		 else c.debt_balance_rub_currency_amount
	end as debt_balance_subposition_local_currency_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as debt_balance_subposition_second_local_currency_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as debt_balance_subposition_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as debt_balance_position_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as debt_balance_subposition_document_currency_to_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_rub_currency_amount
		 else c.debt_balance_rub_currency_amount
	end as debt_balance_subpos_no_revaluation_local_currency_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as debt_balance_subposition_no_revaluation_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - (sum(c.debt_balance_usd_currency_amount) over wdebt)
		 else (sum(c.debt_balance_usd_currency_amount) over wdebt)
	end as debt_balance_contract_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - (sum(c.debt_balance_usd_currency_amount) over wdebt)
		 else (sum(c.debt_balance_usd_currency_amount) over wdebt)
	end as debt_balance_contract_document_currency_to_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - (sum(c.debt_balance_usd_currency_amount) over wdebt)
		 else (sum(c.debt_balance_usd_currency_amount) over wdebt)
	end as debt_balance_contract_no_revaluation_usd_amount,
	case when c.debit_or_credit_name = 'КЗ' then - c.debt_balance_usd_currency_amount
		 else c.debt_balance_usd_currency_amount
	end as usd_amount,
	c.database_code_1c,
	c.database_name_1c
from 
	ods.account_debt_for_working_capital_1c as c
left join cc as ct on
	ct.counterparty_mdm_code = c.counterparty_mdm_code
	and ct.ranks = 1
left join dict_dds.unit_balance as ubc on
	c.unit_balance_mdm_code_1c = ubc.counterparty_mdm_code 
window wdebt as (partition by
	c.dt_report,
	ct.counterparty_code,
	c.contract_number);