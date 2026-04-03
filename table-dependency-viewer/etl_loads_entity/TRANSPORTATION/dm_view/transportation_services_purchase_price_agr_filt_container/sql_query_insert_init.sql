drop view if exists dm_view.transportation_services_purchase_price_agr_filt_container;
 
create or replace view dm_view.transportation_services_purchase_price_agr_filt_container as
select
	dt_created,
	dt_purchase_contract,
	purchase_contract_subtype_code,
	purchase_contract_subtype_name,
	purchase_contract_name,
	purchase_contract_code,
	created_by,
	dt_purchase_contract_valid_from,
	dt_purchase_contract_valid_to,
	supplier_code,
	purchase_contract_appendix_number,
	external_contract_number,
	shipment_type_code,
	currency_code,
	terminal_code,
	terminal_name,
	terminal_search_name,
	port_code,
	port_name,
	port_search_name,
	purchase_contract_price_uom_code,
	purchase_contract_position_line_item_code,
	plant_code,
	plant_name,
	freight_movement_method_code,
	freight_movement_method_name,
	container_length_type_code,
	container_length_type_name,
	sea_forwarder_code,
	sea_forwarder_name,
	sea_forwarder_search_name,
	material_reporting_group_code,
	container_ownership_type_code,
	container_ownership_type_name,
	platform_ownership_type_code,
	platform_ownership_type_name,
	export_method_code,
	export_method_name,
	route_code,
	route_name,
	sea_route_code,
	sea_route_name,
	transport_type_code,
	transport_type_name,
	transport_previous_type_code,
	transport_previous_type_name,
	railway_platform_completeness_type_code,
	railway_platform_completeness_type_name,
	material_reporting_type_code,
	service_code,
	service_name,
	service_search_name,
	railway_station_code,
	railway_station_name,
	container_pickup_transport_hub_code,
	container_pickup_transport_hub_name,
	transport_subtype_code,
	service_type_code,
	service_type_name,
	service_type_search_name,
	import_method_code,
	import_method_name,
	uom_code,
	price_rate,
	supplier_name,
	supplier_search_name,
	contract_supervisor_code,
	contract_supervisor_name,
	contract_supervisor_search_name,
	responsible_person_code,
	responsible_person_name,
	responsible_person_search_name,
	country_of_departure_hub_code,
	country_of_destination_hub_code,
	shape_name,
	dttm_inserted,
	dttm_updated,
	job_name,
	deleted_flag
from dm.transportation_services_purchase_price_agreement
where purchase_group_code = 'D02'
  and paydox_contract_type_code = '1'
  and deleted_flag = false;

comment on view dm_view.transportation_services_purchase_price_agr_filt_container is 'Стоимостные соглашения на транспортные услуги для ДКП';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_code is 'Контракт на закупку (код) | Контракт на закупку (код) | dm.transportation_services_purchase_price_agreement.purchase_contract_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_position_line_item_code is 'Позиция контракта на закупку (код) | Позиция контракта на закупку (код) | dm.transportation_services_purchase_price_agreement.position_line_item_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.dt_created is 'Дата создания записи | Дата создания записи | dm.transportation_services_purchase_price_agreement.dt_created';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.dt_purchase_contract is 'Дата контракта на закупку | Дата контракта на закупку | dm.transportation_services_purchase_price_agreement.dt_purchase_contract';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_subtype_code is 'Вид контракта на закупку (код) | Вид контракта на закупку (код) | dm.transportation_services_purchase_price_agreement.purchase_document_subtype_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_subtype_name is 'Вид контракта на закупку (наименование) | Вид контракта на закупку (наименование) | dm.transportation_services_purchase_price_agreement.document_kind_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_name is 'Название контракта | Название контракта | dm.transportation_services_purchase_price_agreement.purchase_contract_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.created_by is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | dm.transportation_services_purchase_price_agreement.created_by';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.dt_purchase_contract_valid_from is 'Начальный срок действия | Начальный срок действия | dm.transportation_services_purchase_price_agreement.dt_valid_from';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.dt_purchase_contract_valid_to is 'Конечный срок действия | Конечный срок действия | dm.transportation_services_purchase_price_agreement.dt_valid_to';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.supplier_code is 'Поставщик (код) | Поставщик (код) | dm.transportation_services_purchase_price_agreement.supplier_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.supplier_name is 'Поставщик (наименование) | Поставщик (наименование) | dm.transportation_services_purchase_price_agreement.counterparty_full_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.supplier_search_name is 'Поставщик (код и наименование) | Поставщик (код и наименование) | supplier_code-supplier_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_appendix_number is 'Номер приложения | Номер приложения | dm.transportation_services_purchase_price_agreement.appendix_number';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.external_contract_number is 'Номер контракта на закупку у поставщика | Номер контракта на закупку у поставщика | dm.transportation_services_purchase_price_agreement.external_contract_number_part1';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.currency_code is 'Валюта (код) | Валюта (код) | dm.transportation_services_purchase_price_agreement.currency_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.contract_supervisor_code is 'Куратор договора (код) | Куратор договора (код) | dm.transportation_services_purchase_price_agreement.personnel_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.contract_supervisor_name is 'Куратор договора (наименование) | Куратор договора (наименование) | dm.transportation_services_purchase_price_agreement.first_name dict_dds.employee_main_data.middle_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.contract_supervisor_search_name is 'Куратор договора (код и наименование) | Куратор договора (код и наименование) | contract_supervisor_code-contract_supervisor_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.responsible_person_code is 'Ответственный cотрудник (код) | Ответственный cотрудник (код) | dm.transportation_services_purchase_price_agreement.personnel_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.responsible_person_name is 'Ответственный cотрудник (наименование) | Ответственный cотрудник (наименование) | dm.transportation_services_purchase_price_agreement.first_name dict_dds.employee_main_data.middle_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.responsible_person_search_name is 'Ответственный cотрудник (код и наименование) | Ответственный cотрудник (код и наименование) | responsible_person_code-responsible_person_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.purchase_contract_price_uom_code is 'Единица измерения цены заказа (код) | Единица измерения цены заказа (код) | dm.transportation_services_purchase_price_agreement.price_uom_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.plant_code is 'Завод (код) | Завод (код) | dm.transportation_services_purchase_price_agreement.plant_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.plant_name is 'Завод (наименование) | Завод (наименование) | dm.transportation_services_purchase_price_agreement.plant_full_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.freight_movement_method_code is 'Вид фрахта (код) | Вид фрахта (код) | dm.transportation_services_purchase_price_agreement.freight_movement_method_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.freight_movement_method_name is 'Вид фрахта (наименование) | Вид фрахта (наименование) | dm.transportation_services_purchase_price_agreement.freight_movement_method_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.container_length_type_code is 'Длина контейнера (код) | Длина контейнера (код) | dm.transportation_services_purchase_price_agreement.container_length_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.container_length_type_name is 'Длина контейнера (наименование) | Длина контейнера (наименование) | dm.transportation_services_purchase_price_agreement.container_length_type_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.sea_forwarder_code is 'Линия (код) | Линия (код) | dm.transportation_services_purchase_price_agreement.sea_forwarder_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.sea_forwarder_name is 'Линия (наименование) | Линия (наименование) | dm.transportation_services_purchase_price_agreement.counterparty_full_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.sea_forwarder_search_name is 'Линия (код и наименование) | Линия (код и наименование) | sea_forwarder_code-sea_forwarder_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.material_reporting_group_code is 'Группа материала (код) | Группа материала (код) | dm.transportation_services_purchase_price_agreement.material_reporting_group_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.container_ownership_type_code is 'Принадлежность контейнера (код) | Принадлежность контейнера (код) | dm.transportation_services_purchase_price_agreement.container_ownership_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.container_ownership_type_name is 'Принадлежность контейнера (наименование) | Принадлежность контейнера (наименование) | dm.transportation_services_purchase_price_agreement.container_ownership_type_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.platform_ownership_type_code is 'Принадлежность платформы (код) | Принадлежность платформы (код) | dm.transportation_services_purchase_price_agreement.platform_ownership_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.platform_ownership_type_name is 'Принадлежность платформы (наименование) | Принадлежность платформы (наименование) | dm.transportation_services_purchase_price_agreement.container_ownership_type_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.export_method_code is 'Режим экспорта (код) | Режим экспорта (код) | dm.transportation_services_purchase_price_agreement.export_method_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.export_method_name is 'Режим экспорта (наименование) | Режим экспорта (наименование) | dm.transportation_services_purchase_price_agreement.export_method_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.route_code is 'Маршрут (код) | Маршрут (код) | dm.transportation_services_purchase_price_agreement.route_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.route_name is 'Маршрут (наименование) | Маршрут (наименование) | dm.transportation_services_purchase_price_agreement.transport_route_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.sea_route_code is 'Морской маршрут (код) | Морской маршрут (код) | dm.transportation_services_purchase_price_agreement.sea_route_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.sea_route_name is 'Морской маршрут (наименование) | Морской маршрут (наименование) | dm.transportation_services_purchase_price_agreement.transport_route_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.transport_type_code is 'Тип вагона (код) | Тип вагона (код) | dm.transportation_services_purchase_price_agreement.transport_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.transport_type_name is 'Тип вагона (наименование) | Тип вагона (наименование) | dm.transportation_services_purchase_price_agreement.transport_transfer_type_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.transport_previous_type_code is 'Тип исходного ТС/ПС (код) | Тип исходного ТС/ПС (код) | dm.transportation_services_purchase_price_agreement.transport_previous_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.transport_previous_type_name is 'Тип исходного ТС/ПС (наименование) | Тип исходного ТС/ПС (наименование) | dm.transportation_services_purchase_price_agreement.transport_transfer_type_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.railway_platform_completeness_type_code is 'Признак комплектности (код) | Признак комплектности (код) | dm.transportation_services_purchase_price_agreement.railway_platform_completeness_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.railway_platform_completeness_type_name is 'Признак комплектности (наименование) | Признак комплектности (наименование) | dm.transportation_services_purchase_price_agreement.railway_platform_completeness_type_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.material_reporting_type_code is 'Сектор (код) | Сектор (код) | dm.transportation_services_purchase_price_agreement.material_reporting_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.service_code is 'Номер услуги LE (код) | Номер услуги LE (код) | dm.transportation_services_purchase_price_agreement.service_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.service_name is 'Номер услуги LE (наименование) | Номер услуги LE (наименование) | dm.transportation_services_purchase_price_agreement.service_dsc';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.service_search_name is 'Номер услуги LE (код и наименование) | Номер услуги LE (код и наименование) | service_code-service_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.railway_station_code is 'Станция (код) | Станция (код) | dm.transportation_services_purchase_price_agreement.railway_station_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.railway_station_name is 'Станция (наименование) | Станция (наименование) | dm.transportation_services_purchase_price_agreement.transport_hub_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.container_pickup_transport_hub_code is 'Сток (код) | Сток (код) | dm.transportation_services_purchase_price_agreement.container_pickup_transport_hub_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.container_pickup_transport_hub_name is 'Сток (наименование) | Сток (наименование) | dm.transportation_services_purchase_price_agreement.transport_hub_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.terminal_code is 'Терминал (код) | Терминал (код) | dm.transportation_services_purchase_price_agreement.terminal_code dm.transportation_services_purchase_price_agreement.terminal_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.terminal_name is 'Терминал (наименование) | Терминал (наименование) | dm.transportation_services_purchase_price_agreement.transport_hub_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.terminal_search_name is 'Терминал (код и наименование) | Терминал (код и наименование) | terminal_code-terminal_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.port_code is 'Порт (код) | Порт (код) | dm.transportation_services_purchase_price_agreement.port_code dm.transportation_services_purchase_price_agreement.port_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.port_name is 'Порт (наименование) | Порт (наименование) | dm.transportation_services_purchase_price_agreement.transport_hub_name_rus';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.port_search_name is 'Порт (код и наименование) | Порт (код и наименование) | port_code-port_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.transport_subtype_code is 'Вид транспортного средства (код) | Вид транспортного средства (код) | dm.transportation_services_purchase_price_agreement.transport_subtype_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.service_type_code is 'Тип услуги (код) | Тип услуги (код) | dm.transportation_services_purchase_price_agreement.service_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.service_type_name is 'Тип услуги (наименование) | Тип услуги (наименование) | dm.transportation_services_purchase_price_agreement.service_type_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.service_type_search_name is 'Тип услуги (код и наименование) | Тип услуги (код и наименование) | service_type_code-service_type_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.import_method_code is 'Схема реализации (код) | Схема реализации (код) | dm.transportation_services_purchase_price_agreement.import_method_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.import_method_name is 'Схема реализации (наименование) | Схема реализации (наименование) | dm.transportation_services_purchase_price_agreement.import_method_name';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.shipment_type_code is 'Вид отгрузки (код) | Вид отгрузки (код) | dm.transportation_services_purchase_price_agreement.shipment_type_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.uom_code is 'Единица измерения ценового условия (код) | Единица измерения ценового условия (код) | dm.transportation_services_purchase_price_agreement.price_condition_uom_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.price_rate is 'Цена или процентная ставка условия | Цена или процентная ставка условия | dm.transportation_services_purchase_price_agreement.price_rate';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.country_of_departure_hub_code is 'Страна начального узла маршрута (код) | Страна начального узла маршрута (код) | dm.transportation_services_purchase_price_agreement.country_of_departure_hub_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.country_of_destination_hub_code is 'Страна конечного узла маршрута (код) | Страна конечного узла маршрута (код) | dm.transportation_services_purchase_price_agreement.country_of_destination_hub_code';
comment on column dm_view.transportation_services_purchase_price_agr_filt_container.shape_name is 'Форма (наименование) | Форма (наименование) | dm.transportation_services_purchase_price_agreement.shape_name';