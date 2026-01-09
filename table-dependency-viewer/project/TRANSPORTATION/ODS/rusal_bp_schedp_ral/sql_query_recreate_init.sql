drop table if exists ods."/rusal/bp_schedp_ral";

create table ods."/rusal/bp_schedp_ral" (
	gjahr varchar(4) null,
	"version" varchar(3) null,
	oper varchar(2) null,
	posnr varchar(6) null,
	werks varchar(4) null,
	pickup varchar(1) null,
	sdabw varchar(4) null,
	werks_kn varchar(10) null,
	port_from varchar(10) null,
	port_frkn varchar(10) null,
	zpr_cont varchar(2) null,
	zpr_pl varchar(2) null,
	prdouble varchar(1) null,
	zlencont varchar(1) null,
	menge_sum numeric(13,0) null,
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
distributed by (gjahr, "version", oper, posnr);

comment on table ods."/rusal/bp_schedp_ral" is 'Бизнес-план по транспортировке Готовой продукции: Позиция';
comment on column ods."/rusal/bp_schedp_ral".gjahr is 'Год бизнес-плана | Год бизнес-плана | stg./RUSAL/OTMM_RV.GJAHR';
comment on column ods."/rusal/bp_schedp_ral"."version" is 'Версия (код) | Версия (код) | stg./RUSAL/OTMM_RV.VERSION';
comment on column ods."/rusal/bp_schedp_ral".oper is 'Тип бизнес-плана (по этапу транспортировки) (код) | Тип бизнес-плана (по этапу транспортировки) (код) | stg./RUSAL/OTMM_RV.OPER';
comment on column ods."/rusal/bp_schedp_ral".posnr is 'Позиция бизнес-плана (код) | Позиция бизнес-плана (код) | stg./RUSAL/OTMM_RV.POSNR';
comment on column ods."/rusal/bp_schedp_ral".werks is 'Завод (код) | Завод (код) | stg./RUSAL/OTMM_RV.WERKS';
comment on column ods."/rusal/bp_schedp_ral".pickup is 'Идентификатор: самовывоз (код) | Идентификатор: самовывоз (код) | stg./RUSAL/OTMM_RV.PICKUP';
comment on column ods."/rusal/bp_schedp_ral".sdabw is 'Тип транспортного средства (код) | ГТип транспортного средства (код) | stg./RUSAL/OTMM_RV.SDABW';
comment on column ods."/rusal/bp_schedp_ral".werks_kn is 'Cтанция завода (код) | Cтанция завода (код) | stg./RUSAL/OTMM_RV.WERKS_KN';
comment on column ods."/rusal/bp_schedp_ral".port_from is 'Порт РФ (код) | Порт РФ (код) | stg./RUSAL/OTMM_RV.PORT_FROM';
comment on column ods."/rusal/bp_schedp_ral".port_frkn is 'Cтанция порта РФ (код) | Cтанция порта РФ (код) | stg./RUSAL/OTMM_RV.PORT_FRKN';
comment on column ods."/rusal/bp_schedp_ral".zpr_cont is 'Принадлежность контейнера (код) | Принадлежность контейнера (код) | stg./RUSAL/OTMM_RV.ZPR_CONT';
comment on column ods."/rusal/bp_schedp_ral".zpr_pl is 'Причина перетарки (код) | Причина перетарки (код) | stg./RUSAL/OTMM_RV.ZPR_PL';
comment on column ods."/rusal/bp_schedp_ral".prdouble is 'Футовость контейнера (код) | Футовость контейнера (код) | stg./RUSAL/OTMM_RV.PRDOUBLE';
comment on column ods."/rusal/bp_schedp_ral".zlencont is 'Принадлежность платформы (код) | Принадлежность платформы (код) | stg./RUSAL/OTMM_RV.ZLENCONT';
comment on column ods."/rusal/bp_schedp_ral".menge_sum is 'Количество транспортных средств | Количество транспортных средств | stg./RUSAL/OTMM_RV.MENGE_SUM';