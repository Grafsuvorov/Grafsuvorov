create temporary table base on commit drop as (
    select
		-- общие признаки
  		ddp.delivery_code as initial_delivery_code,																									-- Поставки завода производителя, код LE.000600
 		ddp.material_code,
 		mt.material_name,
  		ddp.delivery_position_line_item_code as initial_delivery_item_code,																			-- Поставки завода производителя, позиция LE.000601
 		fd.sales_order_in_shipment as sales_order_code, 																							-- Заказ ЦК LE.000694
		zle_1431_fraht.expense_code as expense_account_code, 								-- Статья затрат (код) LE.000740
		zle_1431_fraht.service_code as service_account_code,
		treate.expense_account_name as expense_account_name, 																						-- Статья затрат (наименование) LE.000741
		concat_ws('-', zle_1431_fraht.expense_code, treate.expense_account_name) as expense_account_search_name, 									-- Статья затрат (связка) LE.000742
		concat_ws('-', ddp.plant_producer_code, pas.plant_short_name) as plant_producer_search_name,												-- Завод (связка) LE.000604
 	 	sabu.sales_bundle_code as sales_bundle_code,																								-- ID химии LE.000739
		zle_1431_fraht.usd_currency_code as expense_translated_currency_code,																		-- Валюта затраты USD LE.000744
		concat_ws('-', zle_1431_fraht.expense_position_code, zle_1431_fraht.expense_name) as expense_group_search_name,								-- Группа затрат (связка) LE.000747
		zle_1431_fraht.purchase_contract_code as transportation_service_contract_code,  -- Договор затраты LE.000748
		zle_1431_fraht.transportation_scheme_code as transportation_scheme_code,
		sabu.sales_bundle_gross_weight / 1000 as sales_bundle_gross_weight,		-- Вес брутто пакета LE.000759
		sabu.sales_bundle_net_weight / 1000 as sales_bundle_net_weight,   -- Вес нетто пакета LE.000760
		zle_1431_fraht.expense_per_ton_amount as expense_per_ton_usd_amount,																		-- Сумма в USD на тонну LE.000743
		zle_1431_fraht.expense_per_ton_amount * sabu.sales_bundle_gross_weight / 1000 as total_expense_per_gross_weight_usd_amount, 				-- Сумма в USD на вес брутто пакета LE.000762
		zle_1431_fraht.expense_per_ton_amount * sabu.sales_bundle_net_weight / 1000 as total_expense_per_net_weight_usd_amount,						-- Сумма в USD на вес нетто пакета LE.000761
        sum(sabu.sales_bundle_gross_weight) over wind as sum_sales_bundle_gross_weight,
		sum(sabu.sales_bundle_net_weight) over wind as sum_sales_bundle_net_weight,
		sabu.sales_bundle_gross_weight as sales_bundle_gross_weight_nedelen,
		sabu.sales_bundle_net_weight as sales_bundle_net_weight_nedelen
	from dds.delivery_document_position as ddp
 		left join dict_dds.material_texts as mt
			on mt.material_code = ddp.material_code
	  		and mt.language_code = 'R'
	  		and mt.deleted_flag = false
		left join dict_dds.plant_and_subsidiary	as pas
			on pas.plant_code = ddp.plant_producer_code
			and pas.deleted_flag = false
		left join ods.map_transportation_expenses_keys_ral as zle_1431_fraht on
			zle_1431_fraht.delivery_code = ddp.delivery_code
			and zle_1431_fraht.deleted_flag = false
			and zle_1431_fraht.expense_type_code in ('1', '3')
		left join dds.sales_batch_delivery as fd
			on fd.delivery_number_of_plant_producer = ddp.delivery_code
			and fd.delivery_item_number_of_plant_producer = ddp.delivery_position_line_item_code
			and fd.batch_code = ddp.batch_code
			and fd.is_not_valid_for_reporting = false
			and fd.deleted_flag = false
		left join dds.sales_bundle as sabu on
			sabu.delivery_reference_code =  ddp.delivery_code || ddp.delivery_position_line_item_code
			and sabu.deleted_flag = false
		left join dict_dds.transportation_expense_account_texts as treate on
			treate.expense_account_code = zle_1431_fraht.expense_code
			and treate.language_code = 'R'
			and treate.deleted_flag = false
	where ddp.deleted_flag = false
	window wind as (partition by ddp.delivery_code, ddp.delivery_position_line_item_code, fd.sales_order_in_shipment, zle_1431_fraht.expense_code, zle_1431_fraht.service_code)
)
distributed by (initial_delivery_code);


create temporary table punct_1 on commit drop as (
	select
		-- общие признаки
  		pre_1.initial_delivery_code,																									-- Поставки завода производителя, код LE.000600
 		pre_1.initial_delivery_item_code,																			-- Поставки завода производителя, позиция LE.000601
 		pre_1.sales_order_code, 																							-- Заказ ЦК LE.000694
		pre_1.expense_account_code, 								-- Статья затрат (код) LE.000740
		pre_1.expense_account_name, 																						-- Статья затрат (наименование) LE.000741
		pre_1.expense_account_search_name, 									-- Статья затрат (связка) LE.000742
		pre_1.plant_producer_search_name,												-- Завод (связка) LE.000604
 	 	concat_ws('-', ddh.transport_type_code, ttt.transport_transfer_type_name_rus) as transport_type_search_name,								-- Тип ПС (связка) LE.000610
 	 	ddh.vehicle_code as transport_vehicle_code,		  																							-- Номер вагона LE.000611
 	 	ddh.transport_bill_code,																													-- Номер транспортной накладной LE.000612
 	 	concat_ws('-', ddh.transport_bill_code, ddh.vehicle_code) as transport_bill_and_railcar_uni_code, 											-- Склейка Ж/д Накладная - №Вагона LE.000613
 	 	concat_ws('-', k3.etsng_code, et.etsng_name_rus) as etsng_search_name,																		-- Код ЕТСНГ (связка) LE.000633
 	 	concat_ws('-', pre_1.material_code, pre_1.material_name) as material_search_name,																-- Материал (связка) LE.000637
 	 	concat_ws('-', ms.shape_code, st.material_shape_full_name) as shape_search_name,															-- Форма груза (связка) LE.000641
		case
			when mm.sector_code = '03' then concat_ws('-', '01', us.sector_name)
			else concat_ws('-', mm.sector_code,	us.sector_name)
		end as sector_search_name,																													-- Сектор - группа материалов (связка) , замена k3 на s LE.000644
		concat_ws('-', ms.grade_rusal_code, grt.grade_rusal_name) as grade_search_name,																-- Марка металла (связка) LE.000647
		concat_ws('-', k3.transport_subtype_code, tvtyt.transport_subtype_name) as transport_subtype_search_name,													-- Вид ПС (связка) LE.000730
		pre_1.sales_bundle_code,																								-- ID химии LE.000739
		pre_1.expense_translated_currency_code,																		-- Валюта затраты USD LE.000744
		pre_1.expense_group_search_name,								-- Группа затрат (связка) LE.000747
		pre_1.transportation_service_contract_code,																-- Договор затраты LE.000748
		concat_ws('-', pre_1.transportation_scheme_code, trsc.transportation_scheme_name) as transportation_scheme_search_name, 			-- Схема транспортировки (связка) LE.000752
		concat_ws('-', trsc.transportation_scheme_type_code, trsstt.transportation_scheme_type_name) as transportation_scheme_type_search_name,		-- Тип схемы транспортировки (связка) LE.000755
		concat_ws('-', trsc.transportation_scheme_subtype_code, trscst.transportation_scheme_subtype_name) as transportation_scheme_subtype_search_name, -- Подтип схемы транспортировки (связка) LE.000758
		pre_1.sales_bundle_gross_weight,																		-- Вес брутто пакета LE.000759
		pre_1.sales_bundle_net_weight, 																			-- Вес нетто пакета LE.000760
		pre_1.expense_per_ton_usd_amount,																		-- Сумма в USD на тонну LE.000743
		pre_1.total_expense_per_gross_weight_usd_amount,     				-- Сумма в USD на вес брутто пакета LE.000762
		pre_1.total_expense_per_net_weight_usd_amount,						-- Сумма в USD на вес нетто пакета LE.000761
		pre_1.sum_sales_bundle_gross_weight,
		pre_1.sum_sales_bundle_net_weight,
		pre_1.sales_bundle_gross_weight_nedelen,
		pre_1.sales_bundle_net_weight_nedelen
	from base as pre_1
		join dm_calc.is_relevant_transportation_aluminium_shipment_from_plant as ietasfp
			on ietasfp.initial_delivery_code = pre_1.initial_delivery_code
			and ietasfp.initial_delivery_item_code = pre_1.initial_delivery_item_code
			and ietasfp.is_relevant_transportation_aluminium_shipment_from_plant is not null
			and ietasfp.deleted_flag = false
		join dds.delivery_document_header as ddh
			on ddh.delivery_code = pre_1.initial_delivery_code
			and ddh.deleted_flag = false
		left join dict_dds.transport_transfer_type as ttt
			on ttt.transport_transfer_type_code = ddh.transport_type_code
			and ttt.deleted_flag = false
		left join ods.map_delivery_document_attributes_keys_ral as k3
			on k3.delivery_code = pre_1.initial_delivery_code
			and k3.deleted_flag = false
		left join dict_dds.etsng as et
			on et.etsng_code = k3.etsng_code
			and et.deleted_flag = false
	    left join dict_dds.material_specification as ms
			on ms.material_code = pre_1.material_code
			and ms.deleted_flag = false
		left join dict_dds.material_shape_texts as st
			on st.shape_code = ms.shape_code
			and st.language_code = 'R'
			and st.deleted_flag = false
		left join dict_dds.material as mm
			on mm.material_code = pre_1.material_code
			and mm.deleted_flag = false
		left join dict_dds.sales_sector_texts as us
			on us.sector_code = case when mm.sector_code = '03' then '01' else mm.sector_code end
			and us.deleted_flag = false
			and us.language_code = 'R'
		left join dict_dds.grade_rusal_texts as grt
			on grt.grade_rusal_code = ms.grade_rusal_code
			and grt.language_code = 'R'
			and grt.deleted_flag = false 
		left join dict_dds.transportation_scheme as trsc on
			trsc.transportation_scheme_code = pre_1.transportation_scheme_code
			and trsc.deleted_flag = false
		left join dict_dds.transport_subtype_texts as tvtyt
			on tvtyt.transport_subtype_code = k3.transport_subtype_code
			and tvtyt.language_code = 'R'
			and tvtyt.deleted_flag = false
		left join dict_dds.transportation_scheme_type_texts as trsstt on
			trsstt.transportation_scheme_type_code = trsc.transportation_scheme_type_code
			and trsstt.language_code = 'R'
			and trsstt.deleted_flag = false
		left join dict_dds.transportation_scheme_subtype_texts as trscst on
			trscst.transportation_scheme_subtype_code = trsc.transportation_scheme_subtype_code
			and trscst.language_code = 'R'
			and trscst.deleted_flag = false
)
distributed by (sales_bundle_code); 


create temporary table punct_ck on commit drop as (
	select
	    sales_bundle_code,
	    sales_order_code,
	    sales_bundle_gross_weight_nedelen,
	    sales_bundle_net_weight_nedelen
	from
	    punct_1
	group by
	    sales_bundle_code,
	    sales_order_code,
	    sales_bundle_gross_weight_nedelen,
	    sales_bundle_net_weight_nedelen)
distributed by (sales_bundle_code);

create temporary table pre_2 on commit drop as (
	select
        -- общие признаки
        pre_2.initial_delivery_code,                                                                                                    -- Поставки завода производителя, код LE.000600
        pre_2.initial_delivery_item_code,                                                                            -- Поставки завода производителя, позиция LE.000601
        punct_ck.sales_order_code,                                                                                             -- Заказ ЦК LE.000694
        pre_2.expense_account_code,                                 -- Статья затрат (код) LE.000740
        pre_2.expense_account_name,                                                                                         -- Статья затрат (наименование) LE.000741
        pre_2.expense_account_search_name,                                     -- Статья затрат (связка) LE.000742
        pre_2.plant_producer_search_name,                -- Завод (связка) LE.000604
        pre_2.material_code,
        concat_ws('-', pre_2.material_code, pre_2.material_name) as material_search_name,                                                                -- Материал (связка) LE.000637
        sbadr.sales_bundle_code,                                                                                                                    -- ID химии LE.000739
        pre_2.expense_translated_currency_code,                                                                        -- Валюта затраты USD LE.000744
        pre_2.expense_group_search_name,                                -- Группа затрат (связка) LE.000747
        pre_2.transportation_service_contract_code,                                                                -- Договор затраты LE.000748
        pre_2.transportation_scheme_code,
        punct_ck.sales_bundle_gross_weight_nedelen / 1000 as sales_bundle_gross_weight,                                                                        -- Вес брутто пакета LE.000759
        punct_ck.sales_bundle_net_weight_nedelen / 1000 as sales_bundle_net_weight,                                                                             -- Вес нетто пакета LE.000760
        pre_2.expense_per_ton_usd_amount,                                                                        -- Сумма в USD на тонну LE.000743
        pre_2.expense_per_ton_usd_amount * punct_ck.sales_bundle_gross_weight_nedelen / 1000 as total_expense_per_gross_weight_usd_amount,                 -- Сумма в USD на вес брутто пакета LE.000762
        pre_2.expense_per_ton_usd_amount * punct_ck.sales_bundle_net_weight_nedelen / 1000 as total_expense_per_net_weight_usd_amount,                        -- Сумма в USD на вес нетто пакета LE.000761
        sum(punct_ck.sales_bundle_gross_weight_nedelen) over wind as sum_sales_bundle_gross_weight,
        sum(punct_ck.sales_bundle_net_weight_nedelen) over wind as sum_sales_bundle_net_weight
	from base as pre_2
        join dm_calc.is_metal_transshipped_in_container as imtic
            on imtic.initial_delivery_code = pre_2.initial_delivery_code
            and imtic.is_metal_transshipped_in_container_code is not null
            and imtic.deleted_flag = false
        left join dds.sales_bundle_and_delivery_relationship as sbadr on
            sbadr.delivery_code = pre_2.initial_delivery_code
            and sbadr.delivery_position_code = pre_2.initial_delivery_item_code
            and sbadr.deleted_flag = false
        join punct_ck
            on punct_ck.sales_bundle_code = sbadr.sales_bundle_code
	window wind as (partition by pre_2.initial_delivery_code, pre_2.initial_delivery_item_code, punct_ck.sales_order_code, pre_2.expense_account_code, pre_2.service_account_code)
)
distributed by (sales_bundle_code); 

create temporary table punct_2 on commit drop as (
	select
		-- общие признаки
		pre_2.initial_delivery_code,                                                                                                    -- Поставки завода производителя, код LE.000600
		pre_2.initial_delivery_item_code,                                                                            -- Поставки завода производителя, позиция LE.000601
		pre_2.sales_order_code,                                                                                             -- Заказ ЦК LE.000694
        pre_2.expense_account_code,                                 -- Статья затрат (код) LE.000740
        pre_2.expense_account_name,                                                                                         -- Статья затрат (наименование) LE.000741
        pre_2.expense_account_search_name,                                     -- Статья затрат (связка) LE.000742
        pre_2.plant_producer_search_name,                                                -- Завод (связка) LE.000604
		concat_ws('-', ddh.transport_type_code, ttt.transport_transfer_type_name_rus) as transport_type_search_name,                                -- Тип ПС (связка) LE.000610
		ddh.vehicle_code as transport_vehicle_code,                                                                                                      -- Номер вагона LE.000611
		ddh.transport_bill_code,                                                                                                            -- Номер транспортной накладной LE.000612
		concat_ws('-', ddh.transport_bill_code, ddh.vehicle_code) as transport_bill_and_railcar_uni_code,                                             -- Склейка Ж/д Накладная - №Вагона LE.000613
		concat_ws('-', k3.etsng_code, et.etsng_name_rus) as etsng_search_name,                                                                        -- Код ЕТСНГ (связка) LE.000633
		pre_2.material_search_name,                                                                -- Материал (связка) LE.000637
		concat_ws('-', ms.shape_code, st.material_shape_full_name) as shape_search_name,                                                            -- Форма груза (связка) LE.000641
		case
			when mm.sector_code = '03' then concat_ws('-', '01', us.sector_name)
            else concat_ws('-', mm.sector_code,    us.sector_name)
        end as sector_search_name,                                                                                                                    -- Сектор - группа материалов (связка) , замена k3 на s LE.000644
        concat_ws('-', ms.grade_rusal_code, grt.grade_rusal_name) as grade_search_name,                                                                -- Марка металла (связка) LE.000647
        concat_ws('-', k3.transport_subtype_code, tvtyt.transport_subtype_name) as transport_subtype_search_name,                                                    -- Вид ПС (связка) LE.000730
        pre_2.sales_bundle_code,                                                                                                                    -- ID химии LE.000739
        pre_2.expense_translated_currency_code,                                                                        -- Валюта затраты USD LE.000744
        pre_2.expense_group_search_name,                                -- Группа затрат (связка) LE.000747
        pre_2.transportation_service_contract_code,                                                                -- Договор затраты LE.000748
        concat_ws('-', pre_2.transportation_scheme_code, trsc.transportation_scheme_name) as transportation_scheme_search_name,             -- Схема транспортировки (связка) LE.000752
        concat_ws('-', trsc.transportation_scheme_type_code, trsstt.transportation_scheme_type_name) as transportation_scheme_type_search_name,        -- Тип схемы транспортировки (связка) LE.000755
        concat_ws('-', trsc.transportation_scheme_subtype_code, trscst.transportation_scheme_subtype_name) as transportation_scheme_subtype_search_name, -- Подтип схемы транспортировки (связка) LE.000758
        pre_2.sales_bundle_gross_weight,                                                                        -- Вес брутто пакета LE.000759
        pre_2.sales_bundle_net_weight,                                                                             -- Вес нетто пакета LE.000760
        pre_2.expense_per_ton_usd_amount,                                                                        -- Сумма в USD на тонну LE.000743
        pre_2.total_expense_per_gross_weight_usd_amount,                 -- Сумма в USD на вес брутто пакета LE.000762
        pre_2.total_expense_per_net_weight_usd_amount,                        -- Сумма в USD на вес нетто пакета LE.000761
        pre_2.sum_sales_bundle_gross_weight,
        pre_2.sum_sales_bundle_net_weight
	from pre_2
        join dds.delivery_document_header as ddh
            on ddh.delivery_code = pre_2.initial_delivery_code
            and ddh.deleted_flag = false
        left join dict_dds.transport_transfer_type as ttt
            on ttt.transport_transfer_type_code = ddh.transport_type_code
            and ttt.deleted_flag = false
        left join ods.map_delivery_document_attributes_keys_ral as k3
            on k3.delivery_code = pre_2.initial_delivery_code
            and k3.deleted_flag = false
        left join dict_dds.etsng as et
            on et.etsng_code = k3.etsng_code
            and et.deleted_flag = false
        left join dict_dds.material_specification as ms
            on ms.material_code = pre_2.material_code
            and ms.deleted_flag = false
        left join dict_dds.material_shape_texts as st
            on st.shape_code = ms.shape_code
            and st.language_code = 'R'
            and st.deleted_flag = false
        left join dict_dds.material as mm
            on mm.material_code = pre_2.material_code
            and mm.deleted_flag = false
        left join dict_dds.sales_sector_texts as us
            on us.sector_code = case when mm.sector_code = '03' then '01' else mm.sector_code end
            and us.deleted_flag = false
            and us.language_code = 'R'
        left join dict_dds.grade_rusal_texts as grt
            on grt.grade_rusal_code = ms.grade_rusal_code
            and grt.language_code = 'R'
            and grt.deleted_flag = false 
        left join dict_dds.transportation_scheme as trsc on
            trsc.transportation_scheme_code = pre_2.transportation_scheme_code
            and trsc.deleted_flag = false
        left join dict_dds.transport_subtype_texts as tvtyt
            on tvtyt.transport_subtype_code = k3.transport_subtype_code
            and tvtyt.language_code = 'R'
            and tvtyt.deleted_flag = false
        left join dict_dds.transportation_scheme_type_texts as trsstt on
            trsstt.transportation_scheme_type_code = trsc.transportation_scheme_type_code
            and trsstt.language_code = 'R'
            and trsstt.deleted_flag = false
        left join dict_dds.transportation_scheme_subtype_texts as trscst on
            trscst.transportation_scheme_subtype_code = trsc.transportation_scheme_subtype_code
            and trscst.language_code = 'R'
            and trscst.deleted_flag = false
)
distributed by (sales_bundle_code); 

insert into dm_calc.alverse_transportation_life_cycle (
    initial_delivery_code,
    initial_delivery_item_code,
    sales_order_code,
    expense_account_code,
    expense_account_name,
    expense_account_search_name,
    plant_producer_search_name,
    transport_type_search_name,
    transport_vehicle_code,
    transport_bill_code,
    transport_bill_and_railcar_uni_code,
    etsng_search_name,
    material_search_name,
    shape_search_name,
    supplier_search_name,
    sector_search_name,
    grade_search_name,
    transport_subtype_search_name,
    sales_bundle_code,
    expense_translated_currency_code,
    expense_group_search_name,
    transportation_service_contract_code,
    transportation_scheme_search_name,
    transportation_scheme_type_search_name,
    transportation_scheme_subtype_search_name,
    sales_bundle_gross_weight,
    sales_bundle_net_weight,
    expense_per_ton_usd_amount,
    total_expense_per_gross_weight_usd_amount,
    total_expense_per_net_weight_usd_amount,
    sum_sales_bundle_gross_weight,
    sum_sales_bundle_net_weight,
    external_contract_number
)
with uni as (
	select
	    initial_delivery_code,
	    initial_delivery_item_code,
	    sales_order_code,
	    expense_account_code,
	    expense_account_name,
	    expense_account_search_name,
	    plant_producer_search_name,
	    transport_type_search_name,
	    transport_vehicle_code,
	    transport_bill_code,
	    transport_bill_and_railcar_uni_code,
	    etsng_search_name,
	    material_search_name,
	    shape_search_name,
	    sector_search_name,
	    grade_search_name,
	    transport_subtype_search_name,
	    sales_bundle_code,
	    expense_translated_currency_code,
	    expense_group_search_name,
	    transportation_service_contract_code,
	    transportation_scheme_search_name,
	    transportation_scheme_type_search_name,
	    transportation_scheme_subtype_search_name,
	    sales_bundle_gross_weight,
	    sales_bundle_net_weight,
	    expense_per_ton_usd_amount,
	    total_expense_per_gross_weight_usd_amount,
	    total_expense_per_net_weight_usd_amount,
	    sum_sales_bundle_gross_weight,
	    sum_sales_bundle_net_weight
	from
	    punct_1
	union all
	select
	    initial_delivery_code,
	    initial_delivery_item_code,
	    sales_order_code,
	    expense_account_code,
	    expense_account_name,
	    expense_account_search_name,
	    plant_producer_search_name,
	    transport_type_search_name,
	    transport_vehicle_code,
	    transport_bill_code,
	    transport_bill_and_railcar_uni_code,
	    etsng_search_name,
	    material_search_name,
	    shape_search_name,
	    sector_search_name,
	    grade_search_name,
	    transport_subtype_search_name,
	    sales_bundle_code,
	    expense_translated_currency_code,
	    expense_group_search_name,
	    transportation_service_contract_code,
	    transportation_scheme_search_name,
	    transportation_scheme_type_search_name,
	    transportation_scheme_subtype_search_name,
	    sales_bundle_gross_weight,
	    sales_bundle_net_weight,
	    expense_per_ton_usd_amount,
	    total_expense_per_gross_weight_usd_amount,
	    total_expense_per_net_weight_usd_amount,
	    sum_sales_bundle_gross_weight,
	    sum_sales_bundle_net_weight
	from
	    punct_2
)
select
    uni.initial_delivery_code,
    uni.initial_delivery_item_code,
    uni.sales_order_code,
    uni.expense_account_code,
    uni.expense_account_name,
    uni.expense_account_search_name,
    uni.plant_producer_search_name,
    uni.transport_type_search_name,
    uni.transport_vehicle_code,
    uni.transport_bill_code,
    uni.transport_bill_and_railcar_uni_code,
    uni.etsng_search_name,
    uni.material_search_name,
    uni.shape_search_name,
    concat_ws('-', coalesce(ekko_1.supplier_code, ekko_2.supplier_code, ekko_3.supplier_code), coalesce(cntr3.counterparty_full_name, '')) as supplier_search_name,  -- Поставщик и его наименование LE.000749
    uni.sector_search_name,
    uni.grade_search_name,
    uni.transport_subtype_search_name,
    uni.sales_bundle_code,
    uni.expense_translated_currency_code,
    uni.expense_group_search_name,
    uni.transportation_service_contract_code,
    uni.transportation_scheme_search_name,
    uni.transportation_scheme_type_search_name,
    uni.transportation_scheme_subtype_search_name,
    uni.sales_bundle_gross_weight,
    uni.sales_bundle_net_weight,
    uni.expense_per_ton_usd_amount,
    uni.total_expense_per_gross_weight_usd_amount,
    uni.total_expense_per_net_weight_usd_amount,
    uni.sum_sales_bundle_gross_weight,
    uni.sum_sales_bundle_net_weight,
    coalesce(ekko_1.purchase_contract_external_part1_number, ekko_2.purchase_contract_external_part1_number, ekko_3.purchase_contract_external_part1_number)
    as external_contract_number
from
    uni
	left join dds.purchase_order_header as ekko_1 on
	    ekko_1.purchase_order_code = uni.transportation_service_contract_code
	    and ekko_1.deleted_flag = false
	left join dds.purchase_agreement_header as ekko_2 on
	    ekko_2.purchase_agreement_code = uni.transportation_service_contract_code
	    and ekko_2.deleted_flag = false
	left join dds.purchase_contract_header as ekko_3 on
	    ekko_3.purchase_contract_code = uni.transportation_service_contract_code
	    and ekko_3.deleted_flag = false
	left join dict_dds.counterparty as cntr3 on
	    cntr3.counterparty_code = coalesce(ekko_1.supplier_code, ekko_2.supplier_code, ekko_3.supplier_code)
	    and cntr3.deleted_flag = false
;