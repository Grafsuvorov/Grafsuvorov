drop table if exists ods.map_controlling_transport_and_procurement_cost_keys;

----------------------------------------------------------------------------------------------------------------CREATE
CREATE TABLE ods.map_controlling_transport_and_procurement_cost_keys (
	report_version_code	varchar(10),
	unit_balance_code	varchar(4),
	plant_code	varchar(4),
	fiscal_year	numeric(4,0),
	fiscal_period	varchar(3),
	report_line_code	varchar(20),
	report_column_code	varchar(20),
	subsequent_code varchar(3),
	cost_element_code	varchar(10),
	local_currency_amount	numeric(17,2),
	local_currency_code varchar(5),
	second_local_currency_amount	numeric(17,2),
	second_local_currency_code varchar(5),
	
	dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	dttm_updated	timestamp	NOT NULL DEFAULT now(),
	job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,	
	deleted_flag	bool	NOT NULL DEFAULT false
)
WITH (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 1
)
DISTRIBUTED RANDOMLY;-----------------------------------------

----------------------------------------------------------------------------------------------------------------COMMENT
comment on table ods.map_controlling_transport_and_procurement_cost_keys is 'Маппер определения ТЗР в "Расшифровка к строке 211,214"';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.report_version_code is 'Код отчета | Код отчета | REPCOD';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.unit_balance_code is 'Балансовая единица | Балансовая единица | BUKRS';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.plant_code is 'Завод | Завод | WERKS';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.fiscal_year is 'Финансовый год | Финансовый год | GJAHR';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.fiscal_period is 'Период | Период | PERIO';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.report_line_code is 'Код строки отчета | Код строки отчета | LNCOD';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.report_column_code is 'Код столбца отчета | Код столбца отчета | CLCOD';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.subsequent_code is 'Простой индекс для обеспечения возможности сохранять записи с остальными одинаковыми ключевыми полями | Простой индекс | INDX';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.cost_element_code is 'Вид затрат (без преобразования) | Вид затрат (без преобразования) | KSTAR';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.local_currency_amount is 'Общая сумма в валюте объекта | Общая сумма в валюте объекта | WOGBTR';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.local_currency_code is 'Общая сумма в валюте объекта | Общая сумма в валюте объекта | unit_balance.currency_code';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.second_local_currency_amount is 'Общая сумма в валюте КЕ | Общая сумма в валюте КЕ | WKGBTR';
comment on column ods.map_controlling_transport_and_procurement_cost_keys.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | controlling_area.currency_code';
