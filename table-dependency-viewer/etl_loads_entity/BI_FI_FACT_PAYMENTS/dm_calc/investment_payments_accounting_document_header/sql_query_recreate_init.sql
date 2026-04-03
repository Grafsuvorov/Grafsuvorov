drop table if exists dm_calc.investment_payments_accounting_document_header ;
CREATE TABLE dm_calc.investment_payments_accounting_document_header  (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	dt_posting date NOT NULL,
	reverse_document_code varchar(10) NULL,
	reverse_document_fiscal_year numeric(4) NULL,
	dt_posting_reverse_document  date  NULL,
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
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code);


comment on table dm_calc.investment_payments_accounting_document_header is 'Заголовок документа для бухгалтерии_для Факта платежей БИЗ';
comment on column dm_calc.investment_payments_accounting_document_header.unit_balance_code is 'Балансовая единица | Балансовая единица | dds.accounting_documents';
comment on column dm_calc.investment_payments_accounting_document_header.fiscal_year is 'Финансовый год | Финансовый год | dds.accounting_documents';
comment on column dm_calc.investment_payments_accounting_document_header.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | dds.accounting_documents';
comment on column dm_calc.investment_payments_accounting_document_header.dt_posting is 'Дата проводки в документе | Дата проводки в документе | dds.accounting_documents';
comment on column dm_calc.investment_payments_accounting_document_header.reverse_document_code is '№ документа сторно | № документа сторно | dds.accounting_documents';
comment on column dm_calc.investment_payments_accounting_document_header.reverse_document_fiscal_year is 'Финансовый год документа сторно | Финансовый год документа сторно | dds.accounting_documents';
comment on column dm_calc.investment_payments_accounting_document_header.dt_posting_reverse_document is 'Дата проводки сторно в документе | Дата проводки сторно в документе | dds.accounting_documents';