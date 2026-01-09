drop table if  exists dm_calc.investment_expenses_invoice_purchase_documents;

create table dm_calc.investment_expenses_invoice_purchase_documents (
    invoice_code varchar(10) NULL,
	invoice_position_line_item_code varchar(6) NULL,
	fiscal_year varchar(4) NULL,
	material_code varchar(18) NULL,
	plant_code varchar(4) NULL,
	reference_document_code varchar(10) NULL,
	reference_document_fiscal_year varchar(4) NULL,
	reference_document_position_line_item_code varchar(4) NULL,
	unit_balance_code varchar(4) NULL,
	valuation_type_code varchar(10) NULL,
	purchase_document_code varchar(10) NULL,
	purchase_document_position_line_item_code varchar(5) NULL,
	purchase_contract_code varchar(13) NULL,
	payee_alternative_code varchar(10) NULL,
	is_additionaly_debited_code varchar(1) NULL,
	"dttm_inserted" timestamp not null default now(),
	"dttm_updated" timestamp not null default now(),
	"job_name" varchar(60) not null default 'airflow'::character varying,
	"deleted_flag" bool not null default false
)
with (
 appendonly = true,
 orientation = column,
 compresstype = zstd,
 compresslevel = 1
)
distributed by (invoice_code,fiscal_year, invoice_position_line_item_code );

comment on table dm_calc.investment_expenses_invoice_purchase_documents is 'Предрасчеты с документами  входящих счетов для факта затрат БИЗ';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.invoice_code is 'Счет-фактура | Счет-фактура | invoice_purchase_document_position.sap.invoice_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.invoice_position_line_item_code is 'Позиция счёт-фактуры | Позиция счёт-фактуры | invoice_purchase_document_position.invoice_position_line_item_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.fiscal_year is 'Финансовый год  | Финансовый год  | invoice_purchase_document_position.fiscal_year';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.material_code is 'Материал (код) | Материал (код) | invoice_purchase_document_position.plant_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.plant_code is 'Завод (код) | Завод (код) | invoice_purchase_document_position.reference_object_key';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.reference_document_code is 'Ссылочный документ | Ссылочный документ | invoice_purchase_document_position.reference_document_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.reference_document_fiscal_year is 'Финансовый год ссылочного документа | Финансовый год ссылочного документа | invoice_purchase_document_position.reference_document_fiscal_year';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.reference_document_position_line_item_code is 'Позиция ссылочного документа | Позиция ссылочного документа | invoice_purchase_document_position.reference_document_position_line_item_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | invoice_purchase_document_position.unit_balance_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.valuation_type_code is 'Вид оценки (код) | Вид оценки (код) | invoice_purchase_document_position.valuation_type_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.purchase_document_code is 'Номер документа закупки (код) | Номер документа закупки (код) | invoice_purchase_document_position.purchase_document_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.purchase_document_position_line_item_code is 'Номер позиции документа закупки (код) | Номер позиции документа закупки (код) | invoice_purchase_document_position.purchase_document_position_line_item_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.purchase_contract_code is 'Контракт на закупку, код | Контракт на закупку, код | invoice_purchase_document_header.purchase_contract_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.payee_alternative_code is 'Альтернативный выставитель счета (код) | Альтернативный выставитель счета (код) | invoice_purchase_document_header.payee_alternative_code';
comment on column dm_calc.investment_expenses_invoice_purchase_documents.is_additionaly_debited_code is 'Индикатор: дополнительное дебетование (код) | Индикатор: дополнительное дебетование (код) | invoice_purchase_document_position.is_additionaly_debited_code';