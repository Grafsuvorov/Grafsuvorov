drop table if exists dds.transportation_service_and_accounting_relation_history;

create table dds.transportation_service_and_accounting_relation_history (
	plant_code varchar(4) null,
	transportation_service_invoice_code varchar(10) null,
	transportation_service_invoice_position_code varchar(5) null,
	unit_balance_code varchar(4) null,
	accounting_document_code varchar(10) null,
	accounting_document_fiscal_year varchar(4) null,
	sales_document_code varchar(10) null,
	sales_document_position_code varchar(6) null,
	sales_document_type_code varchar(1) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
 	appendonly=true,
 	orientation=column,
 	compresstype=zstd,
 	compresslevel=3
)
distributed by (
	plant_code,
	transportation_service_invoice_code
);

comment on table dds.transportation_service_and_accounting_relation_history is 'Исторические документы закрытия или списания позиций документов на оплату';
comment on column dds.transportation_service_and_accounting_relation_history.plant_code is 'Завод (код) | Завод (код) | ods./rusal/perf_ral.werks';
comment on column dds.transportation_service_and_accounting_relation_history.transportation_service_invoice_code is 'Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | ods./rusal/perf_ral.id';
comment on column dds.transportation_service_and_accounting_relation_history.transportation_service_invoice_position_code is 'Позиция акта на транспортировку (код) | Позиция акта на транспортировку (код) | ods./rusal/perf_ral.pos';
comment on column dds.transportation_service_and_accounting_relation_history.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | ods./rusal/perf_ral.bukrs';
comment on column dds.transportation_service_and_accounting_relation_history.accounting_document_code is 'Номер бухгалтерского документа (код) | Номер бухгалтерского документа (код) | ods./rusal/perf_ral.belnr';
comment on column dds.transportation_service_and_accounting_relation_history.accounting_document_fiscal_year is 'Финансовый год | Финансовый год | ods./rusal/perf_ral.gjahr';
comment on column dds.transportation_service_and_accounting_relation_history.sales_document_code is 'Торговый документ (код) | Торговый документ (код) | ods./rusal/perf_ral.vbeln';
comment on column dds.transportation_service_and_accounting_relation_history.sales_document_position_code is 'Позиция торгового документа (код) | Позиция торгового документа (код) | ods./rusal/perf_ral.posnr';
comment on column dds.transportation_service_and_accounting_relation_history.sales_document_type_code is 'Тип документа (как категория, например, БухгДокумент (ПозПроведена), Счет-фактура (Списание), Документ регистра материала (Списание)) | Тип документа (как категория, например, БухгДокумент (ПозПроведена), Счет-фактура (Списание), Документ регистра материала (Списание)) | ods./rusal/perf_ral.type';
