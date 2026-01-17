drop table if exists ods."/rusal/otmm_rv_ral";

create table ods."/rusal/otmm_rv_ral" (
	matnr varchar(18) null,
	werks varchar(4) null,
	popers varchar(6) null,
	poperpo varchar(6) null,
	id_ves varchar(3) null,
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
distributed by (matnr, werks, popers, poperpo, id_ves);

comment on table ods."/rusal/otmm_rv_ral" is 'Разделительная ведомость поставок сырья для обеспечения производства';
comment on column ods."/rusal/otmm_rv_ral".matnr is 'Материал (код) | Материал (код) | stg./RUSAL/OTMM_RV.MATNR';
comment on column ods."/rusal/otmm_rv_ral".werks is 'Завод (код) | Завод (код) | stg./RUSAL/OTMM_RV.WERKS';
comment on column ods."/rusal/otmm_rv_ral".popers is 'Период закупки с | МПериод закупки с | stg./RUSAL/OTMM_RV.POPERS';
comment on column ods."/rusal/otmm_rv_ral".poperpo is 'Период закупки по | Период закупки по | stg./RUSAL/OTMM_RV.POPERPO';
comment on column ods."/rusal/otmm_rv_ral".id_ves is 'Способ учета веса (код) | Способ учета веса (код) | stg./RUSAL/OTMM_RV.ID_VES';