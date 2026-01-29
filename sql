INSERT INTO dict_stg."TORO2_FLC_HDR" (
    /* ---------- бизнес-атрибуты ---------- */
      "TPLNR"
    , "FLTYP"
    , "PLTXT"
    , "EARTX"
    , "ZZWERKS"
    , "ZZDIVISION"
    , "IWERK"
    , "STTXT"
    , "ASTTX"
    , "ZCOBTYP"
    , "ZCOBCOD"
    , "KLART"
    , "CLASS"
    , "TPLMA"
    , "BUKRS"
    , "RBNR"
    , "ZZTPLNR"
    , "EQART"
    , "SUBMT"
    , "DATAB"
    /* ---------- атрибуты источника ---------- */
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
)
WITH src AS (
    /* 1. Берём нужные сообщения из landing */
    SELECT
        unnest(xpath('//item', document_xml)) AS xml_item,
        flow_id,
        source_system,
        record_id,
        uuid,
        dt_insert
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechPlaceReplicate_AI'
),
new_only AS (
    /* 2. Отсекаем уже загруженные uuid (БЕЗ NOT IN) */
    SELECT s.*
    FROM src s
    LEFT JOIN dict_stg."TORO2_FLC_HDR" d
        ON d.uuid = s.uuid
    WHERE d.uuid IS NULL
),
parsed AS (
    /* 3. Парсинг XML → scalar-типы */
    SELECT
          (xpath('TPLNR_INT/text()', xml_item))[1]::text AS "TPLNR"
        , (xpath('FLTYP/text()',       xml_item))[1]::text AS "FLTYP"
        , (xpath('PLTXT/text()',       xml_item))[1]::text AS "PLTXT"
        , (xpath('EARTX/text()',       xml_item))[1]::text AS "EARTX"
        , (xpath('WERKS/text()',       xml_item))[1]::text AS "ZZWERKS"
        , (xpath('DIVISION_1/text()',  xml_item))[1]::text AS "ZZDIVISION"
        , (xpath('IWERK/text()',       xml_item))[1]::text AS "IWERK"
        , (xpath('STTXT/text()',       xml_item))[1]::text AS "STTXT"
        , (xpath('USTXT/text()',       xml_item))[1]::text AS "ASTTX"
        , (xpath('ZCOBTYP/text()',     xml_item))[1]::text AS "ZCOBTYP"
        , (xpath('ZCOBCOD/text()',     xml_item))[1]::text AS "ZCOBCOD"
        , (xpath('KLART/text()',       xml_item))[1]::text AS "KLART"
        , (xpath('CLASS/text()',       xml_item))[1]::text AS "CLASS"
        , (xpath('TPLMA/text()',       xml_item))[1]::text AS "TPLMA"
        , (xpath('BUKRS/text()',       xml_item))[1]::text AS "BUKRS"
        , (xpath('RBNR/text()',        xml_item))[1]::text AS "RBNR"
        , (xpath('ZZTPLNR/text()',     xml_item))[1]::text AS "ZZTPLNR"
        , (xpath('EQART/text()',       xml_item))[1]::text AS "EQART"
        , (xpath('SUBMT/text()',       xml_item))[1]::text AS "SUBMT"

        /* дата — с защитой */
        , CASE
            WHEN (xpath('DATAB/text()', xml_item))[1]::text ~ '^\d{8}$'
            THEN to_date((xpath('DATAB/text()', xml_item))[1]::text, 'YYYYMMDD')
          END AS "DATAB"

        , flow_id
        , source_system
        , record_id
        , uuid
        , dt_insert
    FROM new_only
)
SELECT
      "TPLNR"
    , "FLTYP"
    , "PLTXT"
    , "EARTX"
    , "ZZWERKS"
    , "ZZDIVISION"
    , "IWERK"
    , "STTXT"
    , "ASTTX"
    , "ZCOBTYP"
    , "ZCOBCOD"
    , "KLART"
    , "CLASS"
    , "TPLMA"
    , "BUKRS"
    , "RBNR"
    , "ZZTPLNR"
    , "EQART"
    , "SUBMT"
    , "DATAB"
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
FROM parsed;
