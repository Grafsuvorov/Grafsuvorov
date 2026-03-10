insert into dds.delivery_document_position
select
	l.vbeln as delivery_code,								-- Поставка
	l.posnr as delivery_position_line_item_code,			-- Позиция поставки
	l.werks as plant_producer_code,							-- Завод производитель (код)
	l.charg as batch_code,									-- Номер партии
	l.lgort as warehouse_code, 								-- Склад
	l.bwtar as valuation_type_code,							-- Вид оценки	
	l.spart as sector_code,									-- Сектор - группа материалов (код)
	l.matkl as material_group_code,							-- Группа матириалов (код)
	l.matnr as material_code,								-- Материал (код)
	l.vgbel as sales_document_code,							-- Торговый документ (код)
	l.vgpos as sales_document_position_line_item_code,		-- Торговый документ, позиция
	l.pstyv as delivery_position_line_item_type_code,		-- Тип позиции поставки
	l.ntgew as weight_net,									-- Вес нетто
	l.brgew as weight_gross,								-- Вес брутто
	l.lfimg as quantity,									-- Количество
	l.meins as quantity_uom_code,							-- Единица измерения для количества
	l.gewei	as weight_uom_code								-- Единица измерения для весов нетто и брутто
from ods.lips_ral as l   									-- Документ сбыта: поставка: данные позиции
where 1=1
--and l.dttm_updated  >='20240301'  -- Инкремент обновления, по дате обновления ods. После инициирующей (всё), обновлять на согласованную глубину (последние полгода)
;