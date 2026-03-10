delete
from
	ods.rusal_ovs_ral
where
	bdatj between (date_part('year',
	(now() - interval '1 year')))::varchar and (date_part('year',
	now()))::varchar;