drop table if exists ods."/rul/rw_docs_ral";

create table if not exists ods."/rul/rw_docs_ral" (
	matnr varchar(19) null,	
	charg varchar(10) null,
	werks varchar(4) null,
	belnr varchar(10) null,
	posnr varchar(6) null,
	status varchar(2) null,
	ebeln varchar(10) null,
	ebelp varchar(5) null,
	fvdt3 date null,
	mblnr varchar(10) null,
	mjahr varchar(4) null,
	zeile varchar(4) null,
	path varchar(3) null,
	conosnum varchar(30) null,
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
distributed by (matnr, charg, werks);

comment on table ods."/rul/rw_docs_ral" is 'БД транспортных средств - документы';
comment on column ods."/rul/rw_docs_ral"."matnr" is 'Номер материала | Номер материала | /RUL/RW_DOCS.MATNR';
comment on column ods."/rul/rw_docs_ral"."charg" is 'Номер партии | Номер партии | /RUL/RW_DOCS.CHARG';
comment on column ods."/rul/rw_docs_ral"."werks" is 'Завод | Завод | /RUL/RW_DOCS.WERKS';
comment on column ods."/rul/rw_docs_ral"."belnr" is 'Поставка | Поставка | /RUL/RW_DOCS.BELNR';
comment on column ods."/rul/rw_docs_ral"."posnr" is 'Позиция поставки | Позиция поставки | /RUL/RW_DOCS.POSNR';
comment on column ods."/rul/rw_docs_ral"."status" is 'Статус состояния документа | Статус состояния документа | /RUL/RW_DOCS.STATUS';
comment on column ods."/rul/rw_docs_ral"."ebeln" is 'Номер документа закупки | Номер документа закупки | /RUL/RW_DOCS.EBELN';
comment on column ods."/rul/rw_docs_ral"."ebelp" is 'Номер позиции документа закупки | Номер позиции документа закупки | /RUL/RW_DOCS.EBELP';
comment on column ods."/rul/rw_docs_ral"."fvdt3" is 'Дата поступления | Дата поступления | /RUL/RW_DOCS.FVDT3';
comment on column ods."/rul/rw_docs_ral"."mblnr" is 'Номер документа материала | Номер документа материала | /RUL/RW_DOCS.MBLNR';
comment on column ods."/rul/rw_docs_ral"."mjahr" is 'Год документа материала | Год документа материала | /RUL/RW_DOCS.MJAHR';
comment on column ods."/rul/rw_docs_ral"."zeile" is 'Позиция документа материала | Позиция документа материала | /RUL/RW_DOCS.ZEILE';
comment on column ods."/rul/rw_docs_ral"."path" is 'Номер пути во внешней системе | Номер пути во внешней системе | /RUL/RW_DOCS.PATH';
comment on column ods."/rul/rw_docs_ral"."conosnum" is 'Номер коносамента | Номер коносамента | /RUL/RW_DOCS.CONOSNUM';