insert into dds.transport_bill_and_bill_of_lading_relation (
	transport_bill_code,
	vehicle_code,
	transport_bill_and_vehicle_code,
	vessel_code,
	bill_of_lading_number,
	delivery_code,
	dt_general_act,
	dt_vessel_arrival_to_russian_port,
	supplier_code,
	producer_code,
	material_code,
	package_type_code,
	weight_net
)
select
	lp.numnakl as transport_bill_code,
	lp.numvag as vehicle_code,
	lp.numnakl||'-'||lp.numvag as transport_bill_and_vehicle_code,	
	lp.vehicle as vessel_code,
	lp.conosnum as bill_of_lading_number,
	lp.delivery_in as delivery_code,
	lp.genaktdate as dt_general_act,
	lp.arrvesdate as dt_vessel_arrival_to_russian_port,
	ausp1.atwrt as supplier_code,
	ausp2.atwrt as producer_code,
	lp.matnr as material_code,
	lp.cartare as package_type_code,
	sum(lp.weightnet) as weight_net
from ods."/rusal/lepervlka_ral" as lp
	left join ods.lips_ral as lips
		on lips.vbeln = lp.delivery_in
	left join dict_stg."INOB" as inob
		on inob."OBJEK" = lips.matnr||lips.charg
	left join ods.ausp_ral as ausp1
		on ausp1.objek = inob."CUOBJ" and
	       ausp1.atinn = ( select cabn.internal_characteristic_code		
						   from dict_dds.internal_characteristic as cabn
		                   where cabn.internal_characteristic_title_code = 'ROH_PVAG' ) and				--0000000063
		   ausp1.klart = '023'
	left join ods.ausp_ral as ausp2
		on ausp2.objek = inob."CUOBJ" and
	       ausp2.atinn = ( select cabn.internal_characteristic_code		
					   	   from dict_dds.internal_characteristic as cabn
		               	   where cabn.internal_characteristic_title_code = 'ROH_PROIZV' ) and 			--0000001909
		   ausp2.klart = '023'
group by
	lp.numnakl,
	lp.numvag,
	lp.vehicle,
	lp.conosnum,
	lp.delivery_in,
	lp.genaktdate,
	lp.arrvesdate,
	ausp1.atwrt,
	ausp2.atwrt,
	lp.matnr,
	lp.cartare
-----------------------------------------------------------------------------------------------------------------------------------
union all
-----------------------------------------------------------------------------------------------------------------------------------
select
	lp.numnakl as transport_bill_code,
	lp.numvag as vehicle_code,
	lp.numnakl||'-'||lp.numvag as transport_bill_and_vehicle_code,	
	lp.vehicle as vessel_code,
	lp.conosnum as bill_of_lading_number,
	lp.delivery_in as delivery_code,
	lp.genaktdate as dt_general_act,
	null as dt_vessel_arrival_to_russian_port,	
	null as supplier_code,
	null as producer_code,
	lp.matnr as material_code,
	lp.cartare as package_type_code,	
	sum(lp.weightnet) as weight_net
from ods."/rusal/lepervlk1_ral" as lp
	left join ods."/rusal/lepervlka_ral" as leper1
		on leper1.numvag = lp.numvag and
		   leper1.numnakl = lp.numnakl
	left join ods."/rusal/lepervlka_ral" as leper2
		on leper2.regdate = lp.regdate and
		   leper2.vehicle = lp.vehicle
where leper1.numvag is null 
	and leper1.numnakl is null
	and leper2.regdate is null 
	and leper2.vehicle is null
group by
	lp.numnakl,
	lp.numvag,
	lp.vehicle,
	lp.conosnum,
	lp.delivery_in,
	lp.genaktdate,
	lp.matnr,
	lp.cartare
;