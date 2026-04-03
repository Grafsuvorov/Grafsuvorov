drop table if exists dm.alverse_sales_life_cycle cascade;

create table if not exists dm.alverse_sales_life_cycle (
    customer_code varchar null,
    contract_code varchar null,
    delivery_code varchar null,
    delivery_position_code varchar null,
    created_by varchar null,
    document_type_name varchar null,
    document_status_name varchar null,
    unit_balance_code varchar null,
    unit_balance_currency_code varchar null,
    plant_producer_unit_balance_code varchar null,
    seller_unit_balance_code varchar null,
    customer_name varchar null,
    contract_producer_code varchar null,
    contract_producer_name varchar null,
    contract_trader_code varchar null,
    contract_trader_name varchar null,
    contract_external_number varchar null,
    contract_currency_code varchar null,
    contract_incoterms_code varchar null,
    vat_rate varchar null, -- numeric(13, 3)
    agent_contract_code varchar null,
    dt_posting date null,
    dt_currency_exchange_rate_for_payment date null,
    usd_exchange_rate_for_payment numeric(13, 3) null,
    payment_usd_amount numeric(13, 3) null,
    gnr_plant_short_eng_name varchar null,
    gnr_net_weight numeric(13, 3) null,
    gnr_weight_uom_code varchar null,
    gnr_revenue_document_currency_amount numeric(13, 3) null,
    dt_gnr_currency_translation_to_usd date null,
    gnr_revenue_currency_translation_to_usd_rate numeric(13, 3) null,
    gnr_revenue_local_currency_amount numeric(13, 3) null,
    gnr_local_currency_code varchar null,
    gnr_consignee_code varchar null,
    gnr_consignee_name varchar null,
    gnr_material_code varchar null,
    gnr_material_specification_name varchar null,
    gnr_material_aggr_name varchar null,
    clearing_status_code varchar null,
    gnr_contract_lme_qp_amount numeric(13, 3) null,
    gnr_contract_premium_amount numeric(13, 3) null,
    gnr_contract_premium_total_amount numeric(13, 3) null,
    is_edm_applicable_code varchar null,
    sr_trader_code varchar null,
    sr_sales_request_code varchar null,
    sr_plant_code varchar null,
    sr_plant_short_rus_name varchar null,
    sr_transport_type_code varchar null,
    sr_ingot_per_unit_net_weight varchar null, -- numeric(13, 3)
    sr_transportation_service_payed_by_code varchar null,
    sr_consignee_code varchar null,
    sr_consignee_name varchar null,
    dt_sr_quota_yyyymm varchar null,
    sr_created_by varchar null,
    sr_terms_of_payment_code varchar null,
    sr_terms_of_payment_name varchar null,
    dt_sr_payment date null,
    sr_remote_warehouse_shipment_forwarder_code varchar null,
    dt_si_shipment_instruction date null,
    si_incoterms_code varchar null,
    si_transportation_service_payed_by_name varchar null,
    od_unit_balance_owner_code varchar null,
    od_plant_owner_code varchar null,
    od_ownership_transfer_code varchar null,
    od_agency_contract_code varchar null,
    dt_od_outbound_delivery_created date null,
    dt_od_shipment_from_warehouse date null,
    dt_od_shipment_from_plant date null,
    dt_od_shipment_from_plant_plus5_days date null,
    dt_od_ownership_transfer date null,
    od_seller_code varchar null,
    od_transport_type_code varchar null,
    od_transport_vehicle_code varchar null,
    od_transport_capacity numeric(13, 3) null,
    od_transport_bill_code varchar null,
    od_material_attribute_text varchar null,
    dt_od_price date null,
    od_price_vat_excluded_amount numeric(13, 3) null,
    od_price_currency_code varchar null,
    od_transaction_currency_code varchar null,
    od_currency_translation_rate numeric(13, 3) null,
    od_weight_net_with_wirerod numeric(13, 3) null,
    od_initial_delivery_code varchar null,
    od_initial_delivery_position_code varchar null,
    od_inbound_delivery_code varchar null,
    od_batch_code varchar null,
    od_outbound_delivery_status_code varchar null,
    odp_entry_system_code varchar null,
    odp_local_currency_code varchar null,
    odp_second_local_currency_code varchar null,
    pr_payment_return_document_code varchar null,
    dt_pr_payment_return_document_yyyy varchar null,
    pr_document_reverse_code varchar null,
    dt_ri_realization_invoice date null,
    dt_ri_posting date null,
    ri_realization_invoice_code varchar null,
    ri_realization_invoice_agent_reverse_code varchar null,
    dt_ri_currency_translation_to_usd date null,
    ri_realization_invoice_external_number varchar null,
    ri_vat_code varchar null,
    ri_realization_invoice_comment_text varchar null,
    ai_unit_balance_code varchar null,
    dt_ai_agent_invoice date null,
    ai_agent_invoice_code varchar null,
    ai_agent_invoice_reverse_code varchar null,
    ai_contract_code varchar null,
    dt_ai_currency_translation_to_usd date null,
    ai_currency_translation_to_usd_rate numeric(13, 3) null,
    ai_agent_invoice_external_number varchar null,
    oi_accounting_document_code varchar null,
    oi_fiscal_year varchar null,
    oi_owner_invoice_code varchar null,
    oi_owner_invoice_position_code varchar null,
    dt_oi_currency_translation_to_usd date null,
    oi_owner_invoice_external_number varchar null,
    dt_oi_accounting_document date null,
    dt_oi_posting date null,
    di_deferred_invoice_code varchar null,
    di_accounting_document_code varchar null,
    di_accounting_document_reverse_code varchar null,
    di_deferred_invoice_external_number varchar null,
    dt_oi_owner_invoice_created date null,
    oi_currency_translation_to_usd_rate numeric(13, 3) null,
    oi_vat_included_rub_amount numeric(13, 3) null,
    oi_vat_included_usd_amount numeric(13, 3) null,
    edm_code varchar null,
    edm_status_code varchar null,
    dt_edm_status_last_updated date null,
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
distributed by (customer_code, contract_code, delivery_code, delivery_position_code);

comment on table dm.alverse_sales_life_cycle is 'Витрина данных по жизненному циклу отгрузки от заказа ЦК до фактуры собственника на основании данных транзакции ZFI3436M';
comment on column dm.alverse_sales_life_cycle.customer_code is 'Код покупателя в SAP, с которым заключен договор | Код покупателя в SAP, с которым заключен договор | ods.ral_map_alverse_sales_life_cycle.customer_code';
comment on column dm.alverse_sales_life_cycle.contract_code is 'Системный номер рамочного договора | Системный номер рамочного договора | ods.ral_map_alverse_sales_life_cycle.contract_code';
comment on column dm.alverse_sales_life_cycle.delivery_code is 'Системный номер исходящей поставки на отгрузку | Системный номер исходящей поставки на отгрузку | ods.ral_map_alverse_sales_life_cycle.delivery_code';
comment on column dm.alverse_sales_life_cycle.delivery_position_code is 'Позиция исходящей поставки на отгрузку | Позиция исходящей поставки на отгрузку | ods.ral_map_alverse_sales_life_cycle.delivery_position_code';
comment on column dm.alverse_sales_life_cycle.created_by is 'Имя пользователя, создавшего запись | Имя пользователя, создавшего запись | ods.ral_map_alverse_sales_life_cycle.created_by';
comment on column dm.alverse_sales_life_cycle.document_type_name is 'Бизнес-смысл созданного документа, выбор значений на основании таблицы /RUSAL/YY_DOCS | Бизнес-смысл созданного документа, выбор значений на основании таблицы /RUSAL/YY_DOCS | ods.ral_map_alverse_sales_life_cycle.document_type_name';
comment on column dm.alverse_sales_life_cycle.document_status_name is 'Статус созданного документа, выбор значений на основании таблицы /RUSAL/YY_DSTAT | Статус созданного документа, выбор значений на основании таблицы /RUSAL/YY_DSTAT | ods.ral_map_alverse_sales_life_cycle.document_status_name';
comment on column dm.alverse_sales_life_cycle.unit_balance_code is 'Балансовая единица (Юрлицо, с которым клиент заключил сбытовой контракт) | Балансовая единица (Юрлицо, с которым клиент заключил сбытовой контракт) | ods.ral_map_alverse_sales_life_cycle.unit_balance_code';
comment on column dm.alverse_sales_life_cycle.unit_balance_currency_code is 'Валюта балансовой единицы | Валюта балансовой единицы | ods.ral_map_alverse_sales_life_cycle.unit_balance_currency_code';
comment on column dm.alverse_sales_life_cycle.plant_producer_unit_balance_code is 'Значение БЕ для завода-производителя | Значение БЕ для завода-производителя | ods.ral_map_alverse_sales_life_cycle.plant_producer_unit_balance_code';
comment on column dm.alverse_sales_life_cycle.seller_unit_balance_code is 'Значение параметра SAPI10 из таблицы Дополнительные данные к БЕ | Значение параметра SAPI10 из таблицы Дополнительные данные к БЕ | ods.ral_map_alverse_sales_life_cycle.seller_unit_balance_code';
comment on column dm.alverse_sales_life_cycle.customer_name is 'Наименование покупателя из справочника дебиторов по коду покупателя | Наименование покупателя из справочника дебиторов по коду покупателя | ods.ral_map_alverse_sales_life_cycle.customer_name';
comment on column dm.alverse_sales_life_cycle.contract_producer_code is 'Системный номер договора на переработку завода с РА | Системный номер договора на переработку завода с РА | ods.ral_map_alverse_sales_life_cycle.contract_producer_code';
comment on column dm.alverse_sales_life_cycle.contract_producer_name is 'Бумажный номер договора на переработку завода с РА | Бумажный номер договора на переработку завода с РА | ods.ral_map_alverse_sales_life_cycle.contract_producer_name';
comment on column dm.alverse_sales_life_cycle.contract_trader_code is 'Табельный номер Трейдера из рамочного договора | Табельный номер Трейдера из рамочного договора | ods.ral_map_alverse_sales_life_cycle.contract_trader_code';
comment on column dm.alverse_sales_life_cycle.contract_trader_name is 'ФИО Трейдера из рамочного договора | ФИО Трейдера из рамочного договора | ods.ral_map_alverse_sales_life_cycle.contract_trader_name';
comment on column dm.alverse_sales_life_cycle.contract_external_number is 'Бумажный номер рамочного договора | Бумажный номер рамочного договора | ods.ral_map_alverse_sales_life_cycle.contract_external_number';
comment on column dm.alverse_sales_life_cycle.contract_currency_code is 'Валюта рамочного договора | Валюта рамочного договора | ods.ral_map_alverse_sales_life_cycle.contract_currency_code';
comment on column dm.alverse_sales_life_cycle.contract_incoterms_code is 'Условие поставки из рамочного договора | Условие поставки из рамочного договора | ods.ral_map_alverse_sales_life_cycle.contract_incoterms_code';
comment on column dm.alverse_sales_life_cycle.vat_rate is 'Процент НДС по налоговой классификации дебитора из рамочного договора | Процент НДС по налоговой классификации дебитора из рамочного договора | ods.ral_map_alverse_sales_life_cycle.vat_rate';
comment on column dm.alverse_sales_life_cycle.agent_contract_code is 'Системный номер агентского договора | Системный номер агентского договора | ods.ral_map_alverse_sales_life_cycle.agent_contract_code';
comment on column dm.alverse_sales_life_cycle.dt_posting is 'Дата операции в бухгалтерском учете | Дата операции в бухгалтерском учете | ods.ral_map_alverse_sales_life_cycle.dt_posting';
comment on column dm.alverse_sales_life_cycle.dt_currency_exchange_rate_for_payment is 'Дата курса для фактического платежа | Дата курса для фактического платежа | ods.ral_map_alverse_sales_life_cycle.dt_currency_exchange_rate_for_payment';
comment on column dm.alverse_sales_life_cycle.usd_exchange_rate_for_payment is 'Курс USD для фактического платежа на дату курса | Курс USD для фактического платежа на дату курса | ods.ral_map_alverse_sales_life_cycle.usd_exchange_rate_for_payment';
comment on column dm.alverse_sales_life_cycle.payment_usd_amount is 'Сумма фактического платежа в USD | Сумма фактического платежа в USD | ods.ral_map_alverse_sales_life_cycle.payment_usd_amount';
comment on column dm.alverse_sales_life_cycle.gnr_plant_short_eng_name is 'Системный буквенный код завода из заказа ЦК | Системный буквенный код завода из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.gnr_plant_short_eng_name';
comment on column dm.alverse_sales_life_cycle.gnr_net_weight is 'Плановое количество из заказа ЦК/фактически отгруженное количество в зависимости от статуса документа | Плановое количество из заказа ЦК/фактически отгруженное количество в зависимости от статуса документа | ods.ral_map_alverse_sales_life_cycle.gnr_net_weight';
comment on column dm.alverse_sales_life_cycle.gnr_weight_uom_code is 'Единица изменения планового количества из заказа ЦК/фактически отгруженного количества в зависимости от статуса документа | Единица изменения планового количества из заказа ЦК/фактически отгруженного количества в зависимости от статуса документа | ods.ral_map_alverse_sales_life_cycle.gnr_weight_uom_code';
comment on column dm.alverse_sales_life_cycle.gnr_revenue_document_currency_amount is 'Сумма фактически отгруженного количества в валюте отгрузки | Сумма фактически отгруженного количества в валюте отгрузки | ods.ral_map_alverse_sales_life_cycle.gnr_revenue_document_currency_amount';
comment on column dm.alverse_sales_life_cycle.dt_gnr_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD | Дата пересчета суммы отгрузки в USD | ods.ral_map_alverse_sales_life_cycle.dt_gnr_currency_translation_to_usd';
comment on column dm.alverse_sales_life_cycle.gnr_revenue_currency_translation_to_usd_rate is 'Курс пересчета суммы отгрузки в USD | Курс пересчета суммы отгрузки в USD | ods.ral_map_alverse_sales_life_cycle.gnr_revenue_currency_translation_to_usd_rate';
comment on column dm.alverse_sales_life_cycle.gnr_revenue_local_currency_amount is 'Сумма фактически отгруженного количества в валюте БЕ | Сумма фактически отгруженного количества в валюте БЕ | ods.ral_map_alverse_sales_life_cycle.gnr_revenue_local_currency_amount';
comment on column dm.alverse_sales_life_cycle.gnr_local_currency_code is 'Внутренняя валюта HWAER | Внутренняя валюта HWAER | ods.ral_map_alverse_sales_life_cycle.gnr_local_currency_code';
comment on column dm.alverse_sales_life_cycle.gnr_consignee_code is 'Код грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | Код грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | ods.ral_map_alverse_sales_life_cycle.gnr_consignee_code';
comment on column dm.alverse_sales_life_cycle.gnr_consignee_name is 'Наименование грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | Наименование грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | ods.ral_map_alverse_sales_life_cycle.gnr_consignee_name';
comment on column dm.alverse_sales_life_cycle.gnr_material_code is 'Системный номер материала из заказа ЦК/распоряжения/поставки в зависимости от статуса документа | Системный номер материала из заказа ЦК/распоряжения/поставки в зависимости от статуса документа | ods.ral_map_alverse_sales_life_cycle.gnr_material_code';
comment on column dm.alverse_sales_life_cycle.gnr_material_specification_name is 'Текст спецификации из заказа ЦК/распоряжения в зависимости от статуса документа | Текст спецификации из заказа ЦК/распоряжения в зависимости от статуса документа | ods.ral_map_alverse_sales_life_cycle.gnr_material_specification_name';
comment on column dm.alverse_sales_life_cycle.gnr_material_aggr_name is 'Текст признака Материал таблицы Связь ОЗМ с названиями марок и спецификациями по коду материала | Текст признака Материал таблицы Связь ОЗМ с названиями марок и спецификациями по коду материала | ods.ral_map_alverse_sales_life_cycle.gnr_material_aggr_name';
comment on column dm.alverse_sales_life_cycle.clearing_status_code is 'Статус фактурирования и выравнивания счета | Статус фактурирования и выравнивания счета | ods.ral_map_alverse_sales_life_cycle.clearing_status_code';
comment on column dm.alverse_sales_life_cycle.gnr_contract_lme_qp_amount is 'Цена металла на London Metal Exchange относительно котировочного периода в ценовом приложении | Цена металла на London Metal Exchange относительно котировочного периода в ценовом приложении | ods.ral_map_alverse_sales_life_cycle.gnr_contract_lme_qp_amount';
comment on column dm.alverse_sales_life_cycle.gnr_contract_premium_amount is 'Продуктовая скидка/надбавка относительно котировочного периода в ценовом приложении | Продуктовая скидка/надбавка относительно котировочного периода в ценовом приложении | ods.ral_map_alverse_sales_life_cycle.gnr_contract_premium_amount';
comment on column dm.alverse_sales_life_cycle.gnr_contract_premium_total_amount is 'Сумма премий/надбавок в ценовом приложении | Сумма премий/надбавок в ценовом приложении | ods.ral_map_alverse_sales_life_cycle.gnr_contract_premium_total_amount';
comment on column dm.alverse_sales_life_cycle.is_edm_applicable_code is 'Признак, что документ участвует в ЭДО | Признак, что документ участвует в ЭДО | ods.ral_map_alverse_sales_life_cycle.is_edm_applicable_code';
comment on column dm.alverse_sales_life_cycle.sr_trader_code is 'Табельный номер Трейдера из заказа ЦК | Табельный номер Трейдера из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_trader_code';
comment on column dm.alverse_sales_life_cycle.sr_sales_request_code is 'Системный номер заказа ЦК | Системный номер заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_sales_request_code';
comment on column dm.alverse_sales_life_cycle.sr_plant_code is 'Системный цифровой код завода из заказа ЦК | Системный цифровой код завода из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_plant_code';
comment on column dm.alverse_sales_life_cycle.sr_plant_short_rus_name is 'Короткое наименование завода из заказа ЦК | Короткое наименование завода из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_plant_short_rus_name';
comment on column dm.alverse_sales_life_cycle.sr_transport_type_code is 'Вид транспортного средства из заказа ЦК | Вид транспортного средства из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_transport_type_code';
comment on column dm.alverse_sales_life_cycle.sr_ingot_per_unit_net_weight is 'Вес чушки из заказа ЦК | Вес чушки из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_ingot_per_unit_net_weight';
comment on column dm.alverse_sales_life_cycle.sr_transportation_service_payed_by_code is 'Данные о том, кто платит перевозчику из заказа ЦК | Данные о том, кто платит перевозчику из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_transportation_service_payed_by_code';
comment on column dm.alverse_sales_life_cycle.sr_consignee_code is 'Код грузополучателя из заказа ЦК | Код грузополучателя из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_consignee_code';
comment on column dm.alverse_sales_life_cycle.sr_consignee_name is 'Наименование грузополучателя из заказа ЦК | Наименование грузополучателя из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_consignee_name';
comment on column dm.alverse_sales_life_cycle.dt_sr_quota_yyyymm is 'Период квоты из заказа ЦК | Период квоты из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.dt_sr_quota_yyyymm';
comment on column dm.alverse_sales_life_cycle.sr_created_by is 'Логин создавшего заказ ЦК | Логин создавшего заказ ЦК | ods.ral_map_alverse_sales_life_cycle.sr_created_by';
comment on column dm.alverse_sales_life_cycle.sr_terms_of_payment_code is 'Код условия платежа из заказа ЦК | Код условия платежа из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_terms_of_payment_code';
comment on column dm.alverse_sales_life_cycle.sr_terms_of_payment_name is 'Наименование условия платежа из заказа ЦК | Наименование условия платежа из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.sr_terms_of_payment_name';
comment on column dm.alverse_sales_life_cycle.dt_sr_payment is 'Дата платежа из заказа ЦК | Дата платежа из заказа ЦК | ods.ral_map_alverse_sales_life_cycle.dt_sr_payment';
comment on column dm.alverse_sales_life_cycle.sr_remote_warehouse_shipment_forwarder_code is 'Грузоотправитель на удаленный склад из заказа ЦК (заполняется при отправке на удаленный склад) | Грузоотправитель на удаленный склад из заказа ЦК (заполняется при отправке на удаленный склад) | ods.ral_map_alverse_sales_life_cycle.sr_remote_warehouse_shipment_forwarder_code';
comment on column dm.alverse_sales_life_cycle.dt_si_shipment_instruction is 'Дата создания распоряжения на отгрузку | Дата создания распоряжения на отгрузку | ods.ral_map_alverse_sales_life_cycle.dt_si_shipment_instruction';
comment on column dm.alverse_sales_life_cycle.si_incoterms_code is 'Условие поставки из распоряжения на отгрузку | Условие поставки из распоряжения на отгрузку | ods.ral_map_alverse_sales_life_cycle.si_incoterms_code';
comment on column dm.alverse_sales_life_cycle.si_transportation_service_payed_by_name is 'Данные о том, кто платит перевозчику из распоряжения на отгрузку | Данные о том, кто платит перевозчику из распоряжения на отгрузку | ods.ral_map_alverse_sales_life_cycle.si_transportation_service_payed_by_name';
comment on column dm.alverse_sales_life_cycle.od_unit_balance_owner_code is 'Код балансовой единицы собственника | Код балансовой единицы собственника | ods.ral_map_alverse_sales_life_cycle.od_unit_balance_owner_code';
comment on column dm.alverse_sales_life_cycle.od_plant_owner_code is 'Системный код завода собственника | Системный код завода собственника | ods.ral_map_alverse_sales_life_cycle.od_plant_owner_code';
comment on column dm.alverse_sales_life_cycle.od_ownership_transfer_code is 'Системный код перехода права собственности | Системный код перехода права собственности | ods.ral_map_alverse_sales_life_cycle.od_ownership_transfer_code';
comment on column dm.alverse_sales_life_cycle.od_agency_contract_code is 'Системный номер агентского договора | Системный номер агентского договора | ods.ral_map_alverse_sales_life_cycle.od_agency_contract_code';
comment on column dm.alverse_sales_life_cycle.dt_od_outbound_delivery_created is 'Дата создания исходящей поставки на отгрузку | Дата создания исходящей поставки на отгрузку | ods.ral_map_alverse_sales_life_cycle.dt_od_outbound_delivery_created';
comment on column dm.alverse_sales_life_cycle.dt_od_shipment_from_warehouse is 'Дата отгрузки со склада клиенту из исходящей поставки | Дата отгрузки со склада клиенту из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.dt_od_shipment_from_warehouse';
comment on column dm.alverse_sales_life_cycle.dt_od_shipment_from_plant is 'Дата отгрузки с завода из исходящей поставки | Дата отгрузки с завода из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.dt_od_shipment_from_plant';
comment on column dm.alverse_sales_life_cycle.dt_od_shipment_from_plant_plus5_days is 'Дата отгрузки с завода плюс 5 дней | Дата отгрузки с завода плюс 5 дней | ods.ral_map_alverse_sales_life_cycle.dt_od_shipment_from_plant_plus5_days';
comment on column dm.alverse_sales_life_cycle.dt_od_ownership_transfer is 'Дата перехода права собственности из исходящей поставки | Дата перехода права собственности из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.dt_od_ownership_transfer';
comment on column dm.alverse_sales_life_cycle.od_seller_code is 'Значение параметра SAPI10 из таблицы Дополнительные данные к БЕ для БЕ собственника | Значение параметра SAPI10 из таблицы Дополнительные данные к БЕ для БЕ собственника | ods.ral_map_alverse_sales_life_cycle.od_seller_code';
comment on column dm.alverse_sales_life_cycle.od_transport_type_code is 'Вид транспортного средства из исходящей поставки | Вид транспортного средства из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.od_transport_type_code';
comment on column dm.alverse_sales_life_cycle.od_transport_vehicle_code is 'Номер транспортного средства из исходящей поставки | Номер транспортного средства из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.od_transport_vehicle_code';
comment on column dm.alverse_sales_life_cycle.od_transport_capacity is 'Грузоподъемность транспортного средства из исходящей поставки | Грузоподъемность транспортного средства из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.od_transport_capacity';
comment on column dm.alverse_sales_life_cycle.od_transport_bill_code is 'Номер накладной из исходящей поставки | Номер накладной из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.od_transport_bill_code';
comment on column dm.alverse_sales_life_cycle.od_material_attribute_text is 'Марка, форма, размер из спецификации материала из исходящей поставки | Марка, форма, размер из спецификации материала из исходящей поставки | ods.ral_map_alverse_sales_life_cycle.od_material_attribute_text';
comment on column dm.alverse_sales_life_cycle.dt_od_price is 'Дата цены | Дата цены | ods.ral_map_alverse_sales_life_cycle.dt_od_price';
comment on column dm.alverse_sales_life_cycle.od_price_vat_excluded_amount is 'Цена без НДС | Цена без НДС | ods.ral_map_alverse_sales_life_cycle.od_price_vat_excluded_amount';
comment on column dm.alverse_sales_life_cycle.od_price_currency_code is 'Валюта цены | Валюта цены | ods.ral_map_alverse_sales_life_cycle.od_price_currency_code';
comment on column dm.alverse_sales_life_cycle.od_transaction_currency_code is 'Валюта операции | Валюта операции | ods.ral_map_alverse_sales_life_cycle.od_transaction_currency_code';
comment on column dm.alverse_sales_life_cycle.od_currency_translation_rate is 'Курс пересчета цены из валюты цены в валюту документа | Курс пересчета цены из валюты цены в валюту документа | ods.ral_map_alverse_sales_life_cycle.od_currency_translation_rate';
comment on column dm.alverse_sales_life_cycle.od_weight_net_with_wirerod is 'Вес нетто + катанка | Вес нетто + катанка | ods.ral_map_alverse_sales_life_cycle.od_weight_net_with_wirerod';
comment on column dm.alverse_sales_life_cycle.od_initial_delivery_code is 'Номер исходящей поставки завода производителя | Номер исходящей поставки завода производителя | ods.ral_map_alverse_sales_life_cycle.od_initial_delivery_code';
comment on column dm.alverse_sales_life_cycle.od_initial_delivery_position_code is 'Позиция исходящей поставки завода производителя | Позиция исходящей поставки завода производителя | ods.ral_map_alverse_sales_life_cycle.od_initial_delivery_position_code';
comment on column dm.alverse_sales_life_cycle.od_inbound_delivery_code is 'Номер входящей поставки | Номер входящей поставки | ods.ral_map_alverse_sales_life_cycle.od_inbound_delivery_code';
comment on column dm.alverse_sales_life_cycle.od_batch_code is 'Номер партии | Номер партии | ods.ral_map_alverse_sales_life_cycle.od_batch_code';
comment on column dm.alverse_sales_life_cycle.od_outbound_delivery_status_code is 'Статус поставки | Статус поставки | ods.ral_map_alverse_sales_life_cycle.od_outbound_delivery_status_code';
comment on column dm.alverse_sales_life_cycle.odp_entry_system_code is 'Номер записи в таблице привязки плановых платежей и фактической отгрузки | Номер записи в таблице привязки плановых платежей и фактической отгрузки | ods.ral_map_alverse_sales_life_cycle.odp_entry_system_code';
comment on column dm.alverse_sales_life_cycle.odp_local_currency_code is 'Внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | Внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | ods.ral_map_alverse_sales_life_cycle.odp_local_currency_code';
comment on column dm.alverse_sales_life_cycle.odp_second_local_currency_code is 'Вторая внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | Вторая внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | ods.ral_map_alverse_sales_life_cycle.odp_second_local_currency_code';
comment on column dm.alverse_sales_life_cycle.pr_payment_return_document_code is 'Номер документа возврата платежа | Номер документа возврата платежа | ods.ral_map_alverse_sales_life_cycle.pr_payment_return_document_code';
comment on column dm.alverse_sales_life_cycle.dt_pr_payment_return_document_yyyy is 'Год документа возврата платежа | Год документа возврата платежа | ods.ral_map_alverse_sales_life_cycle.dt_pr_payment_return_document_yyyy';
comment on column dm.alverse_sales_life_cycle.pr_document_reverse_code is 'Номер сторно документа возврата платежа | Номер сторно документа возврата платежа | ods.ral_map_alverse_sales_life_cycle.pr_document_reverse_code';
comment on column dm.alverse_sales_life_cycle.dt_ri_realization_invoice is 'Дата бухгалтерского документа фактуры реализации | Дата бухгалтерского документа фактуры реализации | ods.ral_map_alverse_sales_life_cycle.dt_ri_realization_invoice';
comment on column dm.alverse_sales_life_cycle.dt_ri_posting is 'Дата проводки бухгалтерского документа фактуры реализации | Дата проводки бухгалтерского документа фактуры реализации | ods.ral_map_alverse_sales_life_cycle.dt_ri_posting';
comment on column dm.alverse_sales_life_cycle.ri_realization_invoice_code is 'Номер фактуры реализации | Номер фактуры реализации | ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_code';
comment on column dm.alverse_sales_life_cycle.ri_realization_invoice_agent_reverse_code is 'Номер документа сторно фактуры агента | Номер документа сторно фактуры агента | ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_agent_reverse_code';
comment on column dm.alverse_sales_life_cycle.dt_ri_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD для фактуры реализации | Дата пересчета суммы отгрузки в USD для фактуры реализации | ods.ral_map_alverse_sales_life_cycle.dt_ri_currency_translation_to_usd';
comment on column dm.alverse_sales_life_cycle.ri_realization_invoice_external_number is 'Бумажный номер фактуры реализации | Бумажный номер фактуры реализации | ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_external_number';
comment on column dm.alverse_sales_life_cycle.ri_vat_code is 'Код налога НДС из фактуры реализации | Код налога НДС из фактуры реализации | ods.ral_map_alverse_sales_life_cycle.ri_vat_code';
comment on column dm.alverse_sales_life_cycle.ri_realization_invoice_comment_text is 'Текст из фактуры реализации | Текст из фактуры реализации | ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_comment_text';
comment on column dm.alverse_sales_life_cycle.ai_unit_balance_code is 'Балансовая единица из фактуры агента | Балансовая единица из фактуры агента | ods.ral_map_alverse_sales_life_cycle.ai_unit_balance_code';
comment on column dm.alverse_sales_life_cycle.dt_ai_agent_invoice is 'Дата бухгалтерского документа фактуры агента | Дата бухгалтерского документа фактуры агента | ods.ral_map_alverse_sales_life_cycle.dt_ai_agent_invoice';
comment on column dm.alverse_sales_life_cycle.ai_agent_invoice_code is 'Номер фактуры агента | Номер фактуры агента | ods.ral_map_alverse_sales_life_cycle.ai_agent_invoice_code';
comment on column dm.alverse_sales_life_cycle.ai_agent_invoice_reverse_code is 'Номер документа сторно фактуры агента | Номер документа сторно фактуры агента | ods.ral_map_alverse_sales_life_cycle.ai_agent_invoice_reverse_code';
comment on column dm.alverse_sales_life_cycle.ai_contract_code is 'Номер договора с покупателем из фактуры агента | Номер договора с покупателем из фактуры агента | ods.ral_map_alverse_sales_life_cycle.ai_contract_code';
comment on column dm.alverse_sales_life_cycle.dt_ai_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD для фактуры агента | Дата пересчета суммы отгрузки в USD для фактуры агента | ods.ral_map_alverse_sales_life_cycle.dt_ai_currency_translation_to_usd';
comment on column dm.alverse_sales_life_cycle.ai_currency_translation_to_usd_rate is 'Курс пересчета суммы отгрузки в USD для фактуры агента | Курс пересчета суммы отгрузки в USD для фактуры агента | ods.ral_map_alverse_sales_life_cycle.ai_currency_translation_to_usd_rate';
comment on column dm.alverse_sales_life_cycle.ai_agent_invoice_external_number is 'Бумажный номер фактуры агента | Бумажный номер фактуры агента | ods.ral_map_alverse_sales_life_cycle.ai_agent_invoice_external_number';
comment on column dm.alverse_sales_life_cycle.oi_accounting_document_code is 'Номер бухгалтерского документа фактуры собственника | Номер бухгалтерского документа фактуры собственника | ods.ral_map_alverse_sales_life_cycle.oi_accounting_document_code';
comment on column dm.alverse_sales_life_cycle.oi_fiscal_year is 'Год бухгалтерского документа фактуры собственника | Год бухгалтерского документа фактуры собственника | ods.ral_map_alverse_sales_life_cycle.oi_fiscal_year';
comment on column dm.alverse_sales_life_cycle.oi_owner_invoice_code is 'Системный номер фактуры собственника | Системный номер фактуры собственника | ods.ral_map_alverse_sales_life_cycle.oi_owner_invoice_code';
comment on column dm.alverse_sales_life_cycle.oi_owner_invoice_position_code is 'Системный номер позиции фактуры собственника | Системный номер позиции фактуры собственника | ods.ral_map_alverse_sales_life_cycle.oi_owner_invoice_position_code';
comment on column dm.alverse_sales_life_cycle.dt_oi_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD для фактуры собственника | Дата пересчета суммы отгрузки в USD для фактуры собственника | ods.ral_map_alverse_sales_life_cycle.dt_oi_currency_translation_to_usd';
comment on column dm.alverse_sales_life_cycle.oi_owner_invoice_external_number is 'Бумажный номер фактуры собственника | Бумажный номер фактуры собственника | ods.ral_map_alverse_sales_life_cycle.oi_owner_invoice_external_number';
comment on column dm.alverse_sales_life_cycle.dt_oi_accounting_document is 'Дата бухгалтерского документа фактуры собственника | Дата бухгалтерского документа фактуры собственника | ods.ral_map_alverse_sales_life_cycle.dt_oi_accounting_document';
comment on column dm.alverse_sales_life_cycle.dt_oi_posting is 'Дата проводки из бухгалтерского документа фактуры собственника | Дата проводки из бухгалтерского документа фактуры собственника | ods.ral_map_alverse_sales_life_cycle.dt_oi_posting';
comment on column dm.alverse_sales_life_cycle.di_deferred_invoice_code is 'Системный номер фактуры на отложенную реализацию | Системный номер фактуры на отложенную реализацию | ods.ral_map_alverse_sales_life_cycle.di_deferred_invoice_code';
comment on column dm.alverse_sales_life_cycle.di_accounting_document_code is 'Номер бухгалтерского документа фактуры на отложенную реализацию | Номер бухгалтерского документа фактуры на отложенную реализацию | ods.ral_map_alverse_sales_life_cycle.di_accounting_document_code';
comment on column dm.alverse_sales_life_cycle.di_accounting_document_reverse_code is 'Номер сторно бухгалтерского документа фактуры на отложенную реализацию | Номер сторно бухгалтерского документа фактуры на отложенную реализацию | ods.ral_map_alverse_sales_life_cycle.di_accounting_document_reverse_code';
comment on column dm.alverse_sales_life_cycle.di_deferred_invoice_external_number is 'Бумажный номер фактуры на отложенную реализацию | Бумажный номер фактуры на отложенную реализацию | ods.ral_map_alverse_sales_life_cycle.di_deferred_invoice_external_number';
comment on column dm.alverse_sales_life_cycle.dt_oi_owner_invoice_created is 'Дата создания фактуры собственника | Дата создания фактуры собственника | ods.ral_map_alverse_sales_life_cycle.dt_oi_owner_invoice_created';
comment on column dm.alverse_sales_life_cycle.oi_currency_translation_to_usd_rate is 'Курс из фактуры собственника | Курс из фактуры собственника | ods.ral_map_alverse_sales_life_cycle.oi_currency_translation_to_usd_rate';
comment on column dm.alverse_sales_life_cycle.oi_vat_included_rub_amount is 'Сумма фактуры собственника с НДС в рублях | Сумма фактуры собственника с НДС в рублях | ods.ral_map_alverse_sales_life_cycle.oi_vat_included_rub_amount';
comment on column dm.alverse_sales_life_cycle.oi_vat_included_usd_amount is 'Сумма фактуры собственника с НДС в долларах | Сумма фактуры собственника с НДС в долларах | ods.ral_map_alverse_sales_life_cycle.oi_vat_included_usd_amount';
comment on column dm.alverse_sales_life_cycle.edm_code is 'Системный номер документа ЭДО | Системный номер документа ЭДО | ods.ral_map_alverse_sales_life_cycle.edm_code';
comment on column dm.alverse_sales_life_cycle.edm_status_code is 'Статус документа ЭДО | Статус документа ЭДО | ods.ral_map_alverse_sales_life_cycle.edm_status_code';
comment on column dm.alverse_sales_life_cycle.dt_edm_status_last_updated is 'Дата последнего изменения статуса документа ЭДО | Дата последнего изменения статуса документа ЭДО | ods.ral_map_alverse_sales_life_cycle.dt_edm_status_last_updated';
