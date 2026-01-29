DELETE FROM dict_stg."TORO2_FLC_HDR" d
USING (
    SELECT DISTINCT uuid
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechPlaceReplicate_AI'
) s
WHERE d.uuid = s.uuid;

DELETE FROM dict_stg."TORO2_EQP_HDR" d
USING (
    SELECT DISTINCT
           uuid
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechObjectReplicate_AI'
) s
WHERE d.uuid = s.uuid;



INSERT INTO dict_stg."TORO2_EQP_HDR" (
    /* ---------- бизнес-атрибуты ---------- */
      "EQUNR"
    , "EARTX"
    , "ZZWERKS"
    , "ZZDIVISION"
    , "EQKTX"
    , "INVNR"
    , "ANLNR"
    , "ANLUN"
    , "IWERK"
    , "TPLNR"
    , "HEQUI"
    , "STTXT"
    , "ASTTX"
    , "ZCOBTYP"
    , "ZCOBCOD"
    , "KLART"
    , "CLASS"
    , "BUKRS"
    , "RBNR"
    , "ZZEQUNR"
    , "EQART"
    , "SUBMT"
    , "SERGE"
    /* ---------- атрибуты источника ---------- */
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
)
WITH src AS (
    /* 1. Берём XML из landing */
    SELECT
        unnest(xpath('//item', document_xml)) AS xml_item,
        flow_id,
        source_system,
        record_id,
        uuid,
        dt_insert
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechObjectReplicate_AI'
),
new_only AS (
    /* 2. Отсекаем уже существующие uuid (anti-join) */
    SELECT s.*
    FROM src s
    LEFT JOIN dict_stg."TORO2_EQP_HDR" d
        ON d.uuid = s.uuid
    WHERE d.uuid IS NULL
),
parsed AS (
    /* 3. Парсинг XML → scalar */
    SELECT
          (xpath('TECHOBJ/text()', xml_item))[1]::text AS "EQUNR"
        , (xpath('EARTX/text()',   xml_item))[1]::text AS "EARTX"
        , (xpath('ZZSWERK/text()', xml_item))[1]::text AS "ZZWERKS"
        , (xpath('DIVISION/text()',xml_item))[1]::text AS "ZZDIVISION"
        , (xpath('TEXT/text()',    xml_item))[1]::text AS "EQKTX"
        , (xpath('INVNR/text()',   xml_item))[1]::text AS "INVNR"
        , (xpath('ANLNR/text()',   xml_item))[1]::text AS "ANLNR"
        , (xpath('ANLUN/text()',   xml_item))[1]::text AS "ANLUN"
        , (xpath('IWERK/text()',   xml_item))[1]::text AS "IWERK"
        , (xpath('TPLMA/text()',   xml_item))[1]::text AS "TPLNR"
        , (xpath('HEQUI/text()',   xml_item))[1]::text AS "HEQUI"
        , (xpath('STTXT/text()',   xml_item))[1]::text AS "STTXT"
        , (xpath('USTXT/text()',   xml_item))[1]::text AS "ASTTX"
        , (xpath('ZCOBTYP/text()', xml_item))[1]::text AS "ZCOBTYP"
        , (xpath('ZCOBCOD/text()', xml_item))[1]::text AS "ZCOBCOD"
        , (xpath('KLART/text()',   xml_item))[1]::text AS "KLART"
        , (xpath('CLASS/text()',   xml_item))[1]::text AS "CLASS"
        , (xpath('BUKRS/text()',   xml_item))[1]::text AS "BUKRS"
        , (xpath('RBNR/text()',    xml_item))[1]::text AS "RBNR"
        , (xpath('ZZEQUNR/text()', xml_item))[1]::text AS "ZZEQUNR"
        , (xpath('EQART/text()',   xml_item))[1]::text AS "EQART"
        , (xpath('SUBMT/text()',   xml_item))[1]::text AS "SUBMT"
        , (xpath('SERGE/text()',   xml_item))[1]::text AS "SERGE"

        , flow_id
        , source_system
        , record_id
        , uuid
        , dt_insert
    FROM new_only
)
SELECT
      "EQUNR"
    , "EARTX"
    , "ZZWERKS"
    , "ZZDIVISION"
    , "EQKTX"
    , "INVNR"
    , "ANLNR"
    , "ANLUN"
    , "IWERK"
    , "TPLNR"
    , "HEQUI"
    , "STTXT"
    , "ASTTX"
    , "ZCOBTYP"
    , "ZCOBCOD"
    , "KLART"
    , "CLASS"
    , "BUKRS"
    , "RBNR"
    , "ZZEQUNR"
    , "EQART"
    , "SUBMT"
    , "SERGE"
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
FROM parsed;
