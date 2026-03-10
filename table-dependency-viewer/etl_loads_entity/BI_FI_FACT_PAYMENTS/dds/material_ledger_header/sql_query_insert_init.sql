insert into dds.material_ledger_header
select
	c."KALNR" as calculation_code ,
	tech_etl.util_text_to_null_validation(c."MLAST") as price_rule_code,
	tech_etl.util_text_to_timestamp_validation( c."ABRECHDAT", c."ABRECHUHR" ) as dt_last_price_determination,
	tech_etl.util_text_to_null_validation(c."MATNR") as material_code,
	tech_etl.util_text_to_null_validation(c."BWKEY") as valuation_area_code,
	tech_etl.util_text_to_null_validation(c."BWTAR") as valuation_type_code,
	tech_etl.util_text_to_null_validation(c."KZBWS") as special_stock_valuation_code,
	tech_etl.util_text_to_null_validation(c."XOBEW") as is_tolling_stock_valuated,
	tech_etl.util_text_to_null_validation(c."SOBKZ") as special_stock_code,
	tech_etl.util_text_to_null_validation(c."VBELN") as sales_document_code,
	tech_etl.util_text_to_null_validation(c."POSNR") as sales_document_position_code,
	tech_etl.util_text_to_null_validation(c."PSPNR") as wbs_element_code,
	tech_etl.util_text_to_null_validation(c."LIFNR") as supplier_code
from stg."CKMLHD" c
where 1=1
	and c."MANDT" = '400';
