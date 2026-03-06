drop table if exists ods."/rusal/perw_ral";

create table ods."/rusal/perw_ral" (
	werks varchar(4) null,
	id varchar(10) null,
	pos varchar(5) null,
	posv varchar(5) null,
	uname varchar(12) null,
	cpudt date null,
	cputm time null,
	ebeln varchar(10) null,
	vbeln varchar(10) null,
	bl varchar(30) null,
	wwert date null,
	n_plata numeric(13, 2) null,
	nds numeric(13, 2) null,
	waers varchar(5) null,	
	n_dmbtr numeric(13, 2) null,
	n_hwaer varchar(5) null,
	n_dmbe2 numeric(13, 2) null,
	n_hwae2 varchar(5) null,
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
distributed by (werks, id);

comment on table ods."/rusal/perw_ral" is 'Вагоны к позиции Акта';
comment on column ods."/rusal/perw_ral".werks is 'Завод | Завод | STG./RUSAL/PERW.WERKS';
comment on column ods."/rusal/perw_ral".id is 'ID документа | ID документа | STG./RUSAL/PERW.ID';
comment on column ods."/rusal/perw_ral".pos is 'Позиция документа | Позиция документа | STG./RUSAL/PERW.POS';
comment on column ods."/rusal/perw_ral".posv is 'Позиция вагона | Позиция вагона | STG./RUSAL/PERW.POSV';
comment on column ods."/rusal/perw_ral".uname is 'Имя пользователя | Имя пользователя | STG./RUSAL/PERW.UNAME';
comment on column ods."/rusal/perw_ral".cpudt is 'Дата ввода документа | Дата ввода документа | STG./RUSAL/PERW.CPUDT';
comment on column ods."/rusal/perw_ral".cputm is 'Время ввода | Время ввода | STG./RUSAL/PERW.CPUTM';
comment on column ods."/rusal/perw_ral".ebeln is 'Номер стоимостного контракта | Номер стоимостного контракта | STG./RUSAL/PERW.EBELN';
comment on column ods."/rusal/perw_ral".vbeln is 'Поставка | Поставка | STG./RUSAL/PERW.VBELN';
comment on column ods."/rusal/perw_ral".bl is 'Номер коносамента, в который входит вагон | Номер коносамента, в который входит вагон | STG./RUSAL/PERW.BL';
comment on column ods."/rusal/perw_ral".wwert is 'Дата курса для пересчета | Дата курса для пересчета | STG./RUSAL/PERW.WWERT';
comment on column ods."/rusal/perw_ral".n_plata is 'Сумма по вагону без НДС | Сумма по вагону без НДС | STG./RUSAL/PERW.N_PLATA';
comment on column ods."/rusal/perw_ral".nds is 'НДС по вагону | НДС по вагону | STG./RUSAL/PERW.NDS';
comment on column ods."/rusal/perw_ral".waers is 'Код валюты | Код валюты | STG./RUSAL/PERW.WAERS';
comment on column ods."/rusal/perw_ral".n_dmbtr is 'Сумма по вагону без НДС во внутренней валюте | Сумма по вагону без НДС во внутренней валюте | STG./RUSAL/PERW.N_DMBTR';
comment on column ods."/rusal/perw_ral".n_hwaer is 'Код внутренней валюты | Код внутренней валюты | STG./RUSAL/PERW.N_HWAER';
comment on column ods."/rusal/perw_ral".n_dmbe2 is 'Сумма по вагону без НДС во второй внутренней валюте | Сумма по вагону без НДС во второй внутренней валюте | STG./RUSAL/PERW.N_DMBE2';
comment on column ods."/rusal/perw_ral".n_hwae2 is 'Код второй внутренней валюты | Код второй внутренней валюты | STG./RUSAL/PERW.N_HWAE2';
