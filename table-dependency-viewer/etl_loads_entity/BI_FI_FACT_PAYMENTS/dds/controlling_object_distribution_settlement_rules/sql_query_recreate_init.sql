drop table if exists dds.controlling_object_distribution_settlement_rules cascade;
CREATE TABLE dds.controlling_object_distribution_settlement_rules (
	object_code	varchar(22),
	distribution_rule_group_code	varchar(3),
	distribution_rule_sequence_code	varchar(3),
	wbs_element_code	varchar(8),

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
DISTRIBUTED RANDOMLY;

----------------------------------------------------------------------------------------------------------------COMMENT
comment on table 	dds.controlling_object_distribution_settlement_rules is 'Правила распределения/правило расчета/расчет затрат по зак.';
comment on column dds.controlling_object_distribution_settlement_rules.object_code is 'Номер объекта | Номер объекта | OBJNR';
comment on column dds.controlling_object_distribution_settlement_rules.distribution_rule_group_code is 'Группа ПравРаспределения | Группа ПравРаспределения | BUREG';
comment on column dds.controlling_object_distribution_settlement_rules.distribution_rule_sequence_code is 'Порядковый номер правило распределения | Порядковый номер правило распределения | LFDNR';
comment on column dds.controlling_object_distribution_settlement_rules.wbs_element_code is 'Элемент структурного плана проекта (СПП-элемент) | Элемент структурного плана проекта (СПП-элемент) | PS_PSP_PNR';