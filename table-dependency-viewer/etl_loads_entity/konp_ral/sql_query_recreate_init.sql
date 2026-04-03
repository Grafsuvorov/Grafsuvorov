drop table if exists ods.konp_ral;

create table ods.konp_ral
(
	"knumh" varchar(10) null,
	"kopos" varchar(2) null,
	"kappl" varchar(2) null,
	"kschl" varchar(4) null,
	"kbetr" numeric(11, 2) null,
	"konwa" varchar(5) null,
	"loevm_ko" varchar(1) null,
	"kmein" varchar(3) null,
	"kzbzg" varchar(1) null,
	"konws" varchar(5) null,
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by ("knumh");

comment on table ods.konp_ral is 'Условия (позиция)';
comment on column ods.konp_ral."knumh" is 'Номер записи условия | Номер записи условия | KONP.KNUMH';
comment on column ods.konp_ral."kopos" is 'Порядковый номер условия | Порядковый номер условия | KONP.KOPOS';
comment on column ods.konp_ral."kappl" is 'Приложение | Приложение | KONP.KAPPL';
comment on column ods.konp_ral."kschl" is 'Вид условия | Вид условия | KONP.KSCHL';
comment on column ods.konp_ral."kbetr" is 'Сумма/процентная ставка условия при отсутствии шкалы | Сумма/процентная ставка условия при отсутствии шкалы | KONP.KBETR';
comment on column ods.konp_ral."konwa" is 'Единица условия (валюта или процентная ставка) | Единица условия (валюта или процентная ставка) | KONP.KONWA';
comment on column ods.konp_ral."loevm_ko" is 'Индикатор удаления позиции условия | Индикатор удаления позиции условия | KONP.LOEVM_KO';
comment on column ods.konp_ral."kmein" is 'Единица измерения | Единица измерения | KONP.KMEIN';
comment on column ods.konp_ral."kzbzg" is 'Ссылочная величина | Ссылочная величина | KONP.KZBZG';
comment on column ods.konp_ral."konws" is 'Код валюты шкалы условий | Код валюты шкалы условий | KONP.KONWS';
