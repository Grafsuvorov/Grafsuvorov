drop table if exists dm_calc.plant_by_unit_balance;
create table if not exists dm_calc.plant_by_unit_balance (
	unit_balance_code varchar(4) not null,
	plant_code varchar(4) null,
	plant_name varchar(30) null,
	plant_full_name varchar(30) null,
	plant_count numeric(3) null,
	
	deleted_flag bool	NOT NULL DEFAULT FALSE,
	dttm_inserted	timestamp NOT NULL DEFAULT now(),
	dttm_updated	timestamp NOT NULL DEFAULT now(),
	job_name	varchar(60) NOT NULL DEFAULT 'airflow'::CHARACTER VARYING

)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed replicated;


comment on table dm_calc.plant_by_unit_balance is 'Заводы по балансовым единицам';
comment on column dm_calc.plant_by_unit_balance.unit_balance_code is 'Балансовая единица | Балансовая единица | dict_dds.plant_and_subsidiary.unit_balance_code';
comment on column dm_calc.plant_by_unit_balance.plant_code is 'Завод | Завод | dict_dds.plant_and_subsidiary.plant_code';
comment on column dm_calc.plant_by_unit_balance.plant_name is 'Завод, короткое наименование | Завод, короткое наименование | dict_dds.plant_and_subsidiary.plant_short_name';
comment on column dm_calc.plant_by_unit_balance.plant_full_name is 'Завод, полное наименование | Завод, полное наименование | dict_dds.plant_and_subsidiary.plant_full_name';
comment on column dm_calc.plant_by_unit_balance.plant_count is 'Количество заводов | Количество заводов | Алгоритм';
