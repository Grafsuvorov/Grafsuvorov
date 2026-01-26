create temporary table items_attr on commit drop  as (
WITH items AS (
	SELECT
        unnest(xpath('//Item',document_xml)) AS xml_item
		, flow_id
		, source_system
		, record_id
		, uuid
		, dt_insert
    FROM 
    	landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE 
    	flow_id = 'SI_MaintenaceOrder_AI'
    	AND uuid NOT IN (SELECT uuid FROM stg."TORO2_ORD_OPR")
	)
	SELECT 
      (xpath('AUFNR/text()', xml_item))[1]::varchar AS "AUFNR"
    , xml_item
    , flow_id
	, source_system
	, record_id
	, uuid
	, dt_insert
	FROM 
		items
	);
INSERT INTO stg."TORO2_ORD_OPR" (
	/* ---------- бизнес‑атрибуты ---------- /
	  "AUFNR" 			-- Заказ (код)
	, "VORNR"  			-- Операция (код)
	, "KTSCH"  			-- Образец (код)
	, "ARBPL"  			-- Выполняющее рабочее место (код)
	, "WERKS"  			-- Завод  выполняющего рабочего места (код)
	, "NTANF_DT" 		-- Базисный срок начала (Дата + время)
	, "NTEND_DT"  		-- Базисный срок окончания (Дата + время)
	, "FSAVD_DT"  		-- Самое раннее запланированное начало (Дата + время)
	, "FSEDD_DT" 		-- Самое раннее запланированное окончание (Дата + время)
	, "EQUNR"  			-- Единица оборудования (код)
	, "TPLNR"  			-- Техническое место (код)
	, "ARBEI"  			-- Плановая работа
	, "ANZZL"  			-- Необходимые мощности
	, "ISMNW"  			-- Фактическая работа
	, "DAUNO"  			-- Стандартная продолжительность
	, "DAUNE"  			-- Единица измерения стандартной продолжительности (код)
	, "ARBEH"  			-- Единица измерения работы (код)
	, "LTXA1"  			-- Краткий текст
	, "ZOP_STTXT"  		-- Системные статусы
	, "ZOP_ASTXT"  		-- Пользовательские статусы
	, "PLNNR"  			-- Группа технологических карт (код)
	, "USR10"  			-- Весь персонал
	, "ZREJECT_OPR"  	-- Отклонение
    / ---------- атрибуты источника ---------- */
    , flow_id        	   			
    , source_system  	   			
    , record_id      	   			
    , uuid           	   		
    , dt_insert    )	
SELECT
    "AUFNR"
	, (xpath('VORNR/text()', attr_node))[1]::varchar 					AS "VORNR"
	, (xpath('KTSCH/text()', attr_node))[1]::varchar 					AS "KTSCH"
	, (xpath('ARBPL/text()', attr_node))[1]::varchar 					AS "ARBPL"
	, (xpath('WERKS/text()', attr_node))[1]::varchar 					AS "WERKS"
	, (xpath('NTANF_DT/text()', attr_node))[1]::varchar::timestamp 		AS "NTANF_DT"
	, (xpath('NTEND_DT/text()', attr_node))[1]::varchar::timestamp 		AS "NTEND_DT"
	, (xpath('FSAVD_DT/text()', attr_node))[1]::varchar::timestamp 		AS "FSAVD_DT"
	, (xpath('FSEDD_DT/text()', attr_node))[1]::varchar::timestamp		AS "FSEDD_DT"
	, (xpath('EQUNR/text()', attr_node))[1]::varchar					AS "EQUNR"
	, (xpath('TPLNR/text()', attr_node))[1]::varchar 					AS "TPLNR"
	, (xpath('ARBEI/text()', attr_node))[1]::varchar::numeric(11,2) 	AS "ARBEI"
	, (xpath('ANZZL/text()', attr_node))[1]::varchar::integer 			AS "ANZZL"
	, (xpath('ISMNW/text()', attr_node))[1]::varchar::numeric(11,2) 	AS "ISMNW"
	, (xpath('DAUNO/text()', attr_node))[1]::varchar::numeric(10,2) 	AS "DAUNO"
	, (xpath('DAUNE/text()', attr_node))[1]::varchar 					AS "DAUNE"
	, (xpath('ARBEH/text()', attr_node))[1]::varchar 					AS "ARBEH"
	, (xpath('LTXA1/text()', attr_node))[1]::varchar 					AS "LTXA1"
	, (xpath('ZOP_STTXT/text()', attr_node))[1]::varchar				AS "ZOP_STTXT"
	, (xpath('ZOP_ASTXT/text()', attr_node))[1]::varchar 				AS "ZOP_ASTXT"
	, (xpath('PLNNR/text()', attr_node))[1]::varchar 					AS "PLNNR"
	, CASE 
		WHEN (xpath('USR10/text()', attr_node))[1]::varchar IS NULL
			THEN FALSE 
		ELSE TRUE 
	END::bool 															AS "USR10"
	, CASE 
		WHEN (xpath('ZREJECT_OPR/text()', attr_node))[1]::varchar IS NULL
			THEN FALSE 
		ELSE TRUE 
	END::bool 															AS "ZREJECT_OPR"
    , flow_id
	, source_system
	, record_id
	, uuid
	, dt_insert
FROM 
	items_attr
	, 	lateral unnest(xpath('ORDER_OPR', xml_item)) 			AS attr_node;
