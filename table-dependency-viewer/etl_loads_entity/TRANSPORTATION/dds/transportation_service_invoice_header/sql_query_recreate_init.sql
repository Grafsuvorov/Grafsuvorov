drop table if exists dds.transportation_service_invoice_header;

create table dds.transportation_service_invoice_header (
	plant_code varchar(4) null,
	transportation_service_invoice_code varchar(10) null,
	supplier_account_code varchar(15) null,
	transportation_service_invoice_number varchar(40) null,
	dt_transportation_service_invoice date null,
	payment_obstacle_code varchar(2) null,
	creditor_code varchar(10) null,
	creditor_agent_code varchar(10) null,
	second_creditor_agent_code varchar(10) null,
	creditor_final_code varchar(10) null,
	comment varchar(200) null,
	dt_due_payment_date date null,
	created_by varchar(12) null,
	updated_by varchar(12) null,
	contract_supervisor_code varchar(12) null,
	transportation_service_invoice_type_code varchar(2) null,
	document_currency_code varchar(5) null,
	prepayed_document_currency_amount numeric(13, 2) null,
	agent_scheme_type_code varchar(2) null,
	is_external_partner_code varchar(1) null,
	total_position_document_currency_vat_excluded_amount numeric(13, 2) null,
	total_subposition_document_currency_vat_excluded_amount numeric(13, 2) null,
	total_subposition_document_currency_vat_amount numeric(13, 2) null,
	unit_balance_code varchar(4) null,
	local_currency_code varchar(5) null,
	second_local_currency_code varchar(5) null,
	is_mirrored_adjustment_transportation_service_invoice bool null,
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

comment on table dds.transportation_service_invoice_header is 'Акт на транспортировку (заголовок)';
comment on column dds.transportation_service_invoice_header.plant_code is 'Завод (код) | Завод (код) | ods./rusal/perh_ral.werks';
comment on column dds.transportation_service_invoice_header.transportation_service_invoice_code is 'Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | Акт на транспортировку - документ на оплату или подтверждающий оплату (код) | ods./rusal/perh_ral.id';
comment on column dds.transportation_service_invoice_header.supplier_account_code is 'Лицевой счет для связи между документом на оплату и рамочным договором (код) | Лицевой счет для связи между документом на оплату и рамочным договором (код) | ods./rusal/perh_ral.noms';
comment on column dds.transportation_service_invoice_header.transportation_service_invoice_number is 'Номер документа на оплату "на бумаге" | Номер документа на оплату "на бумаге" | ods./rusal/perh_ral.nomp';
comment on column dds.transportation_service_invoice_header.dt_transportation_service_invoice is 'Дата документа на оплату | Дата документа на оплату | ods./rusal/perh_ral.bedat';
comment on column dds.transportation_service_invoice_header.payment_obstacle_code is 'Причина, по которой не происходит оплата (код) | Причина, по которой не происходит оплата (код) | ods./rusal/perh_ral.status_doc';
comment on column dds.transportation_service_invoice_header.creditor_code is 'Конечный получатель платежа (код) | Конечный получатель платежа (код) | ods./rusal/perh_ral.lifnr';
comment on column dds.transportation_service_invoice_header.creditor_agent_code is 'Конечный получатель платежа при агентской схеме (код) | Конечный получатель платежа при агентской схеме (код) | ods./rusal/perh_ral.zlifnr';
comment on column dds.transportation_service_invoice_header.second_creditor_agent_code is 'Конечный получатель платежа при двойной агентской схеме (код) | Конечный получатель платежа при двойной агентской схеме (код) | ods./rusal/perh_ral.lifnr_pr';
comment on column dds.transportation_service_invoice_header.creditor_final_code is 'Кредитор, непосредственно оказавший транспортные услуги (код) | Кредитор, непосредственно оказавший транспортные услуги (код) | ods./rusal/perh_ral.lifnr, ods./rusal/perh_ral.zlifnr, ods./rusal/perh_ral.lifnr_pr';
comment on column dds.transportation_service_invoice_header.comment is 'Комментарий | Комментарий | ods./rusal/perh_ral.comments';
comment on column dds.transportation_service_invoice_header.dt_due_payment_date is 'Дата, когда должна быть произведена оплата | Дата, когда должна быть произведена оплата | ods./rusal/perh_ral.duedat';
comment on column dds.transportation_service_invoice_header.created_by is 'Автор, создавший документ на оплату | Автор, создавший документ на оплату | ods./rusal/perh_ral.ernam';
comment on column dds.transportation_service_invoice_header.updated_by is 'Автор, изменивший документ на оплату | Автор, изменивший документ на оплату | ods./rusal/perh_ral.aenam';
comment on column dds.transportation_service_invoice_header.contract_supervisor_code is 'Куратор договора (код) | Куратор договора (код) | ods./rusal/perh_ral.uved_ernam';
comment on column dds.transportation_service_invoice_header.transportation_service_invoice_type_code is 'Вид документа на оплату (код) | Вид документа на оплату (код) | ods./rusal/perh_ral.type2';
comment on column dds.transportation_service_invoice_header.document_currency_code is 'Валюта документа (код) | Валюта документа (код) | ods./rusal/perh_ral.waers';
comment on column dds.transportation_service_invoice_header.prepayed_document_currency_amount is 'Сумма авансового ТАП | Сумма авансового ТАП | ods./rusal/perh_ral.tap_sum';
comment on column dds.transportation_service_invoice_header.agent_scheme_type_code is 'Тип взаимодействия с получателем оплаты (агентская схема) | Тип взаимодействия с получателем оплаты (агентская схема) | ods./rusal/zle112t2_ral.is_agent';
comment on column dds.transportation_service_invoice_header.is_external_partner_code is 'Внешний контур (X - внешний контур, иначе внутренний) (код) | Внешний контур (X - внешний контур, иначе внутренний) (код) | ods./rusal/zle112t2_ral.is_agent + dict_dds.counterparty.is_group_company_affiliated';
comment on column dds.transportation_service_invoice_header.total_position_document_currency_vat_excluded_amount is 'Сумма без НДС всех позиций акта в валюте документа | Сумма без НДС всех позиций акта в валюте документа | ods./rusal/perp_ral.sums';
comment on column dds.transportation_service_invoice_header.total_subposition_document_currency_vat_excluded_amount is 'Сумма без НДС всех подпозиций акта в валюте документа | Сумма без НДС всех подпозиций акта в валюте документа | ods./rusal/perw_ral.n_plata';
comment on column dds.transportation_service_invoice_header.total_subposition_document_currency_vat_amount is 'Сумма НДС всех подпозиций акта в валюте документа | Сумма НДС всех подпозиций акта в валюте документа | ods./rusal/perw_ral.nds';
comment on column dds.transportation_service_invoice_header.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | dict_dds.plant_and_subsidiary.unit_balance_code';
comment on column dds.transportation_service_invoice_header.local_currency_code is 'Внутренняя валюта (код) | Внутренняя валюта (код) | dict_dds.unit_balance.currency_code';
comment on column dds.transportation_service_invoice_header.second_local_currency_code is 'Вторая внутренняя валюта (код) | Вторая внутренняя валюта (код) | dict_dds.controlling_area.currency_code';
comment on column dds.transportation_service_invoice_header.is_mirrored_adjustment_transportation_service_invoice is 'Акт является корректировочным для зекрального акта (типа ZM) | Акт является корректировочным для зекрального акта (типа ZM) | См. алгоритм';
