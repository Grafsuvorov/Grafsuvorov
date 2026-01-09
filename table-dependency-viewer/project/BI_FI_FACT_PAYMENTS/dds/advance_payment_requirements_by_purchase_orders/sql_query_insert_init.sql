insert into  dds.advance_payment_requirements_by_purchase_orders
with cte as(
select
	dp.currency_code ,
	dp.decimal_place_number as decimal_places
from
	dict_dds.currency_decimal_place_ral dp
inner join dict_dds.currency c
on
	c.currency_code = dp.currency_code
)
select 
	tech_etl.util_text_to_null_validation("BUKRS")	as unit_balance_code,
	tech_etl.util_text_to_null_validation("GJAHR")	as fiscal_year,
	tech_etl.util_text_to_null_validation("BELNR")	as accounting_document_code,
	tech_etl.util_text_to_null_validation("BUZEI")	as accounting_document_position_line_item_code,
	tech_etl.util_text_to_null_validation("POS")	as purchase_document_position_reference_line_item_code,
	tech_etl.util_text_to_null_validation("BLART")	as accounting_document_type_code,
	tech_etl.util_text_to_null_validation("EBELN")	as purchase_document_code,
	tech_etl.util_text_to_null_validation("EBELP")	as purchase_document_position_line_item_code,
	"WRBTR"::numeric(17,2)*(10 ^ (2 - coalesce(dp.decimal_places,2)))	as document_currency_amount,
	"NETWR"::numeric(17,2)*(10 ^ (2 - coalesce(dp.decimal_places,2)))	as document_currency_without_vat_amount,
	"WMWST"::numeric(17,2)* (10 ^ (2 - coalesce(dp.decimal_places,2)))	as document_currency_vat_amount,
	tech_etl.util_text_to_null_validation("WAERS")	as document_currency_code,
	tech_etl.util_text_to_null_validation("PROJK")	as wbs_element_code,
	"WRBTR_EB"::numeric(17,2)* (10 ^ (2 - coalesce(dp2.decimal_places,2)))	as specification_currency_amount,
	"WMWST_EB"::numeric(17,2)* (10 ^ (2 - coalesce(dp2.decimal_places,2)))	as specification_currency_vat_amount,
	tech_etl.util_text_to_null_validation("WAERS_EB")	as specification_currency_code
from stg."/RUSAL/TAP_MM" tm
left join cte as dp on 
	dp.currency_code = tech_etl.util_text_to_null_validation("WAERS")
left join cte as dp2 on 
 	dp2.currency_code = tech_etl.util_text_to_null_validation("WAERS_EB")
where
	1 = 1
	and "MANDT" = '400';