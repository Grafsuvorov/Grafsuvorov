DROP TABLE IF EXISTS ods."dms_phio2file_ral";

CREATE TABLE ods."dms_phio2file_ral"
(
"file_id" varchar(32) NULL,
"filename" varchar(255) NULL,
"dttm_inserted" timestamp NOT NULL DEFAULT now(),
"dttm_updated" timestamp NOT NULL DEFAULT now(),
"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
appendonly=true,
orientation=column,
compresstype=zstd,
compresslevel=3
)
distributed by ("file_id");


comment on table ods."dms_phio2file_ral" is 'СУпД: имена файлов для физических инфо-объектов';
comment on column ods."dms_phio2file_ral"."file_id" is 'СУпД: GUID для присвоения "физ. объект - имя файла" | СУпД: GUID для присвоения "физ. объект - имя файла" | DMS_PHIO2FILE.FILE_ID';
comment on column ods."dms_phio2file_ral"."filename" is 'Оригинал документа | Оригинал документа | DMS_PHIO2FILE.FILENAME';
