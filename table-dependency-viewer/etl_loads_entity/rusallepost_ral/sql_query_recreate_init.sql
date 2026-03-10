drop table if exists ods."/rusal/lepost_ral";

create table if not exists ods."/rusal/lepost_ral" (
	id varchar(10) null,
	pos varchar(6) null,
	type_load varchar(2) null,
	numvag varchar(20) null,
	numnakl varchar(35) null,
	zdkodstfr varchar(10) null,
	dateot date null,
	netto numeric(13, 3) null,
	datew date null,
	zdkodstto varchar(10) null,
	dryweight numeric(13, 3) null,
	lifnr_pr varchar(10) null,
	lifnr varchar(10) null,
	ebeln varchar(10) null,
	ebelp varchar(5) null,
	werks varchar(4) null,
	matnr varchar(18) null,
	erdat date null,
	erzet time null,
	ernam varchar(12) null,
	aedat date null,
	aezet time null,
	aenam varchar(12) null,
	check_cont varchar(1) null,
	r_vagn varchar null,
	r_numnakl varchar null,
	r_vagn2 varchar null,
	vagon varchar null,
	nakladn varchar null,
	dataskl varchar(24) null,
	weight_rf numeric(13, 3) null,
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
distributed by ("numvag", "numnakl");

comment on table ods."/rusal/lepost_ral" is 'LE1158M: Отгрузка сырья';
comment on column ods."/rusal/lepost_ral".id is 'ID загрузки | ID загрузки | /RUSAL/LEPOST.ID';
comment on column ods."/rusal/lepost_ral".pos is 'Позиция загрузки | Позиция загрузки | /RUSAL/LEPOST.POS';
comment on column ods."/rusal/lepost_ral".type_load is 'Тип загрузки | Тип загрузки | /RUSAL/LEPOST.TYPE_LOAD';
comment on column ods."/rusal/lepost_ral".numvag is 'Ид. транспортировки | Ид. транспортировки | /RUSAL/LEPOST.NUMVAG';
comment on column ods."/rusal/lepost_ral".numnakl is 'Транспортная накладная | Транспортная накладная | /RUSAL/LEPOST.NUMNAKL';
comment on column ods."/rusal/lepost_ral".zdkodstfr is 'Код станции отгрузки по ЖД классификатору | Код станции отгрузки по ЖД классификатору | /RUSAL/LEPOST.ZDKODSTFR';
comment on column ods."/rusal/lepost_ral".dateot is 'Дата отгрузки по ж/д накладной | Дата отгрузки по ж/д накладной | /RUSAL/LEPOST.DATEOT';
comment on column ods."/rusal/lepost_ral".netto is 'Вес по ж/д накладной, кг | Вес по ж/д накладной, кг | /RUSAL/LEPOST.NETTO';
comment on column ods."/rusal/lepost_ral".datew is 'Дата прибытия завода | Дата прибытия завода | /RUSAL/LEPOST.DATEW';
comment on column ods."/rusal/lepost_ral".zdkodstto is 'Код станции прибытия по ЖД классификатору | Код станции прибытия по ЖД классификатору | /RUSAL/LEPOST.ZDKODSTTO';
comment on column ods."/rusal/lepost_ral".dryweight is 'Сухой вес | Сухой вес | /RUSAL/LEPOST.DRYWEIGHT';
comment on column ods."/rusal/lepost_ral".lifnr_pr is 'Производитель | Производитель | /RUSAL/LEPOST.LIFNR_PR';
comment on column ods."/rusal/lepost_ral".lifnr is 'Поставщик | Поставщик | /RUSAL/LEPOST.LIFNR';
comment on column ods."/rusal/lepost_ral".ebeln is 'Номер документа закупки | Номер документа закупки | /RUSAL/LEPOST.EBELN';
comment on column ods."/rusal/lepost_ral".ebelp is 'Номер позиции документа закупки | Номер позиции документа закупки | /RUSAL/LEPOST.EBELP';
comment on column ods."/rusal/lepost_ral".ebelp is 'Завод | Завод | /RUSAL/LEPOST.WERKS';
comment on column ods."/rusal/lepost_ral".matnr is 'Номер материала | Номер материала | /RUSAL/LEPOST.MATNR';
comment on column ods."/rusal/lepost_ral".erdat is 'Дата создания записи | Дата создания записи | /RUSAL/LEPOST.ERDAT';
comment on column ods."/rusal/lepost_ral".erzet is 'Время ввода | Время ввода | /RUSAL/LEPOST.ERZET';
comment on column ods."/rusal/lepost_ral".ernam is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | /RUSAL/LEPOST.ERNAM';
comment on column ods."/rusal/lepost_ral".aedat is 'Дата последнего изменения | Дата последнего изменения | /RUSAL/LEPOST.AEDAT';
comment on column ods."/rusal/lepost_ral".aezet is 'Время последнего изменения | Время последнего изменения | /RUSAL/LEPOST.AEZET';
comment on column ods."/rusal/lepost_ral".aenam is 'Имя исполнителя, изменившего объект | Имя исполнителя, изменившего объект | /RUSAL/LEPOST.AENAM';
comment on column ods."/rusal/lepost_ral".check_cont is 'Признак контейнера | Признак контейнера | /RUSAL/LEPOST.CHECK_CONT';
comment on column ods."/rusal/lepost_ral".r_numnakl is 'Транспортная накладная РФ | Транспортная накладная РФ | /RUSAL/LEPOST.R_NUMNAKL';
comment on column ods."/rusal/lepost_ral".r_vagn is 'Номер вагона РФ | Номер вагона РФ | /RUSAL/LEPOST.R_VAGN';
comment on column ods."/rusal/lepost_ral".r_numnakl is 'Номер жд накладной РФ | Номер жд накладной РФ | /RUSAL/LEPOST.R_NUMNAKL';
comment on column ods."/rusal/lepost_ral".r_vagn2 is 'Номер вагона РФ 2 | Номер вагона РФ 2 | /RUSAL/LEPOST.R_VAGN2';
comment on column ods."/rusal/lepost_ral".vagon is 'Номер вагона | Номер вагона | /RUSAL/LEPOST.VAGON';
comment on column ods."/rusal/lepost_ral".nakladn is 'Номер жд накладной | Номер жд накладной | /RUSAL/LEPOST.NAKLADN';
comment on column ods."/rusal/lepost_ral".dataskl is 'Дата прихода сырья на склад | Дата прихода сырья на склад | /RUSAL/LEPOST.DATASKL';
comment on column ods."/rusal/lepost_ral".weight_rf is 'Вес вагона РФ | Вес вагона РФ | /RUSAL/LEPOST.WEIGHT_RF';
