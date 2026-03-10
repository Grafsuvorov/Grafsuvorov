DROP TABLE IF EXISTS ods.easu_lp_v_frozen_product;

CREATE TABLE ods.easu_lp_v_frozen_product (
	dat date NULL,
	id_restfrozenrow varchar(40) NULL,
	keysap varchar(10) NULL,
	shape varchar(10) NULL, 
	std varchar(80) NULL, 
	mark varchar(30) NULL, 
	pack varchar(50) NULL, 
	razmer varchar(30) NULL, 
	monthregistry date NULL, 
	ordercc varchar(10) NULL, 
	customer varchar(300) NULL, 
	nettofrozen numeric(15,4) NULL, 
	namefrozentype varchar(50) NULL, 
	id_frozentype numeric(14) NULL, 
	noteplant varchar(300) NULL, 
	notead varchar(1000) NULL, 
	notedsb varchar(500) NULL, 
	notedtil varchar(200) NULL, 
	netto_ad numeric(15,4) NULL, 
	netto_dsb numeric(15,4) NULL, 
	netto_drvr numeric(15,4) NULL, 
	netto_dd numeric(15,4) NULL, 
	netto_dtil numeric(15,4) NULL, 
	id_place numeric(15) NULL, 
	sgp varchar(20) NULL, 
	smelter varchar(10) NULL,
	namefrozenresponsible varchar(15) NULL,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false,
	is_actual bool NOT NULL DEFAULT true
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (dat, id_restfrozenrow);

comment on column ods.easu_lp_v_frozen_product.dat is 'Дата формирования отчета | Дата формирования отчета | stg."EASU_LP_V_FROZEN_PRODUCT".dat';
comment on column ods.easu_lp_v_frozen_product.id_restfrozenrow is 'ID записи в отчете | ID записи в отчете | stg."EASU_LP_V_FROZEN_PRODUCT".id_restfrozenrow';
comment on column ods.easu_lp_v_frozen_product.keysap is 'ID спецификации продукции | ID спецификации продукции | stg."EASU_LP_V_FROZEN_PRODUCT".keysap';
comment on column ods.easu_lp_v_frozen_product.shape is 'Вид продукции | Вид продукции | stg."EASU_LP_V_FROZEN_PRODUCT".shape';
comment on column ods.easu_lp_v_frozen_product.std is 'Текст Спецификации | Текст Спецификации | stg."EASU_LP_V_FROZEN_PRODUCT".std';
comment on column ods.easu_lp_v_frozen_product.mark is 'Марка спецфикации | Марка спецфикации | stg."EASU_LP_V_FROZEN_PRODUCT".mark';
comment on column ods.easu_lp_v_frozen_product.pack is 'Размеры пакета | Размеры пакета | stg."EASU_LP_V_FROZEN_PRODUCT".pack';
comment on column ods.easu_lp_v_frozen_product.razmer is 'Размер единицы продукции | Размер единицы продукции | stg."EASU_LP_V_FROZEN_PRODUCT".razmer';
comment on column ods.easu_lp_v_frozen_product.monthregistry is 'месяц приема | месяц приема | stg."EASU_LP_V_FROZEN_PRODUCT".monthregistry';
comment on column ods.easu_lp_v_frozen_product.ordercc is 'Заказ ЦК | Заказ ЦК | stg."EASU_LP_V_FROZEN_PRODUCT".ordercc';
comment on column ods.easu_lp_v_frozen_product.customer is 'Потребитель | Потребитель | stg."EASU_LP_V_FROZEN_PRODUCT".customer';
comment on column ods.easu_lp_v_frozen_product.nettofrozen is 'Общий вес зависшей продукции | Общий вес зависшей продукции | stg."EASU_LP_V_FROZEN_PRODUCT".nettofrozen';
comment on column ods.easu_lp_v_frozen_product.namefrozentype is 'Причина | Причина | stg."EASU_LP_V_FROZEN_PRODUCT".namefrozentype';
comment on column ods.easu_lp_v_frozen_product.id_frozentype is 'Идентификтор причины | Идентификтор причины | stg."EASU_LP_V_FROZEN_PRODUCT".id_frozentype';
comment on column ods.easu_lp_v_frozen_product.noteplant is 'Комментарий завода | Комментарий завода | stg."EASU_LP_V_FROZEN_PRODUCT".noteplant';
comment on column ods.easu_lp_v_frozen_product.notead is 'Комментарий ДГП АД | Комментарий ДГП АД | stg."EASU_LP_V_FROZEN_PRODUCT".notead';
comment on column ods.easu_lp_v_frozen_product.notedsb is 'Комментарий ДСБ | Комментарий ДСБ | stg."EASU_LP_V_FROZEN_PRODUCT".notedsb';
comment on column ods.easu_lp_v_frozen_product.notedtil is 'Комментрий ДТиЛ | Комментрий ДТиЛ | stg."EASU_LP_V_FROZEN_PRODUCT".notedtil';
comment on column ods.easu_lp_v_frozen_product.netto_ad is 'Вес АД | Вес АД | stg."EASU_LP_V_FROZEN_PRODUCT".netto_ad';
comment on column ods.easu_lp_v_frozen_product.netto_dsb is 'Вес ДСБ | Вес ДСБ | stg."EASU_LP_V_FROZEN_PRODUCT".netto_dsb';
comment on column ods.easu_lp_v_frozen_product.netto_drvr is 'Вес ДРВР | Вес ДРВР | stg."EASU_LP_V_FROZEN_PRODUCT".netto_drvr';
comment on column ods.easu_lp_v_frozen_product.netto_dd is 'Вес ДД | Вес ДД | stg."EASU_LP_V_FROZEN_PRODUCT".netto_dd';
comment on column ods.easu_lp_v_frozen_product.netto_dtil is 'вес ДТиЛ | вес ДТиЛ | stg."EASU_LP_V_FROZEN_PRODUCT".netto_dtil';
comment on column ods.easu_lp_v_frozen_product.id_place is 'ID склада | ID склада | stg."EASU_LP_V_FROZEN_PRODUCT".id_place';
comment on column ods.easu_lp_v_frozen_product.sgp is 'Склад | Склад | stg."EASU_LP_V_FROZEN_PRODUCT".sgp';
comment on column ods.easu_lp_v_frozen_product.smelter is 'Завод | Завод | stg."EASU_LP_V_FROZEN_PRODUCT".smelter';
comment on column ods.easu_lp_v_frozen_product.namefrozenresponsible is 'Зона ответственности | Зона ответственности | stg."EASU_LP_V_FROZEN_PRODUCT".smelter';