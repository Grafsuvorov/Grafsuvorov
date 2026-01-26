SELECT
    i.flow_id,
    i.source_system,
    i.record_id,
    i.uuid,
    i.dt_insert,

    (xpath('AUFNR/text()', item.xml_item))[1]::varchar AS "AUFNR",

    (xpath('VORNR/text()', opr.opr_node))[1]::varchar AS "VORNR",
    (xpath('KTSCH/text()', opr.opr_node))[1]::varchar AS "KTSCH",
    (xpath('ARBPL/text()', opr.opr_node))[1]::varchar AS "ARBPL",
    (xpath('WERKS/text()', opr.opr_node))[1]::varchar AS "WERKS",

    NULLIF((xpath('NTANF_DT/text()', opr.opr_node))[1]::varchar, '')::timestamp AS "NTANF_DT",
    NULLIF((xpath('NTEND_DT/text()', opr.opr_node))[1]::varchar, '')::timestamp AS "NTEND_DT",

    NULLIF((xpath('ARBEI/text()', opr.opr_node))[1]::varchar, '')::numeric(11,2) AS "ARBEI",
    NULLIF((xpath('ANZZL/text()', opr.opr_node))[1]::varchar, '')::integer       AS "ANZZL",

    ((xpath('USR10/text()', opr.opr_node))[1] IS NOT NULL)      AS "USR10",
    ((xpath('ZREJECT_OPR/text()', opr.opr_node))[1] IS NOT NULL) AS "ZREJECT_OPR"

FROM landing."INPUT_DATA_FROM_SAPXI_IN" i

-- ===== уровень Item =====
CROSS JOIN LATERAL (
    SELECT unnest(xpath('//Item', i.document_xml)) AS xml_item
) item

-- ===== уровень ORDER_OPR =====
CROSS JOIN LATERAL (
    SELECT unnest(xpath('ORDER_OPR', item.xml_item)) AS opr_node
) opr

WHERE i.flow_id = 'SI_MaintenaceOrder_AI';
