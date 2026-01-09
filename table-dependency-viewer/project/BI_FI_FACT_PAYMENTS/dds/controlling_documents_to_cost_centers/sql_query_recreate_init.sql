create table dds.controlling_documents_to_cost_centers (
	controlling_area_code										varchar(4),
	controlling_document_code									varchar(10),
	controlling_document_position_code							varchar(3),
	unit_balance_code											varchar(4),
	dt_posting													date,
	reference_document_code										varchar(10),
	reference_document_unit_balance_code						varchar(4),
	reference_document_fiscal_year								varchar(4),
	reference_operation_type_code								varchar(5),
	document_currency_amount									numeric(17,2),
	local_currency_amount			 							numeric(17,2),
	second_local_currency_amount			 					numeric(17,2),
	cost_center_code											varchar(22),
	cost_element_code											varchar(10),
	document_currency_code										varchar(5),
	local_currency_code										    varchar(5),
	second_local_currency_code									varchar(5),
	general_ledger_account_code									varchar(10),
	material_code												varchar(18),
	purchase_document_code										varchar(10),
	purchase_document_position_code								varchar(5),
	accounting_document_position_code							varchar(3),
	value_type_code												varchar(2),
	is_active bool NULL,
	is_deleted bool NULL,
	dttm_from timestamp NULL,
	dttm_to timestamp NULL,
	sap_pointer varchar(24) NULL,
	dttm_inserted 	timestamp not null default now(),
	dttm_updated  	timestamp not null default now(),
	job_name 		varchar(60) not null default 'airflow'::character varying,
	deleted_flag	bool not null default false
)
WITH (
	appendonly=true,
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (controlling_area_code, controlling_document_code, controlling_document_position_code);

----------------------------------------------------------------------------

comment on table dds.controlling_documents_to_cost_centers is 'Контроллинговые документы: МВЗ';
comment on column dds.controlling_documents_to_cost_centers.controlling_area_code is 'Контроллинговая единица | Контроллинговая единица | ods.controlling_documents_to_cost_centers.controlling_area_code';
comment on column dds.controlling_documents_to_cost_centers.controlling_document_code is 'Номер документа | Номер документа | ods.controlling_documents_to_cost_centers.controlling_document_code';
comment on column dds.controlling_documents_to_cost_centers.unit_balance_code is 'Балансовая единица | Балансовая единица | ods.controlling_documents_to_cost_centers.unit_balance_code';
comment on column dds.controlling_documents_to_cost_centers.controlling_document_position_code is 'Строка проводки | Строка проводки | ods.controlling_documents_to_cost_centers.controlling_document_position_line_item_code';
comment on column dds.controlling_documents_to_cost_centers.dt_posting is 'Дата проводки | Дата проводки | ods.controlling_documents_to_cost_centers.dt_posting';
comment on column dds.controlling_documents_to_cost_centers.reference_document_code is 'Номер ссылочного документа | Номер ссылочного документа | ods.controlling_documents_to_cost_centers.reference_document_code';
comment on column dds.controlling_documents_to_cost_centers.reference_document_unit_balance_code is 'БЕ документа FI | БЕ документа FI | ods.controlling_documents_to_cost_centers.reference_document_unit_balance_code';
comment on column dds.controlling_documents_to_cost_centers.reference_document_fiscal_year is 'Финансовый год ссылочного документа | Финансовый год ссылочного документа | ods.controlling_documents_to_cost_centers.reference_document_fiscal_year';
comment on column dds.controlling_documents_to_cost_centers.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | ods.controlling_documents_to_cost_centers.reference_operation_type_code';
comment on column dds.controlling_documents_to_cost_centers.document_currency_amount is 'Сумма в валюте документа |Сумма в валюте документа | ods.controlling_documents_to_cost_centers.document_currency_amount';
comment on column dds.controlling_documents_to_cost_centers.local_currency_amount is 'Сумма в ВВ | Сумма в ВВ | ods.controlling_documents_to_cost_centers.local_currency_amount';
comment on column dds.controlling_documents_to_cost_centers.second_local_currency_amount is 'Сумма в ВВ2 | Сумма в ВВ2 | ods.controlling_documents_to_cost_center.second_local_currency_amount';
comment on column dds.controlling_documents_to_cost_centers.cost_center_code is 'Номер заказа | Номер заказа | ods.controlling_documents_to_cost_centers.cost_center_code';
comment on column dds.controlling_documents_to_cost_centers.cost_element_code is 'Вид затрат | Вид затрат | ods.controlling_documents_to_cost_centers.cost_element_code';
comment on column dds.controlling_documents_to_cost_centers.document_currency_code is 'Валюта документа | Валюта докуента | ods.controlling_documents_to_cost_centers.document_currency_code';
comment on column dds.controlling_documents_to_cost_centers.local_currency_code is 'Валюта ВВ | Валюта ВВ | ods.controlling_documents_to_cost_centers.local_currency_code';
comment on column dds.controlling_documents_to_cost_centers.second_local_currency_code is 'Валюта ВВ2 | Валюта ВВ2 | ods.controlling_documents_to_cost_centers.second_local_currency_code';
comment on column dds.controlling_documents_to_cost_centers.general_ledger_account_code is 'Номер счета | Номер счета | ods.controlling_documents_to_cost_centers.general_ledger_account_code';
comment on column dds.controlling_documents_to_cost_centers.material_code is 'Номер материала | Номер материала | ods.controlling_documents_to_cost_centers.material_code';
comment on column dds.controlling_documents_to_cost_centers.purchase_document_code is 'Номер документа закупки | Номер документа закупки | ods.controlling_documents_to_cost_centers.purchase_document_code';
comment on column dds.controlling_documents_to_cost_centers.purchase_document_position_code is 'Номер позиции документа закупки | Номер позиции документа закупки | ods.controlling_documents_to_cost_centers.purchase_document_position_line_item_code';
comment on column dds.controlling_documents_to_cost_centers.accounting_document_position_code is 'Строка проводки ссылочного документа FI | Строка проводки ссылочного документа FI | ods.controlling_documents_to_cost_centers.accounting_document_position_line_item_code';
comment on column dds.controlling_documents_to_cost_centers.value_type_code is 'Тип значения | Тип значения | ods.controlling_documents_to_cost_centers.value_type_code';