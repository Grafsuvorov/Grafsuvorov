drop table if exists dm_calc.unit_balance_operating_periods cascade;
create table dm_calc.unit_balance_operating_periods (
unit_balance_code varchar(4) not null,
dt_end_of_month date null,
deleted_flag bool not null default false,
dttm_inserted timestamp not null default now(),
dttm_updated timestamp not null default now(),
job_name varchar(60) not null default 'airflow'::character varying
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed REPLICATED;

grant select on table dm_calc.unit_balance_operating_periods to samoshkinvg;
grant select on table dm_calc.unit_balance_operating_periods to soldatovaae;
grant select on table dm_calc.unit_balance_operating_periods to khramovdv;

comment on table dm_calc.unit_balance_operating_periods is 'Периоды работы балансовых единиц';
comment on column dm_calc.unit_balance_operating_periods.unit_balance_code is 'Балансовая единица | Балансовая единица | dict_dds.plant_and_subsidiary.unit_balance_code';
comment on column dm_calc.unit_balance_operating_periods.dt_end_of_month is 'Дата конца месяца | Каждый последний день каждого месяца по годам с открытия БЕ до текущего момента | Алгоритм';