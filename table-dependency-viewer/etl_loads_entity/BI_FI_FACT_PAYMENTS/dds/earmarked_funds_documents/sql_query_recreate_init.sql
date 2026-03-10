drop table if exists dds.earmarked_funds_documents;

create table dds.earmarked_funds_documents (
	earmarked_document_code varchar(10),
	earmarked_document_position_line_item_code varchar(3),
	reference_document_code	varchar(16),
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
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
distributed by (earmarked_document_code, earmarked_document_position_line_item_code);


comment on table dds.earmarked_funds_documents is 'Документы для выделения финансовых средств';
comment on column dds.earmarked_funds_documents.earmarked_document_code is 'Номер документа для выделения финансовых средств | Номер документа для выделения финансовых средств | ods.earmarked_funds_document_header.earmarked_document_code';
comment on column dds.earmarked_funds_documents.earmarked_document_position_line_item_code is 'Позиция документа: выделение средств | Позиция документа: выделение средств | ods.earmarked_funds_document_position.earmarked_document_position_line_item_code';
comment on column dds.earmarked_funds_documents.reference_document_code is 'Ссылочный номер документа | Ссылочный номер документа | ods.earmarked_funds_document_header.reference_document_code';
comment on column dds.earmarked_funds_documents.order_number_code is 'Номер заказа | Номер заказа | ods.earmarked_funds_document_position.order_number_code';
comment on column dds.earmarked_funds_documents.wbs_element_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | ods.earmarked_funds_document_position.wbs_element_code';
comment on column dds.earmarked_funds_documents.general_ledger_account_code is 'Номер основного счета | Номер основного счета | ods.earmarked_funds_document_position.general_ledger_account_code';