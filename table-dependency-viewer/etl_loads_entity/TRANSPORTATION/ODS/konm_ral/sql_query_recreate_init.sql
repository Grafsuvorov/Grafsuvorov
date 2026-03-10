drop table if exists ods.konm_ral;

create table ods.konm_ral
(
	"knumh" varchar(10) not null,
	"kopos" varchar(2) not null,
	"klfn1" varchar(4) null,
	"kstbm" numeric(15, 3) null,	
	"kbetr" numeric(11, 2) null,	
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by ("knumh", "kopos");

comment on table ods.konm_ral is 'Условия (одномерная шкала цен и количеств)';
comment on column ods.konm_ral."knumh" is 'Номер записи условия | Номер записи условия | KONM.KNUMH';
comment on column ods.konm_ral."kopos" is 'Порядковый номер условия | Порядковый номер условия | KONM.KOPOS';
comment on column ods.konm_ral."klfn1" is 'Текущий номер шкалы строк | Текущий номер шкалы строк | KONM.KLFN1';
comment on column ods.konm_ral."kstbm" is 'Базисное количество шкалы для условий | Базисное количество шкалы для условий | KONM.KSTBM';
comment on column ods.konm_ral."kbetr" is 'Цена или процентная ставка условия | Цена или процентная ставка условия | KONM.KBETR';