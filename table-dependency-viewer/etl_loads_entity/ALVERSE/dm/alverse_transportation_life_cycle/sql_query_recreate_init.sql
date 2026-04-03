drop table if exists dm.alverse_transportation_life_cycle cascade;
create table if not exists dm.alverse_transportation_life_cycle (
	initial_delivery_code varchar NULL,
	initial_delivery_item_code varchar NULL,
	sales_order_code varchar NULL,
	expense_account_code varchar null,
	expense_account_name varchar null,
	expense_account_search_name varchar null,
	sales_bundle_gross_weight numeric(13, 3) NULL,
	sales_bundle_net_weight numeric(13, 3) NULL,
	total_expense_per_gross_weight_usd_amount numeric(15, 2) NULL,
	total_expense_per_net_weight_usd_amount numeric(15, 2) NULL,
	plant_producer_search_name varchar NULL,
	transport_type_search_name varchar NULL,
	transport_vehicle_code varchar NULL,
	transport_bill_code varchar NULL,
	transport_bill_and_railcar_uni_code varchar NULL,
	etsng_search_name varchar NULL,
	material_search_name varchar NULL,
	shape_search_name varchar NULL,
	sector_search_name varchar NULL,
	grade_search_name varchar NULL,
	supplier_search_name varchar null,
	transport_subtype_search_name varchar NULL,
	expense_translated_currency_code varchar NULL,
	expense_group_search_name varchar NULL,
	transportation_service_contract_code varchar NULL,
	transportation_scheme_search_name varchar NULL,
	transportation_scheme_type_search_name varchar NULL,
	transportation_scheme_subtype_search_name varchar NULL,
	external_contract_number varchar null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
distributed by (sales_order_code, initial_delivery_code, expense_account_code);

comment on table dm.alverse_transportation_life_cycle is 'Витрина данных для проекта Alverse (вывод всех сведений о перевозке к заказу ЦК)';
comment on column dm.alverse_transportation_life_cycle.initial_delivery_code is 'Номер поставки (код) | Поставка (идентификатор отгрузки в учете)  | alverse_transportation_life_cycle.initial_delivery_code LE.000600';
comment on column dm.alverse_transportation_life_cycle.initial_delivery_item_code is 'Позиция поставки (код) | Позиция поставки (идентификатор отгрузки в учете)  | alverse_transportation_life_cycle.initial_delivery_item_code LE.000601';
comment on column dm.alverse_transportation_life_cycle.sales_order_code is 'Номер заказа (код) | Системный номер заказаЦК в отгрузке | alverse_transportation_life_cycle.sales_order_code LE.000694';
comment on column dm.alverse_transportation_life_cycle.expense_account_code is 'Статья затрат (код) | Статья затрат (код) | alverse_transportation_life_cycle.expense_account_code LE.000740';
comment on column dm.alverse_transportation_life_cycle.expense_account_name is 'Статья затрат (наименование) | Статья затрат (наименование) | alverse_transportation_life_cycle.expense_account_name LE.000741';
comment on column dm.alverse_transportation_life_cycle.expense_account_search_name is 'Статья затрат (связка) | Статья затрат (связка) | alverse_transportation_life_cycle.expense_account_search_name LE.000742';
comment on column dm.alverse_transportation_life_cycle.sales_bundle_gross_weight is 'Вес брутто пакета | Вес брутто пакета | alverse_transportation_life_cycle.sales_bundle_gross_weight LE.000759';
comment on column dm.alverse_transportation_life_cycle.sales_bundle_net_weight is 'Вес нетто пакета | Вес нетто пакета | alverse_transportation_life_cycle.sales_bundle_net_weight LE.000760';
comment on column dm.alverse_transportation_life_cycle.total_expense_per_gross_weight_usd_amount is 'Сумма в USD на вес брутто пакета | Сумма в USD на вес брутто пакета | alverse_transportation_life_cycle.total_expense_per_gross_weight_usd_amount LE.000762';
comment on column dm.alverse_transportation_life_cycle.total_expense_per_net_weight_usd_amount is 'Сумма в USD на вес нетто пакета | Сумма в USD на вес нетто пакета | alverse_transportation_life_cycle.total_expense_per_net_weight_usd_amount LE.000761';
comment on column dm.alverse_transportation_life_cycle.plant_producer_search_name is 'Завод (связка) | Завод производитель, с которого производится физическая отгрузка | alverse_transportation_life_cycle.plant_producer_search_name LE.000604';
comment on column dm.alverse_transportation_life_cycle.transport_type_search_name is 'Тип ПС (связка) | Тип ПС из справочника системы учета (род подвижного состава) | alverse_transportation_life_cycle.transport_type_search_name LE.000610';
comment on column dm.alverse_transportation_life_cycle.transport_vehicle_code is 'Номер ПС (код) | Номер транспортного средства | alverse_transportation_life_cycle.transport_vehicle_code LE.000611';
comment on column dm.alverse_transportation_life_cycle.transport_bill_code is 'Номер накладной (код) | Номер накладной | alverse_transportation_life_cycle.transport_bill_code LE.000612';
comment on column dm.alverse_transportation_life_cycle.transport_bill_and_railcar_uni_code is 'Номер накладной - номер ПС (связка) (код) | Уникальный номер связки (накладная - вагон) | alverse_transportation_life_cycle.transport_bill_and_railcar_uni_code LE.000613';
comment on column dm.alverse_transportation_life_cycle.etsng_search_name is 'Код ЕТСНГ (связка) | Код груза по классификатору РЖД | alverse_transportation_life_cycle.etsng_search_name LE.000633';
comment on column dm.alverse_transportation_life_cycle.material_search_name is 'Материал (связка) | Номер материала | alverse_transportation_life_cycle.material_search_name LE.000637';
comment on column dm.alverse_transportation_life_cycle.shape_search_name is 'Форма (связка) | Форма материала | alverse_transportation_life_cycle.shape_search_name LE.000641';
comment on column dm.alverse_transportation_life_cycle.sector_search_name is 'Сектор материала (связка) | Группировка продукции | alverse_transportation_life_cycle.sector_search_name LE.000644';
comment on column dm.alverse_transportation_life_cycle.grade_search_name is 'Марка металла (связка) | Марка продукции | alverse_transportation_life_cycle.grade_search_name LE.000647';
comment on column dm.alverse_transportation_life_cycle.supplier_search_name is 'Поставщик и его наименование | Поставщик и его наименование | alverse_transportation_life_cycle.supplier_search_name LE.000749';
comment on column dm.alverse_transportation_life_cycle.transport_subtype_search_name is 'Вид ПС (связка) | Вид ПС из справочника системы учета (род подвижного состава) | alverse_transportation_life_cycle.transport_subtype_search_name LE.000730';
comment on column dm.alverse_transportation_life_cycle.expense_translated_currency_code is 'Валюта затраты (код) | Валюта затраты USD | alverse_transportation_life_cycle.expense_translated_currency_code LE.000744';
comment on column dm.alverse_transportation_life_cycle.expense_group_search_name is 'Группа затрат (связка) | Группа затрат (связка) | alverse_transportation_life_cycle.expense_group_search_name LE.000747';
comment on column dm.alverse_transportation_life_cycle.transportation_service_contract_code is 'Договор затраты (код) | Договор затраты | alverse_transportation_life_cycle.transportation_service_contract_code LE.000748';
comment on column dm.alverse_transportation_life_cycle.transportation_scheme_search_name is 'Схема транспортировки (связка) | Схема транспортировки (связка) | alverse_transportation_life_cycle.transportation_scheme_search_name LE.000752';
comment on column dm.alverse_transportation_life_cycle.transportation_scheme_type_search_name is 'Тип схемы транспортировки (связка) | Тип схемы транспортировки (связка) | alverse_transportation_life_cycle.transportation_scheme_type_search_name LE.000755';
comment on column dm.alverse_transportation_life_cycle.transportation_scheme_subtype_search_name is 'Подтип схемы транспортировки (связка) | Подтип схемы транспортировки (связка) | alverse_transportation_life_cycle.transportation_scheme_subtype_search_name LE.000758';
comment on column dm.alverse_transportation_life_cycle.external_contract_number is '№ контракта | № контракта | alverse_transportation_life_cycle.external_contract_number';
