drop table if exists dds.transportation_service_invoice_position;

create table dds.transportation_service_invoice_position (
	plant_code varchar(4) null,
	transportation_service_invoice_code varchar(10) null,
	transportation_service_invoice_position_code varchar(5) null,
	service_code varchar(18) null,
	transportation_service_invoice_position_object_code varchar(35) null,
	position_document_currency_vat_excluded_amount numeric(13, 2) null,
	position_document_currency_vat_amount numeric(13, 2) null,	
	document_currency_code varchar(5) null,
	adjustment_document_code varchar(10) null,
	funds_center_code varchar(16) null,
	etsng_code varchar(6) null,
	purchase_contract_code varchar(10) null,
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

comment on table dds.transportation_service_invoice_position is 'Акт на транспортировку (позиция)';
comment on column dds.transportation_service_invoice_position.plant_code is 'Завод (код) | Завод (код) | ods./rusal/perp_ral.werks';
comment on column dds.transportation_service_invoice_position.transportation_service_invoice_code is 'Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | ods./rusal/perp_ral.id';
comment on column dds.transportation_service_invoice_position.transportation_service_invoice_position_code is 'Позиция акта на транспортировку (код) | Позиция акта на транспортировку (код) | ods./rusal/perp_ral.pos';
comment on column dds.transportation_service_invoice_position.service_code is 'Услуга (код) | Услуга (код) | ods./rusal/perp_ral.srvpos';
comment on column dds.transportation_service_invoice_position.transportation_service_invoice_position_object_code is 'Номер документа или транспортного средства, на который внесена позиция. Например, номер накладной, коносамента, контейнера. | Номер документа или транспортного средства, на который внесена позиция. Например, номер накладной, коносамента, контейнера. | ods./rusal/perp_ral.nomd';
comment on column dds.transportation_service_invoice_position.position_document_currency_vat_excluded_amount is 'Сумма позиции акта на транспортировку без НДС в валюте документа | Сумма позиции акта на транспортировку без НДС в валюте документа | ods./rusal/perp_ral.sums';
comment on column dds.transportation_service_invoice_position.position_document_currency_vat_amount is 'Сумма НДС позиции акта на транспортировку в валюте документа | Сумма НДС позиции акта на транспортировку в валюте документа | ods./rusal/perp_ral.nds';
comment on column dds.transportation_service_invoice_position.document_currency_code is 'Валюта документа (код) | Валюта документа (код) | ods./rusal/perp_ral.waers';
comment on column dds.transportation_service_invoice_position.adjustment_document_code is 'Корректировочный номер акта на транспортировку (код) | Корректировочный номер акта на транспортировку (код) | ods./rusal/perp_ral.akt_id';
comment on column dds.transportation_service_invoice_position.funds_center_code is 'Подразделение финансового менеджмента (код) | Подразделение финансового менеджмента (код) | ods./rusal/perp_ral.fistl';
comment on column dds.transportation_service_invoice_position.etsng_code is 'ЕТСНГ (код) | ЕТСНГ (код) | ods./rusal/perp_ral.etsng';
comment on column dds.transportation_service_invoice_position.purchase_contract_code is 'Договор с перевозчиком (код) | Договор с перевозчиком (код) | ods./rusal/perp_ral.ebelny';
