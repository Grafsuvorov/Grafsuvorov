create temporary TABLE tmp_investment_expenses_actual_accounting_documents (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year varchar(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	creditor_code varchar(10) NULL,
	contract_code varchar(50)  NULL,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED by (unit_balance_code ,fiscal_year, accounting_document_code );


insert into tmp_investment_expenses_actual_accounting_documents
SELECT 	
	ad.unit_balance_code, 
	ad.fiscal_year,
	ad.accounting_document_code, 
	case when max(ad.counterparty_code) = min (ad.counterparty_code) 	then max(ad.counterparty_code) else null end ,
	case when max(ad.contract_number) = min (ad.contract_number) 	then max(ad.contract_number) else null end
FROM dm_calc.accounting_receivables_and_payables   ad
WHERE 1=1								
	and	ad.account_type = 'K'			
	and ad.deleted_flag = false			
GROUP BY ad.unit_balance_code, ad.fiscal_year, ad.accounting_document_code;


CREATE temporary TABLE tmp_investment_expenses_actual_correspondence (
	unit_balance_code varchar(4) NOT NULL,
	fiscal_year numeric(4) NOT NULL,
	accounting_document_code varchar(10) NOT NULL,
	position_line_item numeric(3) NULL,
	correspondence_general_ledger_account_code varchar(10) NULL,
	document_currency_code varchar(5) NULL,
	second_local_currency_code varchar(5) NULL,
	debit_or_credit bpchar(1) NULL,
	document_currency_amount numeric(20, 2) NULL DEFAULT 0,
	second_local_currency_amount numeric(20, 2) NULL DEFAULT 0,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=row,
	compresstype=zstd,
	compresslevel=3
)
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code);


insert into tmp_investment_expenses_actual_correspondence
with cte as (
select  case_code, range_low_value  as glc from(
select
		case_code,
		range_low_value,
		dense_rank() over ( partition by saps.case_code,
		saps.parameter_code
	order by
		coalesce(saps.dt_valid_from, '1000-01-01') desc ) as row_num
	from
		dict_dds.settings_and_parameters_sap saps
	where
		saps.abap_program_code = '/RUSAL/FI1349M'
		and (saps.parameter_code = 'SO_HKONT'
			or saps.parameter_code = 'SO_07' or saps.parameter_code = 'MATKPVPU')
		and saps.range_sign_code is not null) as saps 
		where row_num = 1
		group by case_code, range_low_value 
	)
select
		unit_balance_code,
		fiscal_year,
		accounting_document_code,
		position_line_item,
		correspondence_general_ledger_account_code,
		document_currency_code,
		second_local_currency_code,
		at2.debit_or_credit_code ,
		sum (at2.debit_turnover_document_currency_amount - at2.credit_turnover_document_currency_amount) as document_currency_amount,
		sum (at2.debit_turnover_second_local_currency_amount - at2.credit_turnover_second_local_currency_amount) as second_local_currency_amount
	from
		dm_calc.account_turnover at2
inner join cte hkonts on
	hkonts.case_code = at2.unit_balance_code 
	and hkonts.glc = at2.general_ledger_account_code 
group by
	unit_balance_code,
	fiscal_year,
	accounting_document_code,
	position_line_item,
	correspondence_general_ledger_account_code,
	document_currency_code,
	second_local_currency_code,
	debit_or_credit_code;


create temporary table tmp_investment_expenses_actual_group_01(
		expense_or_payment_source_type_code varchar(10) not null,
		accounting_document_unit_balance_code varchar(4) not null,
		accounting_document_fiscal_year numeric(4,0) not null,
		accounting_document_code varchar(10) not null,
		reference_document_for_reporting_code varchar(28) not null,
		accounting_document_position_code numeric(3,0) not null,
		accounting_document_type_code varchar(2) null,
		controlling_area_code varchar(4)  null,
		controlling_document_code varchar(10)  null,
		controlling_document_position_code varchar(3)  null,
		reference_operation_type_code varchar(5)  null,
		dt_posting date not null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		controlling_order_code varchar(12) null,
		vat_code varchar(2) null,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,
		second_local_currency_amount numeric(20,2) default 0,
		second_local_currency_code varchar(5) null,
		capitalization_code varchar(6) null,
		plant_code varchar(4) null,
		dttm_inserted timestamp NOT NULL DEFAULT now(),
		dttm_updated timestamp NOT NULL DEFAULT now(),
		job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
		deleted_flag bool NOT NULL DEFAULT false)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=3
)
distributed by (reference_document_for_reporting_code);

insert
	into
	tmp_investment_expenses_actual_group_01
with cte as (
	select
		case_code,
		range_low_value as glc,
		max (case
			when saps.parameter_code = 'MATKPVPU' then 'X'
			else null
		end ) as is_matkpvu,
		max (case
			when saps.parameter_code = 'SO_07' then 'X'
			else null
		end ) as is_so07,
		max (case
			when saps.parameter_code = 'SO_HKONT' then 'X'
			else null
		end ) as is_sohkont
	from
		(
		select
			case_code,
			range_low_value,
			parameter_code,
			dense_rank() over ( partition by saps.case_code,
			saps.parameter_code
		order by
			coalesce(saps.dt_valid_from, '1000-01-01') desc ) as row_num
		from
			dict_dds.settings_and_parameters_sap saps
		where
			saps.abap_program_code = '/RUSAL/FI1349M'
			and (saps.parameter_code = 'SO_HKONT'
				or saps.parameter_code = 'SO_07'
				or saps.parameter_code = 'MATKPVPU')
			and saps.range_sign_code is not null) as saps
	where
		row_num = 1
	group by
		case_code,
		range_low_value 
	)
select
	(case
		when saps.is_sohkont = 'X'
			and saps.is_matkpvu is null then 'ZFI_08'
			when saps.is_so07 = 'X' then 'ZFI_07'
			when saps.is_matkpvu = 'X' then 'ZFI_101014'
		end ) as expense_or_payment_source_type_code,
	ad.unit_balance_code as accounting_document_unit_balance_code,
	ad.fiscal_year as accounting_document_fiscal_year,
	ad.accounting_document_code,
	concat(ad.unit_balance_code, ad.fiscal_year, ad.accounting_document_code, ad.position_line_item) as reference_document_for_reporting_code,
	ad.position_line_item as accounting_document_position_code,
	ad.accounting_document_type as accounting_document_type_code,
	null as controlling_area_code,
	null as controlling_document_code,
	null as controlling_document_position_code,
	ad.reference_procedure as reference_operation_type_code,
	ad.dt_posting,
	
			case 
		when ad.reference_procedure = 'RMRP'
		or 
		(ad.reference_procedure = 'BKPF'
			and ad.purchase_document_code is not null )
			then ad.purchase_document_code
		when ad.reference_procedure = 'MKPF'		
			 then coalesce(mdp.purchase_document_code, ad.purchase_document_code)
	end as purchase_document_code,
		
			case 
		when ad.reference_procedure = 'RMRP'
		or 
		(ad.reference_procedure = 'BKPF'
			and ad.purchase_document_code is not null )
			then ad.purchase_document_position_line_item_code
		when ad.reference_procedure = 'MKPF'		
			 then coalesce(mdp.purchase_document_position_line_item_code, ad.purchase_document_position_line_item_code)
	end as purchase_document_position_code,
		
	ad.general_ledger_account_code as cost_element_code,
	at2.correspondence_general_ledger_account_code,
	ad.material_code,
		
				case 
		when ad.reference_procedure = 'RMRP'		
			then pdh.payee_alternative_code
		when ad.reference_procedure = 'MKPF'		
			 then coalesce(mdp.payee_alternative_code, purch.supplier_code)
		when ad.reference_procedure = 'BKPF'
		and ad.purchase_document_code is not null 
		then purch.supplier_code
	end as creditor_code,

			case 
		when ad.reference_procedure = 'MKPF'
		or 		
			(ad.reference_procedure = 'BKPF'
			and ad.purchase_document_code is not null)
		then coalesce(purch.number_of_principal_purchase_agreement, mdp.purchase_document_code)
		when 
		(ad.reference_procedure = 'BKPF'
			and ad.purchase_document_code is null
		)
		or ad.reference_procedure = 'RMRP'
		then ltrim(ad.contract_number, '0')
	end as contract_code,	
	coalesce(ad.wbs_element_code, wemdd1.wbs_element_code) as wbs_element_internal_code,
	wemdd.wbs_element_number as wbs_element_external_code,
	wemdd.investment_project_code as investment_project_internal_code,
	null as controlling_order_code,
	ad.tax_code as vat_code,
	at2.document_currency_amount,
	at2.document_currency_code,
	at2.second_local_currency_amount,
	at2.second_local_currency_code,
	wemdd.posting_reason_code as capitalization_code,
	wemdd.plant_code
from
	dds.accounting_documents ad
left join tmp_investment_expenses_actual_correspondence as at2 on
	 at2.unit_balance_code = ad.unit_balance_code
	and at2.fiscal_year = ad.fiscal_year
	and at2.accounting_document_code = ad.accounting_document_code
	and at2.position_line_item = ad.position_line_item
inner join cte as saps on
	 saps.case_code = ad.unit_balance_code
	and ad.general_ledger_account_code like replace (saps.glc,
	'*',
	'%')
left join dict_dds.wbs_element_master_data_detail wemdd1 on
	wemdd1.wbs_element_number = ad.assignment_number
inner join dict_dds.wbs_element_master_data_detail wemdd on
	wemdd.wbs_element_code = coalesce(ad.wbs_element_code, wemdd1.wbs_element_code )
left join dm_calc.investment_expenses_actual_material_movements mdp on
	mdp.material_movement_document_code = substring(ad.reference_object_key, 1, 10)
	and mdp.material_movement_document_year = substring(ad.reference_object_key, 11, 4)
	and mdp.material_code = ad.material_code
	and mdp.wbs_element_code = coalesce(ad.wbs_element_code, wemdd1.wbs_element_code)
left join dm_calc.investment_expenses_actual_purchase_documents as purch on
				case 
		when ad.reference_procedure = 'RMRP'
		or 
		(ad.reference_procedure = 'BKPF'
			and ad.purchase_document_code is not null )
			then ad.purchase_document_code
		when ad.reference_procedure = 'MKPF'		
			 then coalesce(mdp.purchase_document_code, ad.purchase_document_code)
	end = purch.purchase_document_code
	and case 
		when ad.reference_procedure = 'RMRP'
		or 
		(ad.reference_procedure = 'BKPF'
			and ad.purchase_document_code is not null )
			then ad.purchase_document_position_line_item_code
		when ad.reference_procedure = 'MKPF'		
			 then coalesce(mdp.purchase_document_position_line_item_code, ad.purchase_document_position_line_item_code)
	end = purch.position_line_item_code
left join dds.invoice_purchase_document_header pdh on
	pdh.invoice_code = substring(ad.reference_object_key, 1, 10)
	and pdh.fiscal_year = substring(ad.reference_object_key, 11, 4)
where
	1 = 1
	and ad.is_active = true
	and ad.deleted_flag = false;
	


create temporary table tmp_investment_expenses_actual_group_02(
		expense_or_payment_source_type_code varchar(10) not  null,
		accounting_document_unit_balance_code varchar(4)  null,
		accounting_document_fiscal_year numeric(4,0)  null,
		accounting_document_code varchar(10)  null,
		reference_document_for_reporting_code varchar(28)  null,
		accounting_document_position_code numeric(3,0)  null,
		accounting_document_type_code varchar(2) null,
		controlling_area_code varchar(4)  not null,
		controlling_document_code varchar(10) not  null,
		controlling_document_position_code varchar(3) not  null,
		reference_operation_type_code varchar(5)  null,
		dt_posting date not null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		controlling_order_code varchar(12) null,
		vat_code varchar(2) null,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,
		second_local_currency_amount numeric(20,2) default 0,
		second_local_currency_code varchar(5) null,
		capitalization_code varchar(6) null,
		plant_code varchar(4) null,
		dttm_inserted timestamp NOT NULL DEFAULT now(),
		dttm_updated timestamp NOT NULL DEFAULT now(),
		job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
		deleted_flag bool NOT NULL DEFAULT false)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=3
)
distributed by (reference_document_for_reporting_code);

----------------------------------------------------------------------------------------------------------------COMMENT

insert into tmp_investment_expenses_actual_group_02
with codsr as (
SELECT	
	object_code,  wbs_element_code,
	row_number() over(
		partition by object_code
		order by distribution_rule_sequence_code desc 
	) as row_num
FROM dds.controlling_object_distribution_settlement_rules	--COBRB
WHERE 1=1										--и при этом COBRB-PS_PSP_PNR не пустой (то есть если пустой, то из витрины удаляем)
	and wbs_element_code <> '00000000'
	and distribution_rule_group_code = '000'
	and object_code like 'OR%'
),

ord as 
(
select 
		ot.external_order_code,  --OBJNR
		ot.order_type_code,
		ot.order_code,
		ot.wbs_element_code,
		ot.unit_balance_code
	from
		dict_dds.order_toro ot
		where ot.is_order_for_capital_electrolyser_repair_code = 'X'
union all
	select 
		concat('OR',oc.order_code) as external_order_code,
		oc.order_type_code,
		oc.order_code,
		oc.wbs_element_code,
		oc.unit_balance_code
	from
		dict_dds.order_controlling oc
	where oc.is_order_for_capital_electrolyser_repair_code = 'X'
union all
	select  
		concat('OR',op.order_code) as external_order_code,
		op.order_type_code,
		op.order_code,
		op.wbs_element_code,
		op.unit_balance_code
	from
		dict_dds.order_production op 
		where op.is_order_for_capital_electrolyser_repair_code = 'X'
		)
				
select
	'ZCO'	as expense_or_payment_source_type_code,
	case
		when cd.reference_operation_type_code = 'BKPF'	
			then cd.reference_document_unit_balance_code	
		when cd.reference_operation_type_code in ('RMRP','MKPF')	
			then ref_headers.unit_balance_code					
	end as accounting_document_unit_balance_code,	
	case
		when cd.reference_operation_type_code = 'BKPF'			
			then cd.reference_document_fiscal_year::numeric				
		when cd.reference_operation_type_code in ('RMRP','MKPF')	
			then ref_headers.fiscal_year::numeric						
	end	as accounting_document_fiscal_year,	--3
	case
		when cd.reference_operation_type_code = 'BKPF'	
			then cd.reference_document_code		
		when cd.reference_operation_type_code in ('RMRP','MKPF')	
			then ref_headers.accounting_document_code			
	end	as accounting_document_code,
	concat(cd.controlling_area_code,cd.controlling_document_code,cd.controlling_document_position_code) 	as reference_document_for_reporting_code,
	cd.accounting_document_position_code::numeric::numeric	as accounting_document_position_code,
	null,
	cd.controlling_area_code	as controlling_area_code,
	cd.controlling_document_code	as controlling_document_code,
	cd.controlling_document_position_code	as controlling_document_position_code,
	cd.reference_operation_type_code	as reference_operation_type_code,
	cd.dt_posting	as dt_posting,
	case 
		when cd.reference_operation_type_code = 'RMRP'	or 
		(cd.reference_operation_type_code = 'BKPF'	and cd.purchase_document_code is not null )
			then cd.purchase_document_code
		when cd.reference_operation_type_code = 'MKPF'		
			 then coalesce(ieamm.purchase_document_code,cd.purchase_document_code)
		end  	as purchase_document_code,
	
		case 
		when cd.reference_operation_type_code = 'RMRP'	or 
		(cd.reference_operation_type_code = 'BKPF'	and cd.purchase_document_code is not null )
			then cd.purchase_document_position_code
		when cd.reference_operation_type_code = 'MKPF'		
			 then coalesce(ieamm.purchase_document_position_line_item_code,cd.purchase_document_position_code)
		end 
		as purchase_document_position_code,
	cd.cost_element_code	as cost_element_code,
	null	as correspondence_general_ledger_account_code,
	cd.material_code	as material_code, 
	
		case 
		when cd.reference_operation_type_code = 'RMRP'		
			then ipdh.payee_alternative_code
		when cd.reference_operation_type_code = 'MKPF'		
			 then coalesce(ieamm.payee_alternative_code, pcp.supplier_code) 
		when cd.reference_operation_type_code = 'BKPF'	and cd.purchase_document_code is not null 
		then pcp.supplier_code
		when cd.reference_operation_type_code = 'BKPF'	and cd.purchase_document_code  is null 
		then ad.creditor_code end as creditor_code,		

		case 
		when cd.reference_operation_type_code in ('RMRP', 'MKPF') or 		
			(cd.reference_operation_type_code = 'BKPF'  
			and cd.purchase_document_code is not null)
		then coalesce(pcp.number_of_principal_purchase_agreement,ieamm.purchase_document_code)
		when cd.reference_operation_type_code = 'BKPF' and cd.purchase_document_code is null
		then ltrim(ad.contract_code, '0') end as contract_code,			
				
		cd.wbs_element_code as  wbs_element_internal_code,	

	wemdd1.wbs_element_number as wbs_element_external_code,	
	wemdd1.investment_project_code as investment_project_internal_code,
	cd.real_order_code as controlling_order_code, 	
	null as vat_code,
	cd.document_currency_amount	as document_currency_amount,
	cd.document_currency_code	as document_currency_code,
	cd.second_local_currency_amount	,
	cd.second_local_currency_code,	
	wemdd1.posting_reason_code	as capitalization_code,					
	wemdd1.plant_code	as plant_code				

FROM (
select
	cdo.controlling_area_code,
	cdo.controlling_document_code,
	cdo.controlling_document_position_code,
	cdo.unit_balance_code,
	cdo.dt_posting,
	cdo.reference_document_code,
	cdo.reference_document_unit_balance_code,
	cdo.reference_document_fiscal_year,
	cdo.reference_operation_type_code,
	cdo.document_currency_amount,
	cdo.local_currency_amount,
	cdo.second_local_currency_amount,
	cdo.order_code,
	cdo.cost_element_code,
	cdo.document_currency_code,
	cdo.local_currency_code,
	cdo.second_local_currency_code,
	cdo.general_ledger_account_code,
	cdo.material_code,
	cdo.purchase_document_code,
	cdo.purchase_document_position_code,
	cdo.accounting_document_position_code,
	cdo.value_type_code,
	case when ref_saps.case_code  is not null 
				then codsr.wbs_element_code
				when  ref_saps.case_code is  null 
				then ord.wbs_element_code
				end as wbs_element_code, 
	ord.order_code as real_order_code
from 
	dds.controlling_documents_to_orders cdo
left join
		dict_dds.settings_and_parameters_sap  ref_saps 
	on 
	    cdo.cost_element_code = ref_saps.range_low_value
		and abap_program_code = '/RUSAL/FI1032M'
		and case_code = 'ADD'
		and parameter_code = 'R_USLV11'
		and range_option_code is not null
LEFT JOIN ord on	
	ord.external_order_code = cdo.order_code
	and ref_saps.case_code is  null
left join codsr on 
	codsr.object_code = cdo.order_code
	and ref_saps.case_code is not null
	and codsr.row_num = 1
where
	is_active = true
	 and (codsr.object_code is not null or ord.order_code is not null)
union all 
select
	cdw.controlling_area_code,
	cdw.controlling_document_code,
	cdw.controlling_document_position_code,
	cdw.unit_balance_code,
	cdw.dt_posting,
	cdw.reference_document_code,
	cdw.reference_document_unit_balance_code,
	cdw.reference_document_fiscal_year,
	cdw.reference_operation_type_code,
	cdw.document_currency_amount,
	cdw.local_currency_amount,
	cdw.second_local_currency_amount,
	cdw.wbs_element_prefix_code,
	cdw.cost_element_code,
	cdw.document_currency_code,
	cdw.local_currency_code,
	cdw.second_local_currency_code,
	cdw.general_ledger_account_code,
	cdw.material_code,
	cdw.purchase_document_code,
	cdw.purchase_document_position_code,
	cdw.accounting_document_position_code,
	cdw.value_type_code,
	wemdd.wbs_element_code, 
	null as real_order_code
from 
	dds.controlling_documents_to_wbs_elements cdw
join dict_dds.wbs_element_master_data_detail wemdd		
	on
	wemdd.wbs_element_prefix_code = cdw.wbs_element_prefix_code
	and wemdd.wbs_element_code <> '00000000'
where
	 is_active = true
) as cd

LEFT JOIN dm_calc.investment_expenses_actual_documents_header as ref_headers
	on ref_headers.reference_procedure = cd.reference_operation_type_code
	and ref_headers.reference_object_key = CONCAT(cd.reference_document_code, cd.reference_document_fiscal_year)
	and ref_headers.fiscal_year = cd.reference_document_fiscal_year::numeric
	and ref_headers.row_num = 1
LEFT JOIN dds.invoice_purchase_document_header ipdh
	on	ipdh.invoice_code =  cd.reference_document_code						
	and	ipdh.fiscal_year = cd.reference_document_fiscal_year	
left join dm_calc.investment_expenses_actual_purchase_documents pcp on
		pcp.purchase_document_code  = cd.purchase_document_code 
	and pcp.position_line_item_code = cd.purchase_document_position_code
left join --dm_calc.investment_expenses_actual_accounting_documents 
		tmp_investment_expenses_actual_accounting_documents as ad on  
	ad.unit_balance_code = cd.reference_document_unit_balance_code
	and	ad.accounting_document_code = cd.reference_document_code		
	and	ad.fiscal_year= cd.reference_document_fiscal_year	
LEFT JOIN dict_dds.wbs_element_master_data_detail wemdd1 on	
	wemdd1.wbs_element_code = 	cd.wbs_element_code
LEFT JOIN dm_calc.investment_expenses_actual_material_movements ieamm	
	on	ieamm.material_movement_document_code = cd.reference_document_code					
	and ieamm.material_movement_document_year = cd.reference_document_fiscal_year			
	and ieamm.material_code = cd.material_code											
	and ieamm.wbs_element_code = 	cd.wbs_element_code
 JOIN dict_dds.map_cost_element_to_budget mceb	--204 922 861
	on	mceb.cost_element_code = cd.cost_element_code  -- 3209999998
	and	(mceb.cost_element_type_code is null 
		or mceb.cost_element_type_code ='Z')
WHERE 1=1
	and cd.value_type_code = '04';
	

	create temporary table tmp_investment_expenses_actual_group_03 (
		expense_or_payment_source_type_code varchar(10) not null,
		accounting_document_unit_balance_code varchar(4) not null,
		accounting_document_fiscal_year numeric(4) not null,
		accounting_document_code varchar(10)  null,
		reference_document_for_reporting_code varchar(28) not null,
		accounting_document_position_code numeric(3,0) null,
		accounting_document_type_code varchar(2) null,
		controlling_area_code varchar(4)  null,
		controlling_document_code varchar(10)  null,
		controlling_document_position_code varchar(3)  null,
		reference_operation_type_code varchar(5) null,
		dt_posting date null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		controlling_order_code varchar(12) null,
		vat_code varchar(2) null,
		document_currency_amount numeric(17,2) ,
		document_currency_code varchar(5) null,
		second_local_currency_amount numeric(17,2) ,
		second_local_currency_code varchar(5) null,
		capitalization_code varchar(6) null,
		plant_code varchar(4) null,
		dttm_inserted timestamp NOT NULL DEFAULT now(),
		dttm_updated timestamp NOT NULL DEFAULT now(),
		job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
		deleted_flag bool NOT NULL DEFAULT false)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=1
)
distributed by (reference_document_for_reporting_code);



insert
	into
	tmp_investment_expenses_actual_group_03
with so_1014 as
(
	select
		parameter_code,
		case_code,
		range_low_value
	from
		(
		select
			parameter_code,
			case_code,
			saps.range_low_value,
			dense_rank() over ( partition by saps.case_code
		order by
			coalesce(saps.dt_valid_from, '1000-01-01') desc ) as row_num
		from
			dict_dds.settings_and_parameters_sap saps
		where
			saps.abap_program_code = '/RUSAL/FI1349M'
			and saps.parameter_code = 'SO_1014'
			and saps.range_sign_code is not null
		) as saps
	where
		saps.row_num = 1
),
	bwagr as(
	select
		parameter_code ,
		range_low_value
	from
		dict_dds.settings_and_parameters_sap
	where
		1 = 1
		and (parameter_code = 'BWAGR_K'
			or parameter_code = 'BWAGR_D')
		and abap_program_code = '/RUSAL/CO860M'
		and range_sign_code is not null
),
	bwgr_15 as(
	select
		parameter_code,
		case_code,
		range_low_value
	from
		dict_dds.settings_and_parameters_sap
	where
		1 = 1
		and (parameter_code = 'BWGR_15' )
			and abap_program_code = '/RUSAL/FI1349M'
			and range_sign_code is not null
),
	bwgex as (
	select
		distinct range_low_value
	from
		dict_dds.settings_and_parameters_sap
	where
		1 = 1
		and parameter_code = 'BWG_EX11'
		and abap_program_code = '/RUSAL/FI1032M'
),
	sales_header as (
	select
		sales_contract_code as sales_document_code,
		sales_contract_wbs_element_code as wbs_element_internal_code
	from
		dds.sales_contract_header
union all
	select
		sales_request_for_proposal_code as sales_document_code,
		sales_request_for_proposal_wbs_element_code as wbs_element_internal_code
	from
		dds.sales_request_for_proposal_header
union all
	select
		sales_proposal_code as sales_document_code,
		sales_proposal_wbs_element_code as wbs_element_internal_code
	from
		dds.sales_prorosal_header
union all
	select
		sales_order_code as sales_document_code,
		sales_order_wbs_element_code as wbs_element_internal_code
	from
		dds.sales_order_header
),
	ch as 
(

select

		expense_or_payment_source_type_code,
		unit_balance_code,
		posting_period_yyyy,
		posting_period_mmm,
		plant_code,
		row_code,
		general_ledger_account_code,
		correspondence_general_ledger_account_code,
		local_currency_amount,
		 second_local_currency_amount,
		material_code,
		wbs_element_internal_code,
		sales_document_code,
		purchase_document_code,
		purchase_document_position_line_item_code,
		to_excl,
		general_ledger_operation_processing_type_code,
		reference_document_code, 
		dt_reference_document_yyyy
from (

	select 
		'ZFI_1014' as expense_or_payment_source_type_code,
		mtb.unit_balance_code,
		mtb.posting_period_yyyy,
		mtb.posting_period_mmm,
		mtb.plant_code,
		rod.row_identifier_code as row_code,   
		mtb.general_ledger_account_code,
		mtb.correspondence_general_ledger_account_code,
		case
			when saps1.parameter_code = 'BWGR_15' then rod.local_currency_amount
			else mtb.local_currency_amount
		end local_currency_amount,
		case
			when saps1.parameter_code = 'BWGR_15' then rod.second_local_currency_amount
			else mtb.second_local_currency_amount
		end second_local_currency_amount,
		mlh.material_code,
		mlh.wbs_element_code as wbs_element_internal_code,
		mlh.sales_document_code,
		rod.purchase_document_code,
		rod.purchase_document_position_line_item_code
		,
		null as to_excl
		,
		rod.general_ledger_operation_processing_type_code,
		rod.reference_document_code, 
		rod.dt_reference_document_yyyy,
		row_number() over (partition by mtb.unit_balance_code,
		mtb.posting_period_yyyy,
		mtb.posting_period_mmm,
		mtb.data_type_code,
		mtb.plant_code,
		mtb.calculation_code,
		rod.row_identifier_code,
		rod.reference_document_code,		
		rod.purchase_document_code,
		rod.purchase_document_position_line_item_code
		order by mtb.row_code) as rn 
			from		dds.material_turnover_balance mtb
	join dds.purchase_document_revaluation  rod
		on
		rod.unit_balance_code = mtb.unit_balance_code
		and rod.posting_period_yyyy = mtb.posting_period_yyyy
		and rod.posting_period_mmm = mtb.posting_period_mmm
		and rod.data_type_code = mtb.data_type_code
		and rod.plant_code = mtb.plant_code
		and rod.calculation_code = mtb.calculation_code
	left join dds.material_ledger_header mlh on
		mlh.calculation_code = mtb.calculation_code
	join so_1014 saps on
		mtb.general_ledger_account_code like replace (saps.range_low_value,'*','%')
			and mtb.unit_balance_code = saps.case_code
		join bwgr_15 saps1 on
			mtb.movement_type_code = saps1.range_low_value
			and mtb.unit_balance_code = saps1.case_code
	) deduplication
where 
		 rn=1

	union all
		select
				'ZFI_1014' as expense_or_payment_source_type_code,
				mtb.unit_balance_code,
				mtb.posting_period_yyyy,
				mtb.posting_period_mmm,
				mtb.plant_code,
				mtb.row_code as row_code,
				mtb.general_ledger_account_code,
				mtb.correspondence_general_ledger_account_code,
				case
				when saps1.parameter_code = 'BWAGR_D' then -1 * mtb.local_currency_amount
				else mtb.local_currency_amount
			end local_currency_amount,
				case
				when saps1.parameter_code = 'BWAGR_D' then -1 * mtb.second_local_currency_amount
				else mtb.second_local_currency_amount
			end second_local_currency_amount,
				mlh.material_code,
				mlh.wbs_element_code as wbs_element_internal_code,
				mlh.sales_document_code,
				null as purchase_document_code,
				null as purchase_document_position_line_item_code,
				coalesce (saps2.range_low_value,
			saps3.range_low_value) as to_excl,
			null as general_ledger_operation_processing_type_code,
			null as reference_document_code, 
			null dt_reference_document_yyyy
		from
				dds.material_turnover_balance mtb
		left join dds.material_ledger_header mlh on
				mlh.calculation_code = mtb.calculation_code
		join so_1014 saps on
				mtb.general_ledger_account_code like replace (saps.range_low_value,'*','%')
				and mtb.unit_balance_code = saps.case_code
			join bwagr saps1 on
				mtb.movement_type_code like replace (saps1.range_low_value,'*','%')
			left join bwgr_15 as saps2 on
				mtb.movement_type_code = saps2.range_low_value
					and mtb.unit_balance_code = saps2.case_code
				left join bwgex as saps3 on
					mtb.movement_type_code = saps3.range_low_value
				
)
select
		ch.expense_or_payment_source_type_code,                              
		ch.unit_balance_code as accounting_document_unit_balance_code, 
		ch.posting_period_yyyy::numeric as accounting_document_fiscal_year,
		null as  accounting_document_code,
		concat(ch.unit_balance_code,ch.posting_period_yyyy,ch.row_code) as reference_document_for_reporting_code,
		null as accounting_document_position_code, 
		null as accounting_document_type_code,
		null as controlling_area_code,
		null as controlling_document_code,
		null as controlling_document_position_code,
		null as reference_operation_type_code,
		cast((date_trunc('month', (ch.posting_period_yyyy || substring(ch.posting_period_mmm, 2) || '01')::date) + interval '1 month' - interval '1 day') as date) as dt_posting, 
		ch.purchase_document_code,
		ch.purchase_document_position_line_item_code as purchase_document_position_code,
		ch.general_ledger_account_code as cost_element_code,
		ch.correspondence_general_ledger_account_code, 
		ch.material_code, 
		case when ch.general_ledger_operation_processing_type_code = 'RMRP'
		then ipdh.payee_alternative_code 
		else po.supplier_code end  as creditor_code,
		po.number_of_principal_purchase_agreement as contract_code, 
		case
		when ch.wbs_element_internal_code = '00000000'and ch.sales_document_code is not null then sh.wbs_element_internal_code
		else ch.wbs_element_internal_code 
		end as wbs_element_internal_code,
		wemdd.wbs_element_number as wbs_element_external_code,
		wemdd.investment_project_code as investment_project_internal_code,  
		null as controlling_order_code,
		null as vat_code,
		ch.local_currency_amount as document_currency_amount, 
		ub.currency_code as document_currency_code,  
		ch.second_local_currency_amount,
		ca.currency_code as second_local_currency_code,
		wemdd.posting_reason_code as capitalization_code,
		ch.plant_code
from
	ch
left join dm_calc.investment_expenses_actual_purchase_documents po on
		ch.purchase_document_code = po.purchase_document_code
	and ch.purchase_document_position_line_item_code = po.position_line_item_code
left join dds.invoice_purchase_document_header ipdh
		on ch.reference_document_code  = ipdh.invoice_code
		and ch.dt_reference_document_yyyy =  ipdh.fiscal_year
left join dict_dds.unit_balance ub on
		ch.unit_balance_code = ub.unit_balance_code
left join dict_dds.map_controlling_area_to_unit_balance m on
	m.unit_balance_code = ub.unit_balance_code
left join dict_dds.controlling_area ca on 
	ca.controlling_area_code = m.controlling_area_code
left join sales_header sh on
	sh.sales_document_code = ch.sales_document_code
left join dict_dds.wbs_element_master_data_detail wemdd on
		wemdd.wbs_element_code = case when ch.wbs_element_internal_code = '00000000'and ch.sales_document_code is not null 
		then sh.wbs_element_internal_code
		else ch.wbs_element_internal_code 
		end 
where
	ch.to_excl is null;
	

create temporary table tmp_investment_expenses_actual_group_04 (
		expense_or_payment_source_type_code varchar(10) not null,
		accounting_document_unit_balance_code varchar(4) null,
		accounting_document_fiscal_year numeric(4,0) null,
		accounting_document_code varchar(10) null,
		reference_document_for_reporting_code varchar(28) not null,
		accounting_document_position_code numeric(3,0) null,
		accounting_document_type_code varchar(2) null,
		controlling_area_code varchar(4) not null,
		controlling_document_code varchar(10) not null,
		controlling_document_position_code varchar(3) not null,
		reference_operation_type_code varchar(5) null,
		dt_posting date not null,
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		controlling_order_code varchar(12) null,
		vat_code varchar(2) null,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,
		second_local_currency_amount numeric(20,2) default 0,
		second_local_currency_code varchar(5) null,
		capitalization_code varchar(6) null,
		plant_code varchar(4) null,
		dttm_inserted timestamp not null default now(),
		dttm_updated timestamp not null default now(),
		job_name varchar(60) not null default 'airflow'::character varying,
		deleted_flag bool not null default false)
with (
		appendonly = true,
		orientation = column,
		compresstype = zstd,
		compresslevel = 3
)
distributed by (reference_document_for_reporting_code) ;

insert
	into
	tmp_investment_expenses_actual_group_04
with 
 realiz as
 (
select
		parameter_code,
		case_code,
		range_low_value
from
		dict_dds.settings_and_parameters_sap
where
		1 = 1
	and parameter_code = 'S_REALIZ'
	and abap_program_code = '/RUSAL/FI1349M'
	and range_sign_code is not null
)

select
	'ZFI_STLMNT' as expense_or_payment_source_type_code,
	s.accounting_document_unit_balance_code,
	s.fiscal_year as accounting_document_fiscal_year,
	ad.accounting_document_code,
	concat(s.settlement_document_code,s.sequence_number) as reference_document_for_reporting_code,
	null as accounting_document_position_code,
	null as accounting_document_type_code,
	s.controlling_area_code,
	s.controlling_document_code,
	s.controlling_document_position_line_item_code as controlling_document_position_code,
	ad.reference_procedure as reference_operation_type_code,
	ad.dt_posting ,
	ad.purchase_document_code,
	ad.purchase_document_position_line_item_code as purchase_document_position_code,
	s.cost_element_code as cost_element_code,
	ad.general_ledger_account_code as correspondence_general_ledger_account_code,
	null as material_code,
	null as creditor_code,
	null as contract_code,
	substring(s.object_code, 3, 8) as wbs_element_internal_code,
	w.wbs_element_number as wbs_element_external_code,
	w.investment_project_code as investment_project_internal_code,
	null as controlling_order_code,
	ad.tax_code as vat_code,
	-1 * s.document_currency_amount::numeric(20,2) as document_currency_amount,
	s.document_currency_code,
	-1 * s.second_local_currency_amount::numeric(20,2) as second_local_currency_amount,
	s.second_local_currency_code,
	w.posting_reason_code as capitalization_code,
	w.plant_code

from
	dds.settlement_documents_from_project_to_receiver s
join 
(
	select
		dt_posting,
		reference_object_key,
		unit_balance_code,
		reference_procedure,
		fiscal_year,
		general_ledger_account_code,
		accounting_document_code,
		purchase_document_code,
		purchase_document_position_line_item_code,
		tax_code
	from
		dds.accounting_documents
	where
		reference_procedure = 'AUAK'
		and is_active = true 
	group by
		dt_posting,
		reference_object_key,
		unit_balance_code,
		reference_procedure,
		fiscal_year,
		general_ledger_account_code,
		accounting_document_code,
		purchase_document_code,
		purchase_document_position_line_item_code,
		tax_code
) as ad
	on
	ad.reference_object_key = s.settlement_document_code
	and ad.unit_balance_code = s.accounting_document_unit_balance_code
	and ad.fiscal_year = s.fiscal_year
join realiz sap2 on
	ad.general_ledger_account_code like replace (sap2.range_low_value,'*','%')
	and ad.unit_balance_code = sap2.case_code
left join dict_dds.wbs_element_master_data_detail w 
	on  s.object_code = w.wbs_element_prefix_code
where
	1 = 1
	and settlement_type_code = 'GES'
	and assignment_type_code != 'AN';


	create temporary table tmp_investment_expenses_actual_group_05 (
		expense_or_payment_source_type_code varchar(10) not  null,
		accounting_document_unit_balance_code varchar(4)  null,
		accounting_document_fiscal_year numeric(4,0)  null,
		accounting_document_code varchar(10)  null,
		reference_document_for_reporting_code varchar(28) not null,
		accounting_document_position_code numeric(3,0)  null,
		accounting_document_type_code varchar(2) null,
		controlling_area_code varchar(4)   null,
		controlling_document_code varchar(10)   null,
		controlling_document_position_code varchar(3)  null,
		reference_operation_type_code varchar(5)  null,
		dt_posting date  not null, 
		purchase_document_code varchar(10) null,
		purchase_document_position_code varchar(5) null,
		cost_element_code varchar(10) null,
		correspondence_general_ledger_account_code varchar(10) null,
		material_code varchar(18) null,
		creditor_code varchar(10) null,
		contract_code varchar(50) null,
		wbs_element_internal_code varchar(24) null,
		wbs_element_external_code varchar(24) null,
		investment_project_internal_code varchar(24) null,
		controlling_order_code varchar(12) null,
		vat_code varchar(2) null,
		document_currency_amount numeric(20,2) default 0,
		document_currency_code varchar(5) null,
		second_local_currency_amount numeric(20,2) default 0,
		second_local_currency_code varchar(5) null,
		capitalization_code varchar(6) null,
		plant_code varchar(4) null,
		dttm_inserted timestamp NOT NULL DEFAULT now(),
		dttm_updated timestamp NOT NULL DEFAULT now(),
		job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
		deleted_flag bool NOT NULL DEFAULT false)
with (
		appendonly=true,
		orientation=column,
		compresstype=zstd,
		compresslevel=3
)
distributed by (reference_document_for_reporting_code);

insert
	into
	tmp_investment_expenses_actual_group_05
select
	'ZTZR' as expense_or_payment_source_type_code,
	unit_balance_code as accounting_document_unit_balance_code,
	fiscal_year as accounting_document_fiscal_year,
	null as accounting_document_code,
	concat(coalesce (plant_code ,unit_balance_code),fiscal_year,report_line_code,report_column_code,subsequent_code) as reference_document_for_reporting_code,
	null as accounting_document_position_code,
	null as accounting_document_type_code,
	null as controlling_area_code,
	null as controlling_document_code,
	null as controlling_document_position_code,
	null as reference_operation_type_code,
	cast((date_trunc('month',
	(fiscal_year || substring(fiscal_period,
	2) || '01')::date) + interval '1 month' - interval '1 day') as date) as dt_posting,
	null as purchase_document_code,
	null as purchase_document_position_code,
	cost_element_code,
	null as correspondence_general_ledger_account_code,
	null as material_code,
	null as creditor_code,
	null as contract_code,
	null as wbs_element_internal_code,
	null as wbs_element_external_code,
	null as investment_project_internal_code,
	null as controlling_order_code,
	null as vat_code,
	case
		when report_column_code in ('07', '08', '10', '11') then -1 * local_currency_amount
		else local_currency_amount
	end as document_currency_amount,
	local_currency_code as document_currency_code,
	case
		when report_column_code in ('07', '08', '10', '11') then -1 * second_local_currency_amount
		else second_local_currency_amount
	end as second_local_currency_amount,
	second_local_currency_code,
	null as capitalization_code,
	plant_code as plant_code
from
	ods.map_controlling_transport_and_procurement_cost_keys
where
	report_version_code = '230'
	and report_column_code not in ('01', '02', '06', '09', '12');
	

insert into dm.investment_expenses_actual
with ord as 
(
select 
		ot.order_code,
		ot.order_short_name 
	from
		dict_dds.order_toro ot
union all
	select 
		oc.order_code,
		oc.order_short_name 
	from
		dict_dds.order_controlling oc
union all
	select  
		op.order_code,
		op.order_short_name 
	from
		dict_dds.order_production op 
		)
select
	ad.expense_or_payment_source_type_code,
	ad.accounting_document_unit_balance_code,
	ub.unit_balance_name,
	ad.accounting_document_fiscal_year,
	ad.accounting_document_code,
	ad.reference_document_for_reporting_code,
	ad.accounting_document_position_code,
	ad.accounting_document_type_code,
	ad.controlling_area_code,
	ad.controlling_document_code,
	ad.controlling_document_position_code,
	ad.reference_operation_type_code,
	ad.dt_posting,
	ad.purchase_document_code,
	ad.purchase_document_position_code,
	ad.cost_element_code,
	ad.correspondence_general_ledger_account_code,
	ad.material_code,
	ad.creditor_code,
	ad.contract_code,
    aec.external_contract_number,
	ad.wbs_element_internal_code,
	ad.wbs_element_external_code,
	ad.investment_project_internal_code,
	ip.wbs_element_number as investment_project_external_code,
	ad.controlling_order_code,
	 coalesce(r.currency_to_multiplier,	1) * case when coalesce(r.currency_rate,1) > 0 then coalesce(r.currency_rate,1)	else 1	end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,1))else 1 end 
		* coalesce(currency_from_multiplier,1))::numeric(20,5) as document_exchange_to_usd_rate,
	ad.vat_code,
	ad.document_currency_amount,
	ad.document_currency_code,
	ad.document_currency_amount * coalesce(r.currency_to_multiplier,1) * case
		when coalesce(r.currency_rate,	1) > 0 then coalesce(r.currency_rate,	1)	else 1 end / 
		(case	when coalesce(r.currency_rate,	1) < 0 then abs(coalesce(r.currency_rate,1))else 1 end 
		* coalesce(currency_from_multiplier,1))::numeric(20,2) as document_usd_currency_amount,
	ad.second_local_currency_amount,
	ad.second_local_currency_code,
	ad.capitalization_code,
	case
		when coalesce (ia.capitalization_percent,
		ia2.capitalization_percent) is null then 100::numeric(5,2)
		else coalesce (ia.capitalization_percent,ia2.capitalization_percent)
	end as capitalization_percent,
	ceb.budget_group_code as budget_group_code,
	btext.budget_group_name as budget_group_name,
	ad.plant_code,
	c.currency_iso_code as document_currency_iso_code,
	glac.general_ledger_account_full_name_rus as cost_element_name,
	gla.general_ledger_account_full_name_rus as correspondence_general_ledger_account_name,
	mt.material_name,
	ct.counterparty_short_name as creditor_name,
	ct.counterparty_truncated_code, 
	ct.counterparty_search_name,
	wemdd.wbs_element_short_name as wbs_element_name,
	ip.wbs_element_short_name as investment_project_name,
	ot.order_short_name as controlling_order_name,
	pas.plant_short_name as plant_name,
	case when substring(ip.wbs_element_number from 1 for 4)= coalesce(ad.accounting_document_unit_balance_code, be.unit_balance_code )
         then substring(ip.wbs_element_number from 6) else ip.wbs_element_number end as investment_activity_external_code,
    ia_td.investment_budget_section_code,
    ibst.investment_budget_section_full_name as investment_budget_section_name,
    ia_td.investment_budget_subsection_code,
    ibsst.investment_budget_subsection_full_name	as investment_budget_subsection_name,
    ia_td.division_code,
    dt.division_full_name	as division_name,
    case when iaaf.investment_activity_code is not null
    	then '00' else ia_td.investment_budget_section_code end as investment_budget_section_actual_code,
    ibst2.investment_budget_section_full_name as investment_budget_section_actual_name,
    case when iaaf.investment_activity_code is not null
    	then '001' else  ia_td.investment_budget_subsection_code end as investment_budget_subsection_actual_code,
    ibsst2.investment_budget_subsection_full_name	as investment_budget_subsection_actual_name,
    ia_td.investment_program_code,
    ipt.investment_program_full_name as investment_program_name,
    case when expense_or_payment_source_type_code = 'ZTZR' and ad.wbs_element_internal_code is null
    then ad.accounting_document_unit_balance_code 
    else wemdd.wbs_element_unit_balance_code end wbs_element_unit_balance_code
from
	(

	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		reference_document_for_reporting_code,
		accounting_document_position_code,
		accounting_document_type_code,
		controlling_area_code,
		controlling_document_code,
		controlling_document_position_code,
		reference_operation_type_code,
		dt_posting,
		purchase_document_code,
		purchase_document_position_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		document_currency_amount,
		document_currency_code,
		second_local_currency_amount,
		second_local_currency_code,
		capitalization_code,
		plant_code
	from
		tmp_investment_expenses_actual_group_01
union all 

	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		reference_document_for_reporting_code,
		accounting_document_position_code,
		accounting_document_type_code,
		controlling_area_code,
		controlling_document_code,
		controlling_document_position_code,
		reference_operation_type_code,
		dt_posting,
		purchase_document_code,
		purchase_document_position_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		document_currency_amount,
		document_currency_code,
		second_local_currency_amount,
		second_local_currency_code,
		capitalization_code,
		plant_code
	from
		tmp_investment_expenses_actual_group_02
union all 

	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		reference_document_for_reporting_code,
		accounting_document_position_code,
		accounting_document_type_code,
		controlling_area_code,
		controlling_document_code,
		controlling_document_position_code,
		reference_operation_type_code,
		dt_posting,
		purchase_document_code,
		purchase_document_position_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		document_currency_amount,
		document_currency_code,
		second_local_currency_amount,
		second_local_currency_code,
		capitalization_code,
		plant_code
	from
		tmp_investment_expenses_actual_group_03
union all 

	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		reference_document_for_reporting_code,
		accounting_document_position_code,
		accounting_document_type_code,
		controlling_area_code,
		controlling_document_code,
		controlling_document_position_code,
		reference_operation_type_code,
		dt_posting,
		purchase_document_code,
		purchase_document_position_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		document_currency_amount,
		document_currency_code,
		second_local_currency_amount,
		second_local_currency_code,
		capitalization_code,
		plant_code
	from
		tmp_investment_expenses_actual_group_04
union all 

	select
		expense_or_payment_source_type_code,
		accounting_document_unit_balance_code,
		accounting_document_fiscal_year,
		accounting_document_code,
		reference_document_for_reporting_code,
		accounting_document_position_code,
		accounting_document_type_code,
		controlling_area_code,
		controlling_document_code,
		controlling_document_position_code,
		reference_operation_type_code,
		dt_posting,
		purchase_document_code,
		purchase_document_position_code,
		cost_element_code,
		correspondence_general_ledger_account_code,
		material_code,
		creditor_code,
		contract_code,
		wbs_element_internal_code,
		wbs_element_external_code,
		investment_project_internal_code,
		controlling_order_code,
		vat_code,
		document_currency_amount,
		document_currency_code,
		second_local_currency_amount,
		second_local_currency_code,
		capitalization_code,
		plant_code
	from
		tmp_investment_expenses_actual_group_05
		) as ad
left join dict_dds.currency c on
	c.currency_code = ad.document_currency_code
left join dict_dds.unit_balance ub on
	ub.unit_balance_code = ad.accounting_document_unit_balance_code
left join dm_calc.accounting_external_contracts aec  on
     aec.contract_code = ad.contract_code
     and aec.external_contract_source_table_name like 'purchase%'     
left join dict_dds.currency_rate  r on
		r.deleted_flag = false
	and r.currency_rate_type_code = 'M'
	and r.currency_to = 'USD'
	and r.currency_from = case
		when ad.document_currency_code like 'UE%'
	then c.currency_iso_code
		else ad.document_currency_code
	end
	and r.dt_currency_rate = ad.dt_posting
left join dict_dds.investment_project ip on
		ip.wbs_element_code = ad.investment_project_internal_code
left join dict_dds.map_cost_element_to_budget ceb 
on
	ceb.cost_element_code = ad.cost_element_code
	and (ceb.cost_element_type_code is null
		or ceb.cost_element_type_code = 'Z')
left join dict_dds.budget_group_texts btext
	on  btext.budget_group_code =  ceb.budget_group_code
	and btext.language_code ='R'
left join dict_dds.allocation_of_capitalization_value_for_investment_activity ia on
	ia.capitalization_version_code = '004'
	and ia.unit_balance_code = ad.accounting_document_unit_balance_code
	and ia.posting_reason_code = ad.capitalization_code
	and ia.dt_valid_from::DATE <= now()::date
	and ia.cost_element_mask_code = ad.cost_element_code
left join dict_dds.allocation_of_capitalization_value_for_investment_activity ia2 on
	ia2.capitalization_version_code = '004'
	and ia2.unit_balance_code = ad.accounting_document_unit_balance_code
	and ia2.posting_reason_code = ad.capitalization_code
	and ia2.dt_valid_from::DATE <= now()::date
	and ad.cost_element_code like ia2.cost_element_mask_code
left join dict_dds.general_ledger_account_chart glac on
	glac.general_ledger_account_code = ad.cost_element_code
	and glac.account_chart_code = ub.account_chart_code
left join dict_dds.general_ledger_account_chart gla on
	gla.general_ledger_account_code = ad.correspondence_general_ledger_account_code
	and gla.account_chart_code = ub.account_chart_code
left join dict_dds.plant_and_subsidiary ps on
	ps.plant_code  = ad.plant_code
left join dict_dds.unit_balance be on
	be.unit_balance_code = ps.unit_balance_code
left join dict_dds.material_texts mt on
	mt.material_code = ad.material_code
	and mt.language_code = 'R'
left join dict_dds.counterparty ct on
	ct.counterparty_code = ad.creditor_code
left join dict_dds.wbs_element_master_data_detail wemdd on
	wemdd.wbs_element_number = ad.wbs_element_external_code
left join ord ot on
	ot.order_code = ad.controlling_order_code
left join dict_dds.plant_and_subsidiary pas on
	pas.plant_code = ad.plant_code 
left join dict_dds.investment_activity_td ia_td
	on	ia_td.investment_activity_external_code = case when substring(ip.wbs_element_number from 1 for 4)=  coalesce(ad.accounting_document_unit_balance_code, be.unit_balance_code )
     then substring(ip.wbs_element_number from 6) else ip.wbs_element_number end
     and current_date between ia_td.dt_valid_from and ia_td.dt_valid_to
left join dict_dds.investment_budget_section_texts ibst
	on	ibst.investment_budget_section_code = ia_td.investment_budget_section_code
	and ibst.language_code = 'R'
left join dict_dds.investment_budget_subsection_texts ibsst	--
	on	ibsst.investment_budget_subsection_code = ia_td.investment_budget_subsection_code
	and ibsst.language_code = 'R'
left join dict_dds.division_texts dt
	on	dt.division_code = ia_td.division_code
	and dt.language_code = 'R'	
left join dict_dds.investment_activity_additional_finance iaaf
	on iaaf.fiscal_year = date_part('year', ad.dt_posting)::varchar
	and iaaf.investment_activity_code = 	case when substring(ip.wbs_element_number from 1 for 4)=ad.accounting_document_unit_balance_code 
         then substring(ip.wbs_element_number from 6) else ip.wbs_element_number end 
left join dict_dds.investment_budget_section_texts ibst2
	on	ibst2.investment_budget_section_code = case when iaaf.investment_activity_code is not null
    	then '00' else ia_td.investment_budget_section_code end
	and ibst2.language_code = 'R'
left join dict_dds.investment_budget_subsection_texts ibsst2	
	on	ibsst2.investment_budget_subsection_code = case when iaaf.investment_activity_code is not null
    	then '001' else  ia_td.investment_budget_subsection_code end
	and ibsst2.language_code = 'R'
left join dict_dds.investment_program_texts ipt
	on ipt.investment_program_code  = ia_td.investment_program_code
	and ipt.language_code = 'R';
