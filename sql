INSERT INTO dict_stg."TORO2_FLC_HDR" (
	/* ---------- бизнес‑атрибуты ---------- */
	  "TPLNR"  			-- Техническое место (код)
	, "FLTYP"  			-- Тип технического места (код)
	, "PLTXT"  			-- Техническое место (имя)
	, "EARTX" 			-- Вид объекта (имя)
	, "ZZWERKS"  		-- Завод владелец (код)
	, "ZZDIVISION"  	-- Участок (код)
	, "IWERK"  			-- Завод, планирующий выполнение (код)
	, "STTXT"  			-- Системные статусы
	, "ASTTX"  			-- Пользовательские статусы
	, "ZCOBTYP"  		-- Тип технологического оборудования (код)
	, "ZCOBCOD"  		-- Комплексный объект (код)
	, "KLART"  			-- Вид класса (код)
	, "CLASS" 			-- Класс (код)
	, "TPLMA"  			-- Вышестоящее техническое место (код)
	, "BUKRS"			-- Балансовая единица (код)
	, "RBNR"  			-- Каталог кодов ТОРО (код)
	, "ZZTPLNR"  		-- Образец (код)
	, "EQART"  			-- Вид технического объекта (код)
	, "SUBMT"  			-- Материал типа конструкции (код)
	, "DATAB"  			-- Дата начала эксплуатации
    /* ---------- атрибуты источника ---------- */
    , flow_id        	   			
    , source_system  	   			
    , record_id      	   			
    , uuid           	   		
    , dt_insert      	 		
)
WITH items AS (
	SELECT
        unnest(xpath('//item', document_xml)) AS xml_item,
        flow_id,
        source_system,
        record_id,
        uuid,
        dt_insert
    FROM
        landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE
        flow_id = 'SI_TechPlaceReplicate_AI'
        AND uuid NOT IN (
        	SELECT  
    			uuid 
    		FROM 
    			dict_stg."TORO2_FLC_HDR")
	)
--SELECT * FROM items;
SELECT
	  (xpath('TPLNR_INT/text()', xml_item))[1]::varchar 	AS "TPLNR"
	, (xpath('FLTYP/text()', xml_item))[1]::varchar 		AS "FLTYP"
	, (xpath('PLTXT/text()', xml_item))[1]::varchar 		AS "PLTXT"
	, (xpath('EARTX/text()', xml_item))[1]::varchar 		AS "EARTX"
	, (xpath('WERKS/text()', xml_item))[1]::varchar 		AS "ZZWERKS"
	, (xpath('DIVISION_1/text()', xml_item))[1]::varchar 	AS "ZZDIVISION"
	, (xpath('IWERK/text()', xml_item))[1]::varchar 		AS "IWERK"
	, (xpath('STTXT/text()', xml_item))[1]::varchar 		AS "STTXT"
	, (xpath('USTXT/text()', xml_item))[1]::varchar 		AS "ASTTX"
	, (xpath('ZCOBTYP/text()', xml_item))[1]::varchar 		AS "ZCOBTYP"
	, (xpath('ZCOBCOD/text()', xml_item))[1]::varchar 		AS "ZCOBCOD"
	, (xpath('KLART/text()', xml_item))[1]::varchar 		AS "KLART"
	, (xpath('CLASS/text()', xml_item))[1]::varchar 		AS "CLASS"
	, (xpath('TPLMA/text()', xml_item))[1]::varchar 		AS "TPLMA"
	, (xpath('BUKRS/text()', xml_item))[1]::varchar 		AS "BUKRS"
	, (xpath('RBNR/text()', xml_item))[1]::varchar 			AS "RBNR"
	, (xpath('ZZTPLNR/text()', xml_item))[1]::varchar 		AS "ZZTPLNR"
	, (xpath('EQART/text()', xml_item))[1]::varchar 		AS "EQART"
	, (xpath('SUBMT/text()', xml_item))[1]::varchar 		AS "SUBMT"
	, (xpath('DATAB/text()', xml_item))[1]::varchar::date 	AS "DATAB"
    , flow_id
	, source_system
	, record_id
	, uuid
	, dt_insert
FROM 
	items;
