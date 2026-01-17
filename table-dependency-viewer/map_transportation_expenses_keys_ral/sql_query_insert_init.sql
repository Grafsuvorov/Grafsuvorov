insert into ods.map_transportation_expenses_keys_ral (expense_code,
dt_expense_period_yyyymm,
delivery_code,
service_code,
delivery_at_plant_code,
expense_position_code,
transport_type_at_plant_code,
expense_amount,
expense_currency_code,
usd_currency_code,
purchase_contract_code,
transportation_scheme_code,
expense_per_ton_amount,
expense_type_code,
expense_name
)
select 
	z1431."EXPENSE" as expense_code,
	z1431."PERIOD_" as dt_expense_period_yyyymm,
	z1431."VBELN" as delivery_code,
	tech_etl.util_text_to_null_validation(z1431."ZSRVPOS") as service_code,
	tech_etl.util_text_to_null_validation(z1431."VBELN_LF") as delivery_at_plant_code,
	tech_etl.util_text_to_null_validation(z1431."LINE_ITEM") as expense_position_code,
	tech_etl.util_text_to_null_validation(z1431."SDABW") as transport_type_at_plant_code,
	z1431."KWERT" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as expense_amount,								---преобразовываем сумму по формуле
	tech_etl.util_text_to_null_validation(z1431."WAERS") as expense_currency_code,
	tech_etl.util_text_to_null_validation(z1431."KONWA_USD") as usd_currency_code,
	tech_etl.util_text_to_null_validation(z1431."KONNR") as purchase_contract_code,
	tech_etl.util_text_to_null_validation(z1431."SCHEME") as transportation_scheme_code,
	z1431."KBETR_T_USD" as expense_per_ton_amount,
	tech_etl.util_text_to_null_validation(z1431."EXPENSE_TYPE") as expense_type_code,
	tech_etl.util_text_to_null_validation(z1431."EXPENSE_TXT") as expense_name
from stg."ZLE_1431M_FRAHT" as z1431
	left join dict_dds.currency_decimal_place_ral as dp						 									---джойн с TCURX RAL
		on dp.currency_code = z1431."WAERS"
where 1 = 1
and "PERIOD_" >= '202401'; -- Старые данные косячные и нам не нужны