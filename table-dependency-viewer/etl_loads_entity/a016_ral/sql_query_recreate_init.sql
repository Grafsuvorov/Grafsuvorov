drop table if exists ods.a016_ral;

create table ods.a016_ral
(
	"kappl" varchar(2) not null,
	"kschl" varchar(4) not null,
	"evrtn" varchar(10) not null,
	"evrtp" varchar(5) not null,
	"datbi" date not null,
	"datab" date not null,
	"knumh" varchar(10) not null,
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
distributed by ("kappl", "kschl", "evrtn", "evrtp");

comment on table ods.a016_ral is 'Позиция контракта';
comment on column ods.a016_ral."kappl" is 'Приложение | Приложение | A016.KAPPL';
comment on column ods.a016_ral."kschl" is 'Вид условия | Вид условия | A016.KSCHL';
comment on column ods.a016_ral."evrtn" is 'Номер документа закупки | Номер документа закупки | A016.EVRTN';
comment on column ods.a016_ral."evrtp" is 'Номер позиции документа закупки | Номер позиции документа закупки | A016.EVRTP';
comment on column ods.a016_ral."datbi" is 'Конец срока действия записи условия | Конец срока действия записи условия | A016.DATBI';
comment on column ods.a016_ral."datab" is 'Начало срока действия записи условия | Начало срока действия записи условия | A016.DATAB';
comment on column ods.a016_ral."knumh" is 'Номер записи условия | Номер записи условия | A016.KNUMH';