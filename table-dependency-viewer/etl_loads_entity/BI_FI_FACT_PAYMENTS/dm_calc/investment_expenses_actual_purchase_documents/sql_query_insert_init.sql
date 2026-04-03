insert into dm_calc.investment_expenses_actual_purchase_documents
select
		pc.purchase_contract_code as purchase_document_code ,
		pcp.position_line_item_code,
		pc.supplier_code,
		pcp.number_of_principal_purchase_agreement ,
		'purchase_contract' as source_table_name
	from
		dds.purchase_contract_header  pc
		left join dds.purchase_contract_position pcp on 
		pcp.purchase_contract_code = pc.purchase_contract_code 
union all
	select
		po.purchase_order_code as purchase_document_code ,
		pop.position_line_item_code,
		po.supplier_code,
		pop.number_of_principal_purchase_agreement,
		'purchase_order' as source_table_name
	from
		dds.purchase_order_header po
	left join dds.purchase_order_position pop on 
		pop.purchase_order_code = po.purchase_order_code 
union all
	select
		pa.purchase_agreement_code as purchase_document_code ,
		pap.position_line_item_code,
		pa.supplier_code,
		pap.number_of_principal_purchase_agreement,
		'purchase_agreement' as source_table_name
	from
		dds.purchase_agreement_header pa
	left join dds.purchase_agreement_position pap on 
		pap.purchase_agreement_code = pa.purchase_agreement_code;