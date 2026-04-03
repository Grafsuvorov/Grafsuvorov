drop table if exists lake;
create temporary table lake
(
    delivery_number_initial              varchar(30),
    delivery_number_of_producer_plant    varchar(30),
    batch                                varchar(30),
    plant_producer_code                  varchar(12),
    plant_producer_name                  varchar(90),
    plant_owner_code                     varchar(12),
    dt_shipment                          date,
    railcar                              varchar(60),
    transport_bill                       varchar(105),
    quality_certificate_number           varchar(60),
    internal_compound_key_code           varchar(16),
    delivery_item_of_plant               varchar(18),
    delivery_number_of_plant_owner       varchar(30),
    destination_station_in_shipment_name varchar(120),
    sap_shipdata_reference_code          varchar(16),
    delivery_number_sales                varchar(30)
) with (appendonly = true, orientation = column, compresstype = zstd, compresslevel = 3)
  on commit drop
  distributed randomly ;--by (delivery_number_sales, batch);
insert into lake
select delivery_number_initial
     , delivery_number_of_producer_plant
     , batch
     , plant_producer_code
     , plant_producer_name
     , plant_owner_code
     , dt_shipment
     , railcar
     , transport_bill
     , quality_certificate_number
     , internal_compound_key_code
     , delivery_item_of_plant
     , delivery_number_of_plant_owner
     , destination_station_in_shipment_name
     , sap_shipdata_reference_code
     , delivery_number_sales
  from dm_calc.sd_sales_main_scm ssm
 where ssm.railcar is not null
   and ssm.transport_bill is not null
;

drop table if exists base;
create temporary table base (
       delivery_number_initial text
     , delivery_number_of_producer_plant text
     , batch text
     , plant_producer_code text
     , plant_producer_name text
     , dt_shipment date
     , dt_shipment_actual date
     , railcar text
     , transport_bill text
     , quality_certificate_number text
     , internal_compound_key_code text
     , cnt_887_cnt_888 int
     , cnt_889 int
     , line_889_SD_000002_SD_000004 int
     , line_887_888_SD_000003_SD_000004 int
     , line_887_888_SD_000002_SD_000004 int
     , postavka_887 text
     , postavka_888 text
     , plant_owner_code text
     , is_plant_not_in_sap_system varchar(1)
     , delivery_item_of_plant text
     , delivery_number_of_plant_owner text
     , temporary_warehouse_movement_type_code varchar(1)
     , destination_station_in_shipment_name text
     , nsert text
     , transport_type_code varchar(4)
) with (appendonly = true, orientation = column, compresstype = zstd, compresslevel = 3)
    on commit drop
    distributed randomly;


insert into base
select lake.delivery_number_initial                                                                                                                                                                         -- SD.000001
     , lake.delivery_number_of_producer_plant                                                                                                                                                               -- SD.000003
     , lake.batch                                                                                                                                                                                           -- SD.000004
     , lake.plant_producer_code                                                                                                                                                                             -- SD.000006
     , lake.plant_producer_name                                                                                                                                                                             -- SD.000007
     , case
           when lake.plant_owner_code <> 'E101' then likp.dt_loaded
           else lake.dt_shipment end                                                                                                                                                  as dt_shipment        -- SD.000010
     , shipdata.dt_shipment                                                                                                                                                           as dt_shipment_actual -- SD.000976
     , lake.railcar                                                                                                                                                                                         -- SD.000013
     , lake.transport_bill                                                                                                                                                                                  -- SD.000014
     , lake.quality_certificate_number                                                                                                                                                                      -- SD.000109
     , lake.internal_compound_key_code                                                                                                                                                                      -- SD.000721
     , count(*) over (partition by lake.delivery_number_of_producer_plant, lake.transport_bill, lake.railcar, lake.quality_certificate_number)                                                 as cnt_887_cnt_888
     , count(*) over (partition by lake.delivery_number_of_producer_plant, lake.batch, lake.internal_compound_key_code)                                                                        as cnt_889
     , row_number() over (partition by lake.delivery_number_of_producer_plant, lake.batch, lake.internal_compound_key_code order by lake.delivery_number_sales, lake.batch)                        as line_889_SD_000002_SD_000004
     , row_number() over (partition by lake.delivery_number_of_producer_plant, lake.transport_bill, lake.railcar, lake.quality_certificate_number order by lake.batch)                             as line_887_888_SD_000003_SD_000004
     , row_number() over (partition by lake.delivery_number_of_producer_plant, lake.transport_bill, lake.railcar, lake.quality_certificate_number order by lake.delivery_number_sales, lake.batch) as line_887_888_SD_000002_SD_000004
     , case when shipdata.is_plant_not_in_sap_system is null then lake.delivery_number_of_producer_plant else lake.delivery_number_initial end                                                                                                                                      as postavka_887
     , case when shipdata.is_plant_not_in_sap_system is null then lake.delivery_number_of_producer_plant else lake.delivery_number_initial end                                                                                                                                      as postavka_888
     , lake.plant_owner_code                                                                                                                                                                                -- SD.000099
     , shipdata.is_plant_not_in_sap_system                                                                                                                                                                  -- WERKS_NOSAP
     , lake.delivery_item_of_plant                                                                                                                                                                          -- SD.000110
     , lake.delivery_number_of_plant_owner                                                                                                                                                                  -- SD.000102
     , shipdata.temporary_warehouse_movement_type_code                                                                                                                                                      -- SVH
     , lake.destination_station_in_shipment_name                                                                                                                                                            -- SD.000113
     , shipdata.quality_certificate_number                                                                                                                                            as nsert
     , shipdata.transport_type_code
from lake
	left join dds.sales_batch_delivery as shipdata on shipdata.shipment_entry_from_file_code = lake.sap_shipdata_reference_code
	left join dds.delivery_document_header as likp on likp.delivery_code = lake.delivery_number_of_producer_plant
	where lake.railcar is not null and lake.transport_bill is not null
--	and coalesce(lake.destination_station_in_shipment_name, 'dsfdf') <> 'САМОВЫВОЗ'
	and coalesce(shipdata.transport_type_code, 'sdfsdf') not in ('ПЧТ', 'ПР', 'СДН') -- 'АВТ',
	and case when lake.plant_owner_code <> 'E101' then likp.dt_loaded else lake.dt_shipment end is not null
	and (shipdata.is_plant_not_in_sap_system is null or lake.plant_owner_code = 'E101')
;


drop table if exists filedoc_887_1_1;
create temporary table filedoc_887_1_1 on commit drop as
    (select asclm.sap_document_code
       from dds.aldor_scan_copy_link_to_multiple_sap_document as asclm
       left join dds.aldor_scan_copy_link_to_single_sap_document as ascls
       on ascls.aldor_document_code = asclm.aldor_document_code and ascls.sap_document_type_code = '02'
      where asclm.aldor_document_type_code = '3'
        and ascls.aldor_document_code is not null
      group by asclm.sap_document_code)
    distributed randomly;

drop table if exists filedoc_887_2_1;
create temporary table filedoc_887_2_1 on commit drop as
    (select sap_document_code
       from dds.aldor_scan_copy_link_to_single_sap_document
      where aldor_document_type_code = '3'
        and is_deleted is null
        and sap_document_type_code = '02'
      group by sap_document_code)
    distributed randomly;

drop table if exists filedoc_887_3;
create temporary table filedoc_887_3 on commit drop as
    (select sap_document_number, dt_sap_document
       from dds.aldor_scan_copy_link_to_single_sap_document
      where aldor_document_type_code = '3'
        and is_deleted is null
        and sap_document_type_code = '02'
      group by sap_document_number
             , dt_sap_document)
    distributed randomly;

drop table if exists filedoc_888_1;
create temporary table filedoc_888_1 on commit drop as
    (select asclm.sap_document_code
       from dds.aldor_scan_copy_link_to_multiple_sap_document as asclm
       left join dds.aldor_scan_copy_link_to_single_sap_document as ascls
       on ascls.aldor_document_code = asclm.aldor_document_code and ascls.is_deleted is null
      where asclm.aldor_document_type_code = '4'
      group by asclm.sap_document_code)
    distributed randomly;


drop table if exists filedoc_888_2;
create temporary table filedoc_888_2 on commit drop as
    (select sap_document_code, sap_document_number
       from dds.aldor_scan_copy_link_to_single_sap_document
      where aldor_document_type_code = '4'
        and is_deleted is null
      group by sap_document_code
             , sap_document_number)
    distributed randomly;

drop table if exists him_1;
create temporary table him_1
(
    delivery_reference_code text,
    transport_bill_code     text,
    vehicle_code            text,
    certificate_number      text
)
with (appendonly = true, orientation = column, compresstype = zstd, compresslevel = 3)
    on commit drop
    distributed randomly;
insert into him_1
select delivery_reference_code, transport_bill_code, vehicle_code, certificate_number
   from dds.sales_bundle
  group by delivery_reference_code
         , transport_bill_code
         , vehicle_code
         , certificate_number;


drop table if exists him_2;
create temporary table him_2 on commit drop as
    (select delivery_reference_code
       from dds.sales_bundle
      group by delivery_reference_code)
    distributed randomly;


insert into dm.sales_scanned_documents_analysis(
delivery_number_initial,
delivery_number_of_producer_plant,
plant_producer_code,
plant_producer_name,
dt_shipment,
dt_shipment_actual,
railcar,
transport_bill,
quality_certificate_number,
internal_compound_key_code,
railcar_without_transport_bill_scan_quantity,
railcar_without_certificate_scan_quantity,
railcar_without_chemistry_scan_quantity
)
select
base.delivery_number_initial,
base.delivery_number_of_producer_plant,
base.plant_producer_code,
base.plant_producer_name,
base.dt_shipment,
base.dt_shipment_actual,
base.railcar,
base.transport_bill,
base.quality_certificate_number,
base.internal_compound_key_code,


case
when base.temporary_warehouse_movement_type_code in ('2', '8') then 'D'
when base.destination_station_in_shipment_name = 'САМОВЫВОЗ' then 'D'
when params_for_887_888.range_low_value is not null then 'D'
when (base.cnt_887_cnt_888 <> 1 and base.line_887_888_SD_000003_SD_000004 <> 1) or (base.cnt_887_cnt_888 <> 1 and base.delivery_number_of_producer_plant is null and base.line_887_888_SD_000002_SD_000004 = 1) then 'D'
when coalesce(filedoc_887_1_1.sap_document_code, filedoc_887_1_2.sap_document_code, filedoc_887_2_1.sap_document_code, filedoc_887_2_2.sap_document_code, filedoc_887_3.sap_document_number) is not null then '1'
else '0'
end as railcar_without_transport_bill_scan_quantity, -- SD.000887


case
when base.temporary_warehouse_movement_type_code in ('2', '8') then 'D'
when base.destination_station_in_shipment_name = 'САМОВЫВОЗ' then 'D'
when params_for_887_888.range_low_value is not null then 'D'
when (base.cnt_887_cnt_888 <> 1 and base.line_887_888_SD_000003_SD_000004 <> 1) or (base.cnt_887_cnt_888 <> 1 and base.delivery_number_of_producer_plant is null and base.line_887_888_SD_000002_SD_000004 = 1) then 'D'
when coalesce(filedoc_888_1.sap_document_code, filedoc_888_2.sap_document_code) is not null then '1'
else '0'
end as railcar_without_certificate_scan_quantity, -- SD.000888


case when params_for_889.range_low_value is not null then 'N'
when base.temporary_warehouse_movement_type_code in ('2', '8') then 'N'
when (base.plant_owner_code <> 'E101' or base.plant_owner_code is null) and base.destination_station_in_shipment_name = 'САМОВЫВОЗ' then 'N'
when (base.plant_owner_code <> 'E101' or base.plant_owner_code is null) and (base.cnt_889 <> 1 and line_889_SD_000002_SD_000004 <> 1) then 'N'
when (base.plant_owner_code <> 'E101' or base.plant_owner_code is null) and not (base.cnt_889 <> 1 and line_889_SD_000002_SD_000004 <> 1) and him_1.delivery_reference_code is not null then '1'
when (base.plant_owner_code <> 'E101' or base.plant_owner_code is null) and not (base.cnt_889 <> 1 and line_889_SD_000002_SD_000004 <> 1) and him_1.delivery_reference_code is null then '0'
when base.plant_owner_code = 'E101' and him_2.delivery_reference_code is not null then '1'
when base.plant_owner_code = 'E101' and him_2.delivery_reference_code is null then '0'
end as railcar_without_chemistry_scan_quantity -- SD.000889

from base
left join dds.delivery_document_header as likp
       on likp.delivery_code = base.delivery_number_of_plant_owner
left join filedoc_887_1_1
       on filedoc_887_1_1.sap_document_code = base.delivery_number_of_producer_plant
left join filedoc_887_1_1 as filedoc_887_1_2
       on filedoc_887_1_2.sap_document_code = base.postavka_887
left join filedoc_887_2_1
       on filedoc_887_2_1.sap_document_code = base.delivery_number_of_producer_plant
left join filedoc_887_2_1 as filedoc_887_2_2
       on filedoc_887_2_2.sap_document_code = base.postavka_887
left join filedoc_887_3
       on filedoc_887_3.sap_document_number = base.transport_bill
      and filedoc_887_3.dt_sap_document = base.dt_shipment
left join filedoc_888_1
       on filedoc_888_1.sap_document_code = base.postavka_888
left join filedoc_888_2
       on filedoc_888_2.sap_document_code = base.postavka_888
      and filedoc_888_2.sap_document_number = base.nsert
left join him_1
       on him_1.delivery_reference_code = base.internal_compound_key_code
      and him_1.transport_bill_code = base.transport_bill
      and him_1.vehicle_code = base.railcar
      and him_1.certificate_number = base.quality_certificate_number
left join him_2
       on him_2.delivery_reference_code = base.internal_compound_key_code
left join dict_dds.settings_and_parameters_sap as params_for_887_888
       on params_for_887_888.abap_program_code = '/RUSAL/SD3277M'
      and params_for_887_888.parameter_code = 'TRATY'
      and params_for_887_888.range_low_value = base.transport_type_code
left join dict_dds.settings_and_parameters_sap as params_for_889
       on params_for_889.abap_program_code = 'ZSD5017M_SHIPDATA'
      and params_for_889.parameter_code = 'LFART_ZL'
      and params_for_889.range_low_value = likp.delivery_type_code
;
