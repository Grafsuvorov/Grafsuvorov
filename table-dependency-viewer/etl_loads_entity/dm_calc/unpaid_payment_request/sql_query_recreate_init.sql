drop table if exists dm_calc.unpaid_payment_request;

create table if not exists  dm_calc.unpaid_payment_request (
	unit_balance_code varchar(4) null,
	fiscal_year numeric(4,0) null,
	invoice_document_code varchar(10) null,
	invoice_document_position_code numeric(3) null,
	unpaid_payment_request_code varchar(10) null,
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
distributed by (unit_balance_code,fiscal_year,invoice_document_code,invoice_document_position_code);

comment on table dm_calc.unpaid_payment_request is 'BSEG-BKPF для быстрого поиска ТАПов по фактурам из актов транспортировки';
comment on column dm_calc.unpaid_payment_request.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | dds.accounting_documents.unit_balance_code';
comment on column dm_calc.unpaid_payment_request.fiscal_year is 'Финансовый год соответствующего счета (при кредитовом авизо) | Финансовый год соответствующего счета (при кредитовом авизо) | dds.accounting_documents.fiscal_year_of_relevant_invoice';
comment on column dm_calc.unpaid_payment_request.invoice_document_code is 'Номер счета-фактуры, к которому относится операция (код) | Номер счета-фактуры, к которому относится операция (код) | dds.accounting_documents.invoice_document_code';
comment on column dm_calc.unpaid_payment_request.invoice_document_position_code is 'Позиция проводки в соответствующем счете | Позиция проводки в соответствующем счете | dds.accounting_documents.position_number_of_relevant_invoice';
comment on column dm_calc.unpaid_payment_request.unpaid_payment_request_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | dds.accounting_documents.accounting_document_code';