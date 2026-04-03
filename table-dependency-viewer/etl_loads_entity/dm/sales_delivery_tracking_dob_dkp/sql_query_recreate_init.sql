drop table if exists dm.sales_delivery_tracking_dob_dkp cascade;
 
create table if not exists dm.sales_delivery_tracking_dob_dkp (
	delivery_number_sales varchar(30) null,								-- Продажная поставка SD.000002
	plant_producer_code varchar(12) null,								-- Завод производитель (код) SD.000006
	plant_producer_name varchar(90) null,								-- Завод SD.000007
	tsw_location_name varchar(180) null,								-- Направление SD.000009
	dt_shipment date null,												-- Дата отгрузки SD.000010
	dt_arrival_by_railway date null,									-- Дата прибытия по ЖД SD.000011
	dt_forwarder date null,												-- Дата экспедитора SD.000012
	railcar varchar(60) null,											-- Вагон SD.000013
	transport_bill varchar(105) null,									-- Накладная SD.000014
	material_aggr_name varchar(210) null,								-- Материал SD.000016
	material_group_code varchar(27) null,								-- Группа материалов SD.000017
	shipment_market_name varchar(120) null,								-- Рынок в отгрузке SD.000019
	dt_warehouse date null,												-- Дата склада SD.000024
	transport_railcar_type_code varchar(12) null,						-- Тип вагона (код) SD.000028
	transport_railcar_type_name varchar(120) null,						-- Тип вагона SD.000029
	weight_gross numeric(13, 3) null,									-- Вес брутто SD.000031
	weight_net numeric(13, 3) null,										-- Вес нетто SD.000032
	weight_net_with_wirerod numeric(13, 3) null,						-- Вес Н&K SD.000033
	station_current varchar(90) null,									-- Текущая станция SD.000034
	station_destination varchar(90) null,								-- Станция назначения SD.000035
	port_of_discharge_name varchar(90) null,							-- Порт выгрузки SD.000045
	status_description varchar(75) null,								-- Описание статуса SD.000057
	dt_arrival_in_port_of_discharge date null,							-- Дата прибытия в порт выгрузки SD.000059
	dimensions_unit varchar(60) null,									-- Размер единицы готовой продукции SD.000079
	container_after_repacking varchar(60) null,							-- Контейнер после перетарки SD.000119
	distance_remaining int8 null,										-- Оставшееся расстояние SD.000122
	sales_order varchar(18) null,										-- Заказ ЦК SD.000123
	dt_arrival_in_port_of_discharge_plan date null,						-- Дата прибытия в порт выгрузки план SD.000130
	material_code varchar(54) null,										-- Номер материала SD.000143
	grade_name varchar(90) null,										-- Марка по спецификации SD.000145
	uni varchar(180) null,												-- UNI SD.000151
	status_al2all varchar(150) null,									-- Статус для портала AL2ALL SD.000161
	material_shape_name_full varchar(90) null,							-- Форма SD.000180
	country_of_discharge_port_code varchar(9) null,						-- Страна POD (код) SD.000340
	country_of_discharge_port_name varchar(45) null,					-- Страна POD SD.000341
	business_location_name varchar(50) null,							-- Статус в Supply chain (Business) SD.000492
	port_of_loading_name varchar(30) null,								-- Порт погрузки SD.000653
	dt_arrival_to_port_of_discharge_yyyymm varchar(7) null,				-- Месяц прибытия в порт выгрузки SD.000736
	container_after_repacking_estimated_quantity numeric(13, 2) null,	-- Количество контейнеров SD.000917
	transportation_scheme_name varchar(45) null,						-- Схема перевозки SD.000918
	shipment_type_code varchar(2) null,									-- Вид отгрузки (код) LE SD.001023	
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
distributed by (delivery_number_sales);

comment on table dm.sales_delivery_tracking_dob_dkp is 'Продукция контейнерных перевозок';
comment on column dm.sales_delivery_tracking_dob_dkp.delivery_number_sales is 'Продажная поставка | Продажная поставка | dm_calc.sd_sales_main_scm.delivery_number_sales';
comment on column dm.sales_delivery_tracking_dob_dkp.plant_producer_code is 'Завод производитель (код) | Код завода производителя | dm_calc.sd_sales_main_scm.plant_producer_code';
comment on column dm.sales_delivery_tracking_dob_dkp.plant_producer_name is 'Завод | Название завода производителя | dm_calc.sd_sales_main_scm.plant_producer_name';
comment on column dm.sales_delivery_tracking_dob_dkp.tsw_location_name is 'Направление | Направление | dm_calc.sd_sales_main_scm.tsw_location_name';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_shipment is 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sd_sales_main_scm.dt_shipment';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_arrival_by_railway is 'Дата прибытия по ЖД | Дата прибытия вагона по железной дороге на конечную станцию | dm_calc.sd_sales_main_scm.dt_arrival_by_railway';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_forwarder is 'Дата экспедитора | Дата, когда экспедитор принял груз на склад, и подготовил документы для экспорта - готовность к вывозу | dm_calc.sd_sales_main_scm.dt_forwarder';
comment on column dm.sales_delivery_tracking_dob_dkp.railcar is 'Вагон | Вагон | dm_calc.sd_sales_main_scm.railcar';
comment on column dm.sales_delivery_tracking_dob_dkp.transport_bill is 'Накладная | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя | dm_calc.sd_sales_main_scm.transport_bill';
comment on column dm.sales_delivery_tracking_dob_dkp.material_aggr_name is 'Материал | Код признака «Материал». Применяется для готовой алюминиевой продукции. dm_calc.sd_sales_main_scm.material_aggr_name';
comment on column dm.sales_delivery_tracking_dob_dkp.material_group_code is 'Группа материалов | Группа материалов | dm_calc.sd_sales_main_scm.material_group_code';
comment on column dm.sales_delivery_tracking_dob_dkp.shipment_market_name is 'Рынок в отгрузке | Рынок в отгрузке | dm_calc.sd_sales_main_scm.shipment_market_name';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_warehouse is 'Дата склада | Дата прибытия на склад порта, когда экспедитор принял груз на склад | dm_calc.sd_sales_main_scm.dt_warehouse';
comment on column dm.sales_delivery_tracking_dob_dkp.transport_railcar_type_code is 'Тип вагона (код) | Код типа вагона на текущий момент | dm_calc.sd_sales_main_scm.transport_railcar_type_code';
comment on column dm.sales_delivery_tracking_dob_dkp.transport_railcar_type_name is 'Тип вагона | Название типа вагона на текущий момент | dm_calc.sd_sales_main_scm.transport_railcar_type_name';
comment on column dm.sales_delivery_tracking_dob_dkp.weight_gross is 'Вес брутто | Вес брутто | dm_calc.sd_sales_main_scm.weight_gross';
comment on column dm.sales_delivery_tracking_dob_dkp.weight_net is 'Вес нетто | Вес нетто | dm_calc.sd_sales_main_scm.weight_net';
comment on column dm.sales_delivery_tracking_dob_dkp.weight_net_with_wirerod is 'Вес Н&K | Вес Н&K | dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
comment on column dm.sales_delivery_tracking_dob_dkp.station_current is 'Текущая станция | Заполняется только для ж\д отгрузки | dm_calc.sd_sales_main_scm.station_current';
comment on column dm.sales_delivery_tracking_dob_dkp.station_destination is 'Станция назначения | Конечная точка доставки по ж\д, инфо выводится из конечного узла Маршрута завода | dm_calc.sd_sales_main_scm.station_destination';
comment on column dm.sales_delivery_tracking_dob_dkp.port_of_discharge_name is 'Порт выгрузки | Порт выгрузки | dm_calc.sd_sales_main_scm.port_of_discharge_name';
comment on column dm.sales_delivery_tracking_dob_dkp.status_description is 'Описание статуса | Описание значка статуса движения метала | dm_calc.sd_sales_main_scm.status_description';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_arrival_in_port_of_discharge is 'Дата прибытия в порт выгрузки | Дата прибытия в порт выгрузки | dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge';
comment on column dm.sales_delivery_tracking_dob_dkp.dimensions_unit is 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | dm_calc.sd_sales_main_scm.dimensions_unit';
comment on column dm.sales_delivery_tracking_dob_dkp.container_after_repacking is 'Контейнер после перетарки | Контейнер после перетарки | dm_calc.sd_sales_main_scm.container_after_repacking';
comment on column dm.sales_delivery_tracking_dob_dkp.distance_remaining is 'Оставшееся расстояние | Оставшееся расстояние до прибытия вагона на конечную станцию назначения | dm_calc.sd_sales_main_scm.distance_remaining';
comment on column dm.sales_delivery_tracking_dob_dkp.sales_order is 'Заказ ЦК | Это системный номер заказа ЦК в отгрузке | dm_calc.sd_sales_main_scm.sales_order';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_arrival_in_port_of_discharge_plan is 'Дата прибытия в порт выгрузки план | Плановая дата прибытия в порт выгрузки по коносаменту РФ. dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge_plan';
comment on column dm.sales_delivery_tracking_dob_dkp.material_code is 'Код материала | Системный номер материала | dm_calc.sd_sales_main_scm.material_code';
comment on column dm.sales_delivery_tracking_dob_dkp.grade_name is 'Марка по спецификации | Наименование марки по спецификации | dm_calc.sd_sales_main_scm.grade_name';
comment on column dm.sales_delivery_tracking_dob_dkp.uni is 'UNI | 
Если Причина деления постави = "4 - Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком "-"; 
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки; 
Иначе: Накладная + Вагон | 
dm_calc.sd_sales_main_scm.uni';
comment on column dm.sales_delivery_tracking_dob_dkp.status_al2all is 'Статус для портала AL2ALL | Статус, который передаем на клиентский портал, набор статусов определется для «Сценарий маршрута». | dm_calc.sd_sales_main_scm.status_al2all';
comment on column dm.sales_delivery_tracking_dob_dkp.material_shape_name_full is 'Форма | Форма | dm_calc.sd_sales_main_scm.material_shape_name_full';
comment on column dm.sales_delivery_tracking_dob_dkp.country_of_discharge_port_code is 'Страна POD (код) | Страна POD (код) | dm_calc.sd_sales_main_scm.country_of_discharge_port_code ';
comment on column dm.sales_delivery_tracking_dob_dkp.country_of_discharge_port_name is 'Страна POD | Страна POD | dm_calc.sd_sales_main_scm.country_of_discharge_port_name ';
comment on column dm.sales_delivery_tracking_dob_dkp.business_location_name is 'Статус в Supply chain (Business) | Статус в Supply chain (Business) | dm_calc.sd_sales_main_scm.business_location_name';
comment on column dm.sales_delivery_tracking_dob_dkp.port_of_loading_name is 'Порт погрузки | МР - место размещения. Системный код порта погрузки. | dm_calc.sd_sales_main_scm.port_of_loading_name';
comment on column dm.sales_delivery_tracking_dob_dkp.dt_arrival_to_port_of_discharge_yyyymm is 'Месяц прибытия в порт выгрузки | Месяц прибытия в порт выгрузки | dt_arrival_in_port_of_discharge ';
comment on column dm.sales_delivery_tracking_dob_dkp.container_after_repacking_estimated_quantity is 'Количество контейнеров | 
Количество контейнеров, согласно запросу ЛЕ
Если МК то = 1
Иначе вес поставки делить на 25, "количество" - с огружлением в большую сторону | 
dm_calc.sd_sales_main_scm ';
comment on column dm.sales_delivery_tracking_dob_dkp.transportation_scheme_name is 'Схема перевозки | 
1 = КР/ПВ/TL02/АВРТ с дальнейшей перетаркой в TL04
2 = Прямые КТК – TL04 или TL02 сразу от завода.
3 = КП – TL02 c видом отгрузки X5 (поезд) | dm_calc.sd_sales_main_scm/ods.map_delivery_document_attributes_keys_ral ';
comment on column dm.sales_delivery_tracking_dob_dkp.shipment_type_code is 'Вид отгрузки (код) LE | "Вид отгрузки" спецификация LE  | ods.map_delivery_document_attributes_keys_ral.shipment_type_code ';
