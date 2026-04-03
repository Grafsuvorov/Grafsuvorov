DROP TABLE IF EXISTS ods."auak_ral" cascade;
CREATE TABLE ods."auak_ral"
(
	"belnr" varchar(10) NULL,
	"perbz" varchar(3) NULL,
	"objnr" varchar(22) NULL,
	"gjahr" varchar(4) NULL,
	"kokrs" varchar(4) NULL,
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
distributed by ("belnr", "kokrs");


comment on table ods."auak_ral" is 'Заголовок документа для расчета заказов';
comment on column ods."auak_ral"."belnr" is 'Номер документа расчета | Номер документа расчета | AUAK.BELNR';
comment on column ods."auak_ral"."perbz" is 'Вид расчета | Вид расчета | AUAK.PERBZ';
comment on column ods."auak_ral"."objnr" is 'Номер объекта на уровне позиции | Номер объекта на уровне позиции | AUAK.OBJNR';
comment on column ods."auak_ral"."gjahr" is 'Финансовый год | Финансовый год | AUAK.GJAHR';
comment on column ods."auak_ral"."kokrs" is 'Контроллинговая единица | Контроллинговая единица | AUAK.KOKRS';