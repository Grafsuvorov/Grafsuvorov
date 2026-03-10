drop table if exists ods.zle_dislcont_ral;

create table ods.zle_dislcont_ral (
	id varchar(10) null,
	pos varchar(6) null,
	container varchar(11) null,
	numnakl varchar(35) null,
	carnumber varchar(20) null,
	oper_code varchar(2) null,
	oper_date date null,
	oper_time time null,
	load_station varchar(10) null,
	erdat date null,
	erzet time null,
	ernam varchar(12) null,
	aedat date null,
	aezet time null,
	aenam varchar(12) null,
	oper_station varchar(10) null,
	dest_station varchar(10) null,
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
distributed by (container, numnakl);

comment on table ods.zle_dislcont_ral is 'Дислокация контейнеров';
comment on column ods.zle_dislcont_ral.id is 'ID загрузки | ID загрузки | ZLE_DISLCONT.ID';
comment on column ods.zle_dislcont_ral.pos is 'Позиция загрузки | Позиция загрузки | ZLE_DISLCONT.POS';
comment on column ods.zle_dislcont_ral.container is 'Номер контейнера | Номер контейнера | ZLE_DISLCONT.CONTAINER';
comment on column ods.zle_dislcont_ral.numnakl is 'Транспортная накладная | Транспортная накладная | ZLE_DISLCONT.NUMNAKL';
comment on column ods.zle_dislcont_ral.carnumber is 'Номер вагона (платформы) | Номер вагона (платформы) | ZLE_DISLCONT.CARNUMBER';
comment on column ods.zle_dislcont_ral.oper_code is 'Код операции | Код операции | ZLE_DISLCONT.OPER_CODE';
comment on column ods.zle_dislcont_ral.oper_date is 'Дата операции | Дата операции | ZLE_DISLCONT.OPER_DATE';
comment on column ods.zle_dislcont_ral.oper_time is 'Время операции | Время операции | ZLE_DISLCONT.OPER_TIME';
comment on column ods.zle_dislcont_ral.load_station is 'Код станции погрузки | Код станции погрузки | ZLE_DISLCONT.LOAD_STATION';
comment on column ods.zle_dislcont_ral.erdat is 'Дата создания записи | Дата создания записи | ZLE_DISLCONT.ERDAT';
comment on column ods.zle_dislcont_ral.erzet is 'Время ввода | Время ввода | ZLE_DISLCONT.ERZET';
comment on column ods.zle_dislcont_ral.ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | ZLE_DISLCONT.ERNAM';
comment on column ods.zle_dislcont_ral.aedat is 'Дата последнего изменения | Дата последнего изменения | ZLE_DISLCONT.AEDAT';
comment on column ods.zle_dislcont_ral.aezet is 'Время последнего изменения | Время последнего изменения | ZLE_DISLCONT.AEZET';
comment on column ods.zle_dislcont_ral.aenam is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | ZLE_DISLCONT.AENAM';
comment on column ods.zle_dislcont_ral.oper_station is 'Код станции операции | Код станции операции | ZLE_DISLCONT.OPER_STATION';
comment on column ods.zle_dislcont_ral.dest_station is 'Код станции назначения | Код станции назначения | ZLE_DISLCONT.DEST_STATION';
