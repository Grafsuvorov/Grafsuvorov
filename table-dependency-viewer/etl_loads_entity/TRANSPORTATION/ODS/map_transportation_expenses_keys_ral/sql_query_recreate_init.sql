drop table ods.map_transportation_expenses_keys_ral;

create table ods.map_transportation_expenses_keys_ral (  -- ключ expense_code, dt_expense_period_yyyymm, delivery_code, service_code
	expense_code varchar(5) not null,
	dt_expense_period_yyyymm varchar(6) not null,
	delivery_code varchar(10) not null,
	service_code varchar(18) null,
	delivery_at_plant_code varchar(10) null,
	expense_position_code varchar(3) null,
	transport_type_at_plant_code varchar(4) null,
	expense_amount numeric(13, 2) null default 0,
	expense_currency_code varchar(5) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false 
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=1
)
distributed randomly;

comment on table ods.map_transportation_expenses_keys_ral is 'Затраты на перевозку';
comment on column ods.map_transportation_expenses_keys_ral.expense_code is 'Затрата (код) | Затрата (код) | ZLE_1431M_FRAHT.EXPENSE';
comment on column ods.map_transportation_expenses_keys_ral.dt_expense_period_yyyymm is 'Период (годмесяц) | Период (годмесяц) | ZLE_1431M_FRAHT.PERIOD_';
comment on column ods.map_transportation_expenses_keys_ral.delivery_code is 'Поставка | Поставка | ZLE_1431M_FRAHT.VBELN';
comment on column ods.map_transportation_expenses_keys_ral.service_code is '№ Услуги | № Услуги | ZLE_1431M_FRAHT.ZSRVPOS';
comment on column ods.map_transportation_expenses_keys_ral.delivery_at_plant_code is 'Заводская поставка | Заводская поставка | ZLE_1431M_FRAHT.VBELN_LF';
comment on column ods.map_transportation_expenses_keys_ral.expense_position_code is 'Статья затрат | Статья затрат | ZLE_1431M_FRAHT.LINE_ITEM';
comment on column ods.map_transportation_expenses_keys_ral.transport_type_at_plant_code is 'Тип вагона, указанный в графике отгрузке на заводе-производителе | Тип вагона, указанный в графике отгрузке на заводе-производителе | ZLE_1431M_FRAHT.SDABW';
comment on column ods.map_transportation_expenses_keys_ral.expense_amount is 'Сумма за поставку | Сумма за поставку | ZLE_1431M_FRAHT.KWERT';
comment on column ods.map_transportation_expenses_keys_ral.expense_currency_code is 'Валюта ставки | Валюта ставки | ZLE_1431M_FRAHT.WAERS';