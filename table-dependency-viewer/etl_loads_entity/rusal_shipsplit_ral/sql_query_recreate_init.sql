DROP TABLE IF EXISTS ods."/rusal/shipsplit_ral" CASCADE;

CREATE TABLE ods."/rusal/shipsplit_ral" (
	werks varchar(4) NULL,				-- Завод (код)
	vbeln_src varchar(10) NULL,			-- Исходная поставка (код)
	vbeln_dst varchar(10) NULL,			-- Разделённая поставка (код)
	charg varchar(10) NULL,				-- Партия (код)
	vbeln_rfr varchar(10) NULL,			-- Ссылочная поставка (код)
	reason varchar(1) NULL,				-- Причина деления (код)
	-----------------------------------------------
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
DISTRIBUTED BY (
	werks,
	vbeln_src,
	vbeln_dst,
	charg
);


COMMENT ON TABLE ods."/rusal/shipsplit_ral" IS 'Распределённые поставки';
COMMENT ON COLUMN ods."/rusal/shipsplit_ral".werks IS 'Завод (код) | Завод (код) | stg."/RUSAL/SHIPSPLIT"."WERKS"';
COMMENT ON COLUMN ods."/rusal/shipsplit_ral".vbeln_src IS 'Исходная поставка (код) | Исходная поставка (код) | stg."/RUSAL/SHIPSPLIT"."VBELN_SRC"';
COMMENT ON COLUMN ods."/rusal/shipsplit_ral".vbeln_dst IS 'Разделённая поставка (код) | Разделённая поставка (код) | stg."/RUSAL/SHIPSPLIT"."VBELN_DST"';
COMMENT ON COLUMN ods."/rusal/shipsplit_ral".charg IS 'Партия (код) | Партия (код) | stg."/RUSAL/SHIPSPLIT"."CHARG"';
COMMENT ON COLUMN ods."/rusal/shipsplit_ral".vbeln_rfr IS 'Ссылочная поставка (код) | Ссылочная поставка (код) | stg."/RUSAL/SHIPSPLIT"."VBELN_RFR"';
COMMENT ON COLUMN ods."/rusal/shipsplit_ral".reason IS 'Причина деления (код) | Причина деления (код) | stg."/RUSAL/SHIPSPLIT"."REASON"';
