Итог по паре
dds.sales_contract и ods.sales_contract похожи на 95%. Совпадающих выражений SELECT: 11. Совпадает: Общие источники, Общие SQL-функции. Отличается: Логика почти идентична, различия минимальны.
Пара выглядит как хороший кандидат на объединение в один расчёт.
Совпадает
Общие источники
stg.vbak
stg.vbkd
Общие SQL-функции
util_text_to_date_validation
util_text_to_null_validation
util_text_to_timestamp_validation
Одинаковые алиасы в SELECT
contract_type_code
created_by
dt_changed
dt_created
dt_sales_contract
external_contract_number
frame_contract_code
responsibility_center_code
sales_contract_code
sales_contract_registration_number
sales_contract_type_code
sales_group_code
WHERE совпадает
auart in ('zdgs', 'zdgq', 'zdgo', 'zdgt', 'zdtt') and tech_etl.util_text_to_null_validation(vbak.vbeln) is not null;
Отличается
Сильных отличий не найдено.
Object A
Открыть таблицу
dds.sales_contract
dds.sales_contract (BI_SB_WUC) | Режим загрузки: TRUNCATE_INIT | Слои зависимостей: stg | Ключевые поля: не указаны | Проверки: не указаны | SQL-функции: util_text_to_date_validation, util_text_to_null_validation, util_text_to_timestamp_validation | Источники SQL: stg.vbak, stg.vbkd
Фичи SQL
fn:util_text_to_date_validation
fn:util_text_to_null_validation
fn:util_text_to_timestamp_validation
src:stg.vbak
src:stg.vbkd
SELECT-выражения
sales_contract_code
tech_etl.util_text_to_null_validation(vbak.vbeln) as sales_contract_code
sales_contract_type_code
tech_etl.util_text_to_null_validation(vbkd.bsark) as sales_contract_type_code
frame_contract_code
tech_etl.util_text_to_null_validation(vbak.zuonr) as frame_contract_code
dt_sales_contract
tech_etl.util_text_to_date_validation(vbak.audat) as dt_sales_contract
external_contract_number
tech_etl.util_text_to_null_validation(vbkd.bstkd) as external_contract_number
sales_group_code
tech_etl.util_text_to_null_validation(vbak.vkgrp) as sales_group_code
responsibility_center_code
tech_etl.util_text_to_null_validation(vbak.zzresp) as responsibility_center_code
contract_type_code
tech_etl.util_text_to_null_validation(vbak.abrvw) as contract_type_code
Object B
Открыть таблицу
ods.sales_contract
ods.sales_contract (BI_SB_WUC) | Режим загрузки: TRUNCATE_INIT | Слои зависимостей: stg | Ключевые поля: не указаны | Проверки: не указаны | SQL-функции: util_text_to_date_validation, util_text_to_null_validation, util_text_to_timestamp_validation | Источники SQL: stg.vbak, stg.vbkd
Фичи SQL
fn:util_text_to_date_validation
fn:util_text_to_null_validation
fn:util_text_to_timestamp_validation
src:stg.vbak
src:stg.vbkd
SELECT-выражения
sales_contract_code
tech_etl.util_text_to_null_validation(vbak.vbeln) as sales_contract_code
sales_contract_type_code
tech_etl.util_text_to_null_validation(vbkd.bsark) as sales_contract_type_code
frame_contract_code
tech_etl.util_text_to_null_validation(vbak.zuonr) as frame_contract_code
dt_sales_contract
tech_etl.util_text_to_date_validation(vbak.audat) as dt_sales_contract
external_contract_number
tech_etl.util_text_to_null_validation(vbak.bstnk) as external_contract_number
sales_group_code
tech_etl.util_text_to_null_validation(vbak.vkgrp) as sales_group_code
responsibility_center_code
tech_etl.util_text_to_null_validation(vbak.zzresp) as responsibility_center_code
contract_type_code
tech_etl.util_text_to_null_validation(vbak.abrvw) as contract_type_code
