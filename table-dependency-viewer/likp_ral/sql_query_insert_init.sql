insert into ods.likp_ral (
	vbeln,
	vkorg,
	traid,
	bolnr,
	lfart,
	lddat,
	kodat,
	route,
	sdabw,
	xabln,
	traty,
	lifex,
	lstel,
	ntgew, 
	btgew,
	gewei,
	erdat,
	erzet,
	ernam,
	trspg,
	vsart,
	kunnr,
	vstel,
	vbtyp,
	wadat_ist
)
select
	l."VBELN" as vbeln,														-- Заводская поставка (код)
	tech_etl.util_text_to_null_validation(l."VKORG") as vkorg,				-- Сбытовая организация
	tech_etl.util_text_to_null_validation(l."TRAID") as traid,				-- Номер вагона
	tech_etl.util_text_to_null_validation(l."BOLNR") as bolnr,				-- Транспортная накладная
	tech_etl.util_text_to_null_validation(l."LFART") as lfart,				-- Вид поставки
	tech_etl.util_text_to_date_validation(l."LDDAT") as lddat,				-- Дата отгрузки с завода
	tech_etl.util_text_to_date_validation(l."KODAT") as kodat,				-- Дата отгрузки со склада
	tech_etl.util_text_to_null_validation(l."ROUTE") as route,				-- Маршрут
	tech_etl.util_text_to_null_validation(l."SDABW") as sdabw,				-- Тип транспортного средства (код)
	tech_etl.util_text_to_null_validation(l."XABLN") as xabln,				-- Номер накладной
	tech_etl.util_text_to_null_validation(l."TRATY") as traty,				-- Вид транспортного средства (код)
	tech_etl.util_text_to_null_validation(l."LIFEX") as lifex,				-- Внешняя идентификация накладной
	tech_etl.util_text_to_null_validation(l."LSTEL") as lstel,				-- Пункт погрузки
	l."NTGEW" as ntgew, 													-- Вес нетто
	l."BTGEW" as btgew, 													-- Вес нетто + катанка
	tech_etl.util_text_to_null_validation(l."GEWEI") as gewei,				-- Единица измерения веса
	tech_etl.util_text_to_date_validation(l."ERDAT") as erdat,				-- Дата создания записи	
	tech_etl.util_text_to_time_validation(l."ERZET") as erzet,				-- Время создания записи
	tech_etl.util_text_to_null_validation(l."ERNAM") as ernam,				-- Логин пользователя, создавшего запись
	tech_etl.util_text_to_null_validation(l."TRSPG") as trspg,
	tech_etl.util_text_to_null_validation(l."VSART") as vsart,				-- Wagon/container
	tech_etl.util_text_to_null_validation(l."KUNNR") as kunnr,				-- Получатель материала
	tech_etl.util_text_to_null_validation(l."VSTEL") as vstel,				-- Пункт отгрузки(организационная единица (код))
	tech_etl.util_text_to_null_validation(l."VBTYP") as vbtyp,				-- Категория документов
	tech_etl.util_text_to_date_validation(l."WADAT_IST") as wadat_ist		-- Дата фактического движения материала   
from stg."LIKP" as l
where l."DELETED_FLAG" = false;