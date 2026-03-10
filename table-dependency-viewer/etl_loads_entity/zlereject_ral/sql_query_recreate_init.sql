drop table if exists ods.zlereject_ral;

create table if not exists ods.zlereject_ral (
	werks varchar(4) null,
	id varchar(10) null,
	pos varchar(5) null,
	numrej varchar(3) null,
	daterej date null,
	timerej time null,
	"text" text null,
	rejdel varchar(1) null,
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

comment on table ods.zlereject_ral is 'Журнал отказов в деблокировании';
comment on column ods.zlereject_ral.werks is 'Завод (код) | Завод (код) | stg.ZLEREJECT.WERKS';
comment on column ods.zlereject_ral.id is 'Акт на транспортировку (код) | Акт на транспортировку (код) | stg.ZLEREJECT.ID';
comment on column ods.zlereject_ral.pos is 'Позиция акта на транспортировку (код) | Позиция акта на транспортировку (код) | stg.ZLEREJECT.POS';
comment on column ods.zlereject_ral.numrej is 'Порядковый номер записи | Порядковый номер записи | stg.ZLEREJECT.NUMREJ';
comment on column ods.zlereject_ral.daterej is 'Дата отказа в деблокировании | Дата отказа в деблокировании | stg.ZLEREJECT.DATEREJ';
comment on column ods.zlereject_ral.timerej is 'Время отказа в деблокировании | Время отказа в деблокировании | stg.ZLEREJECT.TIMEREJ';
comment on column ods.zlereject_ral."text" is 'Описание отказа в деблокировании | Описание отказа в деблокировании | stg.ZLEREJECT.TEXT';
comment on column ods.zlereject_ral.rejdel is 'Метка удаления записи (код) | Метка удаления записи (код) | stg.ZLEREJECT.REJDEL';