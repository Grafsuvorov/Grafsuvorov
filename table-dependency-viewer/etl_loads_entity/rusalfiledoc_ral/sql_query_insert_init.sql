insert into ods."/rusal/filedoc_ral" (
fileid, 
dlflg, 
sapid_type, 
sapid, 
doctype, 
docnum, 
docdate,
"source",
vagon,
crdat
)
select tech_etl.util_text_to_null_validation("FILEID") as fileid,
tech_etl.util_text_to_null_validation("DLFLG") as dlflg,
tech_etl.util_text_to_null_validation("SAPID_TYPE") as sapid_type,
tech_etl.util_text_to_null_validation("SAPID") as sapid,
tech_etl.util_text_to_null_validation("DOCTYPE") as doctype,
tech_etl.util_text_to_null_validation("DOCNUM") as docnum,
tech_etl.util_text_to_date_validation("DOCDATE") as docdate,
tech_etl.util_text_to_null_validation("SOURCE") as "source",
tech_etl.util_text_to_null_validation("VAGON") as vagon,
tech_etl.util_text_to_date_validation("CRDAT") as crdat
from stg."/RUSAL/FILEDOC";
