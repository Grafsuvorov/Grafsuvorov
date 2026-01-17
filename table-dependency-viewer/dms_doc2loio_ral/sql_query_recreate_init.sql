
DROP TABLE IF EXISTS ods."dms_doc2loio_ral";

CREATE TABLE ods."dms_doc2loio_ral"
(
"dokar" varchar(3) NULL,
"doknr" varchar(25) NULL,
"doktl" varchar(3) NULL,
"dokvr" varchar(2) NULL,
"lo_index" int8 NULL,
"lo_type" varchar(2) NULL,
"lo_objid" varchar(32) NULL,
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
distributed by ("dokar", "doknr", "doktl", "dokvr", "lo_index", "lo_type");


comment on table ods."dms_doc2loio_ral" is 'СУпД: таблица соединений: ключ СУпД <-> ид. логич. объекта';
comment on column ods."dms_doc2loio_ral"."dokar" is 'Вид документа | Вид документа | DMS_DOC2LOIO.DOKAR';
comment on column ods."dms_doc2loio_ral"."doknr" is 'Номер документа | Номер документа | DMS_DOC2LOIO.DOKNR';
comment on column ods."dms_doc2loio_ral"."doktl" is 'Поддокумент | Поддокумент | DMS_DOC2LOIO.DOKTL';
comment on column ods."dms_doc2loio_ral"."dokvr" is 'Версия документа | Версия документа | DMS_DOC2LOIO.DOKVR';
comment on column ods."dms_doc2loio_ral"."lo_index" is 'Счетчик для документов | Счетчик для документов | DMS_DOC2LOIO.LO_INDEX';
comment on column ods."dms_doc2loio_ral"."lo_type" is 'Тип файла оригинала | Тип файла оригинала | DMS_DOC2LOIO.LO_TYPE';
comment on column ods."dms_doc2loio_ral"."lo_objid" is 'Логический документ | Логический документ | DMS_DOC2LOIO.LO_OBJID';
