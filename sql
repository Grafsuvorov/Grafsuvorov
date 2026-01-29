WITH src AS (
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
    /* 
       Только новые uuid — 
       ровно как было раньше через NOT IN,
       но безопасно через anti-join
    */
    SELECT s.*
    FROM src s
    LEFT JOIN dict_stg."TORO2_FLC_HDR" d
        ON d.uuid = s.uuid
    WHERE d.uuid IS NULL
)
INSERT INTO dict_stg."TORO2_FLC_HDR" (
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
)
SELECT
      (xpath('TPLNR_INT/text()', xml_item))[1]::text
    , (xpath('FLTYP/text()',     xml_item))[1]::text
    , (xpath('PLTXT/text()',     xml_item))[1]::text
    , (xpath('EARTX/text()',     xml_item))[1]::text
    , (xpath('WERKS/text()',     xml_item))[1]::text
    , (xpath('DIVISION_1/text()',xml_item))[1]::text
    , (xpath('IWERK/text()',     xml_item))[1]::text
    , (xpath('STTXT/text()',     xml_item))[1]::text
    , (xpath('USTXT/text()',     xml_item))[1]::text
    , (xpath('ZCOBTYP/text()',   xml_item))[1]::text
    , (xpath('ZCOBCOD/text()',   xml_item))[1]::text
    , (xpath('KLART/text()',     xml_item))[1]::text
    , (xpath('CLASS/text()',     xml_item))[1]::text
    , (xpath('TPLMA/text()',     xml_item))[1]::text
    , (xpath('BUKRS/text()',     xml_item))[1]::text
    , (xpath('RBNR/text()',      xml_item))[1]::text
    , (xpath('ZZTPLNR/text()',   xml_item))[1]::text
    , (xpath('EQART/text()',     xml_item))[1]::text
    , (xpath('SUBMT/text()',     xml_item))[1]::text
    , CASE
        WHEN (xpath('DATAB/text()', xml_item))[1]::text ~ '^\d{8}$'
        THEN to_date((xpath('DATAB/text()', xml_item))[1]::text,'YYYYMMDD')
      END
    , flow_id
    , source_system
    , record_id
    , uuid
    , dt_insert
FROM new_only;
