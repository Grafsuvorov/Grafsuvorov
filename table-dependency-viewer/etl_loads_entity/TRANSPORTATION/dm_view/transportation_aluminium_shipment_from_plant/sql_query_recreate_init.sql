drop view if exists dm_view.transportation_aluminium_shipment_from_plant;

create or replace view dm_view.transportation_aluminium_shipment_from_plant as
select *
from dm.transportation_aluminium_shipment_from_plant
where 1=1
and deleted_flag = false;

comment on view dm_view.transportation_aluminium_shipment_from_plant is 'Реестр поставок - повагонная информация для ДСб';
comment on column dm_view.transportation_aluminium_shipment_from_plant.plant_producer_code is 'Завод производитель (код) | Завод производитель (код) | delivery_document_position.plant_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.plant_producer_name is 'Завод, наименование | Завод, наименование | plant_and_subsidiary.plant_short_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.initial_delivery_code is 'Номер поставки завода производителя | Номер поставки завода производителя | delivery_document_position.delivery_document_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.initial_delivery_item_code is 'Позиция поставки | Позиция поставки | delivery_document_position.delivery_document_position_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.sales_market_code is 'Рынок сбыта (код) | Рынок сбыта, к которому относится страна потребителя | .';
comment on column dm_view.transportation_aluminium_shipment_from_plant.sales_market_name is 'Рынок сбыта, наименование | Название рынка сбыта, к которому относится страна потребителя | sales_order_market.market_in_sales_order_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_type_name is 'Тип ПС  | Тип ПС, нименование | transport_transfer_type.transport_transfer_type_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_vehicle_code is 'Номер транспортного средства | Номер транспортного средства | plant_delivery.railcar';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_bill_code is 'Номер накладной | Номер накладной | plant_delivery.railway_bill_number';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_bill_and_railcar_uni_code is 'Ж/д Накладная - №Вагона | Ж/д Накладная - №Вагона | plant_delivery.';
comment on column dm_view.transportation_aluminium_shipment_from_plant.dt_shipped is 'Дата отгрузки | Дата отгрузки | plant_delivery.dt_delivery';
comment on column dm_view.transportation_aluminium_shipment_from_plant.dt_shipped_yyyymm is 'Период отгрузки  | Период отгрузки MM.yyyy | plant_delivery.dt_delivery';
comment on column dm_view.transportation_aluminium_shipment_from_plant.route_shipping_code is 'Маршрут отгрузки (код) | Маршрут отгрузки (код) | plant_delivery.transport_route_code_plant';
comment on column dm_view.transportation_aluminium_shipment_from_plant.route_shipping_name is 'Маршрут отгрузки, название | Маршрут отгрузки, название | transport_route.transport_route_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_departure_hub_code is 'Узел  отправки (код) | Узел  отправки (код) | map_delivery_document_attributes_keys_ral.transport_departure_hub_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_departure_hub_name is 'Название узла отправки | Название узла отправки | transport_hub.transport_hub_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_destination_hub_code is 'Узел назначения (код) | Узел назначения (код) | map_delivery_document_attributes_keys_ral.transport_destination_hub_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_destination_hub_name is 'Название узла назначения | Название узла назначения | transport_hub.transport_hub_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.port_of_destination_code is 'Узел Порт назначения (код) | Узел Порт назначения (код) | map_delivery_document_attributes_keys_ral.port_of_destination_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.port_of_destination_name is 'Порт назначения | Порт назначения | transport_hub.transport_hub_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_border_cross_hub_code is 'Узел Погранпереход (код) | Узел Погранпереход (код) | map_delivery_document_attributes_keys_ral.transport_border_cross_hub_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_border_cross_hub_name is 'Название транспортного узла | Название транспортного узла | transport_hub.transport_hub_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.etsng_code is 'Код ЕТСНГ | Код ЕТСНГ | map_delivery_document_attributes_keys_ral.etsng_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.etsng_name is 'Код ЕТСНГ, наименование | Код ЕТСНГ, наименование | etsng.etsng_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.is_pickup_at_plant is 'Самовывоз | Признак Самовывоз | map_delivery_document_attributes_keys_ral.is_pickup_at_plant';
comment on column dm_view.transportation_aluminium_shipment_from_plant.material_code is 'Материал (код) | Материал (код) | map_delivery_document_attributes_keys_ral.material_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.material_name is 'Материал (Наименование) | Материал (Наименование) | material_texts.material_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.batch_code is 'Партия | Партия | delivery_document_position.batch_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.shape_code is 'Форма груза (код) | Форма груза (код) | material_specification.shape_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.shape_name is 'Форма груза (наименование) | Форма груза (наименование) | material_shape_texts.material_shape_full_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.sector_code is 'Сектор - группа материалов (код) | Сектор - группа материалов (код) | map_delivery_document_attributes_keys_ral.sector_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.sector_name is 'Сектор - группа материалов (наименование) | Сектор - группа материалов (наименование) | sb_unit_org_sector.sector_name_rus';
comment on column dm_view.transportation_aluminium_shipment_from_plant.grade_code is 'Марка металла (код) | Марка металла (код) | material_specification.grade_rusal_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.complected_train_code is 'Комплектность (код) | Комплектность (код) | map_delivery_document_attributes_keys_ral.complected_train_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.complected_train_name is 'Комплектность (наименование) | Комплектность (наименование) | railway_platform_completeness_type_texts.railway_platform_completeness_type_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.complected_train_quantity_index_code is 'Индекс кол-ва ПС (код) | Индекс кол-ва ПС (код) | map_delivery_document_attributes_keys_ral.complected_train_quantity_index_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.complected_train_quantity_index_name is 'Индекс кол-ва ПС (наименование) | Индекс кол-ва ПС (наименование) | dict_dds.railcar_quantity_index_texts.railcar_quantity_index_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.cargo_layout_scheme_code is 'Схема погрузки (код) | Схема погрузки (код) | sd_sales_main_scm.?';
comment on column dm_view.transportation_aluminium_shipment_from_plant.package_weight is 'Масса упаковки | Масса упаковки | /rusal/shipdata_ral.packing';
comment on column dm_view.transportation_aluminium_shipment_from_plant.sales_order_code is 'Заказ ЦК | Заказ ЦК | /rusal/shipdata_ral.sales_order_in_shipment_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.fixing_holder_weight is 'Масса реквизита | Масса реквизита | /rusal/shipdata_ral.rekvizit';
comment on column dm_view.transportation_aluminium_shipment_from_plant.customer_code is 'Покупатель (код) | Покупатель (код) | /rusal/shipdata_ral.customid';
comment on column dm_view.transportation_aluminium_shipment_from_plant.consignee_code is 'Грузополучатель (код) | Грузополучатель (код) | /rusal/shipdata_ral.firmapid';
comment on column dm_view.transportation_aluminium_shipment_from_plant.unit_dimension_code is 'Размеры | Размеры | /rusal/shipdata_ral.unit_dimension_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.cargo_layout_scheme_gross_plan_weight is 'Плановая загрузка с реквизитом | Плановая загрузка с реквизитом | /rusal/shipdata_ral.?';
comment on column dm_view.transportation_aluminium_shipment_from_plant.shipment_type_code is 'Вид отгрузки (код) | Вид отгрузки (код) | map_delivery_document_attributes_keys_ral.shipment_type_code';
comment on column dm_view.transportation_aluminium_shipment_from_plant.forward_kind_code is 'Вид экспедирования (код) | Вид экспедирования (код) | map_delivery_document_attributes_keys_ral.transport_route_kind';
comment on column dm_view.transportation_aluminium_shipment_from_plant.forwarder_at_railway_name is 'Экспедитор по ж/д | Экспедитор по ж/д, номенование | counterparty.counterparty_full_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_owner_name is 'Собственник ПС/Морской экспедитор | Собственник ПС/Морской экспедитор, наименование | counterparty.counterparty_full_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.forwarder_name is 'Экспедитор, наименование | Экспедитор, наименование | sales_batch_delivery.forwarder_name';
comment on column dm_view.transportation_aluminium_shipment_from_plant.is_transferrable_expenses is 'Возмещаемые/Невозмещ. Расходы | Признак Возмещаемые/Невозмещ. Расходы | map_delivery_document_attributes_keys_ral.refund_cost_sign';
comment on column dm_view.transportation_aluminium_shipment_from_plant.is_owned_by_rusal_code is 'Собственный ПС | Да, если ПС стоит на балансе компании | ZLE_SD3332M_DATA.HOME_VAGON';
comment on column dm_view.transportation_aluminium_shipment_from_plant.carrying_capacity_for_tariff_planning_weight is 'Грузоподъёмность для определения тарифа | Грузоподъёмность для определения тарифа | map_delivery_document_attributes_keys_ral.carrying_capacity_for_tariff_planning_weight';
comment on column dm_view.transportation_aluminium_shipment_from_plant.load_calculated_weight is 'Фактическая загрузка | Фактическая загрузка | map_delivery_document_attributes_keys_ral.load_calculated_weight';
comment on column dm_view.transportation_aluminium_shipment_from_plant.load_waybill_documented_weight is 'Фактическая загрузка по накладная-вагон | Фактическая загрузка по накладная-вагон | map_delivery_document_attributes_keys_ral.load_waybill_documented_weight';
comment on column dm_view.transportation_aluminium_shipment_from_plant.monthly_usd_rate is 'Курс фактический | Курс фактический type_code = M2 | currency_rate.currency_rate';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transport_total_cost_from_departure_station_rub_amount is 'Общая стоимость (без участка до ст.отпр.), руб | Провозная плата повагонная от ст.отпр., руб. + Плата за пользование, руб + Сбор за охрану от ст.отпр., руб RT | Сумма';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transportation_total_cost_from_plant_rub_amount is 'Общая стоимость (с участком до ст.отпр.), руб. | Провозная плата повагонная до ст.отпр., руб. + Провозная плата повагонная от ст.отпр., руб. + Плата за пользование, руб + Сбор за охрану от ст.отпр., руб RT | Сумма';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transportation_cost_to_departure_station_rub_amount is 'Провозная плата повагонная до ст.отпр., руб. | Провозная плата повагонная до ст.отпр., руб. | map_transportation_expenses_keys_ral.expense_rub_amount';
comment on column dm_view.transportation_aluminium_shipment_from_plant.transportation_cost_from_departure_station_rub_amount is 'Провозная плата повагонная от ст.отпр., руб. | Провозная плата повагонная от ст.отпр., руб. | map_transportation_expenses_keys_ral.';
comment on column dm_view.transportation_aluminium_shipment_from_plant.vehicle_usage_cost_rub_amount is 'Плата за пользование, руб. | Плата за пользование, руб. | map_transportation_expenses_keys_ral.';
comment on column dm_view.transportation_aluminium_shipment_from_plant.vehicle_usage_cost_document_currency_amount is 'Плата за пользование в вал.дог. | Плата за пользование в вал.дог. | map_transportation_expenses_keys_ral.';
comment on column dm_view.transportation_aluminium_shipment_from_plant.security_cost_to_departure_station_rub_amount is 'Сбор за охрану до ст.отпр., руб RT | Сбор за охрану до ст.отпр., руб RT | map_transportation_expenses_keys_ral.expense_rub_amount';
comment on column dm_view.transportation_aluminium_shipment_from_plant.security_cost_from_departure_station_rub_amount is 'Сбор за охрану от ст.отпр., руб RT | Сбор за охрану от ст.отпр., руб RT | map_transportation_expenses_keys_ral.expense_rub_amount';
comment on column dm_view.transportation_aluminium_shipment_from_plant.dt_updated is 'Дата и время последнего изменения на источнике | Дата и время последнего изменения на источнике | ZLE_SD3332M_DATA.CRDATE, CRTIME';
comment on column dm_view.transportation_aluminium_shipment_from_plant.is_relevant_transportation_aluminium_shipment_from_plant is 'Релевантность для отчета отгрузка с завода | Релевантность для отчета отгрузка с завода | Заполнение на основе условий выборки данных';

