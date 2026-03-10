insert into dm_calc.investment_payments_accounting_document_header 
select
		ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code,
		ad.dt_posting,
		ad.reverse_document_code,
		ad.reverse_document_fiscal_year,
		revdoc.dt_posting as dt_posting_reverse_document
from
		dds.accounting_documents ad
inner join dict_dds.settings_and_parameters_sap saps on
		saps.abap_program_code = '/RUSAL/FI1349M'
	and ad.unit_balance_code = saps.case_code
	and (saps.parameter_code = 'SO_BLAFI' )
	and saps.range_sign_code is not null
	and saps.range_low_value = ad.accounting_document_type
left join dds.accounting_documents revdoc on
		revdoc.unit_balance_code = ad.unit_balance_code
	and revdoc.fiscal_year = ad.reverse_document_fiscal_year
	and revdoc.accounting_document_code = ad.reverse_document_code
where
	ad.is_active = true
	and ad.deleted_flag = false 
	and( revdoc.is_active = true or revdoc.is_active is null)
	and( revdoc.deleted_flag = false or revdoc.deleted_flag is null)
group by
		ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code,
		ad.dt_posting,
		ad.reverse_document_code,
		ad.reverse_document_fiscal_year,
		revdoc.dt_posting;