DROP TABLE IF EXISTS ods."auas_ral" cascade;
CREATE TABLE ods."auas_ral"
(
	"belnr" varchar(10) NULL,
	"lfdnr" varchar(10) NULL,
	"wtgbtr" numeric(15,2) NULL,
	"twaer" varchar(5) NULL,
	"wkgbtr" numeric(15,2) NULL,
	"key01" varchar(120) NULL,
	"plfnr" varchar(6) NULL,
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
distributed by ("belnr", "lfdnr", "plfnr");


comment on table ods."auas_ral" is 'Документ расчета заказов: сегмент итоговых записей';
comment on column ods."auas_ral"."belnr" is 'Номер документа расчета | Номер документа расчета | AUAS.BELNR';
comment on column ods."auas_ral"."lfdnr" is 'Текущий номер | Текущий номер | AUAS.LFDNR';
comment on column ods."auas_ral"."wtgbtr" is 'Общее значение в валюте транзакции | Общее значение в валюте транзакции | AUAS.WTGBTR';
comment on column ods."auas_ral"."twaer" is 'Валюта транзакции | Валюта транзакции | AUAS.TWAER';
comment on column ods."auas_ral"."wkgbtr" is 'Общая сумма в валюте КЕ | Общая сумма в валюте КЕ | AUAS.WKGBTR';
comment on column ods."auas_ral"."key01" is 'Контроллинговая единица | Контроллинговая единица | AUAS.KEY01';
comment on column ods."auas_ral"."plfnr" is 'Порядковый номер | Порядковый номер | AUAS.PLFNR';