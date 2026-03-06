drop table if exists ods."zle2464m_bp_rawp_ral";

create table ods."zle2464m_bp_rawp_ral" (
	gjahr varchar(4) null,
	matnr varchar(18) null,
	"version" varchar(3) null,
	posnr varchar(6) null,
	etsng varchar(6) null,
	scheme varchar(7) null,
	sdabw varchar(4) null,
	knanf varchar(10) null,
	knend varchar(10) null,
	menge numeric(13, 3) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false 
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (gjahr, matnr, "version", posnr);

comment on table ods."zle2464m_bp_rawp_ral" is 'Бизнес-план по транспортировке Корзины сырья: Позиция';
comment on column ods."zle2464m_bp_rawp_ral".gjahr is 'Год бинес-плана | Год бинес-плана | stg.ZLE2464M_BP_RAWP.GJAHR';
comment on column ods."zle2464m_bp_rawp_ral".matnr is 'Материал (код) | Материал (код) | stg.ZLE2464M_BP_RAWP.MATNR';
comment on column ods."zle2464m_bp_rawp_ral"."version" is 'Версия (код) | Версия (код) | stg.ZLE2464M_BP_RAWP.VERSION';
comment on column ods."zle2464m_bp_rawp_ral".posnr is 'Позиция бизнес-плана (код) | Позиция бизнес-плана (код) | stg.ZLE2464M_BP_RAWP.POSNR';
comment on column ods."zle2464m_bp_rawp_ral".etsng is 'ЕТСНГ исходный (код) | ЕТСНГ исходный (код) | stg.ZLE2464M_BP_RAWP.ETSNG';
comment on column ods."zle2464m_bp_rawp_ral".scheme is 'Схема перевозки (код) | Схема перевозки (код) | stg.ZLE2464M_BP_RAWP.SCHEME';
comment on column ods."zle2464m_bp_rawp_ral".sdabw is 'Тип транспортного средства (код) | Тип транспортного средства (код) | stg.ZLE2464M_BP_RAWP.SDABW';
comment on column ods."zle2464m_bp_rawp_ral".knanf is 'Транспортный узел места отправления (код) | Транспортный узел места отправления (код) | stg.ZLE2464M_BP_RAWP.KNANF';
comment on column ods."zle2464m_bp_rawp_ral".knend is 'Транспортный узел места назначения (код) | Транспортный узел места назначения (код) | stg.ZLE2464M_BP_RAWP.KNEND';
comment on column ods."zle2464m_bp_rawp_ral".menge is 'Количество транспортных средств | Количество транспортных средств | stg.ZLE2464M_BP_RAWP.MENGE';
