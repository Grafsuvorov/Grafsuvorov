SQL Error [53000]: ERROR: number of workfiles per query limit exceeded  (seg0 slice3 192.168.20.203:10000 pid=79883)

explain
	    select
   
	        
	                d_ir.invoice_realization_code,

	                d_ir.invoice_realization_group_code ,
	                d_ldadr2.invoice_code ,
	                d_ir.counterparty_country_code ,
	                d_ldadr2."LAND1_exp04" ,
	                d_i2.billing_document_code ,
	                d_sch.sales_partner_role_code ,
	                count(*)
	      
	    from
	        pg_temp.vbrk as d_ir                                                    -- VBRK
	    --определяем поставку по группе из VBRK
	    left join
	        dds.logistics_document_and_delivery_relationship as d_ldadr                     -- VBSS
	        on d_ldadr.logistics_document_code = d_ir.invoice_realization_group_code        -- по VBSS-SAMMG = VBRK-ZZSAMMG
	        
		left join
	        vbss_vbsk_o_dedup as d_ldadr2                    -- VBSS
	        on d_ldadr2.delivery_code = d_ldadr.delivery_code            
	    
	    left join  dds.invoice as d_i2 on
	    	d_i2.billing_document_code = case
	                						when d_ir.invoice_realization_group_code is not null and d_ldadr2.billing_document_code is not null
												then d_ldadr2.billing_document_code
											when d_ir.invoice_realization_group_code is null and d_ir.vgtyp = 'U'
												then d_ir.vgbel
											else d_ir.invoice_realization_code
	            						end                                                                         -- SD.0000891 "Фактура сбыта (инвойс)"
				and d_ldadr2.invoice_type_code = 'О' 
		left join
	        pg_temp.sales_contract_header_prepare as d_sch                                              -- VBAK
	        on d_sch.sales_contract_code = d_i2.sales_contract_code                         -- по VBAK-VBELN = VBSK-ZZVBELN_RAM
	
	    where d_ir.posting_status_code in ('C', 'E')
	    group by  d_ir.invoice_realization_code,

	                d_ir.invoice_realization_group_code ,
	                d_ldadr2.invoice_code ,
	                d_ir.counterparty_country_code ,
	                d_ldadr2."LAND1_exp04" ,
	                d_i2.billing_document_code ,
	                d_sch.sales_partner_role_code 
	                having count(*)>1
Gather Motion 8:1  (slice7; segments: 8)  (cost=0.00..4584129.74 rows=7327051983 width=61)
  ->  Result  (cost=0.00..3344960.39 rows=915881498 width=61)
        Filter: ((count()) > 1)
        ->  HashAggregate  (cost=0.00..3269629.14 rows=2289703745 width=69)
              Group Key: vbrk.invoice_realization_code, vbrk.invoice_realization_group_code, vbss_vbsk_o_dedup.invoice_code, vbrk.counterparty_country_code, vbss_vbsk_o_dedup."LAND1_exp04", invoice.billing_document_code, sales_contract_header_prepare.sales_partner_role_code
              ->  Redistribute Motion 8:8  (slice6; segments: 8)  (cost=0.00..1133782.03 rows=2289703745 width=53)
                    Hash Key: vbrk.invoice_realization_code, vbrk.invoice_realization_group_code, vbss_vbsk_o_dedup.invoice_code, vbrk.counterparty_country_code, vbss_vbsk_o_dedup."LAND1_exp04", invoice.billing_document_code, sales_contract_header_prepare.sales_partner_role_code
                    ->  Hash Left Join  (cost=0.00..753943.08 rows=2289703745 width=53)
                          Hash Cond: ((invoice.sales_contract_code)::text = (sales_contract_header_prepare.sales_contract_code)::text)
                          ->  Redistribute Motion 8:8  (slice5; segments: 8)  (cost=0.00..258375.29 rows=327273855 width=61)
                                Hash Key: invoice.sales_contract_code
                                ->  Hash Left Join  (cost=0.00..195888.89 rows=327273855 width=61)
                                      Hash Cond: ((CASE WHEN ((NOT (vbrk.invoice_realization_group_code IS NULL)) AND (NOT (vbss_vbsk_o_dedup.billing_document_code IS NULL))) THEN vbss_vbsk_o_dedup.billing_document_code WHEN ((vbrk.invoice_realization_group_code IS NULL) AND ((vbrk.vgtyp)::text = 'U'::text)) THEN vbrk.vgbel ELSE vbrk.invoice_realization_code END)::text = (invoice.billing_document_code)::text)
                                      Join Filter: ((vbss_vbsk_o_dedup.invoice_type_code)::text = 'О'::text)
                                      ->  Hash Left Join  (cost=0.00..64684.36 rows=93343133 width=66)
                                            Hash Cond: ((logistics_document_and_delivery_relationship.delivery_code)::text = (vbss_vbsk_o_dedup.delivery_code)::text)
                                            ->  Redistribute Motion 8:8  (slice3; segments: 8)  (cost=0.00..17283.68 rows=41680436 width=49)
                                                  Hash Key: logistics_document_and_delivery_relationship.delivery_code
                                                  ->  Hash Right Join  (cost=0.00..10891.16 rows=41680436 width=49)
                                                        Hash Cond: ((logistics_document_and_delivery_relationship.logistics_document_code)::text = (vbrk.invoice_realization_group_code)::text)
                                                        ->  Redistribute Motion 8:8  (slice1; segments: 8)  (cost=0.00..1406.03 rows=6802701 width=22)
                                                              Hash Key: logistics_document_and_delivery_relationship.logistics_document_code
                                                              ->  Seq Scan on logistics_document_and_delivery_relationship  (cost=0.00..659.23 rows=6802701 width=22)
                                                        ->  Hash  (cost=594.36..594.36 rows=487349 width=38)
                                                              ->  Redistribute Motion 8:8  (slice2; segments: 8)  (cost=0.00..594.36 rows=487349 width=38)
                                                                    Hash Key: vbrk.invoice_realization_group_code
                                                                    ->  Seq Scan on vbrk  (cost=0.00..536.39 rows=487349 width=38)
                                                                          Filter: ((posting_status_code)::text = ANY ('{C,E}'::text[]))
                                            ->  Hash  (cost=504.09..504.09 rows=1925941 width=39)
                                                  ->  Seq Scan on vbss_vbsk_o_dedup  (cost=0.00..504.09 rows=1925941 width=39)
                                      ->  Hash  (cost=496.38..496.38 rows=356392 width=22)
                                            ->  Broadcast Motion 8:8  (slice4; segments: 8)  (cost=0.00..496.38 rows=356392 width=22)
                                                  ->  Seq Scan on invoice  (cost=0.00..435.31 rows=44549 width=22)
                          ->  Hash  (cost=493.63..493.63 rows=2920023 width=14)
                                ->  Seq Scan on sales_contract_header_prepare  (cost=0.00..493.63 rows=2920023 width=14)
Optimizer: Pivotal Optimizer (GPORCA)

