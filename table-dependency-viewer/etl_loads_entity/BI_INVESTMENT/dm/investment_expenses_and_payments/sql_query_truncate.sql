delete
from
	dm.investment_expenses_and_payments
where
	fiscal_year in
(
	select

		fiscal_year
	from
		dds.investment_expenses
	where
		dttm_inserted
in (
		select
			max(dttm_inserted)
		from
			dds.investment_expenses));
