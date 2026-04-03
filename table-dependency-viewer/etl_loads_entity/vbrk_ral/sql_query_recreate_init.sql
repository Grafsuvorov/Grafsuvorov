DROP TABLE IF EXISTS ods.vbrk_ral CASCADE;

CREATE TABLE if not exists ods.vbrk_ral (
	vbeln varchar NULL,
	zzsammg varchar NULL,
	rfbsk varchar NULL,
	vbtyp varchar NULL,
	fkdat date NULL,
	kunrg varchar NULL,
	waerk varchar NULL,
	fkart varchar null,
	fksto varchar NULL,
	sfakn varchar NULL,
	dttm_inserted timestamp DEFAULT now() NOT NULL,
	dttm_updated timestamp DEFAULT now() NOT NULL,
	job_name varchar(60) DEFAULT 'airflow'::character varying NOT NULL,
	deleted_flag bool DEFAULT false NOT NULL
)
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED BY (vbeln);

COMMENT ON TABLE ods.vbrk_ral IS 'Фактура: данные заголовка';
COMMENT ON COLUMN ods.vbrk_ral.vbeln IS 'Фактура | Фактура | stg."VBRK"."VBELN"';
COMMENT ON COLUMN ods.vbrk_ral.zzsammg IS 'Группа | Группа | stg."VBRK"."ZZSAMMG"';
COMMENT ON COLUMN ods.vbrk_ral.rfbsk IS 'Статус передачи данных в бухгалтерию (код) | Статус передачи данных в бухгалтерию (код) | stg."VBRK"."RFBSK"';
COMMENT ON COLUMN ods.vbrk_ral.vbtyp IS 'Тип фактуры реализации (код) | Тип фактуры реализации (код) | stg."VBRK"."VBTYP"';
COMMENT ON COLUMN ods.vbrk_ral.fkdat IS 'Дата фактуры для индекса фактур и печати | Дата фактуры для индекса фактур и печати | stg."VBRK"."FKDAT"';
COMMENT ON COLUMN ods.vbrk_ral.kunrg IS 'Плательщик | Плательщик | stg."VBRK"."KUNRG"';
COMMENT ON COLUMN ods.vbrk_ral.waerk IS 'Валюта документа сбыта (код) | - | stg."VBRK"."WAERK"';
COMMENT ON COLUMN ods.vbrk_ral.fkart IS 'Вид фактуры | Вид фактуры | stg."VBRK"."FKART"';
COMMENT ON COLUMN ods.vbrk_ral.fksto IS 'Фактура сторнирована | Фактура сторнирована | stg."VBRK"."FKSTO"';
COMMENT ON COLUMN ods.vbrk_ral.sfakn IS 'Номер сторнированной фактуры | Номер сторнированной фактуры | stg."VBRK"."SFAKN"';