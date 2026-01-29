WITH src AS (
    SELECT
        unnest(xpath('//item', document_xml)) AS xml_item,
        source_system,
        uuid
    FROM landing."INPUT_DATA_FROM_SAPXI_IN"
    WHERE flow_id = 'SI_TechObjectReplicate_AI'
),
new_only AS (
    -- только новые uuid (эквивалент uuid NOT IN)
    SELECT s.*
    FROM src s
    LEFT JOIN dict_stg."TORO2_EQP_HDR" d
        ON d.uuid = s.uuid
    WHERE d.uuid IS NULL
),
keys_to_update AS (
    -- бизнес-ключи новых объектов
    SELECT DISTINCT
           (xpath('TECHOBJ/text()', xml_item))[1]::text AS equnr,
           source_system
    FROM new_only
)
DELETE FROM dict_stg."TORO2_EQP_HDR" d
USING keys_to_update k
WHERE d."EQUNR" = k.equnr
  AND d.source_system = k.source_system;
