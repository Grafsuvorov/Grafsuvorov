DROP TABLE IF EXISTS ods."auaa_ral" cascade;
CREATE TABLE ods."auaa_ral"
(
	"belnr" varchar(10) NULL,
	"lfdnr" varchar(6) NULL,
	"emtyp" varchar(2) NULL,
	"bukrs" varchar(4) NULL,
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
distributed by ("belnr", "lfdnr", "bukrs");


comment on table ods."auaa_ral" is 'Документ расчета заказов: получатель-сегмент';
comment on column ods."auaa_ral"."belnr" is 'Номер документа расчета | Номер документа расчета | AUAA.BELNR';
comment on column ods."auaa_ral"."lfdnr" is 'Порядковый номер | Порядковый номер | AUAA.LFDNR';
comment on column ods."auaa_ral"."emtyp" is 'Тип контировки | Тип контировки | AUAA.EMTYP';
comment on column ods."auaa_ral"."bukrs" is 'Балансовая единица (код) | Балансовая единица (код) | AUAK.BUKRS';