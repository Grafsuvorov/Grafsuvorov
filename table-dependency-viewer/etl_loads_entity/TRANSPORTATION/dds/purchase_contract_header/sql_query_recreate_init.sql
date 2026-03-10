DROP TABLE IF EXISTS dds.purchase_contract_header;

CREATE TABLE dds.purchase_contract_header
(
"purchase_contract_code" varchar(10) NULL,
"purchase_document_subtype_code" varchar(4) NULL,
"purchase_document_type_code" varchar(1) NULL,
"supplier_claim_rate" numeric(5, 2) NULL,
"address_code" varchar(10) NULL,
"agency_contract_code" varchar(10) NULL,
"appendix_number" varchar(12) NULL,
"bank_account_system_code" varchar(4) NULL,
"budget_type_code" varchar(1) NULL,
"calculation_scheme_code" varchar(6) NULL,
"condition_document_reference_code" varchar(10) NULL,
"contract_supervisor_name" varchar(120) NULL,
"cost_region_code" varchar(2) NULL,
"created_by" varchar(12) NULL,
"currency_code" varchar(5) NULL,
"currency_translation_term_code" varchar(1) NULL,
"dt_created" date NULL,
"dt_deferred_payment1" date NULL,
"dt_deferred_payment2" date NULL,
"dt_deferred_payment3" date NULL,
"dt_deferred_payment4" date NULL,
"dt_purchase_contract" date NULL,
"dt_purchase_contract_paydox" date NULL,
"dt_quota_yyyymm" varchar(6) NULL,
"dt_valid_from" date NULL,
"dt_valid_to" date NULL,
"edm_applicable_code" varchar(1) NULL,
"external_contract_number_part1" varchar(30) NULL,
"external_contract_number_part2" varchar(16) NULL,
"hfm_reporting_segment_code" varchar(2) NULL,
"incoterms_code" varchar(3) NULL,
"incoterms_location_code" varchar(10) NULL,
"incoterms_location_text" varchar(28) NULL,
"is_penalty_charge_linked_to_central_bank_base_rate_code" varchar(1) NULL,
"is_released_code" varchar(1) NULL,
"legal_agreement_number" varchar(60) NULL,
"material_price_group_code" varchar(2) NULL,
"one_time_penalty_charge_amount" numeric(13, 2) NULL,
"one_time_penalty_charge_rate" numeric(5, 2) NULL,
"ownership_transfer_term_code" varchar(3) NULL,
"paydox_contract_type_code" varchar(1) NULL,
"paydox_document_code" varchar(10) NULL,
"paydox_document_name" varchar(255) NULL,
"paydox_document_status_code" varchar(2) NULL,
"paydox_document_type_code" varchar(10) NULL,
"paydox_document_url" varchar(255) NULL,
"paydox_protocol_registration_number" varchar(35) NULL,
"paydox_registration_number" varchar(128) NULL,
"paydox_responsible_person_code" varchar(12) NULL,
"paydox_unit_balance_code" varchar(64) NULL,
"payment_and_liability_plan_request_code" varchar(10) NULL,
"payment_date_calculation_rule_code" varchar(1) NULL,
"penalty_charge_calculation_terms_code" varchar(1) NULL,
"penalty_charge_for_delay_rate" numeric(5, 2) NULL,
"penalty_charge_maximum_limit_rate" numeric(5, 2) NULL,
"port_code" varchar(10) NULL,
"purchase_contract_available_limit_doc_currency_amount" numeric(15, 2) NULL,
"purchase_contract_draft_code" varchar(10) NULL,
"purchase_contract_name" varchar(40) NULL,
"purchase_contract_registration_number" varchar(12) NULL,
"purchase_contract_research_and_development_niokr_name" varchar(50) NULL,
"purchase_group_code" varchar(3) NULL,
"purchase_organization_code" varchar(4) NULL,
"railway_tariff_calculation_method_code" varchar(2) NULL,
"release_stage_code" varchar(1) NULL,
"release_status_code" varchar(8) NULL,
"release_strategy_code" varchar(2) NULL,
"release_strategy_group_code" varchar(2) NULL,
"rent_type_code" varchar(1) NULL,
"responsibility_center_code" varchar(16) NULL,
"storage_agreement_code" varchar(10) NULL,
"supplier_code" varchar(10) NULL,
"tariff_dob_responsibility_code" varchar(2) NULL,
"terminal_code" varchar(10) NULL,
"terms_of_payment_code" varchar(4) NULL,
"tolling_contract_code" varchar(10) NULL,
"total_purchase_contract_cost_document_currency_amount" numeric(15, 2) NULL,
"transportation_total_cost_vat_code" varchar(2) NULL,
"transportation_total_cost_vat_excluded_amount" numeric(13, 2) NULL,
"unified_purchase_contract_code" varchar(25) NULL,
"unified_purchase_contract_name" varchar(128) NULL,
"unit_balance_code" varchar(4) NULL,
"is_purchase_contract_draft_code" varchar(1) NULL,
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
distributed by ("purchase_contract_code");


comment on table dds.purchase_contract_header is 'Контракт на закупку';
comment on column dds.purchase_contract_header."purchase_contract_code" is 'Контракт на закупку (код) | Контракт на закупку (код) | ekko_ral.ebeln';
comment on column dds.purchase_contract_header."purchase_document_subtype_code" is 'Вид документа закупки (код) | Вид документа закупки (код) | ekko_ral.bsart';
comment on column dds.purchase_contract_header."purchase_document_type_code" is 'Тип документа закупки (код) | Тип документа закупки (код) | ekko_ral.bstyp';
comment on column dds.purchase_contract_header."supplier_claim_rate" is 'Параметр для расчета суммы претензии, выставляемой в адрес поставщика при несоблюдении условий договорного документа, % | Параметр для расчета суммы претензии, выставляемой в адрес поставщика при несоблюдении условий договорного документа, % | ekko_ral.zzcomercialloan';
comment on column dds.purchase_contract_header."address_code" is 'Номер адреса (код) | Номер адреса (код) | ekko_ral.adrnr';
comment on column dds.purchase_contract_header."agency_contract_code" is 'Агентский контракт (код) | Агентский контракт (код) | ekko_ral.zzvbeln';
comment on column dds.purchase_contract_header."appendix_number" is '№ приложения | № приложения | ekko_ral.unsez';
comment on column dds.purchase_contract_header."bank_account_system_code" is 'Тип банка-партнера (код) | Тип банка-партнера (код) | ekko_ral.zzbvtyp';
comment on column dds.purchase_contract_header."budget_type_code" is 'Бюджет (код) | Бюджет (код) | ekko_ral.zzbizp';
comment on column dds.purchase_contract_header."calculation_scheme_code" is 'Схема расчета цен (код) | Схема расчета цен (код) | ekko_ral.kalsm';
comment on column dds.purchase_contract_header."condition_document_reference_code" is 'Номер условия контракта (код) | Номер условия контракта (код) | ekko_ral.knumv';
comment on column dds.purchase_contract_header."contract_supervisor_name" is 'Куратор договора | Куратор договора | ekko_ral.zzdogkr';
comment on column dds.purchase_contract_header."cost_region_code" is 'Регион затрат (код) | Регион затрат (код) | ekko_ral.zzcostr';
comment on column dds.purchase_contract_header."created_by" is 'Имя исполнителя, создавшего объект | Имя исполнителя, создавшего объект | ekko_ral.ernam';
comment on column dds.purchase_contract_header."currency_code" is 'Валюта (код) | Валюта (код) | ekko_ral.waers';
comment on column dds.purchase_contract_header."currency_translation_term_code" is 'Условие курса оплаты (код) | Условие курса оплаты (код) | ekko_ral.zzkurs';
comment on column dds.purchase_contract_header."dt_created" is 'Дата создания записи | Дата создания записи | ekko_ral.aedat';
comment on column dds.purchase_contract_header."dt_deferred_payment1" is 'Дата отсрочки части платежа 1 | Дата отсрочки части платежа 1 | ekko_ral.zzdtots1';
comment on column dds.purchase_contract_header."dt_deferred_payment2" is 'Дата отсрочки части платежа 2 | Дата отсрочки части платежа 2 | ekko_ral.zzdtots2';
comment on column dds.purchase_contract_header."dt_deferred_payment3" is 'Дата отсрочки части платежа 3 | Дата отсрочки части платежа 3 | ekko_ral.zzdtots3';
comment on column dds.purchase_contract_header."dt_deferred_payment4" is 'Дата отсрочки части платежа 4 | Дата отсрочки части платежа 4 | ekko_ral.zzdtots4';
comment on column dds.purchase_contract_header."dt_purchase_contract" is 'Дата контракта на закупку | Дата контракта на закупку | ekko_ral.bedat';
comment on column dds.purchase_contract_header."dt_purchase_contract_paydox" is 'Дата контракта на закупку в PAYDOX | Дата контракта на закупку в PAYDOX | /rusal/dtl_pdx_h_ral.bedat';
comment on column dds.purchase_contract_header."dt_quota_yyyymm" is 'Трейдеры: квота (дата) | Трейдеры: квота (дата) | ekko_ral.zzquota';
comment on column dds.purchase_contract_header."dt_valid_from" is 'Начальный срок действия | Начальный срок действия | ekko_ral.kdatb';
comment on column dds.purchase_contract_header."dt_valid_to" is 'Конечный срок действия | Конечный срок действия | ekko_ral.kdate';
comment on column dds.purchase_contract_header."edm_applicable_code" is 'Электронный документооборот (ЭДО) (код) | Электронный документооборот (ЭДО) (код) | ekko_ral.zzedo';
comment on column dds.purchase_contract_header."external_contract_number_part1" is 'Внешний номер договора с бумажного носителя (вариант 1) | Внешний номер договора с бумажного носителя (вариант 1) | ekko_ral.verkf';
comment on column dds.purchase_contract_header."external_contract_number_part2" is 'Внешнего номера договора с бумажного носителя (продолжение) (вариант 2) | Внешнего номера договора с бумажного носителя (продолжение) (вариант 2) | ekko_ral.telf1';
comment on column dds.purchase_contract_header."hfm_reporting_segment_code" is 'Сегмент отчетности (код) | Сегмент отчетности (код) | ekko_ral.zzsegrep';
comment on column dds.purchase_contract_header."incoterms_code" is 'Инкотермс (код) | Инкотермс (код) | ekko_ral.inco1';
comment on column dds.purchase_contract_header."incoterms_location_code" is 'Инкотермс 2 (Транспортный узел) (код) | Инкотермс 2 (Транспортный узел) (код) | ekko_ral.zzknote';
comment on column dds.purchase_contract_header."incoterms_location_text" is 'Инкотермс 2 | Инкотермс 2 | ekko_ral.inco2';
comment on column dds.purchase_contract_header."is_penalty_charge_linked_to_central_bank_base_rate_code" is 'Плата финансирования / комерческий кредит по ставке рефинансирования ЦБ | Плата финансирования / комерческий кредит по ставке рефинансирования ЦБ | ekko_ral.zzpenaltyrefrate';
comment on column dds.purchase_contract_header."is_released_code" is 'Индикатор: неполное деблокирование (код) | Индикатор: неполное деблокирование (код) | ekko_ral.frgrl';
comment on column dds.purchase_contract_header."legal_agreement_number" is 'Юридический номер договора | Юридический номер договора | ekko_ral.zurdog';
comment on column dds.purchase_contract_header."material_price_group_code" is 'Тип рыночного индикатора (код) | Тип рыночного индикатора (код) | ekko_ral.zzkondm';
comment on column dds.purchase_contract_header."one_time_penalty_charge_amount" is 'Разовый штраф в валюте контракта | Разовый штраф в валюте контракта | ekko_ral.zzonepenalty1';
comment on column dds.purchase_contract_header."one_time_penalty_charge_rate" is 'Разовый штраф, % | Разовый штраф, % | ekko_ral.zzonepenalty';
comment on column dds.purchase_contract_header."ownership_transfer_term_code" is 'Переход права собственности (ППС) (код) | Переход права собственности (ППС) (код) | ekko_ral.zzppskd';
comment on column dds.purchase_contract_header."paydox_contract_type_code" is 'Статус в PayDox (код) | Статус в PayDox (код) | ekko_ral.zzpaydox';
comment on column dds.purchase_contract_header."paydox_document_code" is 'Идентификатор в PAYDOX (код) | Идентификатор в PAYDOX (код) | /rusal/dtl_pdx_h_ral.docidint';
comment on column dds.purchase_contract_header."paydox_document_name" is 'Заголовок документа в PAYDOX | Заголовок документа в PAYDOX | /rusal/dtl_pdx_h_ral.name';
comment on column dds.purchase_contract_header."paydox_document_status_code" is 'Статус PAYDOX (код) | Статус PAYDOX (код) | /rusal/dtl_pdx_h_ral.paydox_status';
comment on column dds.purchase_contract_header."paydox_document_type_code" is 'Вид документа в PayDox (код) | Вид документа в PayDox (код) | /rusal/dtl_pdx_h_ral.bsart_pd';
comment on column dds.purchase_contract_header."paydox_document_url" is 'Ссылка на оригинал документа в PAYDOX | Ссылка на оригинал документа в PAYDOX | /rusal/dtl_pdx_h_ral.url / dms_phio2file_ral.filename';
comment on column dds.purchase_contract_header."paydox_protocol_registration_number" is 'Регистрационный номер протокола из системы PayDox | Регистрационный номер протокола из системы PayDox | ekko_ral.zznumpr';
comment on column dds.purchase_contract_header."paydox_registration_number" is 'Региcтрационный номер, присвоенный документу в PayDox | Региcтрационный номер, присвоенный документу в PayDox | ekko_ral.zzihrez';
comment on column dds.purchase_contract_header."paydox_responsible_person_code" is 'Пользователь PayDox (код) | Пользователь PayDox (код) | ekko_ral.zzernam';
comment on column dds.purchase_contract_header."paydox_unit_balance_code" is 'Организационная единица (код) | Организационная единица (код) | /rusal/dtl_pdx_h_ral.oe';
comment on column dds.purchase_contract_header."payment_and_liability_plan_request_code" is 'Заявка на закупку, используемая для формирования плана обязательств и платежей (код) | Заявка на закупку, используемая для формирования плана обязательств и платежей (код) | ekko_ral.zzbanfn';
comment on column dds.purchase_contract_header."payment_date_calculation_rule_code" is 'Правило расчета даты оплаты (код) | Правило расчета даты оплаты (код) | ekko_ral.zzpaymentrule';
comment on column dds.purchase_contract_header."penalty_charge_calculation_terms_code" is 'Параметр, отражающий от какой суммы выполняется расчет разового штрафа (код) | Параметр, отражающий от какой суммы выполняется расчет разового штрафа (код) | ekko_ral.zzsum';
comment on column dds.purchase_contract_header."penalty_charge_for_delay_rate" is 'Пеня, % | Пеня, % | ekko_ral.zzpenalty';
comment on column dds.purchase_contract_header."penalty_charge_maximum_limit_rate" is 'Максимальный процент для расчета суммы претензии, выставляемой в адрес поставщика при несоблюдении условий договорного документа, % | Максимальный процент для расчета суммы претензии, выставляемой в адрес поставщика при несоблюдении условий договорного документа, % | ekko_ral.zznomore';
comment on column dds.purchase_contract_header."port_code" is 'Порт (код) | Порт (код) | ekko_ral.zzport';
comment on column dds.purchase_contract_header."purchase_contract_available_limit_doc_currency_amount" is 'Остаток суммы по договору | Остаток суммы по договору | zle_dog_limit_ral.ktwrt_balance';
comment on column dds.purchase_contract_header."purchase_contract_draft_code" is 'Номер черновика контракта (код) | Номер черновика контракта (код) | ekko_ral.zztempid';
comment on column dds.purchase_contract_header."purchase_contract_name" is 'Название контракта | Название контракта | ekko_ral.description';
comment on column dds.purchase_contract_header."purchase_contract_registration_number" is 'Регистрационный номер | Регистрационный номер | ekko_ral.ihrez';
comment on column dds.purchase_contract_header."purchase_contract_research_and_development_niokr_name" is 'Название НИОКР | Название НИОКР | ekko_ral.zzniokrtxt';
comment on column dds.purchase_contract_header."purchase_group_code" is 'Группа закупок (код) | Группа закупок (код) | ekko_ral.ekgrp';
comment on column dds.purchase_contract_header."purchase_organization_code" is 'Закупочная организация (код) | Закупочная организация (код) | ekko_ral.ekorg';
comment on column dds.purchase_contract_header."railway_tariff_calculation_method_code" is 'Метод расчета планово-нормативного ЖД-тарифа (код) | Метод расчета планово-нормативного ЖД-тарифа (код) | ekko_ral.zzzhdtarif';
comment on column dds.purchase_contract_header."release_stage_code" is 'Этап деблокирования контракта (код) | Этап деблокирования контракта (код) | ekko_ral.frgke';
comment on column dds.purchase_contract_header."release_status_code" is 'Статус деблокирования (код) | Статус деблокирования (код) | ekko_ral.frgzu';
comment on column dds.purchase_contract_header."release_strategy_code" is 'Стратегия деблокирования (код) | Стратегия деблокирования (код) | ekko_ral.frgsx';
comment on column dds.purchase_contract_header."release_strategy_group_code" is 'Группа деблокирования (код) | Группа деблокирования (код) | ekko_ral.frggr';
comment on column dds.purchase_contract_header."rent_type_code" is 'Тип аренды (код) | Тип аренды (код) | ekko_ral.zzrcode';
comment on column dds.purchase_contract_header."responsibility_center_code" is 'Центр ответственности (код) | Центр ответственности (код) | ekko_ral.zzresp';
comment on column dds.purchase_contract_header."storage_agreement_code" is 'Договор хранения (код) | Договор хранения (код) | ekko_ral.zzvbeln_zx';
comment on column dds.purchase_contract_header."supplier_code" is 'Поставщик (код) | Поставщик (код) | ekko_ral.lifnr';
comment on column dds.purchase_contract_header."tariff_dob_responsibility_code" is 'Тариф - параметр, отражающий распределение транспортных затрат в отчетности КД (код) | Тариф - параметр, отражающий распределение транспортных затрат в отчетности КД (код) | ekko_ral.zztariff';
comment on column dds.purchase_contract_header."terminal_code" is 'Терминал (код) | Терминал (код) | ekko_ral.zzknanf_term';
comment on column dds.purchase_contract_header."terms_of_payment_code" is 'Условие платежа (код) | Условие платежа (код) | ekko_ral.zterm';
comment on column dds.purchase_contract_header."tolling_contract_code" is 'Контракт собственника сырья (код) | Контракт собственника сырья (код) | ekko_ral.zzebeln';
comment on column dds.purchase_contract_header."total_purchase_contract_cost_document_currency_amount" is 'Общая сумма договорного документа с учетом ТЗР и доп.расходов, с НДС | Общая сумма договорного документа с учетом ТЗР и доп.расходов, с НДС | ekko_ral.ktwrt';
comment on column dds.purchase_contract_header."transportation_total_cost_vat_code" is 'Код НДС для ТЗР и Доп.расходов (код) | Код НДС для ТЗР и Доп.расходов (код) | ekko_ral.zzmwskz';
comment on column dds.purchase_contract_header."transportation_total_cost_vat_excluded_amount" is 'Сумма ТЗР и Доп.расходов | Сумма ТЗР и Доп.расходов | ekko_ral.zztzr';
comment on column dds.purchase_contract_header."unified_purchase_contract_code" is 'Единый номер договора (код) | Единый номер договора (код) | ekko_ral.zzunidoc';
comment on column dds.purchase_contract_header."unified_purchase_contract_name" is 'Внешний номер договора с бумажного носителя (полный) | Внешний номер договора с бумажного носителя (полный) | ekko_ral.zzunidoc_s';
comment on column dds.purchase_contract_header."unit_balance_code" is 'Балансовая единица (код) | Балансовая единица (код) | ekko_ral.bukrs';
comment on column dds.purchase_contract_header."is_purchase_contract_draft_code" is 'Индикатор: черновик (код) | Индикатор: черновик (код) | ekko_ral.memory';
