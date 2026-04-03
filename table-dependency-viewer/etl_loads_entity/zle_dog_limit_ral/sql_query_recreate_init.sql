drop table if exists ods.zle_dog_limit_ral;

create table ods.zle_dog_limit_ral (
	ebeln varchar(10) null,
	ktwrt_balance numeric(15, 2) null,
	waers varchar(5) null,
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
distributed by (ebeln);

comment on table ods.zle_dog_limit_ral is 'Таблица хранения данных по лимитам договоров';
comment on column ods.zle_dog_limit_ral.ebeln is 'Номер документа закупки | Номер документа закупки | ZLE_DOG_LIMIT.EBELN';
comment on column ods.zle_dog_limit_ral.ktwrt_balance is 'Остаток суммы по договору | Остаток суммы по договору | ZLE_DOG_LIMIT.KTWRT_BALANCE';
comment on column ods.zle_dog_limit_ral.waers is 'Код валюты | Код валюты | ZLE_DOG_LIMIT.WAERS';
