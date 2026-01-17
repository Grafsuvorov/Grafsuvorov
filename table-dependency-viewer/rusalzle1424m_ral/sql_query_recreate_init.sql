drop table if exists ods."/rusal/zle1424m_ral";

create table ods."/rusal/zle1424m_ral" (
	vbeln varchar(10) null,
	scheme varchar(7) null,
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
distributed by (vbeln);

comment on table ods."/rusal/zle1424m_ral" is 'LE: Связь поставки и договоров ДТиЛ';
comment on column ods."/rusal/zle1424m_ral".vbeln is 'Поставка | Поставка | stg./RUSAL/ZLE1424M.VBELN';
comment on column ods."/rusal/zle1424m_ral".scheme is 'Схема перевозки | Схема перевозки | stg./RUSAL/ZLE1424M.SCHEME';
