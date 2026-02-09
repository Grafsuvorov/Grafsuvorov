create temp TABLE tmp_funds_center_master_data WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
) /*ON COMMIT drop*/ as (
	select
		fcmd.financial_management_area_code,
		funds_center_code,
		dt_valid_from,
		dt_valid_to,
		funds_center_short_name_rus,
		funds_center_full_name_rus,
		row_number() over (partition by financial_management_area_code, funds_center_code order by dt_valid_to desc) as rn
	from
		dict_dds.funds_center_master_data fcmd
) 
DISTRIBUTED replicated;



---сбор статистики ods-dds
analyze ods.map_planned_repayment_dates_keys;
analyze dds.aldor_edm_document; ---в релиз должна уйти от mm
analyze dds.accounting_document_partner_mirror_relation;
analyze dds.invoice_realization_claim;
analyze dds.invoice_realization;

---сбор статистики dm_calc - dm
analyze dm_calc.account_debt;
analyze dm_calc.account_debt_revaluation;
analyze dm_calc.accounting_document_contracts;
analyze dm_calc.operating_periods_for_account_debt;
analyze dm_calc.accounting_document_header; --параллельная задача в релиз 
analyze dm_calc.unpaid_payment_request;--параллельная задача в релиз 
analyze dm_calc.sales_invoice_and_invoice_realization_relation;
analyze dm.paydox_credit_limits;

---сбор статистики справочники
analyze dict_dds.currency_rates;
analyze dict_dds.unit_balance;
analyze dict_dds.general_ledger_account_chart;
analyze dict_dds.plant_and_subsidiary;
analyze dict_dds.counterparty ;
analyze dict_dds.address; ---в релиз должна уйти от mm
analyze dict_dds.terms_of_payment_texts;
analyze dict_dds.responsibility_center_texts;
analyze dict_dds.financial_position_master_data_texts;
analyze dict_dds.funds_center_master_data ;
analyze dict_dds.accounting_document_type_texts; 
analyze dict_dds.material_specification;
analyze dict_dds.country_texts;
analyze dict_dds.country;
analyze dict_dds.market_region1_texts;
analyze dict_dds.material_shape_texts;
---------------------------------

---позиции задолженности размноженные на подпозиции из интегротаблицы
CREATE TEMP TABLE ad_wic_debts
WITH (
  appendonly=true,
  orientation=column,
  compresstype=zstd,
  compresslevel=3
) /*ON COMMIT drop*/ as (
select 
	p.dt
	, concat(p.unit_balance_code, p.fiscal_year, p.accounting_document_code, p.position_line_item, coalesce(m.accounting_document_subposition_code::numeric,0)) as debt_row_identifier_code
	, p.is_second_friday
	, p.unit_balance_code
	, p.fiscal_year
	, p.accounting_document_code
	, p.position_line_item
	, coalesce(m.accounting_document_subposition_code::numeric,0) as accounting_document_subposition_code----правильно ли вопрос
	, p.dt_debt
	, coalesce(m.dt_baseline_due_date_calculation, '2299-12-31') as dt_overdue
	, p.dt_clearing
	, p.contract_number
	, p.counterparty_code
	, p.debit_or_credit
	, p.account_type
	, p.general_ledger_account_code
	, p.debt_balance_document_currency_amount
	, p.debt_balance_local_currency_amount
	, p.debt_balance_second_local_currency_amount 
	, p.debt_balance_with_revaluation_diff_second_currency_amount
	, p.debt_balance_usd_amount
	, p.document_currency_code
	, p.local_currency_code
	, p.second_local_currency_code
	, p.accounting_document_type
	, p.reverse_document_code
	, p.reference_document_number
	, p.accounting_document_status_code
	, p.clearing_document_code
	, p.tax_code
	, p.position_line_item_text
	, p.special_general_ledger_indicator
	, p.dt_baseline_due_date_calculation
	, p.assignment_number
	, p.dt_accounting_document
	, p.plant_code
	, p.terms_of_payment_code
	, m.funds_center_code
		---не нашли в маппере - берем рассчитанное самостоятельно без разбивки на подпозиции
	, coalesce(m.debt_subposition_document_currency_amount, p.document_currency_amount) as debt_subposition_document_currency_amount
	, coalesce(m.debt_subposition_local_currency_amount, p.local_currency_amount) as debt_subposition_local_currency_amount
	, coalesce(m.debt_subposition_second_local_currency_amount, p.second_local_currency_amount) as debt_subposition_second_local_currency_amount
	, p.document_currency_amount
	, p.local_currency_amount
	, p.second_local_currency_amount
	, p.usd_amount
	, p.reverse_document_fiscal_year
	, p.reason_for_reversal
	, p.invoice_document_code
	, p.fiscal_year_of_relevant_invoice
	, p.position_number_of_relevant_invoice
	, p.final_position_line_item 
	, p.final_fiscal_year 
	, p.final_accounting_document_code 
	, p.exchange_diff_local_currency_amount
	, p.debt_balance_exchange_diff_local_currency_amount
	, p.exchange_diff_second_local_currency_amount
	, p.debt_balance_exchange_diff_second_local_currency_amount 
	, m.financial_position_code
	, p.reference_operation_type_code
	, p.reference_object_key_code
	, coalesce(mirr.reference_object_key, case when p.reference_operation_type_code = 'VBRK' then p.reference_object_key_code end) as mirr_invoice_code
	, case
		when p.reference_operation_type_code = 'RMRP' and p.account_type='K'
        then p.reference_object_key_code
		when p.reference_operation_type_code = 'BKPFF'  and p.account_type='K'
		then
			concat (substring(p.reference_object_key_code from 11 for 4),
			 substring(p.reference_object_key_code from 0 for 11),
			 substring(p.reference_object_key_code from 15 for 4))
		end   as for_edo_reference_object_key_code	
	from 
		dm_calc.account_debt p
left join ods.map_planned_repayment_dates_keys m on
		p.unit_balance_code = m.unit_balance_code
		and p.fiscal_year = m.accounting_document_fiscal_year
		and p.accounting_document_code  = m.accounting_document_code 
		and p.position_line_item = m.accounting_document_position_code
left join dds.accounting_document_partner_mirror_relation  as mirr on
		mirr.mirror_accounting_document_unit_balance_code = p.unit_balance_code 
		and mirr.mirror_accounting_document_code = p.accounting_document_code 
		and mirr.mirror_accounting_document_fiscal_year::numeric = p.fiscal_year
		and mirr.reference_operation_type_code = 'VBRK'
where 1 = 1
---Вставляем удаленные за два предыдущих месяца+конецпредпредущего
--and p.dt >='2025-01-01'
  	and (p.dt between  (date_trunc('month', now()) - interval '1 month'- interval '1 day')::date and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date)
	and p.deleted_flag is false 
	and (m.deleted_flag is false or m.deleted_flag is null)
	and (mirr.deleted_flag is false or mirr.deleted_flag is null))
DISTRIBUTED BY (dt,debt_row_identifier_code);

analyze ad_wic_debts;


----расчет остатка задолженности + перекурсовки в разрезе подпозиций
CREATE TEMP TABLE ad_wic_debts_sum
WITH (
  appendonly=true,
  orientation=column,
  compresstype=zstd,
  compresslevel=3
) /*ON COMMIT drop */as (
with tmp_rates as (
select 
	ta.unit_balance_code,
	coalesce(ccf.currency_rate_type_alternative_code, ta.currency_rate_type_code) as currency_rate_type_code,
	ccf.currency_from_code,
	ccf.dt_currency_rate_from,
	ccf.dt_currency_rate_to
from 
	dict_dds.unit_balance ta 
left join dict_dds.currency_conversion_factors ccf on
	ccf.currency_rate_type_code = ta.currency_rate_type_code
	and ta.additional_local_currency_control_code = '30'
	and ccf.currency_to_code = 'USD'
group by ta.unit_balance_code,
	coalesce(ccf.currency_rate_type_alternative_code, ta.currency_rate_type_code),
	ccf.currency_from_code,
	ccf.dt_currency_rate_from,
	ccf.dt_currency_rate_to),
debts as(
select
	p.dt
	, p.debt_row_identifier_code
	, p.unit_balance_code
	, p.fiscal_year
	, p.accounting_document_code
	, p.position_line_item
	, p.dt_debt
	, p.document_currency_code
	, p.local_currency_code 
	, p.second_local_currency_code
	, p.debt_balance_usd_amount
	, p.debt_balance_exchange_diff_local_currency_amount
	, p.debt_balance_local_currency_amount
	, p.debt_balance_second_local_currency_amount
	, p.debt_balance_exchange_diff_second_local_currency_amount
	, p.debt_balance_document_currency_amount
	, p.document_currency_amount 
	, p.local_currency_amount
	, p.second_local_currency_amount 
	, accounting_document_subposition_code,
		---не нашли в маппере - берем рассчитанное самостоятельно без разбивки на подпозиции
		
		case when  p.debt_balance_document_currency_amount <= 0 then -1 else 1 end *
			least (case	when p.debt_balance_document_currency_amount < 0 and p.debit_or_credit = 'H' then -1 else 1 end * 
			case when ( p.debit_or_credit = 'H' and p.debt_balance_document_currency_amount = 0) then -1 else 1 end*
			p.debt_subposition_document_currency_amount,(
	---уменьшаем платеж на сумму погашений, если погашения больше подпозиции платежа, то отражаем 0, а остаток погашений вычитаем из следующих подпозиций
	---за вычитание подпозиций отвечает оконная функция	
	---причем из-за накопления погашений(особенность оконных функций), если последний платеж не обрабатывался ,то в расчетном показателе будет последний платеж+остатки от платежей до
	--для этого сравниваем с уменьшаемой суммой рассчетную величину и если она меньше рассчитанного значения, то берем именно ее		
			greatest (0,case when sign(p.debt_balance_document_currency_amount) + sign(p.document_currency_amount) in (0) then -1 else 1 end *  (sum(abs(coalesce(p.debt_subposition_document_currency_amount, 0))) over wdebt
	---max - тк сумма погашений считается в рамках документа, а не подпозиций	
	--если знаки разные добавить ветку		
		   -max(abs(p.debt_balance_document_currency_amount - p.document_currency_amount)) over wdebt )) )) as debt_balance_subposition_document_currency_amount

	-------Валюта ВВ------------
		 , case 
	---Если остаток непогашенной задолженности = 0, то по подпозициям тоже будет 0		   
			   when p.debt_balance_local_currency_amount  = 0  then 0
	---Если знаки у непогашенной задолженности и изначальной суммы документа разные, то из-за курсовых разниц произошла перекрутка знака
	----> в остаток КЗ по подпозиции в последнюю подпозицию пишем сумму непогашенной задолженности, остальные подпозиции будут = 0	
	---debit_or_credit = 'H'	   
			   when (p.debt_balance_local_currency_amount  > 0 and p.local_currency_amount < 0)  then
					case when 
					---max - тк сумма погашений считается в рамках документа, а не подпозиций	
						(((sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt
							-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt )) ) 
							<> 
			 			  (sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt2	
		  					-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt2) 
		  			 then 0 else 
		   				case when sign(p.debt_balance_local_currency_amount) + sign(p.debt_balance_document_currency_amount) =-1  then 1 else -1 end *
							(sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt2	
		   					-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt2)
		   			end
	 ---debit_or_credit = 'S'	 
		   			 when ((p.debt_balance_local_currency_amount  < 0 and p.local_currency_amount > 0))  then
					case when 
					---max - тк сумма погашений считается в рамках документа, а не подпозиций	
						(((sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt
							-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt )) ) 
							<> 
			 			  (sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt2	
		  					-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt2) 
		  			 then 0 else 
		   			--	case when sign(p.debt_balance_local_currency_amount) + sign(p.debt_balance_document_currency_amount) /*=-1*/ in ('-1','-2')  then 1 else -1 end *
							(sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt2	
		   					-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt2)
		   			end
	----В остальных случаях уменьшаем остаток на сумму частичных погашений	     
				else 
					case when p.debt_balance_local_currency_amount < 0 then -1 else 1 end *
					least (case	when p.debt_balance_local_currency_amount < 0 then -1 else 1 end *
						 case when (sign(p.debt_balance_local_currency_amount) + sign(p.debt_balance_document_currency_amount)) in (-1, 0)  
				         and (p.debt_balance_document_currency_amount <> 0 ) then -1 else 1 end * 
							p.debt_subposition_local_currency_amount, (	
								greatest (0,(case when  sign(p.debt_balance_local_currency_amount) + sign(p.debt_balance_document_currency_amount) in (-1, 0) and ( sign(p.debt_balance_document_currency_amount) <> 0 )  then -1 else 1 end * (
									(sum(abs(coalesce(p.debt_subposition_local_currency_amount, 0))) over wdebt
			---max - тк сумма погашений считается в рамках документа, а не подпозиций			
									-max(abs(p.debt_balance_local_currency_amount - p.local_currency_amount)) over wdebt )) ))))
			end		 as debt_balance_subposition_local_currency_amount
	---------------------------
	-------Валюта ВВ2------------
		, case 
	---Если остаток непогашенной задолженности = 0, то по подпозициям тоже будет 0		   
			   when p.debt_balance_second_local_currency_amount  = 0  then 0
	---Если знаки у непогашенной задолженности и изначальной суммы документа разные, то из-за курсовых разниц произошла перекрутка знака
	----> в остаток КЗ по подпозиции в последнюю подпозицию пишем сумму непогашенной задолженности, остальные подпозиции будут = 0		   
			   when (p.debt_balance_second_local_currency_amount  > 0 and p.second_local_currency_amount < 0) then
					case when 
					---max - тк сумма погашений считается в рамках документа, а не подпозиций	
						(((sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt
							-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt )) ) 
							<> 
			 			  (sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt2	
		  					-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt2) 
		  			 then 0 else 
		   				case when sign(p.debt_balance_second_local_currency_amount) + sign(p.debt_balance_document_currency_amount) =-1  then 1 else -1 end *
							(sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt2	
		   					-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt2)
		   			end
		   			
		   			 when (p.debt_balance_second_local_currency_amount  < 0 and p.second_local_currency_amount > 0) then
					case when 
					---max - тк сумма погашений считается в рамках документа, а не подпозиций	
						(((sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt
							-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt )) ) 
							<> 
			 			  (sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt2	
		  					-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt2) 
		  			 then 0 else 
		   			--	case when sign(p.debt_balance_second_local_currency_amount) + sign(p.debt_balance_document_currency_amount) /*=-1*/ in ('-1','-2')  then 1 else -1 end *
							(sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt2	
		   					-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt2)
		   			end
	----В остальных случаях уменьшаем остаток на сумму частичных погашений	     
				else 
					case when p.debt_balance_second_local_currency_amount < 0 then -1 else 1 end *
					least (case	when p.debt_balance_second_local_currency_amount < 0 then -1 else 1 end *
						 case when (sign(p.debt_balance_second_local_currency_amount) + sign(p.debt_balance_document_currency_amount)) in (-1, 0)  
				         and (p.debt_balance_document_currency_amount <> 0 ) then -1 else 1 end * 
							p.debt_subposition_second_local_currency_amount, (	
								greatest (0,(case when  sign(p.debt_balance_second_local_currency_amount) + sign(p.debt_balance_document_currency_amount) in (-1, 0) and ( sign(p.debt_balance_document_currency_amount) <> 0 )  then -1 else 1 end * (
									(sum(abs(coalesce(p.debt_subposition_second_local_currency_amount, 0))) over wdebt
			---max - тк сумма погашений считается в рамках документа, а не подпозиций			
									-max(abs(p.debt_balance_second_local_currency_amount - p.second_local_currency_amount)) over wdebt )) ))))
			end	 as debt_balance_subposition_second_local_currency_amount
		, p.contract_number
		, p.counterparty_code
	from 
		ad_wic_debts p
	where 1 = 1
	window wdebt as (partition by p.dt,
		p.unit_balance_code,
		p.fiscal_year,
		p.accounting_document_code,
		p.position_line_item
	order by
		p.dt_overdue,
		p.accounting_document_subposition_code), ----было debt_subposition_number стало accounting_document_subposition_code
	 wdebt2 as (partition by p.dt,
		p.unit_balance_code,
		p.fiscal_year,
		p.accounting_document_code,
		p.position_line_item))
	select 
		p.dt
		, p.debt_row_identifier_code
		, p.unit_balance_code
		, p.fiscal_year
		, p.accounting_document_code
		, p.position_line_item
		, accounting_document_subposition_code
		, p.debt_balance_subposition_document_currency_amount		
		, p.debt_balance_subposition_local_currency_amount
	 	, p.debt_balance_subposition_second_local_currency_amount
	 	
	-----переводим по курсу на дату проводки debt_balance_subposition_usd_amount
		, case 
			when p.document_currency_code = 'USD' then p.debt_balance_subposition_document_currency_amount
		   	when p.local_currency_code = 'USD' then p.debt_balance_subposition_local_currency_amount
			when p.second_local_currency_code = 'USD' then p.debt_balance_subposition_second_local_currency_amount
			else p.debt_balance_subposition_document_currency_amount
			* coalesce(r.currency_to_multiplier,1) * case when coalesce(r.currency_rate,1) > 0 then coalesce(r.currency_rate, 1) else 1 end / 
			(case when coalesce(r.currency_rate, 1) < 0 then abs(coalesce(r.currency_rate,1)) else 1 end * coalesce(r.currency_from_multiplier,1))end::numeric(15,2)
	-- DWH-1634
		as debt_balance_subposition_usd_amount
	
	------debt_balance_subposition_document_currency_to_usd_amount - переводим по курсу на dt
		, (p.debt_balance_subposition_document_currency_amount
			* coalesce(r2.currency_to_multiplier,1) * case when coalesce(r2.currency_rate,1) > 0 then coalesce(r2.currency_rate, 1) else 1 end / 
			(case when coalesce(r2.currency_rate, 1) < 0 then abs(coalesce(r2.currency_rate,1)) else 1 end * coalesce(r2.currency_from_multiplier,1)))::numeric(15,2)
		as debt_balance_subposition_document_currency_to_usd_amount
	
	-------debt_balance_subpos_no_revaluation_local_currency_amount
		, case 
			when sum(p.debt_balance_subposition_document_currency_amount ) over position_agr = 0
			then 0 
			else ((sum(p.debt_balance_subposition_local_currency_amount) over position_agr) * p.debt_balance_subposition_document_currency_amount /
				(sum(p.debt_balance_subposition_document_currency_amount ) over position_agr)) end
		as debt_balance_subpos_no_revaluation_local_currency_amount
	
	-------debt_balance_subpos_no_revaluation_sec_local_curr_amount---------
		, case
			when sum(p.debt_balance_subposition_document_currency_amount ) over position_agr = 0 
			then 0 
			else ((sum(p.debt_balance_subposition_second_local_currency_amount) over position_agr) * p.debt_balance_subposition_document_currency_amount /
				(sum(p.debt_balance_subposition_document_currency_amount ) over position_agr)) end
		as debt_balance_subpos_no_revaluation_sec_local_curr_amount
	
	-------debt_balance_subposition_no_revaluation_usd_amount---------------
		, case 
			when p.document_currency_code = 'USD' 
			then  p.debt_balance_subposition_document_currency_amount
		   	when p.local_currency_code = 'USD'  	
	-------Валюта ВВ------------
	----Если общая сумма непогашенной задолженности  в ВД = 0 , считаем что ноль 
			then case
					when sum(p.debt_balance_subposition_document_currency_amount ) over position_agr = 0 
					then 0 
				----иначе разбиваем сумму в ВВ пропорционально сумме в ВД по подпозиции
					else ((sum(p.debt_balance_subposition_local_currency_amount) over position_agr) * p.debt_balance_subposition_document_currency_amount /
					(sum(p.debt_balance_subposition_document_currency_amount) over position_agr)) end
	-------Валюта ВВ2------------
			when p.second_local_currency_code = 'USD' 
			then case 
					when sum(p.debt_balance_subposition_document_currency_amount ) over position_agr = 0 then 0 
					else((sum(p.debt_balance_subposition_second_local_currency_amount) over position_agr) * p.debt_balance_subposition_document_currency_amount /
					(sum(p.debt_balance_subposition_document_currency_amount ) over position_agr)) end
			else
	--валюта не подошла
	-------Разбиваем сумму позиции в USD пропорционально ВД------------
			case 
				when sum(p.debt_balance_subposition_document_currency_amount ) over position_agr = 0 then 0
				else(p.debt_balance_usd_amount * p.debt_balance_subposition_document_currency_amount /
				(sum( p.debt_balance_subposition_document_currency_amount) over position_agr)) end end
	
		as debt_balance_subposition_no_revaluation_usd_amount
	
		, p.debt_balance_exchange_diff_local_currency_amount
		, p.debt_balance_exchange_diff_local_currency_amount * 
		   p.debt_balance_subposition_local_currency_amount/nullif(p.debt_balance_local_currency_amount,0) as debt_balance_subpos_exch_diff_local_currency_amount
		, p.debt_balance_exchange_diff_second_local_currency_amount
		, p.debt_balance_exchange_diff_second_local_currency_amount * 
		  p.debt_balance_subposition_second_local_currency_amount/nullif(p.debt_balance_second_local_currency_amount,0)  as debt_balance_subpos_exch_diff_second_local_curr_amount
	    , case
			when p.document_currency_code='USD' 
				then p.document_currency_amount 
	        when p.local_currency_code='USD' 
	        	then p.local_currency_amount
	        when p.second_local_currency_code='USD' 
	       		then p.second_local_currency_amount 
	        else 
	        	p.document_currency_amount * coalesce(r.currency_to_multiplier,1) * 
	        	case when coalesce(r.currency_rate,1) > 0 then coalesce(r.currency_rate, 1) else 1 end / 
				(case when coalesce(r.currency_rate, 1) < 0 then abs(coalesce(r.currency_rate,1)) 
				else 1 end * coalesce(r.currency_from_multiplier,1)) 
		end as usd_amount,
		coalesce(r.currency_to_multiplier,1) * 
	        	case when coalesce(r.currency_rate,1) > 0 then coalesce(r.currency_rate, 1) else 1 end / 
				(case when coalesce(r.currency_rate, 1) < 0 then abs(coalesce(r.currency_rate,1)) 
				else 1 end * coalesce(r.currency_from_multiplier,1)) 
		 as rate_m,
		coalesce(r2.currency_to_multiplier,1) * case when coalesce(r2.currency_rate,1) > 0 then coalesce(r2.currency_rate, 1) else 1 end / 
			(case when coalesce(r2.currency_rate, 1) < 0 then abs(coalesce(r2.currency_rate,1)) else 1 end 
			* coalesce(r2.currency_from_multiplier,1)) as rate_alt
		, p.contract_number
		, p.counterparty_code
	from 
		debts as p
	left join (select 
		r.currency_rate_type_code,
		r.dt_currency_rate,
		r.currency_rate,
		r.currency_from_code,
		r.currency_to_code,
		r.currency_from_multiplier,
		r.currency_to_multiplier 
	from 
		dict_dds.currency_rates r 
	where 
		r.currency_to_code = 'USD' 
		and r.currency_rate_type_code = 'M'
		and r.deleted_flag = false) r on
		r.dt_currency_rate = p.dt_debt
		and r.currency_from_code = p.document_currency_code
	left join tmp_rates as rate_type on 
		 rate_type.unit_balance_code = p.unit_balance_code
	 	and rate_type.dt_currency_rate_from <= p.dt
		and rate_type.dt_currency_rate_to >= p.dt
		and rate_type.currency_from_code = p.document_currency_code
	left join (select 
		r.currency_rate_type_code,
		r.dt_currency_rate,
		r.currency_rate,
		r.currency_from_code,
		r.currency_to_code,
		r.currency_from_multiplier,
		r.currency_to_multiplier 
	from 
		dict_dds.currency_rates r 
	where 
		r.currency_to_code = 'USD' 
		and r.deleted_flag = false) as r2  on
		r2.dt_currency_rate = p.dt
		and r2.currency_from_code = p.document_currency_code
		and r2.currency_rate_type_code = coalesce(rate_type.currency_rate_type_code, 'M')
	window position_agr as (
		partition by p.dt,
		p.unit_balance_code,
		p.fiscal_year, 
		p.accounting_document_code,
		p.position_line_item))
	DISTRIBUTED BY (dt,debt_row_identifier_code);


analyze ad_wic_debts_sum;


----агрегация по контрактам пересчетов из предыдущей tmp таблицы + вешаем суммы на ключи
CREATE TEMP TABLE ad_wic_aggr_contracts
WITH (
  appendonly=true,
  orientation=column,
  compresstype=zstd,
  compresslevel=3
) /*ON COMMIT drop*/ as (
with paydoxlim as (
select
	p.dt,
	p.unit_balance_code,
	pcl.credit_limit_counterparty_code,
	sum(pcl.paydox_credit_limit_usd_currency_amount) as paydox_credit_limit_usd_currency_amount
from
	dm_calc.operating_periods_for_account_debt as p
join dm.paydox_credit_limits as pcl on
	pcl.paydox_credit_limit_status_code = '4'
	and (p.dt >= pcl.dt_paydox_credit_limit_valid_from
	and p.dt <= pcl.dt_paydox_credit_limit_valid_to)
	and (p.dt between  (date_trunc('month', now()) - interval '1 month'- interval '1 day')::date and (date_trunc('month', now()) + interval '1 month' - interval '1 day')::date)
	--and (p.dt between '2025-11-30' and '2026-01-31')
where
	1 = 1
group by 
	p.dt,
	p.unit_balance_code,
	pcl.credit_limit_counterparty_code),
agr_contracts as (
---материализовать, в памяти считает плохо
select 
	p.dt,
	p.contract_number,
	p.counterparty_code,
	sum(p.debt_balance_subposition_usd_amount) as debt_balance_contract_usd_amount,
	sum(p.debt_balance_subposition_document_currency_to_usd_amount) as debt_balance_contract_document_currency_to_usd_amount,
	sum(p.debt_balance_subposition_no_revaluation_usd_amount) as debt_balance_contract_no_revaluation_usd_amount
from
	ad_wic_debts_sum  p
group by
	p.dt,
	p.contract_number,
	p.counterparty_code)
select
	p.dt,
	p.debt_row_identifier_code,
	p2.debt_balance_contract_usd_amount,
	p2.debt_balance_contract_document_currency_to_usd_amount,
	p2.debt_balance_contract_no_revaluation_usd_amount,
	paydoxlim.paydox_credit_limit_usd_currency_amount
from
	ad_wic_debts p
join agr_contracts as p2 on 
	p2.dt = p.dt
	and coalesce(p2.contract_number,'') = coalesce(p.contract_number,'' ) 
	and coalesce(p2.counterparty_code,'') = coalesce(p.counterparty_code,'')
left join paydoxlim as paydoxlim on
	p.dt = paydoxlim.dt
	and p.unit_balance_code = paydoxlim.unit_balance_code
	and p.counterparty_code = paydoxlim.credit_limit_counterparty_code
where
	p.contract_number is not null
	or p.counterparty_code is not null)
distributed by (dt, debt_row_identifier_code);

analyze ad_wic_aggr_contracts; 

insert into dm.account_debt_for_working_capital(
	dt,
	is_second_friday,
	debt_row_identifier_code,
	unit_balance_code, 
	fiscal_year, 
	accounting_document_code,	
	dt_debt,
	dt_overdue,
	dt_clearing,
	contract_number, 
	counterparty_code,
	debit_or_credit, 
	account_type, 
	general_ledger_account_code, 
	debt_balance_document_currency_amount, 
	debt_balance_local_currency_amount, 
	debt_balance_second_local_currency_amount, 
	debt_balance_with_revaluation_diff_second_currency_amount, 
	debt_balance_position_usd_amount,
	document_currency_code, 
	local_currency_code, 
	second_local_currency_code, 
	accounting_document_type,
	accounting_document_type_name,
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
	plant_code, 
	plant_name,
	general_ledger_account_full_name,
	unit_balance_name, 
	counterparty_full_name, 
	external_contract_number,
	dt_external_contract,	
	contract_trader_code,
	contract_trader_name,
	terms_of_payment_code,
	terms_of_payment_name, 
	responsibility_center_code, 
	responsibility_center_name, 
	budget_subtype_code, 
	contract_supervisor_employee_number, 
	contract_supervisor_name, 
	purchase_or_sales_group_code,
	purchase_or_sales_group_name, 
	funds_center_code, 
	funds_center_name, 
	debt_subposition_number,
	debt_subposition_local_currency_amount,
	debt_subposition_document_currency_amount,
	debt_subposition_second_local_currency_amount,
	is_debt_daily_calculated,
	country_code,
	counterparty_hfm_code,
	counterparty_mdm_code,
	is_related_party_tco,
	is_group_company_affiliated,
	is_related_party_rsbo,
	is_bankrupt,
	is_lawsuit_exist,
	is_fns_restriction_list_exist,
	document_currency_amount,
	local_currency_amount,
	second_local_currency_amount,
	counterparty_tin_code,
	reverse_document_fiscal_year,
	reason_for_reversal,
	debt_balance_subposition_document_currency_amount,
	debt_balance_subposition_local_currency_amount,
	debt_balance_subposition_second_local_currency_amount,
	debt_balance_subposition_usd_amount,
	debt_balance_subposition_document_currency_to_usd_amount,
	debt_balance_subpos_no_revaluation_local_currency_amount,
	debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	debt_balance_subposition_no_revaluation_usd_amount,
	debt_balance_contract_usd_amount,
	debt_balance_contract_document_currency_to_usd_amount,
	debt_balance_contract_no_revaluation_usd_amount,
	paydox_credit_limit_usd_currency_amount,
	invoice_document_code,
	fiscal_year_of_relevant_invoice,
	position_number_of_relevant_invoice,
	final_position_line_item,
	final_fiscal_year,
 	final_accounting_document_code,
 	exchange_diff_local_currency_amount,
 	debt_balance_exchange_diff_local_currency_amount,
 	debt_balance_subpos_exch_diff_local_currency_amount,
 	exchange_diff_second_local_currency_amount,
 	debt_balance_exchange_diff_second_local_currency_amount, 
 	debt_balance_subpos_exch_diff_second_local_curr_amount, 
	counterparty_truncated_code,
    counterparty_search_name,
    responsibility_center_level1_code,
    responsibility_center_level1_name,
    financial_position_code,
    financial_position_name,
    usd_amount,
    realization_invoice_code, 
    realization_document_code,
    country_of_end_user_code,
    country_of_end_user_name,
    region_of_end_user_code,
    region_of_end_user_name,
    sales_invoice_code,
    material_shape_code,
    material_shape_name,
    receivable_claim_number,
    receivable_claim_paydox_url,
    dt_receivable_claim,
    reference_operation_type_code,
    reference_object_key_code,
    material_code,
	bank_as_counterparty_code,
	almer_bank_code,
	bank_as_counterparty_name,
    paydox_document_url,
    contract_list,
	contract_list_with_paydox_url,
	external_contract_source_table_name,
	unpaid_payment_request_code,
	purchase_order_code,
	purchase_specification_compound_number,
	dt_edm_counterparty_electonic_signature,
	accounting_document_created_by,
	vat_rate,
	debt_overdue_penalty_document_currency_amount
)
--explain analyze
with edo as (
select
	t.reference_object_key_code as reference_object_key,
	min(t.dt_created)::date as dt_created
from  
	dds.aldor_edm_document t
group by
	t.reference_object_key_code),
debt_contracts as (
select
	p.dt,
	p.debt_row_identifier_code,
	contracts.external_contract_number, 
	contracts.dt_external_contract, 
	contracts.contract_trader_code, 
	contracts.contract_trader_name, 
	contracts.responsibility_center_code,  
	contracts.contract_supervisor_code as contract_supervisor_employee_number, 
	contracts.contract_supervisor_name, 
	contracts.purchase_or_sales_group_code, 
	contracts.purchase_or_sales_group_name,
	contracts.paydox_document_url,
	contracts.contract_list,
	contracts.contract_list_with_paydox_url,
	contracts.responsibility_center_level1_code as responsibility_center_level1_code,
	contracts.external_contract_source_table_name,
	case
		when p.account_type = 'K' then upr.unpaid_payment_request_code
	end as unpaid_payment_request_code
from
	ad_wic_debts p
----- по идее +- одинаково распределять	
left join dm_calc.accounting_document_contracts as contracts on 
	contracts.unit_balance_code = p.unit_balance_code
	and contracts.fiscal_year = p.fiscal_year
	and contracts.accounting_document_code = p.accounting_document_code
	and contracts.accounting_document_position_code = p.position_line_item
----- по идее +- одинаково распределять + в контрактах те же базовые документы	
left join dm_calc.unpaid_payment_request upr on
	p.unit_balance_code = upr.unit_balance_code
	and p.fiscal_year = upr.fiscal_year
	and p.accounting_document_code = upr.invoice_document_code
	and p.position_line_item = upr.invoice_document_position_code
where
	contracts.unit_balance_code is not null
	or upr.unit_balance_code is not null),
debt_headers as (
select
	p.dt,
	p.debt_row_identifier_code,
	wic.material_for_reporting_code as material_code,
	case
		when p.account_type = 'K' then wic.purchase_order_for_reporting_code
	end as purchase_order_for_reporting_code,
	case
		when p.account_type = 'K' then wic.purchase_specification_compound_number
	end as purchase_specification_compound_number,
	wic.accounting_document_created_by
from
	ad_wic_debts p
join dm_calc.accounting_document_header wic on 
	wic.unit_balance_code = p.unit_balance_code
	and wic.fiscal_year = p.fiscal_year
	and wic.accounting_document_code = p.accounting_document_code),
---аналитики из сбыта	
debt_sd as (
select   
	p.dt,
	p.debt_row_identifier_code,
	sir.invoice_realization_code as realization_invoice_code,
	ir.invoice_realization_group_code as realization_document_code,
	sir.country_of_destination_code as country_of_end_user_code,
	ct.country_short_name as country_of_end_user_name,
	co.market_region1_code as region_of_end_user_code,
	rt.market_region1_name as region_of_end_user_name,
	sir.sales_invoice_code,
	ir.claim_code as receivable_claim_number,
	irc.paydox_claim_url as receivable_claim_paydox_url,
	irc.dt_claim as dt_receivable_claim,
	sir.sales_bank_account_code as bank_as_counterparty_code,
	con.almer_bank_code,
	con.counterparty_full_name as bank_as_counterparty_name,
	(ir.document_currency_vat_excluded_amount
	-- Сумма по фактуре реализации 
		* scp.claim_penalty_amount
	-- Сумма штрафа по ключам: дата среза, претензия, фактура сбыта
		/ nullif(sum(ir.document_currency_vat_excluded_amount) over (partition by ir.sales_invoice_code,
	scp.dt_report),0)
	-- Общая сумма по фактуре сбыта 
	) as debt_overdue_penalty_document_currency_amount
	-- SD.001401 Сумма неустойки
from
	ad_wic_debts p
left join dm_calc.sales_invoice_and_invoice_realization_relation sir on
	p.mirr_invoice_code = sir.invoice_realization_code
	---and p.reference_operation_type_code = 'VBRK'  
left join dds.invoice_realization ir on
	p.mirr_invoice_code = ir.invoice_realization_code
	---and p.reference_operation_type_code = 'VBRK'
left join dds.sales_claim_penalty_daily_balance scp on 
	scp.sales_invoice_code = ir.sales_invoice_code
	and scp.dt_report = p.dt
left join dict_dds.country_texts ct on
	sir.country_of_destination_code = ct.country_code
	and ct.language_code = 'R'
left join dict_dds.country co on
	sir.country_of_destination_code = co.country_code
left join dict_dds.market_region1_texts rt on
	co.market_region1_code = rt.market_region1_code
	and rt.language_code = 'R'
left join dds.invoice_realization_claim irc on
	ir.claim_code = irc.claim_code
left join dict_dds.counterparty con on 
	sir.sales_bank_account_code = con.counterparty_code
where
	p.mirr_invoice_code is not null	),
debt_edo as (
select
	p.dt,
	debt_row_identifier_code,
	awkey.dt_created as dt_edm_counterparty_electonic_signature
from
	ad_wic_debts p
join edo as awkey on   
	awkey.reference_object_key = p.for_edo_reference_object_key_code
where
	p.for_edo_reference_object_key_code is not null)
select 
	p.dt,
	p.is_second_friday,
	p.debt_row_identifier_code,
	p.unit_balance_code, 
	p.fiscal_year, 
	p.accounting_document_code,	
	p.dt_debt,
	p.dt_overdue,
	p.dt_clearing,
	p.contract_number, 
	p.counterparty_code,
	p.debit_or_credit, 
	p.account_type, 
	p.general_ledger_account_code, 
	p.debt_balance_document_currency_amount, 
	p.debt_balance_local_currency_amount, 
	p.debt_balance_second_local_currency_amount, 
	p.debt_balance_with_revaluation_diff_second_currency_amount, 
	p.debt_balance_usd_amount as debt_balance_position_usd_amount,
	p.document_currency_code, 
	p.local_currency_code, 
	p.second_local_currency_code, 
	p.accounting_document_type,
	dkd.accounting_document_type_name,
	p.position_line_item, 
	p.reverse_document_code, 
	p.reference_document_number, 
	p.accounting_document_status_code, 
	p.clearing_document_code, 
	p.tax_code, 
	p.position_line_item_text, 
	p.special_general_ledger_indicator,
	p.dt_baseline_due_date_calculation, 
	p.assignment_number, 
	p.dt_accounting_document, 
	p.plant_code, 
	pl.plant_full_name as plant_name, 
	acc.general_ledger_account_full_name_rus as general_ledger_account_full_name, 
	be.unit_balance_name as unit_balance_name, 
	cnt.counterparty_full_name, 
	contracts.external_contract_number, 
	contracts.dt_external_contract, 
	contracts.contract_trader_code, 
	contracts.contract_trader_name, 
	p.terms_of_payment_code, 
	tpt.terms_of_payment_name, 
	contracts.responsibility_center_code, 
	coalesce(fcmd2.funds_center_full_name_rus,
	fcmd2_1.funds_center_full_name_rus) as responsibility_center_name, 
	cnt.budget_subtype_code, 
	contracts.contract_supervisor_employee_number, 
	contracts.contract_supervisor_name, 
	contracts.purchase_or_sales_group_code, 
	contracts.purchase_or_sales_group_name,
	p.funds_center_code, 
	coalesce(fcmd.funds_center_full_name_rus,
	fcmd_1.funds_center_full_name_rus) as funds_center_name,
	p.accounting_document_subposition_code as debt_subposition_number,
	p.debt_subposition_local_currency_amount,
	p.debt_subposition_document_currency_amount,
	p.debt_subposition_second_local_currency_amount,
	case
		when p.dt = (date_trunc('month',
		now()) - interval '1 day')::date then 'X'
		else null
	end as is_debt_daily_calculated, 
	a.country_code, 
	cnt.counterparty_hfm_code, 
	cnt.counterparty_mdm_code, 
	cnt.is_related_party_tco, 
	cnt.is_group_company_affiliated, 
	cnt.is_related_party_rsbo, 
	cnt.is_bankrupt, 
	cnt.is_lawsuit_exist, 
	cnt.is_fns_restriction_list_exist,
	p.document_currency_amount,
	p.local_currency_amount,
	p.second_local_currency_amount,
	cnt.counterparty_tin_code,
	p.reverse_document_fiscal_year,
	p.reason_for_reversal,
	pam.debt_balance_subposition_document_currency_amount,
	pam.debt_balance_subposition_local_currency_amount,
	pam.debt_balance_subposition_second_local_currency_amount,
	pam.debt_balance_subposition_usd_amount,
	pam.debt_balance_subposition_document_currency_to_usd_amount,
	pam.debt_balance_subpos_no_revaluation_local_currency_amount,
	pam.debt_balance_subpos_no_revaluation_sec_local_curr_amount,
	pam.debt_balance_subposition_no_revaluation_usd_amount,
	pamc.debt_balance_contract_usd_amount,
	pamc.debt_balance_contract_document_currency_to_usd_amount,
	pamc.debt_balance_contract_no_revaluation_usd_amount,
	pamc.paydox_credit_limit_usd_currency_amount,
	p.invoice_document_code,
	p.fiscal_year_of_relevant_invoice,
	p.position_number_of_relevant_invoice,
	p.final_position_line_item,
	p.final_fiscal_year,
	p.final_accounting_document_code,
	p.exchange_diff_local_currency_amount,
	pam.debt_balance_exchange_diff_local_currency_amount,
	pam.debt_balance_subpos_exch_diff_local_currency_amount,
	p.exchange_diff_second_local_currency_amount,
	pam.debt_balance_exchange_diff_second_local_currency_amount,
	pam.debt_balance_subpos_exch_diff_second_local_curr_amount,
	cnt.counterparty_truncated_code,
	cnt.counterparty_search_name,
	coalesce(contracts.responsibility_center_level1_code,'RC1_999') ,
	--contracts.responsibility_center_level1_code,
	rct.responsibility_center_name as responsibility_center_level1_name,
	p.financial_position_code,
	fpm.financial_position_full_name as financial_position_name,
	pam.usd_amount,
	sd.realization_invoice_code,
	sd.realization_document_code,
	sd.country_of_end_user_code,
	sd.country_of_end_user_name,
	sd.region_of_end_user_code,
	sd.region_of_end_user_name,
	sd.sales_invoice_code,
	ms.shape_code as material_shape_code,
	st.material_shape_full_name as material_shape_name,
	sd.receivable_claim_number,
	sd.receivable_claim_paydox_url,
	sd.dt_receivable_claim,
	p.reference_operation_type_code,
	p.reference_object_key_code,
	wic.material_code,
	sd.bank_as_counterparty_code,
	sd.almer_bank_code,
	sd.bank_as_counterparty_name,
	contracts.paydox_document_url,
	contracts.contract_list,
	contracts.contract_list_with_paydox_url,
	contracts.external_contract_source_table_name,
	contracts.unpaid_payment_request_code ,
	wic.purchase_order_for_reporting_code ,
	wic.purchase_specification_compound_number,
	awkey.dt_edm_counterparty_electonic_signature,
	wic.accounting_document_created_by,
	vrt.vat_rate,
	sd.debt_overdue_penalty_document_currency_amount
	-- SD.001401 Сумма неустойки
from
	ad_wic_debts p
join ad_wic_debts_sum as pam on 
	p.dt = pam.dt
	and p.debt_row_identifier_code = pam.debt_row_identifier_code
left join ad_wic_aggr_contracts as pamc on 
	p.dt = pamc.dt
	and p.debt_row_identifier_code = pamc.debt_row_identifier_code
left join debt_headers wic on 
	p.dt = wic.dt
	and p.debt_row_identifier_code = wic.debt_row_identifier_code
left join debt_contracts as contracts on 
	p.dt = contracts.dt
	and p.debt_row_identifier_code = contracts.debt_row_identifier_code
left join debt_sd sd on 
	p.dt = sd.dt
	and p.debt_row_identifier_code = sd.debt_row_identifier_code
left join debt_edo as awkey on 
	p.dt = awkey.dt
	and p.debt_row_identifier_code = awkey.debt_row_identifier_code
join dict_dds.unit_balance be on
	be.unit_balance_code = p.unit_balance_code
join dict_dds.general_ledger_account_chart acc on
	acc.account_chart_code = be.account_chart_code
	and acc.general_ledger_account_code = p.general_ledger_account_code
left join dict_dds.plant_and_subsidiary pl on
	pl.plant_code = p.plant_code
left join dict_dds.counterparty cnt on
	cnt.counterparty_code = p.counterparty_code
left join dict_dds.address a on 
	a.address_code = cnt.address_code
	and a.international_display_format_code is null
	and a.deleted_flag = false
left join dict_dds.terms_of_payment_texts tpt on
	tpt.terms_of_payment_code = p.terms_of_payment_code
	and tpt.language_code = 'R'
left join dict_dds.responsibility_center_texts rct on
	rct.responsibility_center_code = coalesce(contracts.responsibility_center_level1_code,'RC1_999') 
	---- по умолчанию вместо пусто
	and rct.language_code = 'R'
left join dict_dds.financial_position_master_data_texts fpm on
	p.financial_position_code = fpm.financial_position_external_code
	and be.financial_management_area_code = fpm.financial_management_area_code
	and cast(p.dt as varchar(4))= fpm.fiscal_year
	and fpm.language_code = 'R'
left join dict_dds.country as country_be on
	be.country_code = country_be.country_code
	and current_date < country_be.dt_valid_to
left join dict_dds.vat_rates_texts as vrt on
	country_be.calculation_scheme_code = vrt.calculation_scheme_code
	and be.language_code = vrt.language_code
	and p.tax_code = vrt.vat_code
left join dict_dds.material_specification ms on 
	wic.material_code = ms.material_code
left join dict_dds.material_shape_texts st on
	ms.shape_code = st.shape_code
	and st.language_code = 'R'
left join dict_dds.funds_center_master_data fcmd2 on
	fcmd2.funds_center_code = contracts.responsibility_center_code
	and fcmd2.financial_management_area_code = be.financial_management_area_code
	and current_date between fcmd2.dt_valid_from and fcmd2.dt_valid_to
left join dict_dds.funds_center_master_data fcmd on
	fcmd.funds_center_code = p.funds_center_code
	and fcmd.financial_management_area_code = be.financial_management_area_code
	and current_date between fcmd.dt_valid_from and fcmd.dt_valid_to
left join dict_dds.accounting_document_type_texts as dkd on
	p.accounting_document_type = dkd.accounting_document_type_code
	and dkd.language_code = 'R'
left join tmp_funds_center_master_data as fcmd2_1 on
	fcmd2_1.funds_center_code = contracts.responsibility_center_code
	and fcmd2_1.financial_management_area_code = be.financial_management_area_code
	and fcmd2_1.rn = 1
left join tmp_funds_center_master_data as fcmd_1 on
	fcmd_1.funds_center_code = p.funds_center_code
	and fcmd_1.financial_management_area_code = be.financial_management_area_code
	and fcmd_1.rn = 1 ;
