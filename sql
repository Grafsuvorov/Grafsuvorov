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
