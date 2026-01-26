SELECT *
FROM landing."INPUT_DATA_FROM_SAPXI_IN" i
CROSS JOIN LATERAL
xpath_table(
    '//Item',
    PASSING i.document_xml,
    COLUMNS
        xml_item xml PATH '.',
        aufnr text PATH 'AUFNR'
) item
WHERE i.flow_id = 'SI_MaintenaceOrder_AI'
LIMIT 10;
