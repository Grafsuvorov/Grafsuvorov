drop table if exists dm.transportation_services_purchase_price_agreement cascade;

create table dm.transportation_services_purchase_price_agreement(
	purchase_contract_code varchar(10) null,
	purchase_contract_position_line_item_code varchar(5) null,
	address_code varchar(10) null,
	dt_created date null,
	dt_purchase_contract date null,
	purchase_contract_subtype_code varchar(4) null,
	purchase_contract_subtype_name varchar(20) null,
	unit_balance_code varchar(4) null,
	purchase_contract_name varchar(40) null,
	purchase_group_code varchar(3) null,
	purchase_group_name varchar(54) null,
	purchase_organization_code varchar(4) null,
	created_by varchar(12) null,
	release_strategy_group_code varchar(2) null,
	release_stage_code varchar(1) null,
	is_released_code varchar(1) null,
	is_released_name varchar(180) null,
	release_strategy_code varchar(2) null,
	release_status_code varchar(8) null,
	purchase_contract_registration_number varchar(12) null,
	incoterms_code varchar(3) null,
	incoterms_name varchar(90) null,
	incoterms_location_code varchar(28) null,
	calculation_scheme_code varchar(6) null,
	dt_purchase_contract_valid_from date null,
	dt_purchase_contract_valid_to date null,
	supplier_code varchar(10) null,
	supplier_name varchar(140) null,
	supplier_search_name varchar(140) null,
	purchase_contract_appendix_number varchar(12) null,
	external_contract_number varchar(30) null,
	currency_code varchar(5) null,
	terms_of_payment_code varchar(4) null,
	legal_agreement_number varchar(60) null,
	budget_type_code varchar(1) null,
	budget_type_name varchar(180) null,
	bank_account_system_code varchar(4) null,
	cost_region_code varchar(2) null,
	cost_region_name varchar(180) null,
	paydox_contract_type_code varchar(1) null,
	paydox_contract_type_name varchar(40) null,
	payment_date_calculation_rule_code varchar(1) null,
	payment_date_calculation_rule_name varchar(180) null,
	responsibility_center_code varchar(16) null,
	unified_purchase_contract_code varchar(25) null,
	unified_purchase_contract_name varchar(128) null,
	dt_paydox_document date null,
	paydox_document_type_code varchar(10) null,
	paydox_registration_number varchar(128) null,
	paydox_document_code varchar(10) null,
	paydox_document_name varchar(255) null,
	paydox_unit_balance_code varchar(64) null,
	paydox_document_status_code varchar(2) null,
	paydox_document_status_name varchar(40) null,
	paydox_document_status_search_name varchar(40) null,
	paydox_document_url varchar(255) null,
	contract_supervisor_code varchar(8) null,
	contract_supervisor_name varchar(120) null,
	contract_supervisor_search_name varchar(130) null,
	responsible_person_code varchar(8) null,
	responsible_person_name varchar(120) null,
	responsible_person_search_name varchar(130) null,
	purchase_contract_price_uom_code varchar(3) null,
	financial_position_code varchar(14) null,
	funds_center_code varchar(16) null,
	fund_code varchar(10) null,
	weight_uom_code varchar(3) null,
	expense_assignment_type_code varchar(1) null,
	base_uom_code varchar(3) null,
	is_deleted varchar(1) null,
	material_code varchar(18) null,
	material_name varchar(120) null,
	purchase_order_uom_code varchar(3) null,
	purchase_order_quantity numeric(13, 3) null,
	vat_code varchar(2) null,
	plant_code varchar(4) null,
	plant_name varchar(30) null,
	vessel_port_call_code varchar(1) null,
	vessel_port_call_name varchar(180) null,
	vehicle_length_type_code varchar(1) null,
	vehicle_length_type_name varchar(180) null,
	booking_number varchar(30) null,
	bunker_adjustment_tariff_calculation_rule_code varchar(1) null,
	tariff_calculation_weight_to numeric(13, 3) null,
	tariff_calculation_weight_from numeric(13, 3) null,
	package_type_code varchar(2) null,
	package_type_name varchar(180) null,
	tariff_calculation_weekday_type_code varchar(1) null,
	tariff_calculation_weekday_type_name varchar(180) null,
	etsng_code varchar(6) null,
	etsng_name varchar(80) null,
	etsng_previous_code varchar(6) null,
	etsng_previous_name varchar(80) null,
	shape_code varchar(3) null,
	shape_name varchar(90) null,	
	tariff_calculation_rule_code varchar(3) null,
	freight_movement_method_code varchar(4) null,
	freight_movement_method_name varchar(180) null,
	fuel_grade_code varchar(15) null,
	counterparty_code varchar(10) null,
	counterparty_name varchar(140) null,
	counterparty_search_name varchar(140) null,
	vessel_crane_code varchar(1) null,
	vessel_crane_name varchar(180) null,
	container_length_type_code varchar(1) null,
	container_length_type_name varchar(180) null,
	railcar_owner_code varchar(10) null,
	railcar_owner_name varchar(140) null,
	railcar_owner_search_name varchar(140) null,
	sea_forwarder_code varchar(10) null,
	sea_forwarder_name varchar(140) null,
	sea_forwarder_search_name varchar(140) null,
	material_reporting_group_code varchar(9) null,
	movement_scheme_code varchar(1) null,
	movement_scheme_name varchar(180) null,
	container_ownership_type_code varchar(2) null,
	container_ownership_type_name varchar(180) null,
	platform_ownership_type_code varchar(2) null,
	platform_ownership_type_name varchar(180) null,
	redirection_type_code varchar(1) null,
	redirection_type_name varchar(180) null,
	export_method_code varchar(2) null,
	export_method_name varchar(180) null,
	route_code varchar(6) null,
	route_name varchar(120) null,
	sea_route_code varchar(6) null,
	sea_route_name varchar(120) null,
	transport_type_code varchar(4) null,
	transport_type_name varchar(120) null,
	transport_previous_type_code varchar(4) null,
	transport_previous_type_name varchar(120) null,
	railway_platform_completeness_type_code varchar(2) null,
	railway_platform_completeness_type_name varchar(180) null,
	material_reporting_type_code varchar(2) null,
	service_code varchar(18) null,
	service_name varchar(120) null,
	service_search_name varchar(139) null,
	railway_station_code varchar(10) null,
	railway_station_name varchar(90) null,
	container_pickup_transport_hub_code varchar(10) null,
	container_pickup_transport_hub_name varchar(90) null,
	terminal_code varchar(10) null,
	terminal_name varchar(90) null,
	terminal_search_name varchar(101) null,
	port_code varchar(10) null,
	port_name varchar(90) null,
	port_search_name varchar(101) null,
	package_subtype_code varchar(2) null,
	package_subtype_name varchar(180) null,
	transport_subtype_code varchar(4) null,
	service_type_code varchar(1) null,
	service_type_name varchar(180) null,
	service_type_search_name varchar(180) null,
	import_method_code varchar(1) null,
	import_method_name varchar(180) null,
	vessel_code varchar(10) null,
	vehicle_detail_type_code varchar(10) null,
	shipment_type_code varchar(2) null,
	country_of_departure_hub_code varchar(3) null,
	country_of_destination_hub_code varchar(3) null,
	condition_record_code varchar(10) null,
	uom_code varchar(3) null,
	price_rate numeric(11, 2) null,
	price_scale_basis_code varchar(1) null,
	price_scale_basis_name varchar(180) null,
	condition_deleted_flag_code varchar(1) null,
	condition_deleted_flag_name varchar(20) null,
	price_scale_quantity numeric(15, 3) null,
	price_scale_rate numeric(11, 2) null,
	purchase_contract_document_currency_amount numeric(15, 2) null,
	purchase_contract_available_limit_doc_currency_amount numeric(15, 2) null,
	purchase_contract_payed_document_currency_amount numeric(15, 2) null,
	purchase_contract_payed_document_currency_percentage numeric(17, 2) null,
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
	purchase_contract_position_line_item_code
);

comment on table dm.transportation_services_purchase_price_agreement is 'Стоимостные соглашения на транспортные услуги';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_code is 'Контракт на закупку (код) | Контракт на закупку (код) | dds.purchase_contract_header.purchase_contract_code';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_position_line_item_code is 'Позиция контракта на закупку (код) | Позиция контракта на закупку (код) | dds.purchase_contract_position.position_line_item_code';
comment on column dm.transportation_services_purchase_price_agreement.address_code is 'Номер адреса (код) | Номер адреса (код) | dds.purchase_contract_header.address_code';
comment on column dm.transportation_services_purchase_price_agreement.dt_created is 'Дата создания записи | Дата создания записи | dds.purchase_contract_header.dt_created';
comment on column dm.transportation_services_purchase_price_agreement.dt_purchase_contract is 'Дата контракта на закупку | Дата контракта на закупку | dds.purchase_contract_header.dt_purchase_contract';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_subtype_code is 'Вид контракта на закупку (код) | Вид контракта на закупку (код) | dds.purchase_contract_header.purchase_document_subtype_code';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_subtype_name is 'Вид контракта на закупку (наименование) | Вид контракта на закупку (наименование) | dict_dds.purchase_document_type_texts.document_kind_name';
comment on column dm.transportation_services_purchase_price_agreement.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | dds.purchase_contract_header.unit_balance_code';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_name is 'Название контракта | Название контракта | dds.purchase_contract_header.purchase_contract_name';
comment on column dm.transportation_services_purchase_price_agreement.purchase_group_code is 'Группа закупок (код) | Группа закупок (код) | dds.purchase_contract_header.purchase_group_code';
comment on column dm.transportation_services_purchase_price_agreement.purchase_group_name is 'Группа закупок (наименование) | Группа закупок (наименование) | dict_dds.purchase_group.purchase_group_name';
comment on column dm.transportation_services_purchase_price_agreement.purchase_organization_code is 'Закупочная организация (код) | Закупочная организация (код) | dds.purchase_contract_header.purchase_organization_code';
comment on column dm.transportation_services_purchase_price_agreement.created_by is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | dds.purchase_contract_header.created_by';
comment on column dm.transportation_services_purchase_price_agreement.release_strategy_group_code is 'Группа деблокирования (код) | Группа деблокирования (код) | dds.purchase_contract_header.release_strategy_group_code';
comment on column dm.transportation_services_purchase_price_agreement.release_stage_code is 'Индикатор деблокирования (код) | Индикатор деблокирования (код) | dds.purchase_contract_header.release_stage_code';
comment on column dm.transportation_services_purchase_price_agreement.is_released_code is 'Релевантно для выдачи (код) | Релевантно для выдачи (код) | dds.purchase_contract_header.is_released_code';
comment on column dm.transportation_services_purchase_price_agreement.is_released_name is 'Релевантно для выдачи (наименование) | Релевантно для выдачи (наименование) | dict_dds.boolean_texts.boolean_name';
comment on column dm.transportation_services_purchase_price_agreement.release_strategy_code is 'Стратегия деблокирования (код) | Стратегия деблокирования (код) | dds.purchase_contract_header.release_strategy_code';
comment on column dm.transportation_services_purchase_price_agreement.release_status_code is 'Статус деблокирования (код) | Статус деблокирования (код) | dds.purchase_contract_header.release_status_code';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_registration_number is 'Регистрационный номер | Регистрационный номер | dds.purchase_contract_header.purchase_contract_registration_number';
comment on column dm.transportation_services_purchase_price_agreement.incoterms_code is 'Инкотермс (код) | Инкотермс (код) | dds.purchase_contract_header.incoterms_code';
comment on column dm.transportation_services_purchase_price_agreement.incoterms_name is 'Инкотермс (наименование) | Инкотермс (наименование) | dict_dds.incoterms.incoterms_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.incoterms_location_code is 'Инкотермс, часть 2 (код) | Инкотермс, часть 2 (код) | dds.purchase_contract_header.incoterms_location_text';
comment on column dm.transportation_services_purchase_price_agreement.calculation_scheme_code is 'Схема (код) | Схема (код) | dds.purchase_contract_header.calculation_scheme_code';
comment on column dm.transportation_services_purchase_price_agreement.dt_purchase_contract_valid_from is 'Начальный срок действия | Начальный срок действия | dds.purchase_contract_header.dt_valid_from';
comment on column dm.transportation_services_purchase_price_agreement.dt_purchase_contract_valid_to is 'Конечный срок действия | Конечный срок действия | dds.purchase_contract_header.dt_valid_to';
comment on column dm.transportation_services_purchase_price_agreement.supplier_code is 'Поставщик (код) | Поставщик (код) | dds.purchase_contract_header.supplier_code';
comment on column dm.transportation_services_purchase_price_agreement.supplier_name is 'Поставщик (наименование) | Поставщик (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm.transportation_services_purchase_price_agreement.supplier_search_name is 'Поставщик (код и наименование) | Поставщик (код и наименование) | supplier_code-supplier_name';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_appendix_number is 'Номер приложения | Номер приложения | dds.purchase_contract_header.appendix_number';
comment on column dm.transportation_services_purchase_price_agreement.external_contract_number is 'Номер контракта на закупку у поставщика | Номер контракта на закупку у поставщика | dds.purchase_contract_header.external_contract_number_part1';
comment on column dm.transportation_services_purchase_price_agreement.currency_code is 'Валюта (код) | Валюта (код) | dds.purchase_contract_header.currency_code';
comment on column dm.transportation_services_purchase_price_agreement.terms_of_payment_code is 'Условие платежа (код) | Условие платежа (код) | dds.purchase_contract_header.terms_of_payment_code';
comment on column dm.transportation_services_purchase_price_agreement.legal_agreement_number is 'Юридический номер договора | Юридический номер договора | dds.purchase_contract_header.legal_agreement_number';
comment on column dm.transportation_services_purchase_price_agreement.budget_type_code is 'Бюджет (код) | Бюджет (код) | dds.purchase_contract_header.budget_type_code';
comment on column dm.transportation_services_purchase_price_agreement.budget_type_name is 'Бюджет (наименование) | Бюджет (наименование) | dict_dds.budget_type_texts.budget_type_name';
comment on column dm.transportation_services_purchase_price_agreement.bank_account_system_code is 'Тип банка-партнера (код) | Тип банка-партнера (код) | dds.purchase_contract_header.bank_account_system_code';
comment on column dm.transportation_services_purchase_price_agreement.cost_region_code is 'Регион затрат (код) | Регион затрат (код) | dds.purchase_contract_header.cost_region_code';
comment on column dm.transportation_services_purchase_price_agreement.cost_region_name is 'Регион затрат (наименование) | Регион затрат (наименование) | dict_dds.cost_region_texts.cost_region_name';
comment on column dm.transportation_services_purchase_price_agreement.paydox_contract_type_code is 'Тип стоимостного соглашения (код) | Тип стоимостного соглашения (код) | dds.purchase_contract_header.paydox_contract_type_code';
comment on column dm.transportation_services_purchase_price_agreement.paydox_contract_type_name is 'Тип стоимостного соглашения (наименование) | Тип стоимостного соглашения (наименование) | dict_dds.paydox_contract_type_texts.paydox_contract_type_name';
comment on column dm.transportation_services_purchase_price_agreement.payment_date_calculation_rule_code is 'Правило расчета даты оплаты (код) | Правило расчета даты оплаты (код) | dds.purchase_contract_header.payment_date_calculation_rule_code';
comment on column dm.transportation_services_purchase_price_agreement.payment_date_calculation_rule_name is 'Правило расчета даты оплаты (наименование) | Правило расчета даты оплаты (наименование) | dict_dds.payment_date_calculation_rule_texts.payment_date_calculation_rule_name';
comment on column dm.transportation_services_purchase_price_agreement.responsibility_center_code is 'Центр ответственности (код) | Центр ответственности (код) | dds.purchase_contract_header.responsibility_center_code';
comment on column dm.transportation_services_purchase_price_agreement.unified_purchase_contract_code is 'Единый номер договора (код) | Единый номер договора (код) | dds.purchase_contract_header.unified_purchase_contract_code';
comment on column dm.transportation_services_purchase_price_agreement.unified_purchase_contract_name is 'Ссылочный номер договора (наименование) | Ссылочный номер договора (наименование) | dds.purchase_contract_header.unified_purchase_contract_name';
comment on column dm.transportation_services_purchase_price_agreement.dt_paydox_document is 'Дата документа PayDox | Дата документа PayDox | dds.purchase_contract_header.dt_purchase_contract_paydox';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_type_code is 'Вид документа в PayDox (код) | Вид документа в PayDox (код) | dds.purchase_contract_header.paydox_document_type_code';
comment on column dm.transportation_services_purchase_price_agreement.paydox_registration_number is 'Регистрационный № спецификации | Регистрационный № спецификации | dds.purchase_contract_header.paydox_registration_number';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_code is 'Номер документа PayDox (код) | Номер документа PayDox (код) | dds.purchase_contract_header.paydox_document_code';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_name is 'Заголовок документа PayDox (наименование) | Заголовок документа PayDox (наименование) | dds.purchase_contract_header.paydox_document_name';
comment on column dm.transportation_services_purchase_price_agreement.paydox_unit_balance_code is 'Организационная единица (код) | Организационная единица (код) | dds.purchase_contract_header.paydox_unit_balance_code';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_status_code is 'Статус документа PayDox (код) | Статус документа PayDox (код) | dds.purchase_contract_header.paydox_document_status_code';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_status_name is 'Статус документа PayDox (наименование) | Статус документа PayDox (наименование) | dict_dds.paydox_document_status_texts.paydox_document_status_name';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_status_search_name is 'Статус документа PayDox (код и наименование) | Статус документа PayDox (код и наименование) | paydox_document_status_code-paydox_document_status_name';
comment on column dm.transportation_services_purchase_price_agreement.paydox_document_url is 'Ссылка на документ PayDox | Ссылка на документ PayDox | dds.purchase_contract_header.paydox_document_url';
comment on column dm.transportation_services_purchase_price_agreement.contract_supervisor_code is 'Куратор договора (код) | Куратор договора (код) | dds.purchase_document_counterparty_role.personnel_code';
comment on column dm.transportation_services_purchase_price_agreement.contract_supervisor_name is 'Куратор договора (наименование) | Куратор договора (наименование) | dict_dds.employee_main_data.last_name dict_dds.employee_main_data.first_name dict_dds.employee_main_data.middle_name';
comment on column dm.transportation_services_purchase_price_agreement.contract_supervisor_search_name is 'Куратор договора (код и наименование) | Куратор договора (код и наименование) | contract_supervisor_code-contract_supervisor_name';
comment on column dm.transportation_services_purchase_price_agreement.responsible_person_code is 'Ответственный cотрудник (код) | Ответственный cотрудник (код) | dds.purchase_document_counterparty_role.personnel_code';
comment on column dm.transportation_services_purchase_price_agreement.responsible_person_name is 'Ответственный cотрудник (наименование) | Ответственный cотрудник (наименование) | dict_dds.employee_main_data.last_name dict_dds.employee_main_data.first_name dict_dds.employee_main_data.middle_name';
comment on column dm.transportation_services_purchase_price_agreement.responsible_person_search_name is 'Ответственный cотрудник (код и наименование) | Ответственный cотрудник (код и наименование) | responsible_person_code-responsible_person_name';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_price_uom_code is 'Единица измерения цены заказа (код) | Единица измерения цены заказа (код) | dds.purchase_contract_position.price_uom_code';
comment on column dm.transportation_services_purchase_price_agreement.financial_position_code is 'Финансовая позиция (код) | Финансовая позиция (код) | dds.purchase_contract_position.financial_position_code';
comment on column dm.transportation_services_purchase_price_agreement.funds_center_code is 'Подразделение финансового менеджмента (код) | Подразделение финансового менеджмента (код) | dds.purchase_contract_position.funds_center_code';
comment on column dm.transportation_services_purchase_price_agreement.fund_code is 'Фонд (код) | Фонд (код) | dds.purchase_contract_position.fund_code';
comment on column dm.transportation_services_purchase_price_agreement.weight_uom_code is 'Единица веса (код) | Единица веса (код) | dds.purchase_contract_position.weight_uom_code';
comment on column dm.transportation_services_purchase_price_agreement.expense_assignment_type_code is 'Тип контировки (код) | Тип контировки (код) | dds.purchase_contract_position.expense_assignment_type_code';
comment on column dm.transportation_services_purchase_price_agreement.base_uom_code is 'Базовая единица измерения (код) | Базовая единица измерения (код) | dds.purchase_contract_position.base_uom_code';
comment on column dm.transportation_services_purchase_price_agreement.is_deleted is 'Индикатор удаления | Индикатор удаления | dds.purchase_contract_position.is_deleted';
comment on column dm.transportation_services_purchase_price_agreement.material_code is 'Материал (код) | Материал (код) | dds.purchase_contract_position.material_code';
comment on column dm.transportation_services_purchase_price_agreement.material_name is 'Материал (наименование) | Материал (наименование) | dict_dds.material_texts.material_name';
comment on column dm.transportation_services_purchase_price_agreement.purchase_order_uom_code is 'ЕИ заказа на поставку (код) | ЕИ заказа на поставку (код) | dds.purchase_contract_position.uom_code';
comment on column dm.transportation_services_purchase_price_agreement.purchase_order_quantity is 'Объем заказа | Объем заказа | dds.purchase_contract_position.quantity';
comment on column dm.transportation_services_purchase_price_agreement.vat_code is 'Код НДС (код) | Код НДС (код) | dds.purchase_contract_position.vat_code';
comment on column dm.transportation_services_purchase_price_agreement.plant_code is 'Завод (код) | Завод (код) | dds.purchase_contract_position.plant_code';
comment on column dm.transportation_services_purchase_price_agreement.plant_name is 'Завод (наименование) | Завод (наименование) | dict_dds.plant_and_subsidiary.plant_full_name';
comment on column dm.transportation_services_purchase_price_agreement.vessel_port_call_code is 'Кол-во заходов в Порты (код) | Кол-во заходов в Порты (код) | dds.purchase_contract_position.vessel_port_call_code';
comment on column dm.transportation_services_purchase_price_agreement.vessel_port_call_name is 'Кол-во заходов в Порты (наименование) | Кол-во заходов в Порты (наименование) | dict_dds.vessel_port_call_texts.vessel_port_call_name';
comment on column dm.transportation_services_purchase_price_agreement.vehicle_length_type_code is 'Длина ПС (код) | Длина ПС (код) | dds.purchase_contract_position.vehicle_length_type_code';
comment on column dm.transportation_services_purchase_price_agreement.vehicle_length_type_name is 'Длина ПС (наименование) | Длина ПС (наименование) | dict_dds.vehicle_length_type_texts.vehicle_length_type_name';
comment on column dm.transportation_services_purchase_price_agreement.booking_number is 'Номер букинга | Номер букинга | dds.purchase_contract_position.booking_number';
comment on column dm.transportation_services_purchase_price_agreement.bunker_adjustment_tariff_calculation_rule_code is 'Базис бункерной поправки (код) | Базис бункерной поправки (код) | dds.purchase_contract_position.bunker_adjustment_tariff_calculation_rule_code';
comment on column dm.transportation_services_purchase_price_agreement.tariff_calculation_weight_to is 'Вес по, тн | Вес по, тн | dds.purchase_contract_position.tariff_calculation_weight_to';
comment on column dm.transportation_services_purchase_price_agreement.tariff_calculation_weight_from is 'Вес с, тн | Вес с, тн | dds.purchase_contract_position.tariff_calculation_weight_from';
comment on column dm.transportation_services_purchase_price_agreement.package_type_code is 'Тип тары (код) | Тип тары (код) | dds.purchase_contract_position.package_type_code';
comment on column dm.transportation_services_purchase_price_agreement.package_type_name is 'Тип тары (наименование) | Тип тары (наименование) | dict_dds.package_type_texts.package_type_name';
comment on column dm.transportation_services_purchase_price_agreement.tariff_calculation_weekday_type_code is 'Выходные и праздничные дни (код) | Выходные и праздничные дни (код) | dds.purchase_contract_position.tariff_calculation_weekday_type_code';
comment on column dm.transportation_services_purchase_price_agreement.tariff_calculation_weekday_type_name is 'Выходные и праздничные дни (наименование) | Выходные и праздничные дни (наименование) | dict_dds.tariff_calculation_weekday_type_texts.tariff_calculation_weekday_type_name';
comment on column dm.transportation_services_purchase_price_agreement.etsng_code is 'Код ЕТ СНГ перевозимого груза (код) | Код ЕТ СНГ перевозимого груза (код) | dds.purchase_contract_position.etsng_code';
comment on column dm.transportation_services_purchase_price_agreement.etsng_name is 'Код ЕТ СНГ перевозимого груза (наименование) | Код ЕТ СНГ перевозимого груза (наименование) | dict_dds.etsng.etsng_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.etsng_previous_code is 'Код ЕТ СНГ исходный (код) | Код ЕТ СНГ исходный (код) | dds.purchase_contract_position.etsng_previous_code';
comment on column dm.transportation_services_purchase_price_agreement.etsng_previous_name is 'Код ЕТ СНГ исходный (наименование) | Код ЕТ СНГ исходный (наименование) | dict_dds.etsng.etsng_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.shape_code is 'Форма (код) | Форма (код) | dds.purchase_contract_position.shape_code';
comment on column dm.transportation_services_purchase_price_agreement.shape_name is 'Форма (наименование) | Форма (наименование) | dict_dds.material_shape_texts.material_shape_full_name';
comment on column dm.transportation_services_purchase_price_agreement.tariff_calculation_rule_code is 'Номер формулы (код) | Номер формулы (код) | dds.purchase_contract_position.tariff_calculation_rule_code';
comment on column dm.transportation_services_purchase_price_agreement.freight_movement_method_code is 'Вид фрахта (код) | Вид фрахта (код) | dds.purchase_contract_position.freight_movement_method_code';
comment on column dm.transportation_services_purchase_price_agreement.freight_movement_method_name is 'Вид фрахта (наименование) | Вид фрахта (наименование) | dict_dds.freight_movement_method_texts.freight_movement_method_name';
comment on column dm.transportation_services_purchase_price_agreement.fuel_grade_code is 'Марка топлива (код) | Марка топлива (код) | dds.purchase_contract_position.fuel_grade_code';
comment on column dm.transportation_services_purchase_price_agreement.counterparty_code is 'Контрагент (код) | Контрагент (код) | dds.purchase_contract_position.counterparty_code';
comment on column dm.transportation_services_purchase_price_agreement.counterparty_name is 'Контрагент (наименование) | Контрагент (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm.transportation_services_purchase_price_agreement.counterparty_search_name is 'Контрагент (код и наименование) | Контрагент (код и наименование) | counterparty_code-counterparty_name';
comment on column dm.transportation_services_purchase_price_agreement.vessel_crane_code is 'Кран (код) | Кран (код) | dds.purchase_contract_position.vessel_crane_code';
comment on column dm.transportation_services_purchase_price_agreement.vessel_crane_name is 'Кран (наименование) | Кран (наименование) | dict_dds.vessel_crane_texts.vessel_crane_name';
comment on column dm.transportation_services_purchase_price_agreement.container_length_type_code is 'Длина контейнера (код) | Длина контейнера (код) | dds.purchase_contract_position.container_length_type_code';
comment on column dm.transportation_services_purchase_price_agreement.container_length_type_name is 'Длина контейнера (наименование) | Длина контейнера (наименование) | dict_dds.container_length_type_texts.container_length_type_name';
comment on column dm.transportation_services_purchase_price_agreement.railcar_owner_code is 'Собственник вагона (код) | Собственник вагона (код) | dds.purchase_contract_position.railcar_owner_code';
comment on column dm.transportation_services_purchase_price_agreement.railcar_owner_name is 'Собственник вагона (наименование) | Собственник вагона (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm.transportation_services_purchase_price_agreement.railcar_owner_search_name is 'Собственник вагона (код и наименование) | Собственник вагона (код и наименование) | railcar_owner_code-railcar_owner_name';
comment on column dm.transportation_services_purchase_price_agreement.sea_forwarder_code is 'Линия (код) | Линия (код) | dds.purchase_contract_position.sea_forwarder_code';
comment on column dm.transportation_services_purchase_price_agreement.sea_forwarder_name is 'Линия (наименование) | Линия (наименование) | dict_dds.counterparty.counterparty_full_name';
comment on column dm.transportation_services_purchase_price_agreement.sea_forwarder_search_name is 'Линия (код и наименование) | Линия (код и наименование) | sea_forwarder_code-sea_forwarder_name';
comment on column dm.transportation_services_purchase_price_agreement.material_reporting_group_code is 'Группа материала (код) | Группа материала (код) | dds.purchase_contract_position.material_reporting_group_code';
comment on column dm.transportation_services_purchase_price_agreement.movement_scheme_code is 'Схема перемещения (код) | Схема перемещения (код) | dds.purchase_contract_position.movement_scheme_code';
comment on column dm.transportation_services_purchase_price_agreement.movement_scheme_name is 'Схема перемещения (наименование) | Схема перемещения (наименование) | dict_dds.movement_scheme_texts.movement_scheme_name';
comment on column dm.transportation_services_purchase_price_agreement.container_ownership_type_code is 'Принадлежность контейнера (код) | Принадлежность контейнера (код) | dds.purchase_contract_position.container_ownership_type_code';
comment on column dm.transportation_services_purchase_price_agreement.container_ownership_type_name is 'Принадлежность контейнера (наименование) | Принадлежность контейнера (наименование) | dict_dds.container_ownership_type_texts.container_ownership_type_name';
comment on column dm.transportation_services_purchase_price_agreement.platform_ownership_type_code is 'Принадлежность платформы (код) | Принадлежность платформы (код) | dds.purchase_contract_position.platform_ownership_type_code';
comment on column dm.transportation_services_purchase_price_agreement.platform_ownership_type_name is 'Принадлежность платформы (наименование) | Принадлежность платформы (наименование) | dict_dds.container_ownership_type_texts.container_ownership_type_name';
comment on column dm.transportation_services_purchase_price_agreement.redirection_type_code is 'Тип переадресации (код) | Тип переадресации (код) | dds.purchase_contract_position.redirection_type_code';
comment on column dm.transportation_services_purchase_price_agreement.redirection_type_name is 'Тип переадресации (наименование) | Тип переадресации (наименование) | dict_dds.redirection_type_texts.redirection_type_name';
comment on column dm.transportation_services_purchase_price_agreement.export_method_code is 'Режим экспорта (код) | Режим экспорта (код) | dds.purchase_contract_position.export_method_code';
comment on column dm.transportation_services_purchase_price_agreement.export_method_name is 'Режим экспорта (наименование) | Режим экспорта (наименование) | dict_dds.export_method_texts.export_method_name';
comment on column dm.transportation_services_purchase_price_agreement.route_code is 'Маршрут (код) | Маршрут (код) | dds.purchase_contract_position.route_code';
comment on column dm.transportation_services_purchase_price_agreement.route_name is 'Маршрут (наименование) | Маршрут (наименование) | dict_dds.transport_route.transport_route_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.sea_route_code is 'Морской маршрут (код) | Морской маршрут (код) | dds.purchase_contract_position.sea_route_code';
comment on column dm.transportation_services_purchase_price_agreement.sea_route_name is 'Морской маршрут (наименование) | Морской маршрут (наименование) | dict_dds.transport_route.transport_route_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.transport_type_code is 'Тип вагона (код) | Тип вагона (код) | dds.purchase_contract_position.transport_type_code';
comment on column dm.transportation_services_purchase_price_agreement.transport_type_name is 'Тип вагона (наименование) | Тип вагона (наименование) | dict_dds.transport_transfer_type.transport_transfer_type_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.transport_previous_type_code is 'Тип исходного ТС/ПС (код) | Тип исходного ТС/ПС (код) | dds.purchase_contract_position.transport_previous_type_code';
comment on column dm.transportation_services_purchase_price_agreement.transport_previous_type_name is 'Тип исходного ТС/ПС (наименование) | Тип исходного ТС/ПС (наименование) | dict_dds.transport_transfer_type.transport_transfer_type_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.railway_platform_completeness_type_code is 'Признак комплектности (код) | Признак комплектности (код) | dds.purchase_contract_position.railway_platform_completeness_type_code';
comment on column dm.transportation_services_purchase_price_agreement.railway_platform_completeness_type_name is 'Признак комплектности (наименование) | Признак комплектности (наименование) | dict_dds.railway_platform_completeness_type_texts.railway_platform_completeness_type_name';
comment on column dm.transportation_services_purchase_price_agreement.material_reporting_type_code is 'Сектор (код) | Сектор (код) | dds.purchase_contract_position.material_reporting_type_code';
comment on column dm.transportation_services_purchase_price_agreement.service_code is 'Номер услуги LE (код) | Номер услуги LE (код) | dds.purchase_contract_position.service_code';
comment on column dm.transportation_services_purchase_price_agreement.service_name is 'Номер услуги LE (наименование) | Номер услуги LE (наименование) | dict_dds.service_assessment_class_dsc.service_dsc';
comment on column dm.transportation_services_purchase_price_agreement.service_search_name is 'Номер услуги LE (код и наименование) | Номер услуги LE (код и наименование) | service_code-service_name';
comment on column dm.transportation_services_purchase_price_agreement.railway_station_code is 'Станция (код) | Станция (код) | dds.purchase_contract_position.railway_station_code';
comment on column dm.transportation_services_purchase_price_agreement.railway_station_name is 'Станция (наименование) | Станция (наименование) | dict_dds.transport_hub.transport_hub_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.container_pickup_transport_hub_code is 'Сток (код) | Сток (код) | dds.purchase_contract_position.container_pickup_transport_hub_code';
comment on column dm.transportation_services_purchase_price_agreement.container_pickup_transport_hub_name is 'Сток (наименование) | Сток (наименование) | dict_dds.transport_hub.transport_hub_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.terminal_code is 'Терминал (код) | Терминал (код) | dds.purchase_contract_position.terminal_code dds.purchase_contract_header.terminal_code';
comment on column dm.transportation_services_purchase_price_agreement.terminal_name is 'Терминал (наименование) | Терминал (наименование) | dict_dds.transport_hub.transport_hub_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.terminal_search_name is 'Терминал (код и наименование) | Терминал (код и наименование) | terminal_code-terminal_name';
comment on column dm.transportation_services_purchase_price_agreement.port_code is 'Порт (код) | Порт (код) | dds.purchase_contract_position.port_code dds.purchase_contract_header.port_code';
comment on column dm.transportation_services_purchase_price_agreement.port_name is 'Порт (наименование) | Порт (наименование) | dict_dds.transport_hub.transport_hub_name_rus';
comment on column dm.transportation_services_purchase_price_agreement.port_search_name is 'Порт (код и наименование) | Порт (код и наименование) | port_code-port_name';
comment on column dm.transportation_services_purchase_price_agreement.package_subtype_code is 'Подтип тары (код) | Подтип тары (код) | dds.purchase_contract_position.package_subtype_code';
comment on column dm.transportation_services_purchase_price_agreement.package_subtype_name is 'Подтип тары (наименование) | Подтип тары (наименование) | dict_dds.package_subtype_texts.package_subtype_name';
comment on column dm.transportation_services_purchase_price_agreement.transport_subtype_code is 'Вид транспортного средства (код) | Вид транспортного средства (код) | dds.purchase_contract_position.transport_subtype_code';
comment on column dm.transportation_services_purchase_price_agreement.service_type_code is 'Тип услуги (код) | Тип услуги (код) | dds.purchase_contract_position.service_type_code';
comment on column dm.transportation_services_purchase_price_agreement.service_type_name is 'Тип услуги (наименование) | Тип услуги (наименование) | dict_dds.service_type_texts.service_type_name';
comment on column dm.transportation_services_purchase_price_agreement.service_type_search_name is 'Тип услуги (код и наименование) | Тип услуги (код и наименование) | service_type_code-service_type_name';
comment on column dm.transportation_services_purchase_price_agreement.import_method_code is 'Схема реализации (код) | Схема реализации (код) | dds.purchase_contract_position.import_method_code';
comment on column dm.transportation_services_purchase_price_agreement.import_method_name is 'Схема реализации (наименование) | Схема реализации (наименование) | dict_dds.import_method_texts.import_method_name';
comment on column dm.transportation_services_purchase_price_agreement.vessel_code is 'Судно (код) | Судно (код) | dds.purchase_contract_position.vessel_code';
comment on column dm.transportation_services_purchase_price_agreement.vehicle_detail_type_code is 'Марка ТС (код) | Марка ТС (код) | dds.purchase_contract_position.vehicle_detail_type_code';
comment on column dm.transportation_services_purchase_price_agreement.shipment_type_code is 'Вид отгрузки (код) | Вид отгрузки (код) | dds.purchase_contract_position.shipment_type_code';
comment on column dm.transportation_services_purchase_price_agreement.country_of_departure_hub_code is 'Страна начального узла маршрута (код) | Страна начального узла маршрута (код) | 1) Страна для узла dict_dds.transport_hub.transport_route_departure_hub_code из маршрута dds.purchase_contract_position.route_code; 2) Страна для узла dict_dds.transport_hub.transport_route_departure_hub_code из маршрута dds.purchase_contract_position.sea_route_code';
comment on column dm.transportation_services_purchase_price_agreement.country_of_destination_hub_code is 'Страна конечного узла маршрута (код) | Страна конечного узла маршрута (код) | 1) Страна для узла dict_dds.transport_hub.transport_route_destination_hub_code из маршрута dds.purchase_contract_position.sea_route_code; 2) Страна для узла dict_dds.transport_hub.transport_route_destination_hub_code из маршрута dds.purchase_contract_position.route_code';
comment on column dm.transportation_services_purchase_price_agreement.condition_record_code is 'Номер ценового условия (код) | Номер ценового условия (код) | dds.purchase_contract_price_conditions.price_condition_code';
comment on column dm.transportation_services_purchase_price_agreement.uom_code is 'Единица измерения ценового условия (код) | Единица измерения ценового условия (код) | dds.purchase_contract_price_conditions.price_condition_uom_code';
comment on column dm.transportation_services_purchase_price_agreement.price_rate is 'Цена или процентная ставка условия | Цена или процентная ставка условия | dds.purchase_contract_price_conditions.price_rate';
comment on column dm.transportation_services_purchase_price_agreement.price_scale_basis_code is 'Базис шкалы ценового условия (код) | Базис шкалы ценового условия (код) | dds.purchase_contract_price_conditions.price_scale_basis_code';
comment on column dm.transportation_services_purchase_price_agreement.price_scale_basis_name is 'Базис шкалы ценового условия (наименование) | Базис шкалы ценового условия (наименование) | dict_dds.price_scale_basis_texts.price_scale_basis_name';
comment on column dm.transportation_services_purchase_price_agreement.condition_deleted_flag_code is 'Индикатор удаления позиции ценового условия (код) | Индикатор удаления позиции ценового условия (код) | dds.purchase_contract_price_conditions.is_price_condition_position_deleted_code';
comment on column dm.transportation_services_purchase_price_agreement.condition_deleted_flag_name is 'Индикатор удаления позиции ценового условия (наименование) | Индикатор удаления позиции ценового условия (наименование) | ';
comment on column dm.transportation_services_purchase_price_agreement.price_scale_quantity is 'Базисное количество позиции шкалы условия | Базисное количество позиции шкалы условия | dds.purchase_contract_price_conditions.price_scale_quantity';
comment on column dm.transportation_services_purchase_price_agreement.price_scale_rate is 'Цена или процентная ставка позиции шкалы условия | Цена или процентная ставка позиции шкалы условия | dds.purchase_contract_price_conditions.price_scale_rate';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_document_currency_amount is 'Сумма с НДС, которую можно потратить по договору на все акты и ТАПы | Сумма с НДС, которую можно потратить по договору на все акты и ТАПы | dds.purchase_contract_header.total_purchase_contract_cost_document_currency_amount';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_available_limit_doc_currency_amount is 'Остаток суммы по договору | Остаток суммы по договору | dds.purchase_contract_header.purchase_contract_available_limit_doc_currency_amount';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_payed_document_currency_amount is 'Сумма всех акцептованнх актов и ТАПов в валюте документа | Сумма всех акцептованнх актов и ТАПов в валюте документа | dds.purchase_contract_header.total_purchase_contract_cost_document_currency_amount - dds.purchase_contract_header.purchase_contract_available_limit_doc_currency_amount';
comment on column dm.transportation_services_purchase_price_agreement.purchase_contract_payed_document_currency_percentage is 'В процентах сумма всех акцептованнх актов и ТАПов от суммы с НДС, которую можно потратить по договору на все акты и ТАПы | В процентах сумма всех акцептованнх актов и ТАПов от суммы с НДС, которую можно потратить по договору на все акты и ТАПы | (dds.purchase_contract_header.total_purchase_contract_cost_document_currency_amount - dds.purchase_contract_header.purchase_contract_available_limit_doc_currency_amount) * 100 / dds.purchase_contract_header.total_purchase_contract_cost_document_currency_amount';