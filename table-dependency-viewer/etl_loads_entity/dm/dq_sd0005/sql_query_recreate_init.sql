--Таблицу не дропать и не транкейтить !!!!

create table if not exists dm.dq_sd0005(
    error_code varchar null,
    error_short_name varchar null,
    error_full_name varchar null,
    business_area_code varchar null,
    error_type_code varchar null,
    severity_type_code varchar null,
    table_source_code varchar null,
    error_description_text text null,
    error_algorithm_text text null,
    change_type_code varchar null,
    total_weight_net numeric(13, 3) null,
    total_including_smelters_wh_weight_net numeric(13, 3) null,
    total_shipped_metal_in_inventory_weight_net numeric(13, 3) null,
    total_not_yet_delivered_metal_weight_net numeric(13, 3) null,
    dt_report varchar null,
    delivery_number_sales varchar null,
    batch varchar null,
    uni varchar null,
    weight_nk numeric(13, 3) null,
    --business_location_for_reporting_name,
    "location" varchar null,
    business_location_name varchar null,
    plant_producer_code varchar null,
    warehouse_shipment_type_name varchar null,
    dttm_inserted timestamp not null default now(),
    dttm_updated timestamp not null default now(),
    job_name varchar(60) not null default 'airflow'::character varying,
    deleted_flag boolean not null default false
    )
with (
    appendonly = true,
    orientation = column,
    compresstype = zstd,
    compresslevel = 3
)
distributed by (dttm_inserted, dt_report, delivery_number_sales, batch);
