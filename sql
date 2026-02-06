explain
with revaluation_documents as(
---тк при расчете суммы переоценки на дату нужна дата проводки, то агрегируем  и по ней
select
	taerr.unit_balance_code,
	taerr.reference_document_fiscal_year::numeric,
	taerr.reference_document_code,
	taerr.reference_document_position_line_item::numeric,
	taerr.dt_posting,
	coalesce(sum(case
		when taerr.debit_or_credit = 'H' then - taerr.local_currency_amount
		else taerr.local_currency_amount
	 end),0) as exchange_diff_local_currency_amount,
	 coalesce( sum(case
		when taerr.debit_or_credit = 'H' then - taerr.second_local_currency_amount
		 else taerr.second_local_currency_amount
	end),0) as exchange_diff_second_local_currency_amount
from 
	dm_calc.accounting_exchange_rate_revaluation_with_document_reference taerr 
where 
	taerr.deleted_flag = false
group by 
	taerr.unit_balance_code,
	taerr.reference_document_fiscal_year::numeric,
	taerr.reference_document_code,
	taerr.reference_document_position_line_item::numeric,
	taerr.dt_posting),
---готовим связанные данные для последующей агрегации, оставляем только нужные поля
receivables_and_payables_with_reval as (
select 
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
	o.dt_posting,
	o.dt_clearing,
---добавляем суммы
	coalesce(case
		when o.debit_or_credit = 'H' then - o.document_currency_amount
		else o.document_currency_amount
	end,0) as document_currency_amount,
	coalesce(case
		when o.debit_or_credit = 'H' then - o.local_currency_amount
		else o.local_currency_amount
	end,0) as local_currency_amount,
	coalesce(case
		when o.debit_or_credit = 'H' then - o.second_local_currency_amount
		else o.second_local_currency_amount
	end,0) as second_local_currency_amount,
	case
		when o.debit_or_credit = 'H' then - o.valuation_difference_second_local_currency_amount
		else o.valuation_difference_second_local_currency_amount
	end as valuation_difference_second_local_currency_amount,
	coalesce(case
		when o.debit_or_credit = 'H' then - o.usd_amount
		else o.usd_amount
	end,0) as usd_amount,
	----суммы из документов переоценки
	taerr.exchange_diff_local_currency_amount,
	taerr.exchange_diff_second_local_currency_amount,
	taerr.dt_posting as dt_posting_rev
from --документы задолженности
	dm_calc.accounting_receivables_and_payables o
left join revaluation_documents taerr on 
	---документы переоценки
	taerr.unit_balance_code = o.unit_balance_code  and 
	taerr.reference_document_fiscal_year = o.fiscal_year  and 
	taerr.reference_document_code  = o.accounting_document_code and 
	taerr.reference_document_position_line_item = o.position_line_item 
left join dict_dds.settings_and_parameters_sap saps on 
	----перечень БЕ, которые считаются неактивными  и для которых расчеты не нужны
	o.unit_balance_code=saps.range_low_value
	and saps.abap_program_code = '/RUSAL/FI_KHD'
	and saps.parameter_code = 'INACTBUK'
where
---документы с пустой валютой документа - битые
	o.document_currency_code is not null
	and saps.range_low_value is null 
	and o.unit_balance_code !~'^[A-Za-z]'
	and o.deleted_flag = false),
---документы, открывающие задолженность, ключи по дням +агрегированные суммы
opening_documents_keys as (
select 
	st.dt as dt,	
	st.is_second_friday,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
---добавляем суммы для документов из dm_calcберем max, тк они замножены на документы переоценки, переоценку суммируем
	max(o.document_currency_amount) as document_currency_amount ,
	max(o.local_currency_amount) as local_currency_amount,
	max(o.second_local_currency_amount) as second_local_currency_amount,
	max(o.valuation_difference_second_local_currency_amount) as valuation_difference_second_local_currency_amount,
	max(o.usd_amount) as usd_amount,
	---если в переоценке неподходящая дата проводки документа переоценки, то это не повод не брать сумму по документу, но в сумме переоценки тогда не учитываем
	sum(case when (o.dt_posting_rev <=st.dt or o.dt_posting_rev is null) then o.exchange_diff_local_currency_amount else null end) as exchange_diff_local_currency_amount,
	sum(case when (o.dt_posting_rev <=st.dt or o.dt_posting_rev is null) then o.exchange_diff_second_local_currency_amount else null end) as exchange_diff_second_local_currency_amount	
from 
 	receivables_and_payables_with_reval as o	
join dm_calc.operating_periods_for_account_debt st on 
	o.unit_balance_code = st.unit_balance_code 
where
	1 = 1			
	---документы с пустой валютой документа - битые
	and coalesce(o.dt_clearing,'2299-12-31') > st.dt
	and st.dt >= o.dt_posting
	and (st.dt >= (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date
     and st.dt <=  (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date)
	and st.deleted_flag = false
group by 
	st.dt,
	st.is_second_friday,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item
),
opening_documents  as (
select 
	o2.dt as dt,
	o2.is_second_friday,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
	o.dt_posting,
	o.accounting_document_type,
	o.reverse_document_code,
	o.reference_document_number,
	o.accounting_document_status_code,
	o.dt_accounting_document,
	o.document_currency_code,
	o.local_currency_code,
	o.second_local_currency_code,
	o.debit_or_credit,
	o.general_ledger_account_code,
	o.tax_code,
	o.account_type,
	o.position_line_item_text,
	o.clearing_document_code,
	o.dt_clearing,
	o.special_general_ledger_indicator,
	o.counterparty_code,
	o.contract_number,
	o.plant_code,
	o.dt_baseline_due_date_calculation,
	o.terms_of_payment_code,
	o.assignment_number,
	o.reverse_document_fiscal_year,
	o.reason_for_reversal,
	o.invoice_document_code,
	o.fiscal_year_of_relevant_invoice,
	o.position_number_of_relevant_invoice,
	o.reference_procedure,
	o.reference_object_key,
---добавляем суммы
	o2.document_currency_amount,
	o2.local_currency_amount,
	o2.second_local_currency_amount,
	o2.valuation_difference_second_local_currency_amount,
	o2.usd_amount,
	o2.exchange_diff_local_currency_amount,
	o2.exchange_diff_second_local_currency_amount,
	case 
		when cp2.document_currency_code = o.document_currency_code 
			and cp2.general_ledger_account_code = o.general_ledger_account_code
			and cp2.debit_or_credit <> o.debit_or_credit 
		then  coalesce (o.position_number_of_relevant_invoice, o.position_line_item)
		else o.position_line_item end as final_position_line_item ,
	
	case 
		when cp2.document_currency_code = o.document_currency_code 
			and cp2.general_ledger_account_code = o.general_ledger_account_code 
			and cp2.debit_or_credit <> o.debit_or_credit 
		then  coalesce (o.fiscal_year_of_relevant_invoice, o.fiscal_year)  
		else o.fiscal_year end  as final_fiscal_year,
	
	case 
		when cp2.document_currency_code = o.document_currency_code 
			and cp2.general_ledger_account_code = o.general_ledger_account_code
			and cp2.debit_or_credit <> o.debit_or_credit 
		then  coalesce (o.invoice_document_code, o.accounting_document_code) 
		else o.accounting_document_code end as final_accounting_document_code,
			
	cp2.document_currency_code as document_currency_code_of_relevant_invoice,
	cp2.general_ledger_account_code as general_ledger_account_code_of_relevant_invoice,
	cp2.debit_or_credit as debit_or_credit_code_of_relevant_invoice
from 
---раскидываем все аналатики документов задолженности по ключам, доопределяем финальные реквизиты документов
 	dm_calc.accounting_receivables_and_payables as o	
join opening_documents_keys as o2 on 
	o2.unit_balance_code = o.unit_balance_code 
	and o2.fiscal_year = o.fiscal_year
	and  o2.accounting_document_code = o.accounting_document_code
	and  o2.position_line_item = o.position_line_item 
left join dm_calc.accounting_receivables_and_payables cp2 on
	cp2.unit_balance_code = o.unit_balance_code
	and cp2.fiscal_year = o.fiscal_year_of_relevant_invoice 
	and  cp2.accounting_document_code = o.invoice_document_code 
	and  cp2.position_line_item = o.position_number_of_relevant_invoice 
where
	1 = 1		
	and (cp2.deleted_flag = false or cp2.deleted_flag  is null)
),
----исключаем документы, для которых есть ссылочные инвойсы
opening_documents_no_invoices as (
select 
	o.dt,
	o.is_second_friday,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
	o.dt_posting,
	o.accounting_document_type,
	o.reverse_document_code,
	o.reference_document_number,
	o.accounting_document_status_code,
	o.dt_accounting_document,
	o.document_currency_code,
	o.local_currency_code,
	o.second_local_currency_code,
	o.debit_or_credit,
	o.general_ledger_account_code,
	o.tax_code,
	o.account_type,
	o.position_line_item_text,
	o.clearing_document_code,
	o.dt_clearing,
	o.special_general_ledger_indicator,
	o.counterparty_code,
	o.contract_number,
	o.plant_code,
	o.dt_baseline_due_date_calculation,
	o.terms_of_payment_code,
	o.assignment_number,
	o.reverse_document_fiscal_year,
	o.reason_for_reversal,
	o.invoice_document_code,
	o.fiscal_year_of_relevant_invoice,
	o.position_number_of_relevant_invoice,
	o.reference_procedure,
	o.reference_object_key,
	o.document_currency_amount,
	o.local_currency_amount,
	o.second_local_currency_amount,
	o.valuation_difference_second_local_currency_amount,
	o.usd_amount,
	o.exchange_diff_local_currency_amount,
	o.exchange_diff_second_local_currency_amount,
	o.final_position_line_item ,
	o.final_fiscal_year,
	o.final_accounting_document_code,		
	o.document_currency_code_of_relevant_invoice,
	o.general_ledger_account_code_of_relevant_invoice,
	o.debit_or_credit_code_of_relevant_invoice
from opening_documents o
----по плану запроса как будто джойн потребит больше памяти, хотя нет loop
----по времени работают одинаково
/*left join opening_documents o2 on 
	o2.dt = o.dt
	and o2.unit_balance_code =   o.unit_balance_code 
	and o2.fiscal_year = o.final_fiscal_year
	and o2.accounting_document_code =o.final_accounting_document_code 
	and o2.position_line_item = o.final_position_line_item 
	and o2.invoice_document_code is null
	and o2.document_currency_code = o.document_currency_code_of_relevant_invoice 	  
	and o2.general_ledger_account_code  = o.general_ledger_account_code_of_relevant_invoice 
	and o2.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice
where o2.dt is  null*/
where 1=1
	and (not  exists(
		  select  1
		  from 
		  	opening_documents   o2
		  where 1 = 1
			  and o2.dt = o.dt
			  and o2.unit_balance_code =   o.unit_balance_code 
			  and o2.fiscal_year = o.final_fiscal_year
			  and o2.accounting_document_code =o.final_accounting_document_code 
			  and o2.position_line_item = o.final_position_line_item 
			  and o2.invoice_document_code is null
			  and o2.document_currency_code = o.document_currency_code_of_relevant_invoice 	  
			  and o2.general_ledger_account_code  = o.general_ledger_account_code_of_relevant_invoice 
		      and o2.debit_or_credit = o.debit_or_credit_code_of_relevant_invoice))),
--в разрезе открывающих документов группируем суммы закрывающих документов
closing_sum_to_opening_documents as (
select
	o.dt,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item,
	sum(coalesce(cp.document_currency_amount, 0))::numeric(17,2) as document_currency_amount,
	sum(coalesce(cp.local_currency_amount, 0))::numeric(17,2) as local_currency_amount, 
	sum(coalesce(cp.second_local_currency_amount, 0))::numeric(17,2) as second_local_currency_amount,
	sum(coalesce(cp.valuation_difference_second_local_currency_amount, 0))::numeric(17,2) as valuation_difference_second_local_currency_amount,
	sum(coalesce(cp.usd_amount, 0))::numeric(17,2) as usd_amount,
	sum(coalesce (cp.exchange_diff_local_currency_amount,0))::numeric(17,2) as exchange_diff_local_currency_amount,
	sum(coalesce (cp.exchange_diff_second_local_currency_amount ,0))::numeric(17,2) as exchange_diff_second_local_currency_amount
from 
	opening_documents_no_invoices o
join opening_documents cp on
	cp.dt = o.dt
	and cp.unit_balance_code = o.unit_balance_code
	and cp.fiscal_year_of_relevant_invoice = o.fiscal_year
	and cp.invoice_document_code = o.accounting_document_code
	and cp.position_number_of_relevant_invoice = o.position_line_item
	and cp.document_currency_code = o.document_currency_code
	and cp.general_ledger_account_code = o.general_ledger_account_code 
	and cp.debit_or_credit <> o.debit_or_credit
	and o.general_ledger_account_code_of_relevant_invoice is null 
	and o.document_currency_code_of_relevant_invoice is null 
	and o.debit_or_credit_code_of_relevant_invoice is null
	and o.invoice_document_code is  null
	and o.fiscal_year_of_relevant_invoice is   null
	and	o.position_number_of_relevant_invoice is  null
where
	1 = 1		
group by
	o.dt,
	o.unit_balance_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.position_line_item
)
---джойним открывающие с закрывающими, считаем сумму непогашенной задолженности и переоценки
 select
	o.dt,
	o.is_second_friday,
	o.unit_balance_code,
	o.plant_code,
	o.fiscal_year,
	o.accounting_document_code,
	o.dt_posting,
	o.dt_clearing,
	o.contract_number,
	o.counterparty_code,
	o.debit_or_credit,
	o.account_type,
	o.general_ledger_account_code,
	(o.document_currency_amount + coalesce(cp.document_currency_amount,0))::numeric(17,2) as debt_balance_document_currency_amount,
	o.document_currency_code,
	(o.local_currency_amount + coalesce(cp.local_currency_amount,0))::numeric(17,2) as debt_balance_local_currency_amount,	
	o.local_currency_code,
	(o.second_local_currency_amount + coalesce(cp.second_local_currency_amount,0))::numeric(17,2) as debt_balance_second_local_currency_amount,
	(o.second_local_currency_amount + coalesce(cp.second_local_currency_amount,0) +
	coalesce(o.valuation_difference_second_local_currency_amount, 0) +coalesce(cp.valuation_difference_second_local_currency_amount,0))::numeric(17,2) as debt_balance_with_revaluation_diff_second_currency_amount,
	(o.usd_amount + coalesce(cp.usd_amount,0))::numeric(17,2) as debt_balance_usd_amount,
	o.second_local_currency_code,
	o.accounting_document_type,
	o.position_line_item,
	o.reverse_document_code,
	o.reference_document_number,
	o.accounting_document_status_code,
	o.clearing_document_code,
	o.tax_code,
	o.position_line_item_text,
	o.special_general_ledger_indicator,
	o.dt_baseline_due_date_calculation,
	o.assignment_number,
	o.dt_accounting_document,
	o.terms_of_payment_code,
	o.document_currency_amount,
	o.local_currency_amount,
	o.second_local_currency_amount,
	o.usd_amount,
	o.reverse_document_fiscal_year,
	o.reason_for_reversal,
	o.invoice_document_code,
	o.fiscal_year_of_relevant_invoice,
	o.position_number_of_relevant_invoice,
	o.final_position_line_item ,
	o.final_fiscal_year,
	o.final_accounting_document_code,
	o.document_currency_code_of_relevant_invoice,
	o.general_ledger_account_code_of_relevant_invoice,
	o.debit_or_credit_code_of_relevant_invoice,
	o.reference_procedure as reference_operation_type_code,
	o.reference_object_key as reference_object_key_code,
	(o.exchange_diff_local_currency_amount)::numeric(17,2) as exchange_diff_local_currency_amount,
	(o.exchange_diff_local_currency_amount + coalesce(cp.exchange_diff_local_currency_amount,0))::numeric(17,2) as debt_balance_exchange_diff_local_currency_amount,
	(o.exchange_diff_second_local_currency_amount)::numeric(17,2) as exchange_diff_second_local_currency_amount,
	(o.exchange_diff_second_local_currency_amount + coalesce(cp.exchange_diff_second_local_currency_amount,0) )::numeric(17,2) as debt_balance_exchange_diff_second_local_currency_amount
from 
	opening_documents_no_invoices o
left join closing_sum_to_opening_documents cp on
	cp.dt = o.dt
	and cp.unit_balance_code = o.unit_balance_code
	and cp.fiscal_year = o.fiscal_year
	and cp.accounting_document_code = o.accounting_document_code
	and cp.position_line_item = o.position_line_item
where
	1 = 1;


Gather Motion 8:1  (slice6; segments: 8)  (cost=0.00..30091627.39 rows=11269397432 width=413)
  ->  Sequence  (cost=0.00..17187688.38 rows=1408674679 width=413)
        ->  Shared Scan (share slice:id 6:3)  (cost=0.00..2391221.34 rows=1408674679 width=1)
              ->  Materialize  (cost=0.00..2391221.34 rows=1408674679 width=1)
                    ->  Result  (cost=0.00..2389812.66 rows=1408674679 width=365)
                          ->  Result  (cost=0.00..1875646.41 rows=1408674679 width=335)
                                Filter: ((NOT accounting_receivables_and_payables_2.deleted_flag) OR (accounting_receivables_and_payables_2.deleted_flag IS NULL))
                                ->  Hash Left Join  (cost=0.00..1829301.01 rows=1408674679 width=336)
                                      Hash Cond: (((accounting_receivables_and_payables.unit_balance_code)::text = (accounting_receivables_and_payables_2.unit_balance_code)::text) AND (accounting_receivables_and_payables.fiscal_year_of_relevant_invoice = accounting_receivables_and_payables_2.fiscal_year) AND ((accounting_receivables_and_payables.invoice_document_code)::text = (accounting_receivables_and_payables_2.accounting_document_code)::text) AND (accounting_receivables_and_payables.position_number_of_relevant_invoice = accounting_receivables_and_payables_2.position_line_item))
                                      ->  Redistribute Motion 8:8  (slice5; segments: 8)  (cost=0.00..126149.41 rows=10361425 width=318)
                                            Hash Key: accounting_receivables_and_payables.unit_balance_code, accounting_receivables_and_payables.fiscal_year_of_relevant_invoice, accounting_receivables_and_payables.invoice_document_code, accounting_receivables_and_payables.position_number_of_relevant_invoice
                                            ->  Hash Join  (cost=0.00..115836.27 rows=10361425 width=318)
                                                  Hash Cond: (((accounting_receivables_and_payables.unit_balance_code)::text = (accounting_receivables_and_payables_1.unit_balance_code)::text) AND (accounting_receivables_and_payables.fiscal_year = accounting_receivables_and_payables_1.fiscal_year) AND ((accounting_receivables_and_payables.accounting_document_code)::text = (accounting_receivables_and_payables_1.accounting_document_code)::text) AND (accounting_receivables_and_payables.position_line_item = accounting_receivables_and_payables_1.position_line_item))
                                                  ->  Seq Scan on accounting_receivables_and_payables  (cost=0.00..2989.75 rows=10361425 width=257)
                                                  ->  Hash  (cost=39371.36..39371.36 rows=12085521 width=87)
                                                        ->  HashAggregate  (cost=0.00..39371.36 rows=12085521 width=87)
                                                              Group Key: operating_periods_for_account_debt.dt, operating_periods_for_account_debt.is_second_friday, accounting_receivables_and_payables_1.unit_balance_code, accounting_receivables_and_payables_1.fiscal_year, accounting_receivables_and_payables_1.accounting_document_code, accounting_receivables_and_payables_1.position_line_item
                                                              ->  Hash Join  (cost=0.00..29373.36 rows=12085521 width=91)
                                                                    Hash Cond: ((accounting_receivables_and_payables_1.unit_balance_code)::text = (operating_periods_for_account_debt.unit_balance_code)::text)
                                                                    Join Filter: ((COALESCE(accounting_receivables_and_payables_1.dt_clearing, '2299-12-31'::date) > operating_periods_for_account_debt.dt) AND (operating_periods_for_account_debt.dt >= accounting_receivables_and_payables_1.dt_posting))
                                                                    ->  Result  (cost=0.00..23039.66 rows=4118713 width=94)
                                                                          ->  Result  (cost=0.00..22652.50 rows=4118713 width=87)
                                                                                Filter: (settings_and_parameters_sap.range_low_value IS NULL)
                                                                                ->  Hash Left Join  (cost=0.00..22516.14 rows=4144570 width=95)
                                                                                      Hash Cond: ((accounting_receivables_and_payables_1.unit_balance_code)::text = (settings_and_parameters_sap.range_low_value)::text)
                                                                                      ->  Hash Left Join  (cost=0.00..19687.00 rows=4144570 width=87)
                                                                                            Hash Cond: (((accounting_receivables_and_payables_1.unit_balance_code)::text = (accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code)::text) AND (accounting_receivables_and_payables_1.fiscal_year = accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year) AND ((accounting_receivables_and_payables_1.accounting_document_code)::text = (accounting_exchange_rate_revaluation_with_document_reference.reference_document_code)::text) AND (accounting_receivables_and_payables_1.position_line_item = accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item))
                                                                                            ->  Seq Scan on accounting_receivables_and_payables accounting_receivables_and_payables_1  (cost=0.00..4567.47 rows=4144570 width=67)
                                                                                                  Filter: ((NOT (document_currency_code IS NULL)) AND ((unit_balance_code)::text !~ '^[A-Za-z]'::text) AND (NOT deleted_flag))
                                                                                            ->  Hash  (cost=2437.79..2437.79 rows=2227328 width=46)
                                                                                                  ->  Result  (cost=0.00..2437.79 rows=2227328 width=46)
                                                                                                        ->  HashAggregate  (cost=0.00..2335.33 rows=2227328 width=46)
                                                                                                              Group Key: accounting_exchange_rate_revaluation_with_document_reference.unit_balance_code, accounting_exchange_rate_revaluation_with_document_reference.reference_document_fiscal_year, accounting_exchange_rate_revaluation_with_document_reference.reference_document_code, accounting_exchange_rate_revaluation_with_document_reference.reference_document_position_line_item, accounting_exchange_rate_revaluation_with_document_reference.dt_posting
                                                                                                              ->  Seq Scan on accounting_exchange_rate_revaluation_with_document_reference  (cost=0.00..884.08 rows=2227328 width=41)
                                                                                                                    Filter: (NOT deleted_flag)
                                                                                      ->  Hash  (cost=511.16..511.16 rows=1 width=8)
                                                                                            ->  Seq Scan on settings_and_parameters_sap  (cost=0.00..511.16 rows=1 width=8)
                                                                                                  Filter: (((abap_program_code)::text = '/RUSAL/FI_KHD'::text) AND ((parameter_code)::text = 'INACTBUK'::text))
                                                                    ->  Hash  (cost=458.00..458.00 rows=2300 width=10)
                                                                          ->  Seq Scan on operating_periods_for_account_debt  (cost=0.00..458.00 rows=2300 width=10)
                                                                                Filter: ((dt >= '2025-12-31'::date) AND (dt <= '2026-02-28'::date) AND (NOT deleted_flag))
                                      ->  Hash  (cost=2989.75..2989.75 rows=10361425 width=44)
                                            ->  Seq Scan on accounting_receivables_and_payables accounting_receivables_and_payables_2  (cost=0.00..2989.75 rows=10361425 width=44)
        ->  Sequence  (cost=0.00..14214684.40 rows=1408674679 width=413)
              ->  Shared Scan (share slice:id 6:4)  (cost=0.00..5212093.74 rows=46 width=1)
                    ->  Materialize  (cost=0.00..5212093.74 rows=46 width=1)
                          ->  Hash Anti Join  (cost=0.00..5212093.74 rows=46 width=342)
                                Hash Cond: ((share3_ref3.dt = share3_ref2.dt) AND ((share3_ref3.unit_balance_code)::text = (share3_ref2.unit_balance_code)::text) AND (share3_ref3.final_fiscal_year = share3_ref2.fiscal_year) AND ((share3_ref3.final_accounting_document_code)::text = (share3_ref2.accounting_document_code)::text) AND (share3_ref3.final_position_line_item = share3_ref2.position_line_item) AND ((share3_ref3.document_currency_code_1)::text = (share3_ref2.document_currency_code)::text) AND ((share3_ref3.general_ledger_account_code_1)::text = (share3_ref2.general_ledger_account_code)::text) AND (share3_ref3.debit_or_credit_1 = share3_ref2.debit_or_credit))
                                ->  Redistribute Motion 8:8  (slice3; segments: 8)  (cost=0.00..2669418.74 rows=1408674679 width=342)
                                      Hash Key: share3_ref3.dt, share3_ref3.unit_balance_code, share3_ref3.final_fiscal_year, share3_ref3.final_accounting_document_code, share3_ref3.final_position_line_item, share3_ref3.document_currency_code_1, share3_ref3.general_ledger_account_code_1, share3_ref3.debit_or_credit_1
                                      ->  Shared Scan (share slice:id 3:3)  (cost=0.00..1161488.84 rows=1408674679 width=342)
                                ->  Hash  (cost=290085.81..290085.81 rows=306349 width=47)
                                      ->  Result  (cost=0.00..290085.81 rows=306349 width=47)
                                            ->  Redistribute Motion 8:8  (slice4; segments: 8)  (cost=0.00..290071.41 rows=306349 width=47)
                                                  Hash Key: share3_ref2.dt, share3_ref2.unit_balance_code, share3_ref2.fiscal_year, share3_ref2.accounting_document_code, share3_ref2.position_line_item, share3_ref2.document_currency_code, share3_ref2.general_ledger_account_code, share3_ref2.debit_or_credit
                                                  ->  Result  (cost=0.00..290026.34 rows=306349 width=47)
                                                        Filter: ((share3_ref2.invoice_document_code IS NULL) AND (share3_ref2.dt >= '2025-12-31'::date) AND (share3_ref2.dt <= '2026-02-28'::date))
                                                        ->  Shared Scan (share slice:id 4:3)  (cost=0.00..197335.55 rows=1408674679 width=58)
              ->  Result  (cost=0.00..8420808.02 rows=1408674679 width=413)
                    ->  Hash Left Join  (cost=0.00..7698157.91 rows=1408674679 width=398)
                          Hash Cond: ((share4_ref3.dt = share4_ref2.dt) AND ((share4_ref3.unit_balance_code)::text = (share4_ref2.unit_balance_code)::text) AND (share4_ref3.fiscal_year = share4_ref2.fiscal_year) AND ((share4_ref3.accounting_document_code)::text = (share4_ref2.accounting_document_code)::text) AND (share4_ref3.position_line_item = share4_ref2.position_line_item))
                          ->  Shared Scan (share slice:id 6:4)  (cost=0.00..1161488.84 rows=1408674679 width=342)
                          ->  Hash  (cost=3056850.82..3056850.82 rows=73 width=86)
                                ->  Broadcast Motion 8:8  (slice2; segments: 8)  (cost=0.00..3056850.82 rows=73 width=86)
                                      ->  Result  (cost=0.00..3056850.77 rows=10 width=86)
                                            ->  Result  (cost=0.00..3056850.77 rows=10 width=86)
                                                  ->  HashAggregate  (cost=0.00..3056850.77 rows=57 width=86)
                                                        Group Key: share4_ref2.dt, share4_ref2.unit_balance_code, share4_ref2.fiscal_year, share4_ref2.accounting_document_code, share4_ref2.position_line_item
                                                        ->  Hash Join  (cost=0.00..3056850.73 rows=57 width=86)
                                                              Hash Cond: ((share3_ref4.dt = share4_ref2.dt) AND ((share3_ref4.unit_balance_code)::text = (share4_ref2.unit_balance_code)::text) AND (share3_ref4.fiscal_year_of_relevant_invoice = share4_ref2.fiscal_year) AND ((share3_ref4.invoice_document_code)::text = (share4_ref2.accounting_document_code)::text) AND (share3_ref4.position_number_of_relevant_invoice = share4_ref2.position_line_item) AND ((share3_ref4.document_currency_code)::text = (share4_ref2.document_currency_code)::text) AND ((share3_ref4.general_ledger_account_code)::text = (share4_ref2.general_ledger_account_code)::text))
                                                              Join Filter: (share3_ref4.debit_or_credit <> share4_ref2.debit_or_credit)
                                                              ->  Result  (cost=0.00..396451.71 rows=1408674679 width=103)
                                                                    Filter: ((share3_ref4.dt >= '2025-12-31'::date) AND (share3_ref4.dt <= '2026-02-28'::date))
                                                                    ->  Shared Scan (share slice:id 2:3)  (cost=0.00..350106.32 rows=1408674679 width=103)
                                                              ->  Hash  (cost=613415.79..613415.79 rows=1 width=47)
                                                                    ->  Redistribute Motion 8:8  (slice1; segments: 8)  (cost=0.00..613415.79 rows=1 width=47)
                                                                          Hash Key: share4_ref2.unit_balance_code, share4_ref2.fiscal_year, share4_ref2.accounting_document_code, share4_ref2.position_line_item
                                                                          ->  Result  (cost=0.00..613415.79 rows=1 width=47)
                                                                                Filter: ((share4_ref2.general_ledger_account_code_1 IS NULL) AND (share4_ref2.document_currency_code_1 IS NULL) AND (share4_ref2.debit_or_credit_1 IS NULL) AND (share4_ref2.invoice_document_code IS NULL) AND (share4_ref2.fiscal_year_of_relevant_invoice IS NULL) AND (share4_ref2.position_number_of_relevant_invoice IS NULL) AND (share4_ref2.dt >= '2025-12-31'::date) AND (share4_ref2.dt <= '2026-02-28'::date) AND (share4_ref2.dt >= '2025-12-31'::date) AND (share4_ref2.dt <= '2026-02-28'::date))
                                                                                ->  Shared Scan (share slice:id 1:4)  (cost=0.00..288998.01 rows=1408674679 width=85)
Optimizer: Pivotal Optimizer (GPORCA)
