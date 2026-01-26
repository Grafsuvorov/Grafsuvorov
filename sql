SELECT
    i.flow_id,
    i.source_system,
    i.record_id,
    i.uuid,
    i.dt_insert,

    item.aufnr                     AS "AUFNR",

    opr.vornr                      AS "VORNR",
    opr.ktsch                      AS "KTSCH",
    opr.arbpl                      AS "ARBPL",
    opr.werks                      AS "WERKS",

    NULLIF(opr.ntanf_dt, '')::timestamp  AS "NTANF_DT",
    NULLIF(opr.ntend_dt, '')::timestamp  AS "NTEND_DT",
    NULLIF(opr.fsavd_dt, '')::timestamp  AS "FSAVD_DT",
    NULLIF(opr.fsedd_dt, '')::timestamp  AS "FSEDD_DT",

    opr.equnr                      AS "EQUNR",
    opr.tplnr                      AS "TPLNR",

    NULLIF(opr.arbei, '')::numeric(11,2) AS "ARBEI",
    NULLIF(opr.anzzl, '')::integer       AS "ANZZL",
    NULLIF(opr.ismnw, '')::numeric(11,2) AS "ISMNW",
    NULLIF(opr.dauno, '')::numeric(10,2) AS "DAUNO",

    opr.daune                      AS "DAUNE",
    opr.arbeh                      AS "ARBEH",
    opr.ltxa1                      AS "LTXA1",
    opr.zop_sttxt                  AS "ZOP_STTXT",
    opr.zop_astxt                  AS "ZOP_ASTXT",
    opr.plnnr                      AS "PLNNR",

    (opr.usr10 IS NOT NULL)        AS "USR10",
    (opr.zreject_opr IS NOT NULL)  AS "ZREJECT_OPR"

FROM landing."INPUT_DATA_FROM_SAPXI_IN" i

-- ========= уровень Item =========
CROSS JOIN LATERAL
xpath_table(
    i.document_xml,
    '//Item',
    PASSING i.document_xml,
    COLUMNS
        xml_item xml PATH '.',
        aufnr    text PATH 'AUFNR'
) item

-- ========= уровень ORDER_OPR =========
CROSS JOIN LATERAL
xpath_table(
    item.xml_item,
    'ORDER_OPR',
    PASSING item.xml_item,
    COLUMNS
        vornr        text PATH 'VORNR',
        ktsch        text PATH 'KTSCH',
        arbpl        text PATH 'ARBPL',
        werks        text PATH 'WERKS',
        ntanf_dt     text PATH 'NTANF_DT',
        ntend_dt     text PATH 'NTEND_DT',
        fsavd_dt     text PATH 'FSAVD_DT',
        fsedd_dt     text PATH 'FSEDD_DT',
        equnr        text PATH 'EQUNR',
        tplnr        text PATH 'TPLNR',
        arbei        text PATH 'ARBEI',
        anzzl        text PATH 'ANZZL',
        ismnw        text PATH 'ISMNW',
        dauno        text PATH 'DAUNO',
        daune        text PATH 'DAUNE',
        arbeh        text PATH 'ARBEH',
        ltxa1        text PATH 'LTXA1',
        zop_sttxt    text PATH 'ZOP_STTXT',
        zop_astxt    text PATH 'ZOP_ASTXT',
        plnnr        text PATH 'PLNNR',
        usr10        text PATH 'USR10',
        zreject_opr  text PATH 'ZREJECT_OPR'
) opr

WHERE i.flow_id = 'SI_MaintenaceOrder_AI';
