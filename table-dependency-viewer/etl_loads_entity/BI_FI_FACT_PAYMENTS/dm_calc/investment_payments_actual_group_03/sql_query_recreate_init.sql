drop table if exists dm_calc.investment_payments_actual_group_03;

create table dm_calc.investment_payments_actual_group_03 (
		expense_or_payment_source_type_code varchar(10) not null,
		accounting_document_unit_balance_code varchar(4) not null,
		accounting_document_fiscal_year numeric(4,0) not null,
		accounting_document_code varchar(10) not null,
		accounting_document_position_code numeric(3,0) not null,
		accounting_document_type_code varchar(2) null,
		payment_document_unit_balance_code varchar(4) null,
		payment_document_fiscal_year numeric(4,0)  null,
		payment_document_code varchar(10) null,
		dt_posting date not null,
		payment_request_position_code varchar(5) null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		reservation_document_code varchar(10) null,
		reservation_document_position_code varchar(3) null,
		reservation_document_reference_code varchar(16) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		external_contract_number varchar(60) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		controlling_order_code varchar(12) null,
		vat_code varchar(2) null,
		vat_rate numeric(4,2) default 0,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,
		vat_payment_document_currency_amount numeric(20,2) default 0,
		exclude_vat_payment_document_currency_amount numeric(20,2) default 0,		
		capitalization_code varchar(6) null,
		reverse_document_code varchar(10) null,
		reverse_document_fiscal_year numeric(4) null,
		dt_posting_reverse_document date null,
		plant_code varchar(4) null,
		is_agent_payment bool null,
		dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	    dttm_updated	timestamp	NOT NULL DEFAULT now(),
	    job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,	
	    deleted_flag	bool	NOT NULL DEFAULT false	
		)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=3
)
distributed by (accounting_document_unit_balance_code, accounting_document_fiscal_year, accounting_document_code, accounting_document_position_code);


comment on table dm_calc.investment_payments_actual_group_03 is 'ГТД и НДС по ГТД, учитываемые как платежи, для факта платежей БИЗ ERP';
comment on column dm_calc.investment_payments_actual_group_03.expense_or_payment_source_type_code is 'Тип затрат/платежей | Тип затрат/платежей | settings_and_parameters_sap.parameter_code';
comment on column dm_calc.investment_payments_actual_group_03.accounting_document_unit_balance_code is 'Балансовая единица | Балансовая единица | accounting_documents.unit_balance_code';
comment on column dm_calc.investment_payments_actual_group_03.accounting_document_fiscal_year is 'Финансовый год | Финансовый год бухдокумента | accounting_documents.fiscal_year';
comment on column dm_calc.investment_payments_actual_group_03.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | accounting_documents.accounting_document_code';
comment on column dm_calc.investment_payments_actual_group_03.accounting_document_position_code is 'Код позиции | Код позиции бухдокумента | accounting_documents.position_line_item_code';
comment on column dm_calc.investment_payments_actual_group_03.accounting_document_type_code is 'Вид документа | Вид бухдокумента | accounting_documents.accounting_document_type';
comment on column dm_calc.investment_payments_actual_group_03.payment_document_unit_balance_code is 'БЕ документа платежа | БЕ документа платежа | accounting_documents_header.unit_balance_code';
comment on column dm_calc.investment_payments_actual_group_03.payment_document_fiscal_year is 'Год документа платежа | Год документа платежа | accounting_documents_header.fiscal_year';
comment on column dm_calc.investment_payments_actual_group_03.payment_document_code is 'Номер документа платежа | Номер документа платежа | accounting_documents_header.accounting_document_code';
comment on column dm_calc.investment_payments_actual_group_03.dt_posting is 'Дата проводки в документе | Дата проводки бухдокумента | accounting_documents.dt_posting';
comment on column dm_calc.investment_payments_actual_group_03.payment_request_position_code is '№ позиции TAP_MM | № позиции TAP_MM | ';
comment on column dm_calc.investment_payments_actual_group_03.purchase_document_code is 'Номер документа закупки | Номер документа закупки | accounting_documents.purchase_document_code';
comment on column dm_calc.investment_payments_actual_group_03.purchase_document_position_code is 'Позиция документа закупки | Позиция документа закупки | accounting_documents.purchase_document_position_line_item_code';
comment on column dm_calc.investment_payments_actual_group_03.reservation_document_code is '№ резервирования | № резервирования | ';
comment on column dm_calc.investment_payments_actual_group_03.reservation_document_position_code is 'Позиция резервирования | Позиция резервирования | ';
comment on column dm_calc.investment_payments_actual_group_03.reservation_document_reference_code is 'Резервирование затрат | Резервирование затрат | ';
comment on column dm_calc.investment_payments_actual_group_03.cost_element_code is 'Основной счет главной книги, код | Код основного счета главной книги | accounting_documents.general_ledger_account_code';
comment on column dm_calc.investment_payments_actual_group_03.correspondence_general_ledger_account_code is 'Корреспондирующий счет главной книги | Код корреспондирующего счета главной книги | dm_calc.account_turnover.correspondence_general_ledger_account_code';
comment on column dm_calc.investment_payments_actual_group_03.material_code is 'Номер материала | Номер материала | accounting_documents.material_code';
comment on column dm_calc.investment_payments_actual_group_03.creditor_code is 'Номер счета поставщика или кредитора | Номер поставщика или кредитора | accounting_documents.supplier_code';
comment on column dm_calc.investment_payments_actual_group_03.contract_code is 'Номер договора | Договор, в рамках которого возникла задолженность (номер) | ';
comment on column dm_calc.investment_payments_actual_group_03.external_contract_number is 'Номер контракта на закупку у поставщика | Номер контракта на закупку у поставщика | purchase_contract_position.external_contract_number';
comment on column dm_calc.investment_payments_actual_group_03.wbs_element_internal_code is 'ID элемента структурного плана проекта (СПП) | ID элемента структурного плана проекта (СПП) | ';
comment on column dm_calc.investment_payments_actual_group_03.wbs_element_external_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | wbs_element_master_data_detail.wbs_element_number';
comment on column dm_calc.investment_payments_actual_group_03.investment_project_internal_code is 'Проект внутренний (код) | Проект внутренний (код) | wbs_element_master_data_detail.investment_project_code';
comment on column dm_calc.investment_payments_actual_group_03.controlling_order_code is 'Проект внешний (код) | Проект внешний (код) | investment_project.wbs_element_number';
comment on column dm_calc.investment_payments_actual_group_03.vat_code is 'Код налога с оборота | Код НДС | accounting_documents.tax_code';
comment on column dm_calc.investment_payments_actual_group_03.vat_rate is 'Ставка НДС | Ставка НДС | ';
comment on column dm_calc.investment_payments_actual_group_03.document_currency_amount is 'Сумма в валюте документа | Сумма в валюте документа | accounting_documents.document_currency_amount';
comment on column dm_calc.investment_payments_actual_group_03.document_currency_code is 'Код внутренней валюты | Код внутренней валюты | accounting_documents.local_currency_code';
comment on column dm_calc.investment_payments_actual_group_03.vat_payment_document_currency_amount is 'Сумма НДС платежа в ВД | Сумма НДС платежа в ВД | ';
comment on column dm_calc.investment_payments_actual_group_03.exclude_vat_payment_document_currency_amount is 'Сумма платежа без НДС в ВД | Сумма платежа без НДС в ВД | ';
comment on column dm_calc.investment_payments_actual_group_03.capitalization_code is 'Оприходование (код) | Оприходование (код) | wbs_element_master_data_detail.posting_reason_code';
comment on column dm_calc.investment_payments_actual_group_03.reverse_document_code is 'Документ сторно платежа № | Документ сторно платежа № | ';
comment on column dm_calc.investment_payments_actual_group_03.reverse_document_fiscal_year is 'Документ сторно платежа год | Документ сторно платежа год | ';
comment on column dm_calc.investment_payments_actual_group_03.dt_posting_reverse_document is 'Дата проводки сторно платежа | Дата проводки сторно платежа | ';
comment on column dm_calc.investment_payments_actual_group_03.plant_code is 'Завод | Код филиала, к которому относится задолженность | accounting_documents.plant_code';
comment on column dm_calc.investment_payments_actual_group_03.is_agent_payment is 'Агентский платёж | Агентский платёж |  ';