drop table if exists dds.advance_payment_requirements_by_purchase_orders;

CREATE TABLE dds.advance_payment_requirements_by_purchase_orders (
	unit_balance_code	varchar(4),
	fiscal_year	varchar(4),
	accounting_document_code	varchar(10),
	accounting_document_position_line_item_code	varchar(3),
	purchase_document_position_reference_line_item_code	varchar(5),
	accounting_document_type_code	varchar(2),
	purchase_document_code	varchar(10),
	purchase_document_position_line_item_code	varchar(5),
	document_currency_amount	numeric(17, 2),
	document_currency_without_vat_amount	numeric(17, 2),
	document_currency_vat_amount	numeric(17, 2),
	document_currency_code	varchar(5),
	wbs_element_code	varchar(8),
	specification_currency_amount numeric(17, 2),
	specification_currency_vat_amount	numeric(17, 2),
	specification_currency_code	varchar(5),
	dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	dttm_updated	timestamp	NOT NULL DEFAULT now(),
	job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,	
	deleted_flag	bool	NOT NULL DEFAULT false
)
WITH (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED by (unit_balance_code, fiscal_year, accounting_document_code,accounting_document_position_line_item_code);

----------------------------------------------------------------------------------------------------------------COMMENT
comment on table 	dds.advance_payment_requirements_by_purchase_orders is 'Сформированные ТАП по заказам ММ';
comment on column dds.advance_payment_requirements_by_purchase_orders.unit_balance_code is 'Балансовая единица | Балансовая единица | BUKRS';
comment on column dds.advance_payment_requirements_by_purchase_orders.fiscal_year is 'Финансовый год | Финансовый год | GJAHR';
comment on column dds.advance_payment_requirements_by_purchase_orders.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | BELNR';
comment on column dds.advance_payment_requirements_by_purchase_orders.accounting_document_position_line_item_code is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа | BUZEI';
comment on column dds.advance_payment_requirements_by_purchase_orders.purchase_document_position_reference_line_item_code is 'Порядковый номер ссылочной строки отдельной позиции документа закупки | Порядковый номер ссылочной строки отдельной позиции документа закупки | POS';
comment on column dds.advance_payment_requirements_by_purchase_orders.accounting_document_type_code is 'Вид документа | Вид документа | BLART';
comment on column dds.advance_payment_requirements_by_purchase_orders.purchase_document_code is 'Номер документа закупки | Номер документа закупки | EBELN';
comment on column dds.advance_payment_requirements_by_purchase_orders.purchase_document_position_line_item_code is 'Номер позиции документа закупки | Номер позиции документа закупки | EBELP';
comment on column dds.advance_payment_requirements_by_purchase_orders.document_currency_amount is 'Стоимость в валюте документа | Стоимость в валюте документа | WRBTR';
comment on column dds.advance_payment_requirements_by_purchase_orders.document_currency_without_vat_amount is 'Стоимость нетто в валюте документа | Стоимость нетто в валюте документа | NETWR';
comment on column dds.advance_payment_requirements_by_purchase_orders.document_currency_vat_amount is 'НДС в валюте документа | НДС в валюте документа | WMWST';
comment on column dds.advance_payment_requirements_by_purchase_orders.wbs_element_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | PROJK';
comment on column dds.advance_payment_requirements_by_purchase_orders.document_currency_code is 'Код валюты документа| Код валюты документа| WAERS';
comment on column dds.advance_payment_requirements_by_purchase_orders.specification_currency_amount is 'Стоимость в валюте спецификации | Стоимость в валюте спецификации | WRBTR_EB';
comment on column dds.advance_payment_requirements_by_purchase_orders.specification_currency_vat_amount is 'НДС в валюте спецификации | НДС в валюте спецификации | WMWST_EB';
comment on column dds.advance_payment_requirements_by_purchase_orders.specification_currency_code is 'Код валюты | Код валюты спецификации | WAERS_EB';