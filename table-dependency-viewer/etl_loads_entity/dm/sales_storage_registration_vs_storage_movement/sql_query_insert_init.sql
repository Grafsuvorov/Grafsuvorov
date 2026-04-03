insert into dm.sales_storage_registration_vs_storage_movement (
	warehouse_code,																-- Удаленный склад (код) SD.000420
	forwarder_in_foreign_port_code, 											-- Экспедитор в иностранном порту (код) SD.000950
	transportation_delivery_code, 												-- LE-поставка прихода или расхода SD.001383
	warehouse_name,																-- Удаленный склад SD.000421
	country_of_remote_warehouse_code,											-- Страна удаленного склада (код) SD.000725
	country_of_remote_warehouse_name,											-- Страна удаленного склада SD.000423
	forwarder_in_foreign_port_name,												-- Экспедитор в иностранном порту SD.000609	
	region_of_remote_warehouse_code,											-- Регион удаленного склада (код) SD.000726
	transportation_delivery_creation_exceed_category_code,						-- Категория отклонения от даты создания LE-поставки SD.001382
	dt_shipment_instruction_in_foreign_port_created,							-- Дата создания инструкции на отгрузку из иностранного порта SD.001384
	shipment_instruction_creation_exceed_category_code,							-- Категория отклонения от даты создания ОИ SD.001396
	flow
)

with t24 as (
	select
		t4.knote as warehouse_code,												-- Удаленный склад (код) SD.000420
		t4.forwarder_in_foreign_port_code, 										-- Экспедитор в иностранном порту (код) SD.000950
		t4.delivery_code_le_p as transportation_delivery_code, 					-- ЛЕ поставка прихода
		t4.dt_transportation_stage_start_p as dt_transportation_stage_start,	-- Дата прихода 
		date(t4.dt_created) as dt_created,										-- Дата-время создания
		'P' as flow
	from 
		dm_calc.sales_bundle_transport_hub_turnover_sdt0004 as t4
	join 
		dict_dds.foreign_warehouse_priority_definition as fwpd
			on t4.knote = fwpd.transport_hub_code
			and fwpd.is_foreign_warehouse_code = 'X'
	group by
		t4.knote,																-- Удаленный склад (код) SD.000420
		t4.forwarder_in_foreign_port_code, 										-- Экспедитор в иностранном порту (код) SD.000950
		t4.delivery_code_le_p, 													-- ЛЕ поставка прихода
		t4.dt_transportation_stage_start_p,										-- Дата прихода 
		date(t4.dt_created)														-- Дата-время создания
	union all 
	select
		t4.knote as warehouse_code,												-- Удаленный склад (код) SD.000420
		t4.forwarder_in_foreign_port_code, 										-- Экспедитор в иностранном порту (код) SD.000950
		t4.delivery_code_le_r as transportation_delivery_code, 					-- ЛЕ поставка расхода
		t4.dt_transportation_stage_start_r as dt_transportation_stage_start,	-- Дата расхода 
		date(t4.dt_created_r) as dt_created,									-- Дата-время создания
		'R' as flow
	from 
		dm_calc.sales_bundle_transport_hub_turnover_sdt0004 as t4
	join 
		dict_dds.foreign_warehouse_priority_definition as fwpd
			on t4.knote = fwpd.transport_hub_code
			and fwpd.is_foreign_warehouse_code = 'X'
	group by
		t4.knote,																-- Удаленный склад (код) SD.000420
		t4.forwarder_in_foreign_port_code, 										-- Экспедитор в иностранном порту (код) SD.000950
		t4.delivery_code_le_r, 													-- ЛЕ поставка прихода
		t4.dt_transportation_stage_start_r,										-- Дата прихода 
		date(t4.dt_created_r)													-- Дата-время создания
), 
cre as (
	select
		vbss.vbeln,
		si.shipment_instruction_code,
		si.dt_created,		 		
		si.dt_shipment_instruction
	from 
		dds.shipment_instruction as si
		join ods."/rusal/vbss_le_ral" as vbss
			on vbss.sammg = si.shipment_instruction_code 
		join t24
			on vbss.vbeln = t24.transportation_delivery_code
			and flow = 'R'
	where
		si.shipment_instruction_type_code = '2'
	group by 
		vbss.vbeln,
		si.shipment_instruction_code,
		si.dt_created,		 		
		si.dt_shipment_instruction		
)
select
	t24.warehouse_code,															-- Удаленный склад (код) SD.000420
	t24.forwarder_in_foreign_port_code, 										-- Экспедитор в иностранном порту (код) SD.000950
	t24.transportation_delivery_code, 											-- LE-поставка прихода или расхода SD.001383
	tvknt.transport_hub_name as warehouse_name,									-- Удаленный склад SD.000421
	adrc.country_code as country_of_remote_warehouse_code,						-- Страна удаленного склада (код) SD.000725
	r_sd556t.country_full_name as country_of_remote_warehouse_name,				-- Страна удаленного склада SD.000423
	kna1.counterparty_short_name as forwarder_in_foreign_port_name,				-- Экспедитор в иностранном порту SD.000609	
	r_sd556.market_region1_code as region_of_remote_warehouse_code,				-- Регион удаленного склада (код) SD.000726
	case
		when t24.flow = 'P'
			then 
				case 
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 1
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 7
						then '02-07ПР'
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 7
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 14
						then '08-14ПР'
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 14
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 21
						then '15-21ПР'
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 21
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 30
						then '22-30ПР'	
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 30
						then '30ПР'	
				end
		when t24.flow = 'R' 
			then 
				case 
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 1
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 7
						then '02-07РАС'
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 7
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 14
						then '08-14РАС'
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 14
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 21
						then '15-21РАС'
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 21
        					and (t24.dt_created::date - t24.dt_transportation_stage_start) <= 30
						then '22-30РАС'	
					when (t24.dt_created::date - t24.dt_transportation_stage_start) > 30
						then '30РАС'	
				end
	end	as transportation_delivery_creation_exceed_category_code,				-- Категория отклонения SD.001382
	cre.dt_created::date as dt_shipment_instruction_in_foreign_port_created,	-- Дата создания инструкции на отгрузку из иностранного порта SD.001384
	case 
		when (cre.dt_created::date - t24.dt_transportation_stage_start) > 1
        		and (cre.dt_created::date - t24.dt_transportation_stage_start) <= 7
			then '02-07РАС'
		when (cre.dt_created::date - t24.dt_transportation_stage_start) > 7
        		and (cre.dt_created::date - t24.dt_transportation_stage_start) <= 14
			then '08-14РАС'
		when (cre.dt_created::date - t24.dt_transportation_stage_start) > 14
        		and (cre.dt_created::date - t24.dt_transportation_stage_start) <= 21
			then '15-21РАС'
		when (cre.dt_created::date - t24.dt_transportation_stage_start) > 21
        		and (cre.dt_created::date - t24.dt_transportation_stage_start) <= 30
			then '22-30РАС'	
		when (cre.dt_created::date - t24.dt_transportation_stage_start) > 30
			then '30РАС'	
	end as shipment_instruction_creation_exceed_category_code,
	t24.flow
from 
	t24
	left join dict_dds.transport_hub_texts as tvknt 	
		on tvknt.transport_hub_code = t24.warehouse_code
		and tvknt.language_code = 'E' 
	left join dict_dds.transport_hub as tvkn
		on tvkn.transport_hub_code = t24.warehouse_code
	left join dict_dds.address as adrc 									 	
		on adrc.address_code = tvkn.address_code
		and international_display_format_code is null
	left join dict_dds.country_texts as r_sd556t		
		on r_sd556t.country_code = adrc.country_code
		and r_sd556t.language_code = 'R'
	left join dict_dds.counterparty as kna1
		on kna1.counterparty_code = t24.forwarder_in_foreign_port_code
	left join dict_dds.country as r_sd556
		on r_sd556.country_code = adrc.country_code
	left join cre
		on cre.vbeln = t24.transportation_delivery_code;
