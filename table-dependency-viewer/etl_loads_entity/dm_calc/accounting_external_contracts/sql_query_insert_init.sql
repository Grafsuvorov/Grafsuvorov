create temporary table cur_p on commit drop as (
    select a.purchase_document_code, a.personnel_code from (
        select pdcr.purchase_document_code,
               pdcr.personnel_code::numeric,
               row_number() over (partition by pdcr.purchase_document_code order by pdcr.consecutive_number desc) as rn
          from dds.purchase_document_counterparty_role as pdcr
         where pdcr.purchase_document_position_code::numeric = 0
           and pdcr.counterparty_role_code = 'AU') a
     where a.rn = 1
       and a.personnel_code <> 0)
distributed by (purchase_document_code);

create temporary table c on commit drop as (
    select
	sch.sales_contract_code as contract_code,
	null::varchar(4) as unit_balance_code,
	sch.sales_order_external_number as external_contract_number,
	sch.dt_sales_contract as dt_external_contract,
	null as purchase_group_code,
	sch.sales_team_code as sales_group_code,
	sch.responsibility_center_code,
	null as responsibility_center_level1_code,
	sch.sales_contract_registration_number as contract_registration_number,
	null as contract_subtype_code,
	sch.contract_type_code as contract_type_code,
	sdcr.personnel_code ::numeric as contract_supervisor_code,
	sdcr2.personnel_code::numeric as contract_trader_code,
	'sales_contract'::varchar(21) as external_contract_source_table_name,
	sch2.sales_contract_paydox_url as paydox_document_url,
	sch.deleted_flag
from dds.sales_contract_header as sch
left join dds.sales_document_counterparty_role as sdcr
	   on sch.sales_contract_code = sdcr.sales_document_code
	  and sdcr.sales_document_position_code::numeric = 0
	  and sdcr.counterparty_role_code = 'VE'
	  and sdcr.personnel_code::numeric <> 0
left join dds.sales_document_counterparty_role as sdcr2
   	   on  sch.sales_contract_code = sdcr2.sales_document_code
	  and sdcr2.sales_document_position_code::numeric = 0
	  and sdcr2.counterparty_role_code = 'YT'
	  and sdcr2.personnel_code::numeric <> 0
left join dds.sales_contract_header as sch2
       on sch2.frame_contract_code = sch.sales_contract_code
	  and sch2.price_contract_type_code='MA'
union all
select
	pc.purchase_contract_code as contract_code,
	pc.unit_balance_code,
	pc.purchase_contract_external_part1_number as external_contract_number,
	pc.dt_purchase_contract as dt_external_contract,
	pc.purchase_group_code,
	null as sales_group_code,
	pc.responsibility_center_code,
	null as responsibility_center_level1_code,
	pc.purchase_contract_registration_number as contract_registration_number,
	pc.purchase_document_subtype_code as contract_subtype_code,
	pc.purchase_document_type_code as contract_type_code,
	cur_p.personnel_code ::numeric as contract_supervisor_code,
	null as contract_trader_code,
	'purchase_contract'::varchar(21) as external_contract_source_table_name,
	pc.paydox_document_url,
	pc.deleted_flag
from dds.purchase_contract_header as pc
left join cur_p as cur_p
       on cur_p.purchase_document_code = pc.purchase_contract_code
union all
select
	po.purchase_order_code as contract_code,
	po.unit_balance_code,
	po.purchase_contract_external_part1_number as external_contract_number,
	po.dt_purchase_order as dt_external_contract,
	po.purchase_group_code,
	null as sales_group_code,
	po.responsibility_center_code,
	null as responsibility_center_level1_code,
	po.registration_number as contract_registration_number,
	po.purchase_document_subtype_code as contract_subtype_code,
	po.purchase_document_type_code as contract_type_code,
	cur_p.personnel_code ::numeric as contract_supervisor_code,
	null as contract_trader_code,
	'purchase_order'::varchar(21) as external_contract_source_table_name,
	po.paydox_document_url,
	po.deleted_flag
from dds.purchase_order_header as po
left join cur_p as cur_p
	   on cur_p.purchase_document_code = po.purchase_order_code
union all
select
	pa.purchase_agreement_code as contract_code,
	pa.unit_balance_code,
	pa.purchase_contract_external_part1_number as external_contract_number,
	pa.dt_purchase_agreement as dt_external_contract,
	pa.purchase_group_code,
	null as sales_group_code,
	pa.responsibility_center_code,
	null as responsibility_center_level1_code,
	pa.registration_number as contract_registration_number,
	pa.purchase_document_subtype_code as contract_subtype_code,
	pa.purchase_document_type_code as contract_type_code,
	cur_p.personnel_code ::numeric as contract_supervisor_code,
	null as contract_trader_code,
	'purchase_agreement'::varchar(21) as external_contract_source_table_name,
	pa.paydox_document_url,
	pa.deleted_flag
from dds.purchase_agreement_header as pa
left join cur_p as cur_p
       on cur_p.purchase_document_code = pa.purchase_agreement_code
union all
select
	ltrim(fl.contract_code,'0') as contract_code,
	fl.unit_balance_code,
	fl.alternative_identification_number  as external_contract_number,
	fl.dt_terms_effective_from as dt_external_contract,
	null as purchase_group_code,
	null as sales_group_code,
	null as responsibility_center_code,
	fl.responsibility_center_level1_code,
	null as contract_registration_number,
	null as contract_subtype_code,
	null as contract_type_code,
	umd.employee_code::numeric as contract_supervisor_code,
	null as contract_trader_code,
	'financial_loan_terms'::varchar(21) as external_contract_source_table_name,
	null as paydox_document_url,
	fl.deleted_flag
from dds.financial_loan_terms as fl
left join dict_dds.user_main_data as umd
       on fl.contract_supervisor_login_username = umd.login_username
      and umd.employee_code ~ '^[0-9]+$'
      and umd.employee_code::numeric <> 0)
distributed randomly;

insert into dm_calc.accounting_external_contracts  (
	contract_code,
	unit_balance_code,
	external_contract_number,
	dt_external_contract,
	responsibility_center_code,
	responsibility_center_level1_code,
	purchase_or_sales_group_code,
	purchase_or_sales_group_name,
	contract_registration_number,
	contract_supervisor_code,
	contract_subtype_code,
	contract_type_code,
	contract_trader_code,
	external_contract_source_table_name,
	contract_supervisor_name,
	contract_trader_name,
	paydox_document_url,
	contract_list_with_paydox_url,
	deleted_flag
	)
select
	c.contract_code,
	c.unit_balance_code,
	c.external_contract_number,
	c.dt_external_contract,
	c.responsibility_center_code,
	coalesce(mrctfc.responsibility_center_level1_code,
	c.responsibility_center_level1_code) as responsibility_center_level1_code,
	coalesce(c.purchase_group_code,
	c.sales_group_code) as purchase_or_sales_group_code,
	coalesce(pg.purchase_group_name,
	sg.sales_group_name_rus) as purchase_or_sales_group_name,
	c.contract_registration_number,
	c.contract_supervisor_code,
	c.contract_subtype_code,
	c.contract_type_code,
	c.contract_trader_code::numeric,
	c.external_contract_source_table_name,
	plmd_c.employee_full_name as contract_supervisor_name,
	plmd_t.employee_full_name as contract_trader_name,
	c.paydox_document_url,
	case when c.external_contract_number is not null
	       or c.paydox_document_url is not null
	     then json_build_object('external_contract_number', coalesce(c.external_contract_number, c.contract_code),
                                'paydox_document_url', c.paydox_document_url)
	     else null
	      end as contract_list_with_paydox_url,
	c.deleted_flag::boolean
from c
left join dict_dds.purchase_group as pg
       on pg.purchase_group_code = c.purchase_group_code
left join dict_dds.sales_group as sg
       on sg.sales_group_code = c.sales_group_code
left join dict_dds.personnel_main_data as plmd_c
       on c.contract_supervisor_code::numeric = plmd_c.employee_code::numeric
	  and plmd_c.dt_valid_from::date <= current_date
	  and plmd_c.dt_valid_to::date >= current_date
left join dict_dds.personnel_main_data as plmd_t
       on c.contract_trader_code::numeric = plmd_t.employee_code::numeric
	  and plmd_t.dt_valid_from::date <= current_date
	  and plmd_t.dt_valid_to::date >= current_date
left join dict_dds.map_responsibility_center_to_funds_center as mrctfc
       on mrctfc.funds_center_code = c.responsibility_center_code
	  and mrctfc.dt_valid_from::date <= current_date
	  and mrctfc.dt_valid_to::date >= current_date;
