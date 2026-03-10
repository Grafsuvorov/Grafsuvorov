drop table if exists ods."/rul/rw_head_ral";

create table ods."/rul/rw_head_ral"(
	"matnr" varchar(19) null,	
	"charg" varchar(10) null,
	"werks" varchar(4) null,
	"n_netto_n" numeric(13, 3) null,
	"n_netto_v" numeric(13, 3) null,
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
distributed by ("matnr", "charg", "werks");

comment on table ods."/rul/rw_head_ral" is 'БД транспортных средств - общие данные';
comment on column ods."/rul/rw_head_ral"."matnr" is 'Номер материала | Номер материала | /RUL/RW_HEAD.MATNR';
comment on column ods."/rul/rw_head_ral"."charg" is 'Номер партии | Номер партии | /RUL/RW_HEAD.CHARG';
comment on column ods."/rul/rw_head_ral"."werks" is 'Завод | Завод | /RUL/RW_HEAD.WERKS';
comment on column ods."/rul/rw_head_ral"."n_netto_n" is 'Количество по накладной | Количество по накладной | /RUL/RW_HEAD.N_NETTO_N';
comment on column ods."/rul/rw_head_ral"."n_netto_v" is 'Базовое количество для расчета | Базовое количество для расчета | /RUL/RW_HEAD.N_NETTO_V';
