drop table if exists dm_calc.investment_expenses_actual_documents_header;
CREATE TABLE dm_calc.investment_expenses_actual_documents_header (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	reference_procedure varchar(5) NULL,
	reference_object_key varchar(20) not NULL,
	row_num int,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED by (reference_object_key ,reference_procedure );

comment on table dm_calc.investment_expenses_actual_documents_header is 'Ссылочные документы для факта затрат БИЗ';
comment on column dm_calc.investment_expenses_actual_documents_header.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.sap.unit_balance_code';
comment on column dm_calc.investment_expenses_actual_documents_header.fiscal_year is 'Финансовый год | Финансовый год | accounting_documents.sap.fiscal_year';
comment on column dm_calc.investment_expenses_actual_documents_header.accounting_document_code is 'Номер бухгалтерского документа  | Номер бухгалтерского документа  | accounting_documents.accounting_document_code';
comment on column dm_calc.investment_expenses_actual_documents_header.reference_procedure is 'Ссылочная операция | Ссылочная операция | accounting_documents.reference_procedure';
comment on column dm_calc.investment_expenses_actual_documents_header.reference_object_key is 'Ссылочный ключ | Ссылочный ключ | accounting_documents.reference_object_key';
comment on column dm_calc.investment_expenses_actual_documents_header.row_num is 'Номер строки | Номер строки | row_num';