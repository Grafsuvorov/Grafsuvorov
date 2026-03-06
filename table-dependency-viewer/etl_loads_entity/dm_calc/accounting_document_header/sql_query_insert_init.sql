insert
	into
	dm_calc.accounting_document_header(
	unit_balance_code,
	fiscal_year,
	accounting_document_code,
	material_for_reporting_code,
	dt_posting,
	accounting_document_type_code,
	reference_object_key_code,
	dt_accounting_document,
	dttm_accounting_document_created,
	accounting_document_status_code,
	reference_document_number,
	document_header_reference_internal_key1_number,
	document_header_reference_internal_key2_number,
	reverse_document_code,
	reverse_document_fiscal_year,
	accounting_document_created_by,
    exchange_rate,
    document_currency_code,
	purchase_order_for_reporting_code,
	purchase_specification_compound_number)
with cte as (
	select
		pc.purchase_contract_code as purchase_order_for_reporting_code,
		'purchase_contract'::varchar(21) as external_contract_source_table_name,
		pc.paydox_registration_number,
		pc.appendix_number,
		coalesce(pc.paydox_registration_number, pc.appendix_number) as purchase_compound_number
	from
		dds.purchase_contract_header as pc
union all
	select
		po.purchase_order_code as purchase_order_for_reporting_code,
		'purchase_order'::varchar(21) as external_contract_source_table_name,
		po.paydox_registration_number,
		po.appendix_number,
		coalesce(po.paydox_registration_number, po.appendix_number) as purchase_compound_number
	from
		dds.purchase_order_header as po
union all
	select
		pa.purchase_agreement_code as purchase_order_for_reporting_code,
		'purchase_agreement'::varchar(21) as external_contract_source_table_name,
		pa.paydox_registration_number,
		pa.appendix_number,
		coalesce(pa.paydox_registration_number, pa.appendix_number) as purchase_compound_number
	from
		dds.purchase_agreement_header as pa),
cte2 as (
	select
		purchase_order_for_reporting_code,
		purchase_compound_number
	from
		cte
	order by
		purchase_compound_number asc),
taps as (
		select 
	cr.clearing_document_unit_balance_code as unit_balance_code,
	cr.clearing_document_fiscal_year  as fiscal_year,
	cr.clearing_document_code as accounting_document_code,
	aprbpo.purchase_document_code
from 	
	dds.advance_payment_requirements_by_purchase_orders aprbpo 
	left join dds.accounting_documents add2  on
	---Идем от дельты, тк новые тап всегда попадают в нее, отношение документ FI-документ ММ после попадания не меняются
		aprbpo.unit_balance_code = add2.unit_balance_code
		and aprbpo.fiscal_year::numeric = add2.fiscal_year
		and aprbpo.accounting_document_code = add2.accounting_document_code
	join dds.accounting_document_clearing_relations cr on
		aprbpo.unit_balance_code = cr.unit_balance_code 
		and aprbpo.fiscal_year::numeric = cr.fiscal_year::numeric 
		and aprbpo.accounting_document_code = cr.accounting_document_code 
	join ods.accounting_documents ad on 
		cr.clearing_document_unit_balance_code = ad.unit_balance_code and 
		cr.clearing_document_fiscal_year = ad.fiscal_year and
		cr.clearing_document_code = ad.accounting_document_code 
where 
	add2.accounting_document_status_code = 'S'
	and aprbpo.purchase_document_code is not null
	and add2.is_active = true
	and add2.is_deleted = false
group by 
	cr.clearing_document_unit_balance_code,
	cr.clearing_document_fiscal_year,
	cr.clearing_document_code,
	aprbpo.purchase_document_code
/*select 
	cr.clearing_document_unit_balance_code as unit_balance_code,
	cr.clearing_document_fiscal_year  as fiscal_year,
	cr.clearing_document_code as accounting_document_code,
	aprbpo.purchase_document_code
from 
	ods.accounting_documents add2
join dds.advance_payment_requirements_by_purchase_orders aprbpo on
---Идем от дельты, тк новые тап всегда попадают в нее, отношение документ FI-документ ММ после попадания не меняются
	aprbpo.unit_balance_code = add2.unit_balance_code
	and aprbpo.fiscal_year::numeric = add2.fiscal_year
	and aprbpo.accounting_document_code = add2.accounting_document_code
join dds.accounting_document_clearing_relations cr on
		aprbpo.unit_balance_code = cr.unit_balance_code 
	and aprbpo.fiscal_year::numeric = cr.fiscal_year::numeric 
	and aprbpo.accounting_document_code = cr.accounting_document_code 
where 
	add2.accounting_document_status_code = 'S'
	and aprbpo.purchase_document_code is not null
group by 
	cr.clearing_document_unit_balance_code,
	cr.clearing_document_fiscal_year,
	cr.clearing_document_code,
	aprbpo.purchase_document_code*/
),
taps_aggr as (
select
	tap.unit_balance_code ,
	tap.fiscal_year,
	tap.accounting_document_code,
	nullif(  array_to_string(array_agg(distinct cte.purchase_compound_number) over w,', '),'') as purchase_specification_compound_number,
	case
		when min(tap.purchase_document_code) over w	= max(tap.purchase_document_code) over w
		then min(tap.purchase_document_code) over w
		else null
		end as purchase_order_for_reporting_code,
	row_number() over w  as row_num
from 
	taps as tap 
	join cte as cte on
		tap.purchase_document_code = cte.purchase_order_for_reporting_code
where 1=1
window w as (partition by 
				tap.unit_balance_code,
				tap.fiscal_year,
				tap.accounting_document_code)),		
t as(
	select
		ad.unit_balance_code,
		ad.fiscal_year,
		ad.accounting_document_code,
		ad.material_code as material_for_reporting_code,
		ad.position_line_item,
		ad.dt_posting,
		ad.accounting_document_type as accounting_document_type_code,
		ad.reference_object_key as reference_object_key_code,
		ad.dt_accounting_document,
		ad.dttm_accounting_document_created,
		ad.accounting_document_status_code,
		ad.reference_document_number,
		ad.reference_key_internal_for_document_header_1 as document_header_reference_internal_key1_number,
		ad.reference_key_internal_for_document_header_2 as document_header_reference_internal_key2_number,
		ad.reverse_document_code,
		ad.reverse_document_fiscal_year,
		ad.accounting_document_created_by,
    	ad.exchange_rate,
    	ad.document_currency_code,
        nullif(array_to_string(array_agg(distinct cte.purchase_compound_number) over w,', '),'')  as purchase_specification_compound_number,
		dense_rank() over( partition by ad.unit_balance_code,
							ad.fiscal_year,
							ad.accounting_document_code
	order by
		--- по постановке необходимо отбирать материал из позиции с минимальным номером, для остальных полей - это неважно, тк они являются атрибутами заголовка
		case
			when ad.material_code is null then position_line_item + 999
			else position_line_item	end asc) as row_num,
	case
		when min(ad.purchase_document_code) over w	= max(ad.purchase_document_code) over w
			then min(ad.purchase_document_code) over w
			else null
		end as purchase_order_for_reporting_code,
		case when min(ad.purchase_document_code) over w is not null then 'X' else null end as is_purchase_document_exists
	from
		ods.accounting_documents ad
	left join cte2 as cte on
		ad.purchase_document_code = cte.purchase_order_for_reporting_code
	where
		1 = 1
		and ad.deleted_flag = false
		and ad.is_active = true
window w as (partition by ad.unit_balance_code,
							ad.fiscal_year,
							ad.accounting_document_code))
select
	t.unit_balance_code,
	t.fiscal_year,
	t.accounting_document_code,
	t.material_for_reporting_code,
	t.dt_posting,
	t.accounting_document_type_code,
	t.reference_object_key_code,
	t.dt_accounting_document,
	t.dttm_accounting_document_created,
	t.accounting_document_status_code,
	t.reference_document_number,
	t.document_header_reference_internal_key1_number,
	t.document_header_reference_internal_key2_number,
	t.reverse_document_code,
	t.reverse_document_fiscal_year,
	t.accounting_document_created_by,
    t.exchange_rate,
    t.document_currency_code,
	case when t.is_purchase_document_exists is not null then t.purchase_order_for_reporting_code else tap.purchase_order_for_reporting_code end as purchase_order_for_reporting_code, 
	case when t.is_purchase_document_exists is not null then t.purchase_specification_compound_number else tap.purchase_specification_compound_number end  as purchase_specification_compound_number 
	-- поле для отладки
	--,case when t.is_purchase_document_exists is not null then '1' else '2' end  as res
from
	t
left join taps_aggr as tap on
	tap.unit_balance_code = t.unit_balance_code
	and tap.fiscal_year = t.fiscal_year 
	and tap.accounting_document_code = t.accounting_document_code 
where 1=1
	and t.row_num = 1
	and (tap.row_num = 1 or tap.row_num is null);