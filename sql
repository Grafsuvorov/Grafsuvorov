RETRIEVE 100 FROM ENDPOINT adb_cursor_652655414000006c80000011f;
12:41
DECLARE adb_cursor_394353893 PARALLEL RETRIEVE CURSOR FOR SELECT transport_bill_code, railcar_code, transport_bill_and_railcar_code, departure_type_code, departure_type_name, status_name, russian_port_pier_code, russian_port_pier_name, russian_port_pier_search_name, russian_port_code, russian_port_name, russian_port_search_name, russian_port_terminal_code, russian_port_terminal_name, russian_port_terminal_search_name, vessel_code, vessel_name, vessel_search_name, import_method_code, import_method_name, import_method_search_name, dt_general_act, supplier_code, supplier_name, supplier_search_name, producer_code, producer_name, producer_search_name, business_scheme_type_code, dt_departure, dt_shipping, dt_shipping_yyyy, dt_shipping_dd, dt_shipping_mmm, dt_shipping_yyyymm, package_type_code, package_type_name, package_type_search_name, material_code, material_name, material_search_name, material_group_code, material_group_name, material_group_search_name, purchase_document_code, purchase_document_position_code,

3rd party error log:
ERROR: [103]: unable to find a valid repository:
       repo1: [FileMissingError] unable to load info file '/net/rgm-s-khbkp01.hq.root.ad/export/backup/adb/rgm-dwh-adben/archive/rgm-s01--1-0/archive.info' or '/net/rgm-s-khbkp01.hq.root.ad/export/backup/adb/rgm-dwh-adben/archive/rgm-s01--1-0/archive.info.copy':
       FileMissingError: unable to open missing file '/net/rgm-s-khbkp01.hq.root.ad/export/backup/adb/rgm-dwh-adben/archive/rgm-s01--1-0/archive.info' for read
       FileMissingError: unable to open missing file '/net/rgm-s-khbkp01.hq.root.ad/export/backup/adb/rgm-dwh-adben/archive/rgm-s01--1-0/archive.info.copy' for read
       HINT: archive.info cannot be opened but is required to push/get WAL segments.
       HINT: is archive_command configured correctly in postgresql.conf?

вот такие запросы вижу 
"create temp table fcmd_tmp on commit drop as
select
	financial_management_area_code,
	funds_center_code,
	dt_valid_from,
	dt_valid_to,
	funds_center_full_name_rus,
	row_number() over (partition by financial_management_area_code, funds_center_code order by dt_valid_to desc ) as rn
from dict_dds.funds_center_master_data
distributed replicated"	2026-02-12 12:45:25.961 +0300	bulgakovaa	dwh
select pg_catalog.gp_acquire_sample_rows(13210725, 30000, 'f');	2026-02-12 12:45:26.070 +0300	bulgakovaa	dwh
