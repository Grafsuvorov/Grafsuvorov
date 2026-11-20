select count(*) as rows_with_vgtyp_u
from pg_temp.vbrk
where posting_status_code in ('C','E')
  and invoice_realization_group_code is null
  and vgtyp = 'U';
 87924

drop table if exists dds.invoice_realization;

create table if not exists dds.invoice_realization (
    invoice_realization_code varchar null,              -- фактура реализации (код)
    claim_code varchar null,                            -- претензия (код)
    probable_claim_code varchar null,                   -- Возможная претензия (код)
    invoice_realization_group_code varchar null,        -- группа фактуры реализации (код)
    posting_status_code varchar null,                   -- статус передачи данных в бухгалтерию (код)
    sales_invoice_code varchar null,                    -- фактура сбыта (инвойс) (код)
    dt_realization_invoice date null,                   -- дата фактуры реализации
    bank_as_counterparty_code varchar null,             -- банк как контрагент (код)
    realization_invoice_type_code varchar null,         -- тип фактуры реализации (код)
    dt_billing_document date null,                      -- дата фактуры для индекса фактур и печати
    realization_invoice_subtype_code varchar null,      -- вид документа фактуры (код)
    payee_or_payer_code varchar null,                   -- плательщик (код)
    document_currency_code varchar null,                    -- Валюта документа сбыта (код)
    document_currency_vat_excluded_amount numeric(15, 2) null,-- Стоимость нетто в валюте документа
    terms_of_payment_code varchar null,
    country_of_destination_code varchar null,           -- SD.000892 "Страна конечной поставки (код)"
    sales_bank_account_code varchar null,               -- SD.000928 "Собственник банковского счёта (код)"
    is_deleted_code bool null,
    is_reversed_code bool null,
    appropval_status_code varchar null,
    dttm_inserted timestamp not null default now(),
    dttm_updated timestamp not null default now(),
    job_name varchar(60) not null default 'airflow'::character varying,
    deleted_flag bool not null default false
)
with (
    appendonly = true,
    orientation = column,
    compresstype = zstd,
    compresslevel = 3
)
distributed by (invoice_realization_code);

comment on table dds.invoice_realization is 'Фактура реализации: заголовок';
comment on column dds.invoice_realization.invoice_realization_code is 'Фактура реализации (код) | Фактура реализации (код) | ods.vbrk_ral.vbeln';
comment on column dds.invoice_realization.claim_code is 'Претензия (код) | Претензия (код) | ods.zsd7536m_pret.sammg';
comment on column dds.invoice_realization.probable_claim_code is 'Возможная претензия (код) | Возможная претензия (код) | ods.zsd7536m_pret.sammg';
comment on column dds.invoice_realization.invoice_realization_group_code is 'Группа фактуры реализации (код) | Группа фактуры реализации (код) | ods.vbsk_ral.sammg';
comment on column dds.invoice_realization.posting_status_code is 'Статус передачи данных в бухгалтерию (код) | Статус передачи данных в бухгалтерию (код) | ods.vbrk_ral.rfbsk';
comment on column dds.invoice_realization.sales_invoice_code is 'Фактура сбыта (инвойс) (код) | Фактура сбыта (инвойс) (код) | ods.vbrk_ral.zzsammg';
comment on column dds.invoice_realization.dt_realization_invoice is 'Дата фактуры реализации | Дата фактуры реализации | ods.vbsk_ral.zzlddat';
comment on column dds.invoice_realization.bank_as_counterparty_code is 'Банк как контрагент (код) | Банк как контрагент (код) | ods.vbsk_ral.zzbank';
comment on column dds.invoice_realization.realization_invoice_type_code is 'Тип фактуры реализации (код) | Тип фактуры реализации (код) | ods.vbrk_ral.vbtyp';
comment on column dds.invoice_realization.dt_billing_document is 'Дата фактуры для индекса фактур и печати | Дата фактуры для индекса фактур и печати | ods.vbrk_ral.fkdat';
comment on column dds.invoice_realization.payee_or_payer_code is 'Плательщик (код) | Плательщик (код) | ods.vbrk_ral.kunrg';
comment on column dds.invoice_realization.document_currency_code is 'Валюта документа сбыта (код) | Код валюты документа сбыта | ods.vbrk_ral.waerk';
comment on column dds.invoice_realization.document_currency_vat_excluded_amount is 'Стоимость нетто в валюте документа | Стоимость нетто в валюте документа | ods.vbrk_ral.netwr';
comment on column dds.invoice_realization.country_of_destination_code is 'Страна конечной поставки (код) | Код страны, куда направляется поставка.
Если VBRK-ZZSAMMG пусто, то VBPA-LAND1
    по VBPA-VBELN  = SD.000890 "Фактура реализации" и VBPA-PARVW = "SH" (WE)
Если VBRK-ZZSAMMG не пусто и /RUSAL/VBSS_VBSK-SMART != "Р" (кирилица) по /RUSAL/VBSS_VBSK-SAMMG = VBRK-ZZSAMMG, то VBPA-LAND1
    по VBPA-VBELN  = SD.000890 "Фактура реализации" и VBPA-PARVW = SH
Если VBRK-ZZSAMMG не пусто и /RUSAL/VBSS_VBSK-SMART = "Р" по /RUSAL/VBSS_VBSK-SAMMG = VBRK-ZZSAMMG, то SD.000577 "Страна поставки по контракту (код)"
Если VBRK-ZZSAMMG не пусто и /RUSAL/VBSS_VBSK-SMART = "Р" по /RUSAL/VBSS_VBSK-SAMMG = VBRK-ZZSAMMG и SD.000577 "Страна поставки по контракту (код)" = пусто, то VBPA-LAND1
    по VBPA-VBELN = SD.000890 "Фактура реализации" и VBPA-PARVW = "SH" (WE) |
Расчётное';
comment on column dds.invoice_realization.sales_bank_account_code is 'Собственник банковского счёта (код) | Код собственника банковского счёта, данные заполняются только для группы сбыта (инвойс).
VBSK-ZZBANK по VBSK-ZZVBELN = SD.0000891 "Фактура сбыта (инвойс)"
Если записи с факторой сбыта в VBSK smart = "О" нет, то пусто.
Если VBSK–ZZBANK = ПУСТО, то взять первую найденную запись из VBPA-KUNNR и VBPA-PARVW = /RUSAL/ROLE_VAL-ROLE
(берём значения VBPA, если значение VBPA-PARVW присутствует в /RUSAL/ROLE_VAL-ROLE)
    по VBPA-VBELN = VBAK-ZUONR
        по VBAK-VBELN = VBSK-ZZVBELN_RAM
            по VBSK-ZZVBELN = SD.0000891 "Фактура сбыта (инвойс)". |
Расчётное';
comment on column dds.invoice_realization.is_deleted_code is 'Индикатор: удалено (код) | Индикатор: удалено (код) | ods.vbrk_ral.fksto';
comment on column dds.invoice_realization.is_reversed_code is 'Индикатор: сторнировано (код) | Индикатор: сторнировано (код) | ods.vbrk_ral.mrnkz';
comment on column dds.invoice_realization.appropval_status_code is 'Cтатус согласования фактуры (код) | Cтатус согласования фактуры (код) | ods.vbrk_ral.zzinvstatus';

truncate table dds.invoice_realization;

------------------------------------------------------------------------------------------------
-- 1. Основа для всех данных
------------------------------------------------------------------------------------------------

drop table if exists pg_temp.sales_document_counterparty_role_we;
create temporary table pg_temp.sales_document_counterparty_role_we with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
	with cte as (
	select
		d_sdcr.sales_document_code,
		d_sdcr.counterparty_country_code,
		row_number() over (partition by d_sdcr.sales_document_code order by d_sdcr.counterparty_country_code) as rwn
	from dds.sales_document_counterparty_role as d_sdcr
		join ods.vbrk_ral as vbrk on
	    	d_sdcr.sales_document_code = vbrk.vbeln and   
	    	d_sdcr.counterparty_role_code = 'WE'
	)
	select
		sales_document_code,
		counterparty_country_code
	from cte
	where rwn = 1
)
distributed by (sales_document_code);


drop table if exists pg_temp.vbrk;
create temporary table pg_temp.vbrk with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
	with vbrp as (
	    select distinct
	        o_vr.vbeln,
	        o_vr.vgtyp,
	        o_vr.vgbel
	    from ods.vbrp_ral as o_vr	
	    where o_vr.vgtyp = 'U' 
    )
	select
        vbrk.vbeln as invoice_realization_code,             -- фактура реализации (код)
        p.sammg as claim_code,                              -- претензия (код)
        p.sammg as probable_claim_code,                     -- возможная претензия (код)
        vbsk.sammg as invoice_realization_group_code,       -- группа фактуры реализации (код)
        vbrk.rfbsk as posting_status_code,                  -- статус передачи данных в бухгалтерию (код)
        vbsk.zzlddat as dt_realization_invoice,             -- дата фактуры реализации
        vbsk.zzbank as bank_as_counterparty_code,           -- банк как контрагент (код)
        vbrk.vbtyp as realization_invoice_type_code,        -- тип фактуры реализации (код)
        vbrk.fkdat as dt_billing_document,                  -- дата фактуры для индекса фактур и печати,
        vbrk.fkart as realization_invoice_subtype_code,
        vbrk.kunrg as payee_or_payer_code,                  -- плательщик (код)
        vbrk.waerk as document_currency_code,               -- валюта документа сбыта (код)
        vbrk.netwr as document_currency_vat_excluded_amount,-- стоимость нетто в валюте документа
        not coalesce(vbrk.fksto is null, false) as is_deleted_code,
        not coalesce(vbrk.mrnkz is null, false) as is_reversed_code,
        vbrk.zzinvstatus as appropval_status_code,
      	vbrp.vgtyp,
	    vbrp.vgbel,
	    d_sdcr.counterparty_country_code
    from ods.vbrk_ral as vbrk
	    left join ods.zsd7536m_pret_ral as p on
	    	vbrk.vbeln = p.vbeln
	    left join ods.vbsk_ral as vbsk on
	    	vbrk.zzsammg = vbsk.sammg and
	    	vbsk.smart = 'Р'--кирилица (Реализация)
	    left join vbrp on
	    	vbrp.vbeln = vbrk.vbeln
	    left join pg_temp.sales_document_counterparty_role_we as d_sdcr on
	    	d_sdcr.sales_document_code = vbrk.vbeln                 					-- по VBPA-VBELN = SD.000890 "Фактура реализации"
)
distributed by (invoice_realization_code);

drop table if exists pg_temp.sales_document_counterparty_role_we;

------------------------------------------------------------------------------------------------
-- 2. Вспомогательные таблицы
------------------------------------------------------------------------------------------------

drop table if exists pg_temp.vbss_vbsk_base;
create temporary table pg_temp.vbss_vbsk_base with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
    select
        vbrk.invoice_realization_code,
        vbss.vbeln,
        vbss2.sammg,
        vbrk.invoice_realization_group_code
    from pg_temp.vbrk as vbrk
    --определяем поставку по группе из VBRK
    inner join ods.vbss_ral as vbss                                 -- VBSS
        on vbss.sammg = vbrk.invoice_realization_group_code     -- по VBSS-SAMMG = VBRK-ZZSAMMG
    --определяем возможные группы по ранее найденной поставке
    inner join ods.vbss_ral as vbss2                                    -- VBSS
        on vbss2.vbeln = vbss.vbeln
    where vbrk.posting_status_code in ('C', 'E')
)
distributed by (invoice_realization_code);

-- 3.1.
drop table if exists pg_temp.vbss_vbsk_o;
create temporary table pg_temp.vbss_vbsk_o with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
--  определяем группы фактуры сбыта (smart = 'О' (кирилица))
	with cte as (
	    select
	        vvb.invoice_realization_code,
	        vvb.invoice_realization_group_code,
	        vbsk.zzvbeln,
	        row_number() over (
	            partition by
	                vvb.invoice_realization_code, vvb.invoice_realization_group_code
	            order by
	                vbsk.zzvbeln asc
	        ) as rn
	    from pg_temp.vbss_vbsk_base as vvb
	    inner join ods.vbsk_ral as vbsk
	        on
	            vbsk.sammg = vvb.sammg
	            and vbsk.smart = 'О'
	    group by
	        vvb.invoice_realization_code,
	        vvb.invoice_realization_group_code,
	        vbsk.zzvbeln
	)
	select
		invoice_realization_code,
		invoice_realization_group_code,
		zzvbeln
	from cte
	where rn = 1
)
distributed by (invoice_realization_code);

-- 3.2.
drop table if exists pg_temp.vbss_vbsk_q;
create temporary table pg_temp.vbss_vbsk_q with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
	with cte as (
	    select
	        vvb.invoice_realization_code,
	        vvb.invoice_realization_group_code,
	        vbsk.zzvbeln,
	        row_number() over (
	            partition by
	                vvb.invoice_realization_code, vvb.invoice_realization_group_code
	            order by
	                vbsk.zzvbeln asc
	        ) as rn
	    from pg_temp.vbss_vbsk_base as vvb
	    inner join dm_calc.sd_sales_main_scm as ssms
	        on ssms.delivery_number_sales = vvb.vbeln
	    inner join ods.vbss_ral as vbss
	        on vbss.vbeln = ssms.delivery_number_outbound
	    inner join ods.vbsk_ral as vbsk
	        on
	            vbsk.sammg = vbss.sammg
	            and vbsk.smart = 'Q'
	    group by
	        vvb.invoice_realization_code,
	        vvb.invoice_realization_group_code,
	        vbsk.zzvbeln
	)
	select
		invoice_realization_code,
		invoice_realization_group_code,
		zzvbeln
	from cte
	where rn = 1
)
distributed by (invoice_realization_code);

-- 3.3.
drop table if exists pg_temp.vbss_vbsk_k;
create temporary table pg_temp.vbss_vbsk_k with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
	with vbss_vbsk_corr as (
	    select
	        vbss.vbeln,
	        vbsk.zzvbeln,
	        row_number() over (
	            partition by
	                vbss.vbeln
	            order by
	                vbsk.zzlddat,
	                vbsk.uzeit
	        ) as rn
	    from ods.vbss_ral as vbss
	    inner join ods.vbsk_ral as vbsk
	        on
	            vbss.sammg = vbsk.sammg
	            and vbsk.smart = 'К'          -- кириллица
	),
	cte as (
	    select
	        vvb.invoice_realization_code,
	        vvb.invoice_realization_group_code,
	        vvc.zzvbeln,
	        row_number() over (
	            partition by
	                vvb.invoice_realization_code, vvb.invoice_realization_group_code
	            order by
	                vvc.zzvbeln asc
	        ) as rn
	    from pg_temp.vbss_vbsk_base as vvb
	    inner join dm_calc.sd_sales_main_scm as ssms
	        on ssms.delivery_number_sales = vvb.vbeln
	    inner join ods.vbss_ral as vbss
	        on vbss.vbeln = ssms.delivery_number_outbound
	    inner join vbss_vbsk_corr as vvc
	        on
	            vvc.vbeln = ssms.delivery_number_outbound
	            and vvc.rn = 1
	    group by
	        vvb.invoice_realization_code,
	        vvb.invoice_realization_group_code,
	        vvc.zzvbeln
	)
	select
		invoice_realization_code,
		invoice_realization_group_code,
		zzvbeln
	from cte
	where rn = 1
)
distributed by (invoice_realization_code);

drop table if exists pg_temp.vbss_vbsk_base;

------------------------------------------------------------------------------------------------
-- 3. Вспомогательные таблицы
------------------------------------------------------------------------------------------------

drop table if exists pg_temp.vbss_vbsk_o_prepare;
create temporary table pg_temp.vbss_vbsk_o_prepare with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
	select
		d_ldadr2.delivery_code,
		d_i.invoice_code,
		d_i.invoice_type_code,
		d_i.billing_document_code,
		o_mztek."VBELN_P_exp01",
		o_mztek."LAND1_exp04"
	from dds.logistics_document_and_delivery_relationship as d_ldadr2
		left join dds.invoice as d_i on
			d_i.invoice_code = d_ldadr2.logistics_document_code and
			d_i.invoice_type_code = 'О'
	    left join
	        ods.map_zmk_track_exp_keys as o_mztek                                           -- Таблица ключей для витрины "Вагоны по контрактам"
	        on o_mztek."VBELN_P_exp01" = d_ldadr2.delivery_code                             -- по SD.00002 "Продажная поставка" = VBSS-VBELN
)
distributed by (delivery_code);

drop table if exists pg_temp.sales_contract_header_prepare;
create temporary table pg_temp.sales_contract_header_prepare with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
	select
		d_sch.sales_contract_code,
		dd_.sales_partner_role_code,
		d_sdcr2.customer_code
	from dds.sales_contract_header as d_sch
		join dds.sales_document_counterparty_role as d_sdcr2  on                               -- VBPA
	    	d_sdcr2.sales_document_code = d_sch.frame_contract_code                      -- по VBPA-VBELN = VBAK-ZUONR
	    left join dict_dds.sales_partner_role as dd_ on                                             -- /RUSAL/ROLE_VAL
	    	dd_.sales_partner_role_code = d_sdcr2.counterparty_role_code                 -- по VBPA-PARVW = /RUSAL/ROLE_VAL-ROLE
)
distributed by (sales_contract_code);

drop table if exists pg_temp.irc_sic2;
create temporary table pg_temp.irc_sic2 with (appendonly = true,orientation = column,compresstype = zstd,compresslevel = 3) as (
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
)
distributed by (invoice_realization_code);

drop table if exists pg_temp.vbss_vbsk_o_prepare;
drop table if exists pg_temp.sales_contract_header_prepare;

------------------------------------------------------------------------------------------------
-- 4. Итоговый
------------------------------------------------------------------------------------------------

insert into dds.invoice_realization (
    invoice_realization_code,                           -- фактура реализации (код)
    claim_code,                                         -- претензия (код)
    probable_claim_code,                                -- претензия (код)
    invoice_realization_group_code,                     -- группа фактуры реализации (код)
    posting_status_code,                                -- статус передачи данных в бухгалтерию (код)
    sales_invoice_code,                                 -- фактура сбыта (инвойс) (код)
    dt_realization_invoice,                             -- дата фактуры реализации
    bank_as_counterparty_code,                          -- банк как контрагент (код)
    realization_invoice_type_code,                      -- тип фактуры реализации (код)
    dt_billing_document,                                -- дата фактуры для индекса фактур и печати
    realization_invoice_subtype_code,
    payee_or_payer_code,                                -- плательщик (код)
    document_currency_code,                             -- валюта документа сбыта (код)
    document_currency_vat_excluded_amount,              -- стоимость нетто в валюте документа
    terms_of_payment_code,
    country_of_destination_code,                        -- SD.000892 "Страна конечной поставки (код)"
    sales_bank_account_code,                            -- SD.000928 "Собственник банковского счёта (код)"
    is_deleted_code,
    is_reversed_code,
    appropval_status_code
)
select
    vbrk.invoice_realization_code,                                          -- фактура реализации (код)
    vbrk.claim_code,                                                        -- претензия (код)
    vbrk.probable_claim_code,                                               -- претензия (код)
    vbrk.invoice_realization_group_code,                                    -- группа фактуры реализации (код)
    vbrk.posting_status_code,                                               -- статус передачи данных в бухгалтерию (код)
    case
        when vbrk.posting_status_code in ('C', 'E')                         -- VBRK-RFBSK = "C" или "E"
            then
                case
                    when vbrk.realization_invoice_type_code = 'N'
                        then vbrk.invoice_realization_code
                    when vbrk.invoice_realization_group_code is not null
                        then    -- Если VBRK-ZZSAMMG  не пустое и /RUSAL/VBSS_VBSK-SMART = 'Р'
                            case
                                when vvo.zzvbeln is not null then vvo.zzvbeln
                                when vvq.zzvbeln is not null then vvq.zzvbeln
                                when vvk.zzvbeln is not null then vvk.zzvbeln
                                else vbrk.invoice_realization_code
                            end
                    when
                        vbrk.invoice_realization_group_code is null     -- если VBRK-ZZSAMMG пустое
                        and vbrk.vgtyp = 'U'                                -- и VBRP-VGTYP = U,
                        then vbrk.vgbel                                     -- то VBRP-VGBEL
                    else vbrk.invoice_realization_code                      -- иначе SD.0000890 "Фактура реализации"
                end
    end                 as sales_invoice_code,                                              -- sd.000891 "фактура сбыта (инвойс)"
    vbrk.dt_realization_invoice,                                            -- дата фактуры реализации
    vbrk.bank_as_counterparty_code,                                         -- банк как контрагент (код)
    vbrk.realization_invoice_type_code,                                     -- тип фактуры реализации (код)
    vbrk.dt_billing_document,                                               -- дата фактуры для индекса фактур и печати
    vbrk.realization_invoice_subtype_code,
    vbrk.payee_or_payer_code,                                               -- плательщик (код)
    vbrk.document_currency_code,                                            -- валюта документа сбыта (код)
    vbrk.document_currency_vat_excluded_amount,                             -- стоимость нетто в валюте документа
    zv.zzterm_pay       as terms_of_payment_code,
    irc.country_of_destination_code,                                        -- SD.000892 "Страна конечной поставки (код)"
    irc.sales_bank_account_code,                                            -- SD.000928 "Собственник банковского счёта (код)"
    vbrk.is_deleted_code,
    vbrk.is_reversed_code,
    vbrk.appropval_status_code
from pg_temp.vbrk as vbrk
	left join pg_temp.vbss_vbsk_o as vvo on
		vvo.invoice_realization_code = vbrk.invoice_realization_code
	left join pg_temp.vbss_vbsk_q as vvq on
		vvq.invoice_realization_code = vbrk.invoice_realization_code
	left join pg_temp.vbss_vbsk_k as vvk on
		vvk.invoice_realization_code = vbrk.invoice_realization_code    
	left join ods.zvbrk_ral as zv on 
		vbrk.invoice_realization_code = zv.vbeln
	left join pg_temp.irc_sic2 as irc on
		irc.invoice_realization_code = vbrk.invoice_realization_code;
