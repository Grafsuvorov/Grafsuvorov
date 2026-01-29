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
    -- только новые uuid (как было раньше)
    SELECT s.*
    FROM src s
    LEFT JOIN dict_stg."TORO2_FLC_HDR" d
        ON d.uuid = s.uuid
    WHERE d.uuid IS NULL
),
keys_to_update AS (
    -- бизнес-ключи новых объектов
    SELECT DISTINCT
           (xpath('TPLNR_INT/text()', xml_item))[1]::text AS tplnr,
           source_system
    FROM new_only
)
DELETE FROM dict_stg."TORO2_FLC_HDR" d
USING keys_to_update k
WHERE d."TPLNR" = k.tplnr
  AND d.source_system = k.source_system;
