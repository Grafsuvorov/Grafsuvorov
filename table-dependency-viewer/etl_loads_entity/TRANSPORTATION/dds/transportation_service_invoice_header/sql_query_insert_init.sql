insert into dds.transportation_service_invoice_header
with zle112t2 as(
	select
		plant_code,
		customer_contract_account_code,
		is_agent_scheme_code,
		row_number() over (partition by plant_code, 
		                                customer_contract_account_code
		                       order by dt_valid_from desc) as consecutive_number
    from dict_dds.map_customer_contract_account_to_contract_td
    where is_deleted_code is null
),
customer_for_plant as(
	select distinct customer_code
	from dict_dds.plant_and_subsidiary
	where customer_code is not null
),
perp_aggr as (
	select
		perp.werks,
		perp.id,
		sum(perp.sums) as total_position_document_currency_vat_excluded_amount,
		max(case when perp.ebelny is not null then 1 else 0 end) as is_exists_contract,
		max(case when perh_korr.type2 is not null then 1 else 0 end) as is_adjustment_zm
	from ods."/rusal/perp_ral" as perp
		left join ods."/rusal/perh_ral" as perh_korr
			on perh_korr.werks = perp.werks and
			   perh_korr.id = perp.akt_id and
			   perh_korr.type2 = 'ZM'
	group by
		perp.werks,
		perp.id
),
perw_aggr as (
	select
		werks,
		id,
		sum(n_plata) as total_subposition_document_currency_vat_excluded_amount,
		sum(nds) as total_subposition_document_currency_vat_amount
	from ods."/rusal/perw_ral"
	group by werks, id
)
select
	perh.werks as plant_code,
	perh.id as transportation_service_invoice_code,
	perh.noms as supplier_account_code,
	perh.nomp as transportation_service_invoice_number,
	perh.bedat as dt_transportation_service_invoice,
	perh.status_doc as payment_obstacle_code,
	perh.lifnr as creditor_code,
	perh.zlifnr as creditor_agent_code,
	perh.lifnr_pr as second_creditor_agent_code,
	case when zle112t2.is_agent_scheme_code is null then perh.lifnr
	     else case when perp_aggr.is_exists_contract = 1
	     		   then coalesce(perh.lifnr_pr, perh.zlifnr)
	     		   else coalesce(perh.zlifnr, perh.lifnr)
	     	  end	
	end as creditor_final_code,
	perh.comments as comment,
	perh.duedat as dt_due_payment_date,
	perh.ernam as created_by,
	perh.aenam as updated_by,
	perh.uved_ernam as contract_supervisor_code,
	perh.type2 as transportation_service_invoice_type_code,
	perh.waers as document_currency_code,
	perh.tap_sum as prepayed_document_currency_amount,
	case when zle112t2.is_agent_scheme_code is null then '01' 						--прямая схема
	     else case when t001w_zlifnr.customer_code is null then '02'				--агентская схема
	               else '03'														--двойная агентская схема
	          end
	end as agent_scheme_type_code,
	case when zle112t2.is_agent_scheme_code is null
		 then (case when ctd1.is_group_company_affiliated is null then 'X' else null end)
	     else (case when ctd2.is_group_company_affiliated is null then 'X' 
	     			else (case when ctd3.counterparty_code is not null and
	     			                ctd3.is_group_company_affiliated is null then 'X'
	     			           else null
	     			      end)
	           end)
	end as is_external_partner_code,  
	coalesce(perp_aggr.total_position_document_currency_vat_excluded_amount, 0) as total_position_document_currency_vat_excluded_amount,
	coalesce(perw_aggr.total_subposition_document_currency_vat_excluded_amount, 0) as total_subposition_document_currency_vat_excluded_amount,
	coalesce(perw_aggr.total_subposition_document_currency_vat_amount, 0) as total_subposition_document_currency_vat_amount,
	ps.unit_balance_code,
	ub.currency_code as local_currency_code,
	ca.currency_code as second_local_currency_code,
	case when perh.type2 = 'ZK' and perp_aggr.is_adjustment_zm = 1 then true else false end is_mirrored_adjustment_transportation_service_invoice
from ods."/rusal/perh_ral" as perh
	left join zle112t2
		on zle112t2.plant_code = perh.werks and
	   	   zle112t2.customer_contract_account_code = perh.noms and
	       zle112t2.consecutive_number = 1
	left join customer_for_plant as t001w_zlifnr
		on t001w_zlifnr.customer_code = perh.zlifnr
	left join dict_dds.counterparty as ctd1
		on ctd1.counterparty_code = perh.lifnr
	left join dict_dds.counterparty as ctd2
		on ctd2.counterparty_code = perh.zlifnr
	left join dict_dds.counterparty as ctd3
		on ctd3.counterparty_code = perh.lifnr_pr
	left join dict_dds.plant_and_subsidiary as ps
		on ps.plant_code  = perh.werks
	left join dict_dds.unit_balance as ub
		on ub.unit_balance_code = ps.unit_balance_code
	left join dict_dds.map_controlling_area_to_unit_balance as mcatub   --tka02
		on mcatub.unit_balance_code = ps.unit_balance_code
	left join dict_dds.controlling_area as ca
		on ca.controlling_area_code = mcatub.controlling_area_code
	left join perp_aggr
		on perp_aggr.id = perh.id and 
		   perp_aggr.werks = perh.werks
	left join perw_aggr
		on perw_aggr.id = perh.id and 
		   perw_aggr.werks = perh.werks
where perh.werks is not null
  and perh.id is not null;
