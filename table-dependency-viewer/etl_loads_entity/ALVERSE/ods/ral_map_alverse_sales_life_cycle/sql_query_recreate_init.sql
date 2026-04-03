drop table if exists ods.ral_map_alverse_sales_life_cycle cascade;

create table if not exists ods.ral_map_alverse_sales_life_cycle (
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
    vat_rate varchar null, -- numeric(3, 3)?
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
    sr_ingot_per_unit_net_weight varchar null, -- numeric(13, 3)?
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

comment on table ods.ral_map_alverse_sales_life_cycle is 'Витрина данных по жизненному циклу отгрузки от заказа ЦК до фактуры собственника на основании данных транзакции ZFI3436M';
comment on column ods.ral_map_alverse_sales_life_cycle.customer_code is 'Код покупателя в SAP, с которым заключен договор | Код покупателя в SAP, с которым заключен договор | stg."ZFI3436M_BI"."KUNNRKEY"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_code is 'Системный номер рамочного договора | Системный номер рамочного договора | stg."ZFI3436M_BI"."VERTNKEY"';
comment on column ods.ral_map_alverse_sales_life_cycle.delivery_code is 'Системный номер исходящей поставки на отгрузку | Системный номер исходящей поставки на отгрузку | stg."ZFI3436M_BI"."FO_VBELN_KEY"';
comment on column ods.ral_map_alverse_sales_life_cycle.delivery_position_code is 'Позиция исходящей поставки на отгрузку | Позиция исходящей поставки на отгрузку | stg."ZFI3436M_BI"."FO_POSNR_KEY"';
comment on column ods.ral_map_alverse_sales_life_cycle.created_by is 'Имя пользователя, создавшего запись | Имя пользователя, создавшего запись | stg."ZFI3436M_BI"."USNAM"';
comment on column ods.ral_map_alverse_sales_life_cycle.document_type_name is 'Бизнес-смысл созданного документа, выбор значений на основании таблицы /RUSAL/YY_DOCS | Бизнес-смысл созданного документа, выбор значений на основании таблицы /RUSAL/YY_DOCS | stg."ZFI3436M_BI"."D_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.document_status_name is 'Статус созданного документа, выбор значений на основании таблицы /RUSAL/YY_DSTAT | Статус созданного документа, выбор значений на основании таблицы /RUSAL/YY_DSTAT | stg."ZFI3436M_BI"."D_STATUS"';
comment on column ods.ral_map_alverse_sales_life_cycle.unit_balance_code is 'Балансовая единица (Юрлицо, с которым клиент заключил сбытовой контракт) | Балансовая единица (Юрлицо, с которым клиент заключил сбытовой контракт) | stg."ZFI3436M_BI"."BUKRS"';
comment on column ods.ral_map_alverse_sales_life_cycle.unit_balance_currency_code is 'Валюта балансовой единицы | Валюта балансовой единицы | stg."ZFI3436M_BI"."BUKRS_WAERS"';
comment on column ods.ral_map_alverse_sales_life_cycle.plant_producer_unit_balance_code is 'Значение БЕ для завода-производителя | Значение БЕ для завода-производителя | stg."ZFI3436M_BI"."BUKRS_PR"';
comment on column ods.ral_map_alverse_sales_life_cycle.seller_unit_balance_code is 'Значение параметра SAPI10 из таблицы "Дополнительные данные к БЕ" | Значение параметра SAPI10 из таблицы "Дополнительные данные к БЕ" | stg."ZFI3436M_BI"."BUKRS_LIFNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.customer_name is 'Наименование покупателя из справочника дебиторов по коду покупателя | Наименование покупателя из справочника дебиторов по коду покупателя | stg."ZFI3436M_BI"."NAME_KUNNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_producer_code is 'Системный номер договора на переработку завода с РА | Системный номер договора на переработку завода с РА | stg."ZFI3436M_BI"."VERTN_PR"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_producer_name is 'Бумажный номер договора на переработку завода с РА | Бумажный номер договора на переработку завода с РА | stg."ZFI3436M_BI"."VERTN_PR_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_trader_code is 'Табельный номер Трейдера из рамочного договора | Табельный номер Трейдера из рамочного договора | stg."ZFI3436M_BI"."TRADER"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_trader_name is 'ФИО Трейдера из рамочного договора | ФИО Трейдера из рамочного договора | stg."ZFI3436M_BI"."TRADER_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_external_number is 'Бумажный номер рамочного договора | Бумажный номер рамочного договора | stg."ZFI3436M_BI"."NAME_VERTN"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_currency_code is 'Валюта рамочного договора | Валюта рамочного договора | stg."ZFI3436M_BI"."WAERS"';
comment on column ods.ral_map_alverse_sales_life_cycle.contract_incoterms_code is 'Условие поставки из рамочного договора | Условие поставки из рамочного договора | stg."ZFI3436M_BI"."INCO1"';
comment on column ods.ral_map_alverse_sales_life_cycle.vat_rate is 'Процент НДС по налоговой классификации дебитора из рамочного договора | Процент НДС по налоговой классификации дебитора из рамочного договора | stg."ZFI3436M_BI"."PROC_NDS"';
comment on column ods.ral_map_alverse_sales_life_cycle.agent_contract_code is 'Системный номер агентского договора | Системный номер агентского договора | stg."ZFI3436M_BI"."VERTN_S"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_posting is 'Дата операции в бухгалтерском учете | Дата операции в бухгалтерском учете | stg."ZFI3436M_BI"."BUDAT_BY"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_currency_exchange_rate_for_payment is 'Дата курса для фактического платежа | Дата курса для фактического платежа | stg."ZFI3436M_BI"."DATE_RATE"';
comment on column ods.ral_map_alverse_sales_life_cycle.usd_exchange_rate_for_payment is 'Курс USD для фактического платежа на дату курса | Курс USD для фактического платежа на дату курса | stg."ZFI3436M_BI"."USD_RATE"';
comment on column ods.ral_map_alverse_sales_life_cycle.payment_usd_amount is 'Сумма фактического платежа в USD | Сумма фактического платежа в USD | stg."ZFI3436M_BI"."SUMM_PAY"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_plant_short_eng_name is 'Системный буквенный код завода из заказа ЦК | Системный буквенный код завода из заказа ЦК | stg."ZFI3436M_BI"."ZAVOD"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_net_weight is 'Плановое количество из заказа ЦК/фактически отгруженное количество в зависимости от статуса документа | Плановое количество из заказа ЦК/фактически отгруженное количество в зависимости от статуса документа | stg."ZFI3436M_BI"."LFIMG"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_weight_uom_code is 'Единица изменения планового количества из заказа ЦК/фактически отгруженного количества в зависимости от статуса документа | Единица изменения планового количества из заказа ЦК/фактически отгруженного количества в зависимости от статуса документа | stg."ZFI3436M_BI"."VRKME"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_revenue_document_currency_amount is 'Сумма фактически отгруженного количества в валюте отгрузки | Сумма фактически отгруженного количества в валюте отгрузки | stg."ZFI3436M_BI"."O_WRBTR"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_gnr_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD | Дата пересчета суммы отгрузки в USD | stg."ZFI3436M_BI"."WWERT"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_revenue_currency_translation_to_usd_rate is 'Курс пересчета суммы отгрузки в USD | Курс пересчета суммы отгрузки в USD | stg."ZFI3436M_BI"."KURSF"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_revenue_local_currency_amount is 'Сумма фактически отгруженного количества в валюте БЕ | Сумма фактически отгруженного количества в валюте БЕ | stg."ZFI3436M_BI"."O_DMBTR"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_local_currency_code is 'Внутренняя валюта HWAER | Внутренняя валюта HWAER | stg."ZFI3436M_BI"."HWAER"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_consignee_code is 'Код грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | Код грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | stg."ZFI3436M_BI"."GRUZPOL"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_consignee_name is 'Наименование грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | Наименование грузополучателя из заказа ЦК/распоряжения в зависимости от статуса документа | stg."ZFI3436M_BI"."GRUZPOL_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_material_code is 'Системный номер материала из заказа ЦК/распоряжения/поставки в зависимости от статуса документа | Системный номер материала из заказа ЦК/распоряжения/поставки в зависимости от статуса документа | stg."ZFI3436M_BI"."MATNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_material_specification_name is 'Текст спецификации из заказа ЦК/распоряжения в зависимости от статуса документа | Текст спецификации из заказа ЦК/распоряжения в зависимости от статуса документа | stg."ZFI3436M_BI"."NSPECIF"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_material_aggr_name is 'Текст признака "Материал" таблицы "Связь ОЗМ с названиями марок и спецификациями" по коду материала | Текст признака "Материал" таблицы "Связь ОЗМ с названиями марок и спецификациями" по коду материала | stg."ZFI3436M_BI"."PIMARY"';
comment on column ods.ral_map_alverse_sales_life_cycle.clearing_status_code is 'Статус фактурирования и выравнивания счета | Статус фактурирования и выравнивания счета | stg."ZFI3436M_BI"."VR_STATUS"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_contract_lme_qp_amount is 'Цена металла на London Metal Exchange относительно котировочного периода в ценовом приложении | Цена металла на London Metal Exchange относительно котировочного периода в ценовом приложении | stg."ZFI3436M_BI"."LME"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_contract_premium_amount is 'Продуктовая скидка/надбавка относительно котировочного периода в ценовом приложении | Продуктовая скидка/надбавка относительно котировочного периода в ценовом приложении | stg."ZFI3436M_BI"."Z005"';
comment on column ods.ral_map_alverse_sales_life_cycle.gnr_contract_premium_total_amount is 'Сумма премий/надбавок в ценовом приложении | Сумма премий/надбавок в ценовом приложении | stg."ZFI3436M_BI"."PR_CONTRACTPREM_USD"';
comment on column ods.ral_map_alverse_sales_life_cycle.is_edm_applicable_code is 'Признак, что документ участвует в ЭДО | Признак, что документ участвует в ЭДО | stg."ZFI3436M_BI"."ZEDO"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_trader_code is 'Табельный номер Трейдера из заказа ЦК | Табельный номер Трейдера из заказа ЦК | stg."ZFI3436M_BI"."ZP_TRADER"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_sales_request_code is 'Системный номер заказа ЦК | Системный номер заказа ЦК | stg."ZFI3436M_BI2"."ZP_ZAKAZ_KL"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_plant_code is 'Системный цифровой код завода из заказа ЦК | Системный цифровой код завода из заказа ЦК | stg."ZFI3436M_BI2"."ZP_WERKS"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_plant_short_rus_name is 'Короткое наименование завода из заказа ЦК | Короткое наименование завода из заказа ЦК | stg."ZFI3436M_BI2"."ZP_WERKS_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_transport_type_code is 'Вид транспортного средства из заказа ЦК | Вид транспортного средства из заказа ЦК | stg."ZFI3436M_BI2"."ZP_TRANSPORT"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_ingot_per_unit_net_weight is 'Вес чушки из заказа ЦК | Вес чушки из заказа ЦК | stg."ZFI3436M_BI2"."ZP_WEIGHT_BASE"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_transportation_service_payed_by_code is 'Данные о том, кто платит перевозчику из заказа ЦК | Данные о том, кто платит перевозчику из заказа ЦК | stg."ZFI3436M_BI2"."ZP_ZPEREV"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_consignee_code is 'Код грузополучателя из заказа ЦК | Код грузополучателя из заказа ЦК | stg."ZFI3436M_BI2"."ZP_GRUZPOL"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_consignee_name is 'Наименование грузополучателя из заказа ЦК | Наименование грузополучателя из заказа ЦК | stg."ZFI3436M_BI2"."ZP_GRUZPOL_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_sr_quota_yyyymm is 'Период квоты из заказа ЦК | Период квоты из заказа ЦК | stg."ZFI3436M_BI2"."ZP_QUOTA"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_created_by is 'Логин создавшего заказ ЦК | Логин создавшего заказ ЦК | stg."ZFI3436M_BI2"."ZP_ERNAM"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_terms_of_payment_code is 'Код условия платежа из заказа ЦК | Код условия платежа из заказа ЦК | stg."ZFI3436M_BI2"."ZP_ZTERM"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_terms_of_payment_name is 'Наименование условия платежа из заказа ЦК | Наименование условия платежа из заказа ЦК | stg."ZFI3436M_BI2"."ZP_ZTERM_NAME"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_sr_payment is 'Дата платежа из заказа ЦК | Дата платежа из заказа ЦК | stg."ZFI3436M_BI2"."ZP_ZTERM_DATE"';
comment on column ods.ral_map_alverse_sales_life_cycle.sr_remote_warehouse_shipment_forwarder_code is 'Грузоотправитель на удаленный склад из заказа ЦК (заполняется при отправке на удаленный склад) | Грузоотправитель на удаленный склад из заказа ЦК (заполняется при отправке на удаленный склад) | stg."ZFI3436M_BI2"."ZP_GRUZOTP"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_si_shipment_instruction is 'Дата создания распоряжения на отгрузку | Дата создания распоряжения на отгрузку | stg."ZFI3436M_BI2"."R_AUDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.si_incoterms_code is 'Условие поставки из распоряжения на отгрузку | Условие поставки из распоряжения на отгрузку | stg."ZFI3436M_BI2"."R_INCO1"';
comment on column ods.ral_map_alverse_sales_life_cycle.si_transportation_service_payed_by_name is 'Данные о том, кто платит перевозчику из распоряжения на отгрузку | Данные о том, кто платит перевозчику из распоряжения на отгрузку | stg."ZFI3436M_BI2"."R_ZZPEREV"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_unit_balance_owner_code is 'Код балансовой единицы собственника | Код балансовой единицы собственника | stg."ZFI3436M_BI2"."FO_BUKRS"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_plant_owner_code is 'Системный код завода собственника | Системный код завода собственника | stg."ZFI3436M_BI2"."FO_WERKS"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_ownership_transfer_code is 'Системный код перехода права собственности | Системный код перехода права собственности | stg."ZFI3436M_BI2"."FO_KVGR2"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_agency_contract_code is 'Системный номер агентского договора | Системный номер агентского договора | stg."ZFI3436M_BI2"."FO_VERTN_A"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_od_outbound_delivery_created is 'Дата создания исходящей поставки на отгрузку | Дата создания исходящей поставки на отгрузку | stg."ZFI3436M_BI2"."FO_ERDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_od_shipment_from_warehouse is 'Дата отгрузки со склада клиенту из исходящей поставки | Дата отгрузки со склада клиенту из исходящей поставки | stg."ZFI3436M_BI2"."FO_KODAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_od_shipment_from_plant is 'Дата отгрузки с завода из исходящей поставки | Дата отгрузки с завода из исходящей поставки | stg."ZFI3436M_BI2"."FO_LDDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_od_shipment_from_plant_plus5_days is 'Дата отгрузки с завода плюс 5 дней | Дата отгрузки с завода плюс 5 дней | stg."ZFI3436M_BI2"."FO_LDDAT_5"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_od_ownership_transfer is 'Дата перехода права собственности из исходящей поставки | Дата перехода права собственности из исходящей поставки | stg."ZFI3436M_BI2"."FO_WADAT_IST"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_seller_code is 'Значение параметра SAPI10 из таблицы "Дополнительные данные к БЕ" для БЕ собственника | Значение параметра SAPI10 из таблицы "Дополнительные данные к БЕ" для БЕ собственника | stg."ZFI3436M_BI2"."FO_LIFNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_transport_type_code is 'Вид транспортного средства из исходящей поставки | Вид транспортного средства из исходящей поставки | stg."ZFI3436M_BI2"."FO_WAGTYPE"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_transport_vehicle_code is 'Номер транспортного средства из исходящей поставки | Номер транспортного средства из исходящей поставки | stg."ZFI3436M_BI2"."FO_VAGON"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_transport_capacity is 'Грузоподъемность транспортного средства из исходящей поставки | Грузоподъемность транспортного средства из исходящей поставки | stg."ZFI3436M_BI2"."FO_GRUZ"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_transport_bill_code is 'Номер накладной из исходящей поставки | Номер накладной из исходящей поставки | stg."ZFI3436M_BI2"."FO_NAKLADN"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_material_attribute_text is 'Марка, форма, размер из спецификации материала из исходящей поставки | Марка, форма, размер из спецификации материала из исходящей поставки | stg."ZFI3436M_BI2"."FO_MATNR_MFR"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_od_price is 'Дата цены | Дата цены | stg."ZFI3436M_BI2"."FO_PRSDT"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_price_vat_excluded_amount is 'Цена без НДС | Цена без НДС | stg."ZFI3436M_BI2"."FO_KBETR"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_price_currency_code is 'Валюта цены | Валюта цены | stg."ZFI3436M_BI2"."FO_KOEI1"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_transaction_currency_code is 'Валюта операции | Валюта операции | stg."ZFI3436M_BI2"."FO_WAERS"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_currency_translation_rate is 'Курс пересчета цены из валюты цены в валюту документа | Курс пересчета цены из валюты цены в валюту документа | stg."ZFI3436M_BI2"."FO_KURSF"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_weight_net_with_wirerod is 'Вес нетто + катанка | Вес нетто + катанка | stg."ZFI3436M_BI2"."FO_NK"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_initial_delivery_code is 'Номер исходящей поставки завода производителя | Номер исходящей поставки завода производителя | stg."ZFI3436M_BI2"."FO_VBELN_ZV"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_initial_delivery_position_code is 'Позиция исходящей поставки завода производителя | Позиция исходящей поставки завода производителя | stg."ZFI3436M_BI2"."FO_POSNR_ZV"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_inbound_delivery_code is 'Номер входящей поставки | Номер входящей поставки | stg."ZFI3436M_BI2"."FO_VBELN_IN"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_batch_code is 'Номер партии | Номер партии | stg."ZFI3436M_BI2"."FO_CHARG"';
comment on column ods.ral_map_alverse_sales_life_cycle.od_outbound_delivery_status_code is 'Статус поставки | Статус поставки | stg."ZFI3436M_BI2"."FO_WBSTA"';
comment on column ods.ral_map_alverse_sales_life_cycle.odp_entry_system_code is 'Номер записи в таблице привязки плановых платежей и фактической отгрузки | Номер записи в таблице привязки плановых платежей и фактической отгрузки | stg."ZFI3436M_BI2"."PP_FO_ID"';
comment on column ods.ral_map_alverse_sales_life_cycle.odp_local_currency_code is 'Внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | Внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | stg."ZFI3436M_BI2"."PP_FO_HWAER"';
comment on column ods.ral_map_alverse_sales_life_cycle.odp_second_local_currency_code is 'Вторая внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | Вторая внутренняя валюта в таблице привязки плановых платежей и фактической отгрузки | stg."ZFI3436M_BI2"."PP_FO_HWAE2"';
comment on column ods.ral_map_alverse_sales_life_cycle.pr_payment_return_document_code is 'Номер документа возврата платежа | Номер документа возврата платежа | stg."ZFI3436M_BI2"."V_BELNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_pr_payment_return_document_yyyy is 'Год документа возврата платежа | Год документа возврата платежа | stg."ZFI3436M_BI2"."V_GJAHR"';
comment on column ods.ral_map_alverse_sales_life_cycle.pr_document_reverse_code is 'Номер сторно документа возврата платежа | Номер сторно документа возврата платежа | stg."ZFI3436M_BI2"."V_BELNR_S"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_ri_realization_invoice is 'Дата бухгалтерского документа фактуры реализации | Дата бухгалтерского документа фактуры реализации | stg."ZFI3436M_BI3"."FR_BLDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_ri_posting is 'Дата проводки бухгалтерского документа фактуры реализации | Дата проводки бухгалтерского документа фактуры реализации | stg."ZFI3436M_BI3"."FR_BUDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_code is 'Номер фактуры реализации | Номер фактуры реализации | stg."ZFI3436M_BI3"."FR_BELNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_agent_reverse_code is 'Номер документа сторно фактуры агента | Номер документа сторно фактуры агента | stg."ZFI3436M_BI3"."FR_BELNR_S"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_ri_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD для фактуры реализации | Дата пересчета суммы отгрузки в USD для фактуры реализации | stg."ZFI3436M_BI3"."FR_WWERT"';
comment on column ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_external_number is 'Бумажный номер фактуры реализации | Бумажный номер фактуры реализации | stg."ZFI3436M_BI3"."FR_XBLNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.ri_vat_code is 'Код налога НДС из фактуры реализации | Код налога НДС из фактуры реализации | stg."ZFI3436M_BI3"."FR_MWSKZ"';
comment on column ods.ral_map_alverse_sales_life_cycle.ri_realization_invoice_comment_text is 'Текст из фактуры реализации | Текст из фактуры реализации | stg."ZFI3436M_BI3"."FR_SGTXT"';
comment on column ods.ral_map_alverse_sales_life_cycle.ai_unit_balance_code is 'Балансовая единица из фактуры агента | Балансовая единица из фактуры агента | stg."ZFI3436M_BI3"."FA_BUKRS"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_ai_agent_invoice is 'Дата бухгалтерского документа фактуры агента | Дата бухгалтерского документа фактуры агента | stg."ZFI3436M_BI3"."FA_BLDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.ai_agent_invoice_code is 'Номер фактуры агента | Номер фактуры агента | stg."ZFI3436M_BI3"."FA_BELNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.ai_agent_invoice_reverse_code is 'Номер документа сторно фактуры агента | Номер документа сторно фактуры агента | stg."ZFI3436M_BI3"."FA_BELNR_S"';
comment on column ods.ral_map_alverse_sales_life_cycle.ai_contract_code is 'Номер договора с покупателем из фактуры агента | Номер договора с покупателем из фактуры агента | stg."ZFI3436M_BI3"."FA_VERTN"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_ai_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD для фактуры агента | Дата пересчета суммы отгрузки в USD для фактуры агента | stg."ZFI3436M_BI3"."FA_WWERT"';
comment on column ods.ral_map_alverse_sales_life_cycle.ai_currency_translation_to_usd_rate is 'Курс пересчета суммы отгрузки в USD для фактуры агента | Курс пересчета суммы отгрузки в USD для фактуры агента | stg."ZFI3436M_BI3"."FA_KURSF"';
comment on column ods.ral_map_alverse_sales_life_cycle.ai_agent_invoice_external_number is 'Бумажный номер фактуры агента | Бумажный номер фактуры агента | stg."ZFI3436M_BI3"."FA_XBLNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_accounting_document_code is 'Номер бухгалтерского документа фактуры собственника | Номер бухгалтерского документа фактуры собственника | stg."ZFI3436M_BI3"."FS_BELNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_fiscal_year is 'Год бухгалтерского документа фактуры собственника | Год бухгалтерского документа фактуры собственника | stg."ZFI3436M_BI3"."FS_GJAHR"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_owner_invoice_code is 'Системный номер фактуры собственника | Системный номер фактуры собственника | stg."ZFI3436M_BI3"."FS_VBELN"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_owner_invoice_position_code is 'Системный номер позиции фактуры собственника | Системный номер позиции фактуры собственника | stg."ZFI3436M_BI3"."FS_POSNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_oi_currency_translation_to_usd is 'Дата пересчета суммы отгрузки в USD для фактуры собственника | Дата пересчета суммы отгрузки в USD для фактуры собственника | stg."ZFI3436M_BI3"."FS_WWERT"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_owner_invoice_external_number is 'Бумажный номер фактуры собственника | Бумажный номер фактуры собственника | stg."ZFI3436M_BI3"."FS_XBLNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_oi_accounting_document is 'Дата бухгалтерского документа фактуры собственника | Дата бухгалтерского документа фактуры собственника | stg."ZFI3436M_BI3"."FS_BLDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_oi_posting is 'Дата проводки из бухгалтерского документа фактуры собственника | Дата проводки из бухгалтерского документа фактуры собственника | stg."ZFI3436M_BI3"."FS_BUDAT"';
comment on column ods.ral_map_alverse_sales_life_cycle.di_deferred_invoice_code is 'Системный номер фактуры на отложенную реализацию | Системный номер фактуры на отложенную реализацию | stg."ZFI3436M_BI3"."FS2_VBELN"';
comment on column ods.ral_map_alverse_sales_life_cycle.di_accounting_document_code is 'Номер бухгалтерского документа фактуры на отложенную реализацию | Номер бухгалтерского документа фактуры на отложенную реализацию | stg."ZFI3436M_BI3"."FS2_BELNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.di_accounting_document_reverse_code is 'Номер сторно бухгалтерского документа фактуры на отложенную реализацию | Номер сторно бухгалтерского документа фактуры на отложенную реализацию | stg."ZFI3436M_BI3"."FS2_BELNR_S"';
comment on column ods.ral_map_alverse_sales_life_cycle.di_deferred_invoice_external_number is 'Бумажный номер фактуры на отложенную реализацию | Бумажный номер фактуры на отложенную реализацию | stg."ZFI3436M_BI3"."FS2_XBLNR"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_oi_owner_invoice_created is 'Дата создания фактуры собственника | Дата создания фактуры собственника | stg."ZFI3436M_BI3"."FS_CPUDT"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_currency_translation_to_usd_rate is 'Курс из фактуры собственника | Курс из фактуры собственника | stg."ZFI3436M_BI3"."FS_KURSF2"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_vat_included_rub_amount is 'Сумма фактуры собственника с НДС в рублях | Сумма фактуры собственника с НДС в рублях | stg."ZFI3436M_BI3"."FS_KWERT"';
comment on column ods.ral_map_alverse_sales_life_cycle.oi_vat_included_usd_amount is 'Сумма фактуры собственника с НДС в долларах | Сумма фактуры собственника с НДС в долларах | stg."ZFI3436M_BI3"."FS_KWERT_USD"';
comment on column ods.ral_map_alverse_sales_life_cycle.edm_code is 'Системный номер документа ЭДО | Системный номер документа ЭДО | stg."ZFI3436M_BI3"."FE_N"';
comment on column ods.ral_map_alverse_sales_life_cycle.edm_status_code is 'Статус документа ЭДО | Статус документа ЭДО | stg."ZFI3436M_BI3"."FE_STATUSP"';
comment on column ods.ral_map_alverse_sales_life_cycle.dt_edm_status_last_updated is 'Дата последнего изменения статуса документа ЭДО | Дата последнего изменения статуса документа ЭДО | stg."ZFI3436M_BI3"."FE_DATE_ST"';
