--Таблицу не дропать и не транкейтить !!!!
create table if not exists dm.dq_sd0001(
	error_code text null,												-- ID проверки
    error_short_name text null,											-- Краткое наименование
    error_full_name text null,											-- Полное наименование (текст ошибки)
    business_area_code text null,										-- Функциональная область
    error_type_code text null,											-- Тип проверки (1-бизнес/2-технический)
    severity_type_code text null,										-- Степень критичности (3-info|2-warning|1-critical)
    error_description_text text null,									-- Бизнес-смысл
    error_algorithm_text text null,										-- Алгоритм
    table_source_code text null,										-- Проверяемые таблицы
    table_log_code text null,											-- Таблица-лог с деталями   
    delivery_number_sales varchar null,									-- Продажная поставка SD.000002
    batch varchar null,													-- Партия SD.000004
    dt_sailed_loading_port date null,									-- Sailed L.Port SD.000058
	bill_of_lading_group_code varchar null,								-- Группа коносамента SD.000040
	is_shipped_via_overseas_second_foreign_warehouse varchar null,		-- Наличие Иностранный склад 2 SD.000485
	delivery_basis varchar null,										-- Базис поставки SD.000067
	second_foreign_port_of_discharge_plan_name varchar null,			-- Плановый порт выгрузки 2 SD.000493     
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
distributed by (delivery_number_sales, batch);

comment on table dm.dq_sd0001 IS 'есть Sailed. L. Port, но нет коносамента РФ';
comment on column dm.dq_sd0001.error_code is 'ID проверки | - | dict_dds.dq_error.error_code';
comment on column dm.dq_sd0001.error_short_name is 'Краткое наименование | - | dict_dds.dq_error.error_short_name';
comment on column dm.dq_sd0001.error_full_name is 'Полное наименование (текст ошибки) | - | dict_dds.dq_error.error_full_name';
comment on column dm.dq_sd0001.business_area_code is 'Функциональная область | - | dict_dds.dq_error.business_area_code';
comment on column dm.dq_sd0001.error_type_code is 'Тип проверки (1-бизнес/2-технический) | - | dict_dds.dq_error.error_type_code';
comment on column dm.dq_sd0001.severity_type_code is 'Степень критичности (3-info|2-warning|1-critical) | - | dict_dds.dq_error.severity_type_code';
comment on column dm.dq_sd0001.error_description_text is 'Бизнес-смысл | - | dict_dds.dq_error.error_description_text';
comment on column dm.dq_sd0001.error_algorithm_text is 'Алгоритм  | - | dict_dds.dq_error.error_algorithm_text';
comment on column dm.dq_sd0001.table_source_code is 'Проверяемые таблицы | - | dict_dds.dq_error.table_source_code';
comment on column dm.dq_sd0001.table_log_code is 'Таблица-лог с деталями | - | dict_dds.dq_error.table_log_code';
comment on column dm.dq_sd0001.delivery_number_sales is 'Продажная поставка | - | dm_calc.sd_sales_main_scm.delivery_number_sales';
comment on column dm.dq_sd0001.batch is 'Партия | - | dm_calc.sd_sales_main_scm.batch';
comment on column dm.dq_sd0001.dt_sailed_loading_port is 'Sailed L.Port | - | dm_calc.sd_sales_main_scm.dt_sailed_loading_port';
comment on column dm.dq_sd0001.bill_of_lading_group_code is 'Группа коносамента | - | dm_calc.sd_sales_main_scm.bill_of_lading_group_code';
comment on column dm.dq_sd0001.is_shipped_via_overseas_second_foreign_warehouse is 'Наличие Иностранный склад 2 | - | dm_calc.sd_sales_main_scm.is_shipped_via_overseas_second_foreign_warehouse';
comment on column dm.dq_sd0001.delivery_basis is 'Базис поставки | - | dm_calc.sd_sales_main_scm.delivery_basis';
comment on column dm.dq_sd0001.second_foreign_port_of_discharge_plan_name is 'Плановый порт выгрузки 2 | - | dm_calc.sd_sales_main_scm.second_foreign_port_of_discharge_plan_name';

delete from 
	dm.dq_sd0001
where 
	dttm_inserted < current_date - 180
	or dttm_inserted::date = current_date;

insert into dm.dq_sd0001 (
	error_code,															-- ID проверки
    error_short_name,													-- Краткое наименование
    error_full_name,													-- Полное наименование (текст ошибки)
    business_area_code,													-- Функциональная область
    error_type_code,													-- Тип проверки (1-бизнес/2-технический)
    severity_type_code,													-- Степень критичности (3-info|2-warning|1-critical)    
    error_description_text,												-- Бизнес-смысл
    error_algorithm_text,												-- Алгоритм
    table_source_code,													-- Проверяемые таблицы 
    table_log_code,														-- Таблица-лог с деталями 
    delivery_number_sales,												-- Продажная поставка SD.000002
    batch,																-- Партия SD.000004
    dt_sailed_loading_port,												-- Sailed L.Port SD.000058
	bill_of_lading_group_code,											-- Группа коносамента SD.000040
	is_shipped_via_overseas_second_foreign_warehouse,					-- Наличие Иностранный склад 2 SD.000485
	delivery_basis,														-- Базис поставки SD.000067
	second_foreign_port_of_discharge_plan_name							-- Плановый порт выгрузки 2 SD.000493   
)

with inco as (
	select 
		range_low_value
	from
		dict_dds.settings_and_parameters_sap 
	where
		abap_program_code = '/RUSAL/MK_TRACK_ROUTE' 					
		and parameter_code in ('INCO1CIF', 'INCO1CIP', 'INCO1FOB')									
		and range_sign_code = 'I' 
		and range_option_code = 'EQ' 
		and range_low_value is not null		
)
select
	de.error_code,														-- ID проверки
    de.error_short_name,												-- Краткое наименование
    de.error_full_name,													-- Полное наименование (текст ошибки)
    de.business_area_code,												-- Функциональная область
    de.error_type_code,													-- Тип проверки (1-бизнес/2-технический)
    de.severity_type_code,												-- Степень критичности (3-info|2-warning|1-critical)
    de.error_description_text,											-- Бизнес-смысл
    de.error_algorithm_text,											-- Алгоритм
    de.table_source_code,												-- Проверяемые таблицы
    de.table_log_code,													-- Таблица-лог с деталями
	wuc.delivery_number_sales, 											-- Продажная поставка SD.000002
	wuc.batch,															-- Партия SD.000004
	wuc.dt_sailed_loading_port,											-- Sailed L.Port SD.000058
	wuc.bill_of_lading_group_code,										-- Группа коносамента SD.000040
	wuc.is_shipped_via_overseas_second_foreign_warehouse,				-- Наличие Иностранный склад 2 SD.000485
	wuc.delivery_basis,													-- Базис поставки SD.000067
	wuc.second_foreign_port_of_discharge_plan_name						-- Плановый порт выгрузки 2 SD.000493 	
from 
	dm.sb_wuc as wuc
	left join dict_dds.dq_error as de 
		on de.error_code = 'dq_sd0001'
where 	
	wuc.dt_sailed_loading_port is not null
	and wuc.bill_of_lading_group_code is null
	and (wuc.is_shipped_via_overseas_second_foreign_warehouse is null 
	or wuc.delivery_basis not in (select range_low_value from inco))
	and wuc.second_foreign_port_of_discharge_plan_name is null
;
