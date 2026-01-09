drop table if exists dds.material_ledger_header;

create table dds.material_ledger_header (
	calculation_code			varchar(12) not null,
	price_rule_code			varchar(1),
	dt_last_price_determination	timestamp,
	material_code		varchar(18) ,
	valuation_area_code			varchar(4),
	valuation_type_code	 	varchar(10),
	special_stock_valuation_code		varchar(1),
	is_tolling_stock_valuated			varchar(1),
	special_stock_code					varchar(1),
	sales_document_code					varchar(10),
	sales_document_position_code		varchar(6),
	wbs_element_code				varchar(8),
	supplier_code					varchar(10),
	dttm_inserted 					timestamp not null default now(),
	dttm_updated 					timestamp not null default now(),
	job_name 						varchar(60) not null default 'airflow'::character varying,
	deleted_flag 					bool not null default false
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (calculation_code);

--------------------------------------------------------------------------COMMENT
comment on table  dds.material_ledger_header is 'Регистр материалов: заголовок';
comment on column dds.material_ledger_header.calculation_code is 'Номер калькуляции | Номер калькуляции | CKMLHD.KALNR';
comment on column dds.material_ledger_header.price_rule_code is 'Исчисление цен материалов: управление | Исчисление цен материалов: управление | CKMLHD.MLAST';
comment on column dds.material_ledger_header.dt_last_price_determination is 'Дата-время последнего успешного исчисления цен| Дата-время последнего успешного исчисления цен| CKMLHD.ABRECHDAT +CKMLHD.ABRECHUHR ';
comment on column dds.material_ledger_header.material_code is 'Номер материала | Номер материала | CKMLHD.MATNR';
comment on column dds.material_ledger_header.valuation_area_code is 'Область оценки | Область оценки | CKMLHD.BWKEY';
comment on column dds.material_ledger_header.valuation_type_code is 'Вид оценки | Вид оценки| CKMLHD.BWTAR';
comment on column dds.material_ledger_header.special_stock_valuation_code is 'Оценка особого запаса | Оценка особого запаса | CKMLHD.KZBWS';
comment on column dds.material_ledger_header.is_tolling_stock_valuated is 'Раздельно оцененный запас давальческого метериала | Раздельно оцененный запас давальческого метериала | CKMLHD.XOBEW';
comment on column dds.material_ledger_header.special_stock_code is 'Код особого запаса |Код особого запаса | CKMLHD.SOBKZ';
comment on column dds.material_ledger_header.sales_document_code is 'Номер документа сбыта | Номер документа сбыта| CKMLHD.VBELN';
comment on column dds.material_ledger_header.sales_document_position_code is 'Номер позиции документа сбыта | Номер позиции документа сбыта | CKMLHD.POSNR';
comment on column dds.material_ledger_header.wbs_element_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | CKMLHD.PSPNR';
comment on column dds.material_ledger_header.supplier_code is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора| CKMLHD.LIFNR';
