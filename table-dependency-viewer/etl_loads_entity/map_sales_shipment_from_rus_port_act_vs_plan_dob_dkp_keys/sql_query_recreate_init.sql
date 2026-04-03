DROP TABLE IF EXISTS ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys;

CREATE TABLE ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys
(
	sales_market_code varchar(1) NULL,
	dt_shipment_from_russian_port_plan_yyyymm varchar(6) NULL,
	report_row_identification_code varchar(32) NULL,
	railcar_plan_number varchar(90) NULL,
	railcar_from_plant_code varchar(20) NULL,
	railcar_transshipped_code varchar(20) NULL,
	tsw_location_code varchar(10) NULL,
	transport_type_from_plant_code varchar(4) NULL,
	vessel_code varchar(40) NULL,
	dt_bill_of_lading_expected date NULL,
	dt_bill_of_lading_actual date NULL,
	port_of_discharge_code varchar(30) NULL,
	quota_period_yyyymm varchar(6) NULL,
	sales_order_code varchar(30) NULL,
	net_weight_with_wirerod_plan numeric(15, 3) NULL,
	dt_shipment_from_plant_actual date NULL,
	dt_shipment_from_plant_plan date NULL,
	dt_actual_shipment_from_russian_port date NULL,
	bill_of_lading_in_russian_port_code varchar(30) NULL,
	forwarder_comment varchar(140) NULL,
	forwarder_code varchar(10) NULL,
	sea_forwarder_code varchar(10) NULL,
	storage_duration_in_russian_port_in_calendar_days int8 NULL,
	dt_arrival_to_port_of_discharge_plan date NULL,
	dt_arrival_to_port_of_discharge_actual date NULL,
	transport_type_after_repackaging_code varchar(4) NULL,
	dt_etd_departure_from_russian_port_plan date NULL,
	dt_etd_departure_from_russian_port_actual date NULL,
	is_empty_dt_bill_of_lading_expected varchar(1) NULL,
	official_note_for_unplanned_shipment_number varchar(10) NULL,
	dt_official_note_for_unplanned_shipment date NULL,
	dt_saved_in_sap_system time NULL,
	nomination_actual_code varchar(20) NULL,
	metal_owner_code varchar(4) NULL,
	dt_arrival_by_railway date NULL,
	consignee_code varchar(10) NULL,
	is_loaded_and_shipped_in_multiple_month varchar(1) NULL,
	nomination_plan_code varchar(20) NULL,
	is_shipped_via_official_note varchar(1) NULL,
	sales_delivery_code varchar(10) NULL,
	batch_code varchar(10) NULL,
	transport_bill_code varchar(35) NULL,
	uni varchar(60) NULL,
	material_code varchar(18) NULL,
	is_tsw_location_code_changed varchar(30) NULL,
	tsw_location_name varchar(60) NULL,
	buyer_for_reporting_code varchar(10) NULL,
	buyer_for_reporting_name varchar(150) NULL,
	adjustment_difference_weight numeric(15, 3) NULL,
	actual_total_weight numeric(15, 3) NULL,
	shipment_plan_weight numeric(15, 3) NULL,
	shipment_left_plan_weight numeric(15, 3) NULL,
	comment_of_sales varchar(150) NULL,
	comment_of_transportation varchar(150) NULL,
	is_responsibility_of_sales varchar(30) NULL,
	is_responsibility_of_transportation varchar(30) NULL,
	forwarder_name varchar(150) NULL,
	sea_forwarder_name varchar(100) NULL,
	booked_for_shipment_weight numeric(15, 3) NULL,
	transport_type_actual_name varchar(20) NULL,
	transport_type_plan_code varchar(4) NULL,
	transport_type_plan_name varchar(20) NULL,
	report_date_actual_total_weight numeric(15, 3) NULL,
	report_date_plan_weight numeric(15, 3) NULL,
	material_name varchar(30) NULL,
	dt_bill_of_lading_plan date NULL,
	transport_type_after_repackaging_name varchar(20) NULL,
	business_location_name varchar(25) NULL,
	initial_appearance_version_code varchar(1) NULL,
	final_plan_weight numeric(15, 3) NULL,
	final_adjustment_plan_weight numeric(15, 3) NULL,
	final_unplanned_weight numeric(15, 3) NULL,
	dt_plan_version_saved date NULL,
	dt_plan_version_finalized date NULL,
	according_to_plan_shipped_actual_weight numeric(15, 3) NULL,
	according_to_adjusted_plan_shipped_actual_weight numeric(15, 3) NULL,
	dt_delivery_due_date date NULL,
	delivery_route_code varchar(6) NULL,
	shipped_actual_total_weight numeric(15, 3) NULL,
	according_to_adjusted_plan_shipped_actual_total_weight numeric(15, 3) NULL,
	shipped_unplanned_actual_weight numeric(15, 3) NULL,
	dt_official_note_created time NULL,
	official_note_created_by varchar(12) NULL,
	official_note_approval_status_code varchar(1) NULL,
	official_note_approval_status_name varchar(60) NULL,
	official_note_status_code varchar(4) NULL,
	official_note_nomination_code varchar(20) NULL,
	dt_official_note_bill_of_lading_expected date NULL,
	official_note_approved_by varchar(12) NULL,
	dt_official_note_approved date NULL,
	official_note_weight numeric(15, 3) NULL,
	plan_exceed_weight numeric(15, 3) NULL,
	official_note_declined_weight numeric(15, 3) NULL,
	plan_total_weight numeric(15, 3) NULL,
	period_transferred_weight numeric(15, 3) NULL,
	dt_report date null,
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT false
)
WITH (
    appendonly=true,
    orientation=column,
    compresstype=zstd,
    compresslevel=3
)
distributed by (sales_market_code, dt_shipment_from_russian_port_plan_yyyymm, report_row_identification_code);


comment on table ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys is 'Данные отчета План-факт для КХД';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."sales_market_code" is 'Рынок сбыта (код) | Рынок сбыта (код) | ZTSD2902M_L_KHD.MARKET';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_shipment_from_russian_port_plan_yyyymm" is 'Период планирования | Период планирования | ZTSD2902M_L_KHD.POPER';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."report_row_identification_code" is 'UUID (код) | UUID (код) | ZTSD2902M_L_KHD.GUID_KEY';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."railcar_plan_number" is 'Плановый вагон | Плановый вагон | ZTSD2902M_L_KHD.VAGON_PLAN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."railcar_from_plant_code" is 'Вагон (код) | Вагон (код) | ZTSD2902M_L_KHD.VAGON';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."railcar_transshipped_code" is 'Вагон перетарки (код) | Вагон перетарки (код) | ZTSD2902M_L_KHD.VAGON_PR';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."tsw_location_code" is 'Направление (код) (код) | Направление (код) (код) | ZTSD2902M_L_KHD.LOCID';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_type_from_plant_code" is 'ТС при отгрузке с завода (код) | ТС при отгрузке с завода (код) | ZTSD2902M_L_KHD.SDABW';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."vessel_code" is 'Название судна (код) | Название судна (код) | ZTSD2902M_L_KHD.VEH_TEXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_bill_of_lading_expected" is 'Expected BL | Expected BL | ZTSD2902M_L_KHD.ETAR';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_bill_of_lading_actual" is 'Дата коносамента | Дата коносамента | ZTSD2902M_L_KHD.KONOSDATE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."port_of_discharge_code" is 'Порт/Станция выгрузки (код) | Порт/Станция выгрузки (код) | ZTSD2902M_L_KHD.BEZEI_END';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."quota_period_yyyymm" is 'Период квоты | Период квоты | ZTSD2902M_L_KHD.QUOTA';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."sales_order_code" is '№ заказа (код) | № заказа (код) | ZTSD2902M_L_KHD.ZAKAZ_KL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."net_weight_with_wirerod_plan" is 'Изначальный вес | Изначальный вес | ZTSD2902M_L_KHD.VES_WAG_P';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_shipment_from_plant_actual" is 'Дата отгрузки | Дата отгрузки | ZTSD2902M_L_KHD.D_WERKS_OTGR';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_shipment_from_plant_plan" is 'Дата отгрузки плановая | Дата отгрузки плановая | ZTSD2902M_L_KHD.D_WERKS_OTGR_P';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_actual_shipment_from_russian_port" is 'Sailed L.Port | Sailed L.Port | ZTSD2902M_L_KHD.SAILED_L_PORT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."bill_of_lading_in_russian_port_code" is 'Номер коносамента (код) | Номер коносамента (код) | ZTSD2902M_L_KHD.KONOSAMENT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."forwarder_comment" is 'Комментарии экспедитора | Комментарии экспедитора | ZTSD2902M_L_KHD.COMMENTS';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."forwarder_code" is 'Экпедитор (код) (код) | Экпедитор (код) (код) | ZTSD2902M_L_KHD.EXPEDID';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."sea_forwarder_code" is 'Морская линия(код) (код) | Морская линия(код) (код) | ZTSD2902M_L_KHD.SEALINE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."storage_duration_in_russian_port_in_calendar_days" is 'Хранение | Хранение | ZTSD2902M_L_KHD.STORAGE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_arrival_to_port_of_discharge_plan" is 'Плановая дата поступления в порт | Плановая дата поступления в порт | ZTSD2902M_L_KHD.D_PORT_ARRIV_PL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_arrival_to_port_of_discharge_actual" is 'Дата поступления в порт | Дата поступления в порт | ZTSD2902M_L_KHD.D_PORT_ARRIV';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_type_after_repackaging_code" is 'Тип ПС после перетарки(код) (код) | Тип ПС после перетарки(код) (код) | ZTSD2902M_L_KHD.SDABW_PERETARKA';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_etd_departure_from_russian_port_plan" is 'ETD L.Port | ETD L.Port | ZTSD2902M_L_KHD.ETD_L_PORT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_etd_departure_from_russian_port_actual" is 'Дата Букинга | Дата Букинга | ZTSD2902M_L_KHD.BOOKING_DATE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."is_empty_dt_bill_of_lading_expected" is 'Без Expected BL | Без Expected BL | ZTSD2902M_L_KHD.WITHOUT_E_BL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_for_unplanned_shipment_number" is 'Служебная записка | Служебная записка | ZTSD2902M_L_KHD.OFFIC_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_official_note_for_unplanned_shipment" is 'Дата СЗ | Дата СЗ | ZTSD2902M_L_KHD.DATE_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_saved_in_sap_system" is 'Время сохранения записи | Время сохранения записи | ZTSD2902M_L_KHD.SAVTM';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."nomination_actual_code" is 'Номинация (код) | Номинация (код) | ZTSD2902M_L_KHD.NOMTK';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."metal_owner_code" is 'Принимающий завод (код) | Принимающий завод (код) | ZTSD2902M_L_KHD.WERKSP';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_arrival_by_railway" is 'Дата прибытия по ЖД | Дата прибытия по ЖД | ZTSD2902M_L_KHD.DATAPRZD';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."consignee_code" is 'Получатель материала (код) | Получатель материала (код) | ZTSD2902M_L_KHD.FIRMAPID';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."is_loaded_and_shipped_in_multiple_month" is 'Погрузка на стыке месяцев | Погрузка на стыке месяцев | ZTSD2902M_L_KHD.PNSM';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."nomination_plan_code" is 'Плановая номинация (код) | Плановая номинация (код) | ZTSD2902M_L_KHD.NOMTK_RA';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."is_shipped_via_official_note" is 'Добавлено по служебной записке | Добавлено по служебной записке | ZTSD2902M_L_KHD.ADD_BY_OM';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."sales_delivery_code" is 'Поставка (код) | Поставка (код) | ZTSD2902M_L_KHD.VBELN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."batch_code" is 'Партия (код) | Партия (код) | ZTSD2902M_L_KHD.CHARG';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_bill_code" is 'Накладная (код) | Накладная (код) | ZTSD2902M_L_KHD.NAKLADN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."uni" is 'UNI | UNI | ZTSD2902M_L_KHD.UNI';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."material_code" is 'Материал (код) | Материал (код) | ZTSD2902M_L_KHD.MATNR';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."is_tsw_location_code_changed" is 'Изменение направления (код) | Изменение направления (код) | ZTSD2902M_L_KHD.CLOCID';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."tsw_location_name" is 'Направление (текст) | Направление (текст) | ZTSD2902M_L_KHD.LOCNAM';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."buyer_for_reporting_code" is 'Покупатель(код) (код) | Покупатель(код) (код) | ZTSD2902M_L_KHD.BUYER';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."buyer_for_reporting_name" is 'Покупатель | Покупатель | ZTSD2902M_L_KHD.BUYER_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."adjustment_difference_weight" is 'Корректировка изначального веса | Корректировка изначального веса | ZTSD2902M_L_KHD.VES_WAG_P_CORR';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."actual_total_weight" is 'Текущий вес | Текущий вес | ZTSD2902M_L_KHD.VES_WAG_FIN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."shipment_plan_weight" is 'План/К вывозу | План/К вывозу | ZTSD2902M_L_KHD.DEV';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."shipment_left_plan_weight" is 'План/Факт вывоза | План/Факт вывоза | ZTSD2902M_L_KHD.DEV2';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."comment_of_sales" is 'Комментарии (ДСБ) | Комментарии (ДСБ) | ZTSD2902M_L_KHD.COMMENTS_SALES';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."comment_of_transportation" is 'Комментарии (ДТЛ) | Комментарии (ДТЛ) | ZTSD2902M_L_KHD.COMMENTS_DTL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."is_responsibility_of_sales" is 'Ответственность (ДСБ) | Ответственность (ДСБ) | ZTSD2902M_L_KHD.RESPONSIB_SALES';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."is_responsibility_of_transportation" is 'Ответственность (ДТЛ) | Ответственность (ДТЛ) | ZTSD2902M_L_KHD.RESPONSIB_DTL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."forwarder_name" is 'Экспедитор | Экспедитор | ZTSD2902M_L_KHD.EXPEDID_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."sea_forwarder_name" is 'Морская линия | Морская линия | ZTSD2902M_L_KHD.SEALINE_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."booked_for_shipment_weight" is 'Тоннаж к вывозу | Тоннаж к вывозу | ZTSD2902M_L_KHD.VES_WAG';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_type_actual_name" is 'Тип ТС факт | Тип ТС факт | ZTSD2902M_L_KHD.SDABW_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_type_plan_code" is 'Тип ТС план(код) (код) | Тип ТС план(код) (код) | ZTSD2902M_L_KHD.SDABW_PREV';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_type_plan_name" is 'Тип ТС план | Тип ТС план | ZTSD2902M_L_KHD.SDABW_PREV_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."report_date_actual_total_weight" is 'Фактический срез | Фактический срез | ZTSD2902M_L_KHD.VES_WAG_P_NEW';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."report_date_plan_weight" is 'Новый плановый вес | Новый плановый вес | ZTSD2902M_L_KHD.VES_WAG_PC_NEW';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."material_name" is 'Наименование материала | Наименование материала | ZTSD2902M_L_KHD.MATNR_NAME';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_bill_of_lading_plan" is 'Плановая дата коносамента | Плановая дата коносамента | ZTSD2902M_L_KHD.PLAN_BL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."transport_type_after_repackaging_name" is 'Тип ТС после перетарки | Тип ТС после перетарки | ZTSD2902M_L_KHD.SDABW_PERETARKA_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."business_location_name" is 'Описание статуса | Описание статуса | ZTSD2902M_L_KHD.STATUS_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."initial_appearance_version_code" is 'Срез данных (код) | Срез данных (код) | ZTSD2902M_L_KHD.CUT_PRIZN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."final_plan_weight" is 'Окончательный плановый вес | Окончательный плановый вес | ZTSD2902M_L_KHD.VES_WAG_PC';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."final_adjustment_plan_weight" is 'Корректировка окончательного веса | Корректировка окончательного веса | ZTSD2902M_L_KHD.VES_WAG_PC_CORR';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."final_unplanned_weight" is 'Окончательный внеплановый вес | Окончательный внеплановый вес | ZTSD2902M_L_KHD.VES_WAG_PC_FIN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_plan_version_saved" is 'Дата планового среза | Дата планового среза | ZTSD2902M_L_KHD.PLAN_DATE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_plan_version_finalized" is 'Дата корректировочного среза | Дата корректировочного среза | ZTSD2902M_L_KHD.CORR_DATE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."according_to_plan_shipped_actual_weight" is 'Фактический вывоз | Фактический вывоз | ZTSD2902M_L_KHD.VES_WAG_FACT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."according_to_adjusted_plan_shipped_actual_weight" is 'Фактический вывоз изначального веса | Фактический вывоз изначального веса | ZTSD2902M_L_KHD.VES_WAG_P_FACT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_delivery_due_date" is 'Поставки (С/По) | Поставки (С/По) | ZTSD2902M_L_KHD.LFDAT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."delivery_route_code" is 'Маршрут (код) | Маршрут (код) | ZTSD2902M_L_KHD.ROUTE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."shipped_actual_total_weight" is 'Фактический вывоз итого | Фактический вывоз итого | ZTSD2902M_L_KHD.VES_WAG_FACT_PC';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."according_to_adjusted_plan_shipped_actual_total_weight" is 'Фактический вывоз окончательного веса | Фактический вывоз окончательного веса | ZTSD2902M_L_KHD.VES_WAG_P_FACT_PC';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."shipped_unplanned_actual_weight" is 'Фактический вывоз по BL | Фактический вывоз по BL | ZTSD2902M_L_KHD.VES_WAG_PV_FACT_PC';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_official_note_created" is 'Время создания СЗ | Время создания СЗ | ZTSD2902M_L_KHD.TIME_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_created_by" is 'Автор СЗ | Автор СЗ | ZTSD2902M_L_KHD.USER_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_approval_status_code" is 'Статус согласования СЗ (код) (код) | Статус согласования СЗ (код) (код) | ZTSD2902M_L_KHD.STATUS_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_approval_status_name" is 'Статус согласования СЗ | Статус согласования СЗ | ZTSD2902M_L_KHD.STATUS_MEMO_TXT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_status_code" is 'Статус СЗ (код) | Статус СЗ (код) | ZTSD2902M_L_KHD.MEMO_STATUS';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_nomination_code" is 'Номинация по СЗ (код) | Номинация по СЗ (код) | ZTSD2902M_L_KHD.NOMTK_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_official_note_bill_of_lading_expected" is 'Expected BL по СЗ | Expected BL по СЗ | ZTSD2902M_L_KHD.ETAR_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_approved_by" is 'Автор решения | Автор решения | ZTSD2902M_L_KHD.APPROVEDBY';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_official_note_approved" is 'Дата согласования | Дата согласования | ZTSD2902M_L_KHD.APPROVALDATE';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_weight" is 'Вес по СЗ | Вес по СЗ | ZTSD2902M_L_KHD.MEMO_WEIGHT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."plan_exceed_weight" is 'Сверхлан | Сверхлан | ZTSD2902M_L_KHD.OVERPLAN';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."official_note_declined_weight" is 'Отклонено по СЗ | Отклонено по СЗ | ZTSD2902M_L_KHD.DECL_WEIGHT';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."plan_total_weight" is 'План (итого) | План (итого) | ZTSD2902M_L_KHD.PLAN_TOTAL';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."period_transferred_weight" is 'Удалено по СЗ | Удалено по СЗ | ZTSD2902M_L_KHD.DELETED_MEMO';
comment on column ods.map_sales_shipment_from_rus_port_act_vs_plan_dob_dkp_keys."dt_report" is 'Дата отчета | Дата отчета | ZTSD2902M_L_KHD.REPDATE';