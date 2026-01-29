select *  FROM dict_stg."TORO2_FLC_HDR"
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

SQL Error [XX000]: ERROR: could not find hash function for type 142 in operator family 1995 (cdbhash.c:421)
