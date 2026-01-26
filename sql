SELECT
    i.flow_id,
    i.source_system,
    i.record_id,
    i.uuid,
    i.dt_insert,

    item.aufnr AS "AUFNR",

    opr.vornr  AS "VORNR",
    opr.ktsch  AS "KTSCH",
    opr.arbpl  AS "ARBPL",
    opr.werks  AS "WERKS",

    NULLIF(opr.ntanf_dt, '')::timestamp AS "NTANF_DT",
    NULLIF(opr.ntend_dt, '')::timestamp AS "NTEND_DT",

    NULLIF(opr.arbei, '')::numeric(11,2) AS "ARBEI",
    NULLIF(opr.anzzl, '')::integer       AS "ANZZL",

    (opr.usr10 IS NOT NULL)       AS "USR10",
    (opr.zreject_opr IS NOT NULL) AS "ZREJECT_OPR"

FROM landing."INPUT_DATA_FROM_SAPXI_IN" i

-- ========= Item =========
CROSS JOIN LATERAL
xpath_table(
    '//Item',
    PASSING i.document_xml,
    COLUMNS
        xml_item xml  PATH '.',
        aufnr    text PATH 'AUFNR'
) item

-- ========= ORDER_OPR =========
CROSS JOIN LATERAL
xpath_table(
    'ORDER_OPR',
    PASSING item.xml_item,
    COLUMNS
        vornr        text PATH 'VORNR',
        ktsch        text PATH 'KTSCH',
        arbpl        text PATH 'ARBPL',
        werks        text PATH 'WERKS',
        ntanf_dt     text PATH 'NTANF_DT',
        ntend_dt     text PATH 'NTEND_DT',
        arbei        text PATH 'ARBEI',
        anzzl        text PATH 'ANZZL',
        usr10        text PATH 'USR10',
        zreject_opr  text PATH 'ZREJECT_OPR'
) opr

WHERE i.flow_id = 'SI_MaintenaceOrder_AI';
