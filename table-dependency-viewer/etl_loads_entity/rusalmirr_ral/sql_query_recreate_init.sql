drop table if exists ods."/rusal/mirr_ral";

create table ods."/rusal/mirr_ral" (
	awtyp varchar(5) null,
	awkey varchar(20) null,
	bukrs varchar(4) null,
	belnr varchar(10) null,
	gjahr varchar(4) null,
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
distributed by (awtyp, awkey, bukrs, belnr, gjahr);

comment on table ods."/rusal/mirr_ral" is 'Зеркальные проводки';
comment on column ods."/rusal/mirr_ral".awtyp is 'Ссылочная операция | Ссылочная операция | STG./RUSAL/MIRR.AWTYP';
comment on column ods."/rusal/mirr_ral".awkey is 'Ссылочный ключ | Ссылочный ключ | STG./RUSAL/MIRR.AWKEY';
comment on column ods."/rusal/mirr_ral".bukrs is 'Балансовая единица | Балансовая единица | STG./RUSAL/MIRR.BUKRS';
comment on column ods."/rusal/mirr_ral".belnr is 'Номер бухгалтерского документа | Номер бухгалтерского документа | STG./RUSAL/MIRR.BELNR';
comment on column ods."/rusal/mirr_ral".gjahr is 'Финансовый год | Финансовый год | STG./RUSAL/MIRR.GJAHR';
