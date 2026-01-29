DELETE FROM dict_stg."TORO2_FLC_HDR" d
USING (
    SELECT DISTINCT
           (xpath('TPLNR_INT/text()', xml_item))[1]::text AS tplnr,
           source_system
    FROM (
        SELECT
            unnest(xpath('//item', document_xml)) AS xml_item,
            source_system,
            uuid
        FROM landing."INPUT_DATA_FROM_SAPXI_IN"
        WHERE flow_id = 'SI_TechPlaceReplicate_AI'
          AND uuid NOT IN (
              SELECT uuid
              FROM dict_stg."TORO2_FLC_HDR"
          )
    ) t
) s
WHERE d."TPLNR" = s.tplnr
  AND d.source_system = s.source_system;
