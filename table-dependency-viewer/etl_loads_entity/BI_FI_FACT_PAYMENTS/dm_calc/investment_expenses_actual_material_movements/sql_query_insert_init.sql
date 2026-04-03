insert
	into
	dm_calc.investment_expenses_actual_material_movements
with 
bwtar as (
	select
		case_code,
		range_low_value as valuation_type_code
	from
		(
		select
			saps.case_code,
			saps.range_low_value,
			dense_rank() over ( partition by saps.case_code,
			saps.parameter_code
		order by
			coalesce(saps.dt_valid_from,'1000-01-01') desc ) as row_num
		from
			dict_dds.settings_and_parameters_sap saps
		where
			saps.abap_program_code = '/RUSAL/FI1349M'
			and (saps.parameter_code = 'BWTAR_EX')
			and saps.range_sign_code is not null) as saps
	where
		row_num = 1
	group by
		case_code,
		range_low_value 
),
	
yr as (
	select
		case_code,
		range_low_value
	from
		(
		select
			saps.case_code,
			saps.range_low_value,
			dense_rank() over ( partition by saps.case_code ,
			saps.parameter_code
		order by
			coalesce(saps.dt_valid_from,'1000-01-01') desc ) as row_num
		from
			dict_dds.settings_and_parameters_sap saps
		where
			saps.abap_program_code = '/RUSAL/FI1349M'
			and (saps.parameter_code = 'P_YEARS')
				and saps.range_sign_code is not null) as saps
	where
		row_num = 1
	group by
		case_code,
		range_low_value 
),
	mseg_rseg as 
(
select 
	1 as part,
		material_movement_document_code,
		material_movement_document_year,
		material_code,
		wbs_element_code ,
		payee_alternative_code,
		purchase_document_code,
		purchase_document_position_line_item_code
		from 
		(

	select
		1 as part,
		mmd.material_movement_document_code,
		mmd.material_movement_document_year,
		mmd.material_code,
		mmd.wbs_element_code ,
		dp.payee_alternative_code,
		dp.purchase_document_code,
		dp.purchase_document_position_line_item_code,
				row_number() over (partition by 
					mmd.unit_balance_code,
					mmd.material_movement_document_code,
					mmd.material_movement_document_year,
					mmd.material_code,
					mmd.wbs_element_code
			order by
					dp.fiscal_year desc,
					is_additionaly_debited_code desc,
					dp.invoice_code desc) as rn
	from
		dds.material_movement_document mmd
	join 
		dm_calc.investment_expenses_invoice_purchase_documents dp on
		--RSEG  on
		dp.material_code = mmd.material_code
		and dp.unit_balance_code = mmd.unit_balance_code
		and dp.plant_code = mmd.plant_code
		and dp.reference_document_code = mmd.reference_document_code
		and dp.reference_document_fiscal_year = mmd.reference_document_fiscal_year
		and dp.reference_document_position_line_item_code = mmd.reference_document_position_line_item_code
	where 
		mmd.wbs_element_code <> '00000000' and ( 
		dp.payee_alternative_code is not null
		or dp.purchase_contract_code is not null
		or dp.purchase_document_position_line_item_code is not null)
		) p1
	where rn =1
union all
	select
		2 as part,
		material_movement_document_code,
		material_movement_document_year,
		material_code,
		wbs_element_code ,
		payee_alternative_code,
		purchase_document_code,
		purchase_document_position_line_item_code
	from
		(
		select
			mmd.material_movement_document_code,
			mmd.material_movement_document_year,
			mmd.material_code,
			mmd.wbs_element_code ,
			dp2.payee_alternative_code,
			dp2.purchase_document_code,
			dp2.purchase_document_position_line_item_code,
			row_number() over (partition by 
					mmd.unit_balance_code,
					mmd.material_movement_document_code,
					mmd.material_movement_document_year,
					mmd.material_code,
					mmd.wbs_element_code
			order by
					dp2.fiscal_year desc,
					is_additionaly_debited_code desc,
					dp2.invoice_code desc) as rn
		from
			dds.material_movement_document mmd
		left join yr as saps on
			saps.case_code = mmd.unit_balance_code
		left join bwtar as bwtr on
			bwtr.case_code = mmd.unit_balance_code
			and mmd.valuation_type_code = bwtr.valuation_type_code
		left join dm_calc.investment_expenses_invoice_purchase_documents dp2 on
			dp2.fiscal_year >= (mmd.material_movement_document_year::numeric -saps.range_low_value::numeric ) ::varchar
				and dp2.fiscal_year <= mmd.material_movement_document_year
				and dp2.material_code = mmd.material_code
				and dp2.valuation_type_code = mmd.valuation_type_code
				and dp2.unit_balance_code = mmd.unit_balance_code
				and dp2.plant_code = mmd.plant_code
				and bwtr.valuation_type_code is null
			where
				mmd.wbs_element_code <> '00000000'
				and (dp2.payee_alternative_code is not null
					or dp2.purchase_contract_code is not null
					or dp2.purchase_document_position_line_item_code is not null )			
) p2
	where
		rn = 1
		
)
select
	material_movement_document_code,
	material_movement_document_year,
	material_code,
	wbs_element_code,
	payee_alternative_code,
	purchase_document_code,
	purchase_document_position_line_item_code
from
	(
	select
 		mseg_rseg.material_movement_document_code,
		mseg_rseg.material_movement_document_year,
		mseg_rseg.material_code,
		mseg_rseg.wbs_element_code ,
		mseg_rseg.payee_alternative_code,
		mseg_rseg.purchase_document_code,
		mseg_rseg.purchase_document_position_line_item_code,
		row_number() over (partition by 
			material_movement_document_code,
			material_movement_document_year,
			material_code,
			wbs_element_code
		order by
			part)
as rn
	from
		mseg_rseg
) mr
where
	rn = 1;
