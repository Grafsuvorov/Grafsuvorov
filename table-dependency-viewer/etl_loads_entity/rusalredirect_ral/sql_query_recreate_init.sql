drop table if exists ods."/rusal/redirect_ral";

create table ods."/rusal/redirect_ral" (
	traid varchar(20) null,
	bolnr1 varchar(35) null,
	lfdat1 date null,
	change_type varchar(2) null,
	bolnr2 varchar(35) null,
	lfdat2 date null,
	knanf2 varchar(10) null,
	knend2 varchar(10) null,
	knend3 varchar(10) null,
	erdat date null,
	ernam varchar(12) null,
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
distributed by (traid, bolnr1);

comment on table ods."/rusal/redirect_ral" is 'Таблица для хранения данных о переадресации вагонов с глин.';
comment on column ods."/rusal/redirect_ral".traid is '№ вагона | № вагона | /RUSAL/REDIRECT.TRAID';
comment on column ods."/rusal/redirect_ral".bolnr1 is '№ накладной (до переадресации) | № накладной (до переадресации) | /RUSAL/REDIRECT.BOLNR1';
comment on column ods."/rusal/redirect_ral".lfdat1 is 'Дата отгрузки (до переадресации) | Дата отгрузки (до переадресации) | /RUSAL/REDIRECT.LFDAT1';
comment on column ods."/rusal/redirect_ral".change_type is 'Тип переадресации | Тип переадресации | /RUSAL/REDIRECT.CHANGE_TYPE';
comment on column ods."/rusal/redirect_ral".bolnr2 is '№ накладной (после переадресации) | № накладной (после переадресации) | /RUSAL/REDIRECT.BOLNR2';
comment on column ods."/rusal/redirect_ral".lfdat2 is 'Дата отгрузки после переадресации | Дата отгрузки после переадресации | /RUSAL/REDIRECT.LFDAT2';
comment on column ods."/rusal/redirect_ral".knanf2 is 'Станция переадресации | Станция переадресации | /RUSAL/REDIRECT.KNANF2';
comment on column ods."/rusal/redirect_ral".knend2 is 'Станция назначения (после переадресации) | Станция назначения (после переадресации) | /RUSAL/REDIRECT.KNEND2';
comment on column ods."/rusal/redirect_ral".knend3 is 'Станция назначения (до переадресации) | Станция назначения (до переадресации) | /RUSAL/REDIRECT.KNEND3';
comment on column ods."/rusal/redirect_ral".erdat is 'Дата создания записи | Дата создания записи | /RUSAL/REDIRECT.ERDAT';
comment on column ods."/rusal/redirect_ral".ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | /RUSAL/REDIRECT.ERNAM';
