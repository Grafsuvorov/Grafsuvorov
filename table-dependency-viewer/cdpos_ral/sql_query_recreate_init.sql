DROP TABLE IF EXISTS ods.cdpos_ral;

CREATE TABLE ods.cdpos_ral
(
"changenr" varchar(10) NULL,
"fname" varchar(30) NULL,
"objectclas" varchar(15) NULL,
"objectid" varchar(90) NULL,
"tabname" varchar(30) NULL,
"value_new" varchar(254) NULL,
"tabkey" varchar(70) NULL,
"value_old" varchar(254) NULL,
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
distributed by ("changenr", "fname", "objectclas", "objectid", "tabname");


comment on table ods.cdpos_ral is 'Позиции документа изменений';
comment on column ods.cdpos_ral."value_new" is 'Новое содерж. полей измененного поля | Новое содерж. полей измененного поля | CDPOS.VALUE_NEW';
comment on column ods.cdpos_ral."fname" is 'Имя поля | Имя поля | CDPOS.FNAME';
comment on column ods.cdpos_ral."tabname" is 'Имя таблицы | Имя таблицы | CDPOS.TABNAME';
comment on column ods.cdpos_ral."objectid" is 'Значение объекта | Значение объекта | CDPOS.OBJECTID';
comment on column ods.cdpos_ral."objectclas" is 'Класс объектов | Класс объектов | CDPOS.OBJECTCLAS';
comment on column ods.cdpos_ral."changenr" is 'Номер изменения документа | Номер изменения документа | CDPOS.CHANGENR';
comment on column ods.cdpos_ral."tabkey" is 'Ключ измененной строки таблицы | Ключ измененной строки таблицы | CDPOS.TABKEY';
comment on column ods.cdpos_ral."value_old" is 'Старое содерж. поля измененного поля | Старое содерж. поля измененного поля | CDPOS.VALUE_OLD';
