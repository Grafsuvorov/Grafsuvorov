drop table if exists dm_calc.accounting_documents_header_working_capital;

CREATE TABLE dm_calc.accounting_documents_header_working_capital (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	material_code varchar(18) NULL,
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
DISTRIBUTED by (fiscal_year, accounting_document_code, unit_balance_code);


comment on table dm_calc.accounting_documents_header_working_capital is 'Материалы документов для оборотного капитала';
comment on column dm_calc.accounting_documents_header_working_capital.unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.sap.unit_balance_code';
comment on column dm_calc.accounting_documents_header_working_capital.fiscal_year is 'Финансовый год | Финансовый год | accounting_documents.sap.fiscal_year';
comment on column dm_calc.accounting_documents_header_working_capital.accounting_document_code is 'Номер бухгалтерского документа  | Номер бухгалтерского документа  | accounting_documents.accounting_document_code';
comment on column dm_calc.accounting_documents_header_working_capital.material_code is 'Номер материала, код | Номер материала, код | accounting_documents.material_code';

grant select on table dm_calc.accounting_documents_header_working_capital to soldatovaae;

