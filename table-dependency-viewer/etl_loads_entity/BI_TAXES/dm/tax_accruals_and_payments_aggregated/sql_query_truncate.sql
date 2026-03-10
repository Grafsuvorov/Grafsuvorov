delete
from
	dm.tax_accruals_and_payments_aggregated
where
	fiscal_year in
(
	select
		distinct
		fiscal_year
	from
		dds.tax_accruals_and_payments_aggregated
	where
		dttm_inserted
in (
		select
			max(dttm_inserted)
		from
			dds.tax_accruals_and_payments_aggregated));