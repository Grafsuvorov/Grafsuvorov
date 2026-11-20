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

------------------------------------------------------------------------------------------------
-- 3.4. Расчёт country_of_destination_code и sales_bank_account_code (pg_temp.irc_sic2)
--      Вместо одного запроса с миллиардами строк перед row_number() считаем по шагам:
--      строки без группы и с группой отдельно, справочники схлопываем до джойнов.
------------------------------------------------------------------------------------------------

-- a. Нужные строки vbrk
drop table if exists pg_temp.irc_vbrk;
create temporary table pg_temp.irc_vbrk as
select
    invoice_realization_code,
    invoice_realization_group_code,
    counterparty_country_code
from pg_temp.vbrk
where posting_status_code in ('C', 'E')
distributed by (invoice_realization_code);

analyze pg_temp.irc_vbrk;

-- b. Строки БЕЗ группы: страна контрагента, банк пусто.
--    (invoice_realization_code в vbrk уникален, поэтому row_number не нужен;
--     в исходном запросе для этих строк инвойс не присоединялся: условие d_ldadr2.invoice_type_code = 'О' всегда ложно)
drop table if exists pg_temp.irc_res_nogroup;
create temporary table pg_temp.irc_res_nogroup as
select
    invoice_realization_code,
    counterparty_country_code as country_of_destination_code,
    null::varchar as sales_bank_account_code
from pg_temp.irc_vbrk
where invoice_realization_group_code is null
distributed by (invoice_realization_code);

-- c. VBSS только по нужным группам
drop table if exists pg_temp.irc_vbss;
create temporary table pg_temp.irc_vbss as
select
    l.logistics_document_code,
    l.delivery_code
from dds.logistics_document_and_delivery_relationship as l
where l.logistics_document_code in (
    select invoice_realization_group_code
    from pg_temp.irc_vbrk
    where invoice_realization_group_code is not null
)
distributed by (delivery_code);

analyze pg_temp.irc_vbss;

-- d. Группа -> уникальные наборы значений из prepare (схлопываются дубли)
drop table if exists pg_temp.irc_grp;
create temporary table pg_temp.irc_grp as
select distinct
    l.logistics_document_code as grp,
    p.invoice_code,
    p."LAND1_exp04",
    p.billing_document_code,
    p.invoice_type_code
from pg_temp.irc_vbss as l
left join pg_temp.vbss_vbsk_o_prepare as p
    on p.delivery_code = l.delivery_code
distributed by (grp);

analyze pg_temp.irc_grp;

-- e. Одна строка на контракт (с минимальной ролью): убирает размножение строк из-за нескольких партнёров VBPA
drop table if exists pg_temp.irc_sch;
create temporary table pg_temp.irc_sch as
select distinct on (sales_contract_code)
    sales_contract_code,
    sales_partner_role_code,
    customer_code
from pg_temp.sales_contract_header_prepare
order by
    sales_contract_code,
    sales_partner_role_code asc,
    customer_code asc
distributed by (sales_contract_code);

analyze pg_temp.irc_sch;

-- f. Привязка наборов к фактурам реализации с группой
drop table if exists pg_temp.irc_step2;
create temporary table pg_temp.irc_step2 as
select
    v.invoice_realization_code,
    v.invoice_realization_group_code,
    v.counterparty_country_code,
    g.invoice_code,
    g."LAND1_exp04" as land1,
    coalesce(g.billing_document_code, v.invoice_realization_code) as inv_key,   -- SD.0000891 "Фактура сбыта (инвойс)"
    g.invoice_type_code
from pg_temp.irc_vbrk as v
left join pg_temp.irc_grp as g
    on g.grp = v.invoice_realization_group_code
where v.invoice_realization_group_code is not null
distributed by (invoice_realization_code);

analyze pg_temp.irc_step2;

-- g. Строки С группой: инвойс, контракт и выбор одной строки на фактуру реализации
drop table if exists pg_temp.irc_res_group;
create temporary table pg_temp.irc_res_group as
select
    invoice_realization_code,
    country_of_destination_code,
    sales_bank_account_code
from (
    select
        x.invoice_realization_code,
        coalesce(x.land1, x.counterparty_country_code) as country_of_destination_code,   -- SD.000892 "Страна конечной поставки (код)"
        case
            when i.billing_document_code is not null                    -- если SD.000891 "Фактура сбыта (инвойс)" есть в VBSK
                and i.bank_as_counterparty_code is not null             -- и VBSK-ZZBANK не пусто,
                then i.bank_as_counterparty_code                        -- то VBSK-ZZBANK,
            when i.billing_document_code is not null
                and i.bank_as_counterparty_code is null                 -- и VBSK-ZZBANK пусто,
                and s.sales_partner_role_code is not null               -- и значение VBPA-PARVW присутствует в /RUSAL/ROLE_VAL-ROLE
                then s.customer_code                                    -- то VBPA-KUNNR
        end as sales_bank_account_code,                                 -- SD.000928 "Собственник банковского счёта (код)"
        row_number() over (
            partition by
                x.invoice_realization_code
            order by
                x.invoice_realization_group_code asc,
                x.invoice_code asc,
                x.counterparty_country_code asc,
                x.land1 asc,
                i.billing_document_code asc,
                s.sales_partner_role_code asc,
                i.bank_as_counterparty_code asc,
                s.customer_code asc
        ) as rn
    from pg_temp.irc_step2 as x
    left join dds.invoice as i
        on i.billing_document_code = x.inv_key
        and x.invoice_type_code = 'О'
    left join pg_temp.irc_sch as s
        on s.sales_contract_code = i.sales_contract_code
) as q
where rn = 1
distributed by (invoice_realization_code);

-- h. Итог: та же таблица и те же колонки, что давал прежний irc_sic2
drop table if exists pg_temp.irc_sic2;
create temporary table pg_temp.irc_sic2 as
select invoice_realization_code, country_of_destination_code, sales_bank_account_code
from pg_temp.irc_res_group
union all
select invoice_realization_code, country_of_destination_code, sales_bank_account_code
from pg_temp.irc_res_nogroup
distributed by (invoice_realization_code);

analyze pg_temp.irc_sic2;

drop table if exists pg_temp.irc_vbrk;
drop table if exists pg_temp.irc_res_nogroup;
drop table if exists pg_temp.irc_vbss;
drop table if exists pg_temp.irc_grp;
drop table if exists pg_temp.irc_sch;
drop table if exists pg_temp.irc_step2;
drop table if exists pg_temp.irc_res_group;
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
        when vbrk.posting_status_code in ('C', 'E')                         -- VBRK-RFBSK = "C" или "E"
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



Что нужно знать перед запуском
Скрипт в начале делает drop table dds.invoice_realization, как и раньше. Если хотите сравнить новую загрузку со старой, перед запуском сохраните копию: create table dds.invoice_realization_old as select * from dds.invoice_realization;. После загрузки сравните country_of_destination_code и sales_bank_account_code через except по обеим таблицам. Это проверка уже на полных данных, а не на выборке.
Все шаги должны идти в одной сессии, так как таблицы временные.
Буквы 'Р', 'О', 'К' в скрипте кириллические (как в вашем исходнике), 'Q' латинская. Если будете вставлять скрипт через редактор, проверьте, что они не заменились.
Вопрос по 87 924 строкам

Это строки без группы с vgtyp = 'U'. В оригинале (и в моей версии, чтобы результат совпал) у них sales_bank_account_code всегда пусто: инвойс по vgbel не присоединяется, потому что условие d_ldadr2.invoice_type_code = 'О' для них ложно. А по вашему комментарию к колонке банк должен определяться по инвойсу, если он есть в VBSK со smart = 'О'. То есть для этих 87 924 строк результат, возможно, неверный уже сейчас.

Проверить, затронет ли это данные, можно так:

sql
select count(*) as rows_with_vgbel_invoice,
       count(i.bank_as_counterparty_code) as rows_with_bank_directly,
       count(s.customer_code) as rows_with_bank_via_contract
from pg_temp.vbrk as v
join dds.invoice as i
  on i.billing_document_code = v.vgbel
 and i.invoice_type_code = 'О'
left join pg_temp.sales_contract_header_prepare as s
  on s.sales_contract_code = i.sales_contract_code
 and s.sales_partner_role_code is not null
where v.posting_status_code in ('C','E')
  and v.invoice_realization_group_code is null
  and v.vgtyp = 'U';

Запускайте его до того, как скрипт удалит sales_contract_header_prepare (то есть отдельно, в сессии, где эта таблица ещё есть), либо замените её на dds.sales_contract_header с теми же джойнами. Если rows_with_bank_directly или rows_with_bank_via_contract не ноль, значит, у части этих строк должен быть банк, а сейчас там пусто. Тогда это ошибка в исходной логике, и я напишу правку. Менять поведение без вашего решения я не стал, чтобы результат остался таким же, как сейчас.

Как Claude справляется в этой сессии?
