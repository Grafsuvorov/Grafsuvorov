DROP TABLE IF EXISTS ods.cdhdr_ral;

CREATE TABLE ods.cdhdr_ral
(
"changenr" varchar(10) NULL,
"username" varchar(12) NULL,
"objectclas" varchar(15) NULL,
"objectid" varchar(90) NULL,
"udate" date NULL,
"utime" time NULL,
"tcode" varchar(20) NULL,
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
distributed by ("changenr", "objectclas", "objectid");


comment on table ods.cdhdr_ral is 'Заголовок документа изменений';
comment on column ods.cdhdr_ral."changenr" is 'Номер изменения документа | Номер изменения документа | CDHDR.CHANGENR';
comment on column ods.cdhdr_ral."username" is 'Имя автора изменения в документе изменений | Имя автора изменения в документе изменений | CDHDR.USERNAME';
comment on column ods.cdhdr_ral."udate" is 'Дата создания документа изменений | Дата создания документа изменений | CDHDR.UDATE';
comment on column ods.cdhdr_ral."objectid" is 'Значение объекта | Значение объекта | CDHDR.OBJECTID';
comment on column ods.cdhdr_ral."objectclas" is 'Класс объектов | Класс объектов | CDHDR.OBJECTCLAS';
comment on column ods.cdhdr_ral."utime" is 'Время изменения | Время изменения | CDHDR.UTIME';
comment on column ods.cdhdr_ral."tcode" is 'Транзакция, в которой было проведено изменение | Транзакция, в которой было проведено изменение | CDHDR.TCODE';