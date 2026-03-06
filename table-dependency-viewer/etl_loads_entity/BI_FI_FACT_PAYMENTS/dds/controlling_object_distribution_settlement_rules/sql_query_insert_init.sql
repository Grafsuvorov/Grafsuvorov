insert into dds.controlling_object_distribution_settlement_rules
select 
	"OBJNR"::varchar(22)	as object_code,
	"BUREG"::varchar(3)	as distribution_rule_group_code,
	"LFDNR"::varchar(3)	as distribution_rule_sequence_code,
	"PS_PSP_PNR"::varchar(8)	as wbs_element_code
from stg."COBRB"
where 1=1
	and "MANDT" = '400';
	