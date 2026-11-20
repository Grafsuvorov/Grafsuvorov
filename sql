drop table if exists t_orig;
create temp table t_orig as
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
        (select * from pg_temp.vbrk
         where invoice_realization_code in (select invoice_realization_code from t_sample)) as d_ir   -- ИЗМЕНЕНО: было "pg_temp.vbrk as d_ir"
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
distributed by (invoice_realization_code);
