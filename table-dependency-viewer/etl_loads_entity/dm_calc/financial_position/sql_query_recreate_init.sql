create table dm_calc.financial_position (
	financial_management_area_code 			varchar(12) NULL,
	financial_position_external_code 		varchar(72) NULL,
	financial_position_full_name 			varchar(150) NULL,
	financial_position_internal_code 		varchar(42) NULL,
	financial_position_short_name 			varchar(60) NULL,
	fiscal_year 							numeric(4) NULL,
	language_code 							varchar(3) NULL,
	deleted_flag 							bool NOT NULL DEFAULT FALSE,	
	dttm_inserted 							timestamp NOT NULL DEFAULT now(),	
	dttm_updated 							timestamp NOT NULL DEFAULT now(),	
	job_name 								varchar(60) NOT NULL DEFAULT 'airflow'::CHARACTER VARYING
)
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
distributed replicated;

comment on table dm_calc.financial_position is 'Финансовые позиции';
comment on column dm_calc.financial_position.financial_management_area_code is 'Единица финансового менеджмента | Единица финансового менеджмента | dict_dds.financial_position_master_data_texts.financial_management_area_code';
comment on column dm_calc.financial_position.financial_position_external_code is 'Финансовая позиция внешняя | Финансовая позиция внешняя | dict_dds.map_financial_position.financial_position_external_code';
comment on column dm_calc.financial_position.financial_position_full_name is 'Описание | Описание | dict_dds.financial_position_master_data_texts.financial_position_full_name';
comment on column dm_calc.financial_position.financial_position_internal_code is 'Финансовая позиция внутренняя | Финансовая позиция внутренняя | dict_dds.map_financial_position.financial_position_internal_code';
comment on column dm_calc.financial_position.financial_position_short_name is 'Название | Название | dict_dds.financial_position_master_data_texts.financial_position_short_name';
comment on column dm_calc.financial_position.fiscal_year is 'Финансовый год | Финансовый год | dict_dds.financial_position_master_data_texts.fiscal_year';
comment on column dm_calc.financial_position.language_code is 'Язык | Язык | dict_dds.financial_position_master_data_texts.language_code';