drop table if exists ods.likp_ral;

create table if not exists ods.likp_ral (
	vbeln varchar(10) null,
	vkorg varchar(12) null,
	traid varchar(20) null,
	bolnr varchar(35) null,
	lfart varchar(4) null,
	lddat date null,
	kodat date null,
	route varchar(6) null,
	sdabw varchar(4) null,
	xabln varchar(10) null,
	traty varchar(4) null,
	lifex varchar(35) null,
	lstel varchar(6) null,
	ntgew numeric(15, 3) null, 
	btgew numeric(15, 3) null,
	gewei varchar(3) null,
	erdat date null,
	erzet time null,
	ernam varchar(12) null,
	trspg varchar(2) null,
	vsart varchar(2) null,
	kunnr varchar(10) null,
	vstel varchar(4) null,
	vbtyp varchar(5) null,
	wadat_ist date null,
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

comment on table ods.likp_ral is 'Заводская поставка';
comment on column ods.likp_ral.vbeln is 'Заводская поставка (код) | Заводская поставка (код) | LIKP.VBELN';
comment on column ods.likp_ral.vkorg is 'Сбытовая организация | Сбытовая организация | LIKP.VKORG';
comment on column ods.likp_ral.traid is 'Номер вагона | Номер вагона | LIKP.TRAID';
comment on column ods.likp_ral.bolnr is 'Транспортная накладная | Транспортная накладная | LIKP.BOLNR';
comment on column ods.likp_ral.lfart is 'Вид поставки | Вид поставки | LIKP.LFART';
comment on column ods.likp_ral.lddat is 'Дата отгрузки с завода | Дата отгрузки с завода | LIKP.LDDAT';
comment on column ods.likp_ral.kodat is 'Дата отгрузки со склада | Дата отгрузки со склада | LIKP.KODAT';
comment on column ods.likp_ral.route is 'Маршрут | Маршрут | LIKP.ROUTE';
comment on column ods.likp_ral.sdabw is 'Тип транспортного средства (код) | Тип транспортного средства (код) | LIKP.SDABW';
comment on column ods.likp_ral.xabln is 'Номер накладной | Номер накладной | LIKP.XABLN';
comment on column ods.likp_ral.traty is 'Вид транспортного средства (код) | Вид транспортного средства (код) | LIKP.TRATY';
comment on column ods.likp_ral.lifex is 'Внешняя идентификация накладной | Внешняя идентификация накладной | LIKP.LIFEX';
comment on column ods.likp_ral.lstel is 'Пункт погрузки | Пункт погрузки | LIKP.LSTEL';
comment on column ods.likp_ral.ntgew is 'Вес нетто | Вес нетто | LIKP.NTGEW';
comment on column ods.likp_ral.btgew is 'Вес нетто + катанка | Вес нетто + катанка | LIKP.BTGEW';
comment on column ods.likp_ral.gewei is 'Единица измерения веса | Единица измерения веса | LIKP.GEWEI';
comment on column ods.likp_ral.erdat is 'Дата создания записи | Дата создания записи | LIKP.ERDAT';
comment on column ods.likp_ral.erzet is 'Время создания записи | Время создания записи | LIKP.ERZET';
comment on column ods.likp_ral.ernam is 'Логин пользователя, создавшего запись | Логин пользователя, создавшего запись | LIKP.ERNAM';
comment on column ods.likp_ral.trspg is 'Причина блокировки транспортировки | Причина блокировки транспортировки | LIKP.TRSPG';
comment on column ods.likp_ral.vsart is 'Wagon/container | Wagon/container | LIKP.VSART';
comment on column ods.likp_ral.kunnr is 'Получатель материала | Получатель материала | LIKP.KUNNR';
comment on column ods.likp_ral.vstel is 'Пункт отгрузки(организационная единица (код)) | Пункт отгрузки(организационная единица (код)) | LIKP.VSTEL';
comment on column ods.likp_ral.vbtyp is 'Категория документов | Категория документов | LIKP.VBTYP';
comment on column ods.likp_ral.wadat_ist is 'Дата фактического движения материала | Дата фактического движения материала | LIKP.WADAT_IST';
