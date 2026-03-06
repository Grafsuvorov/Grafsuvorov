insert
	into
	dds.accounting_documents_texts (
			unit_balance_code,
			fiscal_year,
			accounting_document_code,
			language_code,
			document_text,
			consignee_code,
			consigner_code,
			agency_contract_code,
			agent_code,
			personal_account_or_subaccount_code,
			invoice_amount_text
	)
select 
	substring(rti.text_key_identifier_code from 1 for 4) as unit_balance_code,
	substring(rti.text_key_identifier_code from 15 for 4)::numeric as fiscal_year ,
	substring(rti.text_key_identifier_code from 5 for 10) as accounting_document_code ,
	rti.language_code ,
	max(case when rti.text_object_identifier_code = '0001' then rti.text_value end) as document_text ,	   
	max(case when rti.text_object_identifier_code = 'S004' then rti.text_value end) as consignee_code ,	   
	max(case when rti.text_object_identifier_code = 'S014' then rti.text_value end) as consigner_code ,
	max(case when rti.text_object_identifier_code = 'S020' then rti.text_value end) as agency_contract_code ,
	max(case when rti.text_object_identifier_code = 'S030' then rti.text_value end) as agent_code ,
	max(case when rti.text_object_identifier_code = 'S036' then rti.text_value end) as personal_account_or_subaccount_code ,
	max(case when rti.text_object_identifier_code = 'S059' then rti.text_value end) as invoice_amount_text
from
	ods.texts_from_sap_fm_read_text as rti
where 
		rti.application_object_code = 'BELEG'
	and length(rti.text_key_identifier_code) = 18
	and rti.is_active = true
group by 
		rti.text_key_identifier_code , 
		rti.language_code,  
		rti.is_active
having
	max(case when rti.text_object_identifier_code = '0001' then rti.text_value end) is not null
	or max(case when rti.text_object_identifier_code = 'S004' then rti.text_value end) is not null
	or max(case when rti.text_object_identifier_code = 'S014' then rti.text_value end) is not null
	or max(case when rti.text_object_identifier_code = 'S020' then rti.text_value end) is not null
	or max(case when rti.text_object_identifier_code = 'S030' then rti.text_value end) is not null
	or max(case when rti.text_object_identifier_code = 'S036' then rti.text_value end) is not null
	or max(case when rti.text_object_identifier_code = 'S059' then rti.text_value end) is not null;