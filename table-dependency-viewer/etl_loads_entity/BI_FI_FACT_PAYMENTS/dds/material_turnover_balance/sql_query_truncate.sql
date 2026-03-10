delete from dds.material_turnover_balance
where posting_period_yyyy between (date_part('year',
	(now() - interval '1 year')))::varchar and (date_part('year',now()))::varchar;
