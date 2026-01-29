delete  FROM dict_stg."TORO2_EQP_HDR" d
USING (
    SELECT DISTINCT
           uuid
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechObjectReplicate_AI'
) s
WHERE d.uuid = s.uuid;



INSERT INTO dict_stg."TORO2_EQP_HDR" (
    /* ---------- бизнес-атрибуты ---------- */
      "EQUNR"
    , "EARTX"
    , "ZZWERKS"
    , "ZZDIVISION"
    , "EQKTX"
    , "INVNR"
    , "ANLNR"
    , "ANLUN"
    , "IWERK"
    , "TPLNR"
    , "HEQUI"
    , "STTXT"
    , "ASTTX"
    , "ZCOBTYP"
    , "ZCOBCOD"
    , "KLART"
    , "CLASS"
    , "BUKRS"
    , "RBNR"
    , "ZZEQUNR"
    , "EQART"
    , "SUBMT"
    , "SERGE"
    /* ---------- атрибуты источника ---------- */
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
)
WITH src AS (
    /* 1. Берём XML из landing */
    SELECT
        unnest(xpath('//item', document_xml)) AS xml_item,
        flow_id,
        source_system,
        record_id,
        uuid,
        dt_insert
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechObjectReplicate_AI'
),
new_only AS (
    /* 2. Отсекаем уже существующие uuid (anti-join) */
    SELECT s.*
    FROM src s
    LEFT JOIN dict_stg."TORO2_EQP_HDR" d
        ON d.uuid = s.uuid
    WHERE d.uuid IS NULL
),
parsed AS (
    /* 3. Парсинг XML → scalar */
    SELECT
          (xpath('TECHOBJ/text()', xml_item))[1]::text AS "EQUNR"
        , (xpath('EARTX/text()',   xml_item))[1]::text AS "EARTX"
        , (xpath('ZZSWERK/text()', xml_item))[1]::text AS "ZZWERKS"
        , (xpath('DIVISION/text()',xml_item))[1]::text AS "ZZDIVISION"
        , (xpath('TEXT/text()',    xml_item))[1]::text AS "EQKTX"
        , (xpath('INVNR/text()',   xml_item))[1]::text AS "INVNR"
        , (xpath('ANLNR/text()',   xml_item))[1]::text AS "ANLNR"
        , (xpath('ANLUN/text()',   xml_item))[1]::text AS "ANLUN"
        , (xpath('IWERK/text()',   xml_item))[1]::text AS "IWERK"
        , (xpath('TPLMA/text()',   xml_item))[1]::text AS "TPLNR"
        , (xpath('HEQUI/text()',   xml_item))[1]::text AS "HEQUI"
        , (xpath('STTXT/text()',   xml_item))[1]::text AS "STTXT"
        , (xpath('USTXT/text()',   xml_item))[1]::text AS "ASTTX"
        , (xpath('ZCOBTYP/text()', xml_item))[1]::text AS "ZCOBTYP"
        , (xpath('ZCOBCOD/text()', xml_item))[1]::text AS "ZCOBCOD"
        , (xpath('KLART/text()',   xml_item))[1]::text AS "KLART"
        , (xpath('CLASS/text()',   xml_item))[1]::text AS "CLASS"
        , (xpath('BUKRS/text()',   xml_item))[1]::text AS "BUKRS"
        , (xpath('RBNR/text()',    xml_item))[1]::text AS "RBNR"
        , (xpath('ZZEQUNR/text()', xml_item))[1]::text AS "ZZEQUNR"
        , (xpath('EQART/text()',   xml_item))[1]::text AS "EQART"
        , (xpath('SUBMT/text()',   xml_item))[1]::text AS "SUBMT"
        , (xpath('SERGE/text()',   xml_item))[1]::text AS "SERGE"

        , flow_id
        , source_system
        , record_id
        , uuid
        , dt_insert
    FROM new_only
)
SELECT
      "EQUNR"
    , "EARTX"
    , "ZZWERKS"
    , "ZZDIVISION"
    , "EQKTX"
    , "INVNR"
    , "ANLNR"
    , "ANLUN"
    , "IWERK"
    , "TPLNR"
    , "HEQUI"
    , "STTXT"
    , "ASTTX"
    , "ZCOBTYP"
    , "ZCOBCOD"
    , "KLART"
    , "CLASS"
    , "BUKRS"
    , "RBNR"
    , "ZZEQUNR"
    , "EQART"
    , "SUBMT"
    , "SERGE"
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
FROM parsed;


/* -------------------------------------------------------------
	1.4. Удаляем данные из таблицы, которые будут обновлены
   ------------------------------------------------------------- */

DELETE FROM dict_stg."TORO2_FLC_HDR"
WHERE (
	  "TPLNR"
	, source_system
	) IN (
		SELECT DISTINCT
      		  (xpath('TPLNR_INT/text()', xml_item))[1]::varchar AS "TPLNR"
			, source_system
		FROM (
			SELECT
        		  unnest(xpath('//item',document_xml)) AS xml_item
				, flow_id
				, source_system
				, record_id
				, uuid
				, dt_insert
	    		FROM 
	    			landing."INPUT_DATA_FROM_SAPXI_IN"
	    		WHERE 
	    			flow_id = 'SI_TechPlaceReplicate_AI' 
	    			AND uuid NOT IN (
	    				SELECT DISTINCT  
	    					uuid 
	    				FROM 
	    					dict_stg."TORO2_FLC_HDR")
	    		) AS t1
    		);
    	
    	
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
