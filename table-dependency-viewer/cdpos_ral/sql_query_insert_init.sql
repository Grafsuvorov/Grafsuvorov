insert into ods.cdpos_ral 
(changenr,fname,objectclas,objectid,tabname,
value_new,tabkey,value_old )
select tech_etl.util_text_to_null_validation("CHANGENR") as changenr,
tech_etl.util_text_to_null_validation("FNAME") as fname,
tech_etl.util_text_to_null_validation("OBJECTCLAS") as objectclas,
tech_etl.util_text_to_null_validation("OBJECTID") as objectid,
tech_etl.util_text_to_null_validation("TABNAME") as tabname,
tech_etl.util_text_to_null_validation("VALUE_NEW") as value_new,
tech_etl.util_text_to_null_validation("TABKEY") as tabkey,
tech_etl.util_text_to_null_validation("VALUE_OLD") as value_old
from stg."CDPOS"
where "MANDANT" = '400';