drop table if exists dm.sales_storage_registration_vs_storage_movement cascade; 

create table if not exists dm.sales_storage_registration_vs_storage_movement (
	warehouse_code varchar null,												-- Удаленный склад (код) SD.000420
	forwarder_in_foreign_port_code varchar null, 								-- Экспедитор в иностранном порту (код) SD.000950
	transportation_delivery_code varchar null, 									-- LE-поставка прихода или расхода SD.001383
	warehouse_name varchar null,												-- Удаленный склад SD.000421
	country_of_remote_warehouse_code varchar null,								-- Страна удаленного склада (код) SD.000725
	country_of_remote_warehouse_name varchar null,								-- Страна удаленного склада SD.000423
	forwarder_in_foreign_port_name varchar null,								-- Экспедитор в иностранном порту SD.000609	
	region_of_remote_warehouse_code varchar null,								-- Регион удаленного склада (код) SD.000726
	transportation_delivery_creation_exceed_category_code varchar null,			-- Категория отклонения от даты создания LE-поставки SD.001382
	dt_shipment_instruction_in_foreign_port_created date null,					-- Дата создания инструкции на отгрузку из иностранного порта
	shipment_instruction_creation_exceed_category_code varchar null,			-- Категория отклонения от даты создания ОИ SD.001396
	flow varchar null,
	dttm_inserted timestamp not null default now(), 
    dttm_updated timestamp not null default now(),
    job_name varchar not null default 'airflow'::character varying,
    deleted_flag bool not null default false	
)
with (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (warehouse_code);

comment on table dm.sales_storage_registration_vs_storage_movement is 'Отклонения от даты регистрации прихода/расхода';
comment on column dm.sales_storage_registration_vs_storage_movement.warehouse_code is 'Удаленный склад (код) | Код склада (порта, ж/д станции) | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.knote';
comment on column dm.sales_storage_registration_vs_storage_movement.forwarder_in_foreign_port_code is 'Экспедитор в иностранном порту (код) | Код контрагента, осуществляющего прием и хранение готовой продукции на складе в ин. порту. | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.forwarder_in_foreign_port_code';
comment on column dm.sales_storage_registration_vs_storage_movement.transportation_delivery_code is 'LE-поставка | LE-поставка прихода или расхода  | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.delivery_code_le_p, delivery_code_le_r';
comment on column dm.sales_storage_registration_vs_storage_movement.warehouse_name is 'Удаленный склад | Наименование удаленного склада порта | dict_dds.transport_hub_texts.transport_hub_name';
comment on column dm.sales_storage_registration_vs_storage_movement.country_of_remote_warehouse_code is 'Страна удаленного склада (код) | Код страны удаленного склада | dict_dds.address.country_code';
comment on column dm.sales_storage_registration_vs_storage_movement.country_of_remote_warehouse_name is 'Страна удаленного склада | Наименование страны удаленного склада | dict_dds.country_texts.country_full_name';
comment on column dm.sales_storage_registration_vs_storage_movement.forwarder_in_foreign_port_name is 'Экспедитор в иностранном порту | Наименование экспедитора в иностранном порту | dict_dds.counterparty.counterparty_short_name';
comment on column dm.sales_storage_registration_vs_storage_movement.region_of_remote_warehouse_code is 'Регион удаленного склада (код) | Код региона удаленного склада | dict_dds.country.market_region1_code';
comment on column dm.sales_storage_registration_vs_storage_movement.transportation_delivery_creation_exceed_category_code is 'Категория отклонения от даты создания LE-поставки | Разница Даты создания LE-поставки и Даты движения | dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_created, dt_created_r, dt_transportation_stage_start_p, dt_transportation_stage_start_r';
comment on column dm.sales_storage_registration_vs_storage_movement.dt_shipment_instruction_in_foreign_port_created is 'Дата создания инструкции на отгрузку из иностранного порта | Дата создания инструкции на отгрузку из иностранного порта | dds.shipment_instruction.dt_created';
comment on column dm.sales_storage_registration_vs_storage_movement.shipment_instruction_creation_exceed_category_code is 'Категория отклонения от даты создания ОИ | Разница Даты создания ОИ и Даты движения | dds.shipment_instruction.dt_created, dm_calc.sales_bundle_transport_hub_turnover_sdt0004.dt_created, dt_created_r';
