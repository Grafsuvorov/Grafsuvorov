drop table if exists dds.delivery_document_position;

create table dds.delivery_document_position -- PK ключ: delivery_code, delivery_position_line_item_code
(
	delivery_code varchar(10) not null,
	delivery_position_line_item_code varchar(6) not null,
	plant_producer_code varchar(4) null,
	batch_code varchar(10) null,
	warehouse_code varchar(4) null,
	valuation_type_code varchar(10) null,
	sector_code varchar(2) null,
	material_group_code varchar(9) null,
	material_code varchar(18) null,
	sales_document_code varchar(10) null,
	sales_document_position_line_item_code varchar(6) null,
	delivery_position_line_item_type_code varchar(4) null,
	weight_net numeric(15, 3) null,
	weight_gross numeric(15, 3) null,
	quantity numeric(13, 3) null,
	quantity_uom_code varchar(3) null,
	weight_uom_code varchar(3) null,
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
distributed by (delivery_code);

comment on table dds.delivery_document_position                                         is 'Сбытовые документы, позиции';
comment on column dds.delivery_document_position.delivery_code                    		is 'Поставка завода производителя (код) | Поставка завода производителя, по которой формируется цепочка продаж на заводе производителе | lips_ral.vbeln';
comment on column dds.delivery_document_position.delivery_position_line_item_code 		is 'Позиция поставки завода производителя | Позиция поставки завода производителя, по которой формируется цепочка продаж на заводе производителе | lips_ral.posnr';
comment on column dds.delivery_document_position.plant_producer_code              		is 'Завод производитель (код) | Завод производитель (код) | lips_ral.werks';
comment on column dds.delivery_document_position.batch_code                      	    is 'Номер партии | Номер партии | lips_ral.charg';
comment on column dds.delivery_document_position.warehouse_code                   		is 'Склад | Склад | lips_ral.lgort';
comment on column dds.delivery_document_position.valuation_type_code              		is 'Вид оценки | Вид оценки | lips_ral.bwtar';
comment on column dds.delivery_document_position.sector_code                            is 'Сектор - группа материалов (код) | Сектор - группа материалов (код) | lips_ral.spart' ;
comment on column dds.delivery_document_position.material_group_code                    is 'Группа материалов (код) | Группа материалов (код) | lips_ral.matkl';
comment on column dds.delivery_document_position.material_code                          is 'Материал (код) | Материал (код) | lips_ral.matnr';
comment on column dds.delivery_document_position.sales_document_code                    is 'Торговый документ (код) | Торговый документ (код) | lips_ral.vgbel';
comment on column dds.delivery_document_position.sales_document_position_line_item_code is 'Торговый документ, позиция | Торговый документ, позиция (VBAP) | lips_ral.vgpos';
comment on column dds.delivery_document_position.delivery_position_line_item_type_code  is 'Тип позиции поставки | Тип позиции поставки | lips_ral.pstyv';
comment on column dds.delivery_document_position.weight_net  							is 'Вес нетто | Вес нетто | lips_ral.ntgew';
comment on column dds.delivery_document_position.weight_gross  							is 'Вес брутто | Вес брутто | lips_ral.brgew';
comment on column dds.delivery_document_position.quantity  								is 'Количество | Количество | lips_ral.lfimg';
comment on column dds.delivery_document_position.quantity_uom_code  					is 'Единица измерения для количества | Единица измерения для количества | lips_ral.meins';
comment on column dds.delivery_document_position.weight_uom_code  						is 'Единица измерения для весов нетто и брутто | Единица измерения для весов нетто и брутто | lips_ral.gewei';
