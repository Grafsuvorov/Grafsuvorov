insert into dm_calc.accounting_exchange_rate_revaluation (
	unit_balance_code,
	fiscal_year,
	account_type ,
	accounting_document_code,
	position_line_item,
	position_line_item_text,
	accounting_document_type,
	dt_posting,
	dt_accounting_document,
	debit_or_credit,
	general_ledger_account_code,
	special_general_ledger_indicator,
	document_currency_code,
	local_currency_code,
	second_local_currency_code,
	document_currency_amount,
	local_currency_amount,
	second_local_currency_amount,
	is_red_reverse_posting,
	reference_document_code,
	reference_document_fiscal_year,
	reference_document_position_line_item,
	reverse_document_code,
	reverse_document_fiscal_year,
	is_reversed_document
		)
SELECT
	ad.unit_balance_code,
	ad.fiscal_year,
	ad.account_type ,
	ad.accounting_document_code,
	ad.position_line_item,
	ad.position_line_item_text,
	ad.accounting_document_type,
	ad.dt_posting,
	ad.dt_accounting_document,
	ad.debit_or_credit,
	ad.general_ledger_account_code,
	ad.special_general_ledger_indicator,
	ad.document_currency_code,
	ad.local_currency_code,
	ad.second_local_currency_code,
	ad.document_currency_amount,
	ad.local_currency_amount,
	ad.second_local_currency_amount,
	ad.is_red_reverse_posting,
	CASE
		WHEN ad.position_line_item_text ~ '^(Оценка|Valuation) [0-9]{9,10} [0-9]{1,3}[- ][0-9]{1,4}( .*)?$' 
		THEN split_part(regexp_replace(ad.position_line_item_text,'[-]',' '),' ',2)
		ELSE NULL
	END AS reference_document_code,
	CASE
		WHEN ad.position_line_item_text ~ '^(Оценка|Valuation) [0-9]{9,10} [0-9]{1,3}[- ][0-9]{1,4}( .*)?$' 
		THEN split_part(regexp_replace(ad.position_line_item_text,'[-]',' '),' ',4)::NUMERIC
		ELSE NULL
	END AS reference_document_fiscal_year,
	CASE
		WHEN ad.position_line_item_text ~ '^(Оценка|Valuation) [0-9]{9,10} [0-9]{1,3}[- ][0-9]{1,4}( .*)?$' 
		THEN split_part(regexp_replace(ad.position_line_item_text,'[-]',' '),' ',3)::NUMERIC
		ELSE NULL
	END AS reference_document_position_line_item,
	ad.reverse_document_code,
	ad.reverse_document_fiscal_year,
	ad.is_reversed_document
FROM 
	ods.accounting_documents as ad
JOIN (select
			dict_aerd.local_account_for_adjustment_code,
			be.unit_balance_code
		from
			dict_dds.account_for_exchange_rate_difference as dict_aerd
		join dict_dds.unit_balance as be
			on dict_aerd.account_chart_code = be.account_chart_code
		join dict_dds.general_ledger_accounts_main_data as dict_glad
			on be.unit_balance_code = dict_glad.unit_balance_code
			and dict_aerd.general_ledger_account_code  = dict_glad.general_ledger_account_code
		where
			1 = 1
			and dict_aerd.currency_code is null
			and dict_aerd.currency_and_valuation_type_code = '30'
			and dict_glad.account_type_code in ('D', 'K')
		group by 
			dict_aerd.local_account_for_adjustment_code, 
			be.unit_balance_code
	) as acc 
	ON	ad.general_ledger_account_code = acc.local_account_for_adjustment_code
	AND ad.unit_balance_code = acc.unit_balance_code
WHERE 
	1 = 1
	AND ad.is_active = true
	and ad.deleted_flag = false;