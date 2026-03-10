CREATE TABLE dds.material_turnover_balance (
	unit_balance_code	varchar(4),
	posting_period_yyyy	varchar(4),
	posting_period_mmm	varchar(3),
	data_type_code	varchar(1),
	plant_code	varchar(4),
	row_code	varchar(20),
	general_ledger_account_code	varchar(10),
	calculation_code	varchar(12),
	movement_type_code	varchar(4),
	correspondence_general_ledger_account_code	varchar(10),
	turnover_table_account_code	varchar(15),
	supplier_agent_code	varchar(10),
	valuation_class_code	varchar(4),
	uom_code	varchar(3),
	quantity	numeric(15,3),
	local_currency_amount	numeric(17,2),
	second_local_currency_amount	numeric(17,2),

	dttm_inserted	timestamp	NOT NULL DEFAULT now(),
	dttm_updated	timestamp	NOT NULL DEFAULT now(),
	job_name	varchar(60)	NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag	bool	NOT NULL DEFAULT false
)
WITH (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED BY (row_code);
---unit_balance_code,posting_period_yyyy,posting_period_mmm,data_type_code,plant_code,row_code
----------------------------------------------------------------------------------------------------------------COMMENT
comment on table 	dds.material_turnover_balance is 'Таблица материальных оборотов';
comment on column dds.material_turnover_balance.unit_balance_code is 'Балансовая единица | Балансовая единица | BUKRS';
comment on column dds.material_turnover_balance.posting_period_yyyy is 'Дата проводки ГГГГ | Дата проводки ГГГГ | BDATJ';
comment on column dds.material_turnover_balance.posting_period_mmm is 'Период проводки | Период проводки | POPER';
comment on column dds.material_turnover_balance.data_type_code is 'Тип данных в строке | Тип данных в строке | DTYPE';
comment on column dds.material_turnover_balance.plant_code is 'Завод | Завод | WERKS';
comment on column dds.material_turnover_balance.row_code is 'Ид строки | Ид строки | ID';
comment on column dds.material_turnover_balance.general_ledger_account_code is 'Основной счет главной бухгалтерии | Основной счет главной бухгалтерии | HKONT';
comment on column dds.material_turnover_balance.calculation_code is 'Номер калькуляции для кальк. без количественной структуры | Номер калькуляции для кальк. без количественной структуры | KALNR';
comment on column dds.material_turnover_balance.movement_type_code is 'Группа видов движения для МСБ | Группа видов движения для МСБ | BWAGR';
comment on column dds.material_turnover_balance.correspondence_general_ledger_account_code is 'Корреспондирующий счет | Корреспондирующий счет | SAKNR';
comment on column dds.material_turnover_balance.turnover_table_account_code is 'Номер основного счета (без преобразования) | Номер основного счета (без преобразования) | ACCOUNT';
comment on column dds.material_turnover_balance.supplier_agent_code is 'Номер счета поставщика или кредитора | Номер счета поставщика или кредитора | LIFNRKA';
comment on column dds.material_turnover_balance.valuation_class_code is 'Класс оценки | Класс оценки | BKLAS';
comment on column dds.material_turnover_balance.uom_code is 'Базовая единица измерения | Базовая единица измерения | MEINS';
comment on column dds.material_turnover_balance.quantity is 'Общее количество | Общее количество | MENGE';
comment on column dds.material_turnover_balance.local_currency_amount is 'Общая сумма в валюте объекта | Общая сумма в валюте объекта | DMBTR';
comment on column dds.material_turnover_balance.second_local_currency_amount is 'Общая сумма в валюте КЕ | Общая сумма в валюте КЕ | DMBE2';
