drop table if exists ods."/rusal/dtl_pdx_h_ral";

create table ods."/rusal/dtl_pdx_h_ral"
(
	"ebeln" varchar(10) not null,
	"name" varchar(255) null,
	"oe" varchar(64) null,
	"url" varchar(255) null,
	"docid" varchar(128) null,
	"docidint" varchar(10) null,
	"pdx_load" varchar(4) null,
	"status" varchar(1) null,
	"paydox_status" varchar(2) null,
	"bedat" date null,
	"bsart_pd" varchar(10) null,
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed by ("ebeln");

comment on table ods."/rusal/dtl_pdx_h_ral" is 'ДТИЛ: Интеграция SAP и PAYDOX. Заголовок';
comment on column ods."/rusal/dtl_pdx_h_ral"."ebeln" 			is 'Номер документа закупки | Номер документа закупки | /RUSAL/DTL_PDX_H.EBELN';
comment on column ods."/rusal/dtl_pdx_h_ral"."name" 			is 'Заголовок документа | Заголовок документа | /RUSAL/DTL_PDX_H.NAME';
comment on column ods."/rusal/dtl_pdx_h_ral"."oe" 				is 'Организационная единица | Организационная единица | /RUSAL/DTL_PDX_H.OE';
comment on column ods."/rusal/dtl_pdx_h_ral"."url" 			is 'Оригинал документа | Оригинал документа | /RUSAL/DTL_PDX_H.URL';
comment on column ods."/rusal/dtl_pdx_h_ral"."docid" 			is 'Регистр.№ спецификации | Регистр.№ спецификации | /RUSAL/DTL_PDX_H.DOCID';
comment on column ods."/rusal/dtl_pdx_h_ral"."docidint" 		is 'Целочисленный идентификатор | Целочисленный идентификатор | /RUSAL/DTL_PDX_H.DOCIDINT';
comment on column ods."/rusal/dtl_pdx_h_ral"."pdx_load" 		is 'Статус (иконка) для интерфейсов MM019M, LE010M | Статус (иконка) для интерфейсов MM019M, LE010M | /RUSAL/DTL_PDX_H.PDX_LOAD';
comment on column ods."/rusal/dtl_pdx_h_ral"."status" 			is 'Статус передачи | Статус передачи | /RUSAL/DTL_PDX_H.STATUS';
comment on column ods."/rusal/dtl_pdx_h_ral"."paydox_status" 	is 'Статус PayDox | Статус PayDox | /RUSAL/DTL_PDX_H.PAYDOX_STATUS';
comment on column ods."/rusal/dtl_pdx_h_ral"."bedat" 			is 'Дата | Дата | /RUSAL/DTL_PDX_H.BEDAT';
comment on column ods."/rusal/dtl_pdx_h_ral"."bsart_pd" 		is 'Вид документа в PayDox | Вид документа в PayDox | /RUSAL/DTL_PDX_H.BSART_PD';