select
  current_user,
  current_setting('gp_resource_group_memory_limit') as rg_mem_limit,
  current_setting('gp_vmem_protect_limit') as vmem_limit,
  current_setting('work_mem') as work_mem,
  current_setting('statement_mem') as statement_mem;

select
    rolname,
    rolcanlogin,
    rolcreaterole,
    rolcreatedb,
    rolreplication,
    rolbypassrls
from pg_roles
where rolname = 'ANALYST_LOGIN';   -- <-- логин аналитика

select
    r.rolname as member_of
from pg_auth_members m
join pg_roles r on r.oid = m.roleid
join pg_roles u on u.oid = m.member
where u.rolname = 'ANALYST_LOGIN';
Пример результата:
member_of
----------------
analyst_role
readonly_role
analytics_rg_role
👉 Именно эти роли определяют доступы к схемам/таблицам.
3️⃣ Посмотри его resource group (ключ к OOM!)
select
    rolname,
    rolresgroup
from pg_roles
where rolname = 'ANALYST_LOGIN';
И затем:
select *
from gp_toolkit.gp_resgroup_config
where groupname = (
    select rolresgroup
    from pg_roles
    where rolname = 'ANALYST_LOGIN'
);
Ты увидишь, например:
memory_limit = 20%
concurrency = 5
👉 Если ты не назначишь ту же resource group — поведение будет другим.
4️⃣ Создаём ТВОЙ логин с теми же правами
🔹 Шаг 1. Создать пользователя
create role my_test_user
login
password 'strong_password';
🔹 Шаг 2. Добавить его во ВСЕ роли аналитика
Берёшь результат из шага 2 и выполняешь:
grant analyst_role to my_test_user;
grant readonly_role to my_test_user;
grant analytics_rg_role to my_test_user;
(названия — точно как у аналитика)
🔹 Шаг 3. Назначить ТУ ЖЕ resource group (если она не через роль)
Если resource group назначена на login:
alter role my_test_user resource group analyst_rg;
Если через 

-- ============================================================
-- 0) (Опционально) чуть безопаснее по памяти на сессию
-- ============================================================
-- set statement_mem = '2GB';
-- set work_mem = '64MB';
-- set gp_workfile_limit_per_query = '0'; -- если у вас есть лимит workfile и он мешает

-- ============================================================
-- 1) Параметр периода (с начала года "год назад")
-- ============================================================
drop table if exists tmp_params;
create temporary table tmp_params on commit drop as
select
    date_trunc('year', current_date - interval '1 year')::date as dt_from
distributed randomly;

analyze tmp_params;

-- ============================================================
-- 2) Маленький справочник SAP-параметров для ZFI5668M (61 строка у вас в плане)
-- ============================================================
drop table if exists tmp_sap_bwasl;
create temporary table tmp_sap_bwasl on commit drop as
select
    range_low_value,
    parameter_code
from dict_dds.settings_and_parameters_sap
where abap_program_code = 'ZFI5668M'
  and range_sign_code is not null
  and is_anlc is null
distributed randomly;

analyze tmp_sap_bwasl;

-- ============================================================
-- 3) Витрина vbrk: берём последнюю реализацию по material_code
--    ВАЖНО: DISTINCT ON часто стабильнее и экономнее памяти, чем row_number + filter
-- ============================================================
drop table if exists tmp_vbrk;
create temporary table tmp_vbrk on commit drop as
with base as (
    select
        rf.unit_balance_code,
        substring(irp.material_code, 3) as asset_main_code,
        ir.payee_or_payer_code as buyer_code,
        sdcr.personnel_code as realization_supervisor_code,
        irp.document_currency_vat_excluded_amount as realization_document_currency_amount,
        irp.document_currency_code as realization_document_currency_code,
        irp.material_code,
        ir.invoice_realization_code,
        ir.dt_billing_document
    from dds.invoice_realization ir
    join dds.invoice_realization_position irp
      on ir.invoice_realization_code = irp.invoice_realization_code
    left join dds.sales_document_counterparty_role sdcr
      on sdcr.sales_document_code = irp.sales_document_code
     and (sdcr.sales_document_position_code = irp.sales_document_position_code
          or sdcr.sales_document_position_code = '000000')
     and sdcr.counterparty_role_code = 'VE'
    left join dict_dds.unit_balance rf
      on rf.fixed_asset_material_prefix_code = left(irp.material_code, 2)
    where irp.sales_document_position_type_code in ('ZAOS', 'ZAKT')
)
select distinct on (material_code)
    unit_balance_code,
    asset_main_code,
    buyer_code,
    realization_supervisor_code,
    realization_document_currency_amount,
    realization_document_currency_code
from base
where unit_balance_code is not null
order by
    material_code,
    invoice_realization_code desc,
    dt_billing_document desc
distributed by (unit_balance_code, asset_main_code);

analyze tmp_vbrk;

-- ============================================================
-- 4) Часть A: операции из dm_calc.fixed_asset_operations (основной поток)
--    Сразу считаем disposal_type_* через tmp_sap_bwasl
-- ============================================================
drop table if exists tmp_fa_ops;
create temporary table tmp_fa_ops on commit drop as
select
    fao.unit_balance_code,
    fao.dt_depreciation_posting_mmm,
    fao.depreciation_posting_internal_code,
    fao.asset_main_code,
    fao.asset_sub_code,
    fao.reference_asset_main_code,
    fao.reference_asset_sub_code,
    fao.dt_posting_yyyy as dt_depreciation_posting_yyyy,
    fao.valuation_area_code,
    fao.depreciation_internal_order_code,
    fao.asset_position_code,
    fao.dt_posting::date as dt_posting,
    fao.dt_reference,
    fao.business_transaction_code,
    fao.reference_operation_code,
    fao.reference_organization_unit_code,
    fao.general_ledger_operation_type_code,
    fao.dt_asset_document_created,
    fao.asset_movement_type_code,
    fao.red_reverse_reason_code,
    fao.dt_red_reverse,
    fao.red_reverse_code,
    fao.is_virtual_asset_movement,
    fao.depreciation_cost_center_code,
    fao.depreciation_typical_amount,
    fao.depreciation_special_amount,
    fao.valuation_area_currency_amount,
    fao.acquisition_cost_valuation_area_currency_amount,
    fao.proportional_cumulative_revaluation_amount,
    fao.asset_realization_revenue_amount,
    fao.depreciation_unplanned_amount,
    fao.cumulative_acquisition_and_production_cost_amount,
    fao.cumulative_depreciation_typical_amount,
    fao.cumulative_depreciation_special_amount,
    fao.cumulative_depreciation_unplanned_amount,
    fao.valuation_area_currency_code,
    fao.asset_movement_type_or_depreciation_calculation_code,
    case
        when sap.parameter_code = 'BWASL_L'  then 'Ликвидация'
        when sap.parameter_code = 'BWASL_SE' then 'Внешняя продажа'
        when sap.parameter_code = 'BWASL_SI' then 'Внутренняя продажа'
        when sap.parameter_code = 'BWASL_TR' then 'Безвозмездная передача'
    end as disposal_type_source_name,
    case
        when sap.parameter_code = 'BWASL_L'  then '3'
        when sap.parameter_code = 'BWASL_SE' then '5'
        when sap.parameter_code = 'BWASL_SI' then '8'
        when sap.parameter_code = 'BWASL_TR' then '1'
    end as disposal_type_code,
    'A' as non_liquid_asset_type_code,
    'Основные средства' as non_liquid_asset_type_name
from dm_calc.fixed_asset_operations fao
join tmp_params p on true
left join tmp_sap_bwasl sap
  on sap.range_low_value = fao.asset_movement_type_code
where fao.dt_posting >= p.dt_from
distributed by (unit_balance_code, asset_main_code, asset_sub_code, valuation_area_code);

analyze tmp_fa_ops;

-- ============================================================
-- 5) Часть B: "Передача в аренду" (lend_lease) — выделяем последнюю запись cd на дату <= posting
-- ============================================================
drop table if exists tmp_cd_rn;
create temporary table tmp_cd_rn on commit drop as
select
    cd.unit_balance_code,
    cd.asset_main_code,
    cd.asset_sub_code,
    cd.valuation_area_code,
    ll.dt_lend_lease_posting,
    cd.depreciation_total_cumulative_amount as depreciation_typical_amount,
    cd.depreciation_special_cumulative_amount as depreciation_special_amount,
    cd.acquisition_cost_cumulative_amount as valuation_area_currency_amount,
    cd.acquisition_cost_cumulative_amount as acquisition_cost_valuation_area_currency_amount,
    cd.depreciation_unplanned_cumulative_amount as depreciation_unplanned_amount,
    cd.valuation_area_currency_code,
    cd.non_liquid_asset_type_code,
    cd.non_liquid_asset_type_name,
    row_number() over (
        partition by cd.unit_balance_code, cd.asset_main_code, cd.asset_sub_code, cd.valuation_area_code
        order by cd.dt_report desc
    ) as rn
from dm.fixed_asset_cost_and_depreciation cd
join dict_dds.fixed_asset_lend_lease ll
  on ll.unit_balance_code = cd.unit_balance_code
 and ll.asset_main_code    = cd.asset_main_code
 and ll.asset_sub_code     = cd.asset_sub_code
join tmp_params p on true
where cd.dt_report >= p.dt_from
  and cd.dt_report <= ll.dt_lend_lease_posting
distributed by (unit_balance_code, asset_main_code, asset_sub_code, valuation_area_code);

analyze tmp_cd_rn;

drop table if exists tmp_fa_lease;
create temporary table tmp_fa_lease on commit drop as
select
    unit_balance_code,
    null::text as dt_depreciation_posting_mmm,
    null::text as depreciation_posting_internal_code,
    asset_main_code,
    asset_sub_code,
    null::text as reference_asset_main_code,
    null::text as reference_asset_sub_code,
    null::int as dt_depreciation_posting_yyyy,
    valuation_area_code,
    null::text as depreciation_internal_order_code,
    null::text as asset_position_code,
    dt_lend_lease_posting::date as dt_posting,
    dt_lend_lease_posting::date as dt_reference,
    null::text as business_transaction_code,
    null::text as reference_operation_code,
    null::text as reference_organization_unit_code,
    null::text as general_ledger_operation_type_code,
    null::timestamp as dt_asset_document_created,
    null::text as asset_movement_type_code,
    null::text as red_reverse_reason_code,
    null::date as dt_red_reverse,
    null::text as red_reverse_code,
    null::bool as is_virtual_asset_movement,
    null::text as depreciation_cost_center_code,
    depreciation_typical_amount,
    depreciation_special_amount,
    valuation_area_currency_amount,
    acquisition_cost_valuation_area_currency_amount,
    null::numeric as proportional_cumulative_revaluation_amount,
    null::numeric as asset_realization_revenue_amount,
    depreciation_unplanned_amount,
    null::numeric as cumulative_acquisition_and_production_cost_amount,
    null::numeric as cumulative_depreciation_typical_amount,
    null::numeric as cumulative_depreciation_special_amount,
    null::numeric as cumulative_depreciation_unplanned_amount,
    valuation_area_currency_code,
    'ZANLU_TRENT' as asset_movement_type_or_depreciation_calculation_code,
    'Передача в аренду' as disposal_type_source_name,
    '7' as disposal_type_code,
    non_liquid_asset_type_code,
    non_liquid_asset_type_name
from tmp_cd_rn
where rn = 1
distributed by (unit_balance_code, asset_main_code, asset_sub_code, valuation_area_code);

analyze tmp_fa_lease;

-- ============================================================
-- 6) Итоговый набор fa = union all двух потоков (важно: одинаковое распределение)
-- ============================================================
drop table if exists tmp_fa;
create temporary table tmp_fa on commit drop as
select * from tmp_fa_ops
union all
select * from tmp_fa_lease
distributed by (unit_balance_code, asset_main_code, asset_sub_code, valuation_area_code);

analyze tmp_fa;

-- ============================================================
-- 7) Финальная выборка: join'ы к fam и справочникам
-- ============================================================
select 
    fam.unit_balance_code,
    fam.unit_balance_name,
    fam.asset_main_code,
    fam.asset_sub_code,
    fam.valuation_area_code,
    fam.valuation_area_name,
    fam.valuation_area_currency_code,
    fam.valuation_area_currency_name,
    fam.asset_depreciation_rule_code,
    fam.asset_depreciation_rule_name,
    fam.asset_class_code,
    fam.asset_class_name,
    fam.asset_inventory_number,
    fam.asset_name,
    fa.dt_depreciation_posting_yyyy,
    fa.asset_position_code,
    fa.depreciation_posting_internal_code,
    fa.asset_movement_type_or_depreciation_calculation_code,
    fa.dt_posting,
    fa.depreciation_internal_order_code,
    ord.order_short_name as depreciation_internal_order_name,
    fa.dt_depreciation_posting_mmm,
    fa.dt_reference,
    fa.business_transaction_code,
    fa.reference_operation_code,
    fa.reference_organization_unit_code,
    fa.is_virtual_asset_movement,
    fa.reference_asset_main_code,
    fa.reference_asset_sub_code,
    fa.general_ledger_operation_type_code,
    fa.dt_asset_document_created,
    fa.asset_movement_type_code,
    mtt.fixed_asset_movement_type_name as asset_movement_type_name,
    fa.red_reverse_code,
    fa.red_reverse_reason_code,
    fa.dt_red_reverse,
    fa.asset_realization_revenue_amount,
    fa.proportional_cumulative_revaluation_amount,
    fam.base_uom_code,
    fam.base_uom_name,
    fam.asset_quantity,    
    fam.cost_center_code,
    fam.cost_center_name,
    fa.depreciation_cost_center_code,
    cc.cost_center_name_rus as depreciation_cost_center_name, 
    fam.plant_code,
    fam.plant_name,  
    fam.is_asset_conservated,
    fam.dt_conservated_from, 
    fam.dt_conservated_to, 
    fam.dt_conservated_actual,
    fam.document_type_code,
    fam.document_type_name,
    fam.special_order_for_conservation_number,
    fam.dt_special_order_for_conservation,
    fam.special_order_for_cancelling_conservation_number,
    fam.dt_special_order_for_cancelling_conservation,
    fam.dt_conservation_cancelled_actual,
    fam.dt_approved_of_techical_state,
    fam.non_liquid_asset_techical_state_code,
    fam.non_liquid_asset_techical_state_name,
    fam.is_non_liquid_asset_record_created_manually,
    fam.dt_asset_status_reverse_from_non_liquid,
    fa.non_liquid_asset_type_code,
    fa.non_liquid_asset_type_name,
    fam.dt_asset_recognized,
    fam.dt_asset_write_off,
    fa.disposal_type_source_name,
    fa.disposal_type_code,
    dtt.disposal_type_name,
    fa.valuation_area_currency_amount,
    fa.acquisition_cost_valuation_area_currency_amount,
    (fa.depreciation_typical_amount + fa.depreciation_special_amount + fa.depreciation_unplanned_amount) as depreciation_total_amount,
    fa.depreciation_typical_amount,
    fa.depreciation_special_amount,
    fa.depreciation_unplanned_amount,
    fa.cumulative_acquisition_and_production_cost_amount,
    fa.cumulative_depreciation_typical_amount,
    fa.cumulative_depreciation_special_amount,
    fa.cumulative_depreciation_unplanned_amount,
    v.buyer_code,
    c.counterparty_full_name as buyer_name,
    v.realization_supervisor_code,
    p.employee_full_name as realization_supervisor_name,
    v.realization_document_currency_amount,
    v.realization_document_currency_code
from tmp_fa fa
left join dm.fixed_asset_main fam
  on fa.unit_balance_code  = fam.unit_balance_code
 and fa.asset_main_code    = fam.asset_main_code
 and fa.asset_sub_code     = fam.asset_sub_code
 and fa.valuation_area_code= fam.valuation_area_code
 and fa.dt_posting between fam.dt_valid_from and fam.dt_valid_to
left join dict_dds.disposal_type_texts dtt
  on fa.disposal_type_code = dtt.disposal_type_code
 and dtt.language_code = 'R'
left join tmp_vbrk v
  on v.unit_balance_code = fa.unit_balance_code
 and v.asset_main_code   = fa.asset_main_code
left join dict_dds.counterparty c
  on c.counterparty_code = v.buyer_code
left join dict_dds.personnel_main_data p
  on p.employee_code = v.realization_supervisor_code
 and fa.dt_posting between p.dt_valid_from and p.dt_valid_to
left join dict_dds.order_controlling ord
  on fa.depreciation_internal_order_code = ord.order_code
left join dict_dds.cost_center cc
  on fa.depreciation_cost_center_code = cc.cost_center_code
 and fa.dt_posting between cc.dt_valid_from and cc.dt_valid_to
left join dict_dds.fixed_asset_movement_type_texts mtt
  on fa.asset_movement_type_code = mtt.fixed_asset_movement_type_code
 and mtt.language_code = 'R';
