drop table if exists dm.alverse_mlc_overview_pivot cascade;
create table dm.alverse_mlc_overview_pivot (
	sales_request_code varchar null,
	dwh_excel_column_code varchar null,
	dwh_table_column_name varchar null,
	dwh_table_column_code varchar null,
	alverse_business_group_name varchar null,
	alverse_business_group_code varchar null,
	alverse_business_subgroup_name varchar null,
	alverse_business_subgroup_code varchar null,
	alverse_concatenated_by_sales_request_field_values_name text null,
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
distributed by (sales_request_code, dwh_excel_column_code);


comment on table dm.alverse_mlc_overview_pivot is 'Витрина Overview для MLC';
comment on column dm.alverse_mlc_overview_pivot.sales_request_code is 'Заказ ЦК в отгрузке | Заказ ЦК в отгрузке | Расчетное поле SD.000005';
comment on column dm.alverse_mlc_overview_pivot.dwh_excel_column_code is 'Поле источник (идентификатор поля в описании витрин) | Поле источник (идентификатор поля в описании витрин) | Расчетное поле';
comment on column dm.alverse_mlc_overview_pivot.dwh_table_column_name is 'Поле источник (наименование поля в таблице) | Поле источник (наименование поля в таблице) | Расчетное поле';
comment on column dm.alverse_mlc_overview_pivot.dwh_table_column_code is 'Поле источник (код - техническое имя поля в таблице) | Поле источник (код - техническое имя поля в таблице) | Расчетное поле';
comment on column dm.alverse_mlc_overview_pivot.alverse_business_group_name is 'Группа поля (наименование) | Верхнеуровневая группа, где отмечены поля относящиеся, к примеру, к Контрату | Расчетное поле SD.001253';
comment on column dm.alverse_mlc_overview_pivot.alverse_business_group_code is 'Техническое поле для сортировки (1) | Верхнеуровневая группа, где отмечены поля относящиеся, к примеру, к Контрату | Расчетное поле SD.001253';
comment on column dm.alverse_mlc_overview_pivot.alverse_business_subgroup_name is 'Подгруппа поля (наименование) | Подуровневая группа к полю Head group, где отмечены поля относящиеся, к примеру, к группе Контрату, но имеют раграничения, к примеру География (инко, базис), или Заключили контракт (клиент, сам контракт) | Расчетное поле SD.001254';
comment on column dm.alverse_mlc_overview_pivot.alverse_business_subgroup_code is 'Техническое поле для сортировки (2) | Подуровневая группа к полю Head group, где отмечены поля относящиеся, к примеру, к группе Контрату, но имеют раграничения, к примеру География (инко, базис), или Заключили контракт (клиент, сам контракт) | Расчетное поле SD.001254';
comment on column dm.alverse_mlc_overview_pivot.alverse_concatenated_by_sales_request_field_values_name is 'Уникальные значение по полям "Источник" в рамках поля "Заказ ЦК в отгрузке" через сепаратор '';'' | Специфика для витрины MLC, суть в том, чтобы объеденить все строки уникального заказа, и если к примеру в поле Базис мы построчно встречаем 1или более Базсиов, то вписать их через точку с запятой в одной яцейке | Расчетное поле SD.001255';
