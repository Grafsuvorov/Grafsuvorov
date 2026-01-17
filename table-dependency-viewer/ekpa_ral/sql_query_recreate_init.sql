DROP TABLE if exists ods."ekpa_ral";

CREATE  TABLE ods."ekpa_ral" (
	ebeln varchar(10) null,
	ebelp varchar(5) null,
	ekorg varchar(4) null,
	erdat date NULL,
	ernam varchar(12) null,
	lifn2 varchar(10) null,
	parvw varchar(2) null,
	parza varchar(3) null,
	pernr varchar(8) null,
	werks varchar(4) null,
	ltsnr varchar(6) null,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED by (ebeln, ebelp, ekorg, ltsnr, werks, parvw, parza);

comment on table ods.ekpa_ral is 'Роли партнеров в системе закупок';
comment on column ods.ekpa_ral."ebeln" is 'Номер документа закупки | Номер документа закупки | EKPA.EBELN';
comment on column ods.ekpa_ral."ebelp" is 'Номер позиции документа закупки | Номер позиции документа закупки | EKPA.EBELP';
comment on column ods.ekpa_ral."ekorg" is 'Закупочная организация | Закупочная организация | EKPA.EKORG';
comment on column ods.ekpa_ral."erdat" is 'Дата создания записи | Дата создания записи | EKPA.ERDAT';
comment on column ods.ekpa_ral."ernam" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | EKPA.ERNAM';
comment on column ods.ekpa_ral."lifn2" is 'Ссылка на другого поставщика | Ссылка на другого поставщика | EKPA.LIFN2';
comment on column ods.ekpa_ral."ltsnr" is 'Субассортимент поставщика | Субассортимент поставщика | EKPA.LTSNR';
comment on column ods.ekpa_ral."parvw" is 'Роль партнера | Роль партнера | EKPA.PARVW';
comment on column ods.ekpa_ral."parza" is 'Счетчик партнеров | Счетчик партнеров | EKPA.PARZA';
comment on column ods.ekpa_ral."pernr" is 'Табельный номер | Табельный номер | EKPA.PERNR';
comment on column ods.ekpa_ral."werks" is 'Завод | Завод | EKPA.WERKS';