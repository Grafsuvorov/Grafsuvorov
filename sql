DELETE FROM stg."TORO2_ORD_HDR" t
USING (
    SELECT DISTINCT
        (xpath('string(AUFNR)', xml_item))::varchar AS aufnr,
        source_system
    FROM (
        SELECT
            unnest(xpath('//Item', document_xml)) AS xml_item,
            source_system,
            uuid
        FROM landing."INPUT_DATA_FROM_SAPXI_IN"
        WHERE flow_id = 'SI_MaintenaceOrder_AI'
          AND uuid NOT IN (
              SELECT uuid FROM stg."TORO2_ORD_HDR"
          )
    ) s
) d
WHERE t."AUFNR" = d.aufnr
  AND t.source_system = d.source_system;
