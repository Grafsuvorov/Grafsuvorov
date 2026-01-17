DROP TABLE IF EXISTS dm.sales_scanned_documents_analysis cascade;

CREATE TABLE IF NOT EXISTS dm.sales_scanned_documents_analysis
(
delivery_number_initial varchar(30) NULL,
delivery_number_of_producer_plant varchar(30) NULL,
plant_producer_code varchar(12) NULL,
plant_producer_name varchar(90) NULL,
dt_shipment date NULL,
dt_shipment_actual date NULL,
railcar varchar(60) NULL,
transport_bill varchar(105) NULL,
quality_certificate_number varchar(60) NULL,
internal_compound_key_code varchar(16) NULL,
railcar_without_transport_bill_scan_quantity varchar(1) NULL,
railcar_without_certificate_scan_quantity varchar(1) NULL,
railcar_without_chemistry_scan_quantity varchar(1) NULL,
dttm_inserted timestamp NOT NULL DEFAULT now(),
dttm_updated timestamp NOT NULL DEFAULT now(),
job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
deleted_flag bool NOT NULL DEFAULT false
) WITH (appendonly=true, orientation=column, compresstype=zstd, compresslevel=3)
distributed by (delivery_number_initial);

comment on table dm.sales_scanned_documents_analysis is 'Консолидированный отчет по сканированию изображений документов и загрузке химсостава';
comment on column dm.sales_scanned_documents_analysis.delivery_number_initial is 'Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах | sd_sales_main_scm.delivery_number_initial SD.000001';
comment on column dm.sales_scanned_documents_analysis.delivery_number_of_producer_plant is 'Номер поставки завода производителя | Поставка завода производителя, по которой формируется цепочка продаж на заводе произвидителе | sd_sales_main_scm.delivery_number_of_producer_plant SD.000003';
comment on column dm.sales_scanned_documents_analysis.plant_producer_code is 'Завод производитель (код) | Код завода производителя | sd_sales_main_scm.plant_producer_code SD.000006';
comment on column dm.sales_scanned_documents_analysis.plant_producer_name is 'Завод | Название завода производителя | sd_sales_main_scm.plant_producer_name SD.000007';
comment on column dm.sales_scanned_documents_analysis.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | sd_sales_main_scm.dt_shipment SD.000010';
comment on column dm.sales_scanned_documents_analysis.dt_shipment_actual is 'Дата отгрузки из Shipdata | Дата отгрузки с завода производителя из Shipdata | sales_batch_delivery.dt_shipment SD.000976';
comment on column dm.sales_scanned_documents_analysis.railcar is 'Вагон | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя. | sd_sales_main_scm.railcar SD.000013';
comment on column dm.sales_scanned_documents_analysis.transport_bill is 'Накладная | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя | sd_sales_main_scm.transport_bill SD.000014';
comment on column dm.sales_scanned_documents_analysis.quality_certificate_number is 'Номер сертификата | Официальный документ, подтверждающий высокое качество продукции и соответствие установленным требованиям государственных стандартов и технических регламентов. | sd_sales_main_scm.quality_certificate_number SD.000109';
comment on column dm.sales_scanned_documents_analysis.internal_compound_key_code is 'Внутр. уникальный идентификатор | Внутренний уникальный идентификатор записи | sd_sales_main_scm.internal_compound_key_code SD.000721';
comment on column dm.sales_scanned_documents_analysis.railcar_without_transport_bill_scan_quantity is 'Вагоны без изображений накладных | Показывает количество вагонов у которых отсутствуют изображения (сканы) накладных. В SAP аналогичная рассылка по заводам, для того чтобы прикрепили. Изображения должны быть прикреплены в течение суток после отгрузки. | Расчетное поле SD.000887';
comment on column dm.sales_scanned_documents_analysis.railcar_without_certificate_scan_quantity is 'Вагоны без изображений сертификатов | Показывает количество вагонов у которых отсутствуют изображения (сканы) сертификатов. В SAP аналогичная рассылка по заводам, для того чтобы прикрепили. Изображения должны быть прикреплены в течение суток после отгрузки. | Расчетное поле SD.000888';
comment on column dm.sales_scanned_documents_analysis.railcar_without_chemistry_scan_quantity is 'Вагоны без химии | Показывает количество вагонов у которых отсутствуют данные химического состава. В SAP аналогичная рассылка по заводам, для того чтобы загрузили данные. Данные химического состава должны быть загружены в течение суток после отгрузки. | Расчетное поле SD.000889';
