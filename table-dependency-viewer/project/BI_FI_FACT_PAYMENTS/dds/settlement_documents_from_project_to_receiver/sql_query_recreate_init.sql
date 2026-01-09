DROP TABLE IF EXISTS dds.settlement_documents_from_project_to_receiver cascade;
CREATE TABLE dds.settlement_documents_from_project_to_receiver
(
	settlement_document_code varchar(10) NULL,
	settlement_type_code varchar(3) NULL,
	object_code varchar(22) NULL,
	fiscal_year numeric(4,0) NULL,
	controlling_area_code varchar(4) NULL,
	assignment_type_code varchar(6) NULL,
	accounting_document_unit_balance_code varchar(4) NULL,
	sequence_number varchar(10) NULL,
	primary_assignment_sequence_number varchar(6) NULL,
	document_currency_amount numeric(15,2) NULL,
	document_currency_code varchar(5) NULL,
	second_local_currency_amount numeric(15,2) NULL,
	second_local_currency_code varchar(5) NULL,
	controlling_document_code varchar(10) NULL,
	controlling_document_position_line_item_code varchar(3) NULL,
	cost_element_code varchar(10) NULL,
	"dttm_inserted" timestamp NOT NULL DEFAULT now(),
	"dttm_updated" timestamp NOT NULL DEFAULT now(),
	"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
	appendonly=true,
	orientation=column,
	compresstype=zstd,
	compresslevel=3
)
distributed by (settlement_document_code, accounting_document_unit_balance_code);

comment on table  dds.settlement_documents_from_project_to_receiver is 'Документы распределения с проекта на получателя';
comment on column dds.settlement_documents_from_project_to_receiver.settlement_document_code is 'Номер документа расчета | Номер документа расчета | STG.AUAK.BELNR';
comment on column dds.settlement_documents_from_project_to_receiver.settlement_type_code is 'Вид расчета | Вид расчета | STG.AUAK.PERBZ';
comment on column dds.settlement_documents_from_project_to_receiver.object_code is 'Номер объекта на уровне позиции | Номер объекта на уровне позиции | STG.AUAK.OBJNR';
comment on column dds.settlement_documents_from_project_to_receiver.fiscal_year is 'Финансовый год | Финансовый год | STG.AUAK.GJAHR';
comment on column dds.settlement_documents_from_project_to_receiver.controlling_area_code is 'Контроллинговая единица | Контроллинговая единица | STG.AUAK.KOKRS';
comment on column dds.settlement_documents_from_project_to_receiver.assignment_type_code is 'Тип контировки | Тип контировки | STG.AUAA.EMTYP';
comment on column dds.settlement_documents_from_project_to_receiver.sequence_number is 'Текущий номер | Текущий номер | STG.AUAS.PLNFR';
comment on column dds.settlement_documents_from_project_to_receiver.primary_assignment_sequence_number is 'Порядковый номер первичной контировки | Порядковый номер первичной контировки | STG.AUAS.LFDNR';
comment on column dds.settlement_documents_from_project_to_receiver.document_currency_amount is 'Общее значение в валюте транзакции | Общее значение в валюте транзакции | STG.AUAS.WTGBTR';
comment on column dds.settlement_documents_from_project_to_receiver.document_currency_code is 'Валюта транзакции | Валюта транзакции | STG.AUAS.TWAER';
comment on column dds.settlement_documents_from_project_to_receiver.second_local_currency_amount is 'Общая сумма в валюте КЕ | Общая сумма в валюте КЕ | STG.AUAS.WKGBTR';
comment on column dds.settlement_documents_from_project_to_receiver.second_local_currency_code is 'Код второй внутренней валюты | Код второй внутренней валюты | DICT_STG.TKA01.WAERS';
comment on column dds.settlement_documents_from_project_to_receiver.controlling_document_code is 'Номер документа | Номер документа | STG.AUAS.KEY01';
comment on column dds.settlement_documents_from_project_to_receiver.controlling_document_position_line_item_code is 'Строка проводки | Строка проводки | STG.AUAS.KEY01';
comment on column dds.settlement_documents_from_project_to_receiver.cost_element_code is 'Вид затрат | Вид затрат | STG.AUAS.KEY01';
comment on column dds.settlement_documents_from_project_to_receiver.accounting_document_unit_balance_code is 'Балансовая единица документа FI (компания группы) | Балансовая единица документа FI (компания группы) | dict_dds.wbs_element_master_data_detail.wbs_element_unit_balance_code';