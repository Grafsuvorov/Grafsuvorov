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
    	flow_id = 'SI_MaintenaceOrder_AI')
    	--AND uuid NOT IN (
    	--	SELECT DISTINCT 
    	--		uuid 
    	--	FROM 
    	--		stg."TORO2_ORD_OPR")
	--)
-- SELECT * FROM items;
, items_attr AS (
	SELECT 
      (xpath('AUFNR/text()', xml_item))[1]::varchar AS "AUFNR"
    , unnest(xpath('ORDER_OPR', xml_item)) 			AS attr_node
    , flow_id
	, source_system
	, record_id
	, uuid
	, dt_insert
	FROM 
		items
	)
-- SELECT * FROM items_attr;	
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



[
  {
    "Plan": {
      "Node Type": "Gather Motion",
      "Senders": 6,
      "Receivers": 1,
      "Slice": 1,
      "Segments": 6,
      "Gang Type": "primary reader",
      "Startup Cost": 0.00,
      "Total Cost": 26409.82,
      "Plan Rows": 221818,
      "Plan Width": 864,
      "Output": ["items_attr.\"AUFNR\"", "(((xpath('VORNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('KTSCH/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('ARBPL/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('WERKS/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "((((xpath('NTANF_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone)", "((((xpath('NTEND_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone)", "((((xpath('FSAVD_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone)", "((((xpath('FSEDD_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone)", "(((xpath('EQUNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('TPLNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "((((xpath('ARBEI/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::numeric(11,2))", "((((xpath('ANZZL/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::integer)", "((((xpath('ISMNW/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::numeric(11,2))", "((((xpath('DAUNO/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::numeric(10,2))", "(((xpath('DAUNE/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('ARBEH/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('LTXA1/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('ZOP_STTXT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('ZOP_ASTXT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(((xpath('PLNNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)", "(CASE WHEN (((xpath('USR10/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying IS NULL) THEN false ELSE true END)", "(CASE WHEN (((xpath('ZREJECT_OPR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying IS NULL) THEN false ELSE true END)", "items_attr.flow_id", "items_attr.source_system", "items_attr.record_id", "items_attr.uuid", "items_attr.dt_insert"],
      "Plans": [
        {
          "Node Type": "Subquery Scan",
          "Parent Relationship": "Outer",
          "Slice": 1,
          "Segments": 6,
          "Gang Type": "primary reader",
          "Alias": "items_attr",
          "Startup Cost": 0.00,
          "Total Cost": 26409.82,
          "Plan Rows": 221818,
          "Plan Width": 864,
          "Output": ["items_attr.\"AUFNR\"", "((xpath('VORNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('KTSCH/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('ARBPL/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('WERKS/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "(((xpath('NTANF_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone", "(((xpath('NTEND_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone", "(((xpath('FSAVD_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone", "(((xpath('FSEDD_DT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::timestamp without time zone", "((xpath('EQUNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('TPLNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "(((xpath('ARBEI/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::numeric(11,2)", "(((xpath('ANZZL/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::integer", "(((xpath('ISMNW/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::numeric(11,2)", "(((xpath('DAUNO/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying)::numeric(10,2)", "((xpath('DAUNE/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('ARBEH/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('LTXA1/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('ZOP_STTXT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('ZOP_ASTXT/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "((xpath('PLNNR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying", "CASE WHEN (((xpath('USR10/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying IS NULL) THEN false ELSE true END", "CASE WHEN (((xpath('ZREJECT_OPR/text()'::text, items_attr.attr_node, '{}'::text[]))[1])::character varying IS NULL) THEN false ELSE true END", "items_attr.flow_id", "items_attr.source_system", "items_attr.record_id", "items_attr.uuid", "items_attr.dt_insert"],
          "Plans": [
            {
              "Node Type": "Result",
              "Parent Relationship": "Subquery",
              "Slice": 1,
              "Segments": 6,
              "Gang Type": "primary reader",
              "Startup Cost": 0.00,
              "Total Cost": 1455.31,
              "Plan Rows": 221818,
              "Plan Width": 864,
              "Output": ["((xpath('AUFNR/text()'::text, (unnest(xpath('//Item'::text, \"INPUT_DATA_FROM_SAPXI_IN\".document_xml, '{}'::text[]))), '{}'::text[]))[1])::character varying", "unnest(xpath('ORDER_OPR'::text, (unnest(xpath('//Item'::text, \"INPUT_DATA_FROM_SAPXI_IN\".document_xml, '{}'::text[]))), '{}'::text[]))", "\"INPUT_DATA_FROM_SAPXI_IN\".flow_id", "\"INPUT_DATA_FROM_SAPXI_IN\".source_system", "\"INPUT_DATA_FROM_SAPXI_IN\".record_id", "\"INPUT_DATA_FROM_SAPXI_IN\".uuid", "\"INPUT_DATA_FROM_SAPXI_IN\".dt_insert"],
              "Plans": [
                {
                  "Node Type": "Result",
                  "Parent Relationship": "Outer",
                  "Slice": 1,
                  "Segments": 6,
                  "Gang Type": "primary reader",
                  "Startup Cost": 0.00,
                  "Total Cost": 318.49,
                  "Plan Rows": 2218,
                  "Plan Width": 864,
                  "Output": ["unnest(xpath('//Item'::text, \"INPUT_DATA_FROM_SAPXI_IN\".document_xml, '{}'::text[]))", "\"INPUT_DATA_FROM_SAPXI_IN\".flow_id", "\"INPUT_DATA_FROM_SAPXI_IN\".source_system", "\"INPUT_DATA_FROM_SAPXI_IN\".record_id", "\"INPUT_DATA_FROM_SAPXI_IN\".uuid", "\"INPUT_DATA_FROM_SAPXI_IN\".dt_insert"],
                  "Plans": [
                    {
                      "Node Type": "Seq Scan",
                      "Parent Relationship": "Outer",
                      "Slice": 1,
                      "Segments": 6,
                      "Gang Type": "primary reader",
                      "Relation Name": "INPUT_DATA_FROM_SAPXI_IN",
                      "Schema": "landing",
                      "Alias": "INPUT_DATA_FROM_SAPXI_IN",
                      "Startup Cost": 0.00,
                      "Total Cost": 318.49,
                      "Plan Rows": 2218,
                      "Plan Width": 864,
                      "Output": ["\"INPUT_DATA_FROM_SAPXI_IN\".document_xml", "\"INPUT_DATA_FROM_SAPXI_IN\".flow_id", "\"INPUT_DATA_FROM_SAPXI_IN\".source_system", "\"INPUT_DATA_FROM_SAPXI_IN\".record_id", "\"INPUT_DATA_FROM_SAPXI_IN\".uuid", "\"INPUT_DATA_FROM_SAPXI_IN\".dt_insert"],
                      "Filter": "((\"INPUT_DATA_FROM_SAPXI_IN\".flow_id)::text = 'SI_MaintenaceOrder_AI'::text)"
                    }
                  ]
                }
              ]
            }
          ]
        }
      ]
    },
    "Settings": {
      "Optimizer": "Postgres query optimizer"
    }
  }
]
