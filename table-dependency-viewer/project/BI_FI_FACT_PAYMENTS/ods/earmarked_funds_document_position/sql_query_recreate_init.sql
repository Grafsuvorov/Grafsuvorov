drop table if exists ods.earmarked_funds_document_position;

create table ods.earmarked_funds_document_position (
	earmarked_document_code	varchar(10),
	earmarked_document_position_line_item_code varchar(3),
	order_number_code varchar(12),
	wbs_element_code varchar(8),
	general_ledger_account_code varchar(10),
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
distributed by (earmarked_document_code, earmarked_document_position_line_item_code);

comment on table  ods.earmarked_funds_document_position is 'Позиция документа для выделения финансовых средств';
comment on column ods.earmarked_funds_document_position.earmarked_document_code is 'Номер документа для выделения финансовых средств | Номер документа для выделения финансовых средств | KBLP.BELNR';
comment on column ods.earmarked_funds_document_position.earmarked_document_position_line_item_code is 'Позиция документа: выделение средств | Позиция документа: выделение средств | KBLP.BLPOS';
comment on column ods.earmarked_funds_document_position.order_number_code is 'Номер заказа | Номер заказа | KBLP.AUFNR';
comment on column ods.earmarked_funds_document_position.wbs_element_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | KBLP.PSPNR';
comment on column ods.earmarked_funds_document_position.general_ledger_account_code is 'Номер основного счета | Номер основного счета | KBLP.SAKNR';