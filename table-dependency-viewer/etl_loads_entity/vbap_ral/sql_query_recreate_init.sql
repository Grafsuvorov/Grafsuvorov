drop table if exists ods.vbap_ral CASCADE;

create table if not exists ods.vbap_ral (   -- ключ vbeln, posnr
	--zwert 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--netwr 			numeric(15, 2) null,				-- преобразовываем сумму по формуле
	--netpr 			numeric(11, 2) null,				-- преобразовываем сумму по формуле
	--wavwr 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--kzwi1 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--kzwi2 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--kzwi3 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--kzwi4 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--kzwi5 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--kzwi6 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--cmpre 			numeric(11, 2) null,				-- преобразовываем сумму по формуле
	--cmpre_flt,											-- преобразовываем сумму по формуле
	--mwsbp 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	--oifeetot 			numeric(13, 2) null,				-- преобразовываем сумму по формуле
	vbeln 				varchar not null,
	posnr 				varchar not null,
	zzcustco 			varchar null,
	ps_psp_pnr 			varchar null,
	aedat				date null,
	erdat 				date null,
	zzzakaz2            varchar null,
	pstyv               varchar null,
	werks 				varchar null,
	zzlfposnr 			varchar null,
	zzlfvbeln 			varchar null,
	dttm_inserted 		timestamp not null default now(),
	dttm_updated 		timestamp not null default now(),
	job_name 			varchar(60) not null default 'airflow'::character varying,
	deleted_flag 		bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (vbeln, posnr);

comment on table ods.vbap_ral is 'Торговый документ: данные позиции';
comment on column ods.vbap_ral.vbeln is 'Торговый документ | Торговый документ | VBAP.VBELN';
comment on column ods.vbap_ral.posnr is 'Позиция торгового документа | Позиция торгового документа | VBAP.POSNR';
comment on column ods.vbap_ral.zzcustco is 'Страна потребителя | Страна потребителя | VBAP.ZZCUSTCO';
comment on column ods.vbap_ral.ps_psp_pnr is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | VBAP.PS_PSP_PNR';
comment on column ods.vbap_ral.aedat is 'Дата последнего изменения | Дата последнего изменения | VBAP.AEDAT';
comment on column ods.vbap_ral.erdat is 'Дата создания записи | Дата создания записи | VBAP.ERDAT';
comment on column ods.vbap_ral.zzzakaz2 is 'Номер заказа клиента | Номер заказа клиента | VBAP.ZZZAKAZ2';
comment on column ods.vbap_ral.pstyv is 'Тип позиции документа сбыта | Тип позиции документа сбыта | VBAP.PSTYV';
comment on column ods.vbap_ral.werks is 'Завод (собственный или внешний) | Завод (собственный или внешний) | VBAP.WERKS';
comment on column ods.vbap_ral.zzlfposnr is 'Позиция поставки) | Позиция поставки | VBAP.ZZLFPOSNR';
comment on column ods.vbap_ral.zzlfvbeln is 'Поставка переработчика | Поставка переработчика | VBAP.ZZLFVBELN';