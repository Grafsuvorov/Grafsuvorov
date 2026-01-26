INSERT INTO stg."TORO2_ORD_OPR" (
    "AUFNR","VORNR","KTSCH","ARBPL","WERKS",
    "NTANF_DT","NTEND_DT","FSAVD_DT","FSEDD_DT",
    "EQUNR","TPLNR","ARBEI","ANZZL","ISMNW","DAUNO",
    "DAUNE","ARBEH","LTXA1","ZOP_STTXT","ZOP_ASTXT",
    "PLNNR","USR10","ZREJECT_OPR",
    flow_id,source_system,record_id,uuid,dt_insert
)
SELECT
    (xpath('AUFNR/text()', item.xml_item))[1]::varchar,

    (xpath('VORNR/text()', opr.opr_node))[1]::varchar,
    (xpath('KTSCH/text()', opr.opr_node))[1]::varchar,
    (xpath('ARBPL/text()', opr.opr_node))[1]::varchar,
    (xpath('WERKS/text()', opr.opr_node))[1]::varchar,

    NULLIF((xpath('NTANF_DT/text()', opr.opr_node))[1]::varchar,'')::timestamp,
    NULLIF((xpath('NTEND_DT/text()', opr.opr_node))[1]::varchar,'')::timestamp,
    NULLIF((xpath('FSAVD_DT/text()', opr.opr_node))[1]::varchar,'')::timestamp,
    NULLIF((xpath('FSEDD_DT/text()', opr.opr_node))[1]::varchar,'')::timestamp,

    (xpath('EQUNR/text()', opr.opr_node))[1]::varchar,
    (xpath('TPLNR/text()', opr.opr_node))[1]::varchar,

    NULLIF((xpath('ARBEI/text()', opr.opr_node))[1]::varchar,'')::numeric(11,2),
    NULLIF((xpath('ANZZL/text()', opr.opr_node))[1]::varchar,'')::integer,
    NULLIF((xpath('ISMNW/text()', opr.opr_node))[1]::varchar,'')::numeric(11,2),
    NULLIF((xpath('DAUNO/text()', opr.opr_node))[1]::varchar,'')::numeric(10,2),

    (xpath('DAUNE/text()', opr.opr_node))[1]::varchar,
    (xpath('ARBEH/text()', opr.opr_node))[1]::varchar,
    (xpath('LTXA1/text()', opr.opr_node))[1]::varchar,
    (xpath('ZOP_STTXT/text()', opr.opr_node))[1]::varchar,
    (xpath('ZOP_ASTXT/text()', opr.opr_node))[1]::varchar,
    (xpath('PLNNR/text()', opr.opr_node))[1]::varchar,

    ((xpath('USR10/text()', opr.opr_node))[1] IS NOT NULL),
    ((xpath('ZREJECT_OPR/text()', opr.opr_node))[1] IS NOT NULL),

    i.flow_id,i.source_system,i.record_id,i.uuid,i.dt_insert

FROM landing."INPUT_DATA_FROM_SAPXI_IN" i

LEFT JOIN stg."TORO2_ORD_OPR" e
       ON e.uuid = i.uuid

CROSS JOIN LATERAL
unnest(xpath('//Item', i.document_xml)) AS item(xml_item)

CROSS JOIN LATERAL
unnest(xpath('ORDER_OPR', item.xml_item)) AS opr(opr_node)

WHERE i.flow_id = 'SI_MaintenaceOrder_AI'
  AND e.uuid IS NULL;
