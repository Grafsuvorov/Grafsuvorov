drop table if exists dm_calc.accounting_document_header;

CREATE table if not exists dm_calc.accounting_document_header (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	material_for_reporting_code varchar(18) NULL,
	dt_posting date NULL,
    accounting_document_type_code varchar(2) NULL,
    reference_object_key_code varchar(20) NULL,
    dt_accounting_document date NULL,
    dttm_accounting_document_created  timestamp null,
    accounting_document_status_code varchar(1) NULL,
    reference_document_number varchar(16) NULL,
    document_header_reference_internal_key1_number varchar(20) NULL,
    document_header_reference_internal_key2_number varchar(20) NULL,
    reverse_document_code varchar(10) NULL,
	reverse_document_fiscal_year numeric(4) NULL,
	accounting_document_created_by varchar(12) null,
    exchange_rate numeric(9, 5) null, 
    document_currency_code varchar(5) null,
	purchase_order_for_reporting_code varchar(10) NULL,
	purchase_specification_compound_number text,
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
distributed by (unit_balance_code, fiscal_year, accounting_document_code);


comment on table dm_calc.accounting_document_header is 'Заголовки бухгалтерских документов';
comment on column dm_calc.accounting_document_header.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.sap.unit_balance_code';
comment on column dm_calc.accounting_document_header.fiscal_year is 'Финансовый год | Финансовый год | accounting_documents.sap.fiscal_year';
comment on column dm_calc.accounting_document_header.accounting_document_code is 'Номер бухгалтерского документа  | Номер бухгалтерского документа  | accounting_documents.accounting_document_code';
comment on column dm_calc.accounting_document_header.material_for_reporting_code is 'Номер материала, код | Номер материала, код | accounting_documents.material_code';
comment on column dm_calc.accounting_document_header.dt_posting is 'Дата проводки в документе | Дата проводки в документе | accounting_documents.dt_posting';
comment on column dm_calc.accounting_document_header.accounting_document_type_code is 'Вид документа (код) | Вид документа (код) | accounting_documents.accounting_document_type';
comment on column dm_calc.accounting_document_header.reference_object_key_code is 'Ссылочный ключ (код) | Ссылочный ключ (код) | accounting_documents.reference_object_key';
comment on column dm_calc.accounting_document_header.dt_accounting_document is 'Дата документа | Дата документа | accounting_documents.dt_accounting_document';
comment on column dm_calc.accounting_document_header.accounting_document_status_code is 'Статус документа (код) | Статус документа (код) | accounting_documents.accounting_document_status_code';
comment on column dm_calc.accounting_document_header.reference_document_number is 'Ссылочный номер документа (код) | Ссылочный номер документа (код) | accounting_documents.reference_document_number';
comment on column dm_calc.accounting_document_header.document_header_reference_internal_key1_number is 'Внутренний ссылочный ключ 1 к заголовку документа | Внутренний ссылочный ключ 1 к заголовку документа | accounting_documents.reference_key_internal_for_document_header_1';
comment on column dm_calc.accounting_document_header.document_header_reference_internal_key2_number is 'Внутренний ссылочный ключ 2 к заголовку документа | Внутренний ссылочный ключ 2 к заголовку документа | accounting_documents.reference_key_internal_for_document_header_2';
comment on column dm_calc.accounting_document_header.reverse_document_code is '№ документа сторно | № документа сторно | dds.accounting_documents';
comment on column dm_calc.accounting_document_header.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | dds.accounting_documents';
comment on column dm_calc.accounting_document_header.purchase_order_for_reporting_code is 'Номер документа закупки | Номер документа закупки | dds.accounting_documents.purchase_document_code';
comment on column dm_calc.accounting_document_header.purchase_specification_compound_number is 'Региcтрационный номер, присвоенный документу в PayDox | Региcтрационный номер, присвоенный документу в PayDox | dds.purchase_contract_header.coalesce(paydox_registration_number, appendix_number)';
comment on column dm_calc.accounting_document_header.dttm_accounting_document_created is 'Дата-время ввода бухгалтерского документа | Дата-время ввода бухгалтерского документа | dds.accounting_documents.dttm_accounting_document_created';
comment on column dm_calc.accounting_document_header.accounting_document_created_by is 'Имя пользователя | Логин пользователя, создавшего бух.документ | dds.accounting_documents.accounting_document_created_by';
comment on column dm_calc.accounting_document_header.exchange_rate is 'Валютный курс | Валютный курс  | dds.accounting_documents.exchange_rate';
comment on column dm_calc.accounting_document_header.document_currency_code is 'Код валюты документа | Код валюты документа | dds.accounting_documents.document_currency_code';