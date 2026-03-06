DROP TABLE IF EXISTS ods.ausp_ral;

CREATE TABLE ods.ausp_ral
(
"atinn" varchar(10) NULL,
"atzhl" varchar(8) NULL,
"klart" varchar(3) NULL,
"mafid" varchar(1) NULL,
"atflv" float8 NULL,
"atwrt" varchar(30) NULL,
"objek" varchar(50) NULL,
"dttm_inserted" timestamp NOT NULL DEFAULT now(),
"dttm_updated" timestamp NOT NULL DEFAULT now(),
"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
"deleted_flag" bool NOT NULL DEFAULT false
)

WITH (
appendonly=true,
orientation=column,
compresstype=zstd,
compresslevel=1
)
distributed by ("atinn", "atzhl", "klart", "mafid");


comment on table ods.ausp_ral is 'Характеристики признаков';
comment on column ods.ausp_ral."atzhl" is 'Счетчик характеристик признака | Счетчик характеристик признака | AUSP.ATZHL';
comment on column ods.ausp_ral."atinn" is 'Внутренний признак | Внутренний признак | AUSP.ATINN';
comment on column ods.ausp_ral."klart" is 'Вид класса | Вид класса | AUSP.KLART';
comment on column ods.ausp_ral."atflv" is 'С внутр. значения с плав. запятой | С внутр. значения с плав. запятой | AUSP.ATFLV';
comment on column ods.ausp_ral."objek" is 'Ключ классифицируемого объекта | Ключ классифицируемого объекта | AUSP.OBJEK';
comment on column ods.ausp_ral."mafid" is 'Индикатор: объект/класс | Индикатор: объект/класс | AUSP.MAFID';
comment on column ods.ausp_ral."atwrt" is 'Значение признака | Значение признака | AUSP.ATWRT';