insert into ods."dms_doc2loio_ral"
select tech_etl.util_text_to_null_validation("DOKAR") as dokar,
tech_etl.util_text_to_null_validation("DOKNR") as doknr,
tech_etl.util_text_to_null_validation("DOKTL") as doktl,
tech_etl.util_text_to_null_validation("DOKVR") as dokvr,
"LO_INDEX" as lo_index,
tech_etl.util_text_to_null_validation("LO_TYPE") as lo_type,
tech_etl.util_text_to_null_validation("LO_OBJID") as lo_objid
from stg."DMS_DOC2LOIO"
where "MANDT" = '400';
