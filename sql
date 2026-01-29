DELETE FROM dict_stg."TORO2_EQP_HDR"
WHERE (
	  "EQUNR"
	, source_system
	) IN (
		SELECT DISTINCT
      		  (xpath('TECHOBJ/text()', xml_item))[1]::varchar AS "EQUNR"
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
	    			flow_id = 'SI_TechObjectReplicate_AI' 
	    			AND uuid NOT IN (
	    				SELECT DISTINCT  
	    					uuid 
	    				FROM 
	    					dict_stg."TORO2_EQP_HDR")
	    		) AS t1
    		);

INSERT INTO dict_stg."TORO2_EQP_HDR" (
	/* ---------- бизнес‑атрибуты ---------- */
	  "EQUNR"  			-- Единица оборудования (код)
	, "EARTX"  			-- Вид объекта (имя)
	, "ZZWERKS"  		-- Завод владелец (код)
	, "ZZDIVISION" 		-- Участок (код)
	, "EQKTX"  			-- Единица оборудования (имя)
	, "INVNR"  			-- Инвентарный номер (код)
	, "ANLNR"  			-- Основной номер основного средства
	, "ANLUN"  			-- Субномер основного средства
	, "IWERK"  			-- Завод, планирующий выполнение (код)
	, "TPLNR" 			-- Техническое место (код)
	, "HEQUI"  			-- Вышестоящая единица оборудования (код)
	, "STTXT"  			-- Системные статусы
	, "ASTTX"  			-- Пользовательские статусы
	, "ZCOBTYP"  		-- Тип технологического оборудования (код)
	, "ZCOBCOD"  		-- Комплексный объект (код)
	, "KLART"  			-- Вид класса (код)
	, "CLASS"  			-- Класс (код)
	, "BUKRS"  			-- Балансовая единица (код)
	, "RBNR"  			-- Каталог кодов ТОРО (код)
	, "ZZEQUNR"  		-- Образец (код)
	, "EQART"  			-- Вид технического объекта (код)
	, "SUBMT"  			-- Материал типа конструкции (код)
	, "SERGE"  			-- Серийный номер изготовителя (код)
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
        flow_id = 'SI_TechObjectReplicate_AI'
        AND uuid NOT IN (
        	SELECT  
    			uuid 
    		FROM 
    			dict_stg."TORO2_EQP_HDR")
	)
--SELECT * FROM items;
SELECT
	  (xpath('TECHOBJ/text()', xml_item))[1]::varchar 		AS "EQUNR"
	, (xpath('EARTX/text()', xml_item))[1]::varchar 		AS "EARTX"
	, (xpath('ZZSWERK/text()', xml_item))[1]::varchar 		AS "ZZWERKS"
	, (xpath('DIVISION/text()', xml_item))[1]::varchar 		AS "ZZDIVISION"
	, (xpath('TEXT/text()', xml_item))[1]::varchar 			AS "EQKTX"
	, (xpath('INVNR/text()', xml_item))[1]::varchar 		AS "INVNR"
	, (xpath('ANLNR/text()', xml_item))[1]::varchar 		AS "ANLNR"
	, (xpath('ANLUN/text()', xml_item))[1]::varchar 		AS "ANLUN"
	, (xpath('IWERK/text()', xml_item))[1]::varchar 		AS "IWERK"
	, (xpath('TPLMA/text()', xml_item))[1]::varchar 		AS "TPLNR"
	, (xpath('HEQUI/text()', xml_item))[1]::varchar 		AS "HEQUI"
	, (xpath('STTXT/text()', xml_item))[1]::varchar 		AS "STTXT"
	, (xpath('USTXT/text()', xml_item))[1]::varchar 		AS "ASTTX"
	, (xpath('ZCOBTYP/text()', xml_item))[1]::varchar 		AS "ZCOBTYP"
	, (xpath('ZCOBCOD/text()', xml_item))[1]::varchar 		AS "ZCOBCOD"
	, (xpath('KLART/text()', xml_item))[1]::varchar 		AS "KLART"
	, (xpath('CLASS/text()', xml_item))[1]::varchar 		AS "CLASS"
	, (xpath('BUKRS/text()', xml_item))[1]::varchar 		AS "BUKRS"
	, (xpath('RBNR/text()', xml_item))[1]::varchar 			AS "RBNR"
	, (xpath('ZZEQUNR/text()', xml_item))[1]::varchar 		AS "ZZEQUNR"
	, (xpath('EQART/text()', xml_item))[1]::varchar 		AS "EQART"
	, (xpath('SUBMT/text()', xml_item))[1]::varchar 		AS "SUBMT"
	, (xpath('SERGE/text()', xml_item))[1]::varchar 		AS "SERGE"
    , flow_id
	, source_system
	, record_id
	, uuid
	, dt_insert
FROM 
	items;
