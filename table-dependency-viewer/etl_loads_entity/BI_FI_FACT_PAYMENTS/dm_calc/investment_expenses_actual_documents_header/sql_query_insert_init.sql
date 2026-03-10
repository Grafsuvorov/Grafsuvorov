insert into dm_calc.investment_expenses_actual_documents_header
SELECT 							
	ad.unit_balance_code , 
	ad.fiscal_year,
	ad.accounting_document_code,
	ad.reference_procedure,
	ad.reference_object_key,
	dense_rank() over(
		partition by reference_object_key
		order by accounting_document_code asc 
	) as row_num
FROM dds.accounting_documents ad	
WHERE 1=1								
	and ad.is_active = true		
	and ad.deleted_flag = false
	and ad.reference_object_key is not null
	and ad.reference_object_key <> ' '
	and reference_procedure in ('RMRP','MKPF')	
group by 
	ad.unit_balance_code , 
	ad.fiscal_year,
	ad.accounting_document_code,
	ad.reference_procedure,
	ad.reference_object_key;