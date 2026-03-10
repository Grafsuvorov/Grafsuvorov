delete
from
	dds.tax_accruals_and_payments_aggregated d
where
	d.fiscal_year in 
(
	select
		distinct fiscal_year
	from
		ods.tax_accruals_and_payments_aggregated o);