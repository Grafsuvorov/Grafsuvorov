insert into ods.lips_ral(	
	vbeln,  
	posnr, 
	werks,
	charg,  
	lgort,  
	bwtar,  
	spart,
	matkl,
	matnr,	
	vgbel,  
	vgpos, 
	pstyv,
	lfimg,
	xchpf,
	brgew,
	ntgew,
	meins,
	gewei,
	objpo,
	vrkme
)
select
	l."VBELN" as vbeln,												-- Поставка
	l."POSNR" as posnr,												-- Позиция поставки
	tech_etl.util_text_to_null_validation(l."WERKS") as werks,		-- Завод производитель (код)
	tech_etl.util_text_to_null_validation(l."CHARG") as charg,		-- Номер партии
	tech_etl.util_text_to_null_validation(l."LGORT") as lgort,		-- Склад
	tech_etl.util_text_to_null_validation(l."BWTAR") as bwtar,		-- Вид оценки
	tech_etl.util_text_to_null_validation(l."SPART") as spart,		-- Сектор - группа материалов (код)
	tech_etl.util_text_to_null_validation(l."MATKL") as matkl,		-- Группа материалов (код)
	tech_etl.util_text_to_null_validation(l."MATNR") as matnr,		-- Материал (код)
	tech_etl.util_text_to_null_validation(l."VGBEL") as vgbel,		-- Ссылка на Торговый документ: данные заголовка VBAK, VBAP
	tech_etl.util_text_to_null_validation(l."VGPOS") as vgpos,		-- Ссылка на Торговый документ: данные позиции VBAP
	tech_etl.util_text_to_null_validation(l."PSTYV") as pstyv,		-- Тип позиции поставки
	l."LFIMG" as lfimg,												-- Фактически поставленное количество (ПЕ)
	tech_etl.util_text_to_null_validation(l."XCHPF") as xchpf,      -- Признак упрвления партиями
	l."BRGEW" as brgew,												-- Вес брутто
	l."NTGEW" as ntgew,												-- Вес нетто
	tech_etl.util_text_to_null_validation(l."MEINS") as meins,		-- Базовая единица измерения
	tech_etl.util_text_to_null_validation(l."GEWEI") as gewei,		-- Единица измерения веса	
	tech_etl.util_text_to_null_validation(l."OBJPO") as objpo, 
	tech_etl.util_text_to_null_validation(l."VRKME") as vrkme       -- Код единицы измерения веса
from stg."LIPS" as l
where 1=1
--and case when l."AEDAT"='00000000' then l."ERDAT" else l."AEDAT" end  >='20220101'  -- Инкремент обновления, по дате. После инициирующей, обновлять на согласованную глубину
;