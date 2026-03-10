drop table if exists statement_program_parameters;
create temp table statement_program_parameters as (										
	select distinct	dd_saps.range_low_value	-- Определяем значения настроечных параметров программы /RUSAL/SD4359M для расчёта SD.001244 "Блок данных (statement)"
	from dict_dds.settings_and_parameters_sap as dd_saps
	where dd_saps.abap_program_code = '/RUSAL/SD4359M' 		-- программа = /RUSAL/SD4359M
		and dd_saps.parameter_code IN ('OPERATOR')			-- и один из настроечных параметров = OPERATOR
		and dd_saps.range_sign_code = 'I' 
		and dd_saps.range_option_code = 'EQ' 
		and dd_saps.range_low_value is not null)			-- и значение параметра <> пусто	
distributed by (range_low_value);

drop table if exists d_ldadr;
create temp table d_ldadr as (
	select distinct d_ldadr.delivery_code, d_ldadr.logistics_document_code, d_i_ldc.invoice_code
	from dds.logistics_document_and_delivery_relationship as d_ldadr
	left join dds.invoice as d_i_ldc											-- VBSK + /RUSAL/VBSK_TMPL (VBSK-SMART = "О")
		on d_i_ldc.invoice_code = d_ldadr.logistics_document_code 		-- по VBSK-SAMMG = VBSS-SAMMGL
		and d_i_ldc.invoice_type_code = 'О'							-- и VBSK-SMART = "О"
	where d_i_ldc.invoice_code is not null )
distributed by (delivery_code);	

drop table if exists d_ldadr2;
create temp table d_ldadr2 as (
	select distinct d_ldadr.delivery_code, d_ldadr.logistics_document_code, d_i_ldc.invoice_code
	from dds.logistics_document_and_delivery_relationship as d_ldadr
	left join dds.invoice as d_i_ldc											-- VBSK + /RUSAL/VBSK_TMPL (VBSK-SMART = "Q")
		on d_i_ldc.invoice_code = d_ldadr.logistics_document_code 		-- по VBSK-SAMMG = VBSS-SAMMGL
		and d_i_ldc.invoice_type_code = 'Q'							-- и VBSK-SMART = "Q"
	where d_i_ldc.invoice_code is not null)
distributed by (delivery_code);	

drop table if exists d_ldadr3;
create temp table d_ldadr3 as (
	select d_ldadr.delivery_code, min(d_ldadr.logistics_document_code) as logistics_document_code
	from dds.logistics_document_and_delivery_relationship as d_ldadr
	group by d_ldadr.delivery_code)
distributed by (delivery_code,logistics_document_code);	

drop table if exists th1;
create temp table th1 as (
	select distinct dd_tht.transport_hub_name, dd_tht.location_code
	from dict_dds.transport_hub_texts as dd_tht
	where dd_tht.language_code = 'E' 							-- 
		and dd_tht.transport_hub_name NOT LIKE '@%') 		-- TVKNT-BEZEI <>"@*"
distributed by (transport_hub_name, location_code);

drop table if exists frame_par;
create temp table frame_par as (
	select distinct dd_saps.range_low_value 
	from dict_dds.settings_and_parameters_sap as dd_saps
	where dd_saps.abap_program_code = '/RUSAL/SD2902M' 
		and dd_saps.parameter_code IN ('BSARK_WH','BSARKPWH', 'BSARK_ZL') 
		and dd_saps.range_sign_code = 'I' 
		and dd_saps.range_option_code = 'EQ')
distributed by (range_low_value);

drop table if exists batch_exclude; -- Партии для исключения из отчета
create temp table batch_exclude as (
	select distinct dd_saps.range_low_value 
	from dict_dds.settings_and_parameters_sap as dd_saps
	where abap_program_code = '/RUSAL/SD2973M' 
		and case_code = 'KHD'
		and parameter_code = 'CHARGEXP'  
		and range_sign_code = 'I' 
		and range_option_code = 'EQ')
distributed by (range_low_value);

drop table if exists batch_include; -- Партии для добавления в отчет
create temp table batch_include as (
	select distinct dd_saps.range_low_value 
	from dict_dds.settings_and_parameters_sap as dd_saps
	where abap_program_code = '/RUSAL/SD2973M' 
		and case_code = 'KHD'
		and parameter_code = 'CHARG_2'  
		and range_sign_code = 'I' 
		and range_option_code = 'EQ')
distributed by (range_low_value);

drop table if exists contract_type_exclude; -- Виды контракта для исключения из отчета
create temp table contract_type_exclude as (
	select distinct dd_saps.range_low_value 
	from dict_dds.settings_and_parameters_sap as dd_saps
	where dd_saps.abap_program_code = '/RUSAL/MK_TRACK_2' 
		and dd_saps.parameter_code = 'BSARKRET'  
		and dd_saps.range_sign_code = 'I' 
		and dd_saps.range_option_code = 'EQ')
distributed by (range_low_value);

drop table if exists rseg_deb; -- Дополнительное дебетование
create temp table rseg_deb as (
	select distinct d_ipdp_tben.invoice_code, d_ipdp_tben.fiscal_year
	from dds.invoice_purchase_document_position as d_ipdp_tben
	where d_ipdp_tben.is_additionaly_debited_code = 'X' )
distributed by (invoice_code,fiscal_year);

drop table if exists contract_type_ptc; -- Виды контракта для условий платежа
create temp table contract_type_ptc as (
	select distinct dd_saps.range_low_value 
	from dict_dds.settings_and_parameters_sap as dd_saps
	where dd_saps.abap_program_code = '/RUSAL/SD2902M' 
		and dd_saps.parameter_code IN ('BSARK_WH','BSARKPWH', 'BSARK_ZL')
		and dd_saps.range_sign_code = 'I' 
		and dd_saps.range_option_code = 'EQ')
distributed by (range_low_value);

drop table if exists vbak2;  -- Контракты с максимальной датой окончания
create temp table vbak2 as (
	select vbeln, kunnr, gueen
	from (select vbeln, kunnr, gueen,
			row_number() over (partition by kunnr order by gueen desc, vbeln desc) as rn
	      from ods.vbak_ral
	      where auart = 'ZDGT') as subquery
	where rn = 1
	)
distributed by (kunnr);

drop table if exists vbak4; -- для 1371
create temp table vbak4 as (
	select distinct o_v.vbeln, o_v.zuonr
	from ods.vbak_ral as o_v
	where o_v.auart = 'ZDGS')
distributed by (vbeln,zuonr);

drop table if exists vbsk; -- для 1371
create temp table vbsk as (
	select max(d_i.billing_document_code) as billing_document_code,	d_i.sales_contract_code		
	from dds.invoice as d_i
	where invoice_type_code = 'О'
	group by d_i.sales_contract_code)
distributed by (billing_document_code, sales_contract_code);	

drop table if exists vbap2; -- для 1371
create temp table vbap2 as (
	select vbeln, min(posnr) as posnr, concat(vbeln, min(posnr)) as vbeln_posnr
	from ods.vbap_ral
	group by vbeln)
distributed by (vbeln, vbeln_posnr);		

drop table if exists vbsk4; --для 1371
create temp table vbsk4 as (
	select distinct o_vr.zzkunag, o_vr.zzvbeln
	from ods.vbsk_ral as o_vr
	where o_vr.smart = 'О'
	and o_vr.zzvbeln is not null)
distributed by (zzkunag,zzvbeln);	

drop table if exists vbak5; -- 1371 KUNNR -> KUNAG
create temp table vbak5 as ( 
	select vbeln, kunnr, gueen
	from (
	    select vbeln, kunnr,gueen,
			row_number() over (partition by kunnr order by gueen desc, vbeln desc) as rn
	    from ods.vbak_ral
	    where auart = 'ZDGT') as subquery
	where rn = 1)
distributed by (vbeln,kunnr);

drop table if exists vbak6; --1371
create temp table vbak6 as (
	select max(o_vkr.vbeln) as vbeln, o_vkr.zuonr, min(o_vpr.posnr) as posnr
	from ods.vbak_ral as o_vkr
		left join ods.vbap_ral as o_vpr
		on o_vpr.vbeln = o_vkr.vbeln
	where o_vkr.zuonr is not null
		and o_vkr.auart = 'ZDGS'
		and o_vpr.posnr is not null 
	group by o_vkr.zuonr)
distributed by (vbeln,zuonr);

drop table if exists distinct_vbrp;
create temp table distinct_vbrp as (
	select distinct vgbel, vgpos, posnr
	from ods.vbrp_ral )
distributed by (vgbel,vgpos,posnr);	

drop table if exists vbak1366;
create temp table vbak1366 as (
	select vbak.kunnr, max(vbeln) as vbeln
	from ods.vbak_ral as vbak												-- VBAK
	where vbak.auart = 'ZDGT'														-- и VBAK-AUART = "ZDGT"
		and vbak.guebg <= current_date											-- и VBAK-GUEBG <= текущая дата
		and tech_etl.util_text_to_date_validation(vbak.gueen) >= current_date 	-- и VBAK-GUEEN >= текущая дата 
	group by kunnr)
distributed by (kunnr,vbeln);

drop table if exists vbak7;
create temp table vbak7 as (
	select kunnr, max(vbeln) as vbeln
	from ods.vbak_ral as vbak												-- VBAK
	where vbak.auart = 'ZDGT'														-- и VBAK-AUART = "ZDGT"
		and vbak.guebg <= current_date											-- и VBAK-GUEBG <= текущая дата
		and tech_etl.util_text_to_date_validation(vbak.gueen) >= current_date 	-- и VBAK-GUEEN >= текущая дата 
	group by kunnr)
distributed by (kunnr,vbeln);

drop table if exists vbsk_vbss_1375;
create temp table vbsk_vbss_1375 as (
	select d_ldadr_dns.delivery_code, max(invoice_realization_group_code) as invoice_realization_group_code
	from dds.invoice_realization as d_ir_ldc
		left join dds.logistics_document_and_delivery_relationship as d_ldadr_dns
			on d_ir_ldc.invoice_realization_group_code = d_ldadr_dns.logistics_document_code -- по VBSK_SAMMG = 
		group by d_ldadr_dns.delivery_code)
distributed by (delivery_code,invoice_realization_group_code);
		
drop table if exists dd_topd; --для 1367
create temp table dd_topd as (
	select terms_of_payment_code, payment_terms_days_quantity,payment_event_code, payment_split_quantity
	from (
	    select terms_of_payment_code, payment_terms_days_quantity,payment_event_code,payment_split_quantity,
			row_number() over (partition by terms_of_payment_code order by payment_split_quantity desc) as rn
	    from dict_dds.terms_of_payment_detailed
	    where sap_module_code = 'SD') as subquery
	where rn = 1)
distributed by (terms_of_payment_code, payment_event_code);

drop table if exists dc_sda;
create temp table dc_sda as (		
	select
		dc_sda.delivery_number_initial 								-- SD.000001 "Исходная поставка"
		,dc_sda.delivery_number_sales 									-- SD.000002 "Продажная поставка"
		,dc_sda.plant_producer_name 									-- SD.000007 "Завод"
		,coalesce(t_hub_txt.transport_hub_name,tsw_location_name) as port_of_loading_name  -- SD.000009 "Направление"
		,dc_sda.dt_shipment 											-- SD.000010 "Дата отгрузки"
		,dc_sda.material_aggr_name 									    -- SD.000016 "Материал"
		,dc_sda.material_group_code 									-- SD.000017 "Группа материалов (код)"
		,sales_m_txt.market_in_shipment_name as shipment_market_name    -- SD.000019 "Рынок в отгрузке"
		,dc_sda.dt_warehouse 											-- SD.000024 "Дата склада"
		,trans_t_txt.transport_transfer_type_name as transport_railcar_type_name 	-- SD.000029 "Тип вагона"
		,dc_sda.weight_net 											-- SD.000032 "Вес нетто"
		,dc_sda.customer_for_reporting_code 							-- SD.000036 "Покупатель (код)"
		,dc_sda.customer_for_reporting_name 							-- SD.000037 "Покупатель"
		,dc_sda.contract_name 											-- SD.000038 "Контракт"
		,dc_sda.bill_of_lading_number 									-- SD.000041 "Номер коносамента"
		,dc_sda.dt_bill_of_lading 										-- SD.000042 "Дата коносамента"
		,dc_sda.port_of_discharge_name 								-- SD.000045 "Порт выгрузки"
		,dc_sda.bill_of_lading_in_foreign_port 						-- SD.000048 "Коносамент в ин.порту"
		,dc_sda.dt_bill_of_lading_in_foreign_port 						-- SD.000049 "Дата коносамента в ин.порту"
		,dc_sda.dt_arrival_in_port_of_discharge 						-- SD.000059 "Дата прибытия в порт выгрузки"
		,dc_sda.delivery_basis 										-- SD.000067 "Базис поставки"
		,dc_sda.delivery_point_name 									-- SD.000068 "Пункт доставки по инкотермс"
		,dc_sda.sales_order 											-- SD.000123 "Заказ ЦК"
		,dc_sda.dt_arrival_in_port_of_discharge_plan 					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,dc_sda.grade_name 											-- SD.000145 "Марка по спецификации"
		,dc_sda.uni 													-- SD.000151 "UNI"
		,dc_sda.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,dc_sda.end_user_name 											-- SD.000164 "Конечный потребитель"
		,dc_sda.invoice_provisional_number 							-- SD.000167 "Provisional invoice"
		,dc_sda.dt_storage_start_in_foreign_port 						-- SD.000175 "Дата начала хранения ин. склад"
		,dc_sda.dt_storage_end_in_foreign_port 						-- SD.000176 "Окончание хранения в ин. порту"
		,dc_sda.dt_storage_start_in_second_foreign_warehouse 			-- SD.000177 "Начало хранения склад 2 "
		,dc_sda.dt_storage_end_in_second_foreign_warehouse 			-- SD.000178 "Окончание хранение склад 2 "
		,dc_sda.material_shape_name_full 								-- SD.000180 "Форма"
		,market_reg_txt.market_region1_name as delivery_region_name 	-- SD.000338 "Регион поставки по контракту"
		,country_txt.country_language_name as country_of_discharge_port_name -- SD.000341 "Страна POD"
		,dc_sda.dt_prepared_for_realization 							-- SD.000344 "Дата готовности к релизу"
		,dc_sda.business_location_sap_precalc_name
			as business_location_name 									-- SD.000492 "Статус в Supply chain (Business)"
		,dc_sda.delivery_country_in_contract_name 						-- SD.000576 "Страна поставки по контракту"
		,dc_sda.lot_code 												-- SD.000580 "Номер лота"
		,CASE
			WHEN dc_sda.is_plan_or_actual = 'P'
				THEN dc_sda.buyer_plan_zmk_track_name
			ELSE (
				CASE
					WHEN dd_saps_eufrc.range_low_value is not null
						THEN 'UNSOLD'
					WHEN frame_par.range_low_value is not null
						OR dc_sda.lot_contract_code IS NULL
						THEN COALESCE(dc_cc_cc.counterparty_full_name,
							dc_cc_euc.counterparty_full_name,
							dc_cc_bc.counterparty_full_name)
					ELSE dc_sda.lot_customer_name
				END
				)
		END as customer_for_scm_report_name 							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,CONCAT_WS('/',dc_sda.vessel_actual_name, split_part(nomination_number, '/', 2)) as vessel_and_voyage_actual_search_name					-- SD.000608 "Судно / номер рейса (факт)"
		,dc_sda.dt_invoice_provisional 								-- SD.000620 "Дата инвойса"
		,dc_sda.sales_team_name 										-- SD.000651 "Сбытовая команда"
		,dc_sda.dt_quota_yyyymm 										-- SD.000687 "Квота"
		,dc_sda.dt_realization 											-- SD.000720 "Дата реализации"
		,CASE
			WHEN dd_saps_ctc.range_low_value is not null 								-- Если VBAK-ABRVW = параметру TOLABRVW программы /RUSAL/SD2902M_3,
				THEN 'X' 																-- то"X",
			ELSE NULL 																	-- иначе пусто
		END as is_tolling_code               				-- SD.000749 "Признак толлинг"
		,COALESCE(case
		when dc_sda.shipment_market_code in ('1','4') 				-- Если SD.000018 "Рынок в отгрузке (код)" = ‘1’ (экспорт внешний рынок) или '4' (КУБАЛ)
			and ddh.location_comment is not null				-- Если SD.000630 «EXP: Storage location» <> пусто
		    then dd_ls_lc.location_name								-- OIJLOC-LOCNAM по 1-у условию
        when dc_sda.shipment_market_code in ('1','4')
            and dc_sda.bill_of_lading_group_code_in_foreign_port is not null
            then dd_tht.transport_hub_name                     -- Если SD.000018 "Рынок в отгрузке (код)" = ‘1’ (экспорт внешний рынок) или '4' (КУБАЛ)
		when dc_sda.shipment_market_code in ('1','4')
            and dc_sda.bill_of_lading_group_code_in_foreign_port is null
            then dd_tht_2.transport_hub_name							-- TVKNT-BEZEI где TVKNT-SPRAS = 'E' и TVKNT-BEZEI <> '@*' и TVKNT-KNOTE = SD.000054 «Порт выгрузки 2 (код)», с группированием по полям: TVKNT-BEZEI и TVKNT-BEZKZ
       when dc_sda.shipment_market_code IN ('2','3')				-- Иначе, если SD.000018 "Рынок в отгрузке (код)" = '2', ‘3’ (внутренний рынок РФ и СНГ):
			and dd_saps_coeuc.range_low_value is not null				-- Если SD.000641 "Код страны конечного потребителя" = настроечный параметр LAND1_GP "Страны таможенного союза" (программа /RUSAL/SD3346M)
			then
				(CASE
					WHEN dc_sda.is_plan_or_actual = 'P'
						THEN dc_sda.buyer_plan_zmk_track_name
					ELSE (
						case
							when dd_saps_eufrc.range_low_value is not null then 'UNSOLD'
							when frame_par.range_low_value is not null
								or dc_sda.lot_contract_code is null
								then COALESCE(dc_cc_cc.counterparty_full_name, dc_cc_euc.counterparty_full_name, dc_cc_bc.counterparty_full_name)
							else dc_sda.lot_customer_name
						END)
				END)											-- SD.000603 «Клиент для отчета Металл в Цепочке Поставок»
	   when dc_sda.shipment_market_code IN ('2','3')				-- Иначе, если SD.000018 "Рынок в отгрузке (код)" = '2', ‘3’ (внутренний рынок РФ и СНГ):
			and dc_sda.region_of_destination_port_code = '07'		-- если SD.000342 "Регион POD (код)"= ‘07’ (СНГ)
			then dc_sda.port_of_discharge_name
	   else 'UNDEFINED' end,						         --SD.000045 «Порт выгрузки»
		case
			when dc_sda.shipment_market_code = '4'
        	and dc_sda.tsw_location_name not in ('TUNADAL', 'SORAKER')
        	then 'ONWAY'
		end,
		'UNDEFINED') as warehouse_or_responsible_customer_for_storage_name -- SD.000919 General storage location
		,CASE
			WHEN dc_sda.is_plan_or_actual = 'P' 										-- Если SD.000159 "Признак План/Факт" = "P",
				THEN 'Scheduled'														-- то "Scheduled",
			WHEN dc_sda.delivery_split_reason_code = '8' 								-- если SD.000372 "Причина деления (код)" = 8 (возврат),
				THEN 'fs_returned'														-- то "fs_returned",
			WHEN dc_sda.is_plan_or_actual != 'P' 										-- если SD.000159 "Признак План/Факт" != "P",
				and dc_sda.invoice_provisional_number IS NULL							-- и SD.000167 "Инвойс (счет клиенту)" пусто,
				THEN 'fs_without_invoice'												-- то "fs_without_invoice",
			WHEN dc_sda.is_plan_or_actual != 'P' 										-- если SD.000159 "Признак План/Факт" != "P",
				and dc_sda.invoice_provisional_number is not null						-- и SD.000167 "Инвойс (счет клиенту)" не пусто,
				and spp.range_low_value is not null										-- и SD.000036 "Покупатель (код)" входит в параметр OPERATOR программы /RUSAL/SD4359M
				THEN 'fs_with_invoice_int_operator'										-- то "fs_with_invoice_int_operator",
			WHEN dc_sda.is_plan_or_actual != 'P' 										-- если SD.000159 "Признак План/Факт" != "P",
				and dc_sda.invoice_provisional_number is not null						-- и SD.000167 "Инвойс (счет клиенту)" не пусто,
				and spp.range_low_value IS NULL											-- и SD.000036 "Покупатель (код)" не входит в параметр OPERATOR программы /RUSAL/SD4359M
				THEN 'fs_with_invoice_ext_client'										-- то "fs_with_invoice_ext_client",
		END as statement_data_group_code 									-- SD.001244 "Блок данных (statement)"
		,CASE
			WHEN dc_sda.is_plan_or_actual = 'P' 										-- Если SD.001244 "Блок данных (statement)" ="Scheduled",
				THEN NULL																-- то пусто,
			WHEN dc_sda.is_plan_or_actual != 'P' 										-- если SD.001244 "Блок данных (statement)" ="fs_without_invoice",
				and dc_sda.invoice_provisional_number IS NULL
				THEN NULL																-- то пусто,
			WHEN dc_sda.is_plan_or_actual != 'P' 										-- если SD.001244 "Блок данных (statement)" ="fs_with_invoice_int_operator",
				and dc_sda.invoice_provisional_number is not null
				and spp.range_low_value is not null
				THEN NULL																-- то пусто,
			WHEN dc_sda.is_plan_or_actual != 'P' 										-- если SD.001244 "Блок данных (statement)" ="fs_with_invoice_ext_client",
				and dc_sda.invoice_provisional_number is not null
				and spp.range_low_value IS NULL
				THEN d_ldadr.invoice_code 												-- то /RUSAL/VBSS_VBSK-SAMMG (SMART = "О"),
			WHEN dc_sda.delivery_split_reason_code = '8' 								-- если SD.001244 "Блок данных (statement)" ="fs_returned",
				THEN coalesce(d_ldadr2.invoice_code,										-- то /RUSAL/VBSS_VBSK-SAMMG (SMART = "Q"),
					d_i_ldc3.invoice_code)												-- если /RUSAL/VBSS_VBSK-SAMMG (SMART = "Q") пусто, то /RUSAL/VBSS_VBSK-SAMMG (SMART ="К"),
		END as invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,NULL::varchar as dt_report_yyyy 								-- SD.001246 "Год отчета (statement)"
		,NULL::varchar as purchase_invoice_code 						-- SD.001247 "Входящий счет (statement)"
		,NULL::varchar as dt_purchase_invoice_yyyy 						-- SD.001248 "Год входящего счета (statement)"
		,dc_sda.weight_net::numeric as net_weight 						-- SD.001249 "Вес для statement"
		,NULL::varchar as statement_invoice_code 						-- SD.001250 "Фактура для statement"
		,NULL::varchar as statement_invoice_position_code 				-- SD.001251 "Позиция фактуры для statement"
		-------------------------------------------
		,dc_sda.batch
		,dc_sda.release_material_status_code
		,dc_sda.contract_type_code
		,dc_sda.double_record_in_temporary_warehouse_code
		,dc_sda.warehouse_shipment_type_name
		,dc_sda.shipment_market_code
		,dc_sda.delivery_number_outbound
		,dc_sda.plant_producer_code
		,dc_sda.lot_group
		,dc_sda.sales_contract_code
		,dc_sda.is_shipped_via_overseas_warehouse				-- SD.000483 "Наличие Иностранный склад"
	from dm_calc.sd_sales_main_scm as dc_sda
	-- SD.000749 "Признак толлинг"
	left join dds.nomination as nom_act
		on dc_sda.nomination_actual = nom_act.nomination_code
	left join dds.sales_batch_delivery as d_sbd_ssrc 													-- /RUSAL/SHIPDATA
		on d_sbd_ssrc.shipment_entry_from_file_code = dc_sda.sap_shipdata_reference_code		-- по /RUSAL/SHIPDATA-IDENT = SD.000654 "ID_SHIPDATA"
	--
	left join dds.delivery_document_header as ddh                                        -- Если SD.000630 «EXP: Storage location» <> пусто
		on ddh.delivery_code = dc_sda.delivery_number_sales
	left join dict_dds.transport_hub_texts as t_hub_txt                                  -- port_of_loading_name SD.000009 "Направление"
		on t_hub_txt.transport_hub_code = dc_sda.port_of_loading_code
		and t_hub_txt.language_code = 'E'
	left join dict_dds.sales_market_in_shipment_texts as sales_m_txt                     -- shipment_market_name SD.000019 "Рынок в отгрузке"
		on sales_m_txt.market_in_shipment_code = dc_sda.shipment_market_code
		and sales_m_txt.language_code = 'E'
	left join dict_dds.transport_transfer_type_texts as trans_t_txt                      -- transport_railcar_type_name SD.000029 "Тип вагона"
		on trans_t_txt.transport_transfer_type_code = dc_sda.transport_railcar_type_code
		and trans_t_txt.language_code = 'E'
	left join dict_dds.market_region1_texts as market_reg_txt                            -- delivery_region_name SD.000338 "Регион поставки по контракту"
		on market_reg_txt.market_region1_code = dc_sda.delivery_region_code
		and market_reg_txt.language_code = 'E'
	left join dict_dds.country_texts as country_txt                                      -- country_of_discharge_port_name SD.000341 "Страна POD"
		on country_txt.country_code = dc_sda.country_of_discharge_port_code
		and country_txt.language_code = 'E'
	left join dds.sales_contract_header as d_sch_spcc 												-- VBAK
		on d_sch_spcc.sales_contract_code = d_sbd_ssrc.sales_plant_contract_code 				-- по VBAK-VBELN = /RUSAL/SHIPDATA-CONTR_ID
	--
	left join dict_dds.settings_and_parameters_sap as dd_saps_ctc 									-- /RUSAL/PARAMS
		on dd_saps_ctc.range_low_value = d_sch_spcc.contract_type_code							-- по значение параметра = VBAK-ABRVW
		and dd_saps_ctc.abap_program_code = '/RUSAL/SD2902M_3' 								-- и программа /RUSAL/SD2902M_3
		and dd_saps_ctc.parameter_code ='TOLABRVW' 											-- и параметр TOLABRVW
		and dd_saps_ctc.range_sign_code = 'I'
		and dd_saps_ctc.range_option_code = 'EQ'
	-- SD.000919 "General storage location"
	left join th1																				-- TVKNT
		on th1.transport_hub_name = ddh.location_comment	                                    -- по TVKNT-BEZEI = SD.000630 "EXP: Storage location"
	left join dict_dds.location_sales as dd_ls_lc 												-- OIJLOC
		on dd_ls_lc.location_code = th1.location_code											-- по OIJLOC-LOCID = TVKNT-BEZKZ
	left join dict_dds.transport_hub_texts as dd_tht											-- TVKNT
		on dd_tht.transport_hub_code = dc_sda.port_of_discharge_in_foreign_port_code			-- по TVKNT-KNOTE = SD.000044 "Порт выгрузки (код)"
		and dd_tht.language_code = 'E' 														    -- и TVKNT-SPRAS ="E"
	left join
		dict_dds.transport_hub_texts as dd_tht_2												-- TVKNT
		on dd_tht_2.transport_hub_code = dc_sda.port_of_discharge_code			                -- по TVKNT-KNOTE = SD.000054 "Порт выгрузки 2 (код)
		and dd_tht_2.language_code = 'E' 													    -- и TVKNT-SPRAS ="E"
	left join dict_dds.settings_and_parameters_sap as dd_saps_coeuc 						    -- /RUSAL/PARAMS
		on dd_saps_coeuc.range_low_value = dc_sda.country_of_end_user_code 						-- по значение параметра = SD.000641 "Код страны конечного потребителя"
		and dd_saps_coeuc.abap_program_code = '/RUSAL/SD3346M' 								    -- и программа /RUSAL/SD3346M
		and dd_saps_coeuc.parameter_code ='LAND1_GP' 											-- и настроечный параметр LAND1_GP
		and dd_saps_coeuc.range_sign_code = 'I'
		and dd_saps_coeuc.range_option_code = 'EQ'
	--
	left join dict_dds.settings_and_parameters_sap as dd_saps_eufrc
		on dd_saps_eufrc.range_low_value = dc_sda.end_user_for_reporting_code
		and (dd_saps_eufrc.abap_program_code='/RUSAL/SD2921M_4'
		and dd_saps_eufrc.parameter_code='KUNNRUNS'
		and dd_saps_eufrc.range_sign_code = 'I'
		and dd_saps_eufrc.range_option_code = 'EQ')
	left join dds.sales_contract_header as d_sch_lcc
		on d_sch_lcc.sales_contract_code = dc_sda.lot_contract_code
	left join frame_par
		on frame_par.range_low_value = d_sch_lcc.frame_contract_code
	left join dds.delivery_document_header as d_ddh_dns 										-- /RUSAL/INDEL_1
		on d_ddh_dns.delivery_code = dc_sda.delivery_number_sales								-- по /RUSAL/INDEL_1–VBELN = SD.000002 "Продажная поставка"
	left join dds.sales_document_counterparty_role as d_sdcr_cpc 								-- VBPA
		on d_sdcr_cpc.sales_document_code = d_ddh_dns.contract_plan_code 						-- по VBPA-VBELN = /RUSAL/INDEL_1-CONTRACT_P
		and d_sdcr_cpc.counterparty_role_code='AG'												-- и VBPA-PARVW ="AG"
	left join dm_calc.counterparty_country as dc_cc_cc 											-- KNA1
		on dc_cc_cc.counterparty_code = d_sdcr_cpc.customer_code								-- по KNA1-KUNNR = VBPA-KUNNR
	left join dm_calc.counterparty_country as dc_cc_euc 										-- KNA1
		on dc_cc_euc.counterparty_code = d_ddh_dns.end_user_code								-- KNA1-KUNNR = /RUSAL/INDEL_1-POTREBIT
	left join dds.sales_request as d_sr_so
		on d_sr_so.sales_request_code = dc_sda.sales_order
		and d_sr_so.dt_shipment_yyyymm = to_char(dc_sda.dt_shipment,'YYYYMM')
		and d_sr_so.is_not_valid_for_reporting is FALSE
	left join dm_calc.counterparty_country as dc_cc_bc
		on dc_cc_bc.counterparty_code = d_sr_so.buyer_code
	-- SD.001244 "Блок данных (statement)"
	left join statement_program_parameters as spp								-- /RUSAL/PARAMS
		on spp.range_low_value = dc_sda.customer_for_reporting_code		-- по /RUSAL/PARAMS-LOW = SD.000036 "Покупатель (код)"
	-- SD.001245 "Группа инвойс (statement)"
	left join d_ldadr															-- VBSS (VBSK-SMART = "О")
		on d_ldadr.delivery_code = dc_sda.delivery_number_sales			-- по VBSS-VBELN = SD.000002 "Продажная поставка"
	left join d_ldadr2														-- VBSS (VBSK-SMART = "Q")
		on d_ldadr2.delivery_code = dc_sda.delivery_number_outbound		-- по VBSS-VBELN = SD.000002 "Продажная поставка"
	left join
		d_ldadr3														-- VBSS с мин SAMMG
		on d_ldadr3.delivery_code = dc_sda.delivery_number_outbound		-- по VBSS-VBELN = SD.000002 "Продажная поставка"
	left join dds.invoice as d_i_ldc3											-- VBSK + /RUSAL/VBSK_TMPL (VBSK-SMART = "К")
		on d_i_ldc3.invoice_code = d_ldadr3.logistics_document_code 	-- по VBSK-SAMMG = VBSS-SAMMGL
		and d_i_ldc3.invoice_type_code = 'К'						-- и VBSK-SMART = "К"
	)
distributed by (delivery_number_sales,batch);

drop table if exists dc_sda_tot;
create temp table dc_sda_tot as (
	select
		dc_sda.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,dc_sda.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,dc_sda.plant_producer_name  									-- SD.000007 "Завод"
		,dc_sda.port_of_loading_name  									-- SD.000009 "Направление"
		,dc_sda.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,dc_sda.material_aggr_name  									-- SD.000016 "Материал"
		,dc_sda.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,dc_sda.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,dc_sda.dt_warehouse  											-- SD.000024 "Дата склада"
		,dc_sda.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,dc_sda.weight_net  											-- SD.000032 "Вес нетто"
		,dc_sda.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,dc_sda.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,dc_sda.contract_name  											-- SD.000038 "Контракт"
		,dc_sda.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,dc_sda.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,dc_sda.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,dc_sda.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,dc_sda.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,dc_sda.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,dc_sda.delivery_basis  										-- SD.000067 "Базис поставки"
		,dc_sda.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,dc_sda.sales_order  											-- SD.000123 "Заказ ЦК"
		,dc_sda.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,dc_sda.grade_name  											-- SD.000145 "Марка по спецификации"
		,dc_sda.uni 													-- SD.000151 "UNI"
		,dc_sda.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,dc_sda.end_user_name  											-- SD.000164 "Конечный потребитель"
		,dc_sda.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,dc_sda.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,dc_sda.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,dc_sda.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,dc_sda.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,dc_sda.material_shape_name_full  								-- SD.000180 "Форма"
		,dc_sda.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,dc_sda.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,dc_sda.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,dc_sda.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,dc_sda.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,dc_sda.lot_code  												-- SD.000580 "Номер лота"
		,dc_sda.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,dc_sda.vessel_and_voyage_actual_search_name	-- SD.000608 "Судно / номер рейса (факт)"
		,dc_sda.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,dc_sda.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,dc_sda.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,dc_sda.dt_realization 											-- SD.000720 "Дата реализации"
		,dc_sda.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,dc_sda.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,dc_sda.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,dc_sda.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,dc_sda.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,dc_sda.purchase_invoice_code									-- SD.001247 "Входящий счет (statement)"
		,dc_sda.dt_purchase_invoice_yyyy								-- SD.001248 "Год входящего счета (statement)"
		,dc_sda.net_weight			 									-- SD.001249 "Вес для statement"
		,dc_sda.statement_invoice_code			 						-- SD.001250 "Фактура для statement"
		,dc_sda.statement_invoice_position_code			 				-- SD.001251 "Позиция фактуры для statement"
		---------------------------------------
		,dc_sda.batch
		,dc_sda.release_material_status_code
		,dc_sda.contract_type_code
		,dc_sda.double_record_in_temporary_warehouse_code
		,dc_sda.warehouse_shipment_type_name
		,dc_sda.shipment_market_code
		,dc_sda.delivery_number_outbound
		,dc_sda.plant_producer_code
		,dc_sda.lot_group
		,dc_sda.sales_contract_code
		,dc_sda.is_shipped_via_overseas_warehouse				-- SD.000483 "Наличие Иностранный склад"
	from dc_sda
	left join batch_exclude
		on dc_sda.batch = batch_exclude.range_low_value
	left join contract_type_exclude
		on dc_sda.contract_type_code = contract_type_exclude.range_low_value
	where
		dc_sda.release_material_status_code = 'C'						-- SD.000260 "Статус ОМ" ="C" (лат.)
		and	dc_sda.dt_realization >= '2024-01-01'						-- и минимальная SD.000720 "Дата реализации" ="01.01.2024 "
		and batch_exclude.range_low_value IS NULL						-- и партии не для исключения из отчета
		and dc_sda.double_record_in_temporary_warehouse_code IS NULL	-- и ZMK_TRACK_EXP01-SVH_02_EXIST !="X"
		and contract_type_exclude.range_low_value IS NULL				-- и SD.000242 "Вид контракта (код)" != параметру BSARKRET программы /RUSAL/MK_TRACK_2
		and dc_sda.material_group_code IN ('A01', 'A02', 'A03')			-- и SD.000017 "Группа материалов (код)" = (A01, A02, A03)
	UNION ALL
	select
		dc_sda.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,dc_sda.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,dc_sda.plant_producer_name  									-- SD.000007 "Завод"
		,dc_sda.port_of_loading_name  									-- SD.000009 "Направление"
		,dc_sda.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,dc_sda.material_aggr_name  									-- SD.000016 "Материал"
		,dc_sda.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,dc_sda.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,dc_sda.dt_warehouse  											-- SD.000024 "Дата склада"
		,dc_sda.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,dc_sda.weight_net  											-- SD.000032 "Вес нетто"
		,dc_sda.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,dc_sda.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,dc_sda.contract_name  											-- SD.000038 "Контракт"
		,dc_sda.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,dc_sda.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,dc_sda.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,dc_sda.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,dc_sda.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,dc_sda.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,dc_sda.delivery_basis  										-- SD.000067 "Базис поставки"
		,dc_sda.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,dc_sda.sales_order  											-- SD.000123 "Заказ ЦК"
		,dc_sda.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,dc_sda.grade_name  											-- SD.000145 "Марка по спецификации"
		,dc_sda.uni 													-- SD.000151 "UNI"
		,dc_sda.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,dc_sda.end_user_name  											-- SD.000164 "Конечный потребитель"
		,dc_sda.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,dc_sda.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,dc_sda.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,dc_sda.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,dc_sda.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,dc_sda.material_shape_name_full  								-- SD.000180 "Форма"
		,dc_sda.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,dc_sda.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,dc_sda.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,dc_sda.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,dc_sda.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,dc_sda.lot_code  												-- SD.000580 "Номер лота"
		,dc_sda.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,dc_sda.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,dc_sda.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,dc_sda.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,dc_sda.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,dc_sda.dt_realization 											-- SD.000720 "Дата реализации"
		,dc_sda.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,dc_sda.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,dc_sda.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,dc_sda.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,dc_sda.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,dc_sda.purchase_invoice_code									-- SD.001247 "Входящий счет (statement)"
		,dc_sda.dt_purchase_invoice_yyyy		 						-- SD.001248 "Год входящего счета (statement)"
		,dc_sda.net_weight												-- SD.001249 "Вес для statement"
		,dc_sda.statement_invoice_code									-- SD.001250 "Фактура для statement"
		,dc_sda.statement_invoice_position_code							-- SD.001251 "Позиция фактуры для statement"
		---------------------------------------
		,dc_sda.batch
		,dc_sda.release_material_status_code
		,dc_sda.contract_type_code
		,dc_sda.double_record_in_temporary_warehouse_code
		,dc_sda.warehouse_shipment_type_name
		,dc_sda.shipment_market_code
		,dc_sda.delivery_number_outbound
		,dc_sda.plant_producer_code
		,dc_sda.lot_group
		,dc_sda.sales_contract_code
		,dc_sda.is_shipped_via_overseas_warehouse				-- SD.000483 "Наличие Иностранный склад"
	from dc_sda
	left join batch_include
		on dc_sda.batch = batch_include.range_low_value
	left join contract_type_exclude
		on dc_sda.contract_type_code = contract_type_exclude.range_low_value
	where
		dc_sda.release_material_status_code = 'C'						-- SD.000260 "Статус ОМ" = "C" (лат.)
		and	dc_sda.dt_realization >= '2024-01-01'						-- и минимальная SD.000720 "Дата реализации" = "01.01.2024"
		and batch_include.range_low_value is not null					-- и партии не для исключения из отчета
		and dc_sda.double_record_in_temporary_warehouse_code IS NULL	-- и ZMK_TRACK_EXP01-SVH_02_EXIST != "X"
		and contract_type_exclude.range_low_value IS NULL				-- и SD.000242 "Вид контракта (код)" != параметру BSARKRET программы /RUSAL/MK_TRACK_2
		and dc_sda.material_group_code IN ('A01', 'A02', 'A03'))		-- и SD.000017 "Группа материалов (код)" = (A01, A02, A03)
distributed by (delivery_number_sales,batch);

drop table if exists sda_prev; -- Блок Озеро данных сбыта
create temp table sda_prev as (
	select
		 dc_sda_tot.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,dc_sda_tot.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,dc_sda_tot.plant_producer_name  									-- SD.000007 "Завод"
		,dc_sda_tot.port_of_loading_name  									-- SD.000009 "Направление"
		,dc_sda_tot.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,dc_sda_tot.material_aggr_name  									-- SD.000016 "Материал"
		,dc_sda_tot.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,dc_sda_tot.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,dc_sda_tot.dt_warehouse  											-- SD.000024 "Дата склада"
		,dc_sda_tot.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,dc_sda_tot.weight_net  											-- SD.000032 "Вес нетто"
		,dc_sda_tot.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,dc_sda_tot.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,dc_sda_tot.contract_name  											-- SD.000038 "Контракт"
		,dc_sda_tot.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,dc_sda_tot.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,dc_sda_tot.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,dc_sda_tot.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,dc_sda_tot.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,dc_sda_tot.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,dc_sda_tot.delivery_basis  										-- SD.000067 "Базис поставки"
		,dc_sda_tot.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,dc_sda_tot.sales_order  											-- SD.000123 "Заказ ЦК"
		,dc_sda_tot.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,dc_sda_tot.grade_name  											-- SD.000145 "Марка по спецификации"
		,dc_sda_tot.uni 													-- SD.000151 "UNI"
		,dc_sda_tot.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,dc_sda_tot.end_user_name  											-- SD.000164 "Конечный потребитель"
		,dc_sda_tot.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,dc_sda_tot.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,dc_sda_tot.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,dc_sda_tot.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,dc_sda_tot.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,dc_sda_tot.material_shape_name_full  								-- SD.000180 "Форма"
		,dc_sda_tot.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,dc_sda_tot.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,dc_sda_tot.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,dc_sda_tot.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,dc_sda_tot.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,dc_sda_tot.lot_code  												-- SD.000580 "Номер лота"
		,dc_sda_tot.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,dc_sda_tot.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,dc_sda_tot.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,dc_sda_tot.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,dc_sda_tot.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,dc_sda_tot.dt_realization 											-- SD.000720 "Дата реализации"
		,dc_sda_tot.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,dc_sda_tot.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,dc_sda_tot.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,dc_sda_tot.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,dc_sda_tot.dt_report_yyyy 											-- SD.001246 "Год отчета (statement)"
		,dc_sda_tot.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,dc_sda_tot.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,dc_sda_tot.net_weight 												-- SD.001249 "Вес для statement"
		,dc_sda_tot.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,dc_sda_tot.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,'Озеро данных сбыта'::varchar as block
		-------------------------------------------
		,dc_sda_tot.batch
		,dc_sda_tot.release_material_status_code
		,dc_sda_tot.contract_type_code
		,dc_sda_tot.double_record_in_temporary_warehouse_code
		,dc_sda_tot.warehouse_shipment_type_name
		,dc_sda_tot.shipment_market_code
		,dc_sda_tot.delivery_number_outbound
		,dc_sda_tot.plant_producer_code
		,dc_sda_tot.lot_group
		,dc_sda_tot.sales_contract_code
		,dc_sda_tot.is_shipped_via_overseas_warehouse				-- SD.000483 "Наличие Иностранный склад"
	from dc_sda_tot
	where dc_sda_tot.warehouse_shipment_type_name IS NULL					-- SD.000489 "СВХ" пусто
		and dc_sda_tot.shipment_market_code IN ('1', '4')				-- SD.000018 "Рынок в отгрузке (код)" = "1", "4"
	UNION ALL
	select
		 dc_sda_tot.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,dc_sda_tot.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,dc_sda_tot.plant_producer_name  									-- SD.000007 "Завод"
		,dc_sda_tot.port_of_loading_name  									-- SD.000009 "Направление"
		,dc_sda_tot.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,dc_sda_tot.material_aggr_name  									-- SD.000016 "Материал"
		,dc_sda_tot.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,dc_sda_tot.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,dc_sda_tot.dt_warehouse  											-- SD.000024 "Дата склада"
		,dc_sda_tot.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,dc_sda_tot.weight_net  											-- SD.000032 "Вес нетто"
		,dc_sda_tot.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,dc_sda_tot.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,dc_sda_tot.contract_name  											-- SD.000038 "Контракт"
		,dc_sda_tot.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,dc_sda_tot.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,dc_sda_tot.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,dc_sda_tot.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,dc_sda_tot.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,dc_sda_tot.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,dc_sda_tot.delivery_basis  										-- SD.000067 "Базис поставки"
		,dc_sda_tot.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,dc_sda_tot.sales_order  											-- SD.000123 "Заказ ЦК"
		,dc_sda_tot.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,dc_sda_tot.grade_name  											-- SD.000145 "Марка по спецификации"
		,dc_sda_tot.uni 													-- SD.000151 "UNI"
		,dc_sda_tot.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,dc_sda_tot.end_user_name  											-- SD.000164 "Конечный потребитель"
		,dc_sda_tot.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,dc_sda_tot.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,dc_sda_tot.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,dc_sda_tot.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,dc_sda_tot.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,dc_sda_tot.material_shape_name_full  								-- SD.000180 "Форма"
		,dc_sda_tot.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,dc_sda_tot.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,dc_sda_tot.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,dc_sda_tot.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,dc_sda_tot.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,dc_sda_tot.lot_code  												-- SD.000580 "Номер лота"
		,dc_sda_tot.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,dc_sda_tot.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,dc_sda_tot.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,dc_sda_tot.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,dc_sda_tot.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,dc_sda_tot.dt_realization 											-- SD.000720 "Дата реализации"
		,dc_sda_tot.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,dc_sda_tot.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,dc_sda_tot.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,dc_sda_tot.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,dc_sda_tot.dt_report_yyyy 											-- SD.001246 "Год отчета (statement)"
		,dc_sda_tot.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,dc_sda_tot.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,dc_sda_tot.net_weight 												-- SD.001249 "Вес для statement"
		,dc_sda_tot.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,dc_sda_tot.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,'Озеро данных сбыта'::varchar as block
		-------------------------------------------
		,dc_sda_tot.batch
		,dc_sda_tot.release_material_status_code
		,dc_sda_tot.contract_type_code
		,dc_sda_tot.double_record_in_temporary_warehouse_code
		,dc_sda_tot.warehouse_shipment_type_name
		,dc_sda_tot.shipment_market_code
		,dc_sda_tot.delivery_number_outbound
		,dc_sda_tot.plant_producer_code
		,dc_sda_tot.lot_group
		,dc_sda_tot.sales_contract_code
		,dc_sda_tot.is_shipped_via_overseas_warehouse				-- SD.000483 "Наличие Иностранный склад"
	from dc_sda_tot
	where dc_sda_tot.warehouse_shipment_type_name = 'Со склада клиенту'	-- SD.000489 "СВХ" = "Со склада клиенту"
		and dc_sda_tot.shipment_market_code IN ('1', '4')				-- SD.000018 "Рынок в отгрузке (код)" = "1", "4"
		)
distributed by (delivery_number_sales,batch);

drop table if exists statement_sda_original_data; --Рассчёт полей statement -- statement_sda
create temp table statement_sda_original_data as ( -- замножаем строки, если год реализации != году поставки
	select --count(*) /*
	         sda.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,sda.delivery_number_sales  								-- SD.000002 "Продажная поставка"
			,sda.plant_producer_name  									-- SD.000007 "Завод"
			,sda.port_of_loading_name  									-- SD.000009 "Направление"
			,sda.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,sda.material_aggr_name  									-- SD.000016 "Материал"
			,sda.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,sda.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,sda.dt_warehouse  											-- SD.000024 "Дата склада"
			,sda.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,sda.weight_net  											-- SD.000032 "Вес нетто"
			,sda.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,sda.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,sda.contract_name  										-- SD.000038 "Контракт"
			,sda.bill_of_lading_number  								-- SD.000041 "Номер коносамента"
			,sda.dt_bill_of_lading  									-- SD.000042 "Дата коносамента"
			,sda.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
			,sda.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,sda.dt_bill_of_lading_in_foreign_port  					-- SD.000049 "Дата коносамента в ин.порту"
			,sda.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,sda.delivery_basis  										-- SD.000067 "Базис поставки"
			,sda.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,sda.sales_order  											-- SD.000123 "Заказ ЦК"
			,sda.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,sda.grade_name  											-- SD.000145 "Марка по спецификации"
			,sda.uni 													-- SD.000151 "UNI"
			,sda.dt_arrival_in_second_port_of_discharge_plan			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,sda.end_user_name  										-- SD.000164 "Конечный потребитель"
			,sda.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,sda.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,sda.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,sda.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,sda.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,sda.material_shape_name_full  								-- SD.000180 "Форма"
			,sda.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,sda.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,sda.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,sda.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,sda.delivery_country_in_contract_name  					-- SD.000576 "Страна поставки по контракту"
			,sda.lot_code  												-- SD.000580 "Номер лота"
			,sda.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,sda.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,sda.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,sda.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,sda.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,sda.dt_realization 										-- SD.000720 "Дата реализации"
			,sda.is_tolling_code                            			-- SD.000749 "Признак толлинг"
			,sda.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,sda.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,sda.invoice_group_code 									-- SD.001245 "Группа инвойс (statement)"
			,sda.dt_report_yyyy 										-- SD.001246 "Год отчета (statement)"
			,sda.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,sda.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,sda.net_weight 											-- SD.001249 "Вес для statement"
			,d_i.billing_document_code								-- VBSK-ZZVBELN
				as statement_invoice_code 								-- SD.001250 "Фактура для statement"
			,CASE
				WHEN sda.statement_data_group_code = 				-- Если SD.001244 "Блок данных (statement)" =
					'fs_with_invoice_ext_client'					-- "fs_with_invoice_ext_client",
					THEN vbrp.posnr 								-- то VBRP-POSNR
				ELSE sda.statement_invoice_position_code
			END as statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
			,NULL::varchar as supplier_3rd_party_code					-- SD.001361 "Внешний контрагент"
			,CASE
				WHEN d_i.billing_document_code is not null 			-- Если SD.001250 "Фактура для statement" не пусто,
					THEN CASE
							WHEN o_zr.zzasdate > current_date then coalesce(o_zr.zzpaydt, o_zr.zzasdate) -- то ZVBRK-ZZPAYDT,
							WHEN o_zr.zzasdate <= current_date then coalesce(current_date, o_zr.zzasdate)
					END
				ELSE NULL											-- иначе пусто
			END as dt_payment											-- SD.001362 "Дата оплаты"
			,NULL::integer as dt_payment_week							-- SD.001363 "Неделя оплаты"
			,NULL::varchar as dt_payment_mm								-- SD.001364 "Месяц оплаты"
			,o_zr.zzasdate											-- ZVBRK-ZZASDATE
				as dt_due_payment										-- SD.001365 "Срок оплаты"
			,coalesce(vbsk1251.zzterm,								-- VBSK-ZZTERM по 1-у условию,
				(CASE
					WHEN contract_type_ptc.range_low_value IS NULL
						THEN vbsk2.zzterm
				END),												-- если VBSK-ZZTERM по 1-у условию пусто, то VBSK-ZZTERM по 2-у условию,
				d_sr.terms_of_payment_code,							-- если VBSK-ZZTERM по 2-у условию пусто, то /RUSAL/SD2882M-ZTERM
				vbak1366.vbeln,										-- если /RUSAL/SD2882M-ZTERM пусто, то VBAK-VBELN
				vbkd.vbeln											-- если VBAK-VBELN пусто, то VBKD-ZTERM
				) as payment_terms_code									-- SD.001366 "Условие платежа"
			,NULL::integer as payment_terms_days_quantity				-- SD.001367 "Условие платежа (дни)"
			,NULL::varchar as payment_terms_document_name				-- SD.001368 "Условие платежа (документ)"
			,coalesce(vbsk1251.zzkondm,								-- VBSK-ZZKONDM по 1-у условию,
				(CASE
					WHEN contract_type_ptc.range_low_value IS NULL
						THEN vbsk2.zzkondm
				END)												-- если VBSK-ZZKONDM по 1-у условию пусто, то VBSK-ZZKONDM по 2-у условию
				) as market_indicator_code								-- SD.001369 "Рыночный индикатор (код)"
			,NULL::varchar as market_indicator_name						-- SD.001370 "Тип рыночного индикатора"
			,NULL::varchar as metal_exchange_type_code					-- SD.001371 "Тип биржи"
			,NULL::numeric as usd_currency_vat_excluded_amound			-- SD.001372 "Стоимость"
			,NULL::numeric as document_currency_vat_excluded_amound		-- SD.001373 "Стоимость в исходной валюте"
			,NULL::numeric as usd_currency_vat_included_amound			-- SD.001374 "Стоимость с НДС"
			,CASE
				WHEN sda.statement_data_group_code = 				-- Если SD.001244 "Блок данных (statement)" =
					'fs_with_invoice_ext_client'					-- "fs_with_invoice_ext_client",
					THEN vbrk.vbeln 								-- то VBRK-VBELN
				ELSE NULL
			END as invoice_realization_code								-- SD.001375 "Фактура реализации"
			,NULL::numeric as currency_exchange_rate					-- SD.001376 "Валютный курс"
			,CASE
				WHEN sda.is_shipped_via_overseas_warehouse IS NULL 	-- Если SD.000483 "Наличие Иностранный склад" пусто,
					THEN 'Direct delivery'							-- то "Direct delivery"
				ELSE 'Warehouse'									-- ианче "Warehouse"
			END	as direct_or_overseas_warehouse_delivery_name			-- SD.001377 "Склад/прямая поставка"
			,CASE
				WHEN dd_mctmr2_cfrc.counterparty_code is not null 	-- Если SD.000036 "Покупатель (код)" есть в ZVSD_REG_CLIENT-KUNNR_CODE
					THEN 'Trader'									-- то "Trader",
				ELSE NULL											-- иначе пусто
			END	as is_trader_name										-- SD.001378 "Трейдер"
			,vbsk5.vtext											-- VBSK-VTEXT
				as prepayment_invoice_code								-- SD.001379 "Номер предоплатного инвойса"
			,d_sr.sales_market_code									-- /RUSAL/SD2882M-MARKET
				as sales_market_in_sales_request_code					-- SD.001380 "Рынок из заказа"
			,NULL::numeric as statement_calculated_weight				-- SD.001381 "Расчетный вес STATEMENT"
			,sda.block
			-------------------------------------------
			,sda.batch
			,sda.release_material_status_code
			,sda.contract_type_code
			,sda.double_record_in_temporary_warehouse_code
			,sda.warehouse_shipment_type_name
			,sda.shipment_market_code
			,sda.delivery_number_outbound
			,sda.plant_producer_code
	        ,EXTRACT(YEAR from sda.dt_realization)::varchar as realization_year
	        ,EXTRACT(YEAR from sda.dt_shipment)::varchar as shipment_year
	        ,sda.lot_group
	        ,sda.sales_contract_code
	        ,coalesce(o_tfsfrt1.text_value,
	        	o_tfsfrt2.text_value,
	        	o_tfsfrt3.text_value,
	        	o_tfsfrt4.text_value,
	        	o_tfsfrt5.text_value,
	        	(CASE
	        		WHEN vbak4.vbeln is not null
	        			and o_tfsfrt6.text_value is not null
	        			THEN o_tfsfrt6.text_value
	        		WHEN vbak5.vbeln is not null
	        			and o_tfsfrt7.text_value is not null
	        			THEN o_tfsfrt7.text_value
	        		ELSE o_tfsfrt8.text_value
	        	END),
	        	(CASE
	        		WHEN sda.delivery_region_name = 'Китай'
	        			THEN 'SMM'
	        		ELSE 'ALS'
	        	END)
	        	) as metal_exchange_type
			,sda.is_shipped_via_overseas_warehouse								-- SD.000483 "Наличие Иностранный склад"
	   from sda_prev as sda -- 315307
	    -- SD.001250 "Фактура для statement"
	    left join dds.invoice as d_i													-- VBSK
	    	on d_i.invoice_code = sda.invoice_group_code						-- по VBSK-SAMMG = SD.001245 "Группа инвойс (statement)"
	    -- SD.001251 "Позиция фактуры для statement"
		left join dds.delivery_document_position as d_ddp_dni							-- LIPS
			on d_ddp_dni.delivery_code = sda.delivery_number_sales				-- по LIPS-VBELN = SD.000002 "Продажная поставка"
	    	and d_ddp_dni.batch_code = sda.batch								-- и LIPS-CHARG = SD.000004 "Партия"
		-- объединить с dds.invoice после добавления поля VBSK-ZZVBELN_VA, ZZKONDM
	    left join ods.vbsk_ral as vbsk1251										-- VBSK
	    	on vbsk1251.sammg = sda.invoice_group_code							-- по VBSK-SAMMG = SD.001245 "Группа инвойс (statement)"
	    -- заменить на dds после добавления поля VBAP-ZZFPOSNR
	    left join ods.vbap_ral as vbap											-- VBAP
	    	on vbap.zzlfvbeln = d_ddp_dni.delivery_code							-- VBAP-ZZLFVBELN = LIPS-VBELN
	    	and vbap.zzlfposnr = d_ddp_dni.delivery_position_line_item_code		-- VBAP-ZZLFPOSNR = LIPS-POSNR
	    	and vbap.vbeln = vbsk1251.zzvbeln_va							    -- VBAP-VBELN = VBSK-ZZVBELN_VA
	    -- заменить на dds после добавления поля VBRP-VGBEL, VBRP-VGPOS
	    left join distinct_vbrp as vbrp											-- VBRP
	    	on vbrp.vgbel = vbap.vbeln											-- VBRP-VGBEL = VBAP-VBELN
	    	and vbrp.vgpos = vbap.posnr											-- VBRP-VGPOS = VBAP-POSNR
	    -- SD.001362 "Дата оплаты" -- SD.001365 "Срок оплаты"
	    left join ods.zvbrk_ral as o_zr											-- ZVBRK
			on o_zr.vbeln = d_i.billing_document_code							-- по ZVBRK-VBELN = SD.001250 "Фактура для statement"
		-- SD.001366 "Условие платежа" -- SD.001369 "Рыночный индикатор (код)" -- SD.001380 "Рынок из заказа"
		--заменить на dds.invoice после добавления поля VBSK-ZZTERM
	    left join contract_type_ptc
	    	on contract_type_ptc.range_low_value = sda.contract_type_code
		left join  ods.vbsk_ral as vbsk2										-- VBSK
	    	on vbsk2.sammg = sda.lot_group										-- по VBSK-SAMMG = SD.000061 "Группа лот"
	     left join dds.sales_request as d_sr											-- /RUSAL/SD2882M
	    	on d_sr.sales_request_code = sda.sales_order	                    -- по /RUSAL/SD2882M-ZAKAZ_KL = SD.000123 "Заказ ЦК"
	    	and sales_order_version_code = '00'                                 -- (/RUSAL/SD2882M-NUMVR = "00")
	    	and d_sr.dt_shipment_yyyymm = to_char(sda.dt_shipment, 'yyyymm')	-- и /RUSAL/SD2882M-REG_PERIO = SD.000010 "Дата отгрузки" в формате "ггггмм" формате "ггггмм"
            and is_not_valid_for_reporting is not true
	    --заменить на dds после добавления поля VBAK-KUNAG, VBAK-GUEBG, VBAK-GUEEN
	    left join vbak1366														-- VBAK
	    	on vbak1366.kunnr = sda.customer_for_reporting_code  				-- по VBAK-KUNNR = SD.000036 "Покупатель (код)"
	   --заменить на dds в темп после добавления поля VBAK-KUNAG, VBAK-GUEBG, VBAK-GUEEN
	    left join vbak2															-- VBAK
	    	on vbak2.kunnr = sda.customer_for_reporting_code  					-- по VBAK-KUNNR = SD.000036 "Покупатель (код)"
	   --заменить на dds после добавления VBKD-ZTERM
	    left join ods.vbkd_ral as vbkd												-- VBKD
	    	on vbkd.vbeln = vbak2.vbeln											-- по VBKD-VBELN = VBAK-VBELN
	    -- SD.001371 "Тип биржи"
	    left join ods.texts_from_sap_fm_read_text as o_tfsfrt1						-- ФМ READ_TEXT
			on o_tfsfrt1.text_key_identifier_code = d_i.billing_document_code	-- по TDNAME = VBSK-ZZVBELN
			and o_tfsfrt1.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt1.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt1.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt1.is_active is true
		-- п.2
		left join vbsk															-- VBSK (SMART = "O")
			on vbsk.sales_contract_code = sda.sales_contract_code				-- по VBSK-ZZVBELN_RAM = SD.000179 "Контракт (код)"
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt2						-- ФМ READ_TEXT
			on o_tfsfrt2.text_key_identifier_code = vbsk.billing_document_code	-- по TDNAME = VBSK-ZZVBELN
			and o_tfsfrt2.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt2.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt2.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt2.is_active is true
		-- п.3
		left join ods.vbak_ral as vbak3												-- VBAK
			on vbak3.vbeln = sda.sales_contract_code							-- по VBAK-VBELN = SD.000179 "Контракт (код)"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt3						-- ФМ READ_TEXT
			on o_tfsfrt3.text_key_identifier_code = vbak3.vbeln					-- по TDNAME =  VBAK-VBELN
			and o_tfsfrt3.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt3.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt3.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt3.is_active is true
		left join vbak4															-- VBAK (VBAK-AUART = "ZDGS")
			on vbak4.zuonr = sda.sales_contract_code							-- по VBAK-ZUONR = SD.000179 "Контракт (код)"
		left join vbap2																-- VBAP
	    	on vbap2.vbeln = vbak4.vbeln										-- VBAP-VBELN = VBAK-VBELN
	    --
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt4					-- ФМ READ_TEXT
			on o_tfsfrt4.text_key_identifier_code = vbap2.vbeln_posnr			-- по TDNAME =  VBAP-POSNR
			and o_tfsfrt4.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt4.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt4.application_object_code = 'VBBK'		 			-- и TDOBJECT = VBBK
			and o_tfsfrt4.is_active is true
		-- п.4
		left join vbsk4		 -- 315307						         			-- VBSK (SMART = "O")
			on vbsk4.zzkunag = sda.sales_contract_code							-- по VBSK-ZZKUNAG = SD.000179 "Контракт (код)"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt5						-- ФМ READ_TEXT
			on o_tfsfrt5.text_key_identifier_code = vbsk4.zzvbeln				-- по TDNAME = VBSK-ZZVBELN
			and o_tfsfrt5.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt5.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt5.application_object_code = 'VBBK'		 			-- и TDOBJECT = VBBK
			and o_tfsfrt5.is_active is true
		-- п.5
		left join vbak7														-- VBAK
	    	on vbak7.kunnr = sda.customer_for_reporting_code  					-- по VBAK-KUNAG (kunnr) = SD.000036 "Покупатель (код)"
	    --
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt6					-- ФМ READ_TEXT
			on o_tfsfrt6.text_key_identifier_code = vbak7.vbeln					-- по TDNAME = VBSK-VBELN
			and o_tfsfrt6.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt6.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt6.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt6.is_active is true
		--
		left join vbak5																-- VBAK
	    	on vbak5.kunnr = sda.customer_for_reporting_code  					-- по VBAK-KUNAG (kunnr) = SD.000036 "Покупатель (код)"
	    --
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt7						-- ФМ READ_TEXT
			on o_tfsfrt7.text_key_identifier_code = vbak5.vbeln	 				-- по TDNAME = VBSK-VBELN
			and o_tfsfrt7.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt7.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt7.application_object_code = 'VBBK' 					-- и TDOBJECT = VBB
			and o_tfsfrt7.is_active is true
		left join vbak6
			on vbak6.zuonr = coalesce(vbak4.vbeln, vbak5.vbeln)
		--
		 left join ods.texts_from_sap_fm_read_text as o_tfsfrt8					-- ФМ READ_TEXT
			on o_tfsfrt8.text_key_identifier_code = vbak6.vbeln					-- по TDNAME = VBSK-VBELN
			and o_tfsfrt8.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt8.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt8.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt8.is_active is true
		-- SD.001375 "Фактура реализации"
		left join vbsk_vbss_1375	-- VBSS_VBSK
			on vbsk_vbss_1375.delivery_code = sda.delivery_number_sales				-- по VBSS_VBSK_VBELN = SD.000002 "Продажная поставка"
		--
		left join ods.vbrk_ral as vbrk												-- VBRK
			on vbrk.zzsammg = vbsk_vbss_1375.invoice_realization_group_code 	-- по VBRK-ZZSAMMG = VBSK-SAMMG
			and vbrk.rfbsk = 'C'											-- и VBRK-RFBSK = "C" (лат)
---!!! после добавления полей fkstoб sfakn в вбрк 10.12.2025 снять коммент и перезалить на юзердату
				--and vbrk.fksto IS NULL 										-- и VBRK-FKSTO пусто
				--and vbrk.sfakn IS NULL 										-- и VBRK-SFAKN пусто
		-- SD.001378 "Трейдер"
		left join dict_dds.map_counterparty_to_market_region2 as dd_mctmr2_cfrc		-- ZTSD_REG_CLIENT
			on dd_mctmr2_cfrc.counterparty_code = sda.is_shipped_via_overseas_warehouse	-- по ZVSD_REG_CLIENT-KUNNR_CODE = SD.000483 "Наличие Иностранный склад"
		-- SD.001379 "Номер предоплатного инвойса"
		left join ods."/rusal/sd2921mgo_ral" as mgo								-- /RUSAL/SD2921MGO
			on mgo.sammg_o = sda.invoice_group_code 							-- по /RUSAL/SD2921MGO-SAMMG_O = SD.001245 "Группа инвойс (statement)"
		--
		left join ods.vbsk_ral as vbsk5												-- VBSK
			on vbsk5.sammg = mgo.sammg											-- по VBSK-SAMMG = /RUSAL/SD2921MGO-SAMMG
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_sda_processed_data_prev;
create temp table statement_sda_processed_data_prev as (
	    select --count(*)
	         od.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,od.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,od.plant_producer_name  									-- SD.000007 "Завод"
			,od.port_of_loading_name  									-- SD.000009 "Направление"
			,od.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,od.material_aggr_name  									-- SD.000016 "Материал"
			,od.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,od.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,od.dt_warehouse  											-- SD.000024 "Дата склада"
			,od.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,od.weight_net  											-- SD.000032 "Вес нетто"
			,od.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,od.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,od.contract_name  											-- SD.000038 "Контракт"
			,od.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,od.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,od.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
			,od.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,od.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,od.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,od.delivery_basis  										-- SD.000067 "Базис поставки"
			,od.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,od.sales_order  											-- SD.000123 "Заказ ЦК"
			,od.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,od.grade_name  											-- SD.000145 "Марка по спецификации"
			,od.uni 													-- SD.000151 "UNI"
			,od.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,od.end_user_name  											-- SD.000164 "Конечный потребитель"
			,od.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,od.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,od.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,od.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,od.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,od.material_shape_name_full  								-- SD.000180 "Форма"
			,od.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,od.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,od.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,od.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,od.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,od.lot_code  												-- SD.000580 "Номер лота"
			,od.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,od.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,od.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,od.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,od.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,od.dt_realization 											-- SD.000720 "Дата реализации"
			,od.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,od.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,od.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,od.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
			,od.dt_report_yyyy 											-- SD.001246 "Год отчета (statement)"
			,od.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,od.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,od.net_weight 												-- SD.001249 "Вес для statement"
			,od.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,od.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
			,od.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,od.dt_payment												-- SD.001362 "Дата оплаты"
			,EXTRACT (week from od.dt_payment)::integer
				as dt_payment_week										-- SD.001363 "Неделя оплаты"
			,to_char(od.dt_payment, 'mm.yyyy') as dt_payment_mm			-- SD.001364 "Месяц оплаты"
			,od.dt_due_payment											-- SD.001365 "Срок оплаты"
			,od.payment_terms_code										-- SD.001366 "Условие платежа"
			,dd_topd.payment_terms_days_quantity				-- /RUSAL/ZTERM-DAYS1
				as payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
			,dd_ptdt.payment_terms_document_name				-- D007T-DDTEXT
				as payment_terms_document_name							-- SD.001368 "Условие платежа (документ)"
			,od.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,dd_mpgt.material_price_group_name					-- T178-VTEXT
				as market_indicator_name								-- SD.001370 "Тип рыночного индикатора"
			,dd_certt.currency_exchange_rate_type_name			-- TCURW-CURVW
				as metal_exchange_type_code								-- SD.001371 "Тип биржи"
			,od.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
			,od.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
			,od.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
			,od.invoice_realization_code								-- SD.001375 "Фактура реализации"
			,CASE
				WHEN vbrk.waerk = 'USD'							-- Если VBRK-WAERK = "USD",
					THEN 1										-- то "1",
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate != 1						-- и BKPF-KURSF != 1,
					THEN bkpf.exchange_rate							-- то BKPF-KURSF,
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate = 1						-- и BKPF-KURSF = 1,
					THEN dd_cr.currency_rate					-- то TCURR-UKURS,
				WHEN od.statement_invoice_code IS NULL
					-- если SD.001375 "Фактура реализации" пусто,
					THEN replace(o_tfsfrt9.text_value, '-', '')::numeric -- то ФМ READ_TEXT-текст TR29
			END::numeric
			as currency_exchange_rate									-- SD.001376 "Валютный курс"
			,od.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,od.is_trader_name											-- SD.001378 "Трейдер"
			,od.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,od.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,coalesce(vbrp.brgew,								-- VBRP-BRGEW,
				od.weight_net)  								-- если VBRP-BRGEW пусто, то SD.000032 "Вес нетто"
				as statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
			,od.block
			-------------------------------------------
			,od.batch
			,od.release_material_status_code
			,od.contract_type_code
			,od.double_record_in_temporary_warehouse_code
			,od.warehouse_shipment_type_name
			,od.shipment_market_code
			,od.delivery_number_outbound
			,od.plant_producer_code
	        ,CASE
	            WHEN od.realization_year = od.shipment_year
	            	THEN od.shipment_year
	            ELSE NULL
	        END as year_diff
	        ,od.realization_year
	        ,od.shipment_year
	        ,od.lot_group
	        ,od.sales_contract_code
	        ,od.metal_exchange_type
	        ,od.is_shipped_via_overseas_warehouse							-- SD.000483 "Наличие Иностранный склад"
	    from statement_sda_original_data as od
		-- SD.001367 "Условие платежа (дни)"
		left join dd_topd																-- /RUSAL/ZTERM
			on dd_topd.terms_of_payment_code = od.payment_terms_code			-- по /RUSAL/ZTERM-ZTERM = SD.001366 "Условие платежа"
		-- SD.001368 "Условие платежа (документ)"
		left join dict_dds.tech_rusal_paydocev as dd_trp								-- /RUSAL/PAYDOCEV
			on dd_trp.event = dd_topd.payment_event_code							-- по /RUSAL/PAYDOCEV-EVENT = /RUSAL/ZTERM-SOB1
		--
		left join dict_dds.payment_terms_document_texts as dd_ptdt					-- D007T
			on dd_ptdt.payment_terms_document_code = dd_trp.docum				-- по D007T-DOMVALUE_L = /RUSAL/PAYDOCEV-DOCUM
			and dd_ptdt.language_code = 'E'									-- и D007T-DOLANGUAGE = "EN"
		-- SD.001370 "Тип рыночного индикатора"
		left join dict_dds.material_price_group_texts as dd_mpgt 						-- T178
			on dd_mpgt.material_price_group_code = od.market_indicator_code		-- T178-KONDM = SD.001369 "Рыночный индикатор (код)"
			and dd_mpgt.language_code = 'E'									-- и T178- = "EN"
		-- SD.001371 "Тип биржи"
		left join dict_dds.currency_exchange_rate_type_texts as dd_certt				-- TCURW
			on dd_certt.currency_exchange_rate_type_code =	od.metal_exchange_type	-- TCURW-KURST = текст из заголовка ФМ READ_TEXT								-- текст из заголовка ФМ READ_TEXT
			and dd_certt.language_code = 'E'								-- TCURW-SPRAS = "EN"
		-- SD.001376 "Валютный курс"
	    left join ods.vbrk_ral as vbrk	 											-- VBRK
	    	on vbrk.vbeln = od.statement_invoice_code 							-- по VBRK-VBELN = SD.001250 "Фактура для statement"
	    --
	    left join dm_calc.accounting_document_header as bkpf
	    	on bkpf.reference_object_key_code = od.invoice_realization_code -- по BKPF-AWKEY = -- SD.001375 "Фактура реализации"
	    	--
	    left join dict_dds.currency_rates as dd_cr								-- TCURR
	    	on dd_cr.currency_from_code = bkpf.document_currency_code -- по TCURR-FCURR = BKPF-WAERS
	    	and dd_cr.dt_currency_rate = bkpf.dt_posting	 -- и TCURR-GDATU = BKPF-BUDAT
	    	and dd_cr.currency_rate_type_code = 'M'							-- и TCURR-KURST = "M"
	    	and dd_cr.currency_to_code = 'USD'									-- и TCURR-TCURR = "USD"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt9						-- ФМ READ_TEXT
			on o_tfsfrt9.text_key_identifier_code = vbrk.vbeln					-- по TDNAME = VBRK-VBELN
			and o_tfsfrt9.text_object_identifier_code = 'TR29'				-- и TDID = TR29
			and o_tfsfrt9.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt9.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt9.is_active is true
		-- SD.001381 "Расчетный вес STATEMENT"
		left join ods.vbrp_ral as vbrp												-- VBRP
			on vbrp.vbeln = od.statement_invoice_code 							-- по VBRP-VBELN = SD.001250 "Фактура для statement"
			and vbrp.posnr = od.statement_invoice_position_code 			-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
			and vbrp.kvgr5 = '010'											-- и VBRP-KVGR5 = "010"	*/
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_sda;
create temp table statement_sda as (
	WITH processed_data as (
	select --count(*)
		 pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,(vbrp.netwr / pd.currency_exchange_rate)	-- VBRP-NETWR / SD.001376 "Валютный курс"
		,case
				when pd.currency_exchange_rate < 0 then vbrp.netwr / abs(pd.currency_exchange_rate)
				when pd.currency_exchange_rate > 0 then vbrp.netwr * abs(pd.currency_exchange_rate)
		end as usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,vbrp.netwr 								-- VBRP-NETWR
			as document_currency_vat_excluded_amound				-- SD.001373 "Стоимость в исходной валюте"
		,case
				when pd.currency_exchange_rate < 0 then (vbrp.netwr + vbrp.mwsbp) / abs(pd.currency_exchange_rate)
				when pd.currency_exchange_rate > 0 then (vbrp.netwr + vbrp.mwsbp) * abs(pd.currency_exchange_rate)
		end as usd_currency_vat_included_amound					-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
		,pd.realization_year
		,pd.shipment_year
		,pd.year_diff
	from statement_sda_processed_data_prev as pd
	-- SD.001372 "Стоимость" -- SD.001373 "Стоимость в исходной валюте" -- SD.001374 "Стоимость с НДС"
	left join ods.vbrp_ral as vbrp										-- VBRP
	    on vbrp.vbeln = pd.statement_invoice_code 					-- по VBRP-VBELN = SD.001250 "Фактура для statement"
	    and vbrp.posnr = pd.statement_invoice_position_code 	-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
    	)
	select
		 pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.shipment_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,pd.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,pd.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,pd.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from processed_data as pd
	where pd.year_diff is not null
	UNION ALL
	select
	     pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.realization_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,pd.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,pd.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,pd.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from processed_data as pd
	where pd.year_diff is not null
	UNION ALL
	select
	     pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.shipment_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,pd.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,pd.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,pd.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from processed_data as pd
	where pd.year_diff IS NULL
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_real; -- Блок Реализованный металл
create temp table statement_real as (
	select
	     ss.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,ss.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,ss.plant_producer_name  									-- SD.000007 "Завод"
		,ss.port_of_loading_name  									-- SD.000009 "Направление"
		,ss.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,ss.material_aggr_name  									-- SD.000016 "Материал"
		,ss.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,ss.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,ss.dt_warehouse  											-- SD.000024 "Дата склада"
		,ss.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,ss.weight_net  											-- SD.000032 "Вес нетто"
		,ss.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,ss.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,ss.contract_name  											-- SD.000038 "Контракт"
		,ss.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,ss.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,ss.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,ss.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,ss.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,ss.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,ss.delivery_basis  										-- SD.000067 "Базис поставки"
		,ss.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,ss.sales_order  											-- SD.000123 "Заказ ЦК"
		,ss.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,ss.grade_name  											-- SD.000145 "Марка по спецификации"
		,ss.uni 													-- SD.000151 "UNI"
		,ss.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,ss.end_user_name  											-- SD.000164 "Конечный потребитель"
		,ss.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,ss.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,ss.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,ss.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,ss.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,ss.material_shape_name_full  								-- SD.000180 "Форма"
		,ss.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,ss.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,ss.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,ss.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,ss.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,ss.lot_code  												-- SD.000580 "Номер лота"
		,ss.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,ss.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,ss.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,ss.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,ss.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,ss.dt_realization 											-- SD.000720 "Дата реализации"
		,ss.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,ss.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,ss.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,ss.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,ss.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,ss.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,ss.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,ss.net_weight 												-- SD.001249 "Вес для statement"
		,ss.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,ss.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,ss.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,ss.dt_payment												-- SD.001362 "Дата оплаты"
		,ss.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,ss.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,ss.dt_due_payment											-- SD.001365 "Срок оплаты"
		,ss.payment_terms_code										-- SD.001366 "Условие платежа"
		,ss.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
		,ss.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,ss.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,ss.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,ss.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,ss.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,ss.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,ss.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,ss.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,ss.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,ss.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,ss.is_trader_name											-- SD.001378 "Трейдер"
		,ss.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,ss.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,ss.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,'Реализованный металл'::varchar as block
		-------------------------------------------
		,ss.batch
		,ss.release_material_status_code
		,ss.contract_type_code
		,ss.double_record_in_temporary_warehouse_code
		,ss.warehouse_shipment_type_name
		,ss.shipment_market_code
		,ss.delivery_number_outbound
		,ss.plant_producer_code
		,ss.lot_group
		,ss.sales_contract_code
		,ss.metal_exchange_type
		,ss.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_sda as ss
	where ss.business_location_name != 'Status Smelter WH'			-- SD.000492 "Статус в Supply chain (Business)" != "Status Smelter WH"
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_plan_original_data; -- Плановый металл:
create temp table statement_plan_original_data as (
		select
			tech_etl.util_text_to_null_validation(exp01."VBELN") as delivery_number_initial, 									-- SD.000001 "Исходная поставка"
			tech_etl.util_text_to_null_validation(exp01."VBELN_P") as delivery_number_sales, 									-- SD.000002 "Продажная поставка"
			tech_etl.util_text_to_null_validation(exp01."PLANT_TXT") as plant_producer_name, 									-- SD.000007 "Завод"
			tech_etl.util_text_to_null_validation(exp01."LOCNAM") as port_of_loading_name, 										-- SD.000009 "Направление"
			tech_etl.util_text_to_date_validation(exp01."DATEOT") as dt_shipment, 												-- SD.000010 "Дата отгрузки"
			tech_etl.util_text_to_null_validation(exp01."PIMARY") as material_aggr_name, 										-- SD.000016 "Материал"
			tech_etl.util_text_to_null_validation(exp01."MATKL") as material_group_code, 										-- SD.000017 "Группа материалов (код)"
			tech_etl.util_text_to_null_validation(exp01."MARKET_TXT") as shipment_market_name, 									-- SD.000019 "Рынок в отгрузке"
			tech_etl.util_text_to_date_validation(exp01."DATASKL") as dt_warehouse, 											-- SD.000024 "Дата склада"
			tech_etl.util_text_to_null_validation(exp02."SDABW_TXT") as transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
			exp02."LFIMG"::numeric as weight_net, 																				-- SD.000032 "Вес нетто"
			tech_etl.util_text_to_null_validation(exp02."KUNNR") as customer_for_reporting_code, 								-- SD.000036 "Покупатель (код)"
			tech_etl.util_text_to_null_validation(exp02."KUNNR_TXT") as customer_for_reporting_name, 							-- SD.000037 "Покупатель"
			tech_etl.util_text_to_null_validation(exp02."BSTKD") as contract_name, 												-- SD.000038 "Контракт"
			tech_etl.util_text_to_null_validation(exp02."VTEXT_Y") as bill_of_lading_number, 									-- SD.000041 "Номер коносамента"
			tech_etl.util_text_to_date_validation(exp02."LDDAT_Y") as dt_bill_of_lading, 										-- SD.000042 "Дата коносамента"
			tech_etl.util_text_to_null_validation(exp02."PORT_Y_TXT") as port_of_discharge_name,								-- SD.000045 "Порт выгрузки"
			tech_etl.util_text_to_null_validation(exp02."VTEXT_KOP") as bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
			tech_etl.util_text_to_date_validation(exp02."LDDAT_KOP") as dt_bill_of_lading_in_foreign_port, 						-- SD.000049 "Дата коносамента в ин.порту"
			tech_etl.util_text_to_date_validation(exp02."DATE_ARRIV") as dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
			tech_etl.util_text_to_null_validation(exp02."BASIS") as delivery_basis, 											-- SD.000067 "Базис поставки"
			tech_etl.util_text_to_null_validation(exp02."BASIS2") as delivery_point_name, 										-- SD.000068 "Пункт доставки по инкотермс"
			tech_etl.util_text_to_null_validation(exp02."ZAKAZ_KL") as sales_order, 											-- SD.000123 "Заказ ЦК"
			tech_etl.util_text_to_date_validation(exp02."DATE_ETADP") as dt_arrival_in_port_of_discharge_plan, 					-- SD.000130 "Дата прибытия в порт выгрузки план"
			tech_etl.util_text_to_null_validation(exp02."MMBS_NAME") as grade_name, 											-- SD.000145 "Марка по спецификации"
			tech_etl.util_text_to_null_validation(exp02."UNI") as uni, 															-- SD.000151 "UNI"
			tech_etl.util_text_to_date_validation(exp02."ETADP_KOP") as dt_arrival_in_second_port_of_discharge_plan,			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			tech_etl.util_text_to_null_validation(exp03."KUNNR_END_TXT") as end_user_name, 										-- SD.000164 "Конечный потребитель"
			tech_etl.util_text_to_null_validation(exp03."VTEXT_PIN") as invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
			tech_etl.util_text_to_date_validation(exp03."WH_DATE_POD") as dt_storage_start_in_foreign_port, 					-- SD.000175 "Дата начала хранения ин. склад"
			tech_etl.util_text_to_date_validation(exp03."ST_END_POD") as dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
			tech_etl.util_text_to_date_validation(exp03."START_STORAGE2") as dt_storage_start_in_second_foreign_warehouse, 		-- SD.000177 "Начало хранения склад 2 "
			tech_etl.util_text_to_date_validation(exp03."FINISH_STORAGE2") as dt_storage_end_in_second_foreign_warehouse, 		-- SD.000178 "Окончание хранение склад 2 "
			tech_etl.util_text_to_null_validation(exp02."FORMA_TXT") as material_shape_name_full, 								-- SD.000180 "Форма"
			tech_etl.util_text_to_null_validation(exp04."DELIV_REGION") as delivery_region_name, 								-- SD.000338 "Регион поставки по контракту"
			tech_etl.util_text_to_null_validation(exp02."LANDX_POD") as country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
			tech_etl.util_text_to_date_validation(exp04."READY_TO_SHIP_DATE") as dt_prepared_for_realization,					-- SD.000344 "Дата готовности к релизу"
			tech_etl.util_text_to_null_validation(exp04."STATUS_SCB") as business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
			tech_etl.util_text_to_null_validation(exp04."LANDX") as delivery_country_in_contract_name, 							-- SD.000576 "Страна поставки по контракту"
			tech_etl.util_text_to_null_validation(exp02."VTEXT_L") as lot_code, 												-- SD.000580 "Номер лота"
			NULL::varchar as customer_for_scm_report_name,																		-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			NULL::varchar as vessel_and_voyage_actual_search_name, 																-- SD.000608 "Судно / номер рейса (факт)"
			NULL::date as dt_invoice_provisional,																				-- SD.000620 "Дата инвойса"
			NULL::varchar as sales_team_name, 																					-- SD.000651 "Сбытовая команда"
			NULL::varchar as dt_quota_yyyymm, 																					-- SD.000687 "Квота"
			tech_etl.util_text_to_date_validation(exp03."LDDAT_REA") as dt_realization, 										-- SD.000720 "Дата реализации"
			NULL::varchar as is_tolling_code, 																					-- SD.000749 "Признак толлинг"
			NULL::varchar as warehouse_or_responsible_customer_for_storage_name, 												-- SD.000919 "General storage location"
			'Scheduled'::varchar as statement_data_group_code, 																	-- SD.001244 "Блок данных (statement)"
			NULL::varchar as invoice_group_code, 																				-- SD.001245 "Группа инвойс (statement)"
			NULL::varchar as dt_report_yyyy, 																					-- SD.001246 "Год отчета (statement)"
			NULL::varchar as purchase_invoice_code, 																			-- SD.001247 "Входящий счет (statement)"
			NULL::varchar as dt_purchase_invoice_yyyy, 																			-- SD.001248 "Год входящего счета (statement)"
			NULL::numeric as net_weight, 																						-- SD.001249 "Вес для statement"
			NULL::varchar as statement_invoice_code, 																			-- SD.001250 "Фактура для statement"
			NULL::varchar as statement_invoice_position_code, 																	-- SD.001251 "Позиция фактуры для statement"
			NULL::varchar  as supplier_3rd_party_code,																			-- SD.001361 "Внешний контрагент"
			NULL::date as dt_payment,																							-- SD.001362 "Дата оплаты"
			NULL::integer as dt_payment_week,																					-- SD.001363 "Неделя оплаты"
			NULL::varchar as dt_payment_mm,																						-- SD.001364 "Месяц оплаты"
			NULL::date as dt_due_payment,																						-- SD.001365 "Срок оплаты"
			coalesce(--vbsk1251.zzterm,												-- VBSK-ZZTERM по 1-у условию,
				(CASE
					WHEN contract_type_ptc.range_low_value IS NULL
						THEN vbsk2.zzterm
				END),																	-- если VBSK-ZZTERM по 1-у условию пусто, то VBSK-ZZTERM по 2-у условию,
				d_sr.terms_of_payment_code,												-- если VBSK-ZZTERM по 2-у условию пусто, то /RUSAL/SD2882M-ZTERM
				vbak1366.vbeln,																-- если /RUSAL/SD2882M-ZTERM пусто, то VBAK-VBELN
				vbkd.vbeln																-- если VBAK-VBELN пусто, то VBKD-ZTERM
				) as payment_terms_code,																						-- SD.001366 "Условие платежа"
			NULL::integer as payment_terms_days_quantity,																		-- SD.001367 "Условие платежа (дни)"
			NULL::varchar as payment_terms_document_name,																		-- SD.001368 "Условие платежа (документ)"
			coalesce(--vbsk1251.zzkondm,												-- VBSK-ZZKONDM по 1-у условию,
				(CASE
					WHEN contract_type_ptc.range_low_value IS NULL
						THEN vbsk2.zzkondm
				END)																	-- если VBSK-ZZKONDM по 1-у условию пусто, то VBSK-ZZKONDM по 2-у условию
				) as market_indicator_code,																						-- SD.001369 "Рыночный индикатор (код)"
			NULL::varchar as market_indicator_name,																				-- SD.001370 "Тип рыночного индикатора"
			NULL::varchar as metal_exchange_type_code,																			-- SD.001371 "Тип биржи"
			NULL::numeric as usd_currency_vat_excluded_amound,																	-- SD.001372 "Стоимость"
			NULL::numeric as document_currency_vat_excluded_amound,																-- SD.001373 "Стоимость в исходной валюте"
			NULL::numeric as usd_currency_vat_included_amound,																	-- SD.001374 "Стоимость с НДС"
			NULL::varchar as invoice_realization_code,																			-- SD.001375 "Фактура реализации"
			NULL::numeric as currency_exchange_rate,																				-- SD.001376 "Валютный курс"
			CASE
				WHEN tech_etl.util_text_to_null_validation(exp04."FWH_EXIST") IS NULL 	-- Если SD.000483 "Наличие Иностранный склад" пусто,
					THEN 'Direct delivery'												-- то "Direct delivery"
				ELSE 'Warehouse'														-- ианче "Warehouse"
			END	as direct_or_overseas_warehouse_delivery_name,																	-- SD.001377 "Склад/прямая поставка"
			CASE
				WHEN dd_mctmr2_cfrc.counterparty_code is not null 						-- Если SD.000036 "Покупатель (код)" есть в ZVSD_REG_CLIENT-KUNNR_CODE
					THEN 'Trader'														-- то "Trader",
				ELSE NULL																-- иначе пусто
			END	as is_trader_name,																								-- SD.001378 "Трейдер"
			NULL::varchar as prepayment_invoice_code,																			-- SD.001379 "Номер предоплатного инвойса"
			d_sr.sales_market_code	as sales_market_in_sales_request_code,	 -- /RUSAL/SD2882M-MARKET                           -- SD.001380 "Рынок из заказа"
			NULL::numeric as statement_calculated_weight,																		-- SD.001381 "Расчетный вес STATEMENT"
			'Плановый металл'::varchar as block,
			-------------------------------------------
			tech_etl.util_text_to_null_validation(exp01."CHARG") as batch,
			tech_etl.util_text_to_null_validation(exp04."WBSTK_ISH") as release_material_status_code,
			tech_etl.util_text_to_null_validation(exp04."BSARK") as contract_type_code,
			tech_etl.util_text_to_null_validation(exp01."SVH_02_EXIST") as double_record_in_temporary_warehouse_code,
			tech_etl.util_text_to_null_validation(exp03."SVH_TXT") as warehouse_shipment_type_name,
			tech_etl.util_text_to_null_validation(exp01."MARKET") as shipment_market_code,
			tech_etl.util_text_to_null_validation(exp03."VBELN_ISH") as delivery_number_outbound,
			tech_etl.util_text_to_null_validation(exp01."PLANT") as plant_producer_code,
			EXTRACT(YEAR from tech_etl.util_text_to_date_validation(exp03."LDDAT_REA"))::varchar as realization_year,
	        EXTRACT(YEAR from tech_etl.util_text_to_date_validation(exp01."DATEOT"))::varchar as shipment_year,
			tech_etl.util_text_to_null_validation(exp02."SAMMG_L") as lot_group,
			tech_etl.util_text_to_null_validation(exp03."BSTKD_CODE") as sales_contract_code,
			NULL::varchar as metal_exchange_type,
			tech_etl.util_text_to_null_validation(exp04."FWH_EXIST") as is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"*/
		from  stg."ZMK_TRACK_EXP03" as exp03
	    left join  stg."ZMK_TRACK_EXP01" as exp01
	     	on exp03."GUID_KEY" = exp01."GUID_KEY"
	    left join  stg."ZMK_TRACK_EXP02" as exp02
	     	on exp03."GUID_KEY" = exp02."GUID_KEY"
	    left join  stg."ZMK_TRACK_EXP04" as exp04
	     	on exp03."GUID_KEY" = exp04."GUID_KEY"
		-- SD.001366 "Условие платежа" -- SD.001369 "Рыночный индикатор (код)"
		--заменить на dds.invoice после добавления поля VBSK-ZZTERM
		left join contract_type_ptc
		   	on contract_type_ptc.range_low_value = tech_etl.util_text_to_null_validation(exp04."BSARK")
		--
		left join ods.vbsk_ral as vbsk2																-- VBSK
		   	on vbsk2.sammg = tech_etl.util_text_to_null_validation(exp02."SAMMG_L")					-- по VBSK-SAMMG = -- SD.000061 "Группа лот"
		left join dds.sales_request as d_sr															-- /RUSAL/SD2882M (/RUSAL/SD2882M-NUMVR = "00")
		   	on d_sr.sales_request_code = tech_etl.util_text_to_null_validation(exp02."ZAKAZ_KL") -- по /RUSAL/SD2882M-ZAKAZ_KL = SD.000123 "Заказ ЦК"
		   	and d_sr.dt_shipment_yyyymm = to_char(tech_etl.util_text_to_date_validation(exp01."DATEOT"), 'yyyymm') -- и /RUSAL/SD2882M-REG_PERIO = SD.000010 "Дата отгрузки" в формате "ггггмм"
			and d_sr.is_not_valid_for_reporting is not true
		 --заменить на dds после добавления поля VBAK-KUNAG, VBAK-GUEBG, VBAK-GUEEN
		left join vbak1366															-- VBAK
	    	on vbak1366.kunnr = tech_etl.util_text_to_null_validation(exp02."KUNNR")  	        -- по VBAK-KUNNR = SD.000036 "Покупатель (код)"
		--заменить на dds в темп после добавления поля VBAK-KUNAG, VBAK-GUEBG, VBAK-GUEEN
		left join vbak2																			-- VBAK
		   	on vbak2.kunnr = tech_etl.util_text_to_null_validation(exp02."KUNNR")  				-- по VBAK-KUNNR = SD.000036 "Покупатель (код)"
		--заменить на dds после добавления VBKD-ZTERM
		left join ods.vbkd_ral as vbkd																-- VBKD
		   	on vbkd.vbeln = vbak2.vbeln															-- по VBKD-VBELN = VBAK-VBELN
		-- SD.001378 "Трейдер"
		left join dict_dds.map_counterparty_to_market_region2 as dd_mctmr2_cfrc						-- ZTSD_REG_CLIENT
			on dd_mctmr2_cfrc.counterparty_code = tech_etl.util_text_to_null_validation(exp04."FWH_EXIST") -- по ZVSD_REG_CLIENT-KUNNR_CODE = SD.000483 "Наличие Иностранный склад"
		--
		where  exp03."PLFK" = 'P'
		and exp01."MARKET" IN ('1', '4')
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_plan_processed_data_prev;
create temp table statement_plan_processed_data_prev as (
		select
	         od.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,od.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,od.plant_producer_name  									-- SD.000007 "Завод"
			,od.port_of_loading_name  									-- SD.000009 "Направление"
			,od.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,od.material_aggr_name  									-- SD.000016 "Материал"
			,od.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,od.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,od.dt_warehouse  											-- SD.000024 "Дата склада"
			,od.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,od.weight_net  											-- SD.000032 "Вес нетто"
			,od.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,od.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,od.contract_name  											-- SD.000038 "Контракт"
			,od.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,od.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,od.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
			,od.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,od.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,od.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,od.delivery_basis  										-- SD.000067 "Базис поставки"
			,od.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,od.sales_order  											-- SD.000123 "Заказ ЦК"
			,od.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,od.grade_name  											-- SD.000145 "Марка по спецификации"
			,od.uni 													-- SD.000151 "UNI"
			,od.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,od.end_user_name  											-- SD.000164 "Конечный потребитель"
			,od.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,od.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,od.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,od.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,od.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,od.material_shape_name_full  								-- SD.000180 "Форма"
			,od.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,od.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,od.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,od.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,od.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,od.lot_code  												-- SD.000580 "Номер лота"
			,od.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,od.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,od.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,od.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,od.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,od.dt_realization 											-- SD.000720 "Дата реализации"
			,od.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,od.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,od.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,od.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
			,od.dt_report_yyyy 											-- SD.001246 "Год отчета (statement)"
			,od.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,od.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,od.net_weight 												-- SD.001249 "Вес для statement"
			,od.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,od.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
			,od.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,od.dt_payment												-- SD.001362 "Дата оплаты"
			,EXTRACT (week from od.dt_payment)::integer
				as dt_payment_week										-- SD.001363 "Неделя оплаты"
			,to_char(od.dt_payment, 'mm.yyyy') as dt_payment_mm			-- SD.001364 "Месяц оплаты"
			,od.dt_due_payment											-- SD.001365 "Срок оплаты"
			,od.payment_terms_code										-- SD.001366 "Условие платежа"
			,dd_topd.payment_terms_days_quantity				-- /RUSAL/ZTERM-DAYS1
				as payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
			,dd_ptdt.payment_terms_document_name				-- D007T-DDTEXT
				as payment_terms_document_name							-- SD.001368 "Условие платежа (документ)"
			,od.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,dd_mpgt.material_price_group_name					-- T178-VTEXT
				as market_indicator_name								-- SD.001370 "Тип рыночного индикатора"
			,dd_certt.currency_exchange_rate_type_name			-- TCURW-CURVW
				as metal_exchange_type_code								-- SD.001371 "Тип биржи"
			,od.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
			,od.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
			,od.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
			,od.invoice_realization_code								-- SD.001375 "Фактура реализации"
			,CASE
				WHEN vbrk.waerk = 'USD'							-- Если VBRK-WAERK = "USD",
					THEN 1										-- то "1",
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate != 1						-- и BKPF-KURSF != 1,
					THEN bkpf.exchange_rate						-- то BKPF-KURSF,
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate = 1						-- и BKPF-KURSF = 1,
					THEN dd_cr.currency_rate					-- то TCURR-UKURS,
				WHEN od.statement_invoice_code IS NULL
					-- если SD.001375 "Фактура реализации" пусто,
					THEN replace(o_tfsfrt9.text_value, '-', '')::numeric -- то ФМ READ_TEXT-текст TR29
			END::numeric
			as currency_exchange_rate									-- SD.001376 "Валютный курс"
			,od.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,od.is_trader_name											-- SD.001378 "Трейдер"
			,od.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,od.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,od. statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
			,od.block
			-------------------------------------------
			,od.batch
			,od.release_material_status_code
			,od.contract_type_code
			,od.double_record_in_temporary_warehouse_code
			,od.warehouse_shipment_type_name
			,od.shipment_market_code
			,od.delivery_number_outbound
			,od.plant_producer_code
	        ,CASE
	            WHEN od.realization_year = od.shipment_year
	            	THEN od.shipment_year
	            ELSE NULL
	        END as year_diff
	        ,od.realization_year
	        ,od.shipment_year
	        ,od.lot_group
	        ,od.sales_contract_code
	        ,od.metal_exchange_type
	        ,od.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	    from statement_plan_original_data as od
		-- SD.001367 "Условие платежа (дни)"
		left join dd_topd						-- /RUSAL/ZTERM
			on dd_topd.terms_of_payment_code = od.payment_terms_code			-- по /RUSAL/ZTERM-ZTERM = SD.001366 "Условие платежа" и /RUSAL/ZTERM-MODUL = "SD"
		-- SD.001368 "Условие платежа (документ)"
		left join dict_dds.tech_rusal_paydocev as dd_trp								-- /RUSAL/PAYDOCEV
			on dd_trp.event = dd_topd.payment_event_code							-- по /RUSAL/PAYDOCEV-EVENT = /RUSAL/ZTERM-SOB1
		--
		left join dict_dds.payment_terms_document_texts as dd_ptdt					-- D007T
			on dd_ptdt.payment_terms_document_code = dd_trp.docum				-- по D007T-DOMVALUE_L = /RUSAL/PAYDOCEV-DOCUM
			and dd_ptdt.language_code = 'E'									-- и D007T-DOLANGUAGE = "EN"
		-- SD.001370 "Тип рыночного индикатора"
		left join dict_dds.material_price_group_texts as dd_mpgt 						-- T178
			on dd_mpgt.material_price_group_code = od.market_indicator_code		-- T178-KONDM = SD.001369 "Рыночный индикатор (код)"
			and dd_mpgt.language_code = 'E'
		-- SD.001371 "Тип биржи"
		left join dict_dds.currency_exchange_rate_type_texts as dd_certt				-- TCURW
			on dd_certt.currency_exchange_rate_type_code =	od.metal_exchange_type	-- TCURW-KURST = текст из заголовка ФМ READ_TEXT
			and dd_certt.language_code = 'E'								-- TCURW-SPRAS = "EN"
		-- SD.001376 "Валютный курс"
	    left join ods.vbrk_ral as vbrk												-- VBRK
	    	on vbrk.vbeln = od.statement_invoice_code 							-- по VBRK-VBELN = SD.001250 "Фактура для statement"
   --
	    left join dm_calc.accounting_document_header as bkpf
	    	on bkpf.reference_object_key_code = od.invoice_realization_code -- по BKPF-AWKEY = -- SD.001375 "Фактура реализации"
	    	--
	    left join dict_dds.currency_rates as dd_cr								-- TCURR
	    	on dd_cr.currency_from_code = bkpf.document_currency_code -- по TCURR-FCURR = BKPF-WAERS
	    	and dd_cr.dt_currency_rate = bkpf.dt_posting	 -- и TCURR-GDATU = BKPF-BUDAT
	    	and dd_cr.currency_rate_type_code = 'M'							-- и TCURR-KURST = "M"
	    	and dd_cr.currency_to_code = 'USD'									-- и TCURR-TCURR = "USD"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt9					-- ФМ READ_TEXT
			on o_tfsfrt9.text_key_identifier_code = vbrk.vbeln				    -- по TDNAME = VBRK-VBELN
			and o_tfsfrt9.text_object_identifier_code = 'TR29'				-- и TDID = TR29
			and o_tfsfrt9.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt9.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt9.is_active is true
)
distributed by (delivery_number_sales,batch);

drop table if exists statement_plan_processed_data;
create temp table statement_plan_processed_data as (
		select
			 pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,pd.plant_producer_name  									-- SD.000007 "Завод"
			,pd.port_of_loading_name  									-- SD.000009 "Направление"
			,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,pd.material_aggr_name  									-- SD.000016 "Материал"
			,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,pd.dt_warehouse  											-- SD.000024 "Дата склада"
			,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,pd.weight_net  											-- SD.000032 "Вес нетто"
			,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,pd.contract_name  											-- SD.000038 "Контракт"
			,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
			,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,pd.delivery_basis  										-- SD.000067 "Базис поставки"
			,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,pd.sales_order  											-- SD.000123 "Заказ ЦК"
			,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,pd.grade_name  											-- SD.000145 "Марка по спецификации"
			,pd.uni 													-- SD.000151 "UNI"
			,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
			,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,pd.material_shape_name_full  								-- SD.000180 "Форма"
			,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,pd.lot_code  												-- SD.000580 "Номер лота"
			,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,pd.dt_realization 											-- SD.000720 "Дата реализации"
			,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
			,pd.shipment_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
			,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,pd.net_weight 												-- SD.001249 "Вес для statement"
			,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
			,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,pd.dt_payment												-- SD.001362 "Дата оплаты"
			,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
			,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
			,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
			,pd.payment_terms_code										-- SD.001366 "Условие платежа"
			,pd. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
			,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
			,pd. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
			,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
			,case
				when pd.currency_exchange_rate < 0 then vbrp.netwr / abs(pd.currency_exchange_rate)
				when pd.currency_exchange_rate > 0 then vbrp.netwr * abs(pd.currency_exchange_rate)
			end as usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
			,vbrp.netwr 								-- VBRP-NETWR
			as document_currency_vat_excluded_amound				-- SD.001373 "Стоимость в исходной валюте"
			,case
				when pd.currency_exchange_rate < 0 then (vbrp.netwr + vbrp.mwsbp) / abs(pd.currency_exchange_rate)
				when pd.currency_exchange_rate > 0 then (vbrp.netwr + vbrp.mwsbp) * abs(pd.currency_exchange_rate)
			end as usd_currency_vat_included_amound					-- SD.001374 "Стоимость с НДС"
			,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
			,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
			,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,pd.is_trader_name											-- SD.001378 "Трейдер"
			,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
			,pd.block
			-------------------------------------------
			,pd.batch
			,pd.release_material_status_code
			,pd.contract_type_code
			,pd.double_record_in_temporary_warehouse_code
			,pd.warehouse_shipment_type_name
			,pd.shipment_market_code
			,pd.delivery_number_outbound
			,pd.plant_producer_code
			,pd.lot_group
			,pd.sales_contract_code
			,pd.metal_exchange_type
			,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
			,pd.realization_year
			,pd.shipment_year
			,pd.year_diff
		from statement_plan_processed_data_prev as pd
		-- SD.001372 "Стоимость" -- SD.001373 "Стоимость в исходной валюте" -- SD.001374 "Стоимость с НДС"
		left join ods.vbrp_ral as vbrp										-- VBRP
		    on vbrp.vbeln = pd.statement_invoice_code 					-- по VBRP-VBELN = SD.001250 "Фактура для statement"
		    and vbrp.posnr = pd.statement_invoice_position_code 	-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
	)
	distributed by (delivery_number_sales,batch);

drop table if exists statement_plan;
create temp table statement_plan as (
	select
		 pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.shipment_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,pd.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,pd.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,pd.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_plan_processed_data as pd
	where pd.year_diff is not null
	UNION ALL
	select
	     pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.realization_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,pd.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,pd.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,pd.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_plan_processed_data as pd
	where pd.year_diff is not null
	UNION ALL
	select
	     pd.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,pd.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,pd.plant_producer_name  									-- SD.000007 "Завод"
		,pd.port_of_loading_name  									-- SD.000009 "Направление"
		,pd.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,pd.material_aggr_name  									-- SD.000016 "Материал"
		,pd.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,pd.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,pd.dt_warehouse  											-- SD.000024 "Дата склада"
		,pd.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,pd.weight_net  											-- SD.000032 "Вес нетто"
		,pd.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,pd.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,pd.contract_name  											-- SD.000038 "Контракт"
		,pd.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,pd.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,pd.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,pd.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,pd.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,pd.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,pd.delivery_basis  										-- SD.000067 "Базис поставки"
		,pd.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,pd.sales_order  											-- SD.000123 "Заказ ЦК"
		,pd.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,pd.grade_name  											-- SD.000145 "Марка по спецификации"
		,pd.uni 													-- SD.000151 "UNI"
		,pd.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,pd.end_user_name  											-- SD.000164 "Конечный потребитель"
		,pd.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,pd.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,pd.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,pd.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,pd.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,pd.material_shape_name_full  								-- SD.000180 "Форма"
		,pd.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,pd.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,pd.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,pd.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,pd.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,pd.lot_code  												-- SD.000580 "Номер лота"
		,pd.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,pd.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,pd.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,pd.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,pd.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,pd.dt_realization 											-- SD.000720 "Дата реализации"
		,pd.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,pd.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,pd.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,pd.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,pd.shipment_year::varchar as dt_report_yyyy				-- SD.001246 "Год отчета (statement)"
		,pd.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,pd.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,pd.net_weight 												-- SD.001249 "Вес для statement"
		,pd.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,pd.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,pd.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,pd.dt_payment												-- SD.001362 "Дата оплаты"
		,pd.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,pd.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,pd.dt_due_payment											-- SD.001365 "Срок оплаты"
		,pd.payment_terms_code										-- SD.001366 "Условие платежа"
		,pd.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
		,pd.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,pd.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,pd.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,pd.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,pd.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,pd.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,pd.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,pd.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,pd.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,pd.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,pd.is_trader_name											-- SD.001378 "Трейдер"
		,pd.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,pd.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,pd.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,pd.block
		-------------------------------------------
		,pd.batch
		,pd.release_material_status_code
		,pd.contract_type_code
		,pd.double_record_in_temporary_warehouse_code
		,pd.warehouse_shipment_type_name
		,pd.shipment_market_code
		,pd.delivery_number_outbound
		,pd.plant_producer_code
		,pd.lot_group
		,pd.sales_contract_code
		,pd.metal_exchange_type
		,pd.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_plan_processed_data as pd
	where pd.year_diff IS NULL
	)
distributed by (delivery_number_sales,batch);

-- Общий источник для дальнейших блоков
drop table if exists statement_tot;
create temp table statement_tot as (
	select * from statement_sda
	UNION ALL
	select * from statement_real
	UNION ALL
	select * from statement_plan
	)
distributed by (delivery_number_sales,batch);

-- Блок Финальный/корректирующий инвойс
drop table if exists statement_fci_prev;
create temp table statement_fci_prev as (
		select
		distinct
			 statement_tot.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,statement_tot.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,statement_tot.plant_producer_name  									-- SD.000007 "Завод"
			,statement_tot.port_of_loading_name  									-- SD.000009 "Направление"
			,statement_tot.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,statement_tot.material_aggr_name  										-- SD.000016 "Материал"
			,statement_tot.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,statement_tot.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,statement_tot.dt_warehouse  											-- SD.000024 "Дата склада"
			,statement_tot.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,statement_tot.weight_net  												-- SD.000032 "Вес нетто"
			,statement_tot.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,statement_tot.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,statement_tot.contract_name  											-- SD.000038 "Контракт"
			,statement_tot.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,statement_tot.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,statement_tot.port_of_discharge_name  									-- SD.000045 "Порт выгрузки"
			,statement_tot.bill_of_lading_in_foreign_port  							-- SD.000048 "Коносамент в ин.порту"
			,statement_tot.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,statement_tot.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,statement_tot.delivery_basis  											-- SD.000067 "Базис поставки"
			,statement_tot.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,statement_tot.sales_order  											-- SD.000123 "Заказ ЦК"
			,statement_tot.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,statement_tot.grade_name  												-- SD.000145 "Марка по спецификации"
			,statement_tot.uni 														-- SD.000151 "UNI"
			,statement_tot.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,statement_tot.end_user_name  											-- SD.000164 "Конечный потребитель"
			,statement_tot.invoice_provisional_number  								-- SD.000167 "Provisional invoice"
			,statement_tot.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,statement_tot.dt_storage_end_in_foreign_port  							-- SD.000176 "Окончание хранения в ин. порту"
			,statement_tot.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,statement_tot.dt_storage_end_in_second_foreign_warehouse  				-- SD.000178 "Окончание хранение склад 2 "
			,statement_tot.material_shape_name_full  								-- SD.000180 "Форма"
			,statement_tot.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,statement_tot.country_of_discharge_port_name  							-- SD.000341 "Страна POD"
			,statement_tot.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,statement_tot.business_location_name  									-- SD.000492 "Статус в Supply chain (Business)"
			,statement_tot.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,statement_tot.lot_code  												-- SD.000580 "Номер лота"
			,statement_tot.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,statement_tot.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,statement_tot.dt_invoice_provisional  									-- SD.000620 "Дата инвойса"
			,statement_tot.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,statement_tot.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,statement_tot.dt_realization 											-- SD.000720 "Дата реализации"
			,statement_tot.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,statement_tot.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,'fs_with_invoice_ext_client_final'::varchar
				as statement_data_group_code 										-- SD.001244 "Блок данных (statement)"
			,d_i_ldc.invoice_code as invoice_group_code 							-- SD.001245 "Группа инвойс (statement)"
			,statement_tot.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
			,statement_tot.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,statement_tot.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,statement_tot.net_weight 												-- SD.001249 "Вес для statement"
			,statement_tot.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,statement_tot.statement_invoice_position_code 							-- SD.001251 "Позиция фактуры для statement"
			,statement_tot.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,statement_tot.dt_payment												-- SD.001362 "Дата оплаты"
			,statement_tot.dt_payment_week											-- SD.001363 "Неделя оплаты"
			,statement_tot.dt_payment_mm											-- SD.001364 "Месяц оплаты"
			,statement_tot.dt_due_payment											-- SD.001365 "Срок оплаты"
			,statement_tot.payment_terms_code										-- SD.001366 "Условие платежа"
			,statement_tot.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
			,statement_tot.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
			,statement_tot.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,statement_tot.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
			,statement_tot.metal_exchange_type_code									-- SD.001371 "Тип биржи"
			,statement_tot.usd_currency_vat_excluded_amound							-- SD.001372 "Стоимость"
			,statement_tot.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
			,statement_tot.usd_currency_vat_included_amound							-- SD.001374 "Стоимость с НДС"
			,statement_tot.invoice_realization_code									-- SD.001375 "Фактура реализации"
			,statement_tot.currency_exchange_rate									-- SD.001376 "Валютный курс"
			,statement_tot.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,statement_tot.is_trader_name											-- SD.001378 "Трейдер"
			,statement_tot.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,statement_tot.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,statement_tot.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
			,'Финальный/корректирующий инвойс'::varchar as block
			-------------------------------------------
			,statement_tot.batch
			,statement_tot.release_material_status_code
			,statement_tot.contract_type_code
			,statement_tot.double_record_in_temporary_warehouse_code
			,statement_tot.warehouse_shipment_type_name
			,statement_tot.shipment_market_code
			,statement_tot.delivery_number_outbound
			,statement_tot.plant_producer_code
			,statement_tot.lot_group
			,statement_tot.sales_contract_code
			,statement_tot.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
		from statement_tot
		-- определяем группу финальных/корректирующих инвойсов
		left join dds.logistics_document_and_delivery_relationship as d_ldadr			-- VBSS
			on d_ldadr.delivery_code = statement_tot.delivery_number_outbound	-- по VBSS-VBELN = SD.000258 "Исходящая поставка"
			and d_ldadr.logistics_document_code ILIKE '6%'
		left join dds.invoice as d_i_ldc												-- VBSK
			on d_i_ldc.invoice_code = d_ldadr.logistics_document_code 			-- по VBSK-SAMMG = VBSS-SAMMGL
			and d_i_ldc.invoice_type_code = 'Q'								-- и VBSK-SMART ="Q"
			and d_i_ldc.billing_document_code is not null 					-- и VBSK-ZZVBELN не пусто
		where statement_tot.delivery_number_outbound is not null 					-- SD.000258 "Исходящая поставка" не пусто
			and statement_tot.statement_data_group_code != 'fs_returned'		-- SD.001244 "Блок данных (statement)" !="fs_returned"
			and d_i_ldc.invoice_code is not null
		UNION ALL
		select
		distinct
			 statement_tot.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,statement_tot.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,statement_tot.plant_producer_name  									-- SD.000007 "Завод"
			,statement_tot.port_of_loading_name  									-- SD.000009 "Направление"
			,statement_tot.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,statement_tot.material_aggr_name  										-- SD.000016 "Материал"
			,statement_tot.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,statement_tot.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,statement_tot.dt_warehouse  											-- SD.000024 "Дата склада"
			,statement_tot.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,statement_tot.weight_net  												-- SD.000032 "Вес нетто"
			,statement_tot.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,statement_tot.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,statement_tot.contract_name  											-- SD.000038 "Контракт"
			,statement_tot.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,statement_tot.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,statement_tot.port_of_discharge_name  									-- SD.000045 "Порт выгрузки"
			,statement_tot.bill_of_lading_in_foreign_port  							-- SD.000048 "Коносамент в ин.порту"
			,statement_tot.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,statement_tot.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,statement_tot.delivery_basis  											-- SD.000067 "Базис поставки"
			,statement_tot.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,statement_tot.sales_order  											-- SD.000123 "Заказ ЦК"
			,statement_tot.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,statement_tot.grade_name  												-- SD.000145 "Марка по спецификации"
			,statement_tot.uni 														-- SD.000151 "UNI"
			,statement_tot.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,statement_tot.end_user_name  											-- SD.000164 "Конечный потребитель"
			,statement_tot.invoice_provisional_number  								-- SD.000167 "Provisional invoice"
			,statement_tot.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,statement_tot.dt_storage_end_in_foreign_port  							-- SD.000176 "Окончание хранения в ин. порту"
			,statement_tot.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,statement_tot.dt_storage_end_in_second_foreign_warehouse  				-- SD.000178 "Окончание хранение склад 2 "
			,statement_tot.material_shape_name_full  								-- SD.000180 "Форма"
			,statement_tot.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,statement_tot.country_of_discharge_port_name  							-- SD.000341 "Страна POD"
			,statement_tot.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,statement_tot.business_location_name  									-- SD.000492 "Статус в Supply chain (Business)"
			,statement_tot.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,statement_tot.lot_code  												-- SD.000580 "Номер лота"
			,statement_tot.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,statement_tot.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,statement_tot.dt_invoice_provisional  									-- SD.000620 "Дата инвойса"
			,statement_tot.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,statement_tot.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,statement_tot.dt_realization 											-- SD.000720 "Дата реализации"
			,statement_tot.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,statement_tot.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,'fs_with_invoice_ext_client_final'::varchar
				as statement_data_group_code 										-- SD.001244 "Блок данных (statement)"
			,d_i_ldc2.invoice_code as invoice_group_code 							-- SD.001245 "Группа инвойс (statement)"
			,statement_tot.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
			,statement_tot.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,statement_tot.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,0::numeric as net_weight 												-- SD.001249 "Вес для statement"
			,statement_tot.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,statement_tot.statement_invoice_position_code 							-- SD.001251 "Позиция фактуры для statement"
			,statement_tot.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,statement_tot.dt_payment												-- SD.001362 "Дата оплаты"
			,statement_tot.dt_payment_week											-- SD.001363 "Неделя оплаты"
			,statement_tot.dt_payment_mm											-- SD.001364 "Месяц оплаты"
			,statement_tot.dt_due_payment											-- SD.001365 "Срок оплаты"
			,statement_tot.payment_terms_code										-- SD.001366 "Условие платежа"
			,statement_tot.payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
			,statement_tot.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
			,statement_tot.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,statement_tot.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
			,statement_tot.metal_exchange_type_code									-- SD.001371 "Тип биржи"
			,statement_tot.usd_currency_vat_excluded_amound							-- SD.001372 "Стоимость"
			,statement_tot.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
			,statement_tot.usd_currency_vat_included_amound							-- SD.001374 "Стоимость с НДС"
			,statement_tot.invoice_realization_code									-- SD.001375 "Фактура реализации"
			,statement_tot.currency_exchange_rate									-- SD.001376 "Валютный курс"
			,statement_tot.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,statement_tot.is_trader_name											-- SD.001378 "Трейдер"
			,statement_tot.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,statement_tot.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,statement_tot.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
			,'Финальный/корректирующий инвойс' as block
			-------------------------------------------
			,statement_tot.batch
			,statement_tot.release_material_status_code
			,statement_tot.contract_type_code
			,statement_tot.double_record_in_temporary_warehouse_code
			,statement_tot.warehouse_shipment_type_name
			,statement_tot.shipment_market_code
			,statement_tot.delivery_number_outbound
			,statement_tot.plant_producer_code
			,statement_tot.lot_group
			,statement_tot.sales_contract_code
			,statement_tot.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
		from statement_tot
		-- определяем группу финальных/корректирующих инвойсов
		left join dds.logistics_document_and_delivery_relationship as d_ldadr			-- VBSS
			on d_ldadr.delivery_code = statement_tot.delivery_number_outbound	-- по VBSS-VBELN = SD.000258 "Исходящая поставка"
			and d_ldadr.logistics_document_code ILIKE '71%'
		left join dds.invoice as d_i_ldc2												-- VBSK
			on d_i_ldc2.invoice_code = d_ldadr.logistics_document_code 			-- по VBSK-SAMMG = VBSS-SAMMGL
			and d_i_ldc2.invoice_type_code = 'К'							-- и VBSK-SMART ="К"
			and d_i_ldc2.billing_document_code is not null 					-- и VBSK-ZZVBELN не пусто
		where statement_tot.delivery_number_outbound is not null 					-- SD.000258 "Исходящая поставка" не пусто
		and statement_tot.statement_data_group_code != 'fs_returned'		-- SD.001244 "Блок данных (statement)" !="fs_returned"
		and d_i_ldc2.invoice_code is not null
		)
		distributed by (delivery_number_sales,batch);

drop table if exists statement_fci_tot_prev;
create temp table statement_fci_tot_prev as (
		select
			statement_fci_prev.delivery_number_initial  										-- SD.000001 "Исходная поставка"
			,statement_fci_prev.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,statement_fci_prev.plant_producer_name  									-- SD.000007 "Завод"
			,statement_fci_prev.port_of_loading_name  									-- SD.000009 "Направление"
			,statement_fci_prev.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,statement_fci_prev.material_aggr_name  									-- SD.000016 "Материал"
			,statement_fci_prev.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,statement_fci_prev.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,statement_fci_prev.dt_warehouse  											-- SD.000024 "Дата склада"
			,statement_fci_prev.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,statement_fci_prev.weight_net  											-- SD.000032 "Вес нетто"
			,statement_fci_prev.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,statement_fci_prev.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,statement_fci_prev.contract_name  											-- SD.000038 "Контракт"
			,statement_fci_prev.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,statement_fci_prev.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,statement_fci_prev.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
			,statement_fci_prev.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,statement_fci_prev.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,statement_fci_prev.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,statement_fci_prev.delivery_basis  										-- SD.000067 "Базис поставки"
			,statement_fci_prev.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,statement_fci_prev.sales_order  											-- SD.000123 "Заказ ЦК"
			,statement_fci_prev.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,statement_fci_prev.grade_name  											-- SD.000145 "Марка по спецификации"
			,statement_fci_prev.uni 													-- SD.000151 "UNI"
			,statement_fci_prev.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,statement_fci_prev.end_user_name  											-- SD.000164 "Конечный потребитель"
			,statement_fci_prev.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,statement_fci_prev.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,statement_fci_prev.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,statement_fci_prev.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,statement_fci_prev.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,statement_fci_prev.material_shape_name_full  								-- SD.000180 "Форма"
			,statement_fci_prev.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,statement_fci_prev.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,statement_fci_prev.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,statement_fci_prev.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,statement_fci_prev.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,statement_fci_prev.lot_code  												-- SD.000580 "Номер лота"
			,statement_fci_prev.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,statement_fci_prev.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,statement_fci_prev.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,statement_fci_prev.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,statement_fci_prev.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,statement_fci_prev.dt_realization 											-- SD.000720 "Дата реализации"
			,statement_fci_prev.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,statement_fci_prev.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,statement_fci_prev.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,statement_fci_prev.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
			,statement_fci_prev.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
			,statement_fci_prev.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,statement_fci_prev.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,statement_fci_prev.net_weight 												-- SD.001249 "Вес для statement"
			,d_i.billing_document_code												-- VBSK-ZZVBELN
					as statement_invoice_code 											-- SD.001250 "Фактура для statement"
			,vbrp.posnr		-- VBRP-POSNR
				as statement_invoice_position_code 										-- SD.001251 "Позиция фактуры для statement"
			,supplier_3rd_party_code									                -- SD.001361 "Внешний контрагент"
			,CASE
				WHEN d_i.billing_document_code is not null 							-- Если SD.001250 "Фактура для statement" не пусто,
					THEN o_zr.zzpaydt												-- то ZVBRK-ZZPAYDT,
				ELSE NULL															-- иначе пусто
			END as dt_payment															-- SD.001362 "Дата оплаты"
			,NULL::integer as dt_payment_week											-- SD.001363 "Неделя оплаты"
			,NULL::varchar as dt_payment_mm												-- SD.001364 "Месяц оплаты"
			,o_zr.zzasdate															-- ZVBRK-ZZASDATE
					as dt_due_payment													-- SD.001365 "Срок оплаты"
			,coalesce(vbsk1251.zzterm,												-- VBSK-ZZTERM по 1-у условию,
				(CASE
					WHEN contract_type_ptc.range_low_value IS NULL
						THEN vbsk2.zzterm
				END),																-- если VBSK-ZZTERM по 1-у условию пусто, то VBSK-ZZTERM по 2-у условию,
				d_sr.terms_of_payment_code,											-- если VBSK-ZZTERM по 2-у условию пусто, то /RUSAL/SD2882M-ZTERM
				vbak1366.vbeln,															-- если /RUSAL/SD2882M-ZTERM пусто, то VBAK-VBELN
				vbkd.vbeln															-- если VBAK-VBELN пусто, то VBKD-ZTERM
				) as payment_terms_code													-- SD.001366 "Условие платежа"
			,NULL::integer as payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
			,NULL::varchar as payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
			,coalesce(vbsk1251.zzkondm,												-- VBSK-ZZKONDM по 1-у условию,
				(CASE
					WHEN contract_type_ptc.range_low_value IS NULL
						THEN vbsk2.zzkondm
				END)																-- если VBSK-ZZKONDM по 1-у условию пусто, то VBSK-ZZKONDM по 2-у условию
				) as market_indicator_code												-- SD.001369 "Рыночный индикатор (код)"
			,NULL::varchar as market_indicator_name										-- SD.001370 "Тип рыночного индикатора"
			,NULL::varchar as metal_exchange_type_code									-- SD.001371 "Тип биржи"
			,NULL::numeric as usd_currency_vat_excluded_amound							-- SD.001372 "Стоимость"
			,NULL::numeric as document_currency_vat_excluded_amound						-- SD.001373 "Стоимость в исходной валюте"
			,NULL::numeric as usd_currency_vat_included_amound							-- SD.001374 "Стоимость с НДС"
			,CASE
				WHEN vbrk.vbeln is not null											-- Если VBRK-FKART = ZTKZ и ZTDZ и VBRK-RFBSK =  "С" (лат)
					THEN vbrp2.vbeln												-- то VBRP-VBELN
			END	as invoice_realization_code												-- SD.001375 "Фактура реализации"
			,NULL::numeric as currency_exchange_rate									-- SD.001376 "Валютный курс"
			,CASE
				WHEN statement_fci_prev.is_shipped_via_overseas_warehouse IS NULL 	-- Если SD.000483 "Наличие Иностранный склад" пусто,
					THEN 'Direct delivery'											-- то "Direct delivery"
				ELSE 'Warehouse'													-- ианче "Warehouse"
			END	as direct_or_overseas_warehouse_delivery_name							-- SD.001377 "Склад/прямая поставка"
			,CASE
				WHEN dd_mctmr2_cfrc.counterparty_code is not null 					-- Если SD.000036 "Покупатель (код)" есть в ZVSD_REG_CLIENT-KUNNR_CODE
					THEN 'Trader'													-- то "Trader",
				ELSE NULL															-- иначе пусто
			END	as is_trader_name														-- SD.001378 "Трейдер"
			,vbsk5.vtext															-- VBSK-VTEXT
				as prepayment_invoice_code												-- SD.001379 "Номер предоплатного инвойса"
			,d_sr.sales_market_code													-- /RUSAL/SD2882M-MARKET
				as sales_market_in_sales_request_code									-- SD.001380 "Рынок из заказа"
			,NULL::numeric as statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
			,statement_fci_prev.block
			-------------------------------------------
			,statement_fci_prev.batch
			,statement_fci_prev.release_material_status_code
			,statement_fci_prev.contract_type_code
			,statement_fci_prev.double_record_in_temporary_warehouse_code
			,statement_fci_prev.warehouse_shipment_type_name
			,statement_fci_prev.shipment_market_code
			,statement_fci_prev.delivery_number_outbound
			,statement_fci_prev.plant_producer_code
			,statement_fci_prev.lot_group
			,statement_fci_prev.sales_contract_code
			,coalesce(o_tfsfrt1.text_value,
	        	o_tfsfrt2.text_value,
	        	o_tfsfrt3.text_value,
	        	o_tfsfrt4.text_value,
	        	o_tfsfrt5.text_value,
	        	(CASE
	        		WHEN vbak4.vbeln is not null
	        			and o_tfsfrt6.text_value is not null
	        			THEN o_tfsfrt6.text_value
	        		WHEN vbak5.vbeln is not null
	        			and o_tfsfrt7.text_value is not null
	        			THEN o_tfsfrt7.text_value
	        		ELSE o_tfsfrt8.text_value
	        	END),
	        	(CASE
	        		WHEN statement_fci_prev.delivery_region_name = 'Китай'
	        			THEN 'SMM'
	        		ELSE 'ALS'
	        	END)
	        	) as metal_exchange_type
	       ,statement_fci_prev.is_shipped_via_overseas_warehouse					-- SD.000483 "Наличие Иностранный склад"
	       from
			statement_fci_prev
		-- SD.001250 "Фактура для statement"
		left join dds.invoice as d_i													-- VBSK
			on d_i.invoice_code = statement_fci_prev.invoice_group_code			-- по VBSK-SAMMG = SD.001245 "Группа инвойс (statement)"
		-- SD.001251 "Позиция фактуры для statement"
		left join dds.delivery_document_position as d_ddp_dni							   -- LIPS
			on d_ddp_dni.delivery_code = statement_fci_prev.delivery_number_sales  -- по LIPS-VBELN = SD.000002 "Продажная поставка"
	    	and d_ddp_dni.batch_code = statement_fci_prev.batch				   -- и LIPS-CHARG = SD.000004 "Партия"
		-- заменить на dds после добавления поля VBRP-VGBEL, VBRP-VGPOS
		left join ods.vbrp_ral as vbrp												-- VBRP
			on vbrp.vgbel = d_ddp_dni.delivery_code								-- VBRP-VGBEL = LIPS-VBELN
		    and vbrp.vgpos = d_ddp_dni.delivery_position_line_item_code		-- VBRP-VGPOS = VBAP-POSNR
		 -- SD.001362 "Дата оплаты" -- SD.001365 "Срок оплаты"
		left join ods.zvbrk_ral as o_zr												-- ZVBRK
			on o_zr.vbeln = d_i.billing_document_code 							-- по ZVBRK-VBELN = SD.001250 "Фактура для statement"
		-- SD.001366 "Условие платежа" -- SD.001369 "Рыночный индикатор (код)"
		--объединить с dds.invoice после добавления поля VBSK-ZZVBELN_VA, ZZKONDM
	    left join ods.vbsk_ral as vbsk1251											-- VBSK
	    	on vbsk1251.sammg = statement_fci_prev.invoice_group_code			-- по VBSK-SAMMG = SD.001245 "Группа инвойс (statement)"
	   	--заменить на dds.invoice после добавления поля VBSK-ZZTERM
	    left join contract_type_ptc
	    	on contract_type_ptc.range_low_value = statement_fci_prev.contract_type_code
		left join ods.vbsk_ral as vbsk2											-- VBSK
	    	on vbsk2.sammg = statement_fci_prev.lot_group						-- по VBSK-SAMMG = SD.000061 "Группа лот"
	    left join dds.sales_request as d_sr											-- /RUSAL/SD2882M (/RUSAL/SD2882M-NUMVR = "00")
	    	on d_sr.sales_request_code = statement_fci_prev.sales_order			-- по /RUSAL/SD2882M-ZAKAZ_KL = SD.000123 "Заказ ЦК"
	    	and d_sr.dt_shipment_yyyymm = to_char(statement_fci_prev.dt_shipment, 'yyyymm') -- и /RUSAL/SD2882M-REG_PERIO = SD.000010 "Дата отгрузки" в формате "ггггмм"
	    	and d_sr.is_not_valid_for_reporting is not true
--заменить на dds после добавления поля VBAK-KUNAG, VBAK-GUEBG, VBAK-GUEEN
	    left join vbak1366											-- VBAK
	    	  on vbak1366.kunnr = statement_fci_prev.customer_for_reporting_code  		-- по VBAK-KUNNR = SD.000036 "Покупатель (код)"
	   --заменить на dds в темп после добавления поля VBAK-KUNAG, VBAK-GUEBG, VBAK-GUEEN
	    left join vbak2																-- VBAK
	    	on vbak2.kunnr = statement_fci_prev.customer_for_reporting_code  	-- по VBAK-KUNNR = SD.000036 "Покупатель (код)"
	   --заменить на dds после добавления VBKD-ZTERM
	    left join ods.vbkd_ral as vbkd										    -- VBKD
	    	on vbkd.vbeln = vbak2.vbeln											-- по VBKD-VBELN = VBAK-VBELN
	    -- SD.001371 "Тип биржи"
	    left join ods.texts_from_sap_fm_read_text as o_tfsfrt1						-- ФМ READ_TEXT
			on o_tfsfrt1.text_key_identifier_code = d_i.billing_document_code   -- по TDNAME = VBSK-ZZVBELN
			and o_tfsfrt1.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt1.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt1.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt1.is_active is true
		-- п.2
		left join vbsk															-- VBSK (SMART = "O")
			on vbsk.sales_contract_code = statement_fci_prev.sales_contract_code	-- по VBSK-ZZVBELN_RAM = SD.000179 "Контракт (код)"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt2						-- ФМ READ_TEXT
			on o_tfsfrt2.text_key_identifier_code = vbsk.billing_document_code  -- по TDNAME = VBSK-ZZVBELN
			and o_tfsfrt2.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt2.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt2.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt2.is_active is true
		-- п.3
		left join ods.vbak_ral as vbak3												-- VBAK
			on vbak3.vbeln = statement_fci_prev.sales_contract_code				-- по VBAK-VBELN = SD.000179 "Контракт (код)"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt3						-- ФМ READ_TEXT
			on o_tfsfrt3.text_key_identifier_code = vbak3.vbeln					-- по TDNAME = VBAK-VBELN
			and o_tfsfrt3.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt3.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt3.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
		    and o_tfsfrt3.is_active is true
		left join vbak4															-- VBAK (VBAK-AUART = "ZDGS")
			on vbak4.zuonr = statement_fci_prev.sales_contract_code				-- по VBAK-ZUONR = SD.000179 "Контракт (код)"
		--
		left join vbap2															-- VBAP
	    	on vbap2.vbeln = vbak4.vbeln										-- VBAP-VBELN = VBAK-VBELN
	    --
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt4						-- ФМ READ_TEXT
			on o_tfsfrt4.text_key_identifier_code = vbap2.vbeln_posnr			-- по TDNAME = VBAP-POSNR
			and o_tfsfrt4.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt4.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt4.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt4.is_active is true
		-- п.4
		left join vbsk4															-- VBSK (SMART = "O")
			on vbsk4.zzkunag = statement_fci_prev.sales_contract_code			-- по VBSK-ZZKUNAG = SD.000179 "Контракт (код)"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt5						-- ФМ READ_TEXT
			on o_tfsfrt5.text_key_identifier_code = vbsk4.zzvbeln				-- по TDNAME =  VBSK-ZZVBELN
			and o_tfsfrt5.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt5.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt5.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt5.is_active is true
		-- п.5
		left join vbak7										                    -- VBAK
	    	on vbak7.kunnr = statement_fci_prev.customer_for_reporting_code  	-- по VBAK-KUNAG (kunnr) = SD.000036 "Покупатель (код)"
	    --
		left join
	    	ods.texts_from_sap_fm_read_text as o_tfsfrt6						-- ФМ READ_TEXT
			on o_tfsfrt6.text_key_identifier_code = vbak4.vbeln				-- по TDNAME = VBSK-VBELN
			and o_tfsfrt6.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt6.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt6.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt6.is_active is true
		--
		left join vbak5																-- VBAK
	    	on vbak5.kunnr = statement_fci_prev.customer_for_reporting_code  	-- по VBAK-KUNAG = SD.000036 "Покупатель (код)"
	     --
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt7				-- ФМ READ_TEXT
			on o_tfsfrt7.text_key_identifier_code = vbak5.vbeln				-- по TDNAME = VBSK-VBELN											-- VBSK-VBELN
			and o_tfsfrt7.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt7.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt7.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt7.is_active is true
		--
		left join vbak6
			on vbak6.zuonr = coalesce(vbak4.vbeln, vbak5.vbeln)
		 --
		left join
	    	ods.texts_from_sap_fm_read_text as o_tfsfrt8						-- ФМ READ_TEXT
			on o_tfsfrt8.text_key_identifier_code = vbak6.vbeln					-- по TDNAME = VBSK-VBELN												-- VBSK-VBELN
			and o_tfsfrt8.text_object_identifier_code = 'TR96'				-- и TDID = TR96
			and o_tfsfrt8.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt8.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt8.is_active is true
		-- SD.001375 "Фактура реализации"
		left join ods.vbrp_ral as vbrp2												-- VBRP
			on vbrp2.vgbel = d_i.billing_document_code							-- по VBRP-VGBEL = SD.001250 "Фактура для statement"
			and vbrp2.vgpos	= vbrp.posnr									-- и VBRP-VGPOS = SD.001251 "Позиция фактуры для statement"
		--
		left join ods.vbrk_ral as vbrk													-- VBRK
			on vbrk.vbeln = vbrp.vbeln											-- по VBRK-VBELN = VBRP-VBELN
			and vbrk.rfbsk = 'C'											-- и VBRK-RFBSK = "C"(лат)
			and vbrk.fkart IN ('ZTKZ','ZTDZ') 								-- и VBRK-FKART = ZTKZ и ZTDZ
		-- SD.001378 "Трейдер"
		left join dict_dds.map_counterparty_to_market_region2 as dd_mctmr2_cfrc		-- ZTSD_REG_CLIENT
			on dd_mctmr2_cfrc.counterparty_code = 								-- по ZVSD_REG_CLIENT-KUNNR_CODE =
				statement_fci_prev.is_shipped_via_overseas_warehouse			-- SD.000483 "Наличие Иностранный склад"
		-- SD.001379 "Номер предоплатного инвойса"
		left join ods."/rusal/sd2921mgo_ral" as mgo									-- /RUSAL/SD2921MGO
			on mgo.sammg_o = statement_fci_prev.invoice_group_code 				-- по /RUSAL/SD2921MGO-SAMMG_O = SD.001245 "Группа инвойс (statement)"
		--
		left join ods.vbsk_ral as vbsk5												-- VBSK
			on vbsk5.sammg = mgo.sammg											-- по VBSK-SAMMG = /RUSAL/SD2921MGO-SAMMG
	)
		distributed by (delivery_number_sales,batch);


drop table if exists statement_fci_tot;
create temp table statement_fci_tot as (
		select
	 		sftp.delivery_number_initial  								-- SD.000001 "Исходная поставка"
			,sftp.delivery_number_sales  								-- SD.000002 "Продажная поставка"
			,sftp.plant_producer_name  									-- SD.000007 "Завод"
			,sftp.port_of_loading_name  								-- SD.000009 "Направление"
			,sftp.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,sftp.material_aggr_name  									-- SD.000016 "Материал"
			,sftp.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,sftp.shipment_market_name  								-- SD.000019 "Рынок в отгрузке"
			,sftp.dt_warehouse  										-- SD.000024 "Дата склада"
			,sftp.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,sftp.weight_net  											-- SD.000032 "Вес нетто"
			,sftp.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,sftp.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,sftp.contract_name  										-- SD.000038 "Контракт"
			,sftp.bill_of_lading_number  								-- SD.000041 "Номер коносамента"
			,sftp.dt_bill_of_lading  									-- SD.000042 "Дата коносамента"
			,sftp.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
			,sftp.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,sftp.dt_bill_of_lading_in_foreign_port  					-- SD.000049 "Дата коносамента в ин.порту"
			,sftp.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,sftp.delivery_basis  										-- SD.000067 "Базис поставки"
			,sftp.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,sftp.sales_order  											-- SD.000123 "Заказ ЦК"
			,sftp.dt_arrival_in_port_of_discharge_plan  				-- SD.000130 "Дата прибытия в порт выгрузки план"
			,sftp.grade_name  											-- SD.000145 "Марка по спецификации"
			,sftp.uni 													-- SD.000151 "UNI"
			,sftp.dt_arrival_in_second_port_of_discharge_plan			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,sftp.end_user_name  										-- SD.000164 "Конечный потребитель"
			,sftp.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,sftp.dt_storage_start_in_foreign_port  					-- SD.000175 "Дата начала хранения ин. склад"
			,sftp.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,sftp.dt_storage_start_in_second_foreign_warehouse  		-- SD.000177 "Начало хранения склад 2 "
			,sftp.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,sftp.material_shape_name_full  							-- SD.000180 "Форма"
			,sftp.delivery_region_name  								-- SD.000338 "Регион поставки по контракту"
			,sftp.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,sftp.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,sftp.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,sftp.delivery_country_in_contract_name  					-- SD.000576 "Страна поставки по контракту"
			,sftp.lot_code  											-- SD.000580 "Номер лота"
			,sftp.customer_for_scm_report_name  						-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,sftp.vessel_and_voyage_actual_search_name  				-- SD.000608 "Судно / номер рейса (факт)"
			,sftp.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,sftp.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,sftp.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,sftp.dt_realization 										-- SD.000720 "Дата реализации"
			,sftp.is_tolling_code                            			-- SD.000749 "Признак толлинг"
			,sftp.warehouse_or_responsible_customer_for_storage_name	-- SD.000919 "General storage location"
			,sftp.statement_data_group_code 							-- SD.001244 "Блок данных (statement)"
			,sftp.invoice_group_code 									-- SD.001245 "Группа инвойс (statement)"
			,sftp.dt_report_yyyy 										-- SD.001246 "Год отчета (statement)"
			,sftp.purchase_invoice_code 								-- SD.001247 "Входящий счет (statement)"
			,sftp.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,sftp.net_weight 											-- SD.001249 "Вес для statement"
			,sftp.statement_invoice_code 								-- SD.001250 "Фактура для statement"
			,sftp.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
			,sftp.supplier_3rd_party_code								-- SD.001361 "Внешний контрагент"
			,sftp.dt_payment											-- SD.001362 "Дата оплаты"
			,EXTRACT (week from sftp.dt_payment)::integer
				as dt_payment_week										-- SD.001363 "Неделя оплаты"
			,to_char(sftp.dt_payment, 'mm.yyyy') as dt_payment_mm		-- SD.001364 "Месяц оплаты"
			,sftp.dt_due_payment										-- SD.001365 "Срок оплаты"
			,sftp.payment_terms_code									-- SD.001366 "Условие платежа"
			,dd_topd.payment_terms_days_quantity		-- /RUSAL/ZTERM-DAYS1
				as payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
			,dd_ptdt.payment_terms_document_name		-- D007T-DDTEXT
				as payment_terms_document_name							-- SD.001368 "Условие платежа (документ)"
			,sftp.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,dd_mpgt.material_price_group_name			-- T178-VTEXT
				as market_indicator_name								-- SD.001370 "Тип рыночного индикатора"
			,dd_certt.currency_exchange_rate_type_name	-- TCURW-CURVW
				as metal_exchange_type_code								-- SD.001371 "Тип биржи"
			,sftp.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
			,sftp.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
			,sftp.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
			,sftp.invoice_realization_code								-- SD.001375 "Фактура реализации"
			,CASE
				WHEN vbrk.waerk = 'USD'							-- Если VBRK-WAERK = "USD",
					THEN 1										-- то "1",
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate != 1						-- и BKPF-KURSF != 1,
					THEN bkpf.exchange_rate						-- то BKPF-KURSF,
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate = 1						-- и BKPF-KURSF = 1,
					THEN dd_cr.currency_rate					-- то TCURR-UKURS,
				WHEN sftp.statement_invoice_code IS NULL
					-- если SD.001375 "Фактура реализации" пусто,
					THEN replace(o_tfsfrt9.text_value, '-', '')::numeric -- то ФМ READ_TEXT-текст TR29
			END::numeric
			as currency_exchange_rate									-- SD.001376 "Валютный курс"
			,sftp.direct_or_overseas_warehouse_delivery_name			-- SD.001377 "Склад/прямая поставка"
			,sftp.is_trader_name										-- SD.001378 "Трейдер"
			,sftp.prepayment_invoice_code								-- SD.001379 "Номер предоплатного инвойса"
			,sftp.sales_market_in_sales_request_code					-- SD.001380 "Рынок из заказа"
			,coalesce(vbrp.brgew,								-- VBRP-BRGEW,
				sftp.weight_net)  								-- если VBRP-BRGEW пусто, то SD.000032 "Вес нетто"
				as statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
			,sftp.block
			-------------------------------------------
			,sftp.batch
			,sftp.release_material_status_code
			,sftp.contract_type_code
			,sftp.double_record_in_temporary_warehouse_code
			,sftp.warehouse_shipment_type_name
			,sftp.shipment_market_code
			,sftp.delivery_number_outbound
			,sftp.plant_producer_code
		    ,sftp.lot_group
		    ,sftp.sales_contract_code
		    ,sftp.metal_exchange_type
		    ,sftp.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
		from statement_fci_tot_prev as sftp
		-- SD.001367 "Условие платежа (дни)"
		left join dd_topd						-- /RUSAL/ZTERM
			on dd_topd.terms_of_payment_code = sftp.payment_terms_code			-- по /RUSAL/ZTERM-ZTERM = SD.001366 "Условие платежа							-- и /RUSAL/ZTERM-MODUL = "SD"
		-- SD.001368 "Условие платежа (документ)"
		left join dict_dds.tech_rusal_paydocev as dd_trp								-- /RUSAL/PAYDOCEV
			on dd_trp.event = dd_topd.payment_event_code							-- по /RUSAL/PAYDOCEV-EVENT = /RUSAL/ZTERM-SOB1
		--
		left join dict_dds.payment_terms_document_texts as dd_ptdt					-- D007T
			on dd_ptdt.payment_terms_document_code = dd_trp.docum				-- по D007T-DOMVALUE_L = /RUSAL/PAYDOCEV-DOCUM
			and dd_ptdt.language_code = 'E'									-- и D007T-DOLANGUAGE = "EN"
		-- SD.001370 "Тип рыночного индикатора"
		left join dict_dds.material_price_group_texts as dd_mpgt 						-- T178
			on dd_mpgt.material_price_group_code = sftp.market_indicator_code	-- T178-KONDM = SD.001369 "Рыночный индикатор (код)"
			and dd_mpgt.language_code = 'E'
			-- SD.001371 "Тип биржи"
		left join dict_dds.currency_exchange_rate_type_texts as dd_certt				-- TCURW
			on dd_certt.currency_exchange_rate_type_code = sftp.metal_exchange_type -- TCURW-KURST =  текст из заголовка ФМ READ_TEXT
			and dd_certt.language_code = 'E'									 	-- TCURW-SPRAS = "EN"
		-- SD.001376 "Валютный курс"
	    left join ods.vbrk_ral as vbrk												-- VBRK
	    	on vbrk.vbeln = sftp.statement_invoice_code 						-- по VBRK-VBELN = SD.001250 "Фактура для statement"
	    --
	   --
	    left join dm_calc.accounting_document_header as bkpf
	    	on bkpf.reference_object_key_code = sftp.invoice_realization_code -- по BKPF-AWKEY = -- SD.001375 "Фактура реализации"
	    	--
	    left join dict_dds.currency_rates as dd_cr								-- TCURR
	    	on dd_cr.currency_from_code = bkpf.document_currency_code -- по TCURR-FCURR = BKPF-WAERS
	    	and dd_cr.dt_currency_rate = bkpf.dt_posting	 -- и TCURR-GDATU = BKPF-BUDAT
	    	and dd_cr.currency_rate_type_code = 'M'							-- и TCURR-KURST = "M"
	    	and dd_cr.currency_to_code = 'USD'									-- и TCURR-TCURR = "USD"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt9					-- ФМ READ_TEXT
			on o_tfsfrt9.text_key_identifier_code = vbrk.vbeln				 	-- по TDNAME = VBRK-VBELN
			and o_tfsfrt9.text_object_identifier_code = 'TR29'				-- и TDID = TR29
			and o_tfsfrt9.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt9.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt9.is_active is true
		-- SD.001381 "Расчетный вес STATEMENT"
		left join ods.vbrp_ral as vbrp												-- VBRP
			on vbrp.vbeln = sftp.statement_invoice_code 							-- по VBRP-VBELN = SD.001250 "Фактура для statement"
			and vbrp.posnr = sftp.statement_invoice_position_code 			-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
			and vbrp.kvgr5 = '010'											-- и VBRP-KVGR5 = "010"
	)
		distributed by (delivery_number_sales,batch);

drop table if exists statement_fci;
create temp table statement_fci as (
	select
		 sft.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,sft.delivery_number_sales  								-- SD.000002 "Продажная поставка"
		,sft.plant_producer_name  									-- SD.000007 "Завод"
		,sft.port_of_loading_name  									-- SD.000009 "Направление"
		,sft.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,sft.material_aggr_name  									-- SD.000016 "Материал"
		,sft.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,sft.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,sft.dt_warehouse  											-- SD.000024 "Дата склада"
		,sft.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,sft.weight_net  											-- SD.000032 "Вес нетто"
		,sft.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,sft.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,sft.contract_name  										-- SD.000038 "Контракт"
		,sft.bill_of_lading_number  								-- SD.000041 "Номер коносамента"
		,sft.dt_bill_of_lading  									-- SD.000042 "Дата коносамента"
		,sft.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,sft.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,sft.dt_bill_of_lading_in_foreign_port  					-- SD.000049 "Дата коносамента в ин.порту"
		,sft.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,sft.delivery_basis  										-- SD.000067 "Базис поставки"
		,sft.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,sft.sales_order  											-- SD.000123 "Заказ ЦК"
		,sft.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,sft.grade_name  											-- SD.000145 "Марка по спецификации"
		,sft.uni 													-- SD.000151 "UNI"
		,sft.dt_arrival_in_second_port_of_discharge_plan			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,sft.end_user_name  										-- SD.000164 "Конечный потребитель"
		,sft.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,sft.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,sft.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,sft.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,sft.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,sft.material_shape_name_full  								-- SD.000180 "Форма"
		,sft.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,sft.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,sft.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,sft.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,sft.delivery_country_in_contract_name  					-- SD.000576 "Страна поставки по контракту"
		,sft.lot_code  												-- SD.000580 "Номер лота"
		,sft.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,sft.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,sft.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,sft.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,sft.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,sft.dt_realization 										-- SD.000720 "Дата реализации"
		,sft.is_tolling_code                            			-- SD.000749 "Признак толлинг"
		,sft.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,sft.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,sft.invoice_group_code 									-- SD.001245 "Группа инвойс (statement)"
		,sft.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,sft.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,sft.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,sft.net_weight 											-- SD.001249 "Вес для statement"
		,sft.statement_invoice_code 								-- SD.001250 "Фактура для statement"
		,sft.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,sft.supplier_3rd_party_code								-- SD.001361 "Внешний контрагент"
		,sft.dt_payment												-- SD.001362 "Дата оплаты"
		,sft.dt_payment_week										-- SD.001363 "Неделя оплаты"
		,sft.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,sft.dt_due_payment											-- SD.001365 "Срок оплаты"
		,sft.payment_terms_code										-- SD.001366 "Условие платежа"
		,sft. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,sft.payment_terms_document_name							-- SD.001368 "Условие платежа (документ)"
		,sft. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,sft.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,sft.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,case
			when sft.currency_exchange_rate < 0 then vbrp.netwr / abs(sft.currency_exchange_rate)
			when sft.currency_exchange_rate > 0 then vbrp.netwr * abs(sft.currency_exchange_rate)
		end as usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,vbrp.netwr 								-- VBRP-NETWR
			as document_currency_vat_excluded_amound				-- SD.001373 "Стоимость в исходной валюте"
		,case
			when sft.currency_exchange_rate < 0 then (vbrp.netwr + vbrp.mwsbp) / abs(sft.currency_exchange_rate)
			when sft.currency_exchange_rate > 0 then (vbrp.netwr + vbrp.mwsbp) * abs(sft.currency_exchange_rate)
		end as usd_currency_vat_included_amound					-- SD.001374 "Стоимость с НДС"
		,sft.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,sft.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,sft.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,sft.is_trader_name											-- SD.001378 "Трейдер"
		,sft.prepayment_invoice_code								-- SD.001379 "Номер предоплатного инвойса"
		,sft.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,sft.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
		,sft.block
		-------------------------------------------
		,sft.batch
		,sft.release_material_status_code
		,sft.contract_type_code
		,sft.double_record_in_temporary_warehouse_code
		,sft.warehouse_shipment_type_name
		,sft.shipment_market_code
		,sft.delivery_number_outbound
		,sft.plant_producer_code
		,sft.lot_group
		,sft.sales_contract_code
		,sft.metal_exchange_type
		,sft.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_fci_tot as sft
	-- SD.001372 "Стоимость" -- SD.001373 "Стоимость в исходной валюте" -- SD.001374 "Стоимость с НДС"
	left join ods.vbrp_ral as vbrp										-- VBRP
	    on vbrp.vbeln = sft.statement_invoice_code 					-- по VBRP-VBELN = SD.001250 "Фактура для statement"
	    and vbrp.posnr = sft.statement_invoice_position_code 	-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
	)
distributed by (delivery_number_sales,batch);

-- Блок Закупка от третьих лиц
-- 1. Выбираем все исходные поставки из предыдущего блока, у которых SD.000006 "Завод производитель (код)" ="W990 "
drop table if exists statement_tot_dni;
create temp table statement_tot_dni as (
	select distinct statement_tot.delivery_number_initial  					-- SD.000001 "Исходная поставка"
	from statement_tot
	where statement_tot.plant_producer_code = 'W990')				-- SD.000006 "Завод производитель (код)" ="W990 "
distributed by (delivery_number_initial);

-- 2. Выбрать все из RSEG в LT_RSEG
drop table if exists lt_rseg;
create temp table lt_rseg as (
	select
		d_ipdp_tben.invoice_code, 										-- RSEG-BELNR
		d_ipdp_tben.fiscal_year,										-- RSEG-GJAHR
		d_ipdp_tben.purchase_document_code,								-- RSEG-EBELN
		d_ipdp_tben.purchase_document_position_line_item_code,			-- RSEG-EBELP
		statement_tot_dni.delivery_number_initial  						-- SD.000001 "Исходная поставка"
	/*	,d_ddp_dni.delivery_code,
		d_ddh_dc.delivery_code,
		d_ipdp_tben.purchase_document_code,
		d_ddp_dni.sales_document_code,
		d_ipdp_tben.purchase_document_position_line_item_code,
		d_ddp_dni.sales_document_position_line_item_code,
		d_ipdp_tben.material_code,
		d_ddp_dni.material_code*/
	from statement_tot_dni
	left join dds.delivery_document_position as d_ddp_dni												-- LIPS
		on d_ddp_dni.delivery_code = statement_tot_dni.delivery_number_initial							-- по LIPS-VBELN = SD.000001 "Исходная поставка"
	left join dds.delivery_document_header as d_ddh_dc													-- LIKP
		on d_ddh_dc.delivery_code = d_ddp_dni.delivery_code												-- по LIKP-VBELN = LIPS-VBELN
	left join dds.invoice_purchase_document_position as d_ipdp_tben										-- RSEG
		on d_ipdp_tben.purchase_document_code = d_ddp_dni.sales_document_code 							-- по RSEG-EBELN = LIPS-VGBEL
		and concat('0', d_ipdp_tben.purchase_document_position_line_item_code) =					-- и RSEG-EBELP =
				d_ddp_dni.sales_document_position_line_item_code										-- LIPS-VGPOS
			and d_ipdp_tben.material_code = d_ddp_dni.material_code										-- и RSEG-MATNR = LIPS-MATNR
			and COALESCE(d_ipdp_tben.reference_document_number, '_NULL_') = 							-- и RSEG-XBLNR =
				COALESCE(d_ddh_dc.transport_bill_external_number, d_ddp_dni.delivery_code, '_NULL_')	-- LIKP-LIFEX
	)
distributed by (
	invoice_code,fiscal_year,purchase_document_code,purchase_document_position_line_item_code);

-- 3. Добавить в LT_RSEG из EKBE полe VGABE
drop table if exists lt_rseg_ekbe;
create temp table lt_rseg_ekbe as (
	select
		lt_rseg.invoice_code, 										-- RSEG-BELNR
		lt_rseg.fiscal_year,										-- RSEG-GJAHR
		lt_rseg.purchase_document_code,								-- RSEG-EBELN
		lt_rseg.purchase_document_position_line_item_code,			-- RSEG-EBELP
		o_er.vgabe,													-- EKBE-VGABE
		lt_rseg.delivery_number_initial  							-- SD.000001 "Исходная поставка"
	from lt_rseg
	left join ods.ekbe_ral as o_er									-- LIPS
		on o_er.ebeln = lt_rseg.purchase_document_code				-- по EKBE-EBELN = LT_ RSEG-EBELN
			and o_er.ebelp = 										-- и EKBE-EBELP =
				lt_rseg.purchase_document_position_line_item_code	-- LT_ RSEG-EBELP
			and o_er.belnr = lt_rseg.invoice_code					-- и EKBE-BELNR	= LT_ RSEG-BELNR
			and o_er.gjahr = lt_rseg.fiscal_year					-- и EKBE-GJAHR	= LT_ RSEG-GJAHR
	)
distributed by (invoice_code,fiscal_year,purchase_document_code,purchase_document_position_line_item_code);

-- 4. Добавить в LT_RSEG из RBKP поля RBSTAT, STBLG
drop table if exists lt_rseg_rbkp;
create temp table lt_rseg_rbkp as (
	select
		lt_rseg_ekbe.invoice_code, 									-- RSEG-BELNR
		lt_rseg_ekbe.fiscal_year,									-- RSEG-GJAHR
		lt_rseg_ekbe.purchase_document_code,						-- RSEG-EBELN
		lt_rseg_ekbe.purchase_document_position_line_item_code,		-- RSEG-EBELP
		lt_rseg_ekbe.vgabe,											-- EKBE-VGABE
		d_ipdh_ic.invoice_status_code,								-- RBKP-RBSTAT
		d_ipdh_ic.reverse_document_code,							-- RBKP-STBLG
		lt_rseg_ekbe.delivery_number_initial  						-- SD.000001 "Исходная поставка"
	from lt_rseg_ekbe
	--
	left join
		dds.invoice_purchase_document_header as d_ipdh_ic			-- RBKP
		on d_ipdh_ic.invoice_code = lt_rseg_ekbe.invoice_code		-- и RBKP-BELNR	= LT_ RSEG-BELNR
		and d_ipdh_ic.fiscal_year = lt_rseg_ekbe.fiscal_year	-- и RBKP-GJAHR	= LT_ RSEG-GJAHR
	)
distributed by (invoice_code,fiscal_year,purchase_document_code,purchase_document_position_line_item_code);

-- 5. Выбрать в LT_BELNR из LT_RSEG строки с уникальным значением BELNR, GJAHR и Удалить строки LT_RSEG по RBSTAT <> 2 и STBLG = пусто
drop table if exists lt_rseg_tot;
create temp table lt_rseg_tot as (
	select distinct
		lt_rseg_rbkp.invoice_code, 									-- RSEG-BELNR
		lt_rseg_rbkp.fiscal_year,									-- RSEG-GJAHR
		lt_rseg_rbkp.delivery_number_initial  						-- SD.000001 "Исходная поставка"
	from lt_rseg_rbkp
	where lt_rseg_rbkp.invoice_status_code != '2'
	and lt_rseg_rbkp.reverse_document_code IS NULL
	)
distributed by (invoice_code,fiscal_year,delivery_number_initial);

-- 6. Собираем итоговый блок
drop table if exists statement_btp;
create temp table statement_btp as (
	select
		 statement_tot.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,statement_tot.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,statement_tot.plant_producer_name  									-- SD.000007 "Завод"
		,statement_tot.port_of_loading_name  									-- SD.000009 "Направление"
		,statement_tot.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,statement_tot.material_aggr_name  										-- SD.000016 "Материал"
		,statement_tot.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,statement_tot.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,statement_tot.dt_warehouse  											-- SD.000024 "Дата склада"
		,statement_tot.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,statement_tot.weight_net  												-- SD.000032 "Вес нетто"
		,statement_tot.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,statement_tot.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,statement_tot.contract_name  											-- SD.000038 "Контракт"
		,statement_tot.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,statement_tot.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,statement_tot.port_of_discharge_name  									-- SD.000045 "Порт выгрузки"
		,statement_tot.bill_of_lading_in_foreign_port  							-- SD.000048 "Коносамент в ин.порту"
		,statement_tot.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,statement_tot.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,statement_tot.delivery_basis  											-- SD.000067 "Базис поставки"
		,statement_tot.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,statement_tot.sales_order  											-- SD.000123 "Заказ ЦК"
		,statement_tot.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,statement_tot.grade_name  												-- SD.000145 "Марка по спецификации"
		,statement_tot.uni 														-- SD.000151 "UNI"
		,statement_tot.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,statement_tot.end_user_name  											-- SD.000164 "Конечный потребитель"
		,statement_tot.invoice_provisional_number  								-- SD.000167 "Provisional invoice"
		,statement_tot.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,statement_tot.dt_storage_end_in_foreign_port  							-- SD.000176 "Окончание хранения в ин. порту"
		,statement_tot.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,statement_tot.dt_storage_end_in_second_foreign_warehouse  				-- SD.000178 "Окончание хранение склад 2 "
		,statement_tot.material_shape_name_full  								-- SD.000180 "Форма"
		,statement_tot.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,statement_tot.country_of_discharge_port_name  							-- SD.000341 "Страна POD"
		,statement_tot.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,statement_tot.business_location_name  									-- SD.000492 "Статус в Supply chain (Business)"
		,statement_tot.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,statement_tot.lot_code  												-- SD.000580 "Номер лота"
		,statement_tot.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,statement_tot.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,statement_tot.dt_invoice_provisional  									-- SD.000620 "Дата инвойса"
		,statement_tot.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,statement_tot.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,statement_tot.dt_realization 											-- SD.000720 "Дата реализации"
		,statement_tot.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,statement_tot.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,'purchase_third_parties'::varchar
			as statement_data_group_code 										-- SD.001244 "Блок данных (statement)"
		,NULL::varchar as invoice_group_code 									-- SD.001245 "Группа инвойс (statement)"
		,statement_tot.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,lt_rseg_tot.invoice_code as purchase_invoice_code 						-- SD.001247 "Входящий счет (statement)"
		,lt_rseg_tot.fiscal_year as dt_purchase_invoice_yyyy 					-- SD.001248 "Год входящего счета (statement)"
		,CASE
			WHEN rseg_deb.invoice_code is not null		-- Если RSEG-TBTKZ = "X"
				THEN 0									-- то 0,
			ELSE -1 * statement_tot.weight_net  		-- иначе SD.000032 "Вес нетто" со знаком "-"
		END::numeric as net_weight												-- SD.001249 "Вес для statement"
		,NULL::varchar as statement_invoice_code 								-- SD.001250 "Фактура для statement"
		,NULL::varchar as statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,dd_c_pac.counterparty_full_name 				-- KNA1.NAME1 + KNA1.NAME2 + KNA1.NAME3 + KNA1.NAME4
			as supplier_3rd_party_code											-- SD.001361 "Внешний контрагент"
		,NULL::date as dt_payment												-- SD.001362 "Дата оплаты"
		,NULL::integer as dt_payment_week										-- SD.001363 "Неделя оплаты"
		,NULL::varchar as dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,NULL::date as dt_due_payment											-- SD.001365 "Срок оплаты"
		,NULL::varchar as payment_terms_code									-- SD.001366 "Условие платежа"
		,NULL::integer as payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,NULL::varchar as payment_terms_document_name							-- SD.001368 "Условие платежа (документ)"
		,NULL::varchar as market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,NULL::varchar as market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,NULL::varchar as metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,NULL::numeric as usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,NULL::numeric as document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
		,NULL::numeric as usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
		,NULL::varchar as invoice_realization_code								-- SD.001375 "Фактура реализации"
		,NULL::numeric as currency_exchange_rate								-- SD.001376 "Валютный курс"
		,NULL::varchar as direct_or_overseas_warehouse_delivery_name			-- SD.001377 "Склад/прямая поставка"
		,NULL::varchar as is_trader_name										-- SD.001378 "Трейдер"
		,NULL::varchar as prepayment_invoice_code								-- SD.001379 "Номер предоплатного инвойса"
		,NULL::varchar as sales_market_in_sales_request_code					-- SD.001380 "Рынок из заказа"
		,NULL::numeric as statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
		,'Закупка от третьих лиц'::varchar as block
		-------------------------------------------
		,statement_tot.batch
		,statement_tot.release_material_status_code
		,statement_tot.contract_type_code
		,statement_tot.double_record_in_temporary_warehouse_code
		,statement_tot.warehouse_shipment_type_name
		,statement_tot.shipment_market_code
		,statement_tot.delivery_number_outbound
		,statement_tot.plant_producer_code
		,statement_tot.lot_group
		,statement_tot.sales_contract_code
		,statement_tot.metal_exchange_type
		,statement_tot.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_tot
	-- SD.001247 "Входящий счет (statement)" -- SD.001248 "Год входящего счета (statement)"
	inner join lt_rseg_tot
		on statement_tot.delivery_number_initial = lt_rseg_tot.delivery_number_initial 	-- SD.000001 "Исходная поставка"
	-- SD.001249 "Вес для statement"
	left join rseg_deb																	-- RSEG
		on rseg_deb.invoice_code = lt_rseg_tot.invoice_code							-- RSEG-BELNR = SD.001247 "Входящий счет (statement)"
		and rseg_deb.fiscal_year = lt_rseg_tot.fiscal_year						-- и RSEG-GJARH = SD.001248 "Год входящего счета (statement)"
	-- SD.001361 "Внешний контрагент"
	left join dds.invoice_purchase_document_header as d_ipdh_pic							-- RBKP
		on d_ipdh_pic.invoice_code = lt_rseg_tot.invoice_code 						-- по RBKP-BELNR = SD.001247 "Входящий счет (statement)"
		and d_ipdh_pic.fiscal_year = lt_rseg_tot.fiscal_year					-- и RBKP-GJAHR = SD.001248 "Год входящего счета (statement)
	--
	left join dict_dds.counterparty as dd_c_pac											-- KNA1
		on dd_c_pac.counterparty_code = d_ipdh_pic.payee_alternative_code			-- по KNA1-KUNNR = RBKP-LIFNR
)
		distributed by (delivery_number_sales,batch);

--Блок Additional services
drop table if exists statement_as;
create temp table statement_as as (
	WITH st_as_main as (
		select
			 NULL::varchar as delivery_number_initial 			 								-- SD.000001 "Исходная поставка"
			,NULL::varchar as delivery_number_sales  											-- SD.000002 "Продажная поставка"
			,NULL::varchar as plant_producer_name  												-- SD.000007 "Завод"
			,NULL::varchar as port_of_loading_name 			 									-- SD.000009 "Направление"
			,NULL::date as dt_shipment  														-- SD.000010 "Дата отгрузки"
			,NULL::varchar as material_aggr_name  												-- SD.000016 "Материал"
			,NULL::varchar as material_group_code  												-- SD.000017 "Группа материалов (код)"
			,NULL::varchar as shipment_market_name  											-- SD.000019 "Рынок в отгрузке"
			,NULL::date as dt_warehouse  														-- SD.000024 "Дата склада"
			,NULL::varchar as transport_railcar_type_name  										-- SD.000029 "Тип вагона"
			,NULL::numeric as weight_net  														-- SD.000032 "Вес нетто"
			,NULL::varchar as customer_for_reporting_code  										-- SD.000036 "Покупатель (код)"
			,NULL::varchar as customer_for_reporting_name  										-- SD.000037 "Покупатель"
			,NULL::varchar as contract_name  													-- SD.000038 "Контракт"
			,NULL::varchar as bill_of_lading_number  											-- SD.000041 "Номер коносамента"
			,NULL::date as dt_bill_of_lading  													-- SD.000042 "Дата коносамента"
			,NULL::varchar as port_of_discharge_name			  								-- SD.000045 "Порт выгрузки"
			,NULL::varchar as bill_of_lading_in_foreign_port  									-- SD.000048 "Коносамент в ин.порту"
			,NULL::date as dt_bill_of_lading_in_foreign_port  									-- SD.000049 "Дата коносамента в ин.порту"
			,NULL::date as dt_arrival_in_port_of_discharge  									-- SD.000059 "Дата прибытия в порт выгрузки"
			,NULL::varchar as delivery_basis  													-- SD.000067 "Базис поставки"
			,NULL::varchar as delivery_point_name  												-- SD.000068 "Пункт доставки по инкотермс"
			,NULL::varchar as sales_order  														-- SD.000123 "Заказ ЦК"
			,NULL::date as dt_arrival_in_port_of_discharge_plan  								-- SD.000130 "Дата прибытия в порт выгрузки план"
			,NULL::varchar as grade_name  														-- SD.000145 "Марка по спецификации"
			,NULL::varchar as uni 																-- SD.000151 "UNI"
			,NULL::date as dt_arrival_in_second_port_of_discharge_plan							-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,NULL::varchar as end_user_name  													-- SD.000164 "Конечный потребитель"
			,NULL::varchar as invoice_provisional_number  										-- SD.000167 "Provisional invoice"
			,NULL::date as dt_storage_start_in_foreign_port  									-- SD.000175 "Дата начала хранения ин. склад"
			,NULL::date as dt_storage_end_in_foreign_port  										-- SD.000176 "Окончание хранения в ин. порту"
			,NULL::date as dt_storage_start_in_second_foreign_warehouse  						-- SD.000177 "Начало хранения склад 2 "
			,NULL::date as dt_storage_end_in_second_foreign_warehouse  							-- SD.000178 "Окончание хранение склад 2 "
			,NULL::varchar as material_shape_name_full  										-- SD.000180 "Форма"
			,NULL::varchar as delivery_region_name  											-- SD.000338 "Регион поставки по контракту"
			,NULL::varchar as country_of_discharge_port_name  									-- SD.000341 "Страна POD"
			,NULL::date as dt_prepared_for_realization  										-- SD.000344 "Дата готовности к релизу"
			,NULL::varchar as business_location_name  											-- SD.000492 "Статус в Supply chain (Business)"
			,NULL::varchar as delivery_country_in_contract_name  								-- SD.000576 "Страна поставки по контракту"
			,d_i.invoice_number
				as lot_code  																	-- SD.000580 "Номер лота"
			,NULL::varchar as customer_for_scm_report_name  									-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,NULL::varchar as vessel_and_voyage_actual_search_name  							-- SD.000608 "Судно / номер рейса (факт)"
			,d_i.dt_invoice
				as dt_invoice_provisional  														-- SD.000620 "Дата инвойса"
			,NULL::varchar as sales_team_name  													-- SD.000651 "Сбытовая команда"
			,NULL::varchar as dt_quota_yyyymm  													-- SD.000687 "Квота"
			,NULL::date as dt_realization 													-- SD.000720 "Дата реализации"
			,NULL::varchar as is_tolling_code                            						-- SD.000749 "Признак толлинг"
			,NULL::varchar as warehouse_or_responsible_customer_for_storage_name 				-- SD.000919 "General storage location"
			,'add_servises'::varchar
				as statement_data_group_code 													-- SD.001244 "Блок данных (statement)"
			,d_i.invoice_code
				as invoice_group_code 															-- SD.001245 "Группа инвойс (statement)"
			,EXTRACT(YEAR from d_i.dt_invoice)::varchar
				as dt_report_yyyy																-- SD.001246 "Год отчета (statement)"
			,NULL::varchar as purchase_invoice_code 											-- SD.001247 "Входящий счет (statement)"
			,NULL::varchar as dt_purchase_invoice_yyyy 											-- SD.001248 "Год входящего счета (statement)"
			,s_v."FKIMG"::numeric as net_weight 												-- SD.001249 "Вес для statement"
			,d_i.billing_document_code
				as statement_invoice_code 														-- SD.001250 "Фактура для statement"
			,d_irp_bdc.invoice_realization_position_code
				as statement_invoice_position_code 												-- SD.001251 "Позиция фактуры для statement"
			,NULL::varchar as supplier_3rd_party_code											-- SD.001361 "Внешний контрагент"
			,CASE
				WHEN d_i.billing_document_code is not null		-- Если SD.001250 "Фактура для statement" не пусто,
					THEN o_zr.zzpaydt							-- то, ZVBRK-ZZPAYDT,
				ELSE NULL 										-- иначе пусто
			END as dt_payment																	-- SD.001362 "Дата оплаты"
			,NULL::integer as dt_payment_week													-- SD.001363 "Неделя оплаты"
			,NULL::varchar as dt_payment_mm														-- SD.001364 "Месяц оплаты"
			,o_zr.zzasdate		-- ZVBRK-ZZASDATE
				 as dt_due_payment																-- SD.001365 "Срок оплаты"
			,vbsk1251.zzterm							-- VBSK-ZZTERM по 1-у условию
				as payment_terms_code															-- SD.001366 "Условие платежа"
			,NULL::integer as payment_terms_days_quantity										-- SD.001367 "Условие платежа (дни)"
			,NULL::varchar as payment_terms_document_name										-- SD.001368 "Условие платежа (документ)"
			,vbsk1251.zzkondm							-- VBSK-ZZKONDM по 1-у условию
				as market_indicator_code														-- SD.001369 "Рыночный индикатор (код)"
			,NULL::varchar as market_indicator_name												-- SD.001370 "Тип рыночного индикатора"
			,NULL::varchar as metal_exchange_type_code											-- SD.001371 "Тип биржи"
			,NULL::numeric as usd_currency_vat_excluded_amound									-- SD.001372 "Стоимость"
			,NULL::numeric as document_currency_vat_excluded_amound								-- SD.001373 "Стоимость в исходной валюте"
			,NULL::numeric as usd_currency_vat_included_amound									-- SD.001374 "Стоимость с НДС"
			,CASE
				WHEN vbrk.vbeln is not null 					-- Если VBRK-RFBSK = "C" (лат),
					THEN d_i.billing_document_code				-- то SD.001250 "Фактура для statement",
				ELSE NULL										-- иначе пусто
			END as invoice_realization_code														-- SD.001375 "Фактура реализации"
			,NULL::numeric as currency_exchange_rate											-- SD.001376 "Валютный курс"
			,'Direct delivery' as direct_or_overseas_warehouse_delivery_name					-- SD.001377 "Склад/прямая поставка"
			,NULL::varchar as is_trader_name													-- SD.001378 "Трейдер"
			,vbsk5.vtext										-- VBSK-VTEXT
				as prepayment_invoice_code														-- SD.001379 "Номер предоплатного инвойса"
			,NULL::varchar as sales_market_in_sales_request_code								-- SD.001380 "Рынок из заказа"
			,NULL::numeric as statement_calculated_weight										-- SD.001381 "Расчетный вес STATEMENT"
			,'Additional services'::varchar as block
			-------------------------------------------
			,NULL::varchar as batch
			,NULL::varchar as release_material_status_code
			,NULL::varchar as contract_type_code
			,NULL::varchar as double_record_in_temporary_warehouse_code
			,NULL::varchar as warehouse_shipment_type_name
			,NULL::varchar as shipment_market_code
			,NULL::varchar as delivery_number_outbound
			,NULL::varchar as plant_producer_code
			,NULL::varchar as lot_group
			,NULL::varchar as sales_contract_code
			,o_tfsfrt1.text_value as metal_exchange_type
			,NULL::varchar as is_shipped_via_overseas_warehouse									-- SD.000483 "Наличие Иностранный склад"
		from dds.invoice as d_i												-- VBSK
		-- SD.001249 "Вес для statement" -- SD.001251 "Позиция фактуры для statement"
		left join dds.invoice_realization_position as d_irp_bdc					-- VBRP
			on d_irp_bdc.invoice_realization_code =	d_i.billing_document_code	-- VBRP-VBELN = VBSK-ZZVBELN
		-- заменить на dds поле fkimg
		left join stg."VBRP" as s_v
			on tech_etl.util_text_to_null_validation(s_v."VBELN") =  d_irp_bdc.invoice_realization_code
				and tech_etl.util_text_to_null_validation(s_v."POSNR") = d_irp_bdc.invoice_realization_position_code
 		-- SD.001362 "Дата оплаты" -- SD.001365 "Срок оплаты"
	    left join ods.zvbrk_ral as o_zr									   -- ZVBRK
			on o_zr.vbeln = d_i.billing_document_code 						-- по ZVBRK-VBELN = SD.001250 "Фактура для statement"
		-- SD.001366 "Условие платежа" -- SD.001369 "Рыночный индикатор (код)"
		 left join ods.vbsk_ral as vbsk1251										-- VBSK
	    	on vbsk1251.sammg = d_i.invoice_code							-- по VBSK-SAMMG = SD.001245 "Группа инвойс (statement)"
	    -- SD.001371 "Тип биржи"
	    left join ods.texts_from_sap_fm_read_text as o_tfsfrt1					-- ФМ READ_TEXT
			on o_tfsfrt1.text_key_identifier_code = d_i.billing_document_code -- по TDNAME =  VBSK-ZZVBELN
			and o_tfsfrt1.text_object_identifier_code = 'TR96'			-- и TDID = TR96
			and o_tfsfrt1.language_code = 'R'        					-- и = "RU"
			and o_tfsfrt1.application_object_code = 'VBBK' 				-- и TDOBJECT = VBBK
			and o_tfsfrt1.is_active is true
		-- SD.001375 "Фактура реализации"
		left join ods.vbrk_ral as vbrk											-- VBRK
			on vbrk.vbeln = d_i.billing_document_code 						-- по VBRK-VBELN = SD.001250 "Фактура для statement"
			and vbrk.rfbsk = 'C'										-- и VBRK-RFBSK = "C" (лат)
		-- SD.001379 "Номер предоплатного инвойса"
		left join ods."/rusal/sd2921mgo_ral" as mgo								-- /RUSAL/SD2921MGO
			on mgo.sammg_o = d_i.invoice_code  								-- по /RUSAL/SD2921MGO-SAMMG_O = SD.001245 "Группа инвойс (statement)"
		--
		left join ods.vbsk_ral as vbsk5											-- VBSK
			on vbsk5.sammg = mgo.sammg										-- по VBSK-SAMMG = /RUSAL/SD2921MGO-SAMMG
		--
		where d_i.invoice_code is not null 									-- VBSK-SAMMG не пусто
		and d_i.invoice_type_code = 'У'									-- VBSK-SMART = "У" (услуги)
		and d_i.billing_document_code is not null 						-- и VBSK-ZZVBELN не пусто
		and d_i.dt_invoice >= '2024-01-01'								-- и VBSK-ZZLDDAT => 01.01.2024
		),
	st_as_prev as (
		select
			 st_as_main.delivery_number_initial 			 					-- SD.000001 "Исходная поставка"
			,st_as_main.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,st_as_main.plant_producer_name  									-- SD.000007 "Завод"
			,st_as_main.port_of_loading_name 			 						-- SD.000009 "Направление"
			,st_as_main.dt_shipment  											-- SD.000010 "Дата отгрузки"
			,st_as_main.material_aggr_name  									-- SD.000016 "Материал"
			,st_as_main.material_group_code  									-- SD.000017 "Группа материалов (код)"
			,st_as_main.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,st_as_main.dt_warehouse  											-- SD.000024 "Дата склада"
			,st_as_main.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
			,st_as_main.weight_net  											-- SD.000032 "Вес нетто"
			,st_as_main.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
			,st_as_main.customer_for_reporting_name  							-- SD.000037 "Покупатель"
			,st_as_main.contract_name  											-- SD.000038 "Контракт"
			,st_as_main.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,st_as_main.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,st_as_main.port_of_discharge_name			  						-- SD.000045 "Порт выгрузки"
			,st_as_main.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
			,st_as_main.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,st_as_main.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
			,st_as_main.delivery_basis  										-- SD.000067 "Базис поставки"
			,st_as_main.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
			,st_as_main.sales_order  											-- SD.000123 "Заказ ЦК"
			,st_as_main.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,st_as_main.grade_name  											-- SD.000145 "Марка по спецификации"
			,st_as_main.uni 													-- SD.000151 "UNI"
			,st_as_main.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,st_as_main.end_user_name  											-- SD.000164 "Конечный потребитель"
			,st_as_main.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
			,st_as_main.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,st_as_main.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
			,st_as_main.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,st_as_main.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
			,st_as_main.material_shape_name_full  								-- SD.000180 "Форма"
			,st_as_main.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,st_as_main.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
			,st_as_main.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
			,st_as_main.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
			,st_as_main.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,st_as_main.lot_code  												-- SD.000580 "Номер лота"
			,st_as_main.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,st_as_main.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,st_as_main.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
			,st_as_main.sales_team_name  										-- SD.000651 "Сбытовая команда"
			,st_as_main.dt_quota_yyyymm  										-- SD.000687 "Квота"
			,st_as_main.dt_realization 											-- SD.000720 "Дата реализации"
			,st_as_main.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,st_as_main.warehouse_or_responsible_customer_for_storage_name 		-- SD.000919 "General storage location"
			,st_as_main.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,st_as_main.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
			,st_as_main.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
			,st_as_main.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,st_as_main.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
			,st_as_main.net_weight 												-- SD.001249 "Вес для statement"
			,st_as_main.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,st_as_main.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
			,st_as_main.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,st_as_main.dt_payment												-- SD.001362 "Дата оплаты"
			,EXTRACT(week from st_as_main.dt_payment)::integer
				as dt_payment_week												-- SD.001363 "Неделя оплаты"
			,to_char(st_as_main.dt_payment, 'mm.yyyy') as dt_payment_mm			-- SD.001364 "Месяц оплаты"
			,st_as_main.dt_due_payment											-- SD.001365 "Срок оплаты"
			,st_as_main.payment_terms_code
			,dd_topd.payment_terms_days_quantity					-- /RUSAL/ZTERM-DAYS1
				as payment_terms_days_quantity									-- SD.001367 "Условие платежа (дни)"
			,dd_ptdt.payment_terms_document_name					-- D007T-DDTEXT
				as payment_terms_document_name									-- SD.001368 "Условие платежа (документ)"
			,st_as_main.market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
			,dd_mpgt.material_price_group_name						-- T178-VTEXT
				as market_indicator_name										-- SD.001370 "Тип рыночного индикатора"
			,dd_certt.currency_exchange_rate_type_name				-- TCURW-CURVW
				as metal_exchange_type_code										-- SD.001371 "Тип биржи"
			,st_as_main.usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
			,st_as_main.document_currency_vat_excluded_amound					-- SD.001373 "Стоимость в исходной валюте"
			,st_as_main.usd_currency_vat_included_amound						-- SD.001374 "Стоимость с НДС"
			,st_as_main.invoice_realization_code								-- SD.001375 "Фактура реализации"
			,CASE
				WHEN vbrk.waerk = 'USD'							-- Если VBRK-WAERK = "USD",
					THEN 1										-- то "1",
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate != 1						-- и BKPF-KURSF != 1,
					THEN bkpf.exchange_rate							-- то BKPF-KURSF,
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate = 1						-- и BKPF-KURSF = 1,
					THEN dd_cr.currency_rate					-- то TCURR-UKURS,
				WHEN st_as_main.statement_invoice_code IS NULL
					-- если SD.001375 "Фактура реализации" пусто,
					THEN replace(o_tfsfrt9.text_value, '-', '')::numeric -- то ФМ READ_TEXT-текст TR29
			END::numeric
			as currency_exchange_rate									-- SD.001376 "Валютный курс"
			,st_as_main.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,st_as_main.is_trader_name											-- SD.001378 "Трейдер"
			,st_as_main.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,st_as_main.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,coalesce(vbrp.brgew,									-- VBRP-BRGEW,
				st_as_main.weight_net)  									-- если VBRP-BRGEW пусто, то SD.000032 "Вес нетто"
				as statement_calculated_weight									-- SD.001381 "Расчетный вес STATEMENT"
			,st_as_main.block
			-------------------------------------------
			,st_as_main.batch
			,st_as_main.release_material_status_code
			,st_as_main.contract_type_code
			,st_as_main.double_record_in_temporary_warehouse_code
			,st_as_main.warehouse_shipment_type_name
			,st_as_main.shipment_market_code
			,st_as_main.delivery_number_outbound
			,st_as_main.plant_producer_code
			,st_as_main.lot_group
			,st_as_main.sales_contract_code
			,st_as_main.metal_exchange_type
			,st_as_main.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
		from st_as_main
		-- SD.001367 "Условие платежа (дни)"
		left join dd_topd						-- /RUSAL/ZTERM
			on dd_topd.terms_of_payment_code = st_as_main.payment_terms_code	-- по /RUSAL/ZTERM-ZTERM = SD.001366 "Условие платежа"
		-- SD.001368 "Условие платежа (документ)"
		left join dict_dds.tech_rusal_paydocev as dd_trp								-- /RUSAL/PAYDOCEV
			on dd_trp.event = dd_topd.payment_event_code						-- по /RUSAL/PAYDOCEV-EVENT = /RUSAL/ZTERM-SOB1
		--
		left join dict_dds.payment_terms_document_texts as dd_ptdt					-- D007T
			on dd_ptdt.payment_terms_document_code = dd_trp.docum				-- по D007T-DOMVALUE_L = /RUSAL/PAYDOCEV-DOCUM
			and dd_ptdt.language_code = 'E'									-- и D007T-DOLANGUAGE = "EN"
		-- SD.001370 "Тип рыночного индикатора"
		left join dict_dds.material_price_group_texts as dd_mpgt 						-- T178
			on dd_mpgt.material_price_group_code = 	st_as_main.market_indicator_code -- T178-KONDM = SD.001369 "Рыночный индикатор (код)"
			and dd_mpgt.language_code = 'E'
		-- SD.001371 "Тип биржи"
		left join dict_dds.currency_exchange_rate_type_texts as dd_certt				-- TCURW
			on dd_certt.currency_exchange_rate_type_code = st_as_main.metal_exchange_type -- TCURW-KURST =
			and dd_certt.language_code = 'E'								-- TCURW-SPRAS = "EN"
		-- SD.001376 "Валютный курс"
	    left join ods.vbrk_ral as vbrk												-- VBRK
	    	on vbrk.vbeln = st_as_main.statement_invoice_code 					-- по VBRK-VBELN = SD.001250 "Фактура для statement"
	    --
	    left join dm_calc.accounting_document_header as bkpf
	    	on bkpf.reference_object_key_code = st_as_main.invoice_realization_code -- по BKPF-AWKEY = -- SD.001375 "Фактура реализации"
	    	--
	    left join dict_dds.currency_rates as dd_cr								-- TCURR
	    	on dd_cr.currency_from_code = bkpf.document_currency_code -- по TCURR-FCURR = BKPF-WAERS
	    	and dd_cr.dt_currency_rate = bkpf.dt_posting	 -- и TCURR-GDATU = BKPF-BUDAT
	    	and dd_cr.currency_rate_type_code = 'M'							-- и TCURR-KURST = "M"
	    	and dd_cr.currency_to_code = 'USD'									-- и TCURR-TCURR = "USD"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt9						-- ФМ READ_TEXT
			on o_tfsfrt9.text_key_identifier_code = vbrk.vbeln	 				-- по TDNAME = VBRK-VBELN
			and o_tfsfrt9.text_object_identifier_code = 'TR29'				-- и TDID = TR29
			and o_tfsfrt9.language_code = 'R'        						-- и = "RU"
			and o_tfsfrt9.application_object_code = 'VBBK' 					-- и TDOBJECT = VBBK
			and o_tfsfrt9.is_active is true
		-- SD.001381 "Расчетный вес STATEMENT"
		left join ods.vbrp_ral as vbrp												-- VBRP
			on vbrp.vbeln = st_as_main.statement_invoice_code 					-- по VBRP-VBELN = SD.001250 "Фактура для statement"
			and vbrp.posnr = st_as_main.statement_invoice_position_code 	-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
			and vbrp.kvgr5 = '010'											-- и VBRP-KVGR5 = "010"
	)
	select
		 sap.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,sap.delivery_number_sales  								-- SD.000002 "Продажная поставка"
		,sap.plant_producer_name  									-- SD.000007 "Завод"
		,sap.port_of_loading_name  									-- SD.000009 "Направление"
		,sap.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,sap.material_aggr_name  									-- SD.000016 "Материал"
		,sap.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,sap.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,sap.dt_warehouse  											-- SD.000024 "Дата склада"
		,sap.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,sap.weight_net  											-- SD.000032 "Вес нетто"
		,sap.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,sap.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,sap.contract_name  										-- SD.000038 "Контракт"
		,sap.bill_of_lading_number  								-- SD.000041 "Номер коносамента"
		,sap.dt_bill_of_lading  									-- SD.000042 "Дата коносамента"
		,sap.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,sap.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,sap.dt_bill_of_lading_in_foreign_port  					-- SD.000049 "Дата коносамента в ин.порту"
		,sap.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,sap.delivery_basis  										-- SD.000067 "Базис поставки"
		,sap.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,sap.sales_order  											-- SD.000123 "Заказ ЦК"
		,sap.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,sap.grade_name  											-- SD.000145 "Марка по спецификации"
		,sap.uni 													-- SD.000151 "UNI"
		,sap.dt_arrival_in_second_port_of_discharge_plan			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,sap.end_user_name  										-- SD.000164 "Конечный потребитель"
		,sap.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,sap.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,sap.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,sap.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,sap.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,sap.material_shape_name_full  								-- SD.000180 "Форма"
		,sap.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,sap.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,sap.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,sap.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,sap.delivery_country_in_contract_name  					-- SD.000576 "Страна поставки по контракту"
		,sap.lot_code  												-- SD.000580 "Номер лота"
		,sap.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,sap.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,sap.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,sap.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,sap.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,sap.dt_realization 										-- SD.000720 "Дата реализации"
		,sap.is_tolling_code                            			-- SD.000749 "Признак толлинг"
		,sap.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,sap.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,sap.invoice_group_code 									-- SD.001245 "Группа инвойс (statement)"
		,sap.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,sap.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,sap.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,sap.net_weight 											-- SD.001249 "Вес для statement"
		,sap.statement_invoice_code 								-- SD.001250 "Фактура для statement"
		,sap.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,sap.supplier_3rd_party_code								-- SD.001361 "Внешний контрагент"
		,sap.dt_payment												-- SD.001362 "Дата оплаты"
		,sap.dt_payment_week										-- SD.001363 "Неделя оплаты"
		,sap.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,sap.dt_due_payment											-- SD.001365 "Срок оплаты"
		,sap.payment_terms_code										-- SD.001366 "Условие платежа"
		,sap. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,sap.payment_terms_document_name							-- SD.001368 "Условие платежа (документ)"
		,sap. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,sap.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,sap.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,case
			when sap.currency_exchange_rate < 0 then vbrp.netwr / abs(sap.currency_exchange_rate)
			when sap.currency_exchange_rate > 0 then vbrp.netwr * abs(sap.currency_exchange_rate)
		end as usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,vbrp.netwr 								-- VBRP-NETWR
			as document_currency_vat_excluded_amound				-- SD.001373 "Стоимость в исходной валюте"
		,case
			when sap.currency_exchange_rate < 0 then (vbrp.netwr + vbrp.mwsbp) / abs(sap.currency_exchange_rate)
			when sap.currency_exchange_rate > 0 then (vbrp.netwr + vbrp.mwsbp) * abs(sap.currency_exchange_rate)
		end as usd_currency_vat_included_amound					-- SD.001374 "Стоимость с НДС"
		,sap.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,sap.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,sap.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,sap.is_trader_name											-- SD.001378 "Трейдер"
		,sap.prepayment_invoice_code								-- SD.001379 "Номер предоплатного инвойса"
		,sap.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,sap.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
		,sap.block
		-------------------------------------------
		,sap.batch
		,sap.release_material_status_code
		,sap.contract_type_code
		,sap.double_record_in_temporary_warehouse_code
		,sap.warehouse_shipment_type_name
		,sap.shipment_market_code
		,sap.delivery_number_outbound
		,sap.plant_producer_code
		,sap.lot_group
		,sap.sales_contract_code
		,sap.metal_exchange_type
		,sap.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from st_as_prev as sap
	-- SD.001372 "Стоимость" -- SD.001373 "Стоимость в исходной валюте" -- SD.001374 "Стоимость с НДС"
	left join ods.vbrp_ral as vbrp										-- VBRP
	    on vbrp.vbeln = sap.statement_invoice_code 					-- по VBRP-VBELN = SD.001250 "Фактура для statement"
	    and vbrp.posnr = sap.statement_invoice_position_code 	-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
	)
distributed by (delivery_number_sales,batch);

-- Блок Предоплата
drop table if exists statement_pp_vbsk;
create temp table statement_pp_vbsk as (
		select
			 NULL::varchar as delivery_number_initial 			 								-- SD.000001 "Исходная поставка"
			,NULL::varchar as delivery_number_sales  											-- SD.000002 "Продажная поставка"
			,NULL::varchar as plant_producer_name  												-- SD.000007 "Завод"
			,NULL::varchar as port_of_loading_name 			 									-- SD.000009 "Направление"
			,NULL::date as dt_shipment  														-- SD.000010 "Дата отгрузки"
			,NULL::varchar as material_aggr_name  												-- SD.000016 "Материал"
			,NULL::varchar as material_group_code  												-- SD.000017 "Группа материалов (код)"
			,NULL::varchar as shipment_market_name  											-- SD.000019 "Рынок в отгрузке"
			,NULL::date as dt_warehouse  														-- SD.000024 "Дата склада"
			,NULL::varchar as transport_railcar_type_name  										-- SD.000029 "Тип вагона"
			,NULL::numeric as weight_net  														-- SD.000032 "Вес нетто"
			,NULL::varchar as customer_for_reporting_code  										-- SD.000036 "Покупатель (код)"
			,NULL::varchar as customer_for_reporting_name  										-- SD.000037 "Покупатель"
			,NULL::varchar as contract_name  													-- SD.000038 "Контракт"
			,NULL::varchar as bill_of_lading_number  											-- SD.000041 "Номер коносамента"
			,NULL::date as dt_bill_of_lading  													-- SD.000042 "Дата коносамента"
			,NULL::varchar as port_of_discharge_name			  								-- SD.000045 "Порт выгрузки"
			,NULL::varchar as bill_of_lading_in_foreign_port  									-- SD.000048 "Коносамент в ин.порту"
			,NULL::date as dt_bill_of_lading_in_foreign_port  									-- SD.000049 "Дата коносамента в ин.порту"
			,NULL::date as dt_arrival_in_port_of_discharge  									-- SD.000059 "Дата прибытия в порт выгрузки"
			,NULL::varchar as delivery_basis  													-- SD.000067 "Базис поставки"
			,NULL::varchar as delivery_point_name  												-- SD.000068 "Пункт доставки по инкотермс"
			,NULL::varchar as sales_order  														-- SD.000123 "Заказ ЦК"
			,NULL::date as dt_arrival_in_port_of_discharge_plan  								-- SD.000130 "Дата прибытия в порт выгрузки план"
			,NULL::varchar as grade_name  														-- SD.000145 "Марка по спецификации"
			,NULL::varchar as uni 																-- SD.000151 "UNI"
			,NULL::date as dt_arrival_in_second_port_of_discharge_plan							-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,NULL::varchar as end_user_name  													-- SD.000164 "Конечный потребитель"
			,NULL::varchar as invoice_provisional_number  										-- SD.000167 "Provisional invoice"
			,NULL::date as dt_storage_start_in_foreign_port  									-- SD.000175 "Дата начала хранения ин. склад"
			,NULL::date as dt_storage_end_in_foreign_port  										-- SD.000176 "Окончание хранения в ин. порту"
			,NULL::date as dt_storage_start_in_second_foreign_warehouse  						-- SD.000177 "Начало хранения склад 2 "
			,NULL::date as dt_storage_end_in_second_foreign_warehouse  							-- SD.000178 "Окончание хранение склад 2 "
			,NULL::varchar as material_shape_name_full  										-- SD.000180 "Форма"
			,NULL::varchar as delivery_region_name  											-- SD.000338 "Регион поставки по контракту"
			,NULL::varchar as country_of_discharge_port_name  									-- SD.000341 "Страна POD"
			,NULL::date as dt_prepared_for_realization  										-- SD.000344 "Дата готовности к релизу"
			,NULL::varchar as business_location_name  											-- SD.000492 "Статус в Supply chain (Business)"
			,NULL::varchar as delivery_country_in_contract_name  								-- SD.000576 "Страна поставки по контракту"
			,NULL::varchar as lot_code  														-- SD.000580 "Номер лота"
			,NULL::varchar as customer_for_scm_report_name  									-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,NULL::varchar as vessel_and_voyage_actual_search_name  							-- SD.000608 "Судно / номер рейса (факт)"
			,NULL::date as dt_invoice_provisional  											-- SD.000620 "Дата инвойса"
			,NULL::varchar as sales_team_name  													-- SD.000651 "Сбытовая команда"
			,NULL::varchar as dt_quota_yyyymm  													-- SD.000687 "Квота"
			,NULL::date as dt_realization 													-- SD.000720 "Дата реализации"
			,NULL::varchar as is_tolling_code                            						-- SD.000749 "Признак толлинг"
			,NULL::varchar as warehouse_or_responsible_customer_for_storage_name 				-- SD.000919 "General storage location"
			,'prepayment'::varchar as statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,d_i.sammg as invoice_group_code 													-- SD.001245 "Группа инвойс (statement)"
			,EXTRACT(YEAR from d_i.zzlddat)::varchar
				as dt_report_yyyy																-- SD.001246 "Год отчета (statement)"
			,NULL::varchar as purchase_invoice_code 											-- SD.001247 "Входящий счет (statement)"
			,NULL::varchar as dt_purchase_invoice_yyyy 											-- SD.001248 "Год входящего счета (statement)"
			,s_v."FKIMG"::numeric as net_weight 												-- SD.001249 "Вес для statement"
			,d_i.zzvbeln as statement_invoice_code 												-- SD.001250 "Фактура для statement"
			,d_irp_bdc.invoice_realization_position_code as statement_invoice_position_code 	-- SD.001251 "Позиция фактуры для statement"
			,NULL::varchar  as supplier_3rd_party_code											-- SD.001361 "Внешний контрагент"
			,CASE
				WHEN d_i.zzvbeln is not null		-- Если SD.001250 "Фактура для statement" не пусто,
					THEN o_zr.zzpaydt							-- то, ZVBRK-ZZPAYDT,
				ELSE NULL 										-- иначе пусто
			END as dt_payment																	-- SD.001362 "Дата оплаты"
			,NULL::integer as dt_payment_week													-- SD.001363 "Неделя оплаты"
			,NULL::varchar as dt_payment_mm														-- SD.001364 "Месяц оплаты"
			,o_zr.zzasdate		-- ZVBRK-ZZASDATE
				as dt_due_payment																-- SD.001365 "Срок оплаты"
			,vbsk1251.zzterm									-- VBSK-ZZTERM по 1-у условию,
				as payment_terms_code															-- SD.001366 "Условие платежа"
			,NULL::integer as payment_terms_days_quantity										-- SD.001367 "Условие платежа (дни)"
			,NULL::varchar as payment_terms_document_name										-- SD.001368 "Условие платежа (документ)"
			,vbsk1251.zzkondm									-- VBSK-ZZTERM по 1-у условию
				as market_indicator_code														-- SD.001369 "Рыночный индикатор (код)"
			,NULL::varchar as market_indicator_name												-- SD.001370 "Тип рыночного индикатора"
			,NULL::varchar as metal_exchange_type_code											-- SD.001371 "Тип биржи"
			,NULL::numeric as usd_currency_vat_excluded_amound									-- SD.001372 "Стоимость"
			,NULL::numeric as document_currency_vat_excluded_amound								-- SD.001373 "Стоимость в исходной валюте"
			,NULL::numeric as usd_currency_vat_included_amound									-- SD.001374 "Стоимость с НДС"
			,NULL::varchar as invoice_realization_code											-- SD.001375 "Фактура реализации"
			,NULL::numeric as currency_exchange_rate											-- SD.001376 "Валютный курс"
			,'Direct delivery' as direct_or_overseas_warehouse_delivery_name					-- SD.001377 "Склад/прямая поставка"
			,NULL::varchar as is_trader_name													-- SD.001378 "Трейдер"
			,vbsk5.vtext										-- VBSK-VTEXT
				as prepayment_invoice_code														-- SD.001379 "Номер предоплатного инвойса"
			,NULL::varchar as sales_market_in_sales_request_code								-- SD.001380 "Рынок из заказа"
			,NULL::numeric as statement_calculated_weight										-- SD.001381 "Расчетный вес STATEMENT"
			,'Предоплата'::varchar as block
			-------------------------------------------
			,NULL::varchar as batch
			,NULL::varchar as release_material_status_code
			,NULL::varchar as contract_type_code
			,NULL::varchar as double_record_in_temporary_warehouse_code
			,NULL::varchar as warehouse_shipment_type_name
			,NULL::varchar as shipment_market_code
			,NULL::varchar as delivery_number_outbound
			,NULL::varchar as plant_producer_code
			,NULL::varchar as lot_group
			,NULL::varchar as sales_contract_code
			,o_tfsfrt1.text_value as metal_exchange_type
			,NULL::varchar as is_shipped_via_overseas_warehouse									-- SD.000483 "Наличие Иностранный склад"
		from ods.vbsk_ral as d_i												-- VBSK
		-- SD.001249 "Вес для statement" -- SD.001251 "Позиция фактуры для statement"
		left join dds.invoice_realization_position as d_irp_bdc					-- VBRP
			on d_irp_bdc.invoice_realization_code =	d_i.zzvbeln		-- VBRP-VBELN = VBSK-ZZVBELN
		-- пока не перенесут на прод в таблицу vbrp поле fkimg
		left join stg."VBRP" as s_v
			on tech_etl.util_text_to_null_validation(s_v."VBELN") = d_irp_bdc.invoice_realization_code
			and tech_etl.util_text_to_null_validation(s_v."POSNR") = d_irp_bdc.invoice_realization_position_code
		 -- SD.001362 "Дата оплаты" -- SD.001365 "Срок оплаты"
		left join ods.zvbrk_ral as o_zr											-- ZVBRK
			on o_zr.vbeln = d_i.zzvbeln 									-- по ZVBRK-VBELN = SD.001250 "Фактура для statement"
		-- SD.001366 "Условие платежа" -- SD.001369 "Рыночный индикатор (код)"
		 left join ods.vbsk_ral as vbsk1251										-- VBSK
	    	on vbsk1251.sammg = d_i.sammg									-- по VBSK-SAMMG = SD.001245 "Группа инвойс (statement)"
	    -- SD.001371 "Тип биржи"
	    left join ods.texts_from_sap_fm_read_text as o_tfsfrt1					-- ФМ READ_TEXT
			on o_tfsfrt1.text_key_identifier_code = d_i.zzvbeln			-- по TDNAME = VBSK-ZZVBELN
			and o_tfsfrt1.text_object_identifier_code = 'TR96'			-- и TDID = TR96
			and o_tfsfrt1.language_code = 'R'        					-- и = "RU"
			and o_tfsfrt1.application_object_code = 'VBBK' 				-- и TDOBJECT = VBBK
			and o_tfsfrt1.is_active is true
		-- SD.001379 "Номер предоплатного инвойса"
		left join 	ods."/rusal/sd2921mgo_ral" as mgo								-- /RUSAL/SD2921MGO
			on mgo.sammg_o = d_i.sammg										-- по /RUSAL/SD2921MGO-SAMMG_O = SD.001245 "Группа инвойс (statement)"
		--
		left join ods.vbsk_ral as vbsk5											-- VBSK
			on vbsk5.sammg = mgo.sammg										-- по VBSK-SAMMG = /RUSAL/SD2921MGO-SAMMG
		--
		where
			d_i.sammg is not null 											-- VBSK-SAMMG не пусто
			and d_i.smart = 'О'												-- VBSK-SMART ="О" (Invoice, кириллица)
			and d_i.zzvbeln is not null 									-- и VBSK-ZZVBELN не пусто
			and d_i.zzstatus = 'P'											-- и VBSK-ZZSTATUS = "P" (Prepayment invoice, латиница)
			and d_i.zzlddat >= '2024-01-01'									-- и VBSK-ZZLDDAT => 01.01.2024
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_pp_vbsk_prev;
create temp table statement_pp_vbsk_prev as (
		select
			 vbsk.delivery_number_initial  									-- SD.000001 "Исходная поставка"
			,vbsk.delivery_number_sales  									-- SD.000002 "Продажная поставка"
			,vbsk.plant_producer_name  										-- SD.000007 "Завод"
			,vbsk.port_of_loading_name  									-- SD.000009 "Направление"
			,vbsk.dt_shipment  												-- SD.000010 "Дата отгрузки"
			,vbsk.material_aggr_name  										-- SD.000016 "Материал"
			,vbsk.material_group_code  										-- SD.000017 "Группа материалов (код)"
			,vbsk.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
			,vbsk.dt_warehouse  											-- SD.000024 "Дата склада"
			,vbsk.transport_railcar_type_name  								-- SD.000029 "Тип вагона"
			,vbsk.weight_net  												-- SD.000032 "Вес нетто"
			,vbsk.customer_for_reporting_code  								-- SD.000036 "Покупатель (код)"
			,vbsk.customer_for_reporting_name  								-- SD.000037 "Покупатель"
			,vbsk.contract_name  											-- SD.000038 "Контракт"
			,vbsk.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
			,vbsk.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
			,vbsk.port_of_discharge_name  									-- SD.000045 "Порт выгрузки"
			,vbsk.bill_of_lading_in_foreign_port  							-- SD.000048 "Коносамент в ин.порту"
			,vbsk.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
			,vbsk.dt_arrival_in_port_of_discharge  							-- SD.000059 "Дата прибытия в порт выгрузки"
			,vbsk.delivery_basis  											-- SD.000067 "Базис поставки"
			,vbsk.delivery_point_name  										-- SD.000068 "Пункт доставки по инкотермс"
			,vbsk.sales_order  												-- SD.000123 "Заказ ЦК"
			,vbsk.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
			,vbsk.grade_name  												-- SD.000145 "Марка по спецификации"
			,vbsk.uni 														-- SD.000151 "UNI"
			,vbsk.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
			,vbsk.end_user_name  											-- SD.000164 "Конечный потребитель"
			,vbsk.invoice_provisional_number  								-- SD.000167 "Provisional invoice"
			,vbsk.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
			,vbsk.dt_storage_end_in_foreign_port  							-- SD.000176 "Окончание хранения в ин. порту"
			,vbsk.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
			,vbsk.dt_storage_end_in_second_foreign_warehouse  				-- SD.000178 "Окончание хранение склад 2 "
			,vbsk.material_shape_name_full  								-- SD.000180 "Форма"
			,vbsk.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
			,vbsk.country_of_discharge_port_name  							-- SD.000341 "Страна POD"
			,vbsk.dt_prepared_for_realization  								-- SD.000344 "Дата готовности к релизу"
			,vbsk.business_location_name  									-- SD.000492 "Статус в Supply chain (Business)"
			,vbsk.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
			,vbsk.lot_code  												-- SD.000580 "Номер лота"
			,vbsk.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
			,vbsk.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
			,vbsk.dt_invoice_provisional  									-- SD.000620 "Дата инвойса"
			,vbsk.sales_team_name  											-- SD.000651 "Сбытовая команда"
			,vbsk.dt_quota_yyyymm  											-- SD.000687 "Квота"
			,vbsk.dt_realization 											-- SD.000720 "Дата реализации"
			,vbsk.is_tolling_code                            				-- SD.000749 "Признак толлинг"
			,vbsk.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
			,vbsk.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
			,vbsk.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
			,vbsk.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
			,vbsk.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
			,vbsk.dt_purchase_invoice_yyyy 									-- SD.001248 "Год входящего счета (statement)"
			,vbsk.net_weight 												-- SD.001249 "Вес для statement"
			,vbsk.statement_invoice_code 									-- SD.001250 "Фактура для statement"
			,vbsk.statement_invoice_position_code 							-- SD.001251 "Позиция фактуры для statement"
			,vbsk.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
			,vbsk.dt_payment												-- SD.001362 "Дата оплаты"
			,EXTRACT (week from vbsk.dt_payment)::integer
				as dt_payment_week											-- SD.001363 "Неделя оплаты"
			,to_char(vbsk.dt_payment, 'mm.yyyy') as dt_payment_mm			-- SD.001364 "Месяц оплаты"
			,vbsk.dt_due_payment											-- SD.001365 "Срок оплаты"
			,vbsk.payment_terms_code										-- SD.001366 "Условие платежа"
			,dd_topd.payment_terms_days_quantity					-- /RUSAL/ZTERM-DAYS1
				as payment_terms_days_quantity								-- SD.001367 "Условие платежа (дни)"
			,dd_ptdt.payment_terms_document_name					-- D007T-DDTEXT
				as payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
			,vbsk.market_indicator_code										-- SD.001369 "Рыночный индикатор (код)"
			,dd_mpgt.material_price_group_name						-- T178-VTEXT
				as market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
			,dd_certt.currency_exchange_rate_type_name				-- TCURW-CURVW
				as metal_exchange_type_code									-- SD.001371 "Тип биржи"
			,vbsk.usd_currency_vat_excluded_amound							-- SD.001372 "Стоимость"
			,vbsk.document_currency_vat_excluded_amound						-- SD.001373 "Стоимость в исходной валюте"
			,vbsk. usd_currency_vat_included_amound							-- SD.001374 "Стоимость с НДС"
			,vbsk.invoice_realization_code									-- SD.001375 "Фактура реализации"
			,CASE
				WHEN vbrk.waerk = 'USD'							-- Если VBRK-WAERK = "USD",
					THEN 1										-- то "1",
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate != 1						-- и BKPF-KURSF != 1,
					THEN bkpf.exchange_rate							-- то BKPF-KURSF,
				WHEN vbrk.waerk != 'USD'						-- если VBRK-WAERK != "USD",
					and bkpf.document_currency_code != 'USD'		-- если BKPF-WAERS != "USD",
					and bkpf.exchange_rate = 1						-- и BKPF-KURSF = 1,
					THEN dd_cr.currency_rate					-- то TCURR-UKURS,
				WHEN vbsk.statement_invoice_code IS NULL
					-- если SD.001375 "Фактура реализации" пусто,
					THEN replace(o_tfsfrt9.text_value, '-', '')::numeric -- то ФМ READ_TEXT-текст TR29
			END::numeric
			as currency_exchange_rate									-- SD.001376 "Валютный курс"
			,vbsk.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
			,vbsk.is_trader_name											-- SD.001378 "Трейдер"
			,vbsk.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
			,vbsk.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
			,vbsk.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
			,vbsk.block
			-------------------------------------------
			,vbsk.batch
			,vbsk.release_material_status_code
			,vbsk.contract_type_code
			,vbsk.double_record_in_temporary_warehouse_code
			,vbsk.warehouse_shipment_type_name
			,vbsk.shipment_market_code
			,vbsk.delivery_number_outbound
			,vbsk.plant_producer_code
			,vbsk.lot_group
			,vbsk.sales_contract_code
			,vbsk.metal_exchange_type
			,vbsk.is_shipped_via_overseas_warehouse								-- SD.000483 "Наличие Иностранный склад"
		from statement_pp_vbsk as vbsk
		-- SD.001367 "Условие платежа (дни)"
		left join dd_topd							-- /RUSAL/ZTERM
			on dd_topd.terms_of_payment_code = vbsk.payment_terms_code				-- по /RUSAL/ZTERM-ZTERM = SD.001366 "Условие платежа"
		-- SD.001368 "Условие платежа (документ)"
		left join dict_dds.tech_rusal_paydocev as dd_trp									-- /RUSAL/PAYDOCEV
			on dd_trp.event = dd_topd.payment_event_code							-- по /RUSAL/PAYDOCEV-EVENT = /RUSAL/ZTERM-SOB1
		--
		left join dict_dds.payment_terms_document_texts as dd_ptdt						-- D007T
			on dd_ptdt.payment_terms_document_code = dd_trp.docum					-- по D007T-DOMVALUE_L = /RUSAL/PAYDOCEV-DOCUM
			and dd_ptdt.language_code = 'E'										-- и D007T-DOLANGUAGE = "EN"
		-- SD.001370 "Тип рыночного индикатора"
		left join dict_dds.material_price_group_texts as dd_mpgt 							-- T178
			on dd_mpgt.material_price_group_code = vbsk.market_indicator_code		-- T178-KONDM = SD.001369 "Рыночный индикатор (код)"
			and dd_mpgt.language_code = 'E'
			-- SD.001371 "Тип биржи"
		left join dict_dds.currency_exchange_rate_type_texts as dd_certt					-- TCURW
			on dd_certt.currency_exchange_rate_type_code =	vbsk.metal_exchange_type		-- TCURW-KURST = текст из заголовка ФМ READ_TEXT
				and dd_certt.language_code = 'E'									-- TCURW-SPRAS = "EN"
		-- SD.001376 "Валютный курс"
	    left join ods.vbrk_ral as vbrk													-- VBRK
	    	on vbrk.vbeln = vbsk.statement_invoice_code 							-- по VBRK-VBELN = SD.001250 "Фактура для statement"
	    --
	    left join dm_calc.accounting_document_header as bkpf
	    	on bkpf.reference_object_key_code = vbsk.invoice_realization_code -- по BKPF-AWKEY = -- SD.001375 "Фактура реализации"
	    	--
	    left join dict_dds.currency_rates as dd_cr								-- TCURR
	    	on dd_cr.currency_from_code = bkpf.document_currency_code -- по TCURR-FCURR = BKPF-WAERS
	    	and dd_cr.dt_currency_rate = bkpf.dt_posting	 -- и TCURR-GDATU = BKPF-BUDAT
	    	and dd_cr.currency_rate_type_code = 'M'							-- и TCURR-KURST = "M"
	    	and dd_cr.currency_to_code = 'USD'									-- и TCURR-TCURR = "USD"
		--
		left join ods.texts_from_sap_fm_read_text as o_tfsfrt9							-- ФМ READ_TEXT
			on o_tfsfrt9.text_key_identifier_code = vbrk.vbeln				-- по TDNAME = VBRK-VBELN
			and o_tfsfrt9.text_object_identifier_code = 'TR29'					-- и TDID = TR29
			and o_tfsfrt9.language_code = 'R'        							-- и = "RU"
			and o_tfsfrt9.application_object_code = 'VBBK' 						-- и TDOBJECT = VBBK
			and o_tfsfrt9.is_active is true
	)
distributed by (delivery_number_sales,batch);

drop table if exists statement_pp;
create temp table statement_pp as (
	select
		 vp.delivery_number_initial  								-- SD.000001 "Исходная поставка"
		,vp.delivery_number_sales  									-- SD.000002 "Продажная поставка"
		,vp.plant_producer_name  									-- SD.000007 "Завод"
		,vp.port_of_loading_name  									-- SD.000009 "Направление"
		,vp.dt_shipment  											-- SD.000010 "Дата отгрузки"
		,vp.material_aggr_name  									-- SD.000016 "Материал"
		,vp.material_group_code  									-- SD.000017 "Группа материалов (код)"
		,vp.shipment_market_name  									-- SD.000019 "Рынок в отгрузке"
		,vp.dt_warehouse  											-- SD.000024 "Дата склада"
		,vp.transport_railcar_type_name  							-- SD.000029 "Тип вагона"
		,vp.weight_net  											-- SD.000032 "Вес нетто"
		,vp.customer_for_reporting_code  							-- SD.000036 "Покупатель (код)"
		,vp.customer_for_reporting_name  							-- SD.000037 "Покупатель"
		,vp.contract_name  											-- SD.000038 "Контракт"
		,vp.bill_of_lading_number  									-- SD.000041 "Номер коносамента"
		,vp.dt_bill_of_lading  										-- SD.000042 "Дата коносамента"
		,vp.port_of_discharge_name  								-- SD.000045 "Порт выгрузки"
		,vp.bill_of_lading_in_foreign_port  						-- SD.000048 "Коносамент в ин.порту"
		,vp.dt_bill_of_lading_in_foreign_port  						-- SD.000049 "Дата коносамента в ин.порту"
		,vp.dt_arrival_in_port_of_discharge  						-- SD.000059 "Дата прибытия в порт выгрузки"
		,vp.delivery_basis  										-- SD.000067 "Базис поставки"
		,vp.delivery_point_name  									-- SD.000068 "Пункт доставки по инкотермс"
		,vp.sales_order  											-- SD.000123 "Заказ ЦК"
		,vp.dt_arrival_in_port_of_discharge_plan  					-- SD.000130 "Дата прибытия в порт выгрузки план"
		,vp.grade_name  											-- SD.000145 "Марка по спецификации"
		,vp.uni 													-- SD.000151 "UNI"
		,vp.dt_arrival_in_second_port_of_discharge_plan				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
		,vp.end_user_name  											-- SD.000164 "Конечный потребитель"
		,vp.invoice_provisional_number  							-- SD.000167 "Provisional invoice"
		,vp.dt_storage_start_in_foreign_port  						-- SD.000175 "Дата начала хранения ин. склад"
		,vp.dt_storage_end_in_foreign_port  						-- SD.000176 "Окончание хранения в ин. порту"
		,vp.dt_storage_start_in_second_foreign_warehouse  			-- SD.000177 "Начало хранения склад 2 "
		,vp.dt_storage_end_in_second_foreign_warehouse  			-- SD.000178 "Окончание хранение склад 2 "
		,vp.material_shape_name_full  								-- SD.000180 "Форма"
		,vp.delivery_region_name  									-- SD.000338 "Регион поставки по контракту"
		,vp.country_of_discharge_port_name  						-- SD.000341 "Страна POD"
		,vp.dt_prepared_for_realization  							-- SD.000344 "Дата готовности к релизу"
		,vp.business_location_name  								-- SD.000492 "Статус в Supply chain (Business)"
		,vp.delivery_country_in_contract_name  						-- SD.000576 "Страна поставки по контракту"
		,vp.lot_code  												-- SD.000580 "Номер лота"
		,vp.customer_for_scm_report_name  							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
		,vp.vessel_and_voyage_actual_search_name  					-- SD.000608 "Судно / номер рейса (факт)"
		,vp.dt_invoice_provisional  								-- SD.000620 "Дата инвойса"
		,vp.sales_team_name  										-- SD.000651 "Сбытовая команда"
		,vp.dt_quota_yyyymm  										-- SD.000687 "Квота"
		,vp.dt_realization 											-- SD.000720 "Дата реализации"
		,vp.is_tolling_code                            				-- SD.000749 "Признак толлинг"
		,vp.warehouse_or_responsible_customer_for_storage_name	 	-- SD.000919 "General storage location"
		,vp.statement_data_group_code 								-- SD.001244 "Блок данных (statement)"
		,vp.invoice_group_code 										-- SD.001245 "Группа инвойс (statement)"
		,vp.dt_report_yyyy											-- SD.001246 "Год отчета (statement)"
		,vp.purchase_invoice_code 									-- SD.001247 "Входящий счет (statement)"
		,vp.dt_purchase_invoice_yyyy 								-- SD.001248 "Год входящего счета (statement)"
		,vp.net_weight 												-- SD.001249 "Вес для statement"
		,vp.statement_invoice_code 									-- SD.001250 "Фактура для statement"
		,vp.statement_invoice_position_code 						-- SD.001251 "Позиция фактуры для statement"
		,vp.supplier_3rd_party_code									-- SD.001361 "Внешний контрагент"
		,vp.dt_payment												-- SD.001362 "Дата оплаты"
		,vp.dt_payment_week											-- SD.001363 "Неделя оплаты"
		,vp.dt_payment_mm											-- SD.001364 "Месяц оплаты"
		,vp.dt_due_payment											-- SD.001365 "Срок оплаты"
		,vp.payment_terms_code										-- SD.001366 "Условие платежа"
		,vp. payment_terms_days_quantity							-- SD.001367 "Условие платежа (дни)"
		,vp.payment_terms_document_name								-- SD.001368 "Условие платежа (документ)"
		,vp. market_indicator_code									-- SD.001369 "Рыночный индикатор (код)"
		,vp.market_indicator_name									-- SD.001370 "Тип рыночного индикатора"
		,vp.metal_exchange_type_code								-- SD.001371 "Тип биржи"
		,case
			when vp.currency_exchange_rate < 0 then vbrp.netwr / abs(vp.currency_exchange_rate)
			when vp.currency_exchange_rate > 0 then vbrp.netwr * abs(vp.currency_exchange_rate)
		end as usd_currency_vat_excluded_amound						-- SD.001372 "Стоимость"
		,vbrp.netwr 								-- VBRP-NETWR
			as document_currency_vat_excluded_amound				-- SD.001373 "Стоимость в исходной валюте"
		,case
			when vp.currency_exchange_rate < 0 then (vbrp.netwr + vbrp.mwsbp) / abs(vp.currency_exchange_rate)
			when vp.currency_exchange_rate > 0 then (vbrp.netwr + vbrp.mwsbp) * abs(vp.currency_exchange_rate)
		end as usd_currency_vat_included_amound					-- SD.001374 "Стоимость с НДС"
		,vp.invoice_realization_code								-- SD.001375 "Фактура реализации"
		,vp.currency_exchange_rate									-- SD.001376 "Валютный курс"
		,vp.direct_or_overseas_warehouse_delivery_name				-- SD.001377 "Склад/прямая поставка"
		,vp.is_trader_name											-- SD.001378 "Трейдер"
		,vp.prepayment_invoice_code									-- SD.001379 "Номер предоплатного инвойса"
		,vp.sales_market_in_sales_request_code						-- SD.001380 "Рынок из заказа"
		,vp.statement_calculated_weight								-- SD.001381 "Расчетный вес STATEMENT"
		,vp.block
		-------------------------------------------
		,vp.batch
		,vp.release_material_status_code
		,vp.contract_type_code
		,vp.double_record_in_temporary_warehouse_code
		,vp.warehouse_shipment_type_name
		,vp.shipment_market_code
		,vp.delivery_number_outbound
		,vp.plant_producer_code
		,vp.lot_group
		,vp.sales_contract_code
		,vp.metal_exchange_type
		,vp.is_shipped_via_overseas_warehouse						-- SD.000483 "Наличие Иностранный склад"
	from statement_pp_vbsk_prev as vp
	-- SD.001372 "Стоимость" -- SD.001373 "Стоимость в исходной валюте" -- SD.001374 "Стоимость с НДС"
	left join ods.vbrp_ral as vbrp										-- VBRP
	    on vbrp.vbeln = vp.statement_invoice_code 					-- по VBRP-VBELN = SD.001250 "Фактура для statement"
	    and vbrp.posnr = vp.statement_invoice_position_code 	-- и VBRP-POSNR = SD.001251 "Позиция фактуры для statement"
	)
distributed by (delivery_number_sales,batch);

INSERT INTO dm.sales_statement_report (
	delivery_number_initial, 								-- SD.000001 "Исходная поставка"
	delivery_number_sales,									-- SD.000002 "Продажная поставка"
	delivery_number_outbound,
	plant_producer_name, 									-- SD.000007 "Завод"
	port_of_loading_name, 									-- SD.000009 "Направление"
	dt_shipment, 											-- SD.000010 "Дата отгрузки"
	material_aggr_name, 									-- SD.000016 "Материал"
	material_group_code, 									-- SD.000017 "Группа материалов (код)"
	shipment_market_name, 									-- SD.000019 "Рынок в отгрузке"
	dt_warehouse,											-- SD.000024 "Дата склада"
	transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
	weight_net, 											-- SD.000032 "Вес нетто"
	customer_for_reporting_code, 											-- SD.000036 "Покупатель (код)"
	customer_for_reporting_name, 											-- SD.000037 "Покупатель"
	contract_name, 											-- SD.000038 "Контракт"
	bill_of_lading_number, 									-- SD.000041 "Номер коносамента"
	dt_bill_of_lading, 										-- SD.000042 "Дата коносамента"
	port_of_discharge_name, 								-- SD.000045 "Порт выгрузки"
	bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
	dt_bill_of_lading_in_foreign_port, 						-- SD.000049 "Дата коносамента в ин.порту"
	dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
	delivery_basis, 										-- SD.000067 "Базис поставки"
	delivery_point_name, 									-- SD.000068 "Пункт доставки по инкотермс"
	sales_order,											-- SD.000123 "Заказ ЦК"
	dt_arrival_in_port_of_discharge_plan, 					-- SD.000130 "Дата прибытия в порт выгрузки план"
	grade_name, 											-- SD.000145 "Марка по спецификации"
	uni, 													-- SD.000151 "UNI"
	dt_arrival_in_second_port_of_discharge_plan, 			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	end_user_name, 											-- SD.000164 "Конечный потребитель"
	invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
	dt_storage_start_in_foreign_port, 						-- SD.000175 "Дата начала хранения ин. склад"
	dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
	dt_storage_start_in_second_foreign_warehouse, 			-- SD.000177 "Начало хранения склад 2 "
	dt_storage_end_in_second_foreign_warehouse, 			-- SD.000178 "Окончание хранение склад 2 "
	material_shape_name_full, 								-- SD.000180 "Форма"
	delivery_region_name, 									-- SD.000338 "Регион поставки по контракту"
	country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
	dt_prepared_for_realization, 							-- SD.000344 "Дата готовности к релизу"
	business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
	delivery_country_in_contract_name, 						-- SD.000576 "Страна поставки по контракту"
	lot_code, 												-- SD.000580 "Номер лота"
	customer_for_scm_report_name, 							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	vessel_and_voyage_actual_search_name, 					-- SD.000608 "Судно / номер рейса (факт)"
	dt_invoice_provisional, 								-- SD.000620 "Дата инвойса"
	sales_team_name, 										-- SD.000651 "Сбытовая команда"
	dt_quota_yyyymm, 										-- SD.000687 "Квота"
	dt_realization, 										-- SD.000720 "Дата реализации"
	is_tolling_code,										-- SD.000749 "Признак толлинг"
	warehouse_or_responsible_customer_for_storage_name, 	-- SD.000919 "General storage location"
	statement_data_group_code, 								-- SD.001244 "Блок данных (statement)"
	invoice_group_code, 									-- SD.001245 "Группа инвойс (statement)"
	dt_report_yyyy, 										-- SD.001246 "Год отчета (statement)"
	purchase_invoice_code, 									-- SD.001247 "Входящий счет (statement)"
	dt_purchase_invoice_yyyy, 								-- SD.001248 "Год входящего счета (statement)"
	net_weight, 											-- SD.001249 "Вес для statement"
	statement_invoice_code, 								-- SD.001250 "Фактура для statement"
	statement_invoice_position_code,						-- SD.001251 "Позиция фактуры для statement"
	supplier_3rd_party_code,								-- SD.001361 "Внешний контрагент"
	dt_payment,											-- SD.001362 "Дата оплаты"
	dt_payment_week,										-- SD.001363 "Неделя оплаты"
	dt_payment_mm,										-- SD.001364 "Месяц оплаты"
	dt_due_payment,										-- SD.001365 "Срок оплаты"
	payment_terms_code,									-- SD.001366 "Условие платежа"
	payment_terms_days_quantity,							-- SD.001367 "Условие платежа (дни)"
	payment_terms_document_name,							-- SD.001368 "Условие платежа (документ)"
	market_indicator_code,								-- SD.001369 "Рыночный индикатор (код)"
	market_indicator_name,								-- SD.001370 "Тип рыночного индикатора"
	metal_exchange_type_code,								-- SD.001371 "Тип биржи"
	usd_currency_vat_excluded_amound,						-- SD.001372 "Стоимость"
	document_currency_vat_excluded_amound,				-- SD.001373 "Стоимость в исходной валюте"
	usd_currency_vat_included_amound,						-- SD.001374 "Стоимость с НДС"
	invoice_realization_code,								-- SD.001375 "Фактура реализации"
	currency_exchange_rate,								-- SD.001376 "Валютный курс"
	direct_or_overseas_warehouse_delivery_name,			-- SD.001377 "Склад/прямая поставка"
	is_trader_name,										-- SD.001378 "Трейдер"
	prepayment_invoice_code,								-- SD.001379 "Номер предоплатного инвойса"
	sales_market_in_sales_request_code,					-- SD.001380 "Рынок из заказа"
	statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
	)
SELECT
	distinct
	s.delivery_number_initial, 								-- SD.000001 "Исходная поставка"
	s.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	s.delivery_number_outbound,
	s.plant_producer_name, 									-- SD.000007 "Завод"
	s.port_of_loading_name, 								-- SD.000009 "Направление"
	s.dt_shipment, 											-- SD.000010 "Дата отгрузки"
	s.material_aggr_name, 									-- SD.000016 "Материал"
	s.material_group_code, 									-- SD.000017 "Группа материалов (код)"
	s.shipment_market_name, 								-- SD.000019 "Рынок в отгрузке"
	s.dt_warehouse,											-- SD.000024 "Дата склада"
	s.transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
	s.weight_net, 											-- SD.000032 "Вес нетто"
	s.customer_for_reporting_code, 							-- SD.000036 "Покупатель (код)"
	s.customer_for_reporting_name, 							-- SD.000037 "Покупатель"
	s.contract_name, 										-- SD.000038 "Контракт"
	s.bill_of_lading_number, 								-- SD.000041 "Номер коносамента"
	s.dt_bill_of_lading, 									-- SD.000042 "Дата коносамента"
	s.port_of_discharge_name, 								-- SD.000045 "Порт выгрузки"
	s.bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
	s.dt_bill_of_lading_in_foreign_port, 					-- SD.000049 "Дата коносамента в ин.порту"
	s.dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
	s.delivery_basis, 										-- SD.000067 "Базис поставки"
	s.delivery_point_name, 									-- SD.000068 "Пункт доставки по инкотермс"
	s.sales_order,											-- SD.000123 "Заказ ЦК"
	s.dt_arrival_in_port_of_discharge_plan, 				-- SD.000130 "Дата прибытия в порт выгрузки план"
	s.grade_name, 											-- SD.000145 "Марка по спецификации"
	s.uni, 													-- SD.000151 "UNI"
	s.dt_arrival_in_second_port_of_discharge_plan, 			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	s.end_user_name, 										-- SD.000164 "Конечный потребитель"
	s.invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
	s.dt_storage_start_in_foreign_port, 					-- SD.000175 "Дата начала хранения ин. склад"
	s.dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
	s.dt_storage_start_in_second_foreign_warehouse, 		-- SD.000177 "Начало хранения склад 2 "
	s.dt_storage_end_in_second_foreign_warehouse, 			-- SD.000178 "Окончание хранение склад 2 "
	s.material_shape_name_full, 							-- SD.000180 "Форма"
	s.delivery_region_name, 								-- SD.000338 "Регион поставки по контракту"
	s.country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
	s.dt_prepared_for_realization, 							-- SD.000344 "Дата готовности к релизу"
	s.business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
	s.delivery_country_in_contract_name, 					-- SD.000576 "Страна поставки по контракту"
	s.lot_code, 											-- SD.000580 "Номер лота"
	s.customer_for_scm_report_name, 						-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	s.vessel_and_voyage_actual_search_name, 				-- SD.000608 "Судно / номер рейса (факт)"
	s.dt_invoice_provisional, 								-- SD.000620 "Дата инвойса"
	s.sales_team_name, 										-- SD.000651 "Сбытовая команда"
	s.dt_quota_yyyymm, 										-- SD.000687 "Квота"
	s.dt_realization, 										-- SD.000720 "Дата реализации"
	s.is_tolling_code,										-- SD.000749 "Признак толлинг"
	s.warehouse_or_responsible_customer_for_storage_name, 	-- SD.000919 "General storage location"
	s.statement_data_group_code, 							-- SD.001244 "Блок данных (statement)"
	s.invoice_group_code, 									-- SD.001245 "Группа инвойс (statement)"
	s.dt_report_yyyy, 										-- SD.001246 "Год отчета (statement)"
	s.purchase_invoice_code, 								-- SD.001247 "Входящий счет (statement)"
	s.dt_purchase_invoice_yyyy, 							-- SD.001248 "Год входящего счета (statement)"
	s.net_weight, 											-- SD.001249 "Вес для statement"
	s.statement_invoice_code, 								-- SD.001250 "Фактура для statement"
	s.statement_invoice_position_code,						-- SD.001251 "Позиция фактуры для statement"
	s.supplier_3rd_party_code,								-- SD.001361 "Внешний контрагент"
	s.dt_payment,											-- SD.001362 "Дата оплаты"
	s.dt_payment_week,										-- SD.001363 "Неделя оплаты"
	s.dt_payment_mm,										-- SD.001364 "Месяц оплаты"
	s.dt_due_payment,										-- SD.001365 "Срок оплаты"
	s.payment_terms_code,									-- SD.001366 "Условие платежа"
	s.payment_terms_days_quantity,							-- SD.001367 "Условие платежа (дни)"
	s.payment_terms_document_name,							-- SD.001368 "Условие платежа (документ)"
	s.market_indicator_code,								-- SD.001369 "Рыночный индикатор (код)"
	s.market_indicator_name,								-- SD.001370 "Тип рыночного индикатора"
	s.metal_exchange_type_code,								-- SD.001371 "Тип биржи"
	s.usd_currency_vat_excluded_amound,						-- SD.001372 "Стоимость"
	s.document_currency_vat_excluded_amound,				-- SD.001373 "Стоимость в исходной валюте"
	s.usd_currency_vat_included_amound,						-- SD.001374 "Стоимость с НДС"
	s.invoice_realization_code,								-- SD.001375 "Фактура реализации"
	s.currency_exchange_rate,								-- SD.001376 "Валютный курс"
	s.direct_or_overseas_warehouse_delivery_name,			-- SD.001377 "Склад/прямая поставка"
	s.is_trader_name,										-- SD.001378 "Трейдер"
	s.prepayment_invoice_code,								-- SD.001379 "Номер предоплатного инвойса"
	s.sales_market_in_sales_request_code,					-- SD.001380 "Рынок из заказа"
	s.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
--------------------------------------------------------------------------------------------------------------------------------------------------
FROM
	statement_tot AS s
UNION ALL
SELECT
	distinct
	s.delivery_number_initial, 								-- SD.000001 "Исходная поставка"
	s.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	s.delivery_number_outbound,
	s.plant_producer_name, 									-- SD.000007 "Завод"
	s.port_of_loading_name, 								-- SD.000009 "Направление"
	s.dt_shipment, 											-- SD.000010 "Дата отгрузки"
	s.material_aggr_name, 									-- SD.000016 "Материал"
	s.material_group_code, 									-- SD.000017 "Группа материалов (код)"
	s.shipment_market_name, 								-- SD.000019 "Рынок в отгрузке"
	s.dt_warehouse,											-- SD.000024 "Дата склада"
	s.transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
	s.weight_net, 											-- SD.000032 "Вес нетто"
	s.customer_for_reporting_code, 							-- SD.000036 "Покупатель (код)"
	s.customer_for_reporting_name, 							-- SD.000037 "Покупатель"
	s.contract_name, 										-- SD.000038 "Контракт"
	s.bill_of_lading_number, 								-- SD.000041 "Номер коносамента"
	s.dt_bill_of_lading, 									-- SD.000042 "Дата коносамента"
	s.port_of_discharge_name, 								-- SD.000045 "Порт выгрузки"
	s.bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
	s.dt_bill_of_lading_in_foreign_port, 					-- SD.000049 "Дата коносамента в ин.порту"
	s.dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
	s.delivery_basis, 										-- SD.000067 "Базис поставки"
	s.delivery_point_name, 									-- SD.000068 "Пункт доставки по инкотермс"
	s.sales_order,											-- SD.000123 "Заказ ЦК"
	s.dt_arrival_in_port_of_discharge_plan, 				-- SD.000130 "Дата прибытия в порт выгрузки план"
	s.grade_name, 											-- SD.000145 "Марка по спецификации"
	s.uni, 													-- SD.000151 "UNI"
	s.dt_arrival_in_second_port_of_discharge_plan, 			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	s.end_user_name, 										-- SD.000164 "Конечный потребитель"
	s.invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
	s.dt_storage_start_in_foreign_port, 					-- SD.000175 "Дата начала хранения ин. склад"
	s.dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
	s.dt_storage_start_in_second_foreign_warehouse, 		-- SD.000177 "Начало хранения склад 2 "
	s.dt_storage_end_in_second_foreign_warehouse, 			-- SD.000178 "Окончание хранение склад 2 "
	s.material_shape_name_full, 							-- SD.000180 "Форма"
	s.delivery_region_name, 								-- SD.000338 "Регион поставки по контракту"
	s.country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
	s.dt_prepared_for_realization, 							-- SD.000344 "Дата готовности к релизу"
	s.business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
	s.delivery_country_in_contract_name, 					-- SD.000576 "Страна поставки по контракту"
	s.lot_code, 											-- SD.000580 "Номер лота"
	s.customer_for_scm_report_name, 						-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	s.vessel_and_voyage_actual_search_name, 				-- SD.000608 "Судно / номер рейса (факт)"
	s.dt_invoice_provisional, 								-- SD.000620 "Дата инвойса"
	s.sales_team_name, 										-- SD.000651 "Сбытовая команда"
	s.dt_quota_yyyymm, 										-- SD.000687 "Квота"
	s.dt_realization, 										-- SD.000720 "Дата реализации"
	s.is_tolling_code,										-- SD.000749 "Признак толлинг"
	s.warehouse_or_responsible_customer_for_storage_name, 	-- SD.000919 "General storage location"
	s.statement_data_group_code, 							-- SD.001244 "Блок данных (statement)"
	s.invoice_group_code, 									-- SD.001245 "Группа инвойс (statement)"
	s.dt_report_yyyy, 										-- SD.001246 "Год отчета (statement)"
	s.purchase_invoice_code, 								-- SD.001247 "Входящий счет (statement)"
	s.dt_purchase_invoice_yyyy, 							-- SD.001248 "Год входящего счета (statement)"
	s.net_weight, 											-- SD.001249 "Вес для statement"
	s.statement_invoice_code, 								-- SD.001250 "Фактура для statement"
	s.statement_invoice_position_code,						-- SD.001251 "Позиция фактуры для statement"
	s.supplier_3rd_party_code,								-- SD.001361 "Внешний контрагент"
	s.dt_payment,											-- SD.001362 "Дата оплаты"
	s.dt_payment_week,										-- SD.001363 "Неделя оплаты"
	s.dt_payment_mm,										-- SD.001364 "Месяц оплаты"
	s.dt_due_payment,										-- SD.001365 "Срок оплаты"
	s.payment_terms_code,									-- SD.001366 "Условие платежа"
	s.payment_terms_days_quantity,							-- SD.001367 "Условие платежа (дни)"
	s.payment_terms_document_name,							-- SD.001368 "Условие платежа (документ)"
	s.market_indicator_code,								-- SD.001369 "Рыночный индикатор (код)"
	s.market_indicator_name,								-- SD.001370 "Тип рыночного индикатора"
	s.metal_exchange_type_code,								-- SD.001371 "Тип биржи"
	s.usd_currency_vat_excluded_amound,						-- SD.001372 "Стоимость"
	s.document_currency_vat_excluded_amound,				-- SD.001373 "Стоимость в исходной валюте"
	s.usd_currency_vat_included_amound,						-- SD.001374 "Стоимость с НДС"
	s.invoice_realization_code,								-- SD.001375 "Фактура реализации"
	s.currency_exchange_rate,								-- SD.001376 "Валютный курс"
	s.direct_or_overseas_warehouse_delivery_name,			-- SD.001377 "Склад/прямая поставка"
	s.is_trader_name,										-- SD.001378 "Трейдер"
	s.prepayment_invoice_code,								-- SD.001379 "Номер предоплатного инвойса"
	s.sales_market_in_sales_request_code,					-- SD.001380 "Рынок из заказа"
	s.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
--------------------------------------------------------------------------------------------------------------------------------------------------
FROM
	statement_fci AS s
UNION ALL
SELECT
	distinct
	s.delivery_number_initial, 								-- SD.000001 "Исходная поставка"
	s.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	s.delivery_number_outbound,
	s.plant_producer_name, 									-- SD.000007 "Завод"
	s.port_of_loading_name, 								-- SD.000009 "Направление"
	s.dt_shipment, 											-- SD.000010 "Дата отгрузки"
	s.material_aggr_name, 									-- SD.000016 "Материал"
	s.material_group_code, 									-- SD.000017 "Группа материалов (код)"
	s.shipment_market_name, 								-- SD.000019 "Рынок в отгрузке"
	s.dt_warehouse,											-- SD.000024 "Дата склада"
	s.transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
	s.weight_net, 											-- SD.000032 "Вес нетто"
	s.customer_for_reporting_code, 							-- SD.000036 "Покупатель (код)"
	s.customer_for_reporting_name, 							-- SD.000037 "Покупатель"
	s.contract_name, 										-- SD.000038 "Контракт"
	s.bill_of_lading_number, 								-- SD.000041 "Номер коносамента"
	s.dt_bill_of_lading, 									-- SD.000042 "Дата коносамента"
	s.port_of_discharge_name, 								-- SD.000045 "Порт выгрузки"
	s.bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
	s.dt_bill_of_lading_in_foreign_port, 					-- SD.000049 "Дата коносамента в ин.порту"
	s.dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
	s.delivery_basis, 										-- SD.000067 "Базис поставки"
	s.delivery_point_name, 									-- SD.000068 "Пункт доставки по инкотермс"
	s.sales_order,											-- SD.000123 "Заказ ЦК"
	s.dt_arrival_in_port_of_discharge_plan, 				-- SD.000130 "Дата прибытия в порт выгрузки план"
	s.grade_name, 											-- SD.000145 "Марка по спецификации"
	s.uni, 													-- SD.000151 "UNI"
	s.dt_arrival_in_second_port_of_discharge_plan, 			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	s.end_user_name, 										-- SD.000164 "Конечный потребитель"
	s.invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
	s.dt_storage_start_in_foreign_port, 					-- SD.000175 "Дата начала хранения ин. склад"
	s.dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
	s.dt_storage_start_in_second_foreign_warehouse, 		-- SD.000177 "Начало хранения склад 2 "
	s.dt_storage_end_in_second_foreign_warehouse, 			-- SD.000178 "Окончание хранение склад 2 "
	s.material_shape_name_full, 							-- SD.000180 "Форма"
	s.delivery_region_name, 								-- SD.000338 "Регион поставки по контракту"
	s.country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
	s.dt_prepared_for_realization, 							-- SD.000344 "Дата готовности к релизу"
	s.business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
	s.delivery_country_in_contract_name, 					-- SD.000576 "Страна поставки по контракту"
	s.lot_code, 											-- SD.000580 "Номер лота"
	s.customer_for_scm_report_name, 						-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	s.vessel_and_voyage_actual_search_name, 				-- SD.000608 "Судно / номер рейса (факт)"
	s.dt_invoice_provisional, 								-- SD.000620 "Дата инвойса"
	s.sales_team_name, 										-- SD.000651 "Сбытовая команда"
	s.dt_quota_yyyymm, 										-- SD.000687 "Квота"
	s.dt_realization, 										-- SD.000720 "Дата реализации"
	s.is_tolling_code,										-- SD.000749 "Признак толлинг"
	s.warehouse_or_responsible_customer_for_storage_name, 	-- SD.000919 "General storage location"
	s.statement_data_group_code, 							-- SD.001244 "Блок данных (statement)"
	s.invoice_group_code, 									-- SD.001245 "Группа инвойс (statement)"
	s.dt_report_yyyy, 										-- SD.001246 "Год отчета (statement)"
	s.purchase_invoice_code, 								-- SD.001247 "Входящий счет (statement)"
	s.dt_purchase_invoice_yyyy, 							-- SD.001248 "Год входящего счета (statement)"
	s.net_weight, 											-- SD.001249 "Вес для statement"
	s.statement_invoice_code, 								-- SD.001250 "Фактура для statement"
	s.statement_invoice_position_code,						-- SD.001251 "Позиция фактуры для statement"
	s.supplier_3rd_party_code,								-- SD.001361 "Внешний контрагент"
	s.dt_payment,											-- SD.001362 "Дата оплаты"
	s.dt_payment_week,										-- SD.001363 "Неделя оплаты"
	s.dt_payment_mm,										-- SD.001364 "Месяц оплаты"
	s.dt_due_payment,										-- SD.001365 "Срок оплаты"
	s.payment_terms_code,									-- SD.001366 "Условие платежа"
	s.payment_terms_days_quantity,							-- SD.001367 "Условие платежа (дни)"
	s.payment_terms_document_name,							-- SD.001368 "Условие платежа (документ)"
	s.market_indicator_code,								-- SD.001369 "Рыночный индикатор (код)"
	s.market_indicator_name,								-- SD.001370 "Тип рыночного индикатора"
	s.metal_exchange_type_code,								-- SD.001371 "Тип биржи"
	s.usd_currency_vat_excluded_amound,						-- SD.001372 "Стоимость"
	s.document_currency_vat_excluded_amound,				-- SD.001373 "Стоимость в исходной валюте"
	s.usd_currency_vat_included_amound,						-- SD.001374 "Стоимость с НДС"
	s.invoice_realization_code,								-- SD.001375 "Фактура реализации"
	s.currency_exchange_rate,								-- SD.001376 "Валютный курс"
	s.direct_or_overseas_warehouse_delivery_name,			-- SD.001377 "Склад/прямая поставка"
	s.is_trader_name,										-- SD.001378 "Трейдер"
	s.prepayment_invoice_code,								-- SD.001379 "Номер предоплатного инвойса"
	s.sales_market_in_sales_request_code,					-- SD.001380 "Рынок из заказа"
	s.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
--------------------------------------------------------------------------------------------------------------------------------------------------
FROM
	statement_btp AS s
UNION ALL
SELECT
	distinct
	s.delivery_number_initial, 								-- SD.000001 "Исходная поставка"
	s.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	s.delivery_number_outbound,
	s.plant_producer_name, 									-- SD.000007 "Завод"
	s.port_of_loading_name, 								-- SD.000009 "Направление"
	s.dt_shipment, 											-- SD.000010 "Дата отгрузки"
	s.material_aggr_name, 									-- SD.000016 "Материал"
	s.material_group_code, 									-- SD.000017 "Группа материалов (код)"
	s.shipment_market_name, 								-- SD.000019 "Рынок в отгрузке"
	s.dt_warehouse,											-- SD.000024 "Дата склада"
	s.transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
	s.weight_net, 											-- SD.000032 "Вес нетто"
	s.customer_for_reporting_code, 							-- SD.000036 "Покупатель (код)"
	s.customer_for_reporting_name, 							-- SD.000037 "Покупатель"
	s.contract_name, 										-- SD.000038 "Контракт"
	s.bill_of_lading_number, 								-- SD.000041 "Номер коносамента"
	s.dt_bill_of_lading, 									-- SD.000042 "Дата коносамента"
	s.port_of_discharge_name, 								-- SD.000045 "Порт выгрузки"
	s.bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
	s.dt_bill_of_lading_in_foreign_port, 					-- SD.000049 "Дата коносамента в ин.порту"
	s.dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
	s.delivery_basis, 										-- SD.000067 "Базис поставки"
	s.delivery_point_name, 									-- SD.000068 "Пункт доставки по инкотермс"
	s.sales_order,											-- SD.000123 "Заказ ЦК"
	s.dt_arrival_in_port_of_discharge_plan, 				-- SD.000130 "Дата прибытия в порт выгрузки план"
	s.grade_name, 											-- SD.000145 "Марка по спецификации"
	s.uni, 													-- SD.000151 "UNI"
	s.dt_arrival_in_second_port_of_discharge_plan, 			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	s.end_user_name, 										-- SD.000164 "Конечный потребитель"
	s.invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
	s.dt_storage_start_in_foreign_port, 					-- SD.000175 "Дата начала хранения ин. склад"
	s.dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
	s.dt_storage_start_in_second_foreign_warehouse, 		-- SD.000177 "Начало хранения склад 2 "
	s.dt_storage_end_in_second_foreign_warehouse, 			-- SD.000178 "Окончание хранение склад 2 "
	s.material_shape_name_full, 							-- SD.000180 "Форма"
	s.delivery_region_name, 								-- SD.000338 "Регион поставки по контракту"
	s.country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
	s.dt_prepared_for_realization, 							-- SD.000344 "Дата готовности к релизу"
	s.business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
	s.delivery_country_in_contract_name, 					-- SD.000576 "Страна поставки по контракту"
	s.lot_code, 											-- SD.000580 "Номер лота"
	s.customer_for_scm_report_name, 						-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	s.vessel_and_voyage_actual_search_name, 				-- SD.000608 "Судно / номер рейса (факт)"
	s.dt_invoice_provisional, 								-- SD.000620 "Дата инвойса"
	s.sales_team_name, 										-- SD.000651 "Сбытовая команда"
	s.dt_quota_yyyymm, 										-- SD.000687 "Квота"
	s.dt_realization, 										-- SD.000720 "Дата реализации"
	s.is_tolling_code,										-- SD.000749 "Признак толлинг"
	s.warehouse_or_responsible_customer_for_storage_name, 	-- SD.000919 "General storage location"
	s.statement_data_group_code, 							-- SD.001244 "Блок данных (statement)"
	s.invoice_group_code, 									-- SD.001245 "Группа инвойс (statement)"
	s.dt_report_yyyy, 										-- SD.001246 "Год отчета (statement)"
	s.purchase_invoice_code, 								-- SD.001247 "Входящий счет (statement)"
	s.dt_purchase_invoice_yyyy, 							-- SD.001248 "Год входящего счета (statement)"
	s.net_weight, 											-- SD.001249 "Вес для statement"
	s.statement_invoice_code, 								-- SD.001250 "Фактура для statement"
	s.statement_invoice_position_code,						-- SD.001251 "Позиция фактуры для statement"
	s.supplier_3rd_party_code,								-- SD.001361 "Внешний контрагент"
	s.dt_payment,											-- SD.001362 "Дата оплаты"
	s.dt_payment_week,										-- SD.001363 "Неделя оплаты"
	s.dt_payment_mm,										-- SD.001364 "Месяц оплаты"
	s.dt_due_payment,										-- SD.001365 "Срок оплаты"
	s.payment_terms_code,									-- SD.001366 "Условие платежа"
	s.payment_terms_days_quantity,							-- SD.001367 "Условие платежа (дни)"
	s.payment_terms_document_name,							-- SD.001368 "Условие платежа (документ)"
	s.market_indicator_code,								-- SD.001369 "Рыночный индикатор (код)"
	s.market_indicator_name,								-- SD.001370 "Тип рыночного индикатора"
	s.metal_exchange_type_code,								-- SD.001371 "Тип биржи"
	s.usd_currency_vat_excluded_amound,						-- SD.001372 "Стоимость"
	s.document_currency_vat_excluded_amound,				-- SD.001373 "Стоимость в исходной валюте"
	s.usd_currency_vat_included_amound,						-- SD.001374 "Стоимость с НДС"
	s.invoice_realization_code,								-- SD.001375 "Фактура реализации"
	s.currency_exchange_rate,								-- SD.001376 "Валютный курс"
	s.direct_or_overseas_warehouse_delivery_name,			-- SD.001377 "Склад/прямая поставка"
	s.is_trader_name,										-- SD.001378 "Трейдер"
	s.prepayment_invoice_code,								-- SD.001379 "Номер предоплатного инвойса"
	s.sales_market_in_sales_request_code,					-- SD.001380 "Рынок из заказа"
	s.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"

--------------------------------------------------------------------------------------------------------------------------------------------------
FROM statement_as AS s
UNION ALL
SELECT
	distinct
	s.delivery_number_initial, 								-- SD.000001 "Исходная поставка"
	s.delivery_number_sales,								-- SD.000002 "Продажная поставка"
	s.delivery_number_outbound,
	s.plant_producer_name, 									-- SD.000007 "Завод"
	s.port_of_loading_name, 								-- SD.000009 "Направление"
	s.dt_shipment, 											-- SD.000010 "Дата отгрузки"
	s.material_aggr_name, 									-- SD.000016 "Материал"
	s.material_group_code, 									-- SD.000017 "Группа материалов (код)"
	s.shipment_market_name, 								-- SD.000019 "Рынок в отгрузке"
	s.dt_warehouse,											-- SD.000024 "Дата склада"
	s.transport_railcar_type_name, 							-- SD.000029 "Тип вагона"
	s.weight_net, 											-- SD.000032 "Вес нетто"
	s.customer_for_reporting_code, 							-- SD.000036 "Покупатель (код)"
	s.customer_for_reporting_name, 							-- SD.000037 "Покупатель"
	s.contract_name, 										-- SD.000038 "Контракт"
	s.bill_of_lading_number, 								-- SD.000041 "Номер коносамента"
	s.dt_bill_of_lading, 									-- SD.000042 "Дата коносамента"
	s.port_of_discharge_name, 								-- SD.000045 "Порт выгрузки"
	s.bill_of_lading_in_foreign_port, 						-- SD.000048 "Коносамент в ин.порту"
	s.dt_bill_of_lading_in_foreign_port, 					-- SD.000049 "Дата коносамента в ин.порту"
	s.dt_arrival_in_port_of_discharge, 						-- SD.000059 "Дата прибытия в порт выгрузки"
	s.delivery_basis, 										-- SD.000067 "Базис поставки"
	s.delivery_point_name, 									-- SD.000068 "Пункт доставки по инкотермс"
	s.sales_order,											-- SD.000123 "Заказ ЦК"
	s.dt_arrival_in_port_of_discharge_plan, 				-- SD.000130 "Дата прибытия в порт выгрузки план"
	s.grade_name, 											-- SD.000145 "Марка по спецификации"
	s.uni, 													-- SD.000151 "UNI"
	s.dt_arrival_in_second_port_of_discharge_plan, 			-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	s.end_user_name, 										-- SD.000164 "Конечный потребитель"
	s.invoice_provisional_number, 							-- SD.000167 "Provisional invoice"
	s.dt_storage_start_in_foreign_port, 					-- SD.000175 "Дата начала хранения ин. склад"
	s.dt_storage_end_in_foreign_port, 						-- SD.000176 "Окончание хранения в ин. порту"
	s.dt_storage_start_in_second_foreign_warehouse, 		-- SD.000177 "Начало хранения склад 2 "
	s.dt_storage_end_in_second_foreign_warehouse, 			-- SD.000178 "Окончание хранение склад 2 "
	s.material_shape_name_full, 							-- SD.000180 "Форма"
	s.delivery_region_name, 								-- SD.000338 "Регион поставки по контракту"
	s.country_of_discharge_port_name, 						-- SD.000341 "Страна POD"
	s.dt_prepared_for_realization, 							-- SD.000344 "Дата готовности к релизу"
	s.business_location_name, 								-- SD.000492 "Статус в Supply chain (Business)"
	s.delivery_country_in_contract_name, 					-- SD.000576 "Страна поставки по контракту"
	s.lot_code, 											-- SD.000580 "Номер лота"
	s.customer_for_scm_report_name, 						-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	s.vessel_and_voyage_actual_search_name, 				-- SD.000608 "Судно / номер рейса (факт)"
	s.dt_invoice_provisional, 								-- SD.000620 "Дата инвойса"
	s.sales_team_name, 										-- SD.000651 "Сбытовая команда"
	s.dt_quota_yyyymm, 										-- SD.000687 "Квота"
	s.dt_realization, 										-- SD.000720 "Дата реализации"
	s.is_tolling_code,										-- SD.000749 "Признак толлинг"
	s.warehouse_or_responsible_customer_for_storage_name, 	-- SD.000919 "General storage location"
	s.statement_data_group_code, 							-- SD.001244 "Блок данных (statement)"
	s.invoice_group_code, 									-- SD.001245 "Группа инвойс (statement)"
	s.dt_report_yyyy, 										-- SD.001246 "Год отчета (statement)"
	s.purchase_invoice_code, 								-- SD.001247 "Входящий счет (statement)"
	s.dt_purchase_invoice_yyyy, 							-- SD.001248 "Год входящего счета (statement)"
	s.net_weight, 											-- SD.001249 "Вес для statement"
	s.statement_invoice_code, 								-- SD.001250 "Фактура для statement"
	s.statement_invoice_position_code,						-- SD.001251 "Позиция фактуры для statement"
	s.supplier_3rd_party_code,								-- SD.001361 "Внешний контрагент"
	s.dt_payment,											-- SD.001362 "Дата оплаты"
	s.dt_payment_week,										-- SD.001363 "Неделя оплаты"
	s.dt_payment_mm,										-- SD.001364 "Месяц оплаты"
	s.dt_due_payment,										-- SD.001365 "Срок оплаты"
	s.payment_terms_code,									-- SD.001366 "Условие платежа"
	s.payment_terms_days_quantity,							-- SD.001367 "Условие платежа (дни)"
	s.payment_terms_document_name,							-- SD.001368 "Условие платежа (документ)"
	s.market_indicator_code,								-- SD.001369 "Рыночный индикатор (код)"
	s.market_indicator_name,								-- SD.001370 "Тип рыночного индикатора"
	s.metal_exchange_type_code,								-- SD.001371 "Тип биржи"
	s.usd_currency_vat_excluded_amound,						-- SD.001372 "Стоимость"
	s.document_currency_vat_excluded_amound,				-- SD.001373 "Стоимость в исходной валюте"
	s.usd_currency_vat_included_amound,						-- SD.001374 "Стоимость с НДС"
	s.invoice_realization_code,								-- SD.001375 "Фактура реализации"
	s.currency_exchange_rate,								-- SD.001376 "Валютный курс"
	s.direct_or_overseas_warehouse_delivery_name,			-- SD.001377 "Склад/прямая поставка"
	s.is_trader_name,										-- SD.001378 "Трейдер"
	s.prepayment_invoice_code,								-- SD.001379 "Номер предоплатного инвойса"
	s.sales_market_in_sales_request_code,					-- SD.001380 "Рынок из заказа"
	s.statement_calculated_weight							-- SD.001381 "Расчетный вес STATEMENT"
--------------------------------------------------------------------------------------------------------------------------------------------------
FROM statement_pp AS s;

drop table if exists statement_program_parameters;
drop table if exists d_ldadr;
drop table if exists d_ldadr2;
drop table if exists d_ldadr3;
drop table if exists th1;
drop table if exists frame_par;
drop table if exists batch_exclude;
drop table if exists batch_include;
drop table if exists contract_type_exclude;
drop table if exists rseg_deb;
drop table if exists contract_type_ptc;
drop table if exists vbak2;
drop table if exists vbak4;
drop table if exists vbsk;
drop table if exists vbap2;
drop table if exists vbsk4;
drop table if exists vbak5;
drop table if exists vbak6;
drop table if exists dc_sda;
drop table if exists dc_sda_tot;
drop table if exists sda_prev;
drop table if exists statement_sda;
drop table if exists statement_real;
drop table if exists statement_plan_prev;
drop table if exists statement_plan;
drop table if exists statement_tot;
drop table if exists statement_fci;
drop table if exists statement_tot_dni;
drop table if exists lt_rseg;
drop table if exists lt_rseg_ekbe;
drop table if exists lt_rseg_rbkp;
drop table if exists lt_rseg_tot;
drop table if exists statement_btp;
drop table if exists statement_as;
drop table if exists statement_pp;