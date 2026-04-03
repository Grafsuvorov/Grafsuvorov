insert into dm_calc.account_turnover (
		unit_balance_code,
		fiscal_year, 
		accounting_document_code, 
		dt_posting,
		debit_or_credit_code,
		correspondence_debit_or_credit_code,
		account_type,
		general_ledger_account_code, 
		correspondence_general_ledger_account_code, 
		debit_turnover_document_currency_amount, 
		debit_turnover_local_currency_amount, 
		debit_turnover_second_local_currency_amount, 
		credit_turnover_document_currency_amount, 
		credit_turnover_local_currency_amount, 
		credit_turnover_second_local_currency_amount, 
		document_currency_code,
		local_currency_code, 
		second_local_currency_code, 
		plant_code,
		contract_number, 
		counterparty_code,
		accounting_document_type,
		posting_period,
		accounting_document_header_text, 
		reverse_document_code, 
		reference_document_number, 
		clearing_document_code, 
		dt_clearing, 
		position_line_item, 
		correspondence_line_item_number,
		credit_line_item_number,
		debit_line_item_number,
		credit_item_for_new_item_number,
		debit_item_for_new_item_number,
		credit_item_number_from_ledger_item_split,
		debit_item_number_from_ledger_item_split,
		tax_code, 
		invoice_document_code, 
		fiscal_year_of_relevant_invoice, 
		position_number_of_relevant_invoice, 
		position_line_item_text, 
		special_general_ledger_indicator, 
		dt_baseline_due_date_calculation, 
		terms_of_payment_code, 
		assignment_number, 
		is_red_reverse_posting, 
		dt_accounting_document, 
		dt_tax_reporting, 
		reverse_document_fiscal_year, 
		dt_accounting_document_created, 
		accounting_document_created_by, 
		transaction_code, 
		exchange_rate, 
		reference_procedure, 
		reference_object_key, 
		reason_for_reversal, 
		reference_key_internal_for_document_header_1, 
		reference_key_internal_for_document_header_2, 
		reference_key_for_line_item_1, 
		reference_key_for_line_item_2, 
		reference_key_for_line_item_3, 
		material_code, 
		cost_center_code, 
		co_order_number, 
		wbs_element_code, 
		funds_center_code,
		financial_position_internal_code, 
		transaction_type_general_ledger, 
		asset_main_number, 
		asset_subnumber, 
		asset_transaction_type, 
		settlement_period, 
		payee_or_payer_code,
		is_red_reverse_debit_posting, 
    	is_red_reverse_credit_posting,
    	document_currency_amount, 
    	local_currency_amount, 
    	second_local_currency_amount
)
select
	p.unit_balance_code,
	p.fiscal_year,
	p.accounting_document_code,
	p.dt_posting,
	p.debit_or_credit as debit_or_credit_code,
	'S' as respondence_debit_or_credit_code,
	p.account_type,
	p.general_ledger_account_code,
	case
		when p.general_ledger_account_code = cor.debit_account_code
     then cor.credit_account_code
		else cor.debit_account_code
	end
  as correspondence_general_ledger_account_code,
	--  
case
		when p.position_line_item = cor.debit_line_item_number
		and p.general_ledger_account_code = cor.debit_account_code
		and cor.is_red_reverse_debit_posting is null 
     then cor.document_currency_amount
		--when p.position_line_item = cor.credit_line_item_number
		--and p.general_ledger_account_code = cor.credit_account_code
		--and cor.is_red_reverse_credit_posting = 'X'
    -- then - cor.document_currency_amount
		else 0
	end
  as debit_turnover_document_currency_amount,
	case
		when p.position_line_item = cor.debit_line_item_number
		and p.general_ledger_account_code = cor.debit_account_code
		and cor.is_red_reverse_debit_posting is null 
     then cor.local_currency_amount
	--	when p.position_line_item = cor.credit_line_item_number
	--	and p.general_ledger_account_code = cor.credit_account_code
	--	and cor.is_red_reverse_credit_posting = 'X'
     --then - cor.local_currency_amount
		else 0
	end
  as debit_turnover_local_currency_amount,
	case
		when position_line_item = cor.debit_line_item_number
		and p.general_ledger_account_code = cor.debit_account_code
		and cor.is_red_reverse_debit_posting is null 
     then cor.second_local_currency_amount
	----	when p.position_line_item = cor.credit_line_item_number
	--	and p.general_ledger_account_code = cor.credit_account_code
	--	and cor.is_red_reverse_credit_posting = 'X'
    -- then - cor.second_local_currency_amount
		else 0
	end
  as debit_turnover_second_local_currency_amount,
	--  
case
		--when p.position_line_item = cor.credit_line_item_number
	--	and p.general_ledger_account_code = cor.credit_account_code
	--	and cor.is_red_reverse_credit_posting is null 
    -- then cor.document_currency_amount
		when p.position_line_item = cor.debit_line_item_number
		and p.general_ledger_account_code = cor.debit_account_code
		and cor.is_red_reverse_debit_posting = 'X'
     then - cor.document_currency_amount
		else 0
	end
  as credit_turnover_document_currency_amount,
	case
		--when p.position_line_item = cor.credit_line_item_number
		--and p.general_ledger_account_code = cor.credit_account_code
		--and cor.is_red_reverse_credit_posting is null 
     --then cor.local_currency_amount
		when p.position_line_item = cor.debit_line_item_number
		and p.general_ledger_account_code = cor.debit_account_code
		and cor.is_red_reverse_debit_posting = 'X'
     then - cor.local_currency_amount
		else 0
	end
  as credit_turnover_local_currency_amount,
	case
		--when p.position_line_item = cor.credit_line_item_number
		--and p.general_ledger_account_code = cor.credit_account_code
		--and cor.is_red_reverse_credit_posting is null 
    -- then cor.second_local_currency_amount
		when p.position_line_item = cor.debit_line_item_number
		and p.general_ledger_account_code = cor.debit_account_code
		and cor.is_red_reverse_debit_posting = 'X'
     then - cor.second_local_currency_amount
		else 0
	end
  as credit_turnover_second_local_currency_amount,
	--  
	p.document_currency_code,
	p.local_currency_code,
	p.second_local_currency_code,
	--p.plant_code,
	coalesce(p.plant_code, wr1.plant_code, wr3.plant_code) as plant_code,
	ltrim(p.contract_number,'0') as contract_number,
	case
		when p.account_type = 'D' then coalesce(p.customer_code,p.supplier_code)
		when p.account_type = 'K' then coalesce(p.supplier_code,p.customer_code)
		else null
	end as counterparty_code,
	p.accounting_document_type,
	p.posting_period,
	p.accounting_document_header_text,
	p.reverse_document_code,
	p.reference_document_number,
	p.clearing_document_code,
	p.dt_clearing,
	p.position_line_item,
	cor.credit_line_item_number as correspondence_line_item_number,
	cor.credit_line_item_number,
	cor.debit_line_item_number,
	cor.credit_item_for_new_item_number,
	cor.debit_item_for_new_item_number,
	cor.credit_item_number_from_ledger_item_split,
	cor.debit_item_number_from_ledger_item_split,
	p.tax_code,
	p.invoice_document_code,
	p.fiscal_year_of_relevant_invoice,
	p.position_number_of_relevant_invoice,
	p.position_line_item_text,
	p.special_general_ledger_indicator,
	p.dt_baseline_due_date_calculation,
	p.terms_of_payment_code,
	p.assignment_number,
	p.is_red_reverse_posting,
	p.dt_accounting_document,
	p.dt_tax_reporting,
	p.reverse_document_fiscal_year,
	p.dttm_accounting_document_created ,
	p.accounting_document_created_by,
	p.transaction_code,
	p.exchange_rate,
	p.reference_procedure,
	p.reference_object_key,
	p.reason_for_reversal,
	p.reference_key_internal_for_document_header_1,
	p.reference_key_internal_for_document_header_2,
	p.reference_key_for_line_item_1,
	p.reference_key_for_line_item_2,
	p.reference_key_for_line_item_3,
	p.material_code,
	p.cost_center_code,
	p.co_order_number,
	p.wbs_element_code,
	p.funds_center_code,
	p.financial_position_internal_code,
	p.transaction_type_general_ledger,
	p.asset_main_number,
	p.asset_subnumber,
	p.asset_transaction_type,
	p.settlement_period,
	p.payee_or_payer_code,
	cor.is_red_reverse_debit_posting,
	cor.is_red_reverse_credit_posting,
	cor.document_currency_amount,
	cor.local_currency_amount,
	cor.second_local_currency_amount
from dds.accounting_document_position_correspondence as cor  
join ods.accounting_documents as p  on
	cor.unit_balance_code = p.unit_balance_code
	and cor.fiscal_year = p.fiscal_year
	and cor.accounting_document_code = p.accounting_document_code
	and (p.position_line_item = cor.debit_line_item_number)
left join dm_calc.plant_by_unit_balance as wr1 on
                wr1.plant_count  > 1
                and wr1.plant_code = p.reference_key_internal_for_document_header_1
left join dm_calc.plant_by_unit_balance as wr3 on
                wr3.plant_count  > 1
                and wr3.plant_code = p.reference_key_for_line_item_3
where
	1 = 1
	and (p.is_active = true)	
	and cor.unit_balance_code  not like 'S%'
	and cor.unit_balance_code  not like 'F%'
	and cor.unit_balance_code  not like 'E%'
	and cor.is_active = true
	and (p.accounting_document_status_code is null
			or p.accounting_document_status_code not in ('D', 'M', 'S'))
	
	union all 
	
	--6 min
	--3 мин
--insert into userdata.account_turnover	
select
	p.unit_balance_code,
	p.fiscal_year,
	p.accounting_document_code,
	p.dt_posting,
	p.debit_or_credit,
	'H' as debit_or_credit_code,
	p.account_type,
	p.general_ledger_account_code,
	
	case
		when p.general_ledger_account_code = cor.debit_account_code
     then cor.credit_account_code
		else cor.debit_account_code
	end
  as correspondence_general_ledger_account_code,
	--  
case
		--when p.position_line_item = cor.debit_line_item_number никогда не выполнится
		--and p.general_ledger_account_code = cor.debit_account_code
		--and cor.is_red_reverse_debit_posting is null 
    -- then cor.document_currency_amount
		when p.position_line_item = cor.credit_line_item_number
		and p.general_ledger_account_code = cor.credit_account_code
		and cor.is_red_reverse_credit_posting = 'X'
     then - cor.document_currency_amount
		else 0
	end
  as debit_turnover_document_currency_amount,
	case
		--when p.position_line_item = cor.debit_line_item_number никогда не выполнится
		--and p.general_ledger_account_code = cor.debit_account_code
		--and cor.is_red_reverse_debit_posting is null 
     --then cor.local_currency_amount
		when p.position_line_item = cor.credit_line_item_number
		and p.general_ledger_account_code = cor.credit_account_code
		and cor.is_red_reverse_credit_posting = 'X'
     then - cor.local_currency_amount
		else 0
	end
  as debit_turnover_local_currency_amount,
	case
 --   	when position_line_item = cor.debit_line_item_number
--		and p.general_ledger_account_code = cor.debit_account_code
--		and cor.is_red_reverse_debit_posting is null 
 --    then cor.second_local_currency_amount никогда не выполнится
		when p.position_line_item = cor.credit_line_item_number
		and p.general_ledger_account_code = cor.credit_account_code
		and cor.is_red_reverse_credit_posting = 'X'
     then - cor.second_local_currency_amount
		else 0
	end
  as debit_turnover_second_local_currency_amount,
	--  
case
		when p.position_line_item = cor.credit_line_item_number
		and p.general_ledger_account_code = cor.credit_account_code
		and cor.is_red_reverse_credit_posting is null 
     then cor.document_currency_amount
		--when p.position_line_item = cor.debit_line_item_number никогда не выполнится
		--and p.general_ledger_account_code = cor.debit_account_code
		--and cor.is_red_reverse_debit_posting = 'X'
     --then - cor.document_currency_amount
		else 0
	end
  as credit_turnover_document_currency_amount,
	case
		when p.position_line_item = cor.credit_line_item_number
		and p.general_ledger_account_code = cor.credit_account_code
		and cor.is_red_reverse_credit_posting is null 
     then cor.local_currency_amount
	--	when p.position_line_item = cor.debit_line_item_number никогда не выполнится
	--	and p.general_ledger_account_code = cor.debit_account_code
	--	and cor.is_red_reverse_debit_posting = 'X'
    -- then - cor.local_currency_amount
		else 0
	end
  as credit_turnover_local_currency_amount,
	case
		when p.position_line_item = cor.credit_line_item_number
		and p.general_ledger_account_code = cor.credit_account_code
		and cor.is_red_reverse_credit_posting is null 
     then cor.second_local_currency_amount
		--when p.position_line_item = cor.debit_line_item_number
	--	and p.general_ledger_account_code = cor.debit_account_code никогда не выполнится
	--	and cor.is_red_reverse_debit_posting = 'X'
   --  then - cor.second_local_currency_amount
		else 0
	end
  as credit_turnover_second_local_currency_amount,
	--  
	p.document_currency_code,
	p.local_currency_code,
	p.second_local_currency_code,
	--coalesce(p.plant_code,
	--wr1.plant_code,
	--wr3.plant_code) as plant_code,
--	p.plant_code,
	 coalesce(p.plant_code, wr1.plant_code, wr3.plant_code) as plant_code,
	ltrim(p.contract_number,'0') as contract_number,
	case
		when p.account_type = 'D' then coalesce(p.customer_code,p.supplier_code)
		when p.account_type = 'K' then coalesce(p.supplier_code,p.customer_code)
		else null
	end as counterparty_code,
	p.accounting_document_type,
	p.posting_period,
	p.accounting_document_header_text,
	p.reverse_document_code,
	p.reference_document_number,
	p.clearing_document_code,
	p.dt_clearing,
	p.position_line_item,
	cor.debit_line_item_number as correspondence_line_item_number,
	cor.credit_line_item_number,
	cor.debit_line_item_number,
	cor.credit_item_for_new_item_number,
	cor.debit_item_for_new_item_number,
	cor.credit_item_number_from_ledger_item_split,
	cor.debit_item_number_from_ledger_item_split,
	p.tax_code,
	p.invoice_document_code,
	p.fiscal_year_of_relevant_invoice,
	p.position_number_of_relevant_invoice,
	p.position_line_item_text,
	p.special_general_ledger_indicator,
	p.dt_baseline_due_date_calculation,
	p.terms_of_payment_code,
	p.assignment_number,
	p.is_red_reverse_posting,
	p.dt_accounting_document,
	p.dt_tax_reporting,
	p.reverse_document_fiscal_year,
	p.dttm_accounting_document_created ,
	p.accounting_document_created_by,
	p.transaction_code,
	p.exchange_rate,
	p.reference_procedure,
	p.reference_object_key,
	p.reason_for_reversal,
	p.reference_key_internal_for_document_header_1,
	p.reference_key_internal_for_document_header_2,
	p.reference_key_for_line_item_1,
	p.reference_key_for_line_item_2,
	p.reference_key_for_line_item_3,
	p.material_code,
	p.cost_center_code,
	p.co_order_number,
	p.wbs_element_code,
	p.funds_center_code,
	p.financial_position_internal_code,
	p.transaction_type_general_ledger,
	p.asset_main_number,
	p.asset_subnumber,
	p.asset_transaction_type,
	p.settlement_period,
	p.payee_or_payer_code,
	cor.is_red_reverse_debit_posting,
	cor.is_red_reverse_credit_posting,
	cor.document_currency_amount,
	cor.local_currency_amount,
	cor.second_local_currency_amount
from dds.accounting_document_position_correspondence as cor 
join ods.accounting_documents as p  on
	cor.unit_balance_code = p.unit_balance_code
	and cor.fiscal_year = p.fiscal_year
	and cor.accounting_document_code = p.accounting_document_code
	and (p.position_line_item = cor.credit_line_item_number)
left join dm_calc.plant_by_unit_balance as wr1 on
                wr1.plant_count  > 1
                and wr1.plant_code = p.reference_key_internal_for_document_header_1
left join dm_calc.plant_by_unit_balance as wr3 on
                wr3.plant_count  > 1
                and wr3.plant_code = p.reference_key_for_line_item_3
where
	1 = 1
	and (p.is_active = true)	
	and cor.unit_balance_code not like 'S%'
	and cor.unit_balance_code not like 'F%'
	and cor.unit_balance_code not like 'E%'
	and cor.is_active = true
	and (p.accounting_document_status_code is null
		or p.accounting_document_status_code not in ('D', 'M', 'S'));
