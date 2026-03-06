insert
	into
	 dds.accounting_balance

with precte as (
	select 
		unit_balance_code , 
		max(case when cur.registry_code = '00' then cur.currency1_code else null end) as local_currency_code,
		max(case when cur.registry_code = 'ZA' then cur.currency1_code else cur.currency2_code end) as second_local_currency_code
	from
		DICT_DDS.map_unit_balance_to_registry cur
	where
		cur.registry_code = '00'
		or cur.registry_code = 'ZA'
	group by
		unit_balance_code 
),
	cte0 as (
	select
		"BUKRS" as unit_balance_code,
		"RYEAR" as fiscal_year,
		"RACCT" as general_ledger_account_code ,
		"RTCUR" as document_currency_code ,
		"DRCRK" as debit_or_credit_code,
		unnest(array['01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16']) as posting_period_mm,
		unnest(array["TSLVT",null,null,null,null,null,null,null,null,null,null,null,null,null,null,	null]) as balance_opening_document_currency_amount,
		unnest(array["HSLVT",null,null,null,null,null,null,null,null,null,null,null,null,null,null,	null]) as balance_opening_local_currency_amount,
		unnest(array["KSLVT",null,null,null,null,null,null,null,null,null,null,null,null,null,null,	null]) as balance_opening_second_local_currency_amount,
		unnest(array["TSL01","TSL02","TSL03","TSL04","TSL05","TSL06","TSL07","TSL08","TSL09","TSL10","TSL11","TSL12","TSL13","TSL14","TSL15","TSL16"]) as turnover_document_currency_amount,
		unnest(array["HSL01","HSL02","HSL03","HSL04","HSL05","HSL06","HSL07","HSL08","HSL09","HSL10","HSL11","HSL12","HSL13","HSL14","HSL15","HSL16"]) as turnover_local_currency_amount,
		unnest(array["KSL01","KSL02","KSL03","KSL04","KSL05","KSL06","KSL07","KSL08","KSL09","KSL10","KSL11","KSL12","KSL13","KSL14","KSL15","KSL16"]) as turnover_second_local_currency_amount
	from
		stg."GLT0" c
	where
		1 = 1
		and "RLDNR" = '00'
		and "RRCTY" = '0'
		and "RVERS" = '001'
union all
	select
		"BUKRS" as unit_balance_code,
		"RYEAR" as fiscal_year,
		"RACCT" as general_ledger_account_code ,
		"RTCUR" as document_currency_code ,
		"DRCRK" as debit_or_credit_code,
		unnest(array['01','02','03','04','05','06','07','08','09','10','11','12','13','14','15','16']) as posting_period_mm,
		unnest(array[0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null]) as balance_opening_document_currency_amount,
		unnest(array[0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null]) as balance_opening_local_currency_amount,
		unnest(array["HSLVT",null,null,null,null,null,null,null,null,null,null,null,null,null,null,null]) as balance_opening_second_local_currency_amount,
		unnest(array[0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null]) as turnover_document_currency_amount,
		unnest(array[0,null,null,null,null,null,null,null,null,null,null,null,null,null,null,null]) as turnover_local_currency_amount,
		unnest(array["HSL01","HSL02","HSL03","HSL04","HSL05","HSL06","HSL07","HSL08","HSL09","HSL10","HSL11","HSL12","HSL13","HSL14","HSL15","HSL16"]) as turnover_second_local_currency_amount
	from
		stg."GLT0" c
	where
		1 = 1
		and "RLDNR" = 'ZA'
		and "RRCTY" = '0'
		and "RVERS" = '001'
),

 cte1 as (
 select * from  
 (values ('H','H'),
         ('H','S'),
         ('S','H'),
         ('S','S')) 
  as t(debit_or_credit_name, debit_or_credit_code)
     ),
cte as (
select
		unit_balance_code,
		fiscal_year,
		general_ledger_account_code ,
		cte1.debit_or_credit_code,
		posting_period_mm,
		document_currency_code,
		case when cte0.debit_or_credit_code = cte1.debit_or_credit_code then balance_opening_document_currency_amount else null end as balance_opening_document_currency_amount,
		case when cte0.debit_or_credit_code = cte1.debit_or_credit_code then balance_opening_local_currency_amount else null end as balance_opening_local_currency_amount,
		case when cte0.debit_or_credit_code = cte1.debit_or_credit_code then balance_opening_second_local_currency_amount else null end as balance_opening_second_local_currency_amount,
		case when cte0.debit_or_credit_code = cte1.debit_or_credit_code then turnover_document_currency_amount else null end as turnover_document_currency_amount,
		case when cte0.debit_or_credit_code = cte1.debit_or_credit_code then turnover_local_currency_amount else null end as turnover_local_currency_amount,
		case when cte0.debit_or_credit_code = cte1.debit_or_credit_code then turnover_second_local_currency_amount else null end as turnover_second_local_currency_amount
		
from cte0
 left join cte1 
  on cte0.debit_or_credit_code = cte1.debit_or_credit_name
),
	cte2 as(
	select
		c.unit_balance_code,
		fiscal_year,
		general_ledger_account_code ,
		debit_or_credit_code,
		posting_period_mm,
		document_currency_code ,
		g.local_currency_code,
		g.second_local_currency_code,
		sum(coalesce(balance_opening_document_currency_amount, 0)) as balance_opening_document_currency_amount,
		sum(coalesce(balance_opening_local_currency_amount, 0)) as balance_opening_local_currency_amount,
		sum(coalesce(balance_opening_second_local_currency_amount, 0)) as balance_opening_second_local_currency_amount,
		sum(coalesce(turnover_document_currency_amount, 0)) as turnover_document_currency_amount,
		sum(coalesce(turnover_local_currency_amount, 0)) as turnover_local_currency_amount,
		sum(coalesce(turnover_second_local_currency_amount, 0)) as turnover_second_local_currency_amount
	from
		cte c
	left join precte as g on
		g.unit_balance_code = c.unit_balance_code
	group by
		c.unit_balance_code,
		fiscal_year,
		general_ledger_account_code ,
		document_currency_code ,
		g.local_currency_code,
		g.second_local_currency_code,
		debit_or_credit_code,
		posting_period_mm
	)
	
	-----------------------------------------------------------
	select 	
	t.unit_balance_code,
	fiscal_year,
	t.general_ledger_account_code ,
	document_currency_code ,
	local_currency_code,
	second_local_currency_code,
	debit_or_credit_code,
	posting_period_mm, 
	case when posting_period_mm='01' then balance_opening_document_currency_amount else  coalesce(lag(balance_closing_document_currency_amount, 1) over
	wbalop,	0 ) end as balance_opening_document_currency_amount,
	
	case when posting_period_mm='01' then balance_opening_local_currency_amount else coalesce(lag(balance_closing_local_currency_amount, 1) over
	wbalop,	0 ) end as balance_opening_local_currency_amount,
    	
   case when posting_period_mm='01' then balance_opening_second_local_currency_amount else coalesce(lag(balance_closing_second_local_currency_amount, 1) over
	wbalop,0 ) end balance_opening_second_local_currency_amount,
	
	turnover_document_currency_amount,
	turnover_local_currency_amount,
	turnover_second_local_currency_amount,
	balance_closing_document_currency_amount,
	balance_closing_local_currency_amount,
    balance_closing_second_local_currency_amount

		from 
----------------------		
(	
	
	select
	g.unit_balance_code,
	fiscal_year,
	general_ledger_account_code ,
	document_currency_code ,
	local_currency_code,
	second_local_currency_code,
	debit_or_credit_code,
	posting_period_mm,
    	case
		when debit_or_credit_code = 'H'	and 
	        sum(balance_opening_document_currency_amount) over wbal >= 0 then 0
		when debit_or_credit_code = 'S' and 
			sum(balance_opening_document_currency_amount) over wbal  <= 0 then 0
		else 
			(sum(balance_opening_document_currency_amount) over wbal )
			*(10 ^ (2 - coalesce(dp1.decimal_place_number,2)))::numeric(20,	2)
	end as balance_opening_document_currency_amount,
	
	case
		when debit_or_credit_code = 'H'	and 
			sum(balance_opening_local_currency_amount) over wbal >= 0 then 0
		when debit_or_credit_code = 'S'	and 
			sum(balance_opening_local_currency_amount) over wbal <= 0 then 0
		else
			(sum(balance_opening_local_currency_amount) over wbal )
			*(10 ^ (2 - coalesce(dp2.decimal_place_number,2)))::numeric(20,2)
	end as balance_opening_local_currency_amount,
	
	case
		when debit_or_credit_code = 'H'	and 
			sum(balance_opening_second_local_currency_amount) over wbal >= 0 then 0
		when debit_or_credit_code = 'S'	and 
			sum(balance_opening_second_local_currency_amount) over wbal <= 0 then 0
		else 
			(sum(balance_opening_second_local_currency_amount) over wbal ) 
			*(10 ^ (2 - coalesce(dp3.decimal_place_number,2)))::numeric(20,2)
	end	as balance_opening_second_local_currency_amount,

	
		case
		when debit_or_credit_code = 'H'	and 
			sum(balance_opening_document_currency_amount) over wbal + coalesce (sum(turnover_document_currency_amount) over wbal ,0) >= 0 then 0
		when debit_or_credit_code = 'S'	and 
			sum(balance_opening_document_currency_amount) over wbal + coalesce (sum(turnover_document_currency_amount) over wbal ,0) <= 0 then 0
		else 
			(sum(balance_opening_document_currency_amount) over wbal + coalesce (sum(turnover_document_currency_amount) over wbal ,0))
			*(10 ^ (2 - coalesce(dp1.decimal_place_number,2)))::numeric(20,2)
	end	as balance_closing_document_currency_amount,

	turnover_document_currency_amount *(10 ^ (2 - coalesce(dp1.decimal_place_number,2)))::numeric(20,2) as turnover_document_currency_amount,
	turnover_local_currency_amount *(10 ^ (2 - coalesce(dp2.decimal_place_number,2)))::numeric(20,2) as turnover_local_currency_amount,
	turnover_second_local_currency_amount *(10 ^ (2 - coalesce(dp3.decimal_place_number,2)))::numeric(20,2) as turnover_second_local_currency_amount,
	
	case
		when debit_or_credit_code = 'H'	and 
			sum(balance_opening_local_currency_amount) over wbal + coalesce (sum(turnover_local_currency_amount) over wbal ,0) >= 0 then 0
		when debit_or_credit_code = 'S'	and 
			sum(balance_opening_local_currency_amount) over wbal + coalesce (sum(turnover_local_currency_amount) over wbal ,0) <= 0 then 0
		else 
			(sum(balance_opening_local_currency_amount) over wbal + coalesce (sum(turnover_local_currency_amount) over wbal ,0))
			*(10 ^ (2 - coalesce(dp2.decimal_place_number,2)))::numeric(20,2)
	end	as balance_closing_local_currency_amount,
	
	case
		when debit_or_credit_code = 'H'	and 
			sum(balance_opening_second_local_currency_amount) over wbal + coalesce (sum(turnover_second_local_currency_amount) over wbal ,0)>= 0 then 0
		when debit_or_credit_code = 'S'	and 
			sum(balance_opening_second_local_currency_amount) over wbal + coalesce (sum(turnover_second_local_currency_amount) over wbal ,0)<= 0 then 0
		else 
			(sum(balance_opening_second_local_currency_amount) over wbal + coalesce (sum(turnover_second_local_currency_amount) over wbal ,0))
			*(10 ^ (2 - coalesce(dp3.decimal_place_number,2)))::numeric(20,2)
	end	as balance_closing_second_local_currency_amount
from
	cte2 g
left join dict_dds.currency_decimal_place_ral dp1 on
	dp1.currency_code = g.document_currency_code
left join dict_dds.currency_decimal_place_ral dp2 on 
	dp2.currency_code = g.local_currency_code
left join dict_dds.currency_decimal_place_ral dp3 on 
	dp3.currency_code = g.second_local_currency_code

window wbal as (
	partition by 
		g.unit_balance_code,
		fiscal_year,
		general_ledger_account_code ,
		document_currency_code
	order by
		posting_period_mm asc)


) as t

window	wbalop as (	
	partition by 
		t.unit_balance_code,
		fiscal_year,
		t.general_ledger_account_code,
		document_currency_code,
		debit_or_credit_code
	order by
		posting_period_mm, debit_or_credit_code );