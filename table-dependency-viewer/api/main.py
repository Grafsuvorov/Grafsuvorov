часами бегает и падает с

QL Error [53500]: ERROR: Out of memory (seg2 slice1 10.66.229.174:10000 pid=32670) Подробности: Resource group memory limit reached

explain(analyze)	
with vbrk as (
select
	t.unit_balance_code,
	t.asset_main_code,
	t.payee_or_payer_code as buyer_code,
	t.personnel_code as realization_supervisor_code,
	t.document_currency_vat_excluded_amount as realization_document_currency_amount,
	t.document_currency_code as realization_document_currency_code
from
	(
	select
		ir.payee_or_payer_code,
		irp.document_currency_vat_excluded_amount,
		irp.document_currency_code,
		sdcr.personnel_code,
		rf.unit_balance_code as unit_balance_code,
		substring(irp.material_code, 3) as asset_main_code,
		row_number() over (partition by irp.material_code  order by ir.invoice_realization_code desc,ir.dt_billing_document desc
	) as rnum
	from
		dds.invoice_realization as ir
	left join dds.invoice_realization_position as irp on
		ir.invoice_realization_code = irp.invoice_realization_code
	left join dds.sales_document_counterparty_role as sdcr on
		sdcr.sales_document_code = irp.sales_document_code
		and (sdcr.sales_document_position_code = irp.sales_document_position_code
			or sdcr.sales_document_position_code = '000000')
		and sdcr.counterparty_role_code = 'VE'
	left join dict_dds.unit_balance as rf on
		rf.fixed_asset_material_prefix_code = left(irp.material_code, 2)
	where
		irp.sales_document_position_type_code in ('ZAOS', 'ZAKT')) as t
where
	t.rnum = 1
	and t.unit_balance_code is not null)
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
	fa.depreciation_typical_amount + fa.depreciation_special_amount + fa.depreciation_unplanned_amount as depreciation_total_amount,
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
from (


	select 	
		unit_balance_code,
		dt_depreciation_posting_mmm, 
		depreciation_posting_internal_code, 
		asset_main_code,
		asset_sub_code,
		reference_asset_main_code,
		reference_asset_sub_code,
		dt_posting_yyyy as dt_depreciation_posting_yyyy,
		valuation_area_code,
		depreciation_internal_order_code,
		asset_position_code,
		dt_posting::date,
		dt_reference,
		business_transaction_code,
		reference_operation_code,
		reference_organization_unit_code,
		general_ledger_operation_type_code,
		dt_asset_document_created,
		asset_movement_type_code,		
		red_reverse_reason_code,
		dt_red_reverse,
		red_reverse_code,
		is_virtual_asset_movement,	
		depreciation_cost_center_code,
		depreciation_typical_amount,
		depreciation_special_amount,
		valuation_area_currency_amount,
		acquisition_cost_valuation_area_currency_amount,
		proportional_cumulative_revaluation_amount,
	   	asset_realization_revenue_amount,
		depreciation_unplanned_amount,  
		cumulative_acquisition_and_production_cost_amount,
		cumulative_depreciation_typical_amount,
		cumulative_depreciation_special_amount,
		cumulative_depreciation_unplanned_amount,
		valuation_area_currency_code,
		asset_movement_type_or_depreciation_calculation_code,
		case when parameter_code = 'BWASL_L' then 'Ликвидация'
		when parameter_code = 'BWASL_SE' then 'Внешняя продажа'
		when parameter_code = 'BWASL_SI' then 'Внутренняя продажа'
		when parameter_code = 'BWASL_TR' then 'Безвозмездная передача'
		end as  disposal_type_source_name,
		case when parameter_code = 'BWASL_L' then '3'
		when parameter_code = 'BWASL_SE' then '5'
		when parameter_code = 'BWASL_SI' then '8'
		when parameter_code = 'BWASL_TR' then '1'
		end as  disposal_type_code,
		'A'	as non_liquid_asset_type_code,
		'Основные средства' as non_liquid_asset_type_name
from 
	dm_calc.fixed_asset_operations
left join dict_dds.settings_and_parameters_sap sap on
	sap.range_low_value = asset_movement_type_code
	and sap.abap_program_code = 'ZFI5668M'
	and sap.range_sign_code is not null
	and is_anlc is null
where dt_posting >= date_trunc('year', now()- interval '1 year')::date

union all

select 
	unit_balance_code,
	null as dt_depreciation_posting_mmm, 
	null as depreciation_posting_internal_code, 
	asset_main_code,
	asset_sub_code,
	null as reference_asset_main_code,
	null as reference_asset_sub_code,
	null  as dt_depreciation_posting_yyyy,
	valuation_area_code,
	null  as depreciation_internal_order_code,
	null  as asset_position_code,
	dt_lend_lease_posting as dt_posting,
	dt_lend_lease_posting as dt_reference,
	null  as business_transaction_code,
	null  as reference_operation_code,
	null  as reference_organization_unit_code,
	null  as general_ledger_operation_type_code,
	null  as dt_asset_document_created,
	null  as asset_movement_type_code,
	null  as red_reverse_reason_code,
	null  as dt_red_reverse,
	null  as red_reverse_code,
	null  as is_virtual_asset_movement,
	null  as depreciation_cost_center_code,
	depreciation_typical_amount,
	depreciation_special_amount,
	valuation_area_currency_amount,
	acquisition_cost_valuation_area_currency_amount,
	null as proportional_cumulative_revaluation_amount,
   	null as asset_realization_revenue_amount,
	depreciation_unplanned_amount,  
	null as cumulative_acquisition_and_production_cost_amount,
	null as cumulative_depreciation_typical_amount,
	null as cumulative_depreciation_special_amount,
	null as cumulative_depreciation_unplanned_amount,
	valuation_area_currency_code,
	'ZANLU_TRENT' as asset_movement_type_or_depreciation_calculation_code,
	'Передача в аренду' as  disposal_type_source_name,
	'7' as  disposal_type_code,
	non_liquid_asset_type_code,
	non_liquid_asset_type_name
	from 
(
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
	depreciation_unplanned_cumulative_amount as depreciation_unplanned_amount,
	cd.valuation_area_currency_code,
	cd.non_liquid_asset_type_code,
	cd.non_liquid_asset_type_name,
	row_number() over (partition by cd.unit_balance_code,
						cd.asset_main_code,
						cd.asset_sub_code,
						cd.valuation_area_code
					order by
						dt_report desc) as rn
from
	dm.fixed_asset_cost_and_depreciation cd
join dict_dds.fixed_asset_lend_lease ll on
	ll.unit_balance_code = cd.unit_balance_code
	and ll.asset_main_code = cd.asset_main_code
	and ll.asset_sub_code = cd.asset_sub_code
	and cd.dt_report <= ll.dt_lend_lease_posting
where 
	dt_report >= date_trunc('year', now()- interval '1 year')::date	
) t	
where 
rn = 1  )fa
left join  dm.fixed_asset_main fam on 
	fa.unit_balance_code = fam.unit_balance_code
	and fa.asset_main_code = fam.asset_main_code
	and fa.asset_sub_code = fam.asset_sub_code
	and fa.valuation_area_code = fam.valuation_area_code
	and fa.dt_posting between fam.dt_valid_from and fam.dt_valid_to
left join dict_dds.disposal_type_texts dtt on 
	fa.disposal_type_code = dtt.disposal_type_code
	and language_code = 'R'
left join vbrk v on 	
	v.unit_balance_code = fa.unit_balance_code
	and	v.asset_main_code = fa.asset_main_code 
left join dict_dds.counterparty c on 
	c.counterparty_code = v.buyer_code
left join dict_dds.personnel_main_data p on p.
	employee_code = v.realization_supervisor_code
	and fa.dt_posting between p.dt_valid_from and p.dt_valid_to
left join dict_dds.order_controlling ord on
		fa.depreciation_internal_order_code = ord.order_code
left join dict_dds.cost_center cc on		
	 fa.depreciation_cost_center_code = cc.cost_center_code
	and fa.dt_posting between cc.dt_valid_from and cc.dt_valid_to	
left join dict_dds.fixed_asset_movement_type_texts mtt on
		fa.asset_movement_type_code = mtt.fixed_asset_movement_type_code
		and mtt.language_code = 'R'
;



Gather Motion 6:1  (slice8; segments: 6)  (cost=0.00..901590.94 rows=173963851 width=636) (actual time=13528.886..76808.173 rows=11504383 loops=1)
  ->  Result  (cost=0.00..573724.75 rows=28993976 width=636) (actual time=13197.667..46343.497 rows=1925019 loops=1)
        ->  Hash Left Join  (cost=0.00..555284.58 rows=28993976 width=1078) (actual time=13197.656..45560.665 rows=1925019 loops=1)
              Hash Cond: ((fixed_asset_operations.asset_movement_type_code)::text = (fixed_asset_movement_type_texts.fixed_asset_movement_type_code)::text)
              Extra Text: (seg4)   Hash chain length 1.0 avg, 2 max, using 628 of 8192 buckets.Hash chain length 2.6 avg, 18 max, using 12473 of 16384 buckets.Initial batch 0:

              ->  Hash Left Join  (cost=0.00..433818.55 rows=14496988 width=1033) (actual time=13188.340..45075.243 rows=1925019 loops=1)
                    Hash Cond: ((fixed_asset_operations.depreciation_cost_center_code)::text = (cost_center.cost_center_code)::text)
                    Join Filter: ((fixed_asset_operations.dt_posting >= cost_center.dt_valid_from) AND (fixed_asset_operations.dt_posting <= cost_center.dt_valid_to))
                    Extra Text: (seg4)   Hash chain length 2.6 avg, 18 max, using 12473 of 16384 buckets.Initial batch 0:

                    ->  Hash Left Join  (cost=0.00..365946.59 rows=14496988 width=981) (actual time=13160.474..44356.997 rows=1925019 loops=1)
                          Hash Cond: ((fixed_asset_operations.depreciation_internal_order_code)::text = (order_controlling.order_code)::text)
                          Extra Text: (seg0)   Initial batch 0:
(seg0)     Wrote 15498K bytes to inner workfile.
(seg0)     Wrote 57536K bytes to outer workfile.
(seg0)   Initial batches 1..3:
(seg0)     Read 15498K bytes from inner workfile: 5166K avg x 3 nonempty batches, 5182K max.
(seg0)     Read 57536K bytes from outer workfile: 19179K avg x 3 nonempty batches, 27379K max.
(seg0)   Hash chain length 4.0 avg, 15 max, using 64304 of 65536 buckets.Initial batch 0:

                          ->  Hash Left Join  (cost=0.00..309887.84 rows=7248494 width=928) (actual time=13030.480..43488.473 rows=1925019 loops=1)
                                Hash Cond: ((sales_document_counterparty_role.personnel_code)::text = (personnel_main_data.employee_code)::text)
                                Join Filter: ((fixed_asset_operations.dt_posting >= personnel_main_data.dt_valid_from) AND (fixed_asset_operations.dt_posting <= personnel_main_data.dt_valid_to))
                                Extra Text: (seg1)   Initial batch 0:
(seg1)     Wrote 47666K bytes to inner workfile.
(seg1)     Wrote 6033K bytes to outer workfile.
(seg1)   Initial batches 1..15:
(seg1)     Read 47666K bytes from inner workfile: 3178K avg x 15 nonempty batches, 3222K max.
(seg1)     Read 6033K bytes from outer workfile: 403K avg x 15 nonempty batches, 2526K max.
(seg1)   Hash chain length 4.1 avg, 67 max, using 152907 of 262144 buckets.Initial batch 0:

                                ->  Hash Left Join  (cost=0.00..278441.61 rows=6403775 width=877) (actual time=12754.625..42691.840 rows=1925019 loops=1)
                                      Hash Cond: ((invoice_realization.payee_or_payer_code)::text = (counterparty.counterparty_code)::text)
                                      Extra Text: (seg0)   Initial batch 0:
(seg0)     Wrote 26820K bytes to inner workfile.
(seg0)     Wrote 7006K bytes to outer workfile.
(seg0)   Initial batches 1..7:
(seg0)     Read 26820K bytes from inner workfile: 3832K avg x 7 nonempty batches, 3847K max.
(seg0)     Read 7006K bytes from outer workfile: 1001K avg x 7 nonempty batches, 3316K max.
(seg0)   Hash chain length 3.4 avg, 15 max, using 126411 of 131072 buckets.Initial batch 0:

                                      ->  Hash Left Join  (cost=0.00..255390.11 rows=3201888 width=832) (actual time=12404.857..41759.903 rows=1925019 loops=1)
                                            Hash Cond: (((fixed_asset_operations.unit_balance_code)::text = (unit_balance.unit_balance_code)::text) AND ((fixed_asset_operations.asset_main_code)::text = ("substring"((invoice_realization_position.material_code)::text, 3))))
                                            Extra Text: (seg3)   Initial batch 0:
(seg3)     Wrote 1349K bytes to inner workfile.
(seg3)     Wrote 1152042K bytes to outer workfile.
(seg3)   Initial batches 1..31:
(seg3)     Read 1349K bytes from inner workfile: 44K avg x 31 nonempty batches, 48K max.
(seg3)     Read 1152042K bytes from outer workfile: 37163K avg x 31 nonempty batches, 38497K max.
(seg3)   Hash chain length 1.0 avg, 3 max, using 19014 of 524288 buckets.Hash chain length 1.0 avg, 1 max, using 9 of 16384 buckets.Initial batch 0:

                                            ->  Redistribute Motion 6:6  (slice3; segments: 6)  (cost=0.00..191366.22 rows=3201888 width=814) (actual time=8049.809..34149.260 rows=1925019 loops=1)
                                                  Hash Key: fixed_asset_operations.unit_balance_code, fixed_asset_operations.asset_main_code
                                                  ->  Hash Left Join  (cost=0.00..183208.38 rows=3201888 width=814) (actual time=12943.548..33248.165 rows=1919989 loops=1)
                                                        Hash Cond: ((CASE WHEN ((settings_and_parameters_sap.parameter_code)::text = 'BWASL_L'::text) THEN '3'::text WHEN ((settings_and_parameters_sap.parameter_code)::text = 'BWASL_SE'::text) THEN '5'::text WHEN ((settings_and_parameters_sap.parameter_code)::text = 'BWASL_SI'::text) THEN '8'::text WHEN ((settings_and_parameters_sap.parameter_code)::text = 'BWASL_TR'::text) THEN '1'::text ELSE NULL::text END) = (disposal_type_texts.disposal_type_code)::text)
                                                        Extra Text: (seg3)   Hash chain length 1.0 avg, 1 max, using 9 of 16384 buckets.Initial batch 0:

                                                        ->  Hash Left Join  (cost=0.00..171560.20 rows=3201888 width=789) (actual time=12936.013..32752.663 rows=1919989 loops=1)
                                                              Hash Cond: (((fixed_asset_operations.unit_balance_code)::text = (fixed_asset_main.unit_balance_code)::text) AND ((fixed_asset_operations.asset_main_code)::text = (fixed_asset_main.asset_main_code)::text) AND ((fixed_asset_operations.asset_sub_code)::text = (fixed_asset_main.asset_sub_code)::text) AND ((fixed_asset_operations.valuation_area_code)::text = (fixed_asset_main.valuation_area_code)::text))
                                                              Join Filter: ((fixed_asset_operations.dt_posting >= fixed_asset_main.dt_valid_from) AND (fixed_asset_operations.dt_posting <= fixed_asset_main.dt_valid_to))
                                                              Extra Text: (seg2)   Initial batch 0:
(seg2)     Wrote 3020979K bytes to inner workfile.
(seg2)     Wrote 325384K bytes to outer workfile.
(seg2)   Initial batches 1..1023:
(seg2)     Read 3020979K bytes from inner workfile: 2954K avg x 1023 nonempty batches, 3256K max.
(seg2)     Read 325384K bytes from outer workfile: 319K avg x 1023 nonempty batches, 377K max.
(seg2)   Hash chain length 4.0 avg, 46 max, using 1587013 of 4194304 buckets.Hash chain length 1.0 avg, 1 max, using 61 of 16384 buckets.Initial batch 0:

                                                              ->  Append  (cost=0.00..45175.69 rows=3201888 width=235) (actual time=0.060..11697.775 rows=1919989 loops=1)
                                                                    ->  Result  (cost=0.00..7130.63 rows=2516574 width=235) (actual time=0.040..2758.966 rows=1887338 loops=1)
                                                                          ->  Redistribute Motion 6:6  (slice1; segments: 6)  (cost=0.00..6539.23 rows=2516574 width=208) (actual time=0.025..1734.230 rows=1887338 loops=1)
                                                                                Hash Key: fixed_asset_operations.unit_balance_code, fixed_asset_operations.asset_main_code, fixed_asset_operations.asset_sub_code, fixed_asset_operations.valuation_area_code
                                                                                ->  Hash Left Join  (cost=0.00..4900.84 rows=2516574 width=208) (actual time=360.928..2784.178 rows=1889537 loops=1)
                                                                                      Hash Cond: ((fixed_asset_operations.asset_movement_type_code)::text = (settings_and_parameters_sap.range_low_value)::text)
                                                                                      Join Filter: (fixed_asset_operations.is_anlc IS NULL)
                                                                                      Extra Text: (seg2)   Hash chain length 1.0 avg, 1 max, using 61 of 16384 buckets.Initial batch 0:

                                                                                      ->  Seq Scan on fixed_asset_operations  (cost=0.00..1838.13 rows=1867652 width=205) (actual time=304.547..2413.463 rows=1889537 loops=1)
                                                                                            Filter: (dt_posting >= '2025-01-01'::date)
                                                                                      ->  Hash  (cost=510.56..510.56 rows=58 width=13) (actual time=54.546..54.546 rows=61 loops=1)
                                                                                            ->  Seq Scan on settings_and_parameters_sap  (cost=0.00..510.56 rows=58 width=13) (actual time=24.910..54.524 rows=61 loops=1)
                                                                                                  Filter: (((abap_program_code)::text = 'ZFI5668M'::text) AND (NOT (range_sign_code IS NULL)))
                                                                    ->  Result  (cost=0.00..37292.61 rows=685314 width=294) (actual time=8295.165..8797.940 rows=32738 loops=1)
                                                                          ->  Result  (cost=0.00..37292.61 rows=685314 width=294) (actual time=8295.153..8792.718 rows=32738 loops=1)
                                                                                ->  Result  (cost=0.00..37091.13 rows=685314 width=82) (actual time=8295.144..8785.736 rows=32738 loops=1)
                                                                                      Filter: ((row_number() OVER (?)) = 1)
                                                                                      ->  WindowAgg  (cost=0.00..37034.76 rows=1713285 width=90) (actual time=8295.133..8772.377 rows=196007 loops=1)
                                                                                            Partition By: fixed_asset_cost_and_depreciation.unit_balance_code, fixed_asset_cost_and_depreciation.asset_main_code, fixed_asset_cost_and_depreciation.asset_sub_code, fixed_asset_cost_and_depreciation.valuation_area_code
                                                                                            Order By: fixed_asset_cost_and_depreciation.dt_report
                                                                                            ->  Sort  (cost=0.00..36887.42 rows=1713285 width=86) (actual time=8295.111..8692.391 rows=196007 loops=1)
                                                                                                  Sort Key: fixed_asset_cost_and_depreciation.unit_balance_code, fixed_asset_cost_and_depreciation.asset_main_code, fixed_asset_cost_and_depreciation.asset_sub_code, fixed_asset_cost_and_depreciation.valuation_area_code, fixed_asset_cost_and_depreciation.dt_report
                                                                                                  Sort Method:  external merge  Disk: 134400kB
                                                                                                  ->  Redistribute Motion 6:6  (slice2; segments: 6)  (cost=0.00..19587.03 rows=1713285 width=86) (actual time=0.013..6639.231 rows=196007 loops=1)
                                                                                                        Hash Key: fixed_asset_cost_and_depreciation.unit_balance_code, fixed_asset_cost_and_depreciation.asset_main_code, fixed_asset_cost_and_depreciation.asset_sub_code, fixed_asset_cost_and_depreciation.valuation_area_code
                                                                                                        ->  Hash Join  (cost=0.00..19125.85 rows=1713285 width=86) (actual time=319.124..9210.723 rows=195623 loops=1)
                                                                                                              Hash Cond: (((fixed_asset_cost_and_depreciation.unit_balance_code)::text = (fixed_asset_lend_lease.unit_balance_code)::text) AND ((fixed_asset_cost_and_depreciation.asset_main_code)::text = (fixed_asset_lend_lease.asset_main_code)::text) AND ((fixed_asset_cost_and_depreciation.asset_sub_code)::text = (fixed_asset_lend_lease.asset_sub_code)::text))
                                                                                                              Join Filter: (fixed_asset_cost_and_depreciation.dt_report <= fixed_asset_lend_lease.dt_lend_lease_posting)
                                                                                                              Extra Text: (seg0)   Initial batch 0:
(seg0)     Wrote 20072K bytes to inner workfile.
(seg0)     Wrote 820205K bytes to outer workfile.
(seg0)   Initial batches 1..7:
(seg0)     Read 20072K bytes from inner workfile: 2868K avg x 7 nonempty batches, 2899K max.
(seg0)     Read 820205K bytes from outer workfile: 117173K avg x 7 nonempty batches, 117749K max.
(seg0)   Hash chain length 3.1 avg, 37 max, using 173276 of 262144 buckets.
                                                                                                              ->  Seq Scan on fixed_asset_cost_and_depreciation  (cost=0.00..11317.02 rows=8395263 width=82) (actual time=60.937..4101.069 rows=8370715 loops=1)
                                                                                                                    Filter: (dt_report >= '2025-01-01'::date)
                                                                                                              ->  Hash  (cost=483.51..483.51 rows=533417 width=26) (actual time=193.493..193.493 rows=533417 loops=1)
                                                                                                                    ->  Seq Scan on fixed_asset_lend_lease  (cost=0.00..483.51 rows=533417 width=26) (actual time=22.086..89.462 rows=533417 loops=1)
                                                              ->  Hash  (cost=4648.99..4648.99 rows=6280976 width=570) (actual time=12549.266..12549.266 rows=6285212 loops=1)
                                                                    ->  Seq Scan on fixed_asset_main  (cost=0.00..4648.99 rows=6280976 width=570) (actual time=377.690..5756.393 rows=6285268 loops=1)
                                                        ->  Hash  (cost=431.00..431.00 rows=9 width=27) (actual time=9.650..9.650 rows=9 loops=1)
                                                              ->  Seq Scan on disposal_type_texts  (cost=0.00..431.00 rows=9 width=27) (actual time=9.635..9.644 rows=9 loops=1)
                                                                    Filter: ((language_code)::text = 'R'::text)
                                            ->  Hash  (cost=41486.80..41486.80 rows=1608616 width=49) (actual time=4362.990..4362.990 rows=19408 loops=1)
                                                  ->  Redistribute Motion 6:6  (slice7; segments: 6)  (cost=0.00..41486.80 rows=1608616 width=49) (actual time=4190.382..4358.750 rows=19408 loops=1)
                                                        Hash Key: unit_balance.unit_balance_code, ("substring"((invoice_realization_position.material_code)::text, 3))
                                                        ->  Result  (cost=0.00..41240.08 rows=1608616 width=49) (actual time=4943.807..5031.722 rows=19423 loops=1)
                                                              ->  Result  (cost=0.00..41240.08 rows=1608616 width=49) (actual time=4943.803..5029.601 rows=19423 loops=1)
                                                                    ->  Result  (cost=0.00..41000.40 rows=1608616 width=56) (actual time=4943.796..5025.684 rows=19423 loops=1)
                                                                          Filter: (((row_number() OVER (?)) = 1) AND (NOT (unit_balance.unit_balance_code IS NULL)))
                                                                          ->  WindowAgg  (cost=0.00..40735.78 rows=4021540 width=64) (actual time=4939.065..5035.218 rows=55531 loops=1)
                                                                                Partition By: invoice_realization_position.material_code
                                                                                Order By: invoice_realization.invoice_realization_code, invoice_realization.dt_billing_document
                                                                                ->  Sort  (cost=0.00..40204.94 rows=4021540 width=66) (actual time=4939.046..5013.911 rows=55531 loops=1)
                                                                                      Sort Key: invoice_realization_position.material_code, invoice_realization.invoice_realization_code, invoice_realization.dt_billing_document
                                                                                      Sort Method:  external merge  Disk: 26688kB
                                                                                      ->  Redistribute Motion 6:6  (slice6; segments: 6)  (cost=0.00..7187.58 rows=4021540 width=66) (actual time=4308.485..4579.503 rows=55531 loops=1)
                                                                                            Hash Key: invoice_realization_position.material_code
                                                                                            ->  Hash Left Join  (cost=0.00..6356.81 rows=4021540 width=66) (actual time=4301.631..4525.284 rows=56108 loops=1)
                                                                                                  Hash Cond: ("left"((invoice_realization_position.material_code)::text, 2) = (unit_balance.fixed_asset_material_prefix_code)::text)
                                                                                                  Extra Text: (seg0)   Hash chain length 1.1 avg, 2 max, using 52 of 32768 buckets.
                                                                                                  ->  Hash Join  (cost=0.00..4982.80 rows=65631 width=61) (actual time=4291.545..4501.307 rows=50081 loops=1)
                                                                                                        Hash Cond: ((invoice_realization.invoice_realization_code)::text = (invoice_realization_position.invoice_realization_code)::text)
                                                                                                        Extra Text: (seg0)   Hash chain length 11.3 avg, 1095 max, using 4420 of 32768 buckets.
                                                                                                        ->  Seq Scan on invoice_realization  (cost=0.00..490.53 rows=845594 width=26) (actual time=12.885..120.324 rows=846692 loops=1)
                                                                                                        ->  Hash  (cost=4201.92..4201.92 rows=65631 width=46) (actual time=4280.497..4280.497 rows=50081 loops=1)
                                                                                                              ->  Redistribute Motion 6:6  (slice5; segments: 6)  (cost=0.00..4201.92 rows=65631 width=46) (actual time=1141.093..4272.171 rows=50081 loops=1)
                                                                                                                    Hash Key: invoice_realization_position.invoice_realization_code
                                                                                                                    ->  Hash Right Join  (cost=0.00..4192.47 rows=65631 width=46) (actual time=1022.062..4230.052 rows=57934 loops=1)
                                                                                                                          Hash Cond: ((sales_document_counterparty_role.sales_document_code)::text = (invoice_realization_position.sales_document_code)::text)
                                                                                                                          Join Filter: (((sales_document_counterparty_role.sales_document_position_code)::text = (invoice_realization_position.sales_document_position_code)::text) OR ((sales_document_counterparty_role.sales_document_position_code)::text = '000000'::text))
                                                                                                                          Extra Text: (seg4)   Hash chain length 35.3 avg, 11789 max, using 1639 of 16384 buckets.
                                                                                                                          ->  Seq Scan on sales_document_counterparty_role  (cost=0.00..2634.33 rows=1552991 width=27) (actual time=10.641..2701.822 rows=1592636 loops=1)
                                                                                                                                Filter: ((counterparty_role_code)::text = 'VE'::text)
                                                                                                                          ->  Hash  (cost=909.63..909.63 rows=50112 width=55) (actual time=1004.790..1004.790 rows=57909 loops=1)
                                                                                                                                ->  Redistribute Motion 6:6  (slice4; segments: 6)  (cost=0.00..909.63 rows=50112 width=55) (actual time=3.801..996.645 rows=57909 loops=1)
                                                                                                                                      Hash Key: invoice_realization_position.sales_document_code
                                                                                                                                      ->  Seq Scan on invoice_realization_position  (cost=0.00..901.01 rows=50112 width=55) (actual time=49.866..955.933 rows=48373 loops=1)
                                                                                                                                            Filter: ((sales_document_position_type_code)::text = ANY ('{ZAOS,ZAKT}'::text[]))
                                                                                                  ->  Hash  (cost=431.04..431.04 rows=487 width=8) (actual time=9.820..9.820 rows=57 loops=1)
                                                                                                        ->  Seq Scan on unit_balance  (cost=0.00..431.04 rows=487 width=8) (actual time=9.747..9.796 rows=487 loops=1)
                                      ->  Hash  (cost=573.56..573.56 rows=435628 width=56) (actual time=200.113..200.113 rows=435628 loops=1)
                                            ->  Seq Scan on counterparty  (cost=0.00..573.56 rows=435628 width=56) (actual time=16.815..91.868 rows=435628 loops=1)
                                ->  Hash  (cost=502.71..502.71 rows=623814 width=68) (actual time=268.836..268.836 rows=623814 loops=1)
                                      ->  Seq Scan on personnel_main_data  (cost=0.00..502.71 rows=623814 width=68) (actual time=23.096..138.216 rows=623814 loops=1)
                          ->  Hash  (cost=488.07..488.07 rows=258771 width=65) (actual time=137.177..137.177 rows=258771 loops=1)
                                ->  Seq Scan on order_controlling  (cost=0.00..488.07 rows=258771 width=65) (actual time=29.929..80.586 rows=258771 loops=1)
                    ->  Hash  (cost=433.76..433.76 rows=32745 width=70) (actual time=51.204..51.204 rows=32745 loops=1)
                          ->  Seq Scan on cost_center  (cost=0.00..433.76 rows=32745 width=70) (actual time=37.513..43.562 rows=32745 loops=1)
              ->  Hash  (cost=431.39..431.39 rows=651 width=49) (actual time=8.483..8.483 rows=651 loops=1)
                    ->  Seq Scan on fixed_asset_movement_type_texts  (cost=0.00..431.39 rows=651 width=49) (actual time=7.956..8.336 rows=651 loops=1)
                          Filter: ((language_code)::text = 'R'::text)
Planning time: 564.524 ms
  (slice0)    Executor memory: 15415K bytes.
  (slice1)    Executor memory: 5621K bytes avg x 6 workers, 5623K bytes max (seg1).  Work_mem: 3K bytes max.
* (slice2)    Executor memory: 11163K bytes avg x 6 workers, 11163K bytes max (seg0).  Work_mem: 3689K bytes max, 29172K bytes wanted.
* (slice3)    Executor memory: 90076K bytes avg x 6 workers, 90085K bytes max (seg2).  Work_mem: 9141K bytes max, 3097681K bytes wanted.
  (slice4)    Executor memory: 1022K bytes avg x 6 workers, 1022K bytes max (seg0).
  (slice5)    Executor memory: 9066K bytes avg x 6 workers, 9066K bytes max (seg0).  Work_mem: 5016K bytes max.
  (slice6)    Executor memory: 9578K bytes avg x 6 workers, 9578K bytes max (seg0).  Work_mem: 3866K bytes max.
* (slice7)    Executor memory: 9410K bytes avg x 6 workers, 9410K bytes max (seg0).  Work_mem: 9209K bytes max, 15171K bytes wanted.
* (slice8)    Executor memory: 48320K bytes avg x 6 workers, 48418K bytes max (seg2).  Work_mem: 5980K bytes max, 58106K bytes wanted.
Memory used:  90112kB
Memory wanted:  55762652kB
Optimizer: Pivotal Optimizer (GPORCA)
Execution time: 78235.227 ms
