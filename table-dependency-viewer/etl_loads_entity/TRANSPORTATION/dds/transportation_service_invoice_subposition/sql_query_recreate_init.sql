drop table if exists dds.transportation_service_invoice_subposition;

create table dds.transportation_service_invoice_subposition (
	plant_code varchar(4) null,
	transportation_service_invoice_code varchar(10) null,
	transportation_service_invoice_position_code varchar(5) null,
	transportation_service_invoice_subposition_code varchar(5) null,
	subposition_document_currency_vat_excluded_amount numeric(13, 2) null,
	subposition_document_currency_vat_amount numeric(13, 2) null,
	subposition_document_currency_code varchar(5) null,
	purchase_contract_code varchar(10) null,
	delivery_code varchar(10) null,
	bill_of_lading_code varchar(30) null,
	dt_currency_translation date null,
	subposition_local_currency_vat_excluded_amount numeric(13, 2) null,
	local_currency_code varchar(5) null,
	subposition_second_local_currency_vat_excluded_amount numeric(13, 2) null,
	second_local_currency_code varchar(5) null,
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

comment on table dds.transportation_service_invoice_subposition is 'Акт на транспортировку (подпозиция)';
comment on column dds.transportation_service_invoice_subposition.plant_code is 'Завод (код) | Завод (код) | ods./rusal/perw_ral.werks';
comment on column dds.transportation_service_invoice_subposition.transportation_service_invoice_code is 'Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | ods./rusal/perw_ral.id';
comment on column dds.transportation_service_invoice_subposition.transportation_service_invoice_position_code is 'Позиция акта на транспортировку (код) | Позиция акта на транспортировку (код) | ods./rusal/perw_ral.pos';
comment on column dds.transportation_service_invoice_subposition.transportation_service_invoice_subposition_code is 'Подпозиция акта на транспортировку (код) | Подпозиция акта на транспортировку (код) | ods./rusal/perw_ral.posv';
comment on column dds.transportation_service_invoice_subposition.subposition_document_currency_vat_excluded_amount is 'Сумма без НДС в валюте документа | Сумма без НДС в валюте документа | ods./rusal/perw_ral.n_plata';
comment on column dds.transportation_service_invoice_subposition.subposition_document_currency_vat_amount is 'Сумма НДС в валюте документа | Сумма НДС в валюте документа | ods./rusal/perw_ral.nds';
comment on column dds.transportation_service_invoice_subposition.subposition_document_currency_code is 'Валюта документа (код) | Валюта документа (код) | ods./rusal/perw_ral.waers';
comment on column dds.transportation_service_invoice_subposition.purchase_contract_code is 'Номер стоимостного контракта (код) | Номер стоимостного контракта (код) | ods./rusal/perw_ral.ebeln';
comment on column dds.transportation_service_invoice_subposition.delivery_code is 'Поставка (код) | Поставка (код) | ods./rusal/perw_ral.vbeln';
comment on column dds.transportation_service_invoice_subposition.bill_of_lading_code is 'Коносамент, определенный на основе накладной (код) | Коносамент, определенный на основе накладной (код) | ods./rusal/perw_ral.bl';
comment on column dds.transportation_service_invoice_subposition.dt_currency_translation is 'Дата курса валют для пересчета | Дата курса валют для пересчета | ods./rusal/perw_ral.wwert';
comment on column dds.transportation_service_invoice_subposition.subposition_local_currency_vat_excluded_amount is 'Сумма без НДС во внутренней валюте | Сумма без НДС во внутренней валюте | ods./rusal/perw_ral.n_dmbtr';
comment on column dds.transportation_service_invoice_subposition.local_currency_code is 'Внутренняя валюта (код) | Внутренняя валюта (код) | ods./rusal/perw_ral.n_hwaer';
comment on column dds.transportation_service_invoice_subposition.subposition_second_local_currency_vat_excluded_amount is 'Сумма без НДС во второй внутренней валюте | Сумма без НДС во второй внутренней валюте | ods./rusal/perw_ral.n_dmbe2';
comment on column dds.transportation_service_invoice_subposition.second_local_currency_code is 'Вторая внутренняя валюта (код) | Вторая внутренняя валюта (код) | ods./rusal/perw_ral.n_hwae2';
