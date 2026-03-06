drop table if exists dm_calc.operating_periods_for_account_debt cascade;
create table dm_calc.operating_periods_for_account_debt (
unit_balance_code varchar(4) not null,
dt date null,
is_second_friday bool null,
is_for_account_debt_only bool null,
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


grant select on table dm_calc.operating_periods_for_account_debt to soldatovaae;


comment on table dm_calc.operating_periods_for_account_debt is 'Периоды работы балансовых единиц';
comment on column dm_calc.operating_periods_for_account_debt.unit_balance_code is 'Балансовая единица | Балансовая единица | dict_dds.plant_and_subsidiary.unit_balance_code';
comment on column dm_calc.operating_periods_for_account_debt.dt is 'Дата | Каждый последний день или каждая вторая пятница каждого месяца по годам с открытия БЕ до текущего момента | Алгоритм';
comment on column dm_calc.operating_periods_for_account_debt.is_second_friday is 'Флаг: вторая пятница месяца | Флаг: вторая пятница месяца | Алгоритм';
comment on column dm_calc.operating_periods_for_account_debt.is_for_account_debt_only is 'Флаг: даты для расчета dm.account_debt | Флаг: даты для расчета dm.account_debt | Алгоритм';

