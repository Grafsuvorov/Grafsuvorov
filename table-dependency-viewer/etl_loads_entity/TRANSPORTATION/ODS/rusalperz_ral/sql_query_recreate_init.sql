drop table if exists ods."/rusal/perz_ral";

create table ods."/rusal/perz_ral" (
	werks varchar(4) null,
	id varchar(10) null,
	pos varchar(5) null,
	posv varchar(5) null,
	id_doc varchar(10) null,
	pos_doc varchar(5) null,
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
distributed by (werks, id, pos, posv, id_doc, pos_doc, bukrs, belnr, gjahr, vbeln, posnr, type);

comment on table ods."/rusal/perz_ral" is 'Документы закрытия/списания позиций вагонов';
comment on column ods."/rusal/perz_ral".werks is 'Завод | Завод | STG./RUSAL/PERZ.WERKS';
comment on column ods."/rusal/perz_ral".id is 'ID документа | ID документа | STG./RUSAL/PERZ.ID';
comment on column ods."/rusal/perz_ral".pos is 'Позиция документа | Позиция документа | STG./RUSAL/PERZ.POS';
comment on column ods."/rusal/perz_ral".posv is 'Позиция вагона | Позиция вагона | STG./RUSAL/PERZ.POSV';
comment on column ods."/rusal/perz_ral".id_doc is 'ID первичного ж/д документа | ID первичного ж/д документа | STG./RUSAL/PERZ.ID_DOC';
comment on column ods."/rusal/perz_ral".pos_doc is 'Позиция первичного ж/д документа | Позиция первичного ж/д документа | STG./RUSAL/PERZ.POS_DOC';
comment on column ods."/rusal/perz_ral".bukrs is 'Балансовая единица | Балансовая единица | STG./RUSAL/PERZ.BUKRS';
comment on column ods."/rusal/perz_ral".belnr is 'Номер бухгалтерского документа | Номер бухгалтерского документа | STG./RUSAL/PERZ.BELNR';
comment on column ods."/rusal/perz_ral".gjahr is 'Финансовый год | Финансовый год | STG./RUSAL/PERZ.GJAHR';
comment on column ods."/rusal/perz_ral".vbeln is 'Торговый документ | Торговый документ | STG./RUSAL/PERZ.VBELN';
comment on column ods."/rusal/perz_ral".posnr is 'Позиция торгового документа | Позиция торгового документа | STG./RUSAL/PERZ.POSNR';
comment on column ods."/rusal/perz_ral".type is 'Тип документа | Тип документа | STG./RUSAL/PERZ.TYPE';
comment on column ods."/rusal/perz_ral".cpudt is 'Дата ввода бухгалтерского документа | Дата ввода бухгалтерского документа | STG./RUSAL/PERZ.CPUDT';
comment on column ods."/rusal/perz_ral".cputm is 'Время ввода | Время ввода | STG./RUSAL/PERZ.CPUTM';
