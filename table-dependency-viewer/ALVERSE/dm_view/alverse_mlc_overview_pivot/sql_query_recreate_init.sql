drop view if exists dm_view.alverse_mlc_overview_pivot;
create or replace view dm_view.alverse_mlc_overview_pivot
as select
	sales_request_code,
	dwh_excel_column_code,
	dwh_table_column_name,
	dwh_table_column_code,
	alverse_business_group_name,
	alverse_business_group_code,
	alverse_business_subgroup_name,
	alverse_business_subgroup_code,
	alverse_concatenated_by_sales_request_field_values_name
from dm.alverse_mlc_overview_pivot
where deleted_flag is false;

comment on view dm_view.alverse_mlc_overview_pivot is 'Витрина Overview для MLC';
comment on column dm_view.alverse_mlc_overview_pivot.sales_request_code is 'Заказ ЦК в отгрузке | Заказ ЦК в отгрузке | Расчетное поле SD.000005';
comment on column dm_view.alverse_mlc_overview_pivot.dwh_excel_column_code is 'Поле источник (идентификатор поля в описании витрин) | Поле источник (идентификатор поля в описании витрин) | Расчетное поле';
comment on column dm_view.alverse_mlc_overview_pivot.dwh_table_column_name is 'Поле источник (наименование поля в таблице) | Поле источник (наименование поля в таблице) | Расчетное поле';
comment on column dm_view.alverse_mlc_overview_pivot.dwh_table_column_code is 'Поле источник (код - техническое имя поля в таблице) | Поле источник (код - техническое имя поля в таблице) | Расчетное поле';
comment on column dm_view.alverse_mlc_overview_pivot.alverse_business_group_name is 'Группа поля (наименование) | Верхнеуровневая группа, где отмечены поля относящиеся, к примеру, к Контрату | Расчетное поле SD.001253';
comment on column dm_view.alverse_mlc_overview_pivot.alverse_business_group_code is 'Техническое поле для сортировки (1) | Верхнеуровневая группа, где отмечены поля относящиеся, к примеру, к Контрату | Расчетное поле SD.001253';
comment on column dm_view.alverse_mlc_overview_pivot.alverse_business_subgroup_name is 'Подгруппа поля (наименование) | Подуровневая группа к полю Head group, где отмечены поля относящиеся, к примеру, к группе Контрату, но имеют раграничения, к примеру География (инко, базис), или Заключили контракт (клиент, сам контракт) | Расчетное поле SD.001254';
comment on column dm_view.alverse_mlc_overview_pivot.alverse_business_subgroup_code is 'Техническое поле для сортировки (2) | Подуровневая группа к полю Head group, где отмечены поля относящиеся, к примеру, к группе Контрату, но имеют раграничения, к примеру География (инко, базис), или Заключили контракт (клиент, сам контракт) | Расчетное поле SD.001254';
comment on column dm_view.alverse_mlc_overview_pivot.alverse_concatenated_by_sales_request_field_values_name is 'Уникальные значение по полям "Источник" в рамках поля "Заказ ЦК в отгрузке" через сепаратор '';'' | Специфика для витрины MLC, суть в том, чтобы объеденить все строки уникального заказа, и если к примеру в поле Базис мы построчно встречаем 1или более Базсиов, то вписать их через точку с запятой в одной яцейке | Расчетное поле SD.001255';
