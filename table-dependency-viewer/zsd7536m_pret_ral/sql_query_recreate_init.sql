drop table if exists ods.zsd7536m_pret_ral;

create table ods.zsd7536m_pret_ral(
    vbeln varchar(10) null,	
	sammg varchar(10) null,	
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
distributed by (vbeln, sammg);

comment on table ods.zsd7536m_pret_ral is 'Претензии по фактурам реализации';
comment on column ods.zsd7536m_pret_ral.vbeln is 'Фактура реализации | Фактура реализации| zsd7536m_pret.SAMMG';
comment on column ods.zsd7536m_pret_ral.sammg is 'Претензия выставленная по фактуре реализации | Претензия выставленная по фактуре реализации| zsd7536m_pret.VBELN';
