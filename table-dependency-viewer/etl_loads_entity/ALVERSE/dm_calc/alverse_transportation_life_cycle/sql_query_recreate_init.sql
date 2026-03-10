drop table if exists dm_calc.alverse_transportation_life_cycle;
create table if not exists dm_calc.alverse_transportation_life_cycle (
	initial_delivery_code varchar NULL,
	initial_delivery_item_code varchar NULL,
	sales_order_code varchar NULL,
	expense_account_code varchar NULL,
	expense_account_name varchar null,
	expense_account_search_name varchar null,
	plant_producer_search_name varchar NULL,
	transport_type_search_name varchar NULL,
	transport_vehicle_code varchar NULL,
	transport_bill_code varchar NULL,
	transport_bill_and_railcar_uni_code varchar NULL,
	etsng_search_name varchar NULL,
	material_search_name varchar NULL,
	shape_search_name varchar NULL,
	supplier_search_name varchar null,
	sector_search_name varchar NULL,
	grade_search_name varchar NULL,
	transport_subtype_search_name varchar NULL,
	sales_bundle_code varchar NULL,
	expense_translated_currency_code varchar NULL,
	expense_group_search_name varchar NULL,
	transportation_service_contract_code varchar NULL,
	transportation_scheme_search_name varchar NULL,
	transportation_scheme_type_search_name varchar NULL,
	transportation_scheme_subtype_search_name varchar NULL,
	sales_bundle_gross_weight numeric(13, 3) NULL,
	sales_bundle_net_weight numeric(13, 3) NULL,
	expense_per_ton_usd_amount numeric(11, 2) NULL,
	total_expense_per_gross_weight_usd_amount numeric(15, 2) NULL,
	total_expense_per_net_weight_usd_amount numeric(15, 2) NULL,
	sum_sales_bundle_gross_weight numeric(15, 3) NULL,
	sum_sales_bundle_net_weight numeric(15, 3) NULL,
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

comment on table dm_calc.alverse_transportation_life_cycle is 'Витрина данных для проекта Alverse (вывод всех сведений о перевозке к заказу ЦК)';
comment on column dm_calc.alverse_transportation_life_cycle.initial_delivery_code is 'Номер поставки (код) | Номер поставки (код) | delivery_document_position.delivery_code';
comment on column dm_calc.alverse_transportation_life_cycle.initial_delivery_item_code is 'Позиция поставки (код) | Позиция поставки (код) | delivery_document_position.delivery_position_line_item_code';
comment on column dm_calc.alverse_transportation_life_cycle.sales_order_code is 'Номер заказа (код) | Номер заказа (код) | sales_batch_delivery.sales_order_in_shipment';
comment on column dm_calc.alverse_transportation_life_cycle.expense_account_code is 'Статья затрат (код) | Статья затрат (код) | map_transportation_expenses_keys_ral.expense_code';
comment on column dm_calc.alverse_transportation_life_cycle.expense_account_name is 'Статья затрат (наименование) | Статья затрат (наименование) | transportation_expense_account_texts.expense_account_name';
comment on column dm_calc.alverse_transportation_life_cycle.expense_account_search_name is 'Статья затрат (связка) | Статья затрат (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.plant_producer_search_name is 'Завод (связка) | Завод (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.transport_type_search_name is 'Тип ПС (связка) | Тип ПС (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.transport_vehicle_code is 'Номер ПС (код) | Номер ПС (код) | delivery_document_header.vehicle_code';
comment on column dm_calc.alverse_transportation_life_cycle.transport_bill_code is 'Номер накладной (код) | Номер накладной (код) | delivery_document_header.transport_bill_code';
comment on column dm_calc.alverse_transportation_life_cycle.transport_bill_and_railcar_uni_code is 'Номер накладной - номер ПС (связка) (код) | Номер накладной - номер ПС (связка) (код) | delivery_document_header.transport_bill_code / vehicle_code';
comment on column dm_calc.alverse_transportation_life_cycle.etsng_search_name is 'Код ЕТСНГ (связка) | Код ЕТСНГ (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.material_search_name is 'Материал (связка) | Материал (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.shape_search_name is 'Форма (связка) | Форма (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.supplier_search_name is 'Поставщик и его наименование | Поставщик и его наименование | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.sector_search_name is 'Сектор материала (связка) | Сектор материала (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.grade_search_name is 'Марка металла (связка) | Марка металла (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.transport_subtype_search_name is 'Вид ПС (связка) | Вид ПС (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.sales_bundle_code is 'ID химии (код) | ID химии (код) | sales_bundle.sales_bundle_code';
comment on column dm_calc.alverse_transportation_life_cycle.expense_translated_currency_code is 'Валюта затраты (код) | Валюта затраты (код) | map_transportation_expenses_keys_ral.usd_currency_code';
comment on column dm_calc.alverse_transportation_life_cycle.expense_group_search_name is 'Группа затрат (связка) | Группа затрат (связка) | map_transportation_expenses_keys_ral.expense_position_code + expense_name';
comment on column dm_calc.alverse_transportation_life_cycle.transportation_service_contract_code is 'Договор затраты (код) | Договор затраты (код) | map_transportation_expenses_keys_ral.purchase_contract_code';
comment on column dm_calc.alverse_transportation_life_cycle.transportation_scheme_search_name is 'Схема транспортировки (связка) | Схема транспортировки (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.transportation_scheme_type_search_name is 'Тип схемы транспортировки (связка) | Тип схемы транспортировки (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.transportation_scheme_subtype_search_name is 'Подтип схемы транспортировки (связка) | Подтип схемы транспортировки (связка) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.sales_bundle_gross_weight is 'Вес брутто пакета | Вес брутто пакета | sales_bundle.sales_bundle_gross_weight';
comment on column dm_calc.alverse_transportation_life_cycle.sales_bundle_net_weight is 'Вес нетто пакета | Вес нетто пакета | sales_bundle.sales_bundle_net_weight';
comment on column dm_calc.alverse_transportation_life_cycle.expense_per_ton_usd_amount is 'Сумма в USD на тонну | Сумма в USD на тонну | map_transportation_expenses_keys_ral.expense_per_ton_amount';
comment on column dm_calc.alverse_transportation_life_cycle.total_expense_per_gross_weight_usd_amount is 'Сумма в USD на вес брутто пакета | Сумма в USD на вес брутто пакета | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.total_expense_per_net_weight_usd_amount is 'Сумма в USD на вес нетто пакета | Сумма в USD на вес нетто пакета | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.sum_sales_bundle_gross_weight is 'Техническое поле (сумма веса брутто) | Техническое поле (сумма веса брутто) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.sum_sales_bundle_net_weight is 'Техническое поле (сумма веса нетто) | Техническое поле (сумма веса нетто) | Расчетное поле';
comment on column dm_calc.alverse_transportation_life_cycle.external_contract_number is ' |  | Расчетное поле';
