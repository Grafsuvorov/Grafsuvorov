DROP TABLE IF EXISTS ods."dms_ph_cd1_ral";

CREATE TABLE ods."dms_ph_cd1_ral"
(
"phio_id" varchar(32) NULL,
"loio_id" varchar(32) NULL,
"prop08" varchar(40) NULL,
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
distributed by ("phio_id");


comment on table ods."dms_ph_cd1_ral" is 'СУпД: ФизичИнфоОбъекты ОснОригиналов';
comment on column ods."dms_ph_cd1_ral"."phio_id" is 'Физический документ | Физический документ | DMS_PH_CD1.PHIO_ID';
comment on column ods."dms_ph_cd1_ral"."loio_id" is 'Логический документ | Логический документ | DMS_PH_CD1.LOIO_ID';
comment on column ods."dms_ph_cd1_ral"."prop08" is 'Характеристика атрибута (подробная версия) | Характеристика атрибута (подробная версия) | DMS_PH_CD1.PROP08';
