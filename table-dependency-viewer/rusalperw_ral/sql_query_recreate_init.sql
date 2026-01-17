drop table if exists ods."/rusal/perw_ral";

create table if not exists ods."/rusal/perw_ral" (
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
	statuss varchar(4) null,
	dok_1172 varchar(1) null,
	declaration varchar(30) null,
	n_nakl varchar(35) null,
	n_wag varchar(20) null,
	own_vag varchar(1) null,
	platf varchar(20) null,
	kursf numeric(16, 6) null,
	n_ves_n numeric(13, 3) null,
	d_otpravl date null,
	bl_bum varchar(30) null,
	databl date null,
	nomtk varchar(20) null,
	ztype varchar(1) null,
	wapprove varchar(1) null,
	vag_source varchar(1) null,
	pr_no_rzd varchar(1) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
) with (appendonly=true, orientation=column, compresstype=zstd,compresslevel=3)
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
comment on column ods."/rusal/perw_ral".statuss is 'Статус сверки | Статус сверки | STG./RUSAL/PERP.STATUSS';
comment on column ods."/rusal/perw_ral".dok_1172 is 'Полное распределение | Полное распределение | STG./RUSAL/PERP.DOK_1172';
comment on column ods."/rusal/perw_ral".declaration is '№ декларации | № декларации | STG./RUSAL/PERP.DECLARATION';
comment on column ods."/rusal/perw_ral".n_nakl is 'Транспортная накладная | Транспортная накладная | STG./RUSAL/PERP.N_NAKL';
comment on column ods."/rusal/perw_ral".n_wag is '№ вагона/контейнера | № вагона/контейнера | STG./RUSAL/PERP.N_WAG';
comment on column ods."/rusal/perw_ral".own_vag is 'Собственное ТС | Собственное ТС | STG./RUSAL/PERP.OWN_VAG';
comment on column ods."/rusal/perw_ral".platf is '№ платформы | № платформы | STG./RUSAL/PERP.PLATF';
comment on column ods."/rusal/perw_ral".kursf is 'Валютный курс | Валютный курс | STG./RUSAL/PERP.KURSF';
comment on column ods."/rusal/perw_ral".n_ves_n is 'Вес по накладной | Вес по накладной | STG./RUSAL/PERP.N_VES_N';
comment on column ods."/rusal/perw_ral".d_otpravl is 'Дата отправления | Дата отправления | STG./RUSAL/PERP.D_OTPRAVL';
comment on column ods."/rusal/perw_ral".bl_bum is '№ коносамента | № коносамента | STG./RUSAL/PERP.BL_BUM';
comment on column ods."/rusal/perw_ral".databl is 'Дата коносамента | Дата коносамента | STG./RUSAL/PERP.DATABL';
comment on column ods."/rusal/perw_ral".nomtk is 'Номинация | Номинация | STG./RUSAL/PERP.NOMTK';
comment on column ods."/rusal/perw_ral".ztype is 'Тип услуги | Тип услуги | STG./RUSAL/PERP.ZTYPE';
comment on column ods."/rusal/perw_ral".wapprove is 'Согласовано принимающим заводом | Согласовано принимающим заводом | STG./RUSAL/PERP.WAPPROVE';
comment on column ods."/rusal/perw_ral".vag_source is 'Происхождение вагона | Происхождение вагона | STG./RUSAL/PERP.VAG_SOURCE';
comment on column ods."/rusal/perw_ral".pr_no_rzd is 'Признак запрета выезда на пути общего пользования | Признак запрета выезда на пути общего пользования | STG./RUSAL/PERP.PR_NO_RZD';