DROP TABLE if exists ods.vbpa_ral;

CREATE TABLE ods.vbpa_ral (
	kunnr varchar(10) NULL,		-- Номер дебитора
	parvw varchar(2) NULL,		-- Роль партнера
	pernr varchar(8) NULL,		-- Табельный номер
	posnr varchar(9) NULL,		-- Номер позиции документа сбыта
	vbeln varchar(10) NULL,		-- Номер документа сбыта
	lifnr varchar(10) NULL,		-- Номер счета поставщика или кредитора
	land1 varchar(3) NULL,		-- Страна партнёра (код)
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT FALSE
)
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED by (vbeln, posnr, parvw);

COMMENT ON TABLE ods.vbpa_ral IS 'Документ сбыта: партнер';
COMMENT ON COLUMN ods.vbpa_ral.kunnr IS 'Номер дебитора | Номер дебитора | stg."VBPA"."KUNNR"';
COMMENT ON COLUMN ods.vbpa_ral.parvw IS 'Роль партнера | Роль партнера | stg."VBPA"."PARVW"';
COMMENT ON COLUMN ods.vbpa_ral.pernr IS 'Табельный номер | Табельный номер | stg."VBPA"."PERNR"';
COMMENT ON COLUMN ods.vbpa_ral.posnr IS 'Номер позиции документа сбыта | Номер позиции документа сбыта | stg."VBPA"."POSNR"';
COMMENT ON COLUMN ods.vbpa_ral.vbeln IS 'Номер документа сбыта | Номер документа сбыта | stg."VBPA".VBELN';
COMMENT ON COLUMN ods.vbpa_ral.lifnr IS 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | stg."VBPA"."LIFNR"';
COMMENT ON COLUMN ods.vbpa_ral.land1 IS 'Страна партнёра (код) | Код страны партнёра | stg."VBPA"."LAND1"';

