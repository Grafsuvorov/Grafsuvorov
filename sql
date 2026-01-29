select bukrs, belnr,gjahr,buzei from
						( select 
								--row_number() over (partition by bukrs, belnr,gjahr,buzei order by file_num desc, row_num desc) r,
								s.*,case
        	when nullif(ppdat, '00000000')is null then null
        	else (ppdat::date || ' ' || to_timestamp(pptme,'PTHH24:MI:SS')::time)::timestamp end as dt_accounting_document_provisionally_registered,
		tech_etl.util_text_to_null_validation(ppnam) as accounting_document_provisionally_registered_by_code
					,row_number() over (partition by bukrs, belnr,gjahr,buzei order by file_num desc, row_num desc) r  from stg.ral_zbw1595m_odata_srv s
						  where sap_pointer = '20260128233010_000222000' --and ppdat<>'00000000'
						) a 
				   where r=2 and accounting_document_provisionally_registered_by_code is not null
