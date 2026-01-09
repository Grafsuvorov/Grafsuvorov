insert into dds.purchase_contract_price_conditions
select 
	ekpo.ebeln as purchase_contract_code,
	ekpo.ebelp as purchase_contract_position_code,
	a016.kschl as price_condition_type_code,
	a016.datbi as dt_price_condition_valid_to,
	konp.kzbzg as price_scale_basis_code,
	konm.klfn1 as price_scale_basis_consecutive_code,
	a016.datab as dt_price_condition_valid_from,
	konp.knumh as price_condition_code,
	konp.kopos as price_condition_position_code,
	konp.loevm_ko as condition_deleted_flag_code,
	konp.kmein as price_condition_uom_code,
	case when konm.knumh is not null 
		 then first_value(konm.kbetr) over (partition by konm.knumh, konm.kopos order by konm.klfn1)
		 else konp.kbetr 
	end as price_rate,
	konm.kbetr as price_scale_rate,	
	konm.kstbm as price_scale_limit_from_quantity,
	case when konm.knumh is not null 
		 then coalesce(lead(konm.kstbm) over (partition by konm.knumh, konm.kopos order by konm.klfn1) - 0.001, 999999999999.999)
		 else null
	end as price_scale_limit_to_quantity,
	ctt.condition_type_name	as price_condition_type_name_rus,
	psbt.price_scale_basis_name as price_scale_basis_name_rus
from ods.ekpo_ral as ekpo
	left join ods.ekko_ral as ekko				-- здесь left join, так как через фильтр where оставляем только контракты
		on ekpo.ebeln = ekko.ebeln	
	join ods.a016_ral as a016					-- здесь join, так как нужны контракты, которые есть в таблице для связи A016   !!!
		on a016.evrtn = ekpo.ebeln and 
		   a016.evrtp = ekpo.ebelp and
		   a016.kappl = 'M' and
		   a016.kschl = 'PB00'
	join ods.konp_ral as konp					-- здесь join, так как нужны контракты, для которых есть ценовые условия в KONP
		on konp.knumh = a016.knumh and
		   konp.kappl = 'M' and
		   konp.kschl = 'PB00'   	   
	left join ods.konm_ral as konm      		-- здесь left join, так как шкала не всегда есть, но само ценовое условие должно быть
		on konm.knumh = konp.knumh and 
		   konm.kopos = konp.kopos
	left join dict_dds.price_scale_basis_texts as psbt 		--так как в ключе код вида шкалы, то справочно добавим ее текст (для разработчиков при просмотре данных, чтобы было проще понимать)
		on psbt.price_scale_basis_code = konp.kzbzg and 
		   psbt.language_code = 'R'
	left join dict_dds.condition_type_texts as ctt			--так как в ключе код тип ценового условия, то справочно добавим его текст (для разработчиков при просмотре данных, чтобы было проще понимать)
		on ctt.condition_type_code = konp.kschl and
		   ctt.application_code = konp.kappl and
		   ctt.language_code = 'R' and
		   ctt.condition_usage_area_code = 'A'  
where ekko.bstyp = 'K';
