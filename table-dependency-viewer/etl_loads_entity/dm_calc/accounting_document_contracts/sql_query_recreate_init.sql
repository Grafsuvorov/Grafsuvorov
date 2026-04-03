drop table if exists dm_calc.accounting_document_contracts CASCADE;

create table dm_calc.accounting_document_contracts (
	unit_balance_code varchar(4) not null,
	fiscal_year numeric(4) not null,
	accounting_document_code varchar(10) not null,
	accounting_document_position_code numeric(3) null,
	account_type_code varchar(1) null,
	contract_code varchar(13) null,
	contract_subtype_code varchar(4) NULL,
	contract_type_code varchar(3) NULL,
	reference_operation_type_code varchar(5) null,
	external_contract_number varchar(60) null,
	dt_external_contract date null,
	contract_supervisor_code varchar(10) null,
	contract_supervisor_name varchar(120) null,
	purchase_or_sales_group_code varchar(3) null,
	purchase_or_sales_group_name varchar(20) null,
	contract_registration_number varchar(12) NULL,
	responsibility_center_code varchar(16) NULL,
	responsibility_center_level1_code varchar(30) NULL,
	contract_trader_code numeric(8) NULL,
	contract_trader_name  varchar(120) null,
	paydox_document_url text,
	contract_list text,
	contract_list_with_paydox_url text,
	external_contract_source_table_name varchar(30),
	dttm_inserted 				timestamp not null default now(),
	dttm_updated 				timestamp not null default now(),
	job_name 					varchar(60) not null default 'airflow'::character varying,
	deleted_flag				bool not null default false
) with (appendonly=true, orientation=column, compresstype=zstd, compresslevel=3)
distributed by (unit_balance_code, fiscal_year, accounting_document_code, accounting_document_position_code);

comment on table dm_calc.accounting_document_contracts is 'Позиции бухгалтерских документов: атрибуты контрактов';
comment on column dm_calc.accounting_document_contracts.unit_balance_code is 'Балансовая единица | Балансовая единица | dds.accounting_documents.unit_balance_code';
comment on column dm_calc.accounting_document_contracts.fiscal_year is 'Финансовый год | Финансовый год |  dds.accounting_documents.fiscal_year';
comment on column dm_calc.accounting_document_contracts.accounting_document_code is 'Номер бухгалтерского документа | Номер бухгалтерского документа | a dds.accounting_documents.accounting_document_code';
comment on column dm_calc.accounting_document_contracts.accounting_document_position_code is 'Номер строки проводки в рамках бухгалтерского документа | Номер строки проводки в рамках бухгалтерского документа |  dds.accounting_documents.position_line_item';
comment on column dm_calc.accounting_document_contracts.account_type_code is 'Вид счета | Вид счета | a dds.accounting_documents.account_type';
comment on column dm_calc.accounting_document_contracts.contract_code is 'Номер договора | Номер договора |  dds.accounting_documents.contract_number';
comment on column dm_calc.accounting_document_contracts.contract_subtype_code is 'Код вида договора | Код вида договора | dds.purchase_order_header.purchase_document_subtype_code -dds.purchase_contract_header.purchase_document_subtype_code-dds.purchase_agreement_header.purchase_document_subtype_code ';
comment on column dm_calc.accounting_document_contracts.contract_type_code is 'Код типа договора | Код типа договора | dds.sales_contract_header.contract_type_code -dds.purchase_order_header.purchase_document_code -dds.purchase_contract_header.purchase_document_code-dds.purchase_agreement_header.purchase_document_code ';
comment on column dm_calc.accounting_document_contracts.external_contract_number is 'Внешний номер договора | Внешний номер договора |dds.sales_contract_header.sales_order_external_number -dds.purchase_order_header.purchase_contract_external_part1_number -dds.purchase_contract_header.purchase_contract_external_part1_number-dds.purchase_agreement_header.purchase_contract_external_part1_number-dds.financial_loan_terms.alternative_identification_number';
comment on column dm_calc.accounting_document_contracts.dt_external_contract is 'Дата внешнего договора | Дата внешнего договора | dds.sales_contract_header.dt_external_contract -dds.purchase_order_header.dt_external_contract -dds.purchase_contract_header.dt_external_contract-dds.purchase_agreement_header.dt_external_contract-dds.financial_loan_terms.dt_external_contract';
comment on column dm_calc.accounting_document_contracts.contract_supervisor_code is 'Куратор договора, таб № | Куратор договора, таб № | dds.sales_document_counterparty_role.personnel_code -dds.purchase_document_counterparty_role.personnel_code - dict_dds.user_main_data.employee_code';
comment on column dm_calc.accounting_document_contracts.contract_supervisor_name is 'Куратор договора, ФИО | Куратор договора, ФИО | dict_dds.personnel_main_data-employee_full_name';
comment on column dm_calc.accounting_document_contracts.purchase_or_sales_group_code is 'Группа закупок/сбыта, Код | dds.sales_contract_header.sales_team_code-dds.purchase_order_header.purchase_group_code -dds.purchase_contract_header.purchase_group_code - dds.purchase_agreement_header.purchase_group_code';
comment on column dm_calc.accounting_document_contracts.purchase_or_sales_group_name is 'Группа закупок/сбыта, Наименование | dict_dds.sales_group.sales_group_name_rus - dict_dds.purchase_group.purchase_group_name';
comment on column dm_calc.accounting_document_contracts.contract_registration_number is 'Регистрационный номер договора | Регистрационный номер договора | dds.sales_contract_header.sales_contract_registration_number -dds.purchase_order_header.registration_number -dds.purchase_contract_header.purchase_contract_registration_number-dds.purchase_agreement_header.registration_number';
comment on column dm_calc.accounting_document_contracts.responsibility_center_code is 'Центр ответственности (код) | Центр ответственности (код) | dds.sales_contract_header.responsibility_center_code -dds.purchase_order_header.responsibility_center_code -dds.purchase_contract_header.responsibility_center_code-dds.purchase_agreement_header.responsibility_center_code';
comment on column dm_calc.accounting_document_contracts.responsibility_center_level1_code is 'ЦО 1го уровня, код | ЦО 1го уровня, код | map_responsibility_center_to_funds_center.responsibility_center_level1_code - dds.financial_loan_terms.responsibility_center_level1_code ';
comment on column dm_calc.accounting_document_contracts.contract_trader_code is 'Табельный номер трейдера договора | Табельный номер трейдера договора |  dds.sales_document_counterparty_role.personnel_code';
comment on column dm_calc.accounting_document_contracts.contract_trader_name is 'ФИО трейдера договора | ФИО трейдера договора | dict_dds.personnel_main_data-employee_full_name';
comment on column dm_calc.accounting_document_contracts.paydox_document_url is 'Ссылка на оригинал документа в PAYDOX | Ссылка на оригинал документа в PAYDOX |  dds.purchase_order_header.paydox_document_url -dds.purchase_contract_header.paydox_document_url-dds.purchase_agreement_header.paydox_document_url';
comment on column dm_calc.accounting_document_contracts.contract_list is 'Cписок контрактов закупок | Cписок контрактов закупок  | список dm_calc.accounting_document_and_purchase_contract_relation.cr.purchase_contract_code';
comment on column dm_calc.accounting_document_contracts.contract_list_with_paydox_url is 'Cписок контрактов закупок с ссылками на PAYDOX | Cписок контрактов закупок с ссылками на PAYDOX |  json  на основе external_contract_number и paydox_document_url из dm_calc.accounting_external_contracts ';
comment on column dm_calc.accounting_document_contracts.external_contract_source_table_name is 'Таблица-источник контракта | Таблица-источник контракта | алгоритм на основе tmp_accounting_external_contract.external_contract_source_table_name ';
