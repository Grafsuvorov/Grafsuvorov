insert
	into
	dm_calc.accounting_documents_header_working_capital
	(
	unit_balance_code,
	fiscal_year,
	accounting_document_code,
	material_code
	)
select 
	t.unit_balance_code,
	t.fiscal_year,
	t.accounting_document_code,
	t.material_code
from
	(
	select
		ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code,
		ad.material_code,
		ad.position_line_item,
		dense_rank() over(
		partition by ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code
	order by
		ad.position_line_item asc 
	) as row_num
	from
		ods.accounting_documents ad
	where
		1 = 1
		and ad.deleted_flag = false
		and ad.is_active = true
		and ad.material_code is not null
	group by
		ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code,
		ad.material_code,
		ad.position_line_item) as t
where
	row_num = 1;
