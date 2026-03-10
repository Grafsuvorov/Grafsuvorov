drop table if exists ods."/rusal/mirp_ral";

create table ods."/rusal/mirp_ral" (
	awtyp varchar(5) null,
	awkey varchar(20) null,
	zbukrs varchar(4) null,
	zbelnr varchar(10) null,
	zgjahr varchar(4) null,
	zblart varchar(2) null,
	zstblg varchar(10) null,
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
distributed by (awtyp, awkey, zbukrs, zbelnr, zgjahr);

comment on table ods."/rusal/mirp_ral" is 'Зеркальные проводки (данные документов)';
comment on column ods."/rusal/mirp_ral".awtyp is 'Ссылочная операция | Ссылочная операция | STG./RUSAL/MIRP.AWTYP';
comment on column ods."/rusal/mirp_ral".awkey is 'Ссылочный ключ | Ссылочный ключ | STG./RUSAL/MIRP.AWKEY';
comment on column ods."/rusal/mirp_ral".zbukrs is 'Балансовая единица | Балансовая единица | STG./RUSAL/MIRP.ZBUKRS';
comment on column ods."/rusal/mirp_ral".zbelnr is 'Номер бухгалтерского документа | Номер бухгалтерского документа | STG./RUSAL/MIRP.ZBELNR';
comment on column ods."/rusal/mirp_ral".zgjahr is 'Финансовый год | Финансовый год | STG./RUSAL/MIRP.ZGJAHR';
comment on column ods."/rusal/mirp_ral".zblart is 'Вид документа | Вид документа | STG./RUSAL/MIRP.ZBELNR';
comment on column ods."/rusal/mirp_ral".zstblg is 'Номер документа сторно | Номер документа сторно | STG./RUSAL/MIRP.ZSTBLG';
