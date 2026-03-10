drop table if exists ods."/rusal/perh_ral";

create table ods."/rusal/perh_ral" (
	werks varchar(4) null,
	id varchar(10) null,
	noms varchar(15) null,
	nomp varchar(40) null,
	bedat date null,
	status_doc varchar(2) null,
	lifnr varchar(10) null,
	zlifnr varchar(10) null,
	lifnr_pr varchar(10) null,
	comments varchar(200) null,
	duedat date null,
	ernam varchar(12) null,
	erdat date null,
	erzet time null,
	aenam varchar(12) null,
	aedat date null,
	aezet time null,
	uved_ernam varchar(12) null,
	type2 varchar(2) null,
	waers varchar(5) null,
	tap_sum numeric(13, 2) null,
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

comment on table ods."/rusal/perh_ral" is 'Перечни ж/д документов (заголовок)';
comment on column ods."/rusal/perh_ral".werks is 'Завод | Завод | STG./RUSAL/PERH.WERKS';
comment on column ods."/rusal/perh_ral".id is 'ID документа | ID документа | STG./RUSAL/PERH.ID';
comment on column ods."/rusal/perh_ral".noms is '№ ЛС | № ЛС | STG./RUSAL/PERH.NOMS';
comment on column ods."/rusal/perh_ral".nomp is 'Номер документа | Номер документа | STG./RUSAL/PERH.NOMP';
comment on column ods."/rusal/perh_ral".bedat is 'Дата документа | Дата документа | STG./RUSAL/PERH.BEDAT';
comment on column ods."/rusal/perh_ral".status_doc is 'Препятствие оплаты | Препятствие оплаты | STG./RUSAL/PERH.STATUS_DOC';
comment on column ods."/rusal/perh_ral".lifnr is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | STG./RUSAL/PERH.LIFNR';
comment on column ods."/rusal/perh_ral".zlifnr is 'Кредитор Агента | Кредитор Агента | STG./RUSAL/PERH.ZLIFNR';
comment on column ods."/rusal/perh_ral".lifnr_pr is 'Перевозчик | Перевозчик | STG./RUSAL/PERH.LIFNR_PR';
comment on column ods."/rusal/perh_ral".comments is 'Комментарий | Комментарий | STG./RUSAL/PERH.COMMENTS';
comment on column ods."/rusal/perh_ral".duedat is 'Дата оплаты | Дата оплаты | STG./RUSAL/PERH.DUEDAT';
comment on column ods."/rusal/perh_ral".ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | STG./RUSAL/PERH.ERNAM';
comment on column ods."/rusal/perh_ral".erdat is 'Дата создания записи | Дата создания записи | STG./RUSAL/PERH.ERDAT';
comment on column ods."/rusal/perh_ral".erzet is 'Время ввода | Время ввода | STG./RUSAL/PERH.ERZET';
comment on column ods."/rusal/perh_ral".aenam is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | STG./RUSAL/PERH.AENAM';
comment on column ods."/rusal/perh_ral".aedat is 'Дата последнего изменения | Время последнего изменения | STG./RUSAL/PERH.AEDAT';
comment on column ods."/rusal/perh_ral".aezet is 'Время последнего изменения | Время последнего изменения | STG./RUSAL/PERH.AEZET';
comment on column ods."/rusal/perh_ral".uved_ernam is 'Куратор договора | Куратор договора | STG./RUSAL/PERH.UVED_ERNAM';
comment on column ods."/rusal/perh_ral".type2 is 'Вид документа | Вид документа | STG./RUSAL/PERH.TYPE2';
comment on column ods."/rusal/perh_ral".waers is 'Код валюты | Код валюты | STG./RUSAL/PERH.WAERS';
comment on column ods."/rusal/perh_ral".tap_sum is 'Сумма авансового ТАП | Сумма авансового ТАП | STG./RUSAL/PERH.TAP_SUM';
