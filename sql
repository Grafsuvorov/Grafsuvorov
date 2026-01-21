SELECT
    MAX(length(base.plant_producer_delivery_code)) AS plant_producer_delivery_code_len,
    MAX(length(base.initial_delivery_code))        AS initial_delivery_code_len,
    MAX(length(base.batch_code))                   AS batch_code_len,
    MAX(length(base.sales_delivery_code))          AS sales_delivery_code_len,
    MAX(length(base.delivery_for_storage_calculation_code)) AS delivery_for_storage_calculation_code_len,
    MAX(length(base.delivery_in_final_release_code)) AS delivery_in_final_release_code_len,
    MAX(length(base.bill_of_lading_code))          AS bill_of_lading_code_len,
    MAX(length(base.shipment_instruction_number))  AS shipment_instruction_number_len
FROM dm_calc.storage_sales_bundles_amount base;
