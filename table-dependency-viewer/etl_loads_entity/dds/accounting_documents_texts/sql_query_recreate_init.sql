create TABLE if not exists dds.accounting_documents_texts
(
	unit_balance_code									varchar(4) not null,
	fiscal_year											numeric(4,0) not null,
	accounting_document_code							varchar(10) not null,
	language_code varchar(1) NOT NULL,
	document_text text NULL,
	consignee_code text NULL,
	consigner_code text NULL,
	agency_contract_code text NULL,
	agent_code text NULL,
	personal_account_or_subaccount_code text NULL,
	invoice_amount_text text NULL,
	"dttm_inserted" timestamp NOT NULL DEFAULT now(),
	"dttm_updated" timestamp NOT NULL DEFAULT now(),
	"job_name" varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	"deleted_flag" bool NOT NULL DEFAULT false
)
WITH (
 appendonly=true,
 orientation=column,
 compresstype=zstd,
 compresslevel=1
)
distributed by (unit_balance_code, fiscal_year, accounting_document_code);

comment on table dds.accounting_documents_texts is 'Финансовый документ. Дополнительные данные';
comment on column dds.accounting_documents_texts.unit_balance_code is 'Балансовая единица | Балансовая единица | ods.texts_from_sap_fm_read_text.text_key_identifier_code'; 			
comment on column dds.accounting_documents_texts.fiscal_year is 'Финансовый год | Финансовый год | ods.texts_from_sap_fm_read_text.text_key_identifier_code';
comment on column dds.accounting_documents_texts.language_code is 'Код языка | Код языка | ods.texts_from_sap_fm_read_text.language_code';
comment on column dds.accounting_documents_texts.accounting_document_code	 is 'Номер бухгалтерского документа | Номер бухгалтерского документа | ods.texts_from_sap_fm_read_text.text_key_identifier_code';
comment on column dds.accounting_documents_texts.consignee_code is 'Текст документа | Текст документа  | ods.texts_from_sap_fm_read_text.text_value: text_object_identifier_code = 0001';
comment on column dds.accounting_documents_texts.consignee_code is 'Код грузополучателя | Код грузополучателя | ods.texts_from_sap_fm_read_text.text_value:  text_object_identifier_code = S004';
comment on column dds.accounting_documents_texts.consigner_code is 'Код грузоотправителя | Код грузоотправителя | ods.texts_from_sap_fm_read_text.text_value:  text_object_identifier_code = S014 ';
comment on column dds.accounting_documents_texts.agency_contract_code is 'Агентский договор | Агентский договор | ods.texts_from_sap_fm_read_text.text_value:  text_object_identifier_code = S020';
comment on column dds.accounting_documents_texts.agent_code is 'Код агента | Код агента | ods.texts_from_sap_fm_read_text.text_value:  text_object_identifier_code = S030';
comment on column dds.accounting_documents_texts.personal_account_or_subaccount_code is '№ ЕЛС/код субсчета | № ЕЛС/код субсчета | ods.texts_from_sap_fm_read_text.text_value: S036';
comment on column dds.accounting_documents_texts.invoice_amount_text is 'Текст: Сумма по счету-фактуре | Текст: Сумма по счету-фактуре | ods.texts_from_sap_fm_read_text.text_value: S059';