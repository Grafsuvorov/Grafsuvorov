drop table if exists dm_calc.accounting_external_contracts cascade;
create table dm_calc.accounting_external_contracts (
	contract_code varchar(13) null,
	unit_balance_code varchar(4) null,
	external_contract_number varchar(60) null,
	dt_external_contract date null,
	responsibility_center_code varchar(16) null,
	responsibility_center_level1_code varchar(30) null,
	purchase_or_sales_group_code varchar(3) null,
	purchase_or_sales_group_name varchar(20) null,
	contract_registration_number varchar(12) null,
	contract_supervisor_code varchar(8) null,
	contract_subtype_code varchar(4) null,
	contract_type_code varchar(3) null,
	contract_trader_code numeric(8) null,
	external_contract_source_table_name varchar(21) null,
	contract_supervisor_name varchar(120) null,
	contract_trader_name  varchar(120) null,
	paydox_document_url text,
	contract_list_with_paydox_url text,
	deleted_flag bool not null default false,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying
)
with (appendonly=true, orientation=column, compresstype=zstd, compresslevel=3)
distributed by (contract_code, unit_balance_code);

grant select on table dm_calc.accounting_external_contracts to samoshkinvg;
grant select on table dm_calc.accounting_external_contracts to soldatovaae;
grant select on table dm_calc.accounting_external_contracts to gulyaevai;

comment on table dm_calc.accounting_external_contracts is 'Бухгалтерия, Внешний договор';
comment on column dm_calc.accounting_external_contracts.contract_code is 'Номер договора | Номер договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.unit_balance_code is 'Балансовая единица | Балансовая единица | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.external_contract_number is 'Внешний номер договора | Внешний номер договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.dt_external_contract is 'Дата внешнего договора | Дата внешнего договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.purchase_or_sales_group_code is 'Группа закупок/сбыта, Код | Группа закупок/сбыта, Код | Набор 4 таблиц';
comment on column dm_calc.accounting_external_contracts.purchase_or_sales_group_name is 'Группа закупок/сбыта, Наименование | Группа закупок/сбыта, Наименование | sales_group_name_rus или purchase_group_name';
comment on column dm_calc.accounting_external_contracts.contract_registration_number is 'Регистрационный номер договора | Регистрационный номер договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.contract_supervisor_code is 'Табельный номер куратора договора | Табельный номер куратора договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.contract_subtype_code is 'Код вида договора | Код вида договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.contract_type_code is 'Код типа договора | Код типа договора | Разные таблицы';
comment on column dm_calc.accounting_external_contracts.contract_type_code is 'Табельный номер трейдера договора | Табельный номер трейдера договора | dds.sales_document_counterparty_role.counterparty_role_code';
comment on column dm_calc.accounting_external_contracts.external_contract_source_table_name is 'Источник договора | Источник договора | В зависимости от источника';
comment on column dm_calc.accounting_external_contracts.contract_supervisor_name is 'Куратор договора, ФИО | Куратор договора, ФИО | ods.map_zfi_kntr_data_keys.contract_supervisor_name';
comment on column dm_calc.accounting_external_contracts.contract_trader_name is 'ФИО трейдера договора | ФИО трейдера договора | dict_dds.personnel_main_data.employee_full_name';
comment on column dm_calc.accounting_external_contracts.paydox_document_url is 'Ссылка на документ PayDox | Ссылка на документ PayDox | paydox_document_url из таблиц контрактов';
comment on column dm_calc.accounting_external_contracts.contract_list_with_paydox_url is 'Cписок контрактов закупок с ссылками на PAYDOX | Cписок контрактов закупок с ссылками на PAYDOX |  json  на основе external_contract_number и paydox_document_url из таблиц контрактов';

