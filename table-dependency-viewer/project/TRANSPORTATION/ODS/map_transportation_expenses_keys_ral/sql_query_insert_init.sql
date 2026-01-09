insert into ods.map_transportation_expenses_keys_ral
select 
	"EXPENSE" as expense_code,
	"PERIOD_" as dt_expense_period_yyyymm,
	"VBELN" as delivery_code,
	tech_etl.util_text_to_null_validation("ZSRVPOS") as service_code,
	tech_etl.util_text_to_null_validation("VBELN_LF") as delivery_at_plant_code,
	tech_etl.util_text_to_null_validation("LINE_ITEM") as expense_position_code,
	tech_etl.util_text_to_null_validation("SDABW") as transport_type_at_plant_code,
	"KWERT" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as expense_amount,								---преобразовываем сумму по формуле
	tech_etl.util_text_to_null_validation("WAERS") as expense_currency_code
from stg."ZLE_1431M_FRAHT" as z1431
	left join dict_dds.currency_decimal_place_ral as dp						 									---джойн с TCURX RAL
		on dp.currency_code = z1431."WAERS"
where 1=1
and "PERIOD_" >= '202401'  -- Инкремент обновления, по дате. После инициирующей, обновлять на согласованную глубину
;