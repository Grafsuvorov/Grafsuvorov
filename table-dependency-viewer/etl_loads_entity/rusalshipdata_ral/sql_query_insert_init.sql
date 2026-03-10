insert into ods."/rusal/shipdata_ral" (
	ident, charg, vbeln, vbeln_lf, order_, plant, vagon, platf, gradecod, market, expedidsub, shtempel_date, prih_zavod_date, impexp_date, nstamp, rekvizit, werks,
	customid, contrexp, razmer, firmapid, firmap, idw1, route, unl_term, stationnc, quar_sert, quar_date, mest, lgort, nk, plant1, stationo, raspor, vbeln_lfs,
	dateadd, length, width, height, diameter, nsert, posnr_lf, kodat, stationn, box, marshr, dataprek, zavod, gtd, dataskl, exped, dateot, packing, cust2_id, potrebit, 
	exporter, locid, vsart, datapgp, contr_id, brutto, netto, werks_nosap, svh, posnr_lfs, traty)
select 
	rs."IDENT" as ident, 														-- Идентификатор записи об отгрузке из файла
	tech_etl.util_text_to_null_validation(rs."CHARG") as charg,					-- Партия 
	tech_etl.util_text_to_null_validation(rs."VBELN") as vbeln, 				-- Исходная поставка
	tech_etl.util_text_to_null_validation(rs."VBELN_LF") as vbeln_lf, 			-- Номер поставки завода производителя
	tech_etl.util_text_to_null_validation(rs."ORDER_") as order_,				-- Заказ ЦК в отгрузке,
	tech_etl.util_text_to_null_validation(rs."PLANT") as plant,					-- Завод производитель (код),
	tech_etl.util_text_to_null_validation(rs."VAGON") as vagon,					-- Вагон,
	tech_etl.util_text_to_null_validation(rs."PLATF") as platf,					-- Платформа,
	tech_etl.util_text_to_null_validation(rs."GRADECOD") as gradecod, 			-- Материал (код)
	tech_etl.util_text_to_null_validation(rs."MARKET") as market,				-- Рынок в отгрузке (код),
	tech_etl.util_text_to_null_validation(rs."EXPEDIDSUB") as expedidsub,		-- Экспедитор Договорной (код),  
	tech_etl.util_text_to_date_validation(rs."SHTEMPEL_DATE") as shtempel_date, -- Дата штемпеля по ЖДН   
	tech_etl.util_text_to_date_validation(rs."PRIH_ZAVOD_DATE") as prih_zavod_date,-- Дата прихода на завод      
	tech_etl.util_text_to_date_validation(rs."IMPEXP_DATE") as impexp_date, 	-- Дата перехода из импорта в экспорт
	tech_etl.util_text_to_null_validation(rs."NSTAMP") as nstamp,				-- Номера пломб,
	rs."REKVIZIT" as rekvizit,													-- Вес крепления груза,
	tech_etl.util_text_to_null_validation(rs."WERKS") as werks,					-- Принимающий завод грузополучателя в системе SAP,
	tech_etl.util_text_to_null_validation(rs."CUSTOMID") as customid, 			-- Нет в биг скрипте,
	tech_etl.util_text_to_null_validation(rs."CONTREXP") as contrexp,			-- Номер экспортного контракта,
	tech_etl.util_text_to_null_validation(rs."RAZMER") as razmer,				-- Размер единицы готовой продукции,
	tech_etl.util_text_to_null_validation(rs."FIRMAPID") as firmapid,			-- Код грузополучателя материала,
	tech_etl.util_text_to_null_validation(rs."FIRMAP") as firmap,				-- Наименование грузополучателя материала,
	tech_etl.util_text_to_null_validation(rs."IDW1") as idw1,					-- Idw1,
	tech_etl.util_text_to_null_validation(rs."ROUTE") as route,					-- Маршрут в отгрузке,
	tech_etl.util_text_to_null_validation(rs."UNL_TERM") as unl_term,			-- Код терминала разгрузки,
	tech_etl.util_text_to_null_validation(rs."STATIONNC") as stationnc,			-- Код станции назначения,
	tech_etl.util_text_to_null_validation(rs."QUAR_SERT") as quar_sert,			-- Карантинный сертификат*/,          
	tech_etl.util_text_to_date_validation(rs."QUAR_DATE")  as quar_date, 		-- Дата карантинного сертификата
	rs."MEST" as mest,															-- Количество грузовых мест,
	tech_etl.util_text_to_null_validation(rs."LGORT") as lgort,					-- Принимающий склад,
	rs."NK" as nk, 																-- Нет в биг скрипте,
	tech_etl.util_text_to_null_validation(rs."PLANT1") as plant1,				-- Завод собственник (код),
	tech_etl.util_text_to_null_validation(rs."STATIONO") as stationo,			-- Станция отправления,
	tech_etl.util_text_to_null_validation(rs."RASPOR") as raspor,				-- Номер распоряжения,
	tech_etl.util_text_to_null_validation(rs."VBELN_LFS") as vbeln_lfs,			-- Номер поставки завода собственника*/,     
	tech_etl.util_text_to_date_validation(rs."DATEADD") as dateadd, 			-- Дата первого появления записи в системе
	tech_etl.util_text_to_null_validation(rs."LENGTH") as length,				-- Длина единицы готовой продукции,
	tech_etl.util_text_to_null_validation(rs."WIDTH") as width,					-- Ширина единицы готовой продукции,
	tech_etl.util_text_to_null_validation(rs."HEIGHT") as height,				-- Высота единицы готовой продукции,
	tech_etl.util_text_to_null_validation(rs."DIAMETER") as diameter,			-- Диаметр единицы готовой продукции,
	tech_etl.util_text_to_null_validation(rs."NSERT") as nsert,					-- Номер сертификата,
	tech_etl.util_text_to_null_validation(rs."POSNR_LF") as posnr_lf,			-- Позиция поставки завода производителя,
	tech_etl.util_text_to_date_validation(rs."KODAT") as kodat, 				-- Дата комплектования
	tech_etl.util_text_to_null_validation(rs."STATIONN") as stationn,			-- Станция назначения в отгрузке,
	tech_etl.util_text_to_null_validation(rs."BOX") as box,						-- Ящик
	tech_etl.util_text_to_null_validation(rs."MARSHR") as marshr,				-- Номер маршрута
	tech_etl.util_text_to_date_validation(rs."DATAPREK") as dataprek, 			-- Дата экспедитора
	tech_etl.util_text_to_null_validation(rs."ZAVOD") as zavod,					-- Наименование завода
	tech_etl.util_text_to_null_validation(rs."GTD") as gtd,						-- Номер ГТД
	tech_etl.util_text_to_date_validation(rs."DATASKL") as dataskl, 			-- Дата склада
	tech_etl.util_text_to_null_validation(rs."EXPED") as exped, 				-- Экспедитор, наименование
	tech_etl.util_text_to_date_validation(rs."DATEOT") as dateot,				-- Дата отгрузки
	"PACKING" as packing,														-- Вес упаковки
	tech_etl.util_text_to_null_validation(rs."CUST2_ID") as cust2_id,			-- № конечного покупателя в SAP
	tech_etl.util_text_to_null_validation(rs."POTREBIT") as potrebit,           -- Потребитель
	tech_etl.util_text_to_null_validation(rs."EXPORTER") as exporter,           -- Экспортер
	tech_etl.util_text_to_null_validation(rs."LOCID") as locid,					-- Порт (код)	
	tech_etl.util_text_to_null_validation(rs."VSART") as vsart,					-- Wagon/container
	tech_etl.util_text_to_date_validation(rs."DATAPGP") as datapgp, 			-- Дата пересечения границы вагоном	
	tech_etl.util_text_to_null_validation(rs."CONTR_ID") as contr_id,			-- Системный номер договора завода-производителя
	rs."BRUTTO" as brutto, 														-- Вес брутто
	rs."NETTO" as netto, 														-- Вес нетто
	tech_etl.util_text_to_null_validation(rs."WERKS_NOSAP") as werks_nosap,		-- Завод не в САП
	tech_etl.util_text_to_null_validation(rs."SVH") as svh,						-- Признак удаленного склада
	tech_etl.util_text_to_null_validation(rs."POSNR_LFS") as posnr_lfs, 			-- Позиция поставки завода собственника
	tech_etl.util_text_to_null_validation(rs."TRATY") as traty
from stg."/RUSAL/SHIPDATA" as rs
where 1=1;
