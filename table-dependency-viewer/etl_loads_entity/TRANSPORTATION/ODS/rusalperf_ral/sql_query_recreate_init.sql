drop table if exists ods."/rusal/perf_ral";

create table ods."/rusal/perf_ral" (
	werks varchar(4) null,
	id varchar(10) null,
	pos varchar(5) null,
	bukrs varchar(4) null,
	belnr varchar(10) null,
	gjahr varchar(4) null,
	vbeln varchar(10) null,
	posnr varchar(6) null,
	type varchar(1) null,
	cpudt date null,
	cputm time null,
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
distributed by (werks, id, pos, bukrs, belnr, gjahr, vbeln, posnr, type);

comment on table ods."/rusal/perf_ral" is 'История счетов-фактур по позициям документов на оплату';
comment on column ods."/rusal/perf_ral".werks is 'Завод | Завод | STG./RUSAL/PERF.WERKS';
comment on column ods."/rusal/perf_ral".id is 'ID документа | ID документа | STG./RUSAL/PERF.ID';
comment on column ods."/rusal/perf_ral".pos is 'Позиция документа | Позиция документа | STG./RUSAL/PERF.POS';
comment on column ods."/rusal/perf_ral".bukrs is 'Балансовая единица | Балансовая единица | STG./RUSAL/PERF.BUKRS';
comment on column ods."/rusal/perf_ral".belnr is 'Номер бухгалтерского документа | Номер бухгалтерского документа | STG./RUSAL/PERF.BELNR';
comment on column ods."/rusal/perf_ral".gjahr is 'Финансовый год | Финансовый год | STG./RUSAL/PERF.GJAHR';
comment on column ods."/rusal/perf_ral".vbeln is 'Торговый документ | Торговый документ | STG./RUSAL/PERF.VBELN';
comment on column ods."/rusal/perf_ral".posnr is 'Позиция торгового документа | Позиция торгового документа | STG./RUSAL/PERF.POSNR';
comment on column ods."/rusal/perf_ral".type is 'Тип документа | Тип документа | STG./RUSAL/PERF.TYPE';
comment on column ods."/rusal/perf_ral".cpudt is 'Дата ввода бухгалтерского документа | Дата ввода бухгалтерского документа | STG./RUSAL/PERF.CPUDT';
comment on column ods."/rusal/perf_ral".cputm is 'Время ввода | Время ввода | STG./RUSAL/PERF.CPUTM';
