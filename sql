delete from dm_calc.account_debt
where ---мы пересчитываем только за два предыдущих месяца
dt between   (date_trunc('month', now()) - interval '1 month' - interval '1 day')::date 
         and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date;

--insert into userdata.account_debt_DMCALC

--truncate dm_calc.account_debt;

insert into dm_calc.account_debt(
	dt,
	is_second_friday,
	unit_balance_code,
	plant_code, 
	fiscal_year,
 	accounting_document_code,
 	dt_debt,
	dt_clearing,
 	contract_number,
 	counterparty_code,
	debit_or_credit,
	account_type,	
	general_ledger_account_code,
 	debt_balance_document_currency_amount,
	document_currency_code,
	debt_balance_local_currency_amount,
	local_currency_code,
	debt_balance_second_local_currency_amount,
	debt_balance_with_revaluation_diff_second_currency_amount,
	debt_balance_usd_amount,
	second_local_currency_code,
	accounting_document_type,
	position_line_item,
	reverse_document_code, 
	reference_document_number, 
	accounting_document_status_code,
	clearing_document_code,
	tax_code, 
	position_line_item_text,
	special_general_ledger_indicator,
	dt_baseline_due_date_calculation, 
	assignment_number, 
	dt_accounting_document, 
	terms_of_payment_code,
	document_currency_amount,
	local_currency_amount,
	second_local_currency_amount,
	usd_amount,
	reverse_document_fiscal_year,
	reason_for_reversal,
	invoice_document_code,
	fiscal_year_of_relevant_invoice,
	position_number_of_relevant_invoice,
	final_position_line_item,
	final_fiscal_year,	
 	final_accounting_document_code,
	document_currency_code_of_relevant_invoice,
	general_ledger_account_code_of_relevant_invoice,
	debit_or_credit_code_of_relevant_invoice,
	reference_operation_type_code,
	reference_object_key_code,
	exchange_diff_local_currency_amount,
 	debt_balance_exchange_diff_local_currency_amount,
 	exchange_diff_second_local_currency_amount,
 	debt_balance_exchange_diff_second_local_currency_amount )
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
