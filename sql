   DELETE FROM stg."TORO2_ORD_HDR"
WHERE (
	  "AUFNR"
	, source_system
	) IN (
		SELECT DISTINCT
      		  (xpath('AUFNR/text()', xml_item))[1]::varchar AS "AUFNR"
			, source_system
		FROM (
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
    			AND uuid NOT IN (
    				SELECT DISTINCT  
    					uuid 
    				FROM 
    					stg."TORO2_ORD_HDR"
    				)
    		) AS s
		);
SQL Error [XX000]: ERROR: could not find hash function for type 142 in operator family 1995 (cdbhash.c:421)
