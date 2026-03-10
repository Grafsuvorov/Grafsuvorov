DROP TABLE IF EXISTS dds."purchase_contract_position" cascade;

CREATE TABLE dds."purchase_contract_position"
(
"purchase_contract_code" varchar(10) NULL,
"position_line_item_code" varchar(5) NULL,
"purchase_document_type_code" varchar(1) NULL,
"position_type_code" varchar(1) NULL,
"base_uom_code" varchar(3) NULL,
"booking_number" varchar(30) NULL,
"bunker_adjustment_tariff_calculation_rule_code" varchar(1) NULL,
"container_length_type_code" varchar(1) NULL,
"container_ownership_type_code" varchar(2) NULL,
"container_pickup_transport_hub_code" varchar(10) NULL,
"conversion_denominator_to_base_uom" int8 NULL,
"conversion_denominator_to_purchase_contract_uom" int8 NULL,
"conversion_numerator_to_base_uom" int8 NULL,
"conversion_numerator_to_purchase_contract_uom" int8 NULL,
"counterparty_code" varchar(10) NULL,
"country_of_origin_code" varchar(3) NULL,
"delivery_confirmation_control_code" varchar(4) NULL,
"dob_tariff_responsibility_code" varchar(2) NULL,
"dt_price_calculated" date NULL,
"etsng_code" varchar(6) NULL,
"etsng_previous_code" varchar(6) NULL,
"expense_assignment_type_code" varchar(1) NULL,
"export_method_code" varchar(2) NULL,
"financial_position_code" varchar(14) NULL,
"freight_movement_method_code" varchar(4) NULL,
"fuel_grade_code" varchar(15) NULL,
"fund_code" varchar(10) NULL,
"funds_center_code" varchar(16) NULL,
"import_method_code" varchar(1) NULL,
"incoterms_code" varchar(3) NULL,
"incoterms_location_code" varchar(10) NULL,
"is_deleted" varchar(1) NULL,
"is_delivery_completed_code" varchar(1) NULL,
"is_material_rnpt_code" varchar(1) NULL,
"is_purchase_customs_union_eeu_code" varchar(1) NULL,
"is_purchase_domestic_market_code" varchar(1) NULL,
"is_purchase_export_market_code" varchar(1) NULL,
"is_purchase_undefined_code" varchar(1) NULL,
"material_code" varchar(18) NULL,
"material_group_code" varchar(9) NULL,
"material_main_code" varchar(18) NULL,
"material_okpd2_code" varchar(12) NULL,
"material_reporting_group_code" varchar(9) NULL,
"material_reporting_type_code" varchar(2) NULL,
"material_type_code" varchar(4) NULL,
"movement_scheme_code" varchar(1) NULL,
"number_of_principal_purchase_agreement" varchar(10) NULL,
"option_to_buy_percentage" numeric(3, 1) NULL,
"package_subtype_code" varchar(2) NULL,
"package_type_code" varchar(2) NULL,
"paydox_registration_number" varchar(50) NULL,
"plant_code" varchar(4) NULL,
"platform_ownership_type_code" varchar(2) NULL,
"port_code" varchar(10) NULL,
"position_name" varchar(40) NULL,
"price_unit_code" int8 NULL,
"price_uom_code" varchar(3) NULL,
"price_vat_excluded_document_currency_amount" numeric(11, 2) NULL,
"producer_code" varchar(10) NULL,
"purchase_contract_position_code" varchar(5) NULL,
"purchase_requisition_code" varchar(10) NULL,
"purchase_requisition_position_code" varchar(5) NULL,
"quantity" numeric(13,3) NULL,
"railcar_owner_code" varchar(10) NULL,
"railway_platform_completeness_type_code" varchar(2) NULL,
"railway_station_code" varchar(10) NULL,
"receiving_plant_code" varchar(4) NULL,
"redirection_type_code" varchar(1) NULL,
"route_code" varchar(6) NULL,
"sea_forwarder_code" varchar(10) NULL,
"sea_route_code" varchar(6) NULL,
"service_code" varchar(18) NULL,
"service_type_code" varchar(1) NULL,
"shape_code" varchar(3) NULL,
"shipment_type_code" varchar(2) NULL,
"supplier_transportation_requirement_group_code" varchar(4) NULL,
"tariff_calculation_rule_code" varchar(3) NULL,
"tariff_calculation_weekday_type_code" varchar(1) NULL,
"tariff_calculation_weight_from" numeric(13,3) NULL,
"tariff_calculation_weight_to" numeric(13,3) NULL,
"terminal_code" varchar(10) NULL,
"terminal_handling_charges_payer_code" varchar(1) NULL,
"tnved_code" varchar(17) NULL,
"tolerance_percentage" numeric(13, 3) NULL,
"total_contract_limit_quantity" numeric(13, 3) NULL,
"transport_bill_code" varchar(35) NULL,
"transport_previous_type_code" varchar(4) NULL,
"transport_subtype_code" varchar(4) NULL,
"transport_type_code" varchar(4) NULL,
"uom_code" varchar(3) NULL,
"vat_code" varchar(2) NULL,
"vat_excluded_document_currency_amount" numeric(13, 2) NULL,
"vehicle_detail_type_code" varchar(10) NULL,
"vehicle_length_type_code" varchar(1) NULL,
"vessel_code" varchar(10) NULL,
"vessel_crane_code" varchar(1) NULL,
"vessel_port_call_code" varchar(1) NULL,
"warehouse_code" varchar(4) NULL,
"weight_uom_code" varchar(3) NULL,
"dttm_inserted" timestamp NOT NULL DEFAULT now(),
"dttm_updated" timestamp NOT NULL DEFAULT now(),
"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
appendonly=true,
orientation=column,
compresstype=zstd,
compresslevel=3
)
distributed by ("position_line_item_code", "purchase_contract_code");


comment on table dds."purchase_contract_position" is 'Позиция контракта на закупку';
comment on column dds."purchase_contract_position"."purchase_contract_code" is 'Контракт на закупку (код) | Контракт на закупку (код) | ekpo_ral.ebeln';
comment on column dds."purchase_contract_position"."position_line_item_code" is 'Позиция контракта на закупку (код) | Позиция контракта на закупку (код) | ekpo_ral.ebelp';
comment on column dds."purchase_contract_position"."purchase_document_type_code" is 'Тип документа на закупку (код) | Тип документа на закупку (код) | ekko_ral.bstyp';
comment on column dds."purchase_contract_position"."position_type_code" is 'Тип позиции в контракте на закупку (код) | Тип позиции в контракте на закупку (код) | ekpo_ral.pstyp';
comment on column dds."purchase_contract_position"."base_uom_code" is 'Базисная единица измерения (код) | Базисная единица измерения (код) | ekpo_ral.lmein';
comment on column dds."purchase_contract_position"."booking_number" is 'Номер букинга | Номер букинга | ekpo_ral.zzbucking';
comment on column dds."purchase_contract_position"."bunker_adjustment_tariff_calculation_rule_code" is 'Базис бункерной поправки (код) | Базис бункерной поправки (код) | ekpo_ral.zzbunker';
comment on column dds."purchase_contract_position"."container_length_type_code" is 'Длина контейнера (код) | Длина контейнера (код) | ekpo_ral.zzlength';
comment on column dds."purchase_contract_position"."container_ownership_type_code" is 'Принадлежность контейнера (код) | Принадлежность контейнера (код) | ekpo_ral.zzpr_cont';
comment on column dds."purchase_contract_position"."container_pickup_transport_hub_code" is 'Сток (код) | Сток (код) | ekpo_ral.zzstock';
comment on column dds."purchase_contract_position"."conversion_denominator_to_base_uom" is 'Знаменатель для пересчета ЕИ заказа в базисную ЕИ | Знаменатель для пересчета ЕИ заказа в базисную ЕИ | ekpo_ral.umren';
comment on column dds."purchase_contract_position"."conversion_denominator_to_purchase_contract_uom" is 'Пересчет ЕИЦЗ в ЕИЗ: знаменатель | Пересчет ЕИЦЗ в ЕИЗ: знаменатель | ekpo_ral.bpumn';
comment on column dds."purchase_contract_position"."conversion_numerator_to_base_uom" is 'Числитель для пересчета ЕИ заказа в базисную ЕИ | Числитель для пересчета ЕИ заказа в базисную ЕИ | ekpo_ral.umrez';
comment on column dds."purchase_contract_position"."conversion_numerator_to_purchase_contract_uom" is 'Пересчет ЕИЦЗ в ЕИЗ: числитель | Пересчет ЕИЦЗ в ЕИЗ: числитель | ekpo_ral.bpumz';
comment on column dds."purchase_contract_position"."counterparty_code" is 'Контрагент (код) | Контрагент (код) | ekpo_ral.zzkontrag';
comment on column dds."purchase_contract_position"."country_of_origin_code" is 'Страна происхождения (код) | Страна происхождения (код) | ekpo_ral.zzland';
comment on column dds."purchase_contract_position"."delivery_confirmation_control_code" is 'Управляющий код подтверждения (код) | Управляющий код подтверждения (код) | ekpo_ral.bstae';
comment on column dds."purchase_contract_position"."dob_tariff_responsibility_code" is 'Тариф - параметр, отражающий распределение транспортных затрат в отчетности КД (код) | Тариф - параметр, отражающий распределение транспортных затрат в отчетности КД (код) | ekpo_ral.zztariff';
comment on column dds."purchase_contract_position"."dt_price_calculated" is 'Дата расчета цены | Дата расчета цены | ekpo_ral.prdat';
comment on column dds."purchase_contract_position"."etsng_code" is 'Код ЕТ СНГ (код) | Код ЕТ СНГ (код) | ekpo_ral.zzet_tarif';
comment on column dds."purchase_contract_position"."etsng_previous_code" is 'Код ЕТ СНГ исходный (код) | Код ЕТ СНГ исходный (код) | ekpo_ral.zzetsng1';
comment on column dds."purchase_contract_position"."expense_assignment_type_code" is 'Тип контировки (код) | Тип контировки (код) | ekpo_ral.knttp';
comment on column dds."purchase_contract_position"."export_method_code" is 'Режим экспорта (код) | Режим экспорта (код) | ekpo_ral.zzrej_exp';
comment on column dds."purchase_contract_position"."financial_position_code" is 'Финансовая позиция (код) | Финансовая позиция (код) | ekpo_ral.fipos';
comment on column dds."purchase_contract_position"."freight_movement_method_code" is 'Вид фрахта (код) | Вид фрахта (код) | ekpo_ral.zzfraht_type';
comment on column dds."purchase_contract_position"."fuel_grade_code" is 'Марка топлива (код) | Марка топлива (код) | ekpo_ral.zzgrade';
comment on column dds."purchase_contract_position"."fund_code" is 'Фонд (код) | Фонд (код) | ekpo_ral.geber';
comment on column dds."purchase_contract_position"."funds_center_code" is 'Подразделение финансового менеджмента (код) | Подразделение финансового менеджмента (код) | ekpo_ral.fistl';
comment on column dds."purchase_contract_position"."import_method_code" is 'Схема реализации (код) | Схема реализации (код) | ekpo_ral.zztype_prod';
comment on column dds."purchase_contract_position"."incoterms_code" is 'Инкотермс часть 1 (код) | Инкотермс часть 1 (код) | ekpo_ral.zzinco1';
comment on column dds."purchase_contract_position"."incoterms_location_code" is 'Инкотермс 2 (Транспортный узел) (код) | Инкотермс 2 (Транспортный узел) (код) | ekpo_ral.zzknote';
comment on column dds."purchase_contract_position"."is_deleted" is 'Индикатор удаления | Индикатор удаления | ekpo_ral.loekz';
comment on column dds."purchase_contract_position"."is_delivery_completed_code" is 'Индикатор конечной поставки (код) | Индикатор конечной поставки (код) | ekpo_ral.elikz';
comment on column dds."purchase_contract_position"."is_material_rnpt_code" is 'Индикатор: отслеживается с помощью РНПТ (регистрационный номер партии товара) (код) | Индикатор: отслеживается с помощью РНПТ (регистрационный номер партии товара) (код) | ekpo_ral.zzrnpt';
comment on column dds."purchase_contract_position"."is_purchase_customs_union_eeu_code" is 'Индикатор "Таможенный союз" (код) | Индикатор "Таможенный союз" (код) | ekpo_ral.zztamozhsous';
comment on column dds."purchase_contract_position"."is_purchase_domestic_market_code" is 'Индикатор "Внутренний рынок" (код) | Индикатор "Внутренний рынок" (код) | ekpo_ral.zzintmarket';
comment on column dds."purchase_contract_position"."is_purchase_export_market_code" is 'Индикатор "Импорт" (код) | Индикатор "Импорт" (код) | ekpo_ral.zzimport';
comment on column dds."purchase_contract_position"."is_purchase_undefined_code" is 'Индикатор "Не определено" (код) | Индикатор "Не определено" (код) | ekpo_ral.zzundefined';
comment on column dds."purchase_contract_position"."material_code" is 'Номер материала (код) | Номер материала (код) | ekpo_ral.matnr';
comment on column dds."purchase_contract_position"."material_group_code" is 'Группа материалов (код) | Группа материалов (код) | ekpo_ral.matkl';
comment on column dds."purchase_contract_position"."material_main_code" is 'Номер материала у производителя (код) | Номер материала у производителя (код) | ekpo_ral.ematn';
comment on column dds."purchase_contract_position"."material_okpd2_code" is 'Общероссийский классификатор продукции по видам экономической деятельности (ОКПД2) (код) | Общероссийский классификатор продукции по видам экономической деятельности (ОКПД2) (код) | ekpo_ral.zzkod_okpd';
comment on column dds."purchase_contract_position"."material_reporting_group_code" is 'Группа материала 2 (код) | Группа материала 2 (код) | ekpo_ral.zzmatkl';
comment on column dds."purchase_contract_position"."material_reporting_type_code" is 'Сектор (код) | Сектор (код) | ekpo_ral.zzspart';
comment on column dds."purchase_contract_position"."material_type_code" is 'Вид материала (код) | Вид материала (код) | ekpo_ral.mtart';
comment on column dds."purchase_contract_position"."movement_scheme_code" is 'Схема перемещения (код) | Схема перемещения (код) | ekpo_ral.zzmovement';
comment on column dds."purchase_contract_position"."number_of_principal_purchase_agreement" is 'Номер основного договора | Номер основного договора | ekpo_ral.konnr';
comment on column dds."purchase_contract_position"."option_to_buy_percentage" is 'Опцион поставки в %. Возможное отклонение для поля «Договорное количество» по условиям договора. Право дополнительно купить. | Опцион поставки в %. Возможное отклонение для поля «Договорное количество» по условиям договора. Право дополнительно купить. | ekpo_ral.zzoption';
comment on column dds."purchase_contract_position"."package_subtype_code" is 'Подтип тары (код) | Подтип тары (код) | ekpo_ral.zztaresubtype';
comment on column dds."purchase_contract_position"."package_type_code" is 'Тип тары (код) | Тип тары (код) | ekpo_ral.zzcartare';
comment on column dds."purchase_contract_position"."paydox_registration_number" is 'Регистрационный номер спецификации (ДС) в системе PayDox | Регистрационный номер спецификации (ДС) в системе PayDox | ekpo_ral.zzihrez';
comment on column dds."purchase_contract_position"."plant_code" is 'Завод (код) | Завод (код) | ekpo_ral.werks';
comment on column dds."purchase_contract_position"."platform_ownership_type_code" is 'Принадлежность платформы (код) | Принадлежность платформы (код) | ekpo_ral.zzpr_pl';
comment on column dds."purchase_contract_position"."port_code" is 'Порт (код) | Порт (код) | ekpo_ral.zzport';
comment on column dds."purchase_contract_position"."position_name" is 'Краткий текст позиции контракта на закупку | Краткий текст позиции контракта на закупку | ekpo_ral.txz01';
comment on column dds."purchase_contract_position"."price_unit_code" is 'Указывает, для скольких единиц цены заказа на поставку действительна цена | Указывает, для скольких единиц цены заказа на поставку действительна цена | ekpo_ral.peinh';
comment on column dds."purchase_contract_position"."price_uom_code" is 'Единица измерения цены заказа на поставку (код) | Единица измерения цены заказа на поставку (код) | ekpo_ral.bprme';
comment on column dds."purchase_contract_position"."price_vat_excluded_document_currency_amount" is 'Цена нетто в документе закупки в валюте документа | Цена нетто в документе закупки в валюте документа | ekpo_ral.netpr';
comment on column dds."purchase_contract_position"."producer_code" is 'Производитель (код) | Производитель (код) | ekpo_ral.mfrnr';
comment on column dds."purchase_contract_position"."purchase_contract_position_code" is 'Позиция основного договора (код) | Позиция основного договора (код) | ekpo_ral.ktpnr';
comment on column dds."purchase_contract_position"."purchase_requisition_code" is 'Номер заявки на поставку (код) | Номер заявки на поставку (код) | ekpo_ral.banfn';
comment on column dds."purchase_contract_position"."purchase_requisition_position_code" is 'Номер позиции заявки на поставку (код) | Номер позиции заявки на поставку (код) | ekpo_ral.bnfpo';
comment on column dds."purchase_contract_position"."quantity" is 'Объем заказа на поставку | Объем заказа на поставку | ekpo_ral.menge';
comment on column dds."purchase_contract_position"."railcar_owner_code" is 'Собственник вагона (код) | Собственник вагона (код) | ekpo_ral.zzlif_owner';
comment on column dds."purchase_contract_position"."railway_platform_completeness_type_code" is 'Признак комплектности (код) | Признак комплектности (код) | ekpo_ral.zzset';
comment on column dds."purchase_contract_position"."railway_station_code" is 'Станция (код) | Станция (код) | ekpo_ral.zzstation';
comment on column dds."purchase_contract_position"."receiving_plant_code" is 'Завод-получатель (код) | Завод-получатель (код) | ekpo_ral.zzwerks';
comment on column dds."purchase_contract_position"."redirection_type_code" is 'Тип переадресации (код) | Тип переадресации (код) | ekpo_ral.zzredir_type';
comment on column dds."purchase_contract_position"."route_code" is 'Маршрут (код) | Маршрут (код) | ekpo_ral.zzroute';
comment on column dds."purchase_contract_position"."sea_forwarder_code" is 'Линия (код) | Линия (код) | ekpo_ral.zzline';
comment on column dds."purchase_contract_position"."sea_route_code" is 'Морской маршрут (код) | Морской маршрут (код) | ekpo_ral.zzroute2';
comment on column dds."purchase_contract_position"."service_code" is 'Номер услуги LE (код) | Номер услуги LE (код) | ekpo_ral.zzsrvpos';
comment on column dds."purchase_contract_position"."service_type_code" is 'Тип услуги (код) | Тип услуги (код) | ekpo_ral.zztype';
comment on column dds."purchase_contract_position"."shape_code" is 'Форма (код) | Форма (код) | ekpo_ral.zzforma';
comment on column dds."purchase_contract_position"."shipment_type_code" is 'Вид отгрузки (код) | Вид отгрузки (код) | ekpo_ral.zzvsart';
comment on column dds."purchase_contract_position"."supplier_transportation_requirement_group_code" is 'Группа условий у поставщика (код) | Группа условий у поставщика (код) | ekpo_ral.ekkol';
comment on column dds."purchase_contract_position"."tariff_calculation_rule_code" is 'Номер формулы (код) | Номер формулы (код) | ekpo_ral.zzformula';
comment on column dds."purchase_contract_position"."tariff_calculation_weekday_type_code" is 'Выходные и праздничные дни (код) | Выходные и праздничные дни (код) | ekpo_ral.zzdayoff';
comment on column dds."purchase_contract_position"."tariff_calculation_weight_from" is 'Вес с, тн | Вес с, тн | ekpo_ral.zzcargow';
comment on column dds."purchase_contract_position"."tariff_calculation_weight_to" is 'Вес по, тн | Вес по, тн | ekpo_ral.zzcargoa';
comment on column dds."purchase_contract_position"."terminal_code" is 'Терминал (код) | Терминал (код) | ekpo_ral.zzterminal';
comment on column dds."purchase_contract_position"."terminal_handling_charges_payer_code" is 'THC - параметр, который определяет, кто оплачивает данные расходы: поставщик или покупатель (код) | THC - параметр, который определяет, кто оплачивает данные расходы: поставщик или покупатель (код) | ekpo_ral.zzthc';
comment on column dds."purchase_contract_position"."tnved_code" is 'Классификационный код по единой товарной номенклатуре внешнеэкономической деятельности Евразийского экономического союза (ТН ВЕД) (код) | Классификационный код по единой товарной номенклатуре внешнеэкономической деятельности Евразийского экономического союза (ТН ВЕД) (код) | ekpo_ral.zzkod_tnved';
comment on column dds."purchase_contract_position"."tolerance_percentage" is 'Толеранс поставки в %. Возможное отклонение для поля «Договорное количество» по условиям договора. Норма отгрузки, не зависящая от объемов закупки. | Толеранс поставки в %. Возможное отклонение для поля «Договорное количество» по условиям договора. Норма отгрузки, не зависящая от объемов закупки. | ekpo_ral.zztolerance';
comment on column dds."purchase_contract_position"."total_contract_limit_quantity" is 'Целевое количество (общий объем по договору) | Целевое количество (общий объем по договору) | ekpo_ral.ktmng';
comment on column dds."purchase_contract_position"."transport_bill_code" is 'Транспортная накладная (код) | Транспортная накладная (код) | ekpo_ral.zztrnakl';
comment on column dds."purchase_contract_position"."transport_previous_type_code" is 'Тип исходного ТС/ПС (код) | Тип исходного ТС/ПС (код) | ekpo_ral.zzsdabw2';
comment on column dds."purchase_contract_position"."transport_subtype_code" is 'Вид транспортного средства (код) | Вид транспортного средства (код) | ekpo_ral.zztraty';
comment on column dds."purchase_contract_position"."transport_type_code" is 'Тип вагона (код) | Тип вагона (код) | ekpo_ral.zzsdabw';
comment on column dds."purchase_contract_position"."uom_code" is 'ЕИ заказа на поставку (код) | ЕИ заказа на поставку (код) | ekpo_ral.meins';
comment on column dds."purchase_contract_position"."vat_code" is 'Код налога с оборота (код) | Код налога с оборота (код) | ekpo_ral.mwskz';
comment on column dds."purchase_contract_position"."vat_excluded_document_currency_amount" is 'Стоимость позиции заказа нетто в валюте контракта | Стоимость позиции заказа нетто в валюте контракта | ekpo_ral.netwr';
comment on column dds."purchase_contract_position"."vehicle_detail_type_code" is 'Марка ТС (код) | Марка ТС (код) | ekpo_ral.zzvehicletype';
comment on column dds."purchase_contract_position"."vehicle_length_type_code" is 'Длина ПС (код) | Длина ПС (код) | ekpo_ral.zzbodylength';
comment on column dds."purchase_contract_position"."vessel_code" is 'Судно (код) | Судно (код) | ekpo_ral.zzvehicle';
comment on column dds."purchase_contract_position"."vessel_crane_code" is 'Кран (код) | Кран (код) | ekpo_ral.zzkran';
comment on column dds."purchase_contract_position"."vessel_port_call_code" is 'Кол-во заходов в Порты (код) | Кол-во заходов в Порты (код) | ekpo_ral.zzbasis';
comment on column dds."purchase_contract_position"."warehouse_code" is 'Склад (код) | Склад (код) | ekpo_ral.lgort';
comment on column dds."purchase_contract_position"."weight_uom_code" is 'Единица измерения веса (код) | Единица измерения веса (код) | ekpo_ral.gewei';