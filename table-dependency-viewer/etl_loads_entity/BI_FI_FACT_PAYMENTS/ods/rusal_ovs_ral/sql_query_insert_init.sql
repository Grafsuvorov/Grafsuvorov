insert
	into
	ods.rusal_ovs_ral(
	bukrs,
	bdatj,
	poper,
	dtype,
	werks,
	id,
	hkont,
	kalnr,
	bwagr,
	saknr,
	account,
	lifnrka,
	bklas,
	meins,
	menge,
	dmbtr,
	dmbe2
)
select
	"BUKRS"::varchar(4) as bukrs,
	"BDATJ"::varchar(4) as bdatj,
	"POPER"::varchar(3) as poper,
	"DTYPE"::varchar(1) as dtype,
	tech_etl.util_text_to_null_validation("WERKS") as werks,
	"ID"::varchar(20) as id,
	tech_etl.util_text_to_null_validation("HKONT") as hkont,
	"KALNR"::varchar(12) as kalnr,
	tech_etl.util_text_to_null_validation("BWAGR") as bwagr,
	tech_etl.util_text_to_null_validation("SAKNR") as saknr,
	tech_etl.util_text_to_null_validation("ACCOUNT") as account,
	tech_etl.util_text_to_null_validation("LIFNRKA") as lifnrka,
	tech_etl.util_text_to_null_validation("BKLAS") as bklas,
	tech_etl.util_text_to_null_validation("MEINS") as meins,
	"MENGE"::numeric(15,3) as menge,
	"DMBTR"::numeric(17,2) as dmbtr,
	"DMBE2"::numeric(17,2) as dmbe2
from
	stg."/RUSAL/OVS"
where
	1 = 1
	and "MANDT" = '400'
	and "BDATJ" between (date_part('year',
	(now() - interval '1 year')))::varchar and (date_part('year',now()))::varchar;