explain
	with irc_sic as (
	    select
	        d_ir.invoice_realization_code,      -- VBRK-VBELN                               -- SD.000890 "Фактура реализации"                                                                           -- SD.000891 "Фактура сбыта (инвойс)"
	        case
	            when d_ir.invoice_realization_group_code is null            -- Если /RUSAL/VBSS_VBSK-SMART != 'Р',
	                then d_ir.counterparty_country_code                   -- то VBPA-LAND1;
	            else coalesce(
	                d_ldadr2."LAND1_exp04",                          -- если SD.000577 "Страна поставки по контракту (код)" не пусто, то SD.000577 "Страна поставки по контракту (код)",
	                d_ir.counterparty_country_code
	            )                       -- если SD.000577 "Страна поставки по контракту (код)" пусто, то VBPA-LAND1
	        end as country_of_destination_code,                                                                         -- SD.000892 "Страна конечной поставки (код)"
	        case
	            when
	                d_i2.billing_document_code is not null                  -- если SD.000891 "Фактура сбыта (инвойс)" есть в VBSK
	                and d_i2.bank_as_counterparty_code is not null          -- и VBSK-ZZBANK не пусто,
	                then d_i2.bank_as_counterparty_code                     -- то VBSK-ZZBANK,
	            when
	                d_i2.billing_document_code is not null                  -- если SD.000891 "Фактура сбыта (инвойс)" есть в VBSK,
	                and d_i2.bank_as_counterparty_code is null              -- и VBSK-ZZBANK пусто,
	                and d_sch.sales_partner_role_code is not null                             -- и значение VBPA-PARVW присутствует в /RUSAL/ROLE_VAL-ROLE
	                then d_sch.customer_code                              -- то VBPA-KUNNR                                                    -- иначе пусто
	        end as sales_bank_account_code,                                                                             -- SD.000928 "Собственник банковского счёта (код)"
	        row_number() over (
	            partition by
	                d_ir.invoice_realization_code
	            order by
	                d_ir.invoice_realization_group_code asc,
	                d_ldadr2.invoice_code asc,
	                d_ir.counterparty_country_code asc,
	                d_ldadr2."LAND1_exp04" asc,
	                d_i2.billing_document_code asc,
	                d_sch.sales_partner_role_code asc
	        ) as rn
	    from
	        pg_temp.vbrk as d_ir                                                    -- VBRK
	    --определяем поставку по группе из VBRK
	    left join
	        dds.logistics_document_and_delivery_relationship as d_ldadr                     -- VBSS
	        on d_ldadr.logistics_document_code = d_ir.invoice_realization_group_code        -- по VBSS-SAMMG = VBRK-ZZSAMMG
	        
		left join
	        pg_temp.vbss_vbsk_o_prepare as d_ldadr2                    -- VBSS
	        on d_ldadr2.delivery_code = d_ldadr.delivery_code            
	    
	    left join dds.invoice as d_i2 on
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
	)
    select
        irc_sic.invoice_realization_code,                   -- SD.000890 "Фактура реализации"
        irc_sic.country_of_destination_code,                -- SD.000892 "Страна конечной поставки (код)"
        irc_sic.sales_bank_account_code                     -- SD.000928 "Собственник банковского счёта (код)"
    from irc_sic
    where irc_sic.rn = 1

Gather Motion 8:1  (slice7; segments: 8)  (cost=0.00..1405071522.40 rows=107998023359 width=24)
  ->  Result  (cost=0.00..1397885333.93 rows=13499752920 width=24)
        Filter: ((row_number() OVER (?)) = 1)
        ->  Result  (cost=0.00..1396774979.25 rows=33749382300 width=32)
              ->  WindowAgg  (cost=0.00..1395694999.02 rows=84373455749 width=69)
                    Partition By: vbrk.invoice_realization_code
                    Order By: vbrk.invoice_realization_group_code, vbss_vbsk_o_prepare.invoice_code, vbrk.counterparty_country_code, vbss_vbsk_o_prepare."LAND1_exp04", invoice.billing_document_code, sales_contract_header_prepare.sales_partner_role_code
                    ->  Sort  (cost=0.00..1357726943.93 rows=84373455749 width=75)
                          Sort Key: vbrk.invoice_realization_code, vbrk.invoice_realization_group_code, vbss_vbsk_o_prepare.invoice_code, vbrk.counterparty_country_code, vbss_vbsk_o_prepare."LAND1_exp04", invoice.billing_document_code, sales_contract_header_prepare.sales_partner_role_code
                          ->  Redistribute Motion 8:8  (slice6; segments: 8)  (cost=0.00..55430768.85 rows=84373455749 width=75)
                                Hash Key: vbrk.invoice_realization_code
                                ->  Hash Left Join  (cost=0.00..35624100.12 rows=84373455749 width=75)
                                      Hash Cond: ((invoice.sales_contract_code)::text = (sales_contract_header_prepare.sales_contract_code)::text)
                                      ->  Redistribute Motion 8:8  (slice5; segments: 8)  (cost=0.00..7350936.30 rows=10035757788 width=72)
                                            Hash Key: invoice.sales_contract_code
                                            ->  Hash Left Join  (cost=0.00..5089277.92 rows=10035757788 width=72)
                                                  Hash Cond: ((CASE WHEN ((NOT (vbrk.invoice_realization_group_code IS NULL)) AND (NOT (vbss_vbsk_o_prepare.billing_document_code IS NULL))) THEN vbss_vbsk_o_prepare.billing_document_code WHEN ((vbrk.invoice_realization_group_code IS NULL) AND ((vbrk.vgtyp)::text = 'U'::text)) THEN vbrk.vgbel ELSE vbrk.invoice_realization_code END)::text = (invoice.billing_document_code)::text)
                                                  Join Filter: ((vbss_vbsk_o_prepare.invoice_type_code)::text = 'О'::text)
                                                  ->  Hash Left Join  (cost=0.00..707854.79 rows=2855066579 width=66)
                                                        Hash Cond: ((logistics_document_and_delivery_relationship.delivery_code)::text = (vbss_vbsk_o_prepare.delivery_code)::text)
                                                        ->  Redistribute Motion 8:8  (slice3; segments: 8)  (cost=0.00..17003.66 rows=40818185 width=49)
                                                              Hash Key: logistics_document_and_delivery_relationship.delivery_code
                                                              ->  Hash Right Join  (cost=0.00..10743.38 rows=40818185 width=49)
                                                                    Hash Cond: ((logistics_document_and_delivery_relationship.logistics_document_code)::text = (vbrk.invoice_realization_group_code)::text)
                                                                    ->  Redistribute Motion 8:8  (slice1; segments: 8)  (cost=0.00..1406.03 rows=6802701 width=22)
                                                                          Hash Key: logistics_document_and_delivery_relationship.logistics_document_code
                                                                          ->  Seq Scan on logistics_document_and_delivery_relationship  (cost=0.00..659.23 rows=6802701 width=22)
                                                                    ->  Hash  (cost=594.37..594.37 rows=487434 width=38)
                                                                          ->  Redistribute Motion 8:8  (slice2; segments: 8)  (cost=0.00..594.37 rows=487434 width=38)
                                                                                Hash Key: vbrk.invoice_realization_group_code
                                                                                ->  Seq Scan on vbrk  (cost=0.00..536.40 rows=487434 width=38)
                                                                                      Filter: ((posting_status_code)::text = ANY ('{C,E}'::text[]))
                                                        ->  Hash  (cost=670.63..670.63 rows=6807594 width=39)
                                                              ->  Seq Scan on vbss_vbsk_o_prepare  (cost=0.00..670.63 rows=6807594 width=39)
                                                  ->  Hash  (cost=526.92..526.92 rows=356392 width=33)
                                                        ->  Broadcast Motion 8:8  (slice4; segments: 8)  (cost=0.00..526.92 rows=356392 width=33)
                                                              ->  Seq Scan on invoice  (cost=0.00..435.31 rows=44549 width=33)
                                      ->  Hash  (cost=493.63..493.63 rows=2920023 width=25)
                                            ->  Seq Scan on sales_contract_header_prepare  (cost=0.00..493.63 rows=2920023 width=25)
Optimizer: Pivotal Optimizer (GPORCA)
