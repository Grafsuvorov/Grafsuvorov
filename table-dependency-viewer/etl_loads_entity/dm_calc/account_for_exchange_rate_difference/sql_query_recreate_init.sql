drop table if exists dm_calc.account_for_exchange_rate_difference;

 CREATE  TABLE dm_calc.account_for_exchange_rate_difference (
	local_account_for_adjustment_code varchar(30) NULL,
	unit_balance_code varchar(12) NULL,
	dttm_inserted 	timestamp not null default now(),
	dttm_updated 	timestamp not null default now(),
	job_name 		varchar(60) not null default 'airflow'::character varying,
	deleted_flag	bool not null default false )

WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED REPLICATED;