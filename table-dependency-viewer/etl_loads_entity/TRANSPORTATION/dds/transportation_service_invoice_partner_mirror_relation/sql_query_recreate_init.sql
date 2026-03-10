drop table if exists dds.transportation_service_invoice_partner_mirror_relation;

create table dds.transportation_service_invoice_partner_mirror_relation(
	unit_balance_code varchar(4) null,
	accounting_document_code varchar(10) null,
	accounting_document_fiscal_year varchar(4) null,
	mirror_accounting_document_unit_balance_code varchar(4) null,
	mirror_accounting_document_code varchar(10) null,
	mirror_accounting_document_fiscal_year varchar(4) null,
	reference_operation_type_code varchar(5) null,
	reference_object_key varchar(20) null,
	mirror_accounting_document_type_code varchar(2) null,
	reverse_document_of_mirror_accounting_document_code varchar(10) null,
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
	unit_balance_code,
	accounting_document_code,
	accounting_document_fiscal_year
);

comment on table dds.transportation_service_invoice_partner_mirror_relation is 'Связь бухгалтерского документа (фактуры за транспортировку) с зеркальными проводками';
comment on column dds.transportation_service_invoice_partner_mirror_relation.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | ods./rusal/mirr_ral.bukrs';
comment on column dds.transportation_service_invoice_partner_mirror_relation.accounting_document_code is 'Номер бухгалтерского документа (код) | Номер бухгалтерского документа (код) | ods./rusal/mirr_ral.belnr';
comment on column dds.transportation_service_invoice_partner_mirror_relation.accounting_document_fiscal_year is 'Финансовый год | Финансовый год | ods./rusal/mirr_ral.gjahr';
comment on column dds.transportation_service_invoice_partner_mirror_relation.mirror_accounting_document_unit_balance_code is 'Балансовая единица зеркального документа (код) | Балансовая единица зеркального документа (код) | ods./rusal/mirp_ral.zbukrs';
comment on column dds.transportation_service_invoice_partner_mirror_relation.mirror_accounting_document_code is 'Номер зеркального документа (код) | Номер зеркального документа (код) | ods./rusal/mirp_ral.zbelnr';
comment on column dds.transportation_service_invoice_partner_mirror_relation.mirror_accounting_document_fiscal_year is 'Финансовый год зеркального документа | Финансовый год зеркального документа | ods./rusal/mirp_ral.zgjahr';
comment on column dds.transportation_service_invoice_partner_mirror_relation.reference_operation_type_code is 'Ссылочная операция | Ссылочная операция | ods./rusal/mirr_ral.awtyp';
comment on column dds.transportation_service_invoice_partner_mirror_relation.reference_object_key is 'Ссылочный ключ | Ссылочный ключ | ods./rusal/mirr_ral.awkey';
comment on column dds.transportation_service_invoice_partner_mirror_relation.mirror_accounting_document_type_code is 'Вид зеркального документа (код) | Вид зеркального документа (код) | ods./rusal/mirp_ral.zblart';
comment on column dds.transportation_service_invoice_partner_mirror_relation.reverse_document_of_mirror_accounting_document_code is 'Номер документа сторно зеркального документа (код) | Номер документа сторно зеркального документа (код) | ods./rusal/mirp_ral.zstblg';
