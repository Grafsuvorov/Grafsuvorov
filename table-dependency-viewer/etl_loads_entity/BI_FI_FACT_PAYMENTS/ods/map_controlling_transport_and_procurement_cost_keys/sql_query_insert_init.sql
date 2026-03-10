insert into ods.map_controlling_transport_and_procurement_cost_keys
select
	"REPCOD"::varchar(10)	as report_version_code,
	tech_etl.util_text_to_null_validation("BUKRS")	as unit_balance_code,
	tech_etl.util_text_to_null_validation("WERKS")	as plant_code,
	tech_etl.util_text_to_null_validation("GJAHR")::numeric(4,0)	as fiscal_year,
	"PERIO"::varchar(3)	as fiscal_period,
	"LNCOD"::varchar(20)	as report_line_code,	--!! MAX LENGTH = 4 in SAP(20)
	"CLCOD"::varchar(20)	as report_column_code,	--!! MAX LENGTH = 2 in SAP(20)
	"INDX"::varchar(3) as subsequent_code,
	tech_etl.util_text_to_null_validation("KSTAR")	as cost_element_code,
	(i."WOGBTR" *(10 ^ (2 - coalesce(dp1.decimal_place_number, 2))))::numeric(17,2) as local_currency_amount,
	ub.currency_code as local_currency_code,	
	(i."WKGBTR" *(10 ^ (2 - coalesce(dp2.decimal_place_number, 2))))::numeric(17,2) as second_local_currency_amount,
	ca.currency_code as second_local_currency_code

----------------------------------------------------------------------------------------------------------------FROM
FROM stg."/RUSAL/IMTZR" i
left join dict_dds.unit_balance ub on  
		i."BUKRS" = ub.unit_balance_code  
left join dict_dds.map_controlling_area_to_unit_balance m on
	m.unit_balance_code = ub.unit_balance_code
left join dict_dds.controlling_area ca on 
	ca.controlling_area_code = m.controlling_area_code
left join dict_dds.currency_decimal_place_ral  dp1 on 
 	dp1.currency_code = ub.currency_code
left join dict_dds.currency_decimal_place_ral dp2 on 
	dp2.currency_code = ca.currency_code
----------------------------------------------------------------------------------------------------------------WHERE
WHERE 1=1
	and "MANDT" = '400';