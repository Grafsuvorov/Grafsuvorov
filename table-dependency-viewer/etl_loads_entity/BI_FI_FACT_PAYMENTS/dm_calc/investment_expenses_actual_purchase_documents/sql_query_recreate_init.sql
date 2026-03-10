drop table if exists dm_calc.investment_expenses_actual_purchase_documents;

CREATE TABLE dm_calc.investment_expenses_actual_purchase_documents
(
	purchase_document_code varchar(10) NOT NULL, 
	position_line_item_code varchar(5) NULL,
	supplier_code varchar(10) NULL,
	number_of_principal_purchase_agreement varchar(10) NULL,
	source_table_name varchar(60) NULL,
	"dttm_inserted" timestamp NOT NULL DEFAULT now(),
	"dttm_updated" timestamp NOT NULL DEFAULT now(),
	"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
 appendonly=true,
 orientation=column,
 compresstype=zstd,
 compresslevel=3
)
DISTRIBUTED by (purchase_document_code,position_line_item_code);

comment on table dm_calc.investment_expenses_actual_purchase_documents IS 'Документы закупки для факта затрат БИЗ';
comment on column dm_calc.investment_expenses_actual_purchase_documents.purchase_document_code is 'Номер документа закупки| Номер документа закупки | EKKO.EBELN';
comment on column dm_calc.investment_expenses_actual_purchase_documents.position_line_item_code is 'Позиция документа закупки | Позиция документа закупки | ekpo_ral.ebelp';
comment on column dm_calc.investment_expenses_actual_purchase_documents.number_of_principal_purchase_agreement is 'Номер основного договора | Номер основного договора | ekpo_ral.konnr';
comment on column dm_calc.investment_expenses_actual_purchase_documents.supplier_code is 'Номер поставщика | Номер поставщика | ekko.lifnr';
comment on column dm_calc.investment_expenses_actual_purchase_documents.source_table_name is 'Имя исходной сущности| Имя исходной сущности | purchase_contract_position/purchase_order_position/purchase_agreement_position';