DROP TABLE IF EXISTS ods."/rusal/filedoc_ral";

CREATE TABLE ods."/rusal/filedoc_ral"
(
fileid varchar(32) NULL,
dlflg varchar(1) NULL,
sapid_type varchar(2) NULL,
sapid varchar(20) NULL,
doctype varchar(2) NULL,
docnum varchar(255) NULL,
docdate date NULL,
"source" varchar(2) NULL,
vagon varchar(20) NULL,
crdat date NULL,
dttm_inserted timestamp NOT NULL DEFAULT now(),
dttm_updated timestamp NOT NULL DEFAULT now(),
job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
deleted_flag bool NOT NULL DEFAULT false
)
WITH (
appendonly=true,
orientation=column,
compresstype=zstd,
compresslevel=3
)
distributed by (fileid);

comment on table ods."/rusal/filedoc_ral" is 'Файлы образов документов';
comment on column ods."/rusal/filedoc_ral".fileid is 'Идентификатор файла в Алмер | Идентификатор файла в Алмер | /RUSAL/FILEDOC.FILEID';
comment on column ods."/rusal/filedoc_ral".dlflg is 'Флаг удаления | Флаг удаления | /RUSAL/FILEDOC.DLFLG';
comment on column ods."/rusal/filedoc_ral".sapid_type is 'Тип к SAPID в FILEDOC | Тип к SAPID в FILEDOC | /RUSAL/FILEDOC.SAPID_TYPE';
comment on column ods."/rusal/filedoc_ral".sapid is 'Ключ объекта в SAP | Ключ объекта в SAP | /RUSAL/FILEDOC.SAPID';
comment on column ods."/rusal/filedoc_ral".doctype is 'Вид первичного документа | Вид первичного документа | /RUSAL/FILEDOC.DOCTYPE';
comment on column ods."/rusal/filedoc_ral".docnum is 'Номер первичного документа | Номер первичного документа | /RUSAL/FILEDOC.DOCNUM';
comment on column ods."/rusal/filedoc_ral"."source" is 'Хранилище документов/файлов | Хранилище документов/файлов | /RUSAL/FILEDOC.SOURCE';
comment on column ods."/rusal/filedoc_ral".vagon is 'Номер вагона | Номер вагона | /RUSAL/FILEDOC.VAGON';
comment on column ods."/rusal/filedoc_ral".crdat is 'Дата создания записи | Дата создания записи | /RUSAL/FILEDOC.CRDAT';
