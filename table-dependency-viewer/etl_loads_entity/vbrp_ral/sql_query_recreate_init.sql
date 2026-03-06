drop table if exists ods.vbrp_ral cascade;

create table if not exists ods.vbrp_ral (
	vbeln varchar NULL,
	posnr varchar NULL,
	vgtyp varchar NULL,
	vgbel varchar NULL,
	matnr varchar NULL,
	pstyv varchar NULL,
	netwr numeric(15, 2) NULL,												--поле с суммой, которую необходимо преобразовывать
	aubel varchar NULL,
	aupos varchar NULL,
	fkimg numeric(13, 3) NOT NULL,
	brgew numeric(15, 3) NULL,
	kvgr5 varchar NULL,
	mwsbp numeric(15, 3) NULL,
	vgpos varchar NULL,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT FALSE 
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (vbeln, posnr);

comment on table ods.vbrp_ral is 'Фактура: данные позиции';
comment on column ods.vbrp_ral.vbeln is 'Фактура | - | stg."VBRP"."VBELN"';
comment on column ods.vbrp_ral.posnr is 'Позиция фактуры | - | stg."VBRP"."POSNR"';
comment on column ods.vbrp_ral.vgtyp is 'Тип предшествующего документа сбыта | - | stg."VBRP"."VGTYP"';
comment on column ods.vbrp_ral.vgbel is 'Номер документа-образца | - | stg."VBRP"."VGBEL"';
comment on column ods.vbrp_ral.matnr is 'Номер материала | - | stg."VBRP"."MATNR"';
comment on column ods.vbrp_ral.pstyv is 'Тип позиции документа сбыта | - | stg."VBRP"."PSTYV"';
comment on column ods.vbrp_ral.netwr is 'Стоимость нетто позиции фактуры в валюте документа | - | stg."VBRP"."NETWR"';
comment on column ods.vbrp_ral.aubel is 'Торговый документ | - | stg."VBRP"."AUBEL"';
comment on column ods.vbrp_ral.aupos is 'Позиция торгового документа | - | stg."VBRP"."AUPOS"';
comment on column ods.vbrp_ral.fkimg is 'Фактически фактурированное количество | - | stg."VBRP"."FKIMG"';
comment on column ods.vbrp_ral.brgew is 'Вес бруто | - | stg."VBRP"."BRGEW"';
comment on column ods.vbrp_ral.kvgr5 is 'Тип упаковки катанки | - | stg."VBRP"."KVGR5"';
comment on column ods.vbrp_ral.mwsbp is 'Сумма налога в валюте документа | - | stg."VBRP"."MWSBP"';
comment on column ods.vbrp_ral.vgpos is 'Исходная позиция фактуры | - | stg."VBRP"."VGPOS"';
