delete
from
	dds.investment_expenses as d
where
	d.fiscal_year in 
(
	select
		distinct o.fiscal_year
	from
		ods.investment_expenses as o);