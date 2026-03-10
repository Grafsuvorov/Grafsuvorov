insert into ods.konp_ral (knumh, kopos, kappl, kschl, kbetr, konwa, loevm_ko, kmein, kzbzg, konws)
select
	tech_etl.util_text_to_null_validation("KNUMH") as knumh,
	tech_etl.util_text_to_null_validation("KOPOS") as kopos,
	tech_etl.util_text_to_null_validation("KAPPL") as kappl,
	tech_etl.util_text_to_null_validation("KSCHL") as kschl,
	"KBETR" * (10 ^ (2 - coalesce(dp.decimal_place_number, 2))) as kbetr,								---преобразовываем сумму по формуле
	tech_etl.util_text_to_null_validation("KONWA") as konwa,	
	tech_etl.util_text_to_null_validation("LOEVM_KO") as loevm_ko,
	tech_etl.util_text_to_null_validation("KMEIN") as kmein,
	tech_etl.util_text_to_null_validation("KZBZG") as kzbzg,
	tech_etl.util_text_to_null_validation("KONWS") as konws
from stg."KONP" as konp
	left join dict_dds.currency_decimal_place_ral as dp						 							---джойн с TCURX RAL
		on dp.currency_code = konp."KONWA"
where "MANDT" = '400';
