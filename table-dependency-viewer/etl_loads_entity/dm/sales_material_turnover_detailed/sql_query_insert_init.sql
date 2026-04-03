drop table if exists sdt18;
create temp table sdt18 as (
--with sdt18 as (
	select
		lddr.delivery_code
		,si.shipment_instruction_code
		,si.shipment_instruction_number 
		,si.location_of_port_of_discharge_code
		,si.dt_shipment_instruction
		,row_number() over(partition by lddr.delivery_code order by si.dt_shipment_instruction, si.shipment_instruction_code) as rn
	from dds.logistics_document_and_delivery_relationship as lddr	
	  join dds.shipment_instruction as si	
	    on lddr.logistics_document_code = si.shipment_instruction_code 
	  where si.shipment_instruction_type_code = '2'	
	  )
distributed by (delivery_code, shipment_instruction_number, rn);

drop table if exists vbln;
create temp table vbln as (
--,vbln as ( --cte1 из t5
	select -- distinct 
		 ssms.delivery_number_sales 											-- Продажная поставка SD.000002 
		,sd4798.sales_bundle_code
		,ssms.batch																-- Партия SD.000004
		,ssms.delivery_number_initial											-- Исходная поставка SD.000001
		,ssms.port_of_discharge_code											-- Порт выгрузки (код) SD.000044
		,ssms.port_of_discharge_name											-- Порт выгрузки SD.000045
 		,ssms.bill_of_lading_in_foreign_port									-- Коносамент в ин.порту SD.000048
 		,ssms.external_contract_in_lot_number 									-- Контракт в лоте SD.000063	 												
 		,ssms.lot_customer_code 												-- Покупатель в лоте (код) SD.000064
		,ssms.uni			
 		,ssms.forwarder_name			--2025.07.23 добавила: раскомментила
 		,ssms.bill_of_lading_number		--2025.07.23 добавила: раскомментила	 		
		,ssms.pb1_number				--2025.07.23 добавила
		,ssms.pb2_number				--2025.07.23 добавила
		,ssms.pb3_number				--2025.07.23 добавила
		,ssms.pb1_warehouse_name		--2025.07.23 добавила
		,ssms.pb2_warehouse_name		--2025.07.23 добавила
		,ssms.pb3_warehouse_name		--2025.07.23 добавила
		,ssms.dt_pb1_number				--2025.07.23 добавила
		,ssms.dt_pb2_number				--2025.07.23 добавила
		,ssms.dt_pb3_number				--2025.07.23 добавила
		,ssms2.forwarder_in_foreign_port_name									-- Экспедитор в иностранном порту SD.000609
		,ssms.port_of_discharge_in_foreign_port_code							-- Порт выгрузки 2 (код) SD.000054
		,ssms.sales_order_in_shipment 											-- Заказ ЦК в отгрузке SD.000005
		,ssms.dt_final_release 													-- Дата Финальный релиз SD.000482
		,ssms.final_release_code												-- Номер Финальный релиз SD.000588
		,ssms2.final_release_internal_code										-- Группа Финальный релиз SD.000952
		,ssms.delivery_basis 													-- Базис поставки SD.000067
		,ssms.delivery_point_name 												-- Пункт доставки по инкотермс SD.000068 
		,ssms.pb_number 														-- LotWshe/PB number SD.000158
		,ssms.russian_port_bill_of_lading_forwarder_code 						-- EXP: WH Operator's code SD.000632
		,ssms.receiving_plant_in_sap_system_name as owner_plant_name			-- Завод собственник SD.000655
		,ssms2.forwarder_in_foreign_port_code									-- Экспедитор в иностранном порту (код) SD.000950
		,ssms2.bill_of_lading_created_by_name									-- Создатель коносамента в ин. Порту SD.000951
		,ssms.dt_shipment 														-- Дата отгрузки SD.000010
		,ssms.foreign_port_of_discharge_location_code 							-- Иностранный порт (код локации) SD.000494	
		,ssms.second_shipping_instruction_code									-- Группа инструкции на отгрузку Ин Порт 2 SD.000584
		,sdt18_3.dt_shipment_instruction as dt_shipment_instruction_in_foreign_port	   			-- Дата инструкции на отгрузку Ин Порт SD.000613
		,sdt18_4.dt_shipment_instruction as dt_shipment_instruction_in_second_foreign_port  	-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
		,sdt18_3.shipment_instruction_number as shipment_instruction_in_foreign_port_name		-- Инструкция на отгрузку Ин Порт SD.000612
		,sdt18_4.shipment_instruction_number as shipment_instruction_in_second_foreign_port_name-- Инструкция на отгрузку Ин Порт 2 SD.000618
		,ssms.plant_producer_name 												-- Завод SD.000007
		,ssms.plant_owner_code 													-- Завод собственник (код) SD.000099
		,ssms.sales_order 														-- Заказ ЦК SD.000123
		,ssms.dt_delivery_notice 												-- Дата нотиса о доставке SD.000132
		,ssms.delivery_notice_number											-- Номер нотиса о доставке SD.000133
		,ssms.pledge_in_bank_name 												-- Pledge Bank SD.000172
		,ssms.material_shape_name_full											-- Форма SD.000180
		,ssms.incoterms_plan_code												-- Плановый базис поставки 1 SD.000255
		,ssms.uzbekistan_cargo_declaration_73									-- EXP: ГТД ИМ73 SD.000634
		,ssms.port_of_loading_name												-- Порт погрузки SD.000653
		,ssms.delivery_number_of_producer_plant									-- Номер поставки завода производителя SD.000003
		,ssms.tsw_location_name 												-- 
		,ssms.dt_arrival_by_railway												-- Дата прибытия по ЖД SD.000011
		,ssms.dt_forwarder														-- Дата экспедитора SD.000012
		,ssms.dt_warehouse														-- Дата склада SD.000024
		,ssms.transport_type_after_repackaging_code								-- Тип ПС после перетарки SD.000027
		,ssms.transport_railcar_type_code										-- Тип вагона (код) SD.000028
		,ssms.transport_railcar_type_name										-- Тип вагона SD.000029
		,ssms.dt_bill_of_lading													-- Дата коносамента SD.000042
		,ssms.delivery_region_name												-- Регион поставки по контракту SD.000338
		,ssms.port_of_loading_code 												-- Порт погрузки (код) SD.000649
		,ssms.bill_of_lading_group_code 										-- Группа коносамента SD.000040
		,row_number() over (partition by sd4798.sales_bundle_code order by source_system_position_code desc) as rn --2025.09.29: нужно для отбора последней поставки из ОД
	from dm_calc.sd_sales_main_scm ssms 
	join dds.sales_bundle_and_delivery_relationship sd4798 
	  on ssms.delivery_number_sales = sd4798.delivery_code
	  and sd4798.is_deleted_code is null
	  and sd4798.transportation_stage_code is null
	join dm_calc.sales_delivery_actual_part_2 as ssms2
	  on ssms2.delivery_number_sales = ssms.delivery_number_sales
	  and ssms2.batch = ssms.batch
	left join sdt18	as sdt18_3
  	  on sdt18_3.delivery_code = ssms.delivery_number_sales
  	  and sdt18_3.location_of_port_of_discharge_code = ssms.foreign_port_of_discharge_location_code
  	  and rn = 1
  	left join sdt18	as sdt18_4
  	  on sdt18_4.delivery_code = ssms.delivery_number_sales
  	  and sdt18_4.shipment_instruction_code = ssms.second_shipping_instruction_code
	where ssms2.is_final_delivery_in_sales_chain_code = 'X' --признак посл. продажи		
)
distributed by (sales_bundle_code);

drop table if exists fwpd;
create temp table fwpd as (
	select
		transport_hub_code
		,is_terminal_code
		,is_foreign_warehouse_code
		,is_temporary_warehouse_code
		,is_russian_port_code
		,market_region1_code
	from dict_dds.foreign_warehouse_priority_definition
	/*where (is_terminal_code = 'X' 					--ZSD2973M_LGORT-SIGN_TERMINAL
			or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
			or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW*/
	group by 
		transport_hub_code
		,is_terminal_code
		,is_foreign_warehouse_code
		,is_temporary_warehouse_code
		,is_russian_port_code
		,market_region1_code
)
distributed by (transport_hub_code);			
drop table if exists t5;

create temp table t5 as (
--,t5 as 
	select --distinct
		vbln.delivery_number_sales --vbeln
		,vbln.batch as batch_code --charg
		,t4.sales_bundle_code --id_him
		,t4.knote
		,t4.dt_transportation_stage_start_p /*lddat_p*/
		,t4.dt_transportation_stage_start_r /*lddat_r*/
		,t4.delivery_code_le_r					
		,t4.delivery_code_le_p					
		,t4.transportation_stage_code											-- Этап перевозки SD.000529		УДАЛИТЬ! 
		,t4.is_final_transportation_stage_code	
		,t4.transportation_stage_code_r											-- Этап расхода (код) SD.001043	УДАЛИТЬ! 
		,t4.transportation_inbound_stage_code									-- Код этапа прихода SD.000529
		,t4.transportation_outbound_stage_code									-- Код этапа расхода SD.001043
		,t4.dt_created_r
		,vbln.delivery_number_initial											-- Исходная поставка SD.000001
		,vbln.port_of_discharge_code											-- Порт выгрузки (код) SD.000044
		,vbln.port_of_discharge_name											-- Порт выгрузки SD.000045
 		,vbln.bill_of_lading_in_foreign_port									-- Коносамент в ин.порту SD.000048
 		,vbln.external_contract_in_lot_number 									-- Контракт в лоте SD.000063	 												
 		,vbln.lot_customer_code 												-- Покупатель в лоте (код) SD.000064
		,vbln.uni			
 		,vbln.forwarder_name			--2025.07.23 добавила: раскомментила
 		,vbln.bill_of_lading_number		--2025.07.23 добавила: раскомментила	 		
		,vbln.pb1_number				--2025.07.23 добавила
		,vbln.pb2_number				--2025.07.23 добавила
		,vbln.pb3_number				--2025.07.23 добавила
		,vbln.pb1_warehouse_name		--2025.07.23 добавила
		,vbln.pb2_warehouse_name		--2025.07.23 добавила
		,vbln.pb3_warehouse_name		--2025.07.23 добавила
		,vbln.dt_pb1_number				--2025.07.23 добавила
		,vbln.dt_pb2_number				--2025.07.23 добавила
		,vbln.dt_pb3_number				--2025.07.23 добавила
		,vbln.port_of_discharge_in_foreign_port_code							-- Порт выгрузки 2 (код) SD.000054
		,vbln.sales_order_in_shipment 											-- Заказ ЦК в отгрузке SD.000005
		,vbln.dt_final_release 													-- Дата Финальный релиз SD.000482
		,vbln.final_release_code 												-- Номер Финальный релиз SD.000588
		,vbln.final_release_internal_code 										-- Группа Финальный релиз SD.000952
		,vbln.delivery_basis 													-- Базис поставки SD.000067
		,vbln.delivery_point_name 												-- Пункт доставки по инкотермс SD.000068 
		,vbln.pb_number 														-- LotWshe/PB number SD.000158
		,vbln.russian_port_bill_of_lading_forwarder_code 						-- EXP: WH Operator's code SD.000632
		,vbln.owner_plant_name 													-- Завод собственник SD.000655
		,vbln.forwarder_in_foreign_port_code									-- Экспедитор в иностранном порту (код) SD.000950
		,vbln.bill_of_lading_created_by_name									-- Создатель коносамента в ин. Порту SD.000951
		,vbln.dt_shipment 														-- Дата отгрузки SD.000010
		,vbln.foreign_port_of_discharge_location_code 							-- Иностранный порт (код локации) SD.000494
		,vbln.dt_shipment_instruction_in_foreign_port	   						-- Дата инструкции на отгрузку Ин Порт SD.000613
		,vbln.dt_shipment_instruction_in_second_foreign_port  					-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
		,vbln.shipment_instruction_in_foreign_port_name							-- Инструкция на отгрузку Ин Порт SD.000612
		,vbln.shipment_instruction_in_second_foreign_port_name					-- Инструкция на отгрузку Ин Порт 2 SD.000618
		,vbln.plant_producer_name 												-- Завод SD.000007
		,vbln.plant_owner_code 													-- Завод собственник (код) SD.000099
		,vbln.sales_order 														-- Заказ ЦК SD.000123
		,vbln.dt_delivery_notice 												-- Дата нотиса о доставке SD.000132
		,vbln.delivery_notice_number											-- Номер нотиса о доставке SD.000133
		,vbln.pledge_in_bank_name 												-- Pledge Bank SD.000172
		,vbln.material_shape_name_full											-- Форма SD.000180
		,vbln.incoterms_plan_code												-- Плановый базис поставки 1 SD.000255
		,vbln.uzbekistan_cargo_declaration_73									-- EXP: ГТД ИМ73 SD.000634
		,vbln.port_of_loading_name												-- Порт погрузки SD.000653
		,vbln.delivery_number_of_producer_plant									-- Номер поставки завода производителя SD.000003
		,vbln.tsw_location_name 												-- 
		,vbln.dt_arrival_by_railway												-- Дата прибытия по ЖД SD.000011
		,vbln.dt_forwarder														-- Дата экспедитора SD.000012
		,vbln.dt_warehouse														-- Дата склада SD.000024
		,vbln.transport_type_after_repackaging_code								-- Тип ПС после перетарки SD.000027
		,vbln.transport_railcar_type_code										-- Тип вагона (код) SD.000028
		,vbln.transport_railcar_type_name										-- Тип вагона SD.000029
		,vbln.dt_bill_of_lading													-- Дата коносамента SD.000042
		,vbln.delivery_region_name												-- Регион поставки по контракту SD.000338
		,vbln.port_of_loading_code 												-- Порт погрузки (код) SD.000649
		,vbln.bill_of_lading_group_code 										-- Группа коносамента SD.000040
		,fwpd.is_terminal_code
		,fwpd.is_foreign_warehouse_code
		,fwpd.is_temporary_warehouse_code
		,fwpd.is_russian_port_code	
		,fwpd.market_region1_code
		,fwpd.transport_hub_code
	from dm_calc.sales_bundle_transport_hub_turnover_sdt0004 as t4
	left join vbln 
	  on t4.sales_bundle_code = vbln.sales_bundle_code
	  and rn = 1
	left join fwpd
	  on t4.knote = fwpd.transport_hub_code
	/*where t4.knote in (select distinct fwpd.transport_hub_code
						from dict_dds.foreign_warehouse_priority_definition as fwpd /*dev: 225 || prod: 236*/
						where (fwpd.is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
						   or fwpd.is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
						   or fwpd.is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
					   )*/				
) --4 699 163
distributed by (sales_bundle_code, delivery_code_le_r, delivery_code_le_p, knote);

drop table if exists vbss_vbsk;
create temp table vbss_vbsk as (
--,vbss_vbsk as (
	select --distinct --исключаем моменты, когда на 1 поставку есть несколько sammg с одинаковыми датами
		 vbss.delivery_code 
		,vbsk.dt_end_of_free_storage --VBSK.zzendfreedate
		,row_number() over(partition by vbss.delivery_code order by vbsk.dt_created desc) as rn
	from dds."release" as vbsk 		 
	  join dds.logistics_document_and_delivery_relationship as vbss --Документы сбыта групповой обработки									--  отсекли поставки, sammg которых нет в vbsk
		on vbsk.release_code /*sammg*/ = vbss.logistics_document_code  
	  join dict_dds.settings_and_parameters_sap as frel_kod 			
		on vbsk.release_template_code = frel_kod.range_low_value 
		and frel_kod.abap_program_code = '/RUSAL/SD2921M' 
	 	and frel_kod.parameter_code = 'FREL_KOD' 
	  	and frel_kod.range_sign_code = 'I' 
	  	and frel_kod.range_option_code = 'EQ'
	 where vbsk.release_type_code = 'X' --VBSK.smart
)--2025.07.24: dev: 657 664 || prod: 661 216 - OK
distributed by (delivery_code, dt_end_of_free_storage);

drop table if exists uzb;
create temp table uzb as (
--,uzb as (
	select
		uzb.ident
		,uzb.num_mh1
		,uzb.num_mh3
		,uzb.notification
		,uzb.locid
		,uzb.sammg_n
		,uzb.traid_out
		,uzb.charg
		,ls.transport_hub_code
		,ls.location_name
	from ods.ztsd5018m_uz_b_ral as uzb 
	  join dict_dds.location_sales as ls
	    on ls.location_code = uzb.locid
)
distributed by (ident, charg);

drop table if exists eub;
create temp table eub as (
--,eub as (
	select
		eub.ident
		,eub.ship_unload_date
		,eub.locid
		,eub.notification
		,eub.sammg_n
		,eub.dlv_note
		,eub.container_out
		,eub.capacity
		,eub.loc_name
		,eub.charg
		,ls.transport_hub_code
	from ods.ztsd5018m_eu_b_ral as eub 
	  join dict_dds.location_sales as ls
	    on ls.location_code = eub.locid
)
distributed by (ident, charg);

drop table if exists vbsk_y;
create temp table vbsk_y as (
--,vbsk_y as (
	select 
		bol.dt_discharge
		,bol.bill_of_lading_code 
		,lddr.delivery_code 
		,row_number() over(partition by lddr.delivery_code order by bol.dt_bill_of_lading) as rn
		,bol.nomination_code
	from dds.bill_of_lading as bol	  
	  join dds.logistics_document_and_delivery_relationship as lddr
	    on lddr.logistics_document_code = bol.bill_of_lading_code 
	where bol.bill_of_lading_type_code = 'Y'
)
distributed by (delivery_code);

drop table if exists outb;
create temp table outb as (
--,outb as (
	select 
		ls.transport_hub_code 
		,outb.vbeln 
		,outb.capacity 
		,outb.notification 
		,outb.sammg_n
		,row_number() over(partition by outb.vbeln, outb.loc_id  order by outb.vbeln_le_dlv) as rn
		,outb.charg 
	from ods.ztsd5018m_outb_b_ral as outb
	  join dict_dds.transport_hub_texts as tht
	    on tht.transport_hub_code = outb.loc_id 
	    and tht.language_code = 'E'
	  join dict_dds.location_sales as ls
	    on ls.location_code = tht.location_code 		  
)
distributed by (vbeln, rn);

drop table if exists lgort;
create temp table lgort as (
--,lgort as (
	select
		sales_bundle_code
		,knote
		,dt_transportation_stage_start_p
		,dt_transportation_stage_start_r		
		,row_number() over(partition by sales_bundle_code order by dt_transportation_stage_start_p asc, dt_transportation_stage_start_r asc) as rn
	from t5
	where 
		is_foreign_warehouse_code is not null
)
distributed by (sales_bundle_code, knote);

drop table if exists vbsk_o;
create temp table vbsk_o as (
--,vbsk_o as (
	select
		vbss.delivery_code
		,vbsk.pledge_reserve_contract_code
		,vbsk.pledge_reserve_bank_code
		,vbsk.pledge_reserve_code
	from dds.pledge_reserve as vbsk											
	  join dds.logistics_document_and_delivery_relationship as vbss
		on vbss.logistics_document_code = vbsk.pledge_reserve_code
	where 
		vbsk.pledge_reserve_type_code = 'Щ'
)
distributed by (delivery_code);

drop table if exists s_zrepo;
create temp table s_zrepo as (
--,s_zrepo as (
	select distinct range_low_value 											
	from dict_dds.settings_and_parameters_sap 
	where abap_program_code = '/RUSAL/SD2973M_3' 
	  		and parameter_code = 'S_ZREPO' 
	  		and range_low_value is not null
)
distributed by (range_low_value);

drop table if exists stat1;
	create temp table stat1 as (
	--,stat1 as (
		select scm_pledge_status_name 
		from dict_dds.scm_pledge_status_texts
		where scm_pledge_status_code = '1'
	)
distributed by (scm_pledge_status_name);

drop table if exists nomtk_s;
create temp table nomtk_s as (
	select range_low_value 											
	from dict_dds.settings_and_parameters_sap 
	where abap_program_code = '/RUSAL/SD3275M' 
	  		and parameter_code = 'NOMTK_S' 
	  		and range_low_value is not null
)
distributed by (range_low_value);

insert into dm.sales_material_turnover_detailed (
--insert into dm.sales_material_turnover_detailed_20251010 (
	 delivery_number_initial				/*SD.000001 | Исходная поставка*/
	,port_of_discharge_code					/*SD.000044 | Порт выгрузки (код)*/
	,port_of_discharge_name					/*SD.000045 | Порт выгрузки*/
	,bill_of_lading_in_foreign_port			/*SD.000048 | Коносамент в ин.порту*/
	,dt_storage_start						/*SD.000418 | Дата начала хранения ин. склад*/
	,dt_storage_end							/*SD.000419 | Дата окончания хранения ин. склад*/
	,warehouse_code							/*SD.000420 | Удаленный склад (код)*/
	,warehouse_name 						/*SD.000421 | Удаленный склад*/
	,country_of_remote_warehouse_name		/*SD.000423 | Страна удаленного склада*/
	,sales_bundle_code						/*SD.000511 | ID химии*/
	,dt_storage_end_in_release				/*SD.000546 | Дата окончания хранения на складе за счет RUSAL*/
	,sales_delivery_code					/*SD.000548 | Поставка*/
	,receiving_plant_code					/*SD.000549 | Принимающий завод*/
	,forwarder_in_foreign_port_name			/*SD.000609 | Экспедитор в иностранном порту*/
	,sales_bundle_gross_weight				/*SD.000722 | Вес брутто пакета | Вес брутто металла для одного пакета, в тоннах*/
	,sales_bundle_net_weight				/*SD.000723 | Вес нетто пакета | Вес нетто металла для одного пакета, в тоннах*/
	,sales_bundle_net_weight_with_wirerod	/*SD.000724 | Вес Н&К пакета | Вес нетто + катанка металла для одного пакета, в тоннах*/
	,country_of_remote_warehouse_code		/*SD.000725 | Страна удаленного склада (код)*/
	,region_of_remote_warehouse_code		/*SD.000726 | Регион удаленного склада (код) | Код региона удаленного склада*/
	,region_of_remote_warehouse_name		/*SD.000727 | Регион удаленного склада | Регион удаленного склада*/
	,location_of_remote_warehouse_name		/*SD.000728 | Локация удаленного склада | Наименование локации/города, где находится склад*/
	,batch_code								/*SD.000737 | Партия*/
	,uni									/*SD.000151 | UNI*/
 	,metal_owner_for_reporting_name			/*SD.000544 | Собственник*/
 	,forwarder_name						-- Экспедитор SD.000021				--2025.05.28 добавила
 	,bill_of_lading_number				-- Номер коносамента SD.000041		--2025.05.28 добавила
/*2025.07.23 новые поля из ОД*/ 	
	,pb1_number							-- Номер PB 1 SD.000592				--2025.07.23 добавила
	,pb2_number							-- Номер PB 2 SD.000593				--2025.07.23 добавила
	,pb3_number							-- Номер PB 3 SD.000594				--2025.07.23 добавила
	,pb1_warehouse_name					-- Склад PB 1 SD.000595				--2025.07.23 добавила
	,pb2_warehouse_name					-- Склад PB 2 SD.000596				--2025.07.23 добавила
	,pb3_warehouse_name					-- Склад PB 3 SD.000597				--2025.07.23 добавила
	,dt_pb1_number						-- Дата PB 1 SD.000751				--2025.07.23 добавила
	,dt_pb2_number						-- Дата PB 2 SD.000752				--2025.07.23 добавила
	,dt_pb3_number						-- Дата PB 3 SD.000753				--2025.07.23 добавила
	,dt_shipment_from_foreign_warehouse -- SD.000547 | Дата ухода со склада
	,delivery_code_le_p																	-- LE поставка прихода SD.000513				
    ,delivery_code_le_r																	-- LE поставка расхода SD.000516				
    ,barcode_ean_code 																	-- Штриховой код SD.000929						
    ,fwrd_info_mh1_storage_document_number												-- EXP: № Акта МХ-1	SD.000930					
    ,fwrd_info_mh3_storage_document_number												-- EXP: № Акта МХ-3	SD.000931						
    ,dt_fwrd_info_discharge_in_foreign_port												-- EXP: Дата выгрузки в порту SD.000932			
    ,dt_fwrd_info_storage_start_in_foreign_port											-- EXP: Начало хранения ин. склад 1 SD.000933
    ,dt_fwrd_info_storage_end_in_foreign_port											-- EXP: Окончание хранение ин. склад 1 SD.000934 
    ,fwrd_info_shipment_instruction_number 												-- EXP: Инструкция на отгрузку Ин Порт SD.000935		
	,fwrd_info_shipment_instruction_code												-- EXP: Группа инструкции на отгрузку Ин Порт SD.000936 
	,fwrd_info_transport_bill_external_number											-- EXP: Номер накладной SD.000937     			
	,fwrd_info_delivery_notice_number													-- EXP: Номер нотиса о доставке	SD.000938		
	,fwrd_info_transport_vehicle_in_foreign_port_code 									-- EXP: Номер ТС в ин. Порту SD.000939 			
	,fwrd_info_transport_capacity_amount												-- EXP: Грузоподъемность SD.000940
	,fwrd_info_second_foreign_warehouse_location_name									-- EXP: Storage location 2 SD.000941 				
	,dt_fwrd_info_storage_start_in_second_foreign_warehouse								-- EXP: Начало хранения ин. склад 2 SD.000942
	,dt_fwrd_info_storage_end_in_second_foreign_warehouse								-- EXP: Окончание хранение ин. склад 2 SD.000943
	,fwrd_info_shipment_instruction_in_second_foreign_port_number						-- EXP: Инструкция на отгрузку Ин Порт 2 SD.000944  УДАЛИТЬ! 
	,fwrd_info_shipment_instruction_in_2nd_foreign_port_number							-- EXP: Инструкция на отгрузку Ин Порт 2 SD.000944
	,fwrd_info_shipment_instruction_in_second_foreign_port_code							-- EXP: Группа инструкции на отгрузку Ин Порт 2 SD.000945  УДАЛИТЬ!
	,fwrd_info_shipment_instruction_in_2nd_foreign_port_code							-- EXP: Группа инструкции на отгрузку Ин Порт 2 SD.000945
	,pledge_contract_external_number													-- Номер контракта Pledge reserve SD.000946	
	,final_pledge_in_bank_code															-- Банк Pledge reserve (код) SD.000947
	,final_pledge_in_bank_name															-- Название Банка Pledge reserve SD.000948
	,scm_pledge_status_name																-- Признак ЦП SD.000949				
	,transportation_stage35_delivery_code												-- LE поставка Этап 35 SD.000953	  			
	,transportation_stage40_delivery_code												-- LE поставка Этап 40 SD.000954	  			
	,transportation_stage42_delivery_code												-- LE поставка Этап 42 SD.000955	  			
	,transportation_stage55_delivery_code												-- LE поставка Этап 55 SD.000956	  			
	,transportation_stage60_delivery_code												-- LE поставка Этап 60 SD.000957	  			
	,transportation_stage_final_delivery_code											-- LE поставка последней операции SD.000958
	,sales_order_in_shipment 															-- Заказ ЦК в отгрузке SD.000005
	,dt_final_release 																	-- Дата Финальный релиз SD.000482
	,final_release_code 																-- Номер Финальный релиз SD.000588
	,dt_shipment_instruction_in_foreign_port											-- Дата инструкции на отгрузку Ин Порт SD.000613
	,dt_shipment_instruction_in_second_foreign_port										-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
	,final_release_internal_code 														-- Группа Финальный релиз SD.000952      
	,vehicle_in_transportation_delivery_code											-- Транспортное средство LE-поставки расхода SD.001042 
    ,forwarder_departure_transportation_stage_code /*transportation_stage_code*/		-- Этап расхода (код) SD.001043								УДАЛИТЬ!
	,transportation_stage_code /*2025-10-02 добавляю*/									-- Этап перевозки SD.000529									УДАЛИТЬ!
	,transportation_inbound_stage_code													-- Код этапа прихода SD.000529
	,transportation_outbound_stage_code													-- Код этапа расхода SD.001043
	,dt_transportation_delivery_created													-- Дата создания LE-поставки расхода SD.001044  
	,delivery_basis 																	-- Базис поставки SD.000067
	,delivery_point_name 																-- Пункт доставки по инкотермс SD.000068 
	,pb_number 																			-- LotWshe/PB number SD.000158
	,russian_port_bill_of_lading_forwarder_code 										-- EXP: WH Operator's code SD.000632 -- НА УДАЛЕНИЕ ПОСЛЕ ЗАМЕНЫ В SS
	,forwarder_storing_in_foreign_1st_warehouse_code									-- EXP: WH Operator's code SD.000632
	,owner_plant_name 																	-- Завод собственник SD.000655
	,forwarder_in_foreign_port_code														-- Экспедитор в иностранном порту (код) SD.000950
	,bill_of_lading_created_by_name														-- Создатель коносамента в ин. Порту SD.000951 
	,railway_train_number 																-- Номер поезда SD.000637
	,shipment_instruction_in_foreign_port_name											-- Инструкция на отгрузку Ин Порт SD.000612
	,shipment_instruction_in_second_foreign_port_name									-- Инструкция на отгрузку Ин Порт 2 SD.000618
	,dt_vehicle_loaded    																-- EXP: Load out date SD.000629
	,location_comment 																	-- EXP: Storage location SD.000630
	,plant_producer_name 																-- Завод SD.000007
	,plant_owner_code 																	-- Завод собственник (код) SD.000099
	,sales_order 																		-- Заказ ЦК SD.000123
	,dt_delivery_notice 																-- Дата нотиса о доставке SD.000132
	,delivery_notice_number																-- Номер нотиса о доставке SD.000133
	,pledge_in_bank_name 																-- Pledge Bank SD.000172
	,material_shape_name_full															-- Форма SD.000180
	,incoterms_plan_code																-- Плановый базис поставки 1 SD.000255
	,uzbekistan_cargo_declaration_73													-- EXP: ГТД ИМ73 SD.000634
	,port_of_loading_name																-- Порт погрузки SD.000653  
	,location_type_of_remote_warehouse_name												-- Признак (Ин.склад/СВХ/Терминал/Порт РФ) SD.001218
	,transportation_delivery_to_foreign_1st_warehouse_code								-- LE поставка хранения SD.000241
	,transportation_delivery_to_foreign_2nd_warehouse_code								-- LE поставка хранения 2 SD.001278
	,transportation_stage66_delivery_code												-- LE поставка Этап 66 SD.001273
	,transportation_stage77_delivery_code												-- LE поставка Этап 77 SD.001274
	,transportation_stage49_delivery_code												-- LE поставка Этап 49 SD.001275
	,forwarder_storing_in_foreign_2nd_warehouse_code									-- EXP: WH Operator's code 2 SD.000633
	,forwarder_delivering_to_foreign_1st_warehouse_code									-- EXP: Inb.carrier's code SD.001276
	,forwarder_delivering_to_foreign_2nd_warehouse_code									-- EXP: Inb.carrier's code 2 SD.001279
	,forwarder_delivering_to_foreign_1st_warehouse_name									-- EXP: Inb.carrier SD.001277
	,forwarder_delivering_to_foreign_2nd_warehouse_name									-- EXP: Inb.carrier 2 SD.001280
	,forwarder_storing_in_foreign_1st_warehouse_name									-- EXP: WH Operator's SD.001281
	,forwarder_storing_in_foreign_2nd_warehouse_name									-- EXP: WH Operator's 2 SD.001282
	,delivery_number_of_producer_plant													-- Номер поставки завода производителя SD.000003
	,tsw_location_name 																	-- 
	,dt_arrival_by_railway																-- Дата прибытия по ЖД SD.000011
	,dt_forwarder																		-- Дата экспедитора SD.000012
	,dt_warehouse																		-- Дата склада SD.000024
	,transport_type_after_repackaging_code												-- Тип ПС после перетарки SD.000027
	,transport_railcar_type_code														-- Тип вагона (код) SD.000028
	,transport_railcar_type_name														-- Тип вагона SD.000029
	,dt_bill_of_lading																	-- Дата коносамента SD.000042
	,delivery_region_name																-- Регион поставки по контракту SD.000338
	,dt_shipment																		-- Дата отгрузки SD.000010
	,port_of_loading_code 																-- Порт погрузки (код) SD.000649
)
	select
		t5.delivery_number_initial																-- Исходная поставка SD.000001					--2025.05.22 ДОБАВИТЬ: поле уже есть
		,t5.port_of_discharge_code																-- Порт выгрузки (код) SD.000044
		,t5.port_of_discharge_name 																-- Порт выгрузки SD.000045						--2025.05.22 ДОБАВИТЬ: поле уже есть
	 	,t5.bill_of_lading_in_foreign_port														-- Коносамент в ин.порту SD.000048				--2025.05.22 ДОБАВИТЬ: поле уже есть
	 	,t5.dt_transportation_stage_start_p as dt_storage_start									-- Дата начала хранения ин. склад SD.000418
	 	,t5.dt_transportation_stage_start_r as dt_storage_end									-- Дата окончания хранения ин. склад SD.000419
	 	,t5.knote as warehouse_code																-- Удаленный склад (код) SD.000420
	 	,tvknt.transport_hub_name as warehouse_name												-- Удаленный склад SD.000421
	 	,r_sd556t.country_full_name as country_of_remote_warehouse_name							-- Страна удаленного склада SD.000423
	 	,t5.sales_bundle_code																	-- ID химии SD.000511
	 	,vv.dt_end_of_free_storage as dt_storage_end_in_release									-- Дата окончания хранения на складе за счет RUSAL SD.000546
	 	,t5.delivery_number_sales as sales_delivery_code										-- Поставка SD.000548
	 	,lips.plant_producer_code as receiving_plant_code										-- Принимающий завод SD.000549
	 	,ctp2.counterparty_short_name as forwarder_in_foreign_port_name							-- Экспедитор в иностранном порту SD.000609	
	 	,r_ah.sales_bundle_gross_weight /1000 as sales_bundle_gross_weight 						-- Вес брутто пакета SD.000722
		,r_ah.sales_bundle_net_weight /1000 as sales_bundle_net_weight 							-- Вес нетто пакета SD.000723 
		,r_ah.sales_bundle_net_weight_with_wirerod /1000 as sales_bundle_net_weight_with_wirerod -- Вес Н&К пакета SD.000724
	 	,adrc1.country_code as country_of_remote_warehouse_code									-- Страна удаленного склада (код) SD.000725
	 	,r_sd556.market_region1_code as region_of_remote_warehouse_code							-- Регион удаленного склада (код) SD.000726
	 	,t25a1.market_region1_name as region_of_remote_warehouse_name							-- Регион удаленного склада SD.000727 
	 	,oijloc.location_name as location_of_remote_warehouse_name								-- Локация удаленного склада SD.000728			--2025.05.22 ДОБАВИТЬ: поле уже есть
	 	,t5.batch_code																			-- Партия SD.000737
		,t5.uni																					-- UNI SD.000151							--2025.05.28 добавила
 		,CASE WHEN lips.plant_producer_code IS NOT NULL THEN
		   (CASE
		     WHEN lips.plant_producer_code::text ~~ '%1575%'::text THEN 'RTC'::text
		     WHEN lips.plant_producer_code::text ~~ '%1576%'::text THEN 'RSET'::text
			 WHEN lips.plant_producer_code::text ~~ '%1511%'::text THEN 'RM'::text
			 WHEN lips.plant_producer_code::text ~~ '%1531%'::text THEN 'RM'::text
			 WHEN lips.plant_producer_code::text ~~ '%1515%'::text THEN 'AL+G'::text
			 WHEN lips.plant_producer_code::text ~~ '%1516%'::text THEN 'AL+T'::text
			 ELSE 'ИНОЕ'::text --ELSE NULL::text
		   END)
		   ELSE NULL::text --ELSE 'ИНОЕ'::text
		 END AS metal_owner_for_reporting_name													-- Собственник SD.000544						--2025.05.28 добавила
	 	,t5.forwarder_name																		-- Экспедитор SD.000021							--2025.05.28 добавила
	 	,t5.bill_of_lading_number																-- Номер коносамента SD.000041					--2025.05.28 добавила
		,t5.pb1_number																			-- Номер PB 1 SD.000592							--2025.07.23 добавила
		,t5.pb2_number																			-- Номер PB 2 SD.000593							--2025.07.23 добавила
		,t5.pb3_number																			-- Номер PB 3 SD.000594							--2025.07.23 добавила
		,t5.pb1_warehouse_name																	-- Склад PB 1 SD.000595							--2025.07.23 добавила
		,t5.pb2_warehouse_name																	-- Склад PB 2 SD.000596							--2025.07.23 добавила
		,t5.pb3_warehouse_name																	-- Склад PB 3 SD.000597							--2025.07.23 добавила
		,t5.dt_pb1_number																		-- Дата PB 1 SD.000751							--2025.07.23 добавила
		,t5.dt_pb2_number																		-- Дата PB 2 SD.000752							--2025.07.23 добавила
		,t5.dt_pb3_number																		-- Дата PB 3 SD.000753							--2025.07.23 добавила	
		,CASE
		   WHEN t5.dt_transportation_stage_start_r IS NOT NULL AND vv.dt_end_of_free_storage IS NOT NULL THEN
			   CASE
				 WHEN t5.dt_transportation_stage_start_r < vv.dt_end_of_free_storage OR vv.dt_end_of_free_storage < t5.dt_transportation_stage_start_p THEN t5.dt_transportation_stage_start_r
				 WHEN vv.dt_end_of_free_storage >= t5.dt_transportation_stage_start_p THEN vv.dt_end_of_free_storage
                 ELSE NULL
                END
               ELSE CASE
				 WHEN t5.dt_transportation_stage_start_r IS NOT NULL THEN t5.dt_transportation_stage_start_r
				 WHEN vv.dt_end_of_free_storage IS NOT NULL AND vv.dt_end_of_free_storage >= t5.dt_transportation_stage_start_p THEN vv.dt_end_of_free_storage
				 ELSE NULL
				END
          END AS dt_shipment_from_foreign_warehouse -- SD.000547 | Дата ухода со склада												 
         ,t5.delivery_code_le_p																													-- LE поставка прихода SD.000513				
         ,t5.delivery_code_le_r																													-- LE поставка расхода SD.000516				
         ,r_ah.barcode_ean_code 																												-- Штриховой код SD.000929						
         ,coalesce(uzb1.num_mh1, ddh3.mh1_storage_document_number) as fwrd_info_mh1_storage_document_number										-- EXP: № Акта МХ-1	SD.000930		
		 ,coalesce(uzb1.num_mh3, ddh3.mh3_storage_document_number) as fwrd_info_mh3_storage_document_number										-- EXP: № Акта МХ-3	SD.000931							
		 ,coalesce(sd4798_35.dt_transportation_stage_start, vbsk_y.dt_discharge) as dt_fwrd_info_discharge_in_foreign_port						-- EXP: Дата выгрузки в порту SD.000932		
		 ,lgort_min.dt_transportation_stage_start_p as dt_fwrd_info_storage_start_in_foreign_port												-- EXP: Начало хранения ин. склад 1 SD.000933
         ,lgort_min.dt_transportation_stage_start_r as dt_fwrd_info_storage_end_in_foreign_port													-- EXP: Окончание хранение ин. склад 1 SD.000934         
		 ,coalesce(eub1.notification, uzb1.notification, sdt18_1.shipment_instruction_number) as fwrd_info_shipment_instruction_number 			-- EXP: Инструкция на отгрузку Ин Порт SD.000935		
		 ,coalesce(eub1.sammg_n, uzb1.sammg_n, sdt18_1.shipment_instruction_code) as fwrd_info_shipment_instruction_code						-- EXP: Группа инструкции на отгрузку Ин Порт SD.000936 
		 ,ddh.transport_bill_code as fwrd_info_transport_bill_external_number																	-- EXP: Номер накладной SD.000937     			
		 ,eub1.dlv_note as fwrd_info_delivery_notice_number																						-- EXP: Номер нотиса о доставке	SD.000938		
		 ,coalesce(eub1.container_out, uzb1.traid_out, ddh3.vehicle_in_foreign_port_code) as fwrd_info_transport_vehicle_in_foreign_port_code 	-- EXP: Номер ТС в ин. Порту SD.000939 	
		 ,coalesce(eub1.capacity, outb1.capacity) as fwrd_info_transport_capacity_amount														-- EXP: Грузоподъемность SD.000940				
		 ,coalesce(eub2.loc_name, uzb2.location_name) as fwrd_info_second_foreign_warehouse_location_name										-- EXP: Storage location 2 SD.000941 
		 ,lgort_max.dt_transportation_stage_start_p as dt_fwrd_info_storage_start_in_second_foreign_warehouse									-- EXP: Начало хранения ин. склад 2 SD.000942
		 ,lgort_max.dt_transportation_stage_start_r as dt_fwrd_info_storage_end_in_second_foreign_warehouse										-- EXP: Окончание хранение ин. склад 2 SD.000943
		 ,coalesce(eub2.notification, outb2.notification, sdt18_2.shipment_instruction_number) as fwrd_info_shipment_instruction_in_second_foreign_port_number	-- EXP: Инструкция на отгрузку Ин Порт 2 SD.000944   УДАЛИТЬ! 
		 ,coalesce(eub2.notification, outb2.notification, sdt18_2.shipment_instruction_number) as fwrd_info_shipment_instruction_in_2nd_foreign_port_number		-- EXP: Инструкция на отгрузку Ин Порт 2 SD.000944
		 ,coalesce(eub2.sammg_n, outb2.sammg_n, sdt18_2.shipment_instruction_code) as fwrd_info_shipment_instruction_in_second_foreign_port_code-- EXP: Группа инструкции на отгрузку Ин Порт 2 SD.000945	УДАЛИТЬ! 	
		 ,coalesce(eub2.sammg_n, outb2.sammg_n, sdt18_2.shipment_instruction_code) as fwrd_info_shipment_instruction_in_2nd_foreign_port_code	-- EXP: Группа инструкции на отгрузку Ин Порт 2 SD.000945	 
		 ,sch.sales_order_external_number as pledge_contract_external_number																	-- Номер контракта Pledge reserve SD.000946
		 ,vbsk_sh.pledge_reserve_bank_code as final_pledge_in_bank_code --нет данных															-- Банк Pledge reserve (код) SD.000947
		 ,ctp.counterparty_full_name as final_pledge_in_bank_name																				-- Название Банка Pledge reserve SD.000948
		 ,case 
		 	when sch.sales_contract_type_code =  (select range_low_value from s_zrepo) --'ZREP'
		  		then (select scm_pledge_status_name from stat1) --'Хранение за счет RM'
		  	else 
		  		case 
		  			when zmsr.contract_name like t5.external_contract_in_lot_number || '%'
		  				then pst.scm_pledge_status_name
		  		 end		  	
		 end as scm_pledge_status_name																											-- Признак ЦП SD.000949		 
		,sd4798_35.delivery_code as transportation_stage35_delivery_code																		-- LE поставка Этап 35 SD.000953	  			
		,sd4798_40.delivery_code as transportation_stage40_delivery_code																		-- LE поставка Этап 40 SD.000954			   
        ,sd4798_42.delivery_code as transportation_stage42_delivery_code																		-- LE поставка Этап 42 SD.000955			    
        ,sd4798_55.delivery_code as transportation_stage55_delivery_code																		-- LE поставка Этап 55 SD.000956	  			
        ,sd4798_60.delivery_code as transportation_stage60_delivery_code																		-- LE поставка Этап 60 SD.000957 	  				   
		,sd4798_x.delivery_code as transportation_stage_final_delivery_code																		-- LE поставка последней операции SD.000958
        ,t5.sales_order_in_shipment 																											-- Заказ ЦК в отгрузке SD.000005
		,t5.dt_final_release 																													-- Дата Финальный релиз SD.000482
		,t5.final_release_code 																													-- Номер Финальный релиз SD.000588
		,t5.dt_shipment_instruction_in_foreign_port																								-- Дата инструкции на отгрузку Ин Порт SD.000613
		,t5.dt_shipment_instruction_in_second_foreign_port																						-- Дата инструкции на отгрузку Ин Порт 2 SD.000619
		,t5.final_release_internal_code																											-- Группа Финальный релиз SD.000952  
        ,ddh.vehicle_code as vehicle_in_transportation_delivery_code																			-- Транспортное средство LE-поставки расхода SD.001042 
        ,t5.transportation_stage_code_r as forwarder_departure_transportation_stage_code /*transportation_stage_code*/							-- Этап расхода (код) SD.001043			УДАЛИТЬ!
		,t5.transportation_stage_code as transportation_stage_code /*2025-10-02 добавляю*/														-- Этап перевозки SD.000529				УДАЛИТЬ!
		,t5.transportation_inbound_stage_code																									-- Код этапа прихода SD.000529
		,t5.transportation_outbound_stage_code																									-- Код этапа расхода SD.001043
        ,t5.dt_created_r as dt_transportation_delivery_created																					-- Дата создания LE-поставки расхода SD.001044    
      	,t5.delivery_basis 																														-- Базис поставки SD.000067
		,t5.delivery_point_name 																												-- Пункт доставки по инкотермс SD.000068 
		,t5.pb_number 																															-- LotWshe/PB number SD.000158
		,t5.russian_port_bill_of_lading_forwarder_code 																							-- EXP: WH Operator's code SD.000632  -- НА УДАЛЕНИЕ ПОСЛЕ ЗАМЕНЫ В SS
		,sdcr.supplier_code as forwarder_storing_in_foreign_1st_warehouse_code																	-- EXP: WH Operator's code SD.000632
		,t5.owner_plant_name 																													-- Завод собственник SD.000655
		,t5.forwarder_in_foreign_port_code																										-- Экспедитор в иностранном порту (код) SD.000950		
		,t5.bill_of_lading_created_by_name																										-- Создатель коносамента в ин. Порту SD.000951 
		,case 
			when vbsk_y_smg.nomination_code in (select range_low_value from nomtk_s)
				then concat_ws('-', t5.sales_order_in_shipment, to_char(t5.dt_shipment, 'DD.MM.YYYY'))
			else t5.bill_of_lading_number
		end as railway_train_number 																											-- Номер поезда SD.000637 
		,t5.shipment_instruction_in_foreign_port_name																							-- Инструкция на отгрузку Ин Порт SD.000612
		,t5.shipment_instruction_in_second_foreign_port_name																					-- Инструкция на отгрузку Ин Порт 2 SD.000618 
		,ddh3.dt_vehicle_loaded    																												-- EXP: Load out date SD.000629
		,ddh3.location_comment 																													-- EXP: Storage location SD.000630
		,t5.plant_producer_name 																												-- Завод SD.000007
		,t5.plant_owner_code 																													-- Завод собственник (код) SD.000099
		,t5.sales_order 																														-- Заказ ЦК SD.000123
		,t5.dt_delivery_notice 																													-- Дата нотиса о доставке SD.000132
		,t5.delivery_notice_number																												-- Номер нотиса о доставке SD.000133
		,t5.pledge_in_bank_name 																												-- Pledge Bank SD.000172
		,t5.material_shape_name_full																											-- Форма SD.000180
		,t5.incoterms_plan_code																													-- Плановый базис поставки 1 SD.000255
		,t5.uzbekistan_cargo_declaration_73																										-- EXP: ГТД ИМ73 SD.000634
		,t5.port_of_loading_name																												-- Порт погрузки SD.000653
		,case 
			when t5.is_foreign_warehouse_code = 'X'
			  then 'Ин.склад'
			when t5.is_temporary_warehouse_code = 'X'
			  then 'СВХ'
			when t5.is_terminal_code = 'X'
			  then 'Терминал'
			when t5.is_russian_port_code = 'X'
			  then 'Порт РФ'
		end as location_type_of_remote_warehouse_name																							-- Признак (Ин.склад/СВХ/Терминал/Порт РФ) SD.001218
		,case 
			when t5.market_region1_code = '03'
					and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
						or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
						or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
				then sd4798_w03.delivery_code
			when t5.market_region1_code = '04'
					and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
						or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
						or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
				then sd4798_w04.delivery_code																									
		end as transportation_delivery_to_foreign_1st_warehouse_code																			-- LE поставка хранения SD.000241
		,case 
			when t5.market_region1_code = '03'
					and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
						or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
						or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
				then sd4798_w03_2.delivery_code
			when t5.market_region1_code = '04'
					and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
						or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
						or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
				then sd4798_w04_2.delivery_code																									
		end as transportation_delivery_to_foreign_2nd_warehouse_code																			-- LE поставка хранения 2 SD.001278
		,sd4798_66.delivery_code as transportation_stage66_delivery_code																		-- LE поставка Этап 66 SD.001273
		,sd4798_77.delivery_code as transportation_stage77_delivery_code																		-- LE поставка Этап 77 SD.001274
		,sd4798_49.delivery_code as transportation_stage49_delivery_code																		-- LE поставка Этап 49 SD.001275
		,sdcr_2.supplier_code as forwarder_storing_in_foreign_2nd_warehouse_code																-- EXP: WH Operator's code 2 SD.000633
		,sdcr_3.supplier_code as forwarder_delivering_to_foreign_1st_warehouse_code																-- EXP: Inb.carrier's code SD.001276
		,sdcr_4.supplier_code as forwarder_delivering_to_foreign_2nd_warehouse_code																-- EXP: Inb.carrier's code 2 SD.001279
		,ctp3.counterparty_short_name as forwarder_delivering_to_foreign_1st_warehouse_name														-- EXP: Inb.carrier SD.001277
		,ctp4.counterparty_short_name as forwarder_delivering_to_foreign_2nd_warehouse_name														-- EXP: Inb.carrier 2 SD.001280
		,ctp5.counterparty_short_name as forwarder_storing_in_foreign_1st_warehouse_name														-- EXP: WH Operator's SD.001281
		,ctp6.counterparty_short_name as forwarder_storing_in_foreign_2nd_warehouse_name														-- EXP: WH Operator's 2 SD.001282
		,t5.delivery_number_of_producer_plant																									-- Номер поставки завода производителя SD.000003
		,t5.tsw_location_name 																													-- Направление SD.000009
		,t5.dt_arrival_by_railway																												-- Дата прибытия по ЖД SD.000011
		,t5.dt_forwarder																														-- Дата экспедитора SD.000012
		,t5.dt_warehouse																														-- Дата склада SD.000024
		,t5.transport_type_after_repackaging_code																								-- Тип ПС после перетарки SD.000027
		,t5.transport_railcar_type_code																											-- Тип вагона (код) SD.000028
		,t5.transport_railcar_type_name																											-- Тип вагона SD.000029
		,t5.dt_bill_of_lading																													-- Дата коносамента SD.000042
		,t5.delivery_region_name																												-- Регион поставки по контракту SD.000338
		,t5.dt_shipment 																														-- Дата отгрузки SD.000010
		,t5.port_of_loading_code 																												-- Порт погрузки (код) SD.000649
from t5
	left join dict_dds.transport_hub_texts tvknt 	
	  on tvknt.transport_hub_code = t5.knote
	  and tvknt.language_code = 'E'  
	left join dict_dds.transport_hub tvkn 				 	
	  on tvkn.transport_hub_code = t5.knote
	left join dict_dds.address as adrc1 									 	
		on adrc1.address_code = tvkn.address_code
		and international_display_format_code is null
	left join dict_dds.country_texts r_sd556t		
	  on r_sd556t.country_code = adrc1.country_code
	  and r_sd556t.language_code = 'R'  
	left join vbss_vbsk	vv										
	  on vv.delivery_code = t5.delivery_number_sales
	  and vv.rn = 1  
	left join dds.delivery_document_position as lips									
	  on lips.delivery_code = t5.delivery_number_sales
	  and lips.plant_producer_code is not null 
	  and lips.delivery_position_line_item_code = '000010'
	left join dds.sales_bundle r_ah					
	  on r_ah.sales_bundle_code = t5.sales_bundle_code  
	left join dict_dds.country r_sd556 				 
	  on r_sd556.country_code = adrc1.country_code
	left join dict_dds.market_region1_texts t25a1 	
	  on t25a1.market_region1_code = r_sd556.market_region1_code 
	  and t25a1.language_code = 'R'
	left join dict_dds.location_sales oijloc 		
	  on oijloc.location_code = tvknt.location_code
	  and tvknt.transport_hub_code = t5.knote
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_35
	  on sd4798_35.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_35.transportation_stage_code = '35' 
	  and sd4798_35.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_40
	  on sd4798_40.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_40.transportation_stage_code = '40'
	  and sd4798_40.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_42
	  on sd4798_42.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_42.transportation_stage_code = '42' 
	  and sd4798_42.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_55
	  on sd4798_55.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_55.transportation_stage_code = '55'
	  and sd4798_55.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_60
	  on sd4798_60.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_60.transportation_stage_code = '60'
	  and sd4798_60.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_66
	  on sd4798_66.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_66.transportation_stage_code = '66'
	  and sd4798_66.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_77
	  on sd4798_77.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_77.transportation_stage_code = '77'
	  and sd4798_77.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_49
	  on sd4798_49.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_49.transportation_stage_code = '49'
	  and sd4798_49.rn = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_x
	  on sd4798_x.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_x.is_final_transportation_stage_code = 'X'
	  and sd4798_x.rn2 = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_w03
	  on sd4798_w03.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_w03.rn3 = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_w04
	  on sd4798_w04.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_w04.rn4 = 1
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_w03_2
	  on sd4798_w03_2.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_w03_2.rn3 = 2
	left join dm_calc.sales_bundle_and_delivery_relationship as sd4798_w04_2
	  on sd4798_w04_2.sales_bundle_code = t5.sales_bundle_code
	  and sd4798_w04_2.rn4 = 2
	left join dds.delivery_document_header ddh 					
	  on ddh.delivery_code = t5.delivery_code_le_r
	left join dds.delivery_document_header ddh3 				
	  on ddh3.delivery_code = t5.delivery_number_sales		
	left join vbsk_y											
	  on vbsk_y.delivery_code = t5.delivery_number_sales	
	  and vbsk_y.rn = 1
	left join dds.bill_of_lading as vbsk_y_smg	  											
	  on vbsk_y_smg.bill_of_lading_code = t5.bill_of_lading_group_code
	  and vbsk_y_smg.bill_of_lading_type_code = 'Y'
	left join outb as outb1												
	  on outb1.vbeln = t5.delivery_number_sales
	  and outb1.transport_hub_code = t5.port_of_discharge_code
	  and outb1.rn = 1
	left join uzb as uzb1												
	  on uzb1.ident = t5.sales_bundle_code
	  and uzb1.charg = t5.batch_code
	  and uzb1.transport_hub_code = t5.port_of_discharge_code
	left join eub as eub1												
	  on eub1.ident = t5.sales_bundle_code
	  and eub1.charg = t5.batch_code
	  and eub1.transport_hub_code = t5.port_of_discharge_code 
	left join sdt18	as sdt18_1											
	  on sdt18_1.delivery_code = t5.delivery_number_sales	
	  and sdt18_1.rn = 1
	left join outb as outb2	 											
	  on outb2.vbeln = t5.delivery_number_sales
	  and outb2.transport_hub_code = t5.port_of_discharge_in_foreign_port_code
	  and outb2.rn = 1
 	left join uzb as uzb2										
	  on uzb2.ident = t5.sales_bundle_code
	  and uzb2.charg = t5.batch_code
	  and uzb2.transport_hub_code = t5.port_of_discharge_in_foreign_port_code
	left join eub as eub2										
	  on eub2.ident = t5.sales_bundle_code
	  and eub2.charg = t5.batch_code
	  and eub2.transport_hub_code = t5.port_of_discharge_in_foreign_port_code
	left join sdt18	as sdt18_2											
	  on sdt18_2.delivery_code = t5.delivery_number_sales	
	  and sdt18_2.rn = 2
	left join lgort as lgort_min
	  on lgort_min.sales_bundle_code = t5.sales_bundle_code
	  and lgort_min.rn = 1
	left join lgort as lgort_max
	  on lgort_max.sales_bundle_code = t5.sales_bundle_code
	  and lgort_max.rn = 2
	left join vbsk_o
	  on vbsk_o.delivery_code = t5.delivery_number_sales
	left join dds.pledge_reserve as vbsk_sh
	  on vbsk_sh.pledge_reserve_code = vbsk_o.pledge_reserve_code
	left join dds.sales_contract_header as sch
	  on sch.sales_contract_code = vbsk_sh.pledge_reserve_contract_code
	left join dict_dds.counterparty as ctp
	  on ctp.counterparty_code = vbsk_sh.pledge_reserve_bank_code
	left join ods.zsd2921m_sc_ral zmsr 
	  on zmsr.kunag = t5.lot_customer_code
	left join dict_dds.scm_pledge_status_texts pst
	  on pst.scm_pledge_status_code = zmsr."sign" 
	  and pst.language_code = 'R'
	left join dict_dds.counterparty as ctp2
	  on ctp2.counterparty_code = t5.forwarder_in_foreign_port_code
	left join dds.sales_document_counterparty_role as sdcr 
	  on sdcr.sales_document_code = case 
									  when t5.market_region1_code = '03'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w03.delivery_code
									  when t5.market_region1_code = '04'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w04.delivery_code																									
									end
	  and sdcr.counterparty_role_code = 'XR'
	left join dds.sales_document_counterparty_role as sdcr_2 
	  on sdcr_2.sales_document_code = case 
									  when t5.market_region1_code = '03'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w03_2.delivery_code
									  when t5.market_region1_code = '04'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w04_2.delivery_code																									
									end
	  and sdcr_2.counterparty_role_code = 'XR'
	  left join dds.sales_document_counterparty_role as sdcr_3 
	  on sdcr_3.sales_document_code = case 
									  when t5.market_region1_code = '03'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w03.delivery_code
									  when t5.market_region1_code = '04'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w04.delivery_code																									
									end
	  and sdcr_3.counterparty_role_code = 'ZU'
	left join dds.sales_document_counterparty_role as sdcr_4 
	  on sdcr_4.sales_document_code = case 
									  when t5.market_region1_code = '03'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w03_2.delivery_code
									  when t5.market_region1_code = '04'
									  		and (is_terminal_code = 'X' 				--ZSD2973M_LGORT-SIGN_TERMINAL
												or is_foreign_warehouse_code = 'X'		--ZSD2973M_LGORT-SIGN_FOREIGN_WH
												or is_temporary_warehouse_code = 'X')	--ZSD2973M_LGORT-SIGN_TSW
										then sd4798_w04_2.delivery_code																									
									end
	  and sdcr_4.counterparty_role_code = 'ZU'
	left join dict_dds.counterparty as ctp3
	  on ctp3.counterparty_code = sdcr_3.supplier_code
	  and ctp3.is_deleted is null
	left join dict_dds.counterparty as ctp4
	  on ctp4.counterparty_code = sdcr_4.supplier_code
	  and ctp4.is_deleted is null  
	left join dict_dds.counterparty as ctp5
	  on ctp5.counterparty_code = sdcr.supplier_code
	  and ctp5.is_deleted is null  
	left join dict_dds.counterparty as ctp6
	  on ctp6.counterparty_code = sdcr_2.supplier_code
	  and ctp6.is_deleted is null 
	  ;

drop table if exists sdt18;
drop table if exists vbln;
drop table if exists t5;
drop table if exists adrc1;
drop table if exists vbss_vbsk;
drop table if exists lips;
drop table if exists uzb;
drop table if exists eub;
drop table if exists vbsk_y;
drop table if exists outb;
drop table if exists lgort;
drop table if exists vbsk_o;
drop table if exists s_zrepo;
drop table if exists stat1;
drop table if exists sd4798;
drop table if exists nomtk_s;
