drop table if exists ods.ztle_railcn_ral;

create table if not exists ods.ztle_railcn_ral (
	id varchar(10) null,
	pos varchar(6) null,
	type_load varchar(2) null,
	container varchar(25) null,
	numnakl varchar(35) null,
	car_num varchar(20) null,
	dateot date null,
	zdkodstfr varchar(10) null,
	zdkodstto varchar(10) null,
	werks varchar(4) null,
	vbeln varchar(10) null,
	weight numeric(13, 3) null,
	weight_br numeric(13, 3) null,
	erdat date null,
	erzet time null,
	ernam varchar(12) null,
	aedat date null,
	aezet time null,
	aenam varchar(12) null,
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

comment on table ods.ztle_railcn_ral is 'Данные об отгрузке сырья в ЖД контейнерах из Китая';
comment on column ods.ztle_railcn_ral.id is 'ID загрузки | ID загрузки | ZTLE_RAILCN.ID';
comment on column ods.ztle_railcn_ral.pos is 'Позиция загрузки | Позиция загрузки | ZTLE_RAILCN.POS';
comment on column ods.ztle_railcn_ral.type_load is 'Тип загрузки | Тип загрузки | ZTLE_RAILCN.TYPE_LOAD';
comment on column ods.ztle_railcn_ral.container is '№ контейнера в который перегружается вагон | № контейнера в который перегружается вагон | ZTLE_RAILCN.CONTAINER';
comment on column ods.ztle_railcn_ral.numnakl is 'Транспортная накладная | Транспортная накладная | ZTLE_RAILCN.NUMNAKL';
comment on column ods.ztle_railcn_ral.car_num is 'Номер автомобиля | Номер автомобиля | ZTLE_RAILCN.CAR_NUM';
comment on column ods.ztle_railcn_ral.dateot is 'Дата отгрузки | Дата отгрузки | ZTLE_RAILCN.DATEOT';
comment on column ods.ztle_railcn_ral.zdkodstfr is 'Станция отгрузки | Станция отгрузки | ZTLE_RAILCN.ZDKODSTFR';
comment on column ods.ztle_railcn_ral.zdkodstto is 'Узел назначения | Узел назначения | ZTLE_RAILCN.ZDKODSTTO';
comment on column ods.ztle_railcn_ral.werks is 'Завод назначения | Завод назначения | ZTLE_RAILCN.WERKS';
comment on column ods.ztle_railcn_ral.vbeln is 'Входящая поставка | Входящая поставка | ZTLE_RAILCN.VBELN';
comment on column ods.ztle_railcn_ral.weight is 'Вес нетто | Вес нетто | ZTLE_RAILCN.WEIGHT';
comment on column ods.ztle_railcn_ral.weight_br is 'Вес Брутто | Вес Брутто | ZTLE_RAILCN.WEIGHT_BR';
comment on column ods.ztle_railcn_ral.erdat is 'Дата создания записи | Дата создания записи | ZTLE_RAILCN.ERDAT';
comment on column ods.ztle_railcn_ral.erzet is 'Время ввода | Время ввода | ZTLE_RAILCN.ERZET';
comment on column ods.ztle_railcn_ral.ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | ZTLE_RAILCN.ERNAM';
comment on column ods.ztle_railcn_ral.aedat is 'Дата последнего изменения | Дата последнего изменения | ZTLE_RAILCN.AEDAT';
comment on column ods.ztle_railcn_ral.aezet is 'Время последнего изменения | Время последнего изменения | ZTLE_RAILCN.AEZET';
comment on column ods.ztle_railcn_ral.aenam is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | ZTLE_RAILCN.AENAM';