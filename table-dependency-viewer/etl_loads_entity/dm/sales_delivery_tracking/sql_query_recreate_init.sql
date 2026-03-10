DROP TABLE IF EXISTS dm.sales_delivery_tracking CASCADE;

CREATE TABLE dm.sales_delivery_tracking (
	delivery_number_sales varchar(10) NULL,								-- SD.000002 "Продажная поставка"
	batch varchar(10) NULL,												-- SD.000004 "Партия"
	plant_producer_code varchar(4) NULL,								-- SD.000006 "Завод производитель (код)"
	plant_producer_name varchar(30) NULL,								-- SD.000007 "Завод"
	dt_shipment date NULL,												-- SD.000010 "Дата отгрузки"
	dt_arrival_by_railway date NULL,									-- SD.000011 "Дата прибытия по ЖД"
	dt_forwarder date NULL,												-- SD.000012 "Дата экспедитора"
	railcar varchar(20) NULL,											-- SD.000013 "Вагон"
	transport_bill varchar(35) NULL,									-- SD.000014 "Накладная"
	material_aggr_name varchar(70) NULL,								-- SD.000016 "Материал" 
	material_group_code varchar(9) NULL,								-- SD.000017 "Группа материалов" 
	dt_warehouse date NULL,												-- SD.000024 "Дата склада"
	transport_type_after_repackaging_code varchar(4) NULL,				-- SD.000027 "Тип ПС после перетарки"
	transport_railcar_type_name varchar(40) NULL,						-- SD.000029 "Тип вагона"
	nomination_in_russian_port_code_plan varchar(20) NULL,				-- SD.000030 "Номинация РФ (план)
	weight_gross numeric(13, 3) NULL,									-- SD.000031 "Вес брутто"
	weight_net numeric(13, 3) NULL,										-- SD.000032 "Вес нетто"
	weight_net_with_wirerod numeric(13, 3) NULL,						-- SD.000033 "Вес Н&K"
	station_current varchar(30) NULL,									-- SD.000034 "Текущая станция"
	station_destination varchar(30) NULL,								-- SD.000035 "Станция назначения"
	customer_for_reporting_name varchar(150) NULL,						-- SD.000037 "Покупатель"
	contract_name varchar(105) NULL, 									-- SD.000038 "Контракт"
	quota varchar(6) NULL,												-- SD.000039 "Квота (техническая)"
	bill_of_lading_number varchar(30) NULL,								-- SD.000041 "Номер коносамента"
	dt_bill_of_lading date NULL,										-- SD.000042 "Дата коносамента"
	bill_of_lading_route varchar(6) NULL,								-- SD.000043 "Маршрут коносамента"
	port_of_discharge_name varchar(30) NULL,							-- SD.000045 "Порт выгрузки" 
	nomination_actual varchar(20) NULL,									-- SD.000046 "Номинация"
	status_description varchar(25) NULL,								-- SD.000057 "Описание статуса"
	dimensions_unit varchar(20) NULL,									-- SD.000079 "Размер единицы готовой продукции"
	consignee_name varchar(120) NULL,									-- SD.000081 "Грузополучатель"
	end_user_name varchar(140) NULL,									-- SD.000097 "Потребитель"
	distance_remaining int8 NULL,										-- SD.000122 "Оставшееся расстояние"
	sales_order varchar(6) NULL,										-- SD.000123 "Заказ ЦК"
	dt_arrival_in_port_of_discharge_plan date NULL,						-- SD.000130 "Дата прибытия в порт выгрузки план"
	vessel_actual_name varchar(40) NULL,								-- SD.000138 "Судно факт"
	material_code varchar(18) NULL,										-- SD.000143 "Номер материала"
	customer_grade_name varchar(30) NULL,								-- SD.000144 "Марка клиента"
	grade_name varchar(30) NULL,										-- SD.000145 "Марка по спецификации"
	uni varchar(60) NULL,												-- SD.000151 "UNI"
	uni_in_shipment varchar(60) NULL,									-- SD.000152 "UNI в отгрузке"
	status_al2all varchar(50) NULL,										-- SD.000161 "Статус для портала AL2ALL"
	production_order varchar(30) NULL,									-- SD.000174 "Производственный заказ"
    material_shape_name_full varchar(30) NULL,							-- SD.000180 "Форма"
    material_name varchar(40) NULL,										-- SD.000200 "Наименование материала"
    region_of_destination_port_name varchar(20) NULL,					-- SD.000343 "Регион POD"
	business_location_name varchar(50) NULL,							-- SD.000492 "Статус в Supply chain (Business)"
  	forwarder_instruction_code varchar(10) NULL,						-- SD.000509 "Группа поручение"
	exporter_name varchar(35) NULL,										-- SD.000600 "Экспортер"
	country_of_customer_name varchar(15) NULL,							-- SD.000644 "Страна покупателя"
	port_of_loading_name varchar(30) NULL,								-- SD.000653 "Порт погрузки"
	dislocation_id varchar(10) NULL,									-- SD.000689 "ID_LEDISLOC"
	disclocation_border_cross_railroad_code varchar(7) NULL,			-- SD.000690 "Дорога сдачи (код)" 
	disclocation_border_cross_railroad_name varchar(50) NULL,			-- SD.000691 "Дорога сдачи"
	dislocation_railcar_operation_code varchar(2) NULL,					-- SD.000692 "Код операции" 
	dislocation_railcar_operation_name varchar(80) NULL,				-- SD.000693 "Операция" 
	dislocation_railcar_operation_short_name varchar(4) NULL,			-- SD.000694 "Краткое название операции" 
	dt_dislocation_railcar_operation date NULL,							-- SD.000695 "Дата операции" 
	dt_train_departure date NULL,										-- SD.000696 "Дата начала рейса" 
	dt_train_scheduled_arrival date NULL,	 							-- SD.000697 "Плановая дата прибытия по ЖД (с фактом)" 
	dt_estimated_arrival_to_russian_port date NULL,						-- SD.000698 "Прогнозная дата приемки в порту РФ"
	tnved_code varchar(17) NULL,										-- SD.000699 "Код товара ТНВЭД"
	shipment_type_name varchar(10) NULL,								-- SD.000702 "Тип вывоза из РФ"
	-----------------------------------------------
	dt_updated timestamp NULL,											-- Дата и время последнего изменения на источнике для 20-минутки
	-----------------------------------------------
    dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT FALSE
) 
WITH (
	appendonly = TRUE,
	orientation = COLUMN,
	compresstype = zstd,
	compresslevel = 3
)
DISTRIBUTED BY (
	delivery_number_sales,
	batch
);

 
COMMENT ON TABLE dm.sales_delivery_tracking IS 'Витрина "Вагоны по контрактам"';
-- SD.000002
COMMENT ON COLUMN dm.sales_delivery_tracking.delivery_number_sales is 'Продажная поставка | 
Если поставка разделена, то деленная поставка, если нет, то Исходная поставка. 
Если отгрузка через агента (РТД) - выводится поставка завода производителя | 
dm_calc.sd_sales_main_scm.delivery_number_sales';
-- SD.000004
COMMENT ON COLUMN dm.sales_delivery_tracking.batch IS 'Партия | Номер партии метала, формируется на заводе производителе, либо при закупке на операторе от внешних поставщиков. | dm_calc.sd_sales_main_scm.batch';
-- SD.000006
COMMENT ON COLUMN dm.sales_delivery_tracking.plant_producer_code IS 'Завод производитель (код) | Код завода производителя | dm_calc.sd_sales_main_scm.plant_producer_code';
-- SD.000007
COMMENT ON COLUMN dm.sales_delivery_tracking.plant_producer_name IS 'Завод | Название завода производителя | dm_calc.sd_sales_main_scm.plant_producer_name';
-- SD.000010
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_shipment IS 'Дата отгрузки | Дата отгрузки с завода производителя | dm_calc.sd_sales_main_scm.dt_shipment';
-- SD.000011
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_arrival_by_railway IS 'Дата прибытия по ЖД | Дата прибытия вагона по железной дороге на конечную станцию | dm_calc.sd_sales_main_scm.dt_arrival_by_railway';
-- SD.000012
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_forwarder IS 'Дата экспедитора | Дата, когда экспедитор принял груз на склад, и подготовил документы для экспорта - готовность к вывозу | dm_calc.sd_sales_main_scm.dt_forwarder';
-- SD.000013
COMMENT ON COLUMN dm.sales_delivery_tracking.railcar IS 'Вагон | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя | dm_calc.sd_sales_main_scm.railcar';
-- SD.000014
COMMENT ON COLUMN dm.sales_delivery_tracking.transport_bill IS 'Накладная | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя | dm_calc.sd_sales_main_scm.transport_bill';
-- SD.000016
COMMENT ON COLUMN dm.sales_delivery_tracking.material_aggr_name IS 'Материал | Код признака «Материал. Применяется для готовой алюминиевой продукции. 
Например, для кода материала APT0006ING0045, код признака Материл = COMMODITY | dm_calc.sd_sales_main_scm.material_aggr_name';
-- SD.000017
COMMENT ON COLUMN dm.sales_delivery_tracking.material_group_code IS 'Группа материалов | Группа материалов. 
Например, для кода материала APT0006ING0045, код Группа материалов = A02-Алюминий первичный АТЧ, раскисленный | dm_calc.sd_sales_main_scm.material_group_code';
-- SD.000024
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_warehouse IS 'Дата склада | Дата прибытия на склад порта, когда экспедитор принял груз на склад | dm_calc.sd_sales_main_scm.dt_warehouse';
-- SD.000027
COMMENT ON COLUMN dm.sales_delivery_tracking.transport_type_after_repackaging_code IS 'Тип ПС после перетарки | Тип транспортного средства после перегрузки металла на другое транспортное средство. 
Заполняется, только если была перетарка. Например, метал ехал сначала на ж\д, после перегрузили в морской контейнер | dm_calc.sd_sales_main_scm.transport_type_after_repackaging_code';
-- SD.000029
COMMENT ON COLUMN dm.sales_delivery_tracking.transport_railcar_type_name IS 'Тип вагона | Название типа вагона на текущий момент. 
Заполняется по следующему алгоритму:
= «Тип ПС после перетарки, если значение не пустое. Иначе = Тип вагона на заводе | dm_calc.sd_sales_main_scm.transport_railcar_type_name';
-- SD.000030
COMMENT ON COLUMN dm.sales_delivery_tracking.nomination_in_russian_port_code_plan IS 'Номинация РФ | Определеется по следующему алгоритму:
Для не Морских контейнеров («Тип вагона (код) не равному TL04 - Морской контейнер) берем Номинацию Инструкции ДСБ, если пусто, то берем Номинацию из таблицы распределения.
Для Морских контейнеров («Тип вагона (код) равен TL04 - Морской контейнер) берем номинацию из данных портового экспедитора (заполняем на основании загрузочного файла Excpected),
инфо получаем по следующим значениям:
Если не заполнено поле Контейнер после перетарки, т.е. не было перетарки, то инфо получаем по:  
• «Заказ ЦК в отгрузке
• «Вагон
• «Накладная
• «Дата отгрузки
Если заполнено поле Контейнер после перетарки, т.е. была перетарка, то инфо получаем по: 
• «Заказ ЦК в отгрузке
•«Контейнер после перетарки
Если получили пустые значения, то берем Номинацию Инструкции ДС, при условии, что у нее есть дата Sailed L.Port, если этой даты нет, то берем Номинацию из таблицы распределения | dm_calc.sd_sales_main_scm.nomination_in_russian_port_code_plan';
-- SD.000031
COMMENT ON COLUMN dm.sales_delivery_tracking.weight_gross IS 'Вес брутто | Вес брутто | dm_calc.sd_sales_main_scm.weight_gross';
-- SD.000032
COMMENT ON COLUMN dm.sales_delivery_tracking.weight_net IS 'Вес нетто | Вес нетто | dm_calc.sd_sales_main_scm.weight_net';
-- SD.000033
COMMENT ON COLUMN dm.sales_delivery_tracking.weight_net_with_wirerod IS 'Вес Н&K | Вес нетто + катанки | dm_calc.sd_sales_main_scm.weight_net_with_wirerod';
-- SD.000034
COMMENT ON COLUMN dm.sales_delivery_tracking.station_current IS 'Текущая станция | Заполняется только для ж\д отгрузки. 
Если «Дата прибытия по ЖД заполнено, то выводим «ПРИБЫЛ. 
Если вагон находится в движении, то указываем текущую станцию из Дислокации вагонов | dm_calc.sd_sales_main_scm.station_current';
-- SD.000035
COMMENT ON COLUMN dm.sales_delivery_tracking.station_destination IS 'Станция назначения | Конечная точка доставки по ж\д, инфо выводится из конечного узла Маршрута завода | dm_calc.sd_sales_main_scm.station_destination';
-- SD.000037
COMMENT ON COLUMN dm.sales_delivery_tracking.customer_for_reporting_name IS 'Наименование покупателя | Название покупателя из клиентского лота, если его нет, то Плановый покупатель из заявки под план производства | dm_calc.sd_sales_main_scm.customer_for_reporting_name';
-- SD.000038
COMMENT ON COLUMN dm.sales_delivery_tracking.contract_name IS 'Контракт | Номер контракта из клиентского лота, если его нет, то Плановый контракт из заявки под план производства | dm_calc.sd_sales_main_scm.contract_name';
-- SD.000039
COMMENT ON COLUMN dm.sales_delivery_tracking.quota IS 'Квота | Квота из клиентского лота, если его нет, то Квота из заявки под план производства | dm_calc.sd_sales_main_scm.quota';
-- SD.000041
COMMENT ON COLUMN dm.sales_delivery_tracking.bill_of_lading_number IS 'Номер коносамента | Номер коносамента из РФ, номер на бумажном носителе. 
Документ, который используют в водных перевозках. 
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения | dm_calc.sd_sales_main_scm.bill_of_lading_number';
-- SD.000042
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_bill_of_lading IS 'Дата коносамента | Дата коносамента из РФ. 
Документ, который используют в водных перевозках из российских портов. 
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения | dm_calc.sd_sales_main_scm.dt_bill_of_lading';
-- SD.000043
COMMENT ON COLUMN dm.sales_delivery_tracking.bill_of_lading_route IS 'Маршрут коносамента | Системный номер маршрута коносамента из РФ, который содерит в себе информацию о порте погрузки и порте выгрузки | dm_calc.sd_sales_main_scm.bill_of_lading_route';
-- SD.000046
COMMENT ON COLUMN dm.sales_delivery_tracking.nomination_actual IS 'Номинация | Номинация (номер документа) из коносамента из РФ, если пусто то это номер Номинации поручения. 
Номинация - это процесс назначения судна на выполнение определенного вида работ. 
Этот процесс происходит между клиентом и агентом, который занимается организацией перевозки грузов. 
Номинация сообщает владельцу или управляющей компании судна о предстоящих заданиях и условиях работы. 
В одну номинацию могут быть включены несколько коносаментов | dm_calc.sd_sales_main_scm.nomination_actual';
-- SD.000057
COMMENT ON COLUMN dm.sales_delivery_tracking.status_description IS 'Описание статуса | Описание значка статуса движения метала. 
Возможны следующие варианты:
• Возврат поставщику, определяется в случае если партию вернули поставщику (значение в поле «Причина деления = 9);
• Конечный порт, определяется в случае, если «Дата прибытия в порт выгрузки 2 <= дата построения отчета и «Дата прибытия в порт выгрузки 2 не пустая;
• В море 2, определяется в случае, если «Дата прибытия в порт выгрузки 2 > дата построения отчета или «Дата прибытия в порт выгрузки 2 пустая и «Группа коносамента в ин.порту не пустая;
• В иностранном порту, определяется в случае, если «Дата прибытия в порт выгрузки <= дата построения отчета и «Дата прибытия в порт выгрузки не пустая и «Признак перетарки в ин.порту = "X";
• В порту выгрузки, определяется в случае, если «Дата прибытия в порт выгрузки <= дата построения отчета и «Дата прибытия в порт выгрузки не пустая;
• В море, определяется в случае, если «Sailed L.Port <= дата построения отчета и «Sailed L.Port не пустая и «Дата прибытия в порт выгрузки > дата построения отчета или «Дата прибытия в порт выгрузки - пустая;
• В порту, определяется в случае, если «Дата прибытия по ЖД <= дата построения отчета и «Дата прибытия по ЖД не пустая и «Sailed L.Port > дата построения отчета или «Sailed L.Port - пусто;
• По ЖД, определяется в случае, если «Дата отгрузки <= дата построения отчета и «Дата отгрузки не пустая и «Дата прибытия по ЖД > дата построения отчета или «Дата прибытия по ЖД - пусто | dm_calc.sd_sales_main_scm.status_description';
-- SD.000079
COMMENT ON COLUMN dm.sales_delivery_tracking.dimensions_unit IS 'Размер единицы готовой продукции | Размер единицы готовой продукции, в зависимости от формы | dm_calc.sd_sales_main_scm.dimensions_unit';
-- SD.000081
COMMENT ON COLUMN dm.sales_delivery_tracking.consignee_name IS 'Грузополучатель | Название получателя материала по отгрузочному документу завода - ЖД накладная/CMR/ТТН. 
Тот, в адрес кого Завод производитель отгружает продукцию | dm_calc.sd_sales_main_scm.consignee_name';
-- SD.000097
COMMENT ON COLUMN dm.sales_delivery_tracking.end_user_name IS 'Потребитель | Имя контрагента, который является получателем металла. Потребитель может быть и Конечным потребителем | dm_calc.sd_sales_main_scm.end_user_name';
-- SD.000122
COMMENT ON COLUMN dm.sales_delivery_tracking.distance_remaining IS 'Оставшееся расстояние | Оставшееся расстояние до прибытия вагона на конечную станцию назначения. Источник информации Дислокация вагонов | dm_calc.sd_sales_main_scm.distance_remaining';
-- SD.000123
COMMENT ON COLUMN dm.sales_delivery_tracking.sales_order IS 'Заказ ЦК | Это системный номер заказа ЦК в отгрузке | dm_calc.sd_sales_main_scm.sales_order';
-- SD.000130
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_arrival_in_port_of_discharge_plan IS 'Дата прибытия в порт выгрузки план | Плановая дата прибытия в порт выгрузки по коносаменту РФ. 
Инфо получаем из:
1) Коносамента, поля ETA D. Port;
2) Еслив коносаменте ETA D. Port не заполнено, то из Номинации, указанной в этом коносаменте. 
	В номинацию инфо попадает при помощи: загрузочного файл Expected или автоматической загрузки инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
3) Если нет инфо в номинации, то дату берем из Данных портового экспедитора;
4) Если Коносамент еще не создан и «VF: Дата отправления из Порт погрузки не пустая, то Дата прибытия в порт выгрузки план = «VF: ETA в Порт выгрузки; 
5) Если Коносамент еще не создан и «VF: Дата прибытия в порт погрузки не пустая, то Дата прибытия в порт выгрузки план = «Expected BL + «VF: Время в пути до порта выгрузки;
6) Если «Тип вагона (код) = мосркой контейнер и по пунктам выше дату не нашли, то Дата прибытия в порт выгрузки план = «Дата Коносамента + «Норма морского транзита;
Иначе = «Booking cont + «Норма морского транзита;
Иначе = «Expected BL + «Норма морского транзита | dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge_plan';
-- SD.000138
COMMENT ON COLUMN dm.sales_delivery_tracking.vessel_actual_name IS 'Судно факт | Название судна из Номинации коносамента РФ, если его еще нет то из Поручения | dm_calc.sd_sales_main_scm.vessel_actual_name';
-- SD.000143
COMMENT ON COLUMN dm.sales_delivery_tracking.material_code IS 'Код материала | Системный номер материала. Например, APT0006ING0045. Аналог поля Номер материала | dm_calc.sd_sales_main_scm.material_code';
-- SD.000144
COMMENT ON COLUMN dm.sales_delivery_tracking.customer_grade_name IS 'Марка клиента | Код марки материала клиента. Например у материала AAX0024SLB0148, Марка клиента = A30 | dm_calc.sd_sales_main_scm.customer_grade_name';
-- SD.000145
COMMENT ON COLUMN dm.sales_delivery_tracking.grade_name IS 'Марка по спецификации | Наименование марки по спецификации. Например у материала AAX0024SLB0148, Марка по спецификации = 1050 | dm_calc.sd_sales_main_scm.grade_name';
-- SD.000151
COMMENT ON COLUMN dm.sales_delivery_tracking.uni IS 'UNI | Если Причина деления постави = "4- Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком "-";
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | dm_calc.sd_sales_main_scm.uni';
-- SD.000152
COMMENT ON COLUMN dm.sales_delivery_tracking.uni_in_shipment IS 'UNI в отгрузке | «Накладная и «Вагон разделенные знаком "-" | dm_calc.sd_sales_main_scm.uni_in_shipment';
-- SD.000161
COMMENT ON COLUMN dm.sales_delivery_tracking.status_al2all IS 'Статус для портала AL2ALL | Статус, который передаем на клиентский портал, набор статусов определется для «Сценарий маршрута. 
Возможные значения:
• Arrived at destination
• Called off
• Out for delivery
• On stock
• In warehouse
• Consumed
• At Consignment stock
• In transit to CS
• On vessel
• In the port
• Barging
• Ready for reloading
• In transit to WH
• In transit China
• Arrived to POL
• In rw transit Russia
• Plan
• Доставлено
• Брошено
• В транзите
• На станции
• Выдано распоряжение
• Отгружено
• План ЕАЛ | dm_calc.sd_sales_main_scm.status_al2all';
-- SD.000174
COMMENT ON COLUMN dm.sales_delivery_tracking.production_order IS 'Производственный заказ | Номер заказа, по которому завод выпускает производитель продукцию. 
Источник поступления данных транзакция ZSD2925M - Загрузка данных об отгрузке на трейдерах. Изначально производственные заказы вносятся в тразакции ZSD2882M - Регистрация заявок клиентов | dm_calc.sd_sales_main_scm.production_order';
-- SD.000180
COMMENT ON COLUMN dm.sales_delivery_tracking.material_shape_name_full IS 'Форма | Форма | dm_calc.sd_sales_main_scm.material_shape_full_name';
-- SD.000200
COMMENT ON COLUMN dm.sales_delivery_tracking.material_name IS 'Наименование материала | Наименование материала | .material_name';
-- SD.000343
COMMENT ON COLUMN dm.sales_delivery_tracking.region_of_destination_port_name IS 'Регион POD | Регион POD | dm_calc.sd_sales_main_scm.region_of_destination_port_name';
-- SD.000492
COMMENT ON COLUMN dm.sales_delivery_tracking.business_location_name IS 'Статус в Supply chain (Business) | Статус логистического этапа транспортировки/хранения | dm_calc.sd_sales_main_scm.business_location_name';
-- SD.000509
COMMENT ON COLUMN dm.sales_delivery_tracking.forwarder_instruction_code IS 'Группа поручение | Номер группы поручения | dm_calc.sd_sales_main_scm.forwarder_instruction_code';
-- SD.000600
COMMENT ON COLUMN dm.sales_delivery_tracking.exporter_name IS 'Экспортер | Экспортер | dm_calc.sd_sales_main_scm.exporter_name';
-- SD.000644
COMMENT ON COLUMN dm.sales_delivery_tracking.country_of_customer_name IS 'Страна покупателя | Наименование страны покупателя | dm_calc.sd_sales_main_scm.country_of_customer_name';
-- SD.000653
COMMENT ON COLUMN dm.sales_delivery_tracking.port_of_loading_name IS 'Порт погрузки | Системный код порта погрузки. Например, ZARUBINO | dm_calc.sd_sales_main_scm.port_of_loading_name';
-- SD.000689
COMMENT ON COLUMN dm.sales_delivery_tracking.dislocation_id IS 'ID_LEDISLOC | ID актуального события на пусти по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_id';
-- SD.000690
COMMENT ON COLUMN dm.sales_delivery_tracking.disclocation_border_cross_railroad_code IS 'Дорога сдачи (код) | Дорога сдачи Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.disclocation_border_cross_railroad_code';
-- SD.000691
COMMENT ON COLUMN dm.sales_delivery_tracking.disclocation_border_cross_railroad_name IS 'Дорога сдачи | Дорога сдачи Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.disclocation_border_cross_railroad_name';			
-- SD.000692
COMMENT ON COLUMN dm.sales_delivery_tracking.dislocation_railcar_operation_code IS 'Код операции | Код операции Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_railcar_operation_code';					
-- SD.000693
COMMENT ON COLUMN dm.sales_delivery_tracking.dislocation_railcar_operation_name IS 'Операции | Операции Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_railcar_operation_name';				
-- SD.000694
COMMENT ON COLUMN dm.sales_delivery_tracking.dislocation_railcar_operation_short_name IS 'Краткое название операции | Краткое название операции Актуальное событие на пути по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dislocation_railcar_operation_short_name';			
-- SD.000695
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_dislocation_railcar_operation IS 'Дата операции | Дата операции Актуальное событие на пусти по ЖД по данных СТЖ | dm_calc.sd_sales_main_scm.dt_dislocation_railcar_operation';							
-- SD.000696
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_train_departure IS 'Дата начала рейса | Плановая дата начала отправления по ЖД с фактом | dm_calc.sd_sales_main_scm.dt_train_departure';
-- SD.000697
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_train_scheduled_arrival IS 'Плановая дата прибытия по ЖД (с фактом) | Плановая дата прибытия по ЖД (с фактом) | dm_calc.sd_sales_main_scm.dt_train_scheduled_arrival';
-- SD.000698
COMMENT ON COLUMN dm.sales_delivery_tracking.dt_estimated_arrival_to_russian_port IS 'Прогнозная дата приемки в порту РФ | Дата прибытия по ЖД с сроком приемки | dm_calc.sd_sales_main_scm.dt_estimated_arrival_to_russian_port';
-- SD.000699
COMMENT ON COLUMN dm.sales_delivery_tracking.tnved_code IS 'Код товара ТНВЭД | Код товара ТНВЭД | dm_calc.sd_sales_main_scm.tnved_code';
-- SD.000702
COMMENT ON COLUMN dm.sales_delivery_tracking.shipment_type_name IS 'Тип вывоза из РФ | Тип вагона с учетом перетарки из распределения | dm_calc.sales_delivery_actual_part_2.shipment_type_name';
