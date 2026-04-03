insert into ods.ztle_contcn_ral
(
	container,
	dt_inport,
	dt_outport,
	dt_outrcvr,
	dt_in_stock,
	stock_text,
	stock_knote,
	dt_out_stock,
	dt_load_stock
)
select
	tech_etl.util_text_to_null_validation("CONTAINER") as container,	
	tech_etl.util_text_to_date_validation("DT_INPORT") as dt_inport,
	tech_etl.util_text_to_date_validation("DT_OUTPORT") as dt_outport,
	tech_etl.util_text_to_date_validation("DT_OUTRCVR") as dt_outrcvr,
	tech_etl.util_text_to_date_validation("DT_IN_STOCK") as dt_in_stock,
	tech_etl.util_text_to_null_validation("STOCK_TEXT") as stock_text,
	tech_etl.util_text_to_null_validation("STOCK_KNOTE") as stock_knote,
	tech_etl.util_text_to_date_validation("DT_OUT_STOCK") as dt_out_stock,
	tech_etl.util_text_to_date_validation("DT_LOAD_STOCK") as dt_load_stock
from stg."ZTLE_CONTCN";
