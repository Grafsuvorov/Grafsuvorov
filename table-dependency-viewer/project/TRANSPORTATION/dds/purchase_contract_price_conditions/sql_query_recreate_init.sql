drop table if exists dds.purchase_contract_price_conditions;

create table dds.purchase_contract_price_conditions
(
	purchase_contract_code varchar(10) null,
	purchase_contract_position_code varchar(5) null,
	price_condition_type_code varchar(4) null,
	dt_price_condition_valid_to date null,
	price_scale_basis_code varchar(1) null,
	price_scale_basis_consecutive_code varchar(4) null,
	dt_price_condition_valid_from date null,
	price_condition_code varchar(10) null,
	price_condition_position_code varchar(2) null,
	is_price_condition_position_deleted_code varchar(1) null,	
	price_condition_uom_code varchar(3) null,
	price_rate numeric(11, 2) null,
	price_scale_rate numeric(11, 2) null,
	price_scale_limit_from_quantity numeric(15, 3) null,
	price_scale_limit_to_quantity numeric(15, 3) null,
	price_condition_type_name_rus varchar(50) null,
	price_scale_basis_name_rus varchar(50) null,
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
distributed by (
	purchase_contract_code, 
	purchase_contract_position_code
);

comment on table dds.purchase_contract_price_conditions is 'Ценовые условия контракта на закупку';
comment on column dds.purchase_contract_price_conditions.purchase_contract_code is 'Контракт на закупку (код) | Контракт на закупку (код) | ods.ekpo_ral.ebeln';
comment on column dds.purchase_contract_price_conditions.purchase_contract_position_code is 'Позиция контракта на закупку (код) | Позиция контракта на закупку (код) | ods.ekpo_ral.ebelp';
comment on column dds.purchase_contract_price_conditions.price_condition_type_code is 'Вид ценового условия (код) | Вид ценового условия (код) | ods.a016_ral.kschl';
comment on column dds.purchase_contract_price_conditions.dt_price_condition_valid_to is 'Конец срока действия ценового условия | Конец срока действия ценового условия | ods.a016_ral.datbi';
comment on column dds.purchase_contract_price_conditions.price_scale_basis_code is 'Базис шкалы ценового условия (код) | Базис шкалы ценового условия (код) | ods.konp_ral.kzbzg';
comment on column dds.purchase_contract_price_conditions.price_scale_basis_consecutive_code is 'Позиция в шкале ценового условия (код) | Позиция в шкале ценового условия (код) | ods.konm_ral.klfn1';
comment on column dds.purchase_contract_price_conditions.dt_price_condition_valid_from is 'Начало срока действия ценового условия | Начало срока действия ценового условия | ods.a016_ral.datab';
comment on column dds.purchase_contract_price_conditions.price_condition_code is 'Номер ценового условия (код) | Номер ценового условия (код) | ods.konp_ral.knumh';
comment on column dds.purchase_contract_price_conditions.price_condition_position_code is 'Позиция ценового условия (код) | Позиция ценового условия (код) | ods.konp_ral.kopos';
comment on column dds.purchase_contract_price_conditions.is_price_condition_position_deleted_code is 'Индикатор удаления позиции ценового условия (код) | Индикатор удаления позиции ценового условия (код) | ods.konp_ral.loevm_ko';
comment on column dds.purchase_contract_price_conditions.price_condition_uom_code is 'Единица измерения ценового условия (код) | Единица измерения ценового условия (код) | ods.konp_ral.kmein';
comment on column dds.purchase_contract_price_conditions.price_rate is 'Цена или процентная ставка условия | Цена или процентная ставка условия | ods.konp_ral.kbetr/ods.konm_ral.kbetr';
comment on column dds.purchase_contract_price_conditions.price_scale_rate is 'Цена или процентная ставка позиции шкалы условия | Цена или процентная ставка позиции шкалы условия | ods.konm_ral.kbetr';
comment on column dds.purchase_contract_price_conditions.price_scale_limit_from_quantity is 'Нижняя граница количества позиции шкалы условия | Нижняя граница количества позиции шкалы условия | ods.konm_ral.kstbm';
comment on column dds.purchase_contract_price_conditions.price_scale_limit_to_quantity is 'Верхняя граница количества позиции шкалы условия | Верхняя граница количества позиции шкалы условия | ods.konm_ral.kstbm';
comment on column dds.purchase_contract_price_conditions.price_condition_type_name_rus is 'Вид ценового условия (наименование) | Вид ценового условия (наименование) | dict_dds.condition_type_texts.condition_type_name';
comment on column dds.purchase_contract_price_conditions.price_scale_basis_name_rus is 'Базис шкалы ценового условия (наименование) | Базис шкалы ценового условия (наименование) | dict_dds.price_scale_basis_texts.price_scale_basis_name';
