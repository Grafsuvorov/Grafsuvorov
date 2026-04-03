drop table if exists ods."/rusal/leport_ral";

create table ods."/rusal/leport_ral" (
	container varchar(30) null,
 	bl varchar(30) null,
 	databl date null,
 	port_to varchar(10) null,
	terminal_rf varchar(10) null,
	data_ship date null,
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
distributed by (container, bl);

comment on table ods."/rusal/leport_ral" is 'Приход сырья в Порт РФ';
comment on column ods."/rusal/leport_ral".container is 'Контейнер | Контейнер | /RUSAL/LEPORT.CONTAINER';
comment on column ods."/rusal/leport_ral".bl is 'Номер коносамента | Номер коносамента | /RUSAL/LEPORT.BL';
comment on column ods."/rusal/leport_ral".databl is 'Дата коносамента | Дата коносамента | /RUSAL/LEPORT.DATABL';
comment on column ods."/rusal/leport_ral".port_to is 'Порт выгрузки | Порт выгрузки | /RUSAL/LEPORT.PORT_TO';
comment on column ods."/rusal/leport_ral".terminal_rf is 'Терминал РФ | Терминал РФ | /RUSAL/LEPORT.TERMINAL_RF';
comment on column ods."/rusal/leport_ral".data_ship is 'Дата выгрузки с судна | Дата выгрузки с судна | /RUSAL/LEPORT.DATA_SHIP';
comment on column ods."/rusal/leport_ral".erdat is 'Дата создания записи | Дата создания записи | /RUSAL/LEPORT.ERDAT';
comment on column ods."/rusal/leport_ral".erzet is 'Время ввода | Время ввода | /RUSAL/LEPORT.ERZET';
comment on column ods."/rusal/leport_ral".ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | /RUSAL/LEPORT.ERNAM';
comment on column ods."/rusal/leport_ral".aedat is 'Дата последнего изменения | Дата последнего изменения | /RUSAL/LEPORT.AEDAT';
comment on column ods."/rusal/leport_ral".aezet is 'Время последнего изменения | Время последнего изменения | /RUSAL/LEPORT.AEZET';
comment on column ods."/rusal/leport_ral".aenam is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | /RUSAL/LEPORT.AENAM';
