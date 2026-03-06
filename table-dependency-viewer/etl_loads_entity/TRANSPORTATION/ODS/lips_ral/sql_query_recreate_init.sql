drop table if exists ods.lips_ral;

create table ods.lips_ral ( -- ключ vbeln, posnr
	vbeln varchar(10) not null,  
	posnr varchar(6) not null, 
	werks varchar(4) null,
	charg varchar(10) null,  
	lgort varchar(4) null,  
	bwtar varchar(10) null,  
	spart varchar(2) null,
	matkl varchar(9) null,
	matnr varchar(18) null,	
	vgbel varchar(10) null,  
	vgpos varchar(6) null, 
	pstyv varchar(4) null,
	lfimg numeric(15, 3) null,
	xchpf varchar(4) null,
	brgew numeric(15, 3) null,
	ntgew numeric(15, 3) null,
	meins varchar(3) null,
	gewei varchar(3) null,
	objpo varchar(70) null,
	vrkme varchar(5) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by (vbeln);

comment on table ods.lips_ral is 'Документ сбыта: поставка: данные позиции';
comment on column ods.lips_ral.vbeln is 'Поставка завода производителя, по которой формируется цепочка продаж на заводе производителе | Поставка завода производителя, по которой формируется цепочка продаж на заводе производителе | LIPS.VBELN';
comment on column ods.lips_ral.posnr is 'Позиция поставки завода производителя, по которой формируется цепочка продаж на заводе производителе | Позиция поставки завода производителя, по которой формируется цепочка продаж на заводе производителе | LIPS.POSNR';
comment on column ods.lips_ral.werks is 'Завод производитель (код) | Завод производитель (код) | LIPS.WERKS';
comment on column ods.lips_ral.charg is 'Номер партии | Номер партии | LIPS.CHARG';
comment on column ods.lips_ral.lgort is 'Склад | Склад | LIPS.LGORT';
comment on column ods.lips_ral.bwtar is 'Вид оценки | Вид оценки | LIPS.BWTAR';
comment on column ods.lips_ral.spart is 'Сектор - группа материалов (код) | Сектор - группа материалов (код) | LIPS.SPART';
comment on column ods.lips_ral.matkl is 'Группа материалов (код) | Группа материалов (код) | LIPS.MATKL';
comment on column ods.lips_ral.matnr is 'Материал (код) | Материал (код) | LIPS.MATNR';
comment on column ods.lips_ral.vgbel is 'Ссылка на Торговый документ: данные заголовка | Ссылка на Торговый документ: данные заголовка VBAK, VBAP | LIPS.VGBEL';
comment on column ods.lips_ral.vgpos is 'Ссылка на Торговый документ: данные позиции | Ссылка на Торговый документ: данные позиции VBAP | LIPS.VGPOS';
comment on column ods.lips_ral.pstyv is 'Тип позиции поставки | Тип позиции поставки | LIPS.PSTYV';
comment on column ods.lips_ral.lfimg is 'Фактически поставленное количество (ПЕ) | Фактически поставленное количество (ПЕ) | LIPS.LFIMG';
comment on column ods.lips_ral.xchpf is 'Признак управления партиями | Признак управления партиями | LIPS.XCHPF';
comment on column ods.lips_ral.brgew is 'Вес брутто | Вес брутто | LIPS.BRGEW';
comment on column ods.lips_ral.ntgew is 'Вес нетто | Вес нетто | LIPS.NTGEW';
comment on column ods.lips_ral.meins is 'Базовая единица измерения | Базовая единица измерения | LIPS.MEINS';
comment on column ods.lips_ral.gewei is 'Единица измерения веса | Единица измерения веса | LIPS.GEWEI';
comment on column ods.lips_ral.objpo is 'Ссылка на номер позиции | Ссылка на номер позиции | LIPS.OBJPO';
comment on column ods.lips_ral.vrkme is 'Код единицы измерения веса | Код единицы измерения веса | LIPS.VRKME';