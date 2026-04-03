insert into dm_calc.accounting_documents_balance_aggregated
select
	ad.unit_balance_code ,
	case
		when ad.account_type in ('D', 'K') then coalesce(ad.plant_code,	wr1.plant_code,	wr3.plant_code)
		else null
	end as plant_code,
	ad.general_ledger_account_code ,
	ad.dt_posting ,
	ad.dt_clearing ,
	case
		when ad.account_type = 'D' then ad.customer_code
		else null
	end as customer_code,
		case
		when ad.account_type = 'K' then ad.supplier_code
		else null
	end as supplier_code,
		case
		when ad.account_type = 'D' then coalesce(ad.customer_code,
		ad.supplier_code)
		when ad.account_type = 'K' then coalesce(ad.supplier_code,
		ad.customer_code)
		else null
	end as counterparty_code,
		case
		when ad.account_type in ('D', 'K') then ltrim(ad.contract_number,'0')
		else null
	end as contract_number,
	sum(case when ad.debit_or_credit = 'S' then coalesce(ad.document_currency_amount, 0) else
	- coalesce(ad.document_currency_amount, 0) end)::numeric(19,2) as balance_closing_document_currency_amount,
	ad.document_currency_code,
	sum(case when ad.debit_or_credit = 'S' then coalesce(ad.local_currency_amount, 0) else
	- coalesce(ad.local_currency_amount, 0) end)::numeric(19,2) as balance_closing_local_currency_amount,
	ad.local_currency_code,
	sum(case when ad.debit_or_credit = 'S' then coalesce(ad.second_local_currency_amount, 0) else
	- coalesce(ad.second_local_currency_amount, 0) end)::numeric(19,2) as balance_closing_second_local_currency_amount,
	ad.second_local_currency_code
from
	dds.accounting_documents ad
left join dm_calc.plant_by_unit_balance wr1 on
	wr1.plant_count > 1
	and wr1.plant_code = ad.reference_key_internal_for_document_header_1
left join dm_calc.plant_by_unit_balance wr3 on
	wr3.plant_count > 1
	and wr3.plant_code = ad.reference_key_for_line_item_3
where
	ad.is_deleted = false
	and ad.deleted_flag = false
	and ad.unit_balance_code not like 'E%'
	and ad.unit_balance_code not like 'F%'
	and ad.unit_balance_code not like 'S%'
group by
	ad.unit_balance_code ,
	case
		when ad.account_type in ('D', 'K') then coalesce(ad.plant_code,	wr1.plant_code,	wr3.plant_code)
		else null
	end,
	ad.general_ledger_account_code ,
	ad.dt_posting ,
	ad.dt_clearing ,
	case
		when ad.account_type = 'D' then ad.customer_code
		else null
	end,
		case
		when ad.account_type = 'K' then ad.supplier_code
		else null
	end,
		case
		when ad.account_type = 'D' then coalesce(ad.customer_code,	ad.supplier_code)
		when ad.account_type = 'K' then coalesce(ad.supplier_code,	ad.customer_code)
		else null
	end,
		case
		when ad.account_type in ('D', 'K') then ltrim(ad.contract_number,'0')
		else null
	end ,
	ad.document_currency_code,
	ad.local_currency_code,
	ad.second_local_currency_code
having
	sum(case when ad.debit_or_credit = 'S' then coalesce(ad.document_currency_amount, 0) else
	- coalesce(ad.document_currency_amount, 0) end)::numeric(19,2) != 0
	or
	sum(case when ad.debit_or_credit = 'S' then coalesce(ad.local_currency_amount, 0) else
	- coalesce(ad.local_currency_amount, 0) end)::numeric(19,2) != 0
	or
	sum(case when ad.debit_or_credit = 'S' then coalesce(ad.second_local_currency_amount, 0) else
	- coalesce(ad.second_local_currency_amount, 0) end)::numeric(19,2) != 0