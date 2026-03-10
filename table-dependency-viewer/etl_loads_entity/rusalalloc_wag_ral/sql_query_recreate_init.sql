drop table if exists ods."/rusal/alloc_wag_ral" cascade; --_rusal_alloc_wag_ral
 
create table ods."/rusal/alloc_wag_ral" (
	market varchar(4) null,
	month_otgr varchar(6) null,
	matkl varchar(9) null,
	pimary varchar(30) null,
	locid varchar(10) null,
	matnr varchar(18) null,
	werks varchar(4) null,
	korr_bw varchar(5) null,
	numvr varchar(2) null,
	reserv varchar(4) null,
	no_rasp varchar(4) null,
	allocnr varchar(20) null,
	wagnr varchar(44) null,
	vbeln varchar(10) null,
	d_werks_otgr_p date null,
	vbeli varchar(10) null,
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
distributed by (market, month_otgr, matkl, pimary, locid, matnr, werks, korr_bw, numvr, reserv, no_rasp, allocnr, wagnr);

comment on table ods."/rusal/alloc_wag_ral" is 'Сохранение вагонов в распределении';
comment on column ods."/rusal/alloc_wag_ral".market is 'Трейдеры: рынок сбыта | Трейдеры: рынок сбыта | stg./RUSAL/ALLOC_WAG.market';
comment on column ods."/rusal/alloc_wag_ral".month_otgr is 'Период отгрузки | Период отгрузки | stg./RUSAL/ALLOC_WAG.month_otgr';
comment on column ods."/rusal/alloc_wag_ral".matkl is 'Группа материалов | Группа материалов | stg./RUSAL/ALLOC_WAG.matkl';
comment on column ods."/rusal/alloc_wag_ral".pimary is 'Материал | Материал | stg./RUSAL/ALLOC_WAG.pimary';
comment on column ods."/rusal/alloc_wag_ral".locid is 'Направление | Направление | stg./RUSAL/ALLOC_WAG.locid';
comment on column ods."/rusal/alloc_wag_ral".matnr is 'Номер материала | Номер материала | stg./RUSAL/ALLOC_WAG.matnr';
comment on column ods."/rusal/alloc_wag_ral".werks is 'Завод | Завод | stg./RUSAL/ALLOC_WAG.werks';
comment on column ods."/rusal/alloc_wag_ral".korr_bw is 'Номер корректировки BW | Номер корректировки BW | stg./RUSAL/ALLOC_WAG.korr_bw';
comment on column ods."/rusal/alloc_wag_ral".numvr is 'Номер версии | Номер версии | stg./RUSAL/ALLOC_WAG.numvr';
comment on column ods."/rusal/alloc_wag_ral".reserv is 'Признак резервирования | Признак резервирования | stg./RUSAL/ALLOC_WAG.reserv';
comment on column ods."/rusal/alloc_wag_ral".no_rasp is 'Признак нераспределенной отгрузки | Признак нераспределенной отгрузки | stg./RUSAL/ALLOC_WAG.no_rasp';
comment on column ods."/rusal/alloc_wag_ral".allocnr is '№ записи в таблице распределения | № записи в таблице распределения | stg./RUSAL/ALLOC_WAG.allocnr';
comment on column ods."/rusal/alloc_wag_ral".wagnr is '№ записи в таблице распределения вагонов | № записи в таблице распределения вагонов | stg./RUSAL/ALLOC_WAG.wagnr';
comment on column ods."/rusal/alloc_wag_ral".vbeln is 'Поставка | Поставка | stg./RUSAL/ALLOC_WAG.vbeln';
comment on column ods."/rusal/alloc_wag_ral".d_werks_otgr_p is 'Дата отгрузки плановая | Дата отгрузки плановая | stg./RUSAL/ALLOC_WAG.D_WERKS_OTGR_P';
comment on column ods."/rusal/alloc_wag_ral".vbeli is 'Входящая поставка до разделения | Входящая поставка до разделения | stg./RUSAL/ALLOC_WAG.VBELI';
