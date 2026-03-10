insert into ods.zle_dog_limit_ral
select
	lim."EBELN" as ebeln,
	lim."KTWRT_BALANCE" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as ktwrt_balance,
	tech_etl.util_text_to_null_validation(lim."WAERS") as waers
from stg."ZLE_DOG_LIMIT" as lim
	left join dict_dds.currency_decimal_place_ral as dp			---джойн с TCURX RAL
		on dp.currency_code = "WAERS"
where lim."MANDT" = '400';