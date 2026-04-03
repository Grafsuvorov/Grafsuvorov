create temporary table cte on commit drop as (
select cr.unit_balance_code
     , cr.accounting_document_fiscal_year::numeric            as fiscal_year
     , cr.accounting_document_code
     , string_agg(cr.purchase_contract_code, ';'
                  order by cr.purchase_contract_code)         as contract_list
     , json_agg(
       json_build_object('external_contract_number', coalesce(ext_new.external_contract_number, ext_new.contract_code),
                         'paydox_document_url', ext_new.paydox_document_url) order by cr.purchase_contract_code)
       filter (where ext_new.external_contract_number is not null or
                     ext_new.paydox_document_url is not null) as contract_list_with_paydox_url
  from dm_calc.accounting_document_and_purchase_contract_relation cr
  left join dm_calc.accounting_external_contracts as ext_new
  on ext_new.contract_code = cr.purchase_contract_code
      and ext_new.external_contract_source_table_name = 'purchase_contract'
 group by cr.unit_balance_code
        , cr.accounting_document_fiscal_year::numeric
        , cr.accounting_document_code)
distributed by (unit_balance_code, fiscal_year, accounting_document_code);

create temporary table p on commit drop as (
select
		p.unit_balance_code,
		p.fiscal_year,
		p.accounting_document_code,
		p.position_line_item ,
		p.account_type,
		p.contract_number,
		p.reference_procedure,
		contract_list,
		contract_list_with_paydox_url
	from dm_calc.accounting_receivables_and_payables p
	left join cte cr
	       on p.unit_balance_code = cr.unit_balance_code
		  and p.fiscal_year = cr.fiscal_year
		  and p.accounting_document_code = cr.accounting_document_code
	    where p.contract_number is not null
	union all
	select
		ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code ,
		ad.position_line_item ,
		ad.account_type,
		substring(ltrim(ad.assignment_number,'0') , 1, 10) as contract_number,
		ad.reference_procedure,
		null as contract_list,
		null as contract_list_with_paydox_url
	from dds.accounting_documents as ad
	join dict_dds.map_account_debt_to_allocation as mada
	  on ad.general_ledger_account_code = mada.account_allocation_code
   where ad.assignment_number is not null
	 and ad.reference_document_number is not null
	 and ad.accounting_document_header_text is not null
	 and (ad.accounting_document_status_code is null
	   or ad.accounting_document_status_code = 'A')
	 and ad.unit_balance_code not like 'E%'
	 and ad.unit_balance_code not like 'F%'
	 and ad.unit_balance_code not like 'S%'
	 and ad.is_active = true)
distributed by (contract_number, unit_balance_code);

insert into dm_calc.accounting_document_contracts (
	unit_balance_code,
	fiscal_year,
	accounting_document_code,
	accounting_document_position_code,
	account_type_code,
	contract_code,
	contract_subtype_code,
	contract_type_code,
	reference_operation_type_code,
	external_contract_number,
	dt_external_contract,
	contract_supervisor_code,
	contract_supervisor_name,
	purchase_or_sales_group_code,
	purchase_or_sales_group_name,
	contract_registration_number,
	responsibility_center_code,
	responsibility_center_level1_code,
	contract_trader_code,
	contract_trader_name,
	paydox_document_url,
	external_contract_source_table_name,
	contract_list,
	contract_list_with_paydox_url)
select
	p.unit_balance_code,
	p.fiscal_year,
	p.accounting_document_code,
	p.position_line_item as accounting_document_position_code,
	p.account_type,
	p.contract_number as contract_code,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.contract_subtype_code
			when p.contract_number = sc.contract_code
			then sc.contract_subtype_code
	 		when p.contract_number = ext.contract_code
			then ext.contract_subtype_code
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.contract_subtype_code
		when p.contract_number = ext.contract_code
		then ext.contract_subtype_code
		when p.contract_number = sc.contract_code
		then sc.contract_subtype_code
		else null end end as contract_subtype_code,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.contract_type_code
			when p.contract_number = sc.contract_code
			then sc.contract_type_code
	 		when p.contract_number = ext.contract_code
			then ext.contract_type_code
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.contract_type_code
		when p.contract_number = ext.contract_code
		then ext.contract_type_code
		when p.contract_number = sc.contract_code
		then sc.contract_type_code
		else null end end as contract_type_code,
	p.reference_procedure as reference_operation_type_code,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.external_contract_number
			when p.contract_number = sc.contract_code
			then sc.external_contract_number
	 		when p.contract_number = ext.contract_code
			then ext.external_contract_number
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.external_contract_number
		when p.contract_number = ext.contract_code
		then ext.external_contract_number
		when p.contract_number = sc.contract_code
		then sc.external_contract_number
		else null end end as external_contract_number,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.dt_external_contract
			when p.contract_number = sc.contract_code
			then sc.dt_external_contract
	 		when p.contract_number = ext.contract_code
			then ext.dt_external_contract
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.dt_external_contract
		when p.contract_number = ext.contract_code
		then ext.dt_external_contract
		when p.contract_number = sc.contract_code
		then sc.dt_external_contract
		else null end end as dt_external_contract,
--  case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.contract_supervisor_code
			when
			p.contract_number = sc.contract_code and exists(
				select
					1
				from
					dict_dds.settings_and_parameters_sap sap
				where
				sap.abap_program_code = '/RUSAL/SD1785M'
				and sap.parameter_code = 'BUKRS'
				and p.unit_balance_code = sap.range_low_value
			)
			then sc.contract_supervisor_code
	 		when p.contract_number = ext.contract_code
			then ext.contract_supervisor_code
			else null end
		else case --'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.contract_supervisor_code
		when p.contract_number = ext.contract_code
		then ext.contract_supervisor_code
		when p.contract_number = sc.contract_code
		then sc.contract_supervisor_code
		else null end end as contract_supervisor_code,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.contract_supervisor_name
			when
			p.contract_number = sc.contract_code and exists(
				select
					1
				from
					dict_dds.settings_and_parameters_sap sap
				where
				sap.abap_program_code = '/RUSAL/SD1785M'
				and sap.parameter_code = 'BUKRS'
				and p.unit_balance_code = sap.range_low_value
			)
			then sc.contract_supervisor_name
	 		when p.contract_number = ext.contract_code
			then ext.contract_supervisor_name
			else null end
		else case --'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.contract_supervisor_name
		when p.contract_number = ext.contract_code
		then ext.contract_supervisor_name
		when p.contract_number = sc.contract_code
		then sc.contract_supervisor_name
		else null end end as contract_supervisor_name,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = sc.contract_code
			then sc.purchase_or_sales_group_code
	 		when p.contract_number = ext.contract_code
			then ext.purchase_or_sales_group_code
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = ext.contract_code
		then ext.purchase_or_sales_group_code
		when p.contract_number = sc.contract_code
		then sc.purchase_or_sales_group_code
		else null end end as purchase_or_sales_group_code,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = sc.contract_code
			then sc.purchase_or_sales_group_name
	 		when p.contract_number = ext.contract_code
			then ext.purchase_or_sales_group_name
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = ext.contract_code
		then ext.purchase_or_sales_group_name
		when p.contract_number = sc.contract_code
		then sc.purchase_or_sales_group_name
		else null end end as purchase_or_sales_group_name,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.contract_registration_number
			when p.contract_number = sc.contract_code
			then sc.contract_registration_number
	 		when p.contract_number = ext.contract_code
			then ext.contract_registration_number
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.contract_registration_number
		when p.contract_number = ext.contract_code
		then ext.contract_registration_number
		when p.contract_number = sc.contract_code
		then sc.contract_registration_number
		else null end end as contract_registration_number,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = sc.contract_code
			then sc.responsibility_center_code
	 		when p.contract_number = ext.contract_code
			then ext.responsibility_center_code
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = ext.contract_code
		then ext.responsibility_center_code
		when p.contract_number = sc.contract_code
		then sc.responsibility_center_code
		else null end end as responsibility_center_code,
--	case when p.reference_procedure in ('RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF') then
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.responsibility_center_level1_code
			when p.contract_number = sc.contract_code
			then sc.responsibility_center_level1_code
	 		when p.contract_number = ext.contract_code
			then ext.responsibility_center_level1_code
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.responsibility_center_level1_code
		when p.contract_number = ext.contract_code
		then ext.responsibility_center_level1_code
		when p.contract_number = sc.contract_code
		then sc.responsibility_center_level1_code
		else null end end as responsibility_center_level1_code,
	sc.contract_trader_code,
	sc.contract_trader_name,
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = sc.contract_code
			then sc.paydox_document_url
	 		when p.contract_number = ext.contract_code
			then ext.paydox_document_url
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = ext.contract_code
		then ext.paydox_document_url
		when p.contract_number = sc.contract_code
		then sc.paydox_document_url
		else null end end as paydox_document_url,
	case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then flt.external_contract_source_table_name
			when p.contract_number = sc.contract_code
			then sc.external_contract_source_table_name
	 		when p.contract_number = ext.contract_code
			then ext.external_contract_source_table_name
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then flt.external_contract_source_table_name
		when p.contract_number = ext.contract_code
		then ext.external_contract_source_table_name
		when p.contract_number = sc.contract_code
		then sc.external_contract_source_table_name
		else null end end as external_contract_source_table_name,

	contract_list,

		case when p.reference_procedure = 'VBRK' then
		case
			when p.contract_number = flt.contract_code
			then coalesce(p.contract_list_with_paydox_url,flt.contract_list_with_paydox_url::json )
			when p.contract_number = sc.contract_code
			then coalesce(p.contract_list_with_paydox_url,sc.contract_list_with_paydox_url::json )
	 		when p.contract_number = ext.contract_code
			then coalesce(p.contract_list_with_paydox_url,ext.contract_list_with_paydox_url::json )
			else null end
		else case -- 'RMRP', 'LOANS', 'TR-TM', 'BKPF', 'BKPFF'
		when p.contract_number = flt.contract_code
		then coalesce(p.contract_list_with_paydox_url,flt.contract_list_with_paydox_url::json )
		when p.contract_number = ext.contract_code
		then coalesce(p.contract_list_with_paydox_url,ext.contract_list_with_paydox_url::json )
		when p.contract_number = sc.contract_code
		then coalesce(p.contract_list_with_paydox_url,sc.contract_list_with_paydox_url::json )
		else null end end as contract_list_with_paydox_url
from p
left join dm_calc.accounting_external_contracts  as flt
       on flt.contract_code = p.contract_number
	  and flt.unit_balance_code = p.unit_balance_code
	  and flt.external_contract_source_table_name ='financial_loan_terms'
left join dm_calc.accounting_external_contracts  as sc
       on sc.contract_code = p.contract_number
      and sc.external_contract_source_table_name = 'sales_contract'
left join dm_calc.accounting_external_contracts  as ext
	   on ext.contract_code = p.contract_number
      and ext.external_contract_source_table_name like 'purchase%';
