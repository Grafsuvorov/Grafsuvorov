drop table if exists ods.ztle_contcn_ral;

create table ods.ztle_contcn_ral (
	container varchar(20) null,
	dt_inport date null,
	dt_outport date null,
	dt_outrcvr date null,
	dt_in_stock date null,
	stock_text varchar(40) null,
	stock_knote varchar(10) null,
	dt_out_stock date null,
	dt_load_stock date null,
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
distributed by (container, dt_inport);

comment on table ods.ztle_contcn_ral is 'Данные собственных контейнеров по КНР';
comment on column ods.ztle_contcn_ral.container is 'Номер контейнера | | ZTLE_CONTCN.CONTAINER';
comment on column ods.ztle_contcn_ral.dt_inport is 'Дата приемки контейнера в порту КНР | | ZTLE_CONTCN.DT_INPORT';
comment on column ods.ztle_contcn_ral.dt_outport is 'Дата вывоза контейнера из порта выгрузки КНР | | ZTLE_CONTCN.DT_OUTPORT';
comment on column ods.ztle_contcn_ral.dt_outrcvr is 'Дата выгрузки у получателя/ на складе КНР | | ZTLE_CONTCN.DT_OUTRCVR';
comment on column ods.ztle_contcn_ral.dt_in_stock is 'Дата сдачи порожнего контейнера в сток КНР | | ZTLE_CONTCN.DT_IN_STOCK';
comment on column ods.ztle_contcn_ral.stock_text is 'Сток сдачи порожнего контейнера КНР | | ZTLE_CONTCN.STOCK_TEXT';
comment on column ods.ztle_contcn_ral.stock_knote is 'Узел стока сдачи порожнего контейнера КНР | | ZTLE_CONTCN.STOCK_KNOTE';
comment on column ods.ztle_contcn_ral.dt_out_stock is 'Дата вывоза порожнего контейнера из стока КНР | | ZTLE_CONTCN.DT_OUT_STOCK';
comment on column ods.ztle_contcn_ral.dt_load_stock is 'Дата завоза в сток под отгрузку импорта КНР | | ZTLE_CONTCN.DT_LOAD_STOCK';
