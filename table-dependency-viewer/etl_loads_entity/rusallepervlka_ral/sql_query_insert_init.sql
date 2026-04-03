insert into ods."/rusal/lepervlka_ral"
(id, pos, type_load, numvag, numnakl, weightnet, regdate, senddate, cartare, type_vagon, zterminal, genaktdate, arrvesdate, delivery_in, 
knote, knote1, knote2, werks_from, werks_to, matnr, vehicle, conosnum, dock_knote, erdat, erzet, ernam, aedat, aezet, aenam, type_prod,
bldat)

select
	"ID" as "id",
	"POS" as "pos",
	"TYPE_LOAD" as "type_load",
	"NUMVAG" as "numvag",
	"NUMNAKL" as "numnakl",
	"WEIGHTNET" as "weightnet",
	tech_etl.util_text_to_date_validation("REGDATE") as "regdate",
	tech_etl.util_text_to_date_validation("SENDDATE") as "senddate",
	tech_etl.util_text_to_null_validation("CARTARE") as "cartare",
	tech_etl.util_text_to_null_validation("TYPE_VAGON") as "type_vagon",
	tech_etl.util_text_to_null_validation("ZTERMINAL") as "zterminal",
	tech_etl.util_text_to_date_validation("GENAKTDATE") as "genaktdate",
	tech_etl.util_text_to_date_validation("ARRVESDATE") as "arrvesdate",
	tech_etl.util_text_to_null_validation("DELIVERY_IN") as "delivery_in",
	tech_etl.util_text_to_null_validation("KNOTE") as "knote",
	tech_etl.util_text_to_null_validation("KNOTE1") as "knote1",
	tech_etl.util_text_to_null_validation("KNOTE2") as "knote2",
	tech_etl.util_text_to_null_validation("WERKS_FROM") as "werks_from",
	tech_etl.util_text_to_null_validation("WERKS_TO") as "werks_to",
	tech_etl.util_text_to_null_validation("MATNR") as "matnr",
	tech_etl.util_text_to_null_validation("VEHICLE") as "vehicle",
	tech_etl.util_text_to_null_validation("CONOSNUM") as "conosnum",
	tech_etl.util_text_to_null_validation("DOCK_KNOTE") as "dock_knote",
	tech_etl.util_text_to_date_validation("ERDAT") as "erdat",
	tech_etl.util_text_to_time_validation("ERZET") as "erzet",
	tech_etl.util_text_to_null_validation("ERNAM") as "ernam",
	tech_etl.util_text_to_date_validation("AEDAT") as "aedat",
	tech_etl.util_text_to_time_validation("AEZET") as "aezet",
	tech_etl.util_text_to_null_validation("AENAM") as "aenam",
	tech_etl.util_text_to_null_validation("TYPE_PROD") as "type_prod",
	tech_etl.util_text_to_date_validation("BLDAT") as "bldat"
from stg."/RUSAL/LEPERVLKA"
where "MANDT" = '400';