DROP TABLE IF EXISTS dm.sales_statement_report CASCADE;

CREATE TABLE IF NOT EXISTS dm.sales_statement_report (
	delivery_number_initial varchar NULL, 								-- SD.000001 "Исходная поставка"
	delivery_number_sales varchar NULL, 								-- SD.000002 "Продажная поставка"
	delivery_number_outbound varchar NULL,
	plant_producer_name varchar NULL, 									-- SD.000007 "Завод"
	port_of_loading_name varchar NULL, 									-- SD.000009 "Направление"
	dt_shipment date NULL, 												-- SD.000010 "Дата отгрузки"
	material_aggr_name varchar NULL, 									-- SD.000016 "Материал"
	material_group_code varchar NULL, 									-- SD.000017 "Группа материалов (код)"
	shipment_market_name varchar NULL, 									-- SD.000019 "Рынок в отгрузке"
	dt_warehouse date NULL, 											-- SD.000024 "Дата склада"
	transport_railcar_type_name varchar NULL, 							-- SD.000029 "Тип вагона"
	weight_net numeric(13, 3) NULL, 									-- SD.000032 "Вес нетто"
	customer_for_reporting_code varchar NULL, 							-- SD.000036 "Покупатель (код)"
	customer_for_reporting_name varchar NULL, 							-- SD.000037 "Покупатель"
	contract_name varchar NULL, 										-- SD.000038 "Контракт"
	bill_of_lading_number varchar NULL, 								-- SD.000041 "Номер коносамента"
	dt_bill_of_lading date NULL, 										-- SD.000042 "Дата коносамента"
	port_of_discharge_name varchar NULL, 								-- SD.000045 "Порт выгрузки"
	bill_of_lading_in_foreign_port varchar NULL, 						-- SD.000048 "Коносамент в ин.порту"
	dt_bill_of_lading_in_foreign_port date NULL, 						-- SD.000049 "Дата коносамента в ин.порту"
	dt_arrival_in_port_of_discharge date NULL, 							-- SD.000059 "Дата прибытия в порт выгрузки"
	delivery_basis varchar NULL, 										-- SD.000067 "Базис поставки"
	delivery_point_name varchar NULL, 									-- SD.000068 "Пункт доставки по инкотермс"
	sales_order varchar NULL, 											-- SD.000123 "Заказ ЦК"
	dt_arrival_in_port_of_discharge_plan date NULL, 					-- SD.000130 "Дата прибытия в порт выгрузки план"
	grade_name varchar NULL, 											-- SD.000145 "Марка по спецификации"
	uni varchar NULL, 													-- SD.000151 "UNI"
	dt_arrival_in_second_port_of_discharge_plan	date NULL, 				-- SD.000157 "Дата прибытия в порт выгрузки 2 план"
	end_user_name varchar NULL, 										-- SD.000164 "Конечный потребитель"
	invoice_provisional_number varchar NULL,							-- SD.000167 "Provisional invoice"
	dt_storage_start_in_foreign_port date NULL, 						-- SD.000175 "Дата начала хранения ин. склад"
	dt_storage_end_in_foreign_port date NULL, 							-- SD.000176 "Окончание хранения в ин. порту"
	dt_storage_start_in_second_foreign_warehouse date NULL,		 		-- SD.000177 "Начало хранения склад 2 "
	dt_storage_end_in_second_foreign_warehouse date NULL,		 		-- SD.000178 "Окончание хранение склад 2 "
	material_shape_name_full varchar NULL,								-- SD.000180 "Форма"
	delivery_region_name varchar NULL, 									-- SD.000338 "Регион поставки по контракту"
	country_of_discharge_port_name varchar NULL, 						-- SD.000341 "Страна POD"
	dt_prepared_for_realization date NULL, 								-- SD.000344 "Дата готовности к релизу"
	business_location_name varchar NULL, 								-- SD.000492 "Статус в Supply chain (Business)"
	delivery_country_in_contract_name varchar NULL, 					-- SD.000576 "Страна поставки по контракту"
	lot_code varchar NULL, 												-- SD.000580 "Номер лота"
	customer_for_scm_report_name varchar NULL, 							-- SD.000603 "Клиент для отчета Металл в Цепочке Поставок"
	vessel_and_voyage_actual_search_name varchar NULL,		 			-- SD.000608 "Судно / номер рейса (факт)"
	dt_invoice_provisional date NULL, 									-- SD.000620 "Дата инвойса"
	sales_team_name varchar NULL, 										-- SD.000651 "Сбытовая команда"
	dt_quota_yyyymm varchar NULL, 										-- SD.000687 "Квота"
	dt_realization date NULL, 											-- SD.000720 "Дата реализации"
	is_tolling_code varchar NULL, 										-- SD.000749 "Признак толлинг"
	warehouse_or_responsible_customer_for_storage_name varchar NULL, 	-- SD.000919 "General storage location"
	statement_data_group_code varchar NULL, 							-- SD.001244 "Блок данных (statement)"
	invoice_group_code varchar NULL,									-- SD.001245 "Группа инвойс (statement)"
	dt_report_yyyy varchar NULL, 										-- SD.001246 "Год отчета (statement)"
	purchase_invoice_code varchar NULL,									-- SD.001247 "Входящий счет (statement)"
	dt_purchase_invoice_yyyy varchar NULL, 								-- SD.001248 "Год входящего счета (statement)"
	net_weight numeric(13, 3) NULL, 									-- SD.001249 "Вес для statement"
	statement_invoice_code varchar NULL,								-- SD.001250 "Фактура для statement"
	statement_invoice_position_code varchar NULL,						-- SD.001251 "Позиция фактуры для statement"

	supplier_3rd_party_code	varchar NULL,								-- SD.001361 "Внешний контрагент"
	dt_payment date NULL,												-- SD.001362 "Дата оплаты"
	dt_payment_week	int NULL,										    -- SD.001363 "Неделя оплаты"
	dt_payment_mm varchar NULL,											-- SD.001364 "Месяц оплаты"
	dt_due_payment date NULL,										    -- SD.001365 "Срок оплаты"
	payment_terms_code varchar NULL,									-- SD.001366 "Условие платежа"
	payment_terms_days_quantity int NULL,							    -- SD.001367 "Условие платежа (дни)"
	payment_terms_document_name	 varchar NULL,							-- SD.001368 "Условие платежа (документ)"
	market_indicator_code varchar NULL,									-- SD.001369 "Рыночный индикатор (код)"
	market_indicator_name varchar NULL,									-- SD.001370 "Тип рыночного индикатора"
	metal_exchange_type_code varchar NULL,								-- SD.001371 "Тип биржи"
	usd_currency_vat_excluded_amound numeric(13, 2) NULL,				-- SD.001372 "Стоимость"
	document_currency_vat_excluded_amound numeric(13, 2) NULL,			-- SD.001373 "Стоимость в исходной валюте"
	usd_currency_vat_included_amound numeric(13, 2) NULL,				-- SD.001374 "Стоимость с НДС"
	invoice_realization_code varchar NULL,								-- SD.001375 "Фактура реализации"
	currency_exchange_rate numeric(13, 2) NULL,							-- SD.001376 "Валютный курс"
	direct_or_overseas_warehouse_delivery_name varchar NULL,			-- SD.001377 "Склад/прямая поставка"
	is_trader_name varchar NULL,										-- SD.001378 "Трейдер"
	prepayment_invoice_code varchar NULL,								-- SD.001379 "Номер предоплатного инвойса"
	sales_market_in_sales_request_code varchar NULL,					-- SD.001380 "Рынок из заказа"
	statement_calculated_weight	numeric(13, 2) NULL,					-- SD.001381 "Расчетный вес STATEMENT"

	-----------------------------------------------
	dttm_inserted timestamp NOT NULL DEFAULT now(),
	dttm_updated timestamp NOT NULL DEFAULT now(),
	job_name varchar(60) NOT NULL DEFAULT 'airflow'::character varying,
	deleted_flag bool NOT NULL DEFAULT FALSE
	) WITH (appendonly = TRUE,orientation = COLUMN,compresstype = zstd,compresslevel = 3)
DISTRIBUTED BY (delivery_number_sales);

COMMENT ON TABLE dm.sales_statement_report IS 'Витрина "Statement"';
COMMENT ON COLUMN dm.sales_statement_report.delivery_number_initial IS 'Исходная поставка | Исходная (первая) поставка, от которой начинается оформление цепочки продаж. Источник поступления данных транзакция ZSD2925M -Загрузка данных об отгрузке на трейдерах | dm_calc.sd_sales_main_scm.delivery_number_initial';
COMMENT ON COLUMN dm.sales_statement_report.delivery_number_sales IS 'Продажная поставка | Если поставка разделена, то деленная поставка, если нет, то Исходная поставка. Если отгрузка через агента (РТД) - выводится поставка завода производителя | dm_calc.sdsales_main_scm.delivery_number_sales';
 --SD.000007
COMMENT ON COLUMN dm.sales_statement_report.plant_producer_name IS 'Завод |
Название завода производителя |
dm_calc.sd_sales_main_scm.plant_producer_name';
--SD.000009
COMMENT ON COLUMN dm.sales_statement_report.port_of_loading_name IS 'Направление |
МР - место размещения. Название порта погрузки. Например, ZARUBINO |
dm_calc.sd_sales_main_scm.port_of_loading_name';
 --SD.000010
COMMENT ON COLUMN dm.sales_statement_report.dt_shipment IS 'Дата отгрузки |
Дата отгрузки с завода производителя |
dm_calc.sd_sales_main_scm.dt_shipment';
 --SD.000016
COMMENT ON COLUMN dm.sales_statement_report.material_aggr_name IS 'Материал |
Код признака «Материал». Применяется для готовой алюминиевой продукции. Например, для кода материала APT0006ING0045, код признака Материл = COMMODITY |
dm_calc.sd_sales_main_scm.material_aggr_name';
 --SD.000017
COMMENT ON COLUMN dm.sales_statement_report.material_group_code IS 'Группа материалов (код) |
Группа материалов. Например, для кода материала APT0006ING0045, код Группа материалов = A02-Алюминий первичный АТЧ, раскисленный |
dm_calc.sd_sales_main_scm.material_group_code';
 --SD.000019
COMMENT ON COLUMN dm.sales_statement_report.shipment_market_name IS 'Рынок в отгрузке |
Название рынка сбыта, к которому относится страна потребителя (внутренний, СНГ, Экспорт, Кубал) |
dm_calc.sd_sales_main_scm.shipment_market_name';
--SD.000024
COMMENT ON COLUMN dm.sales_statement_report.dt_warehouse IS 'Дата склада |
WH - warehouse. Дата прибытия на склад порта, когда экспедитор принял груз на склад |
dm_calc.sd_sales_main_scm.dt_warehouse';
--SD.000029
COMMENT ON COLUMN dm.sales_statement_report.transport_railcar_type_name IS 'Тип вагона |
Название типа вагона на текущий момент. Заполняется по следующему алгоритму:
= «Тип ПС после перетарки», если значение не пустое. Иначе = Тип вагона на заводе |
dm_calc.sd_sales_main_scm.transport_railcar_type_name';
 --SD.000032
COMMENT ON COLUMN dm.sales_statement_report.weight_net IS 'Вес нетто |
Вес нетто |
dm_calc.sd_sales_main_scm.weight_net';
 --SD.000036
COMMENT ON COLUMN dm.sales_statement_report.customer_for_reporting_code IS 'Покупатель (код) |
Системный код покупателя из клиентского лота, если его нет то Плановый покупатель из заявки под план производства |
dm_calc.sd_sales_main_scm.customer_for_reporting_code';
 --SD.000037
COMMENT ON COLUMN dm.sales_statement_report.customer_for_reporting_name IS 'Покупатель |
Название покупателя из клиентского лота, если его нет, то Плановый покупатель из заявки под план производства |
dm_calc.sd_sales_main_scm.customer_for_reporting_name';
 --SD.000038
COMMENT ON COLUMN dm.sales_statement_report.contract_name IS 'Контракт |
Номер контракта из клиентского лота, если его нет, то Плановый контракт из заявки под план производства |
dm_calc.sd_sales_main_scm.contract_name';
 --SD.000041
COMMENT ON COLUMN dm.sales_statement_report.bill_of_lading_number IS 'Номер коносамента |
Номер коносамента из РФ, номер на бумажном носителе. Документ, который используют в водных перевозках.
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения |
dm_calc.sd_sales_main_scm.bill_of_lading_number';
 --SD.000042
COMMENT ON COLUMN dm.sales_statement_report.dt_bill_of_lading IS 'Дата коносамента |
Дата коносамента из РФ. Документ, который используют в водных перевозках из российских портов.
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения |
dm_calc.sd_sales_main_scm.dt_bill_of_lading';
 --SD.000045
COMMENT ON COLUMN dm.sales_statement_report.port_of_discharge_name IS 'Порт выгрузки |
Порт выгрузки (Конечный узел доставки) из Маршрута коносамента из РФ. Например, BUSAN |
dm_calc.sd_sales_main_scm.port_of_discharge_name';
 --SD.000048
COMMENT ON COLUMN dm.sales_statement_report.bill_of_lading_in_foreign_port IS 'Коносамент в ин.порту |
Номер коносамента в ин. порту, номер на бумажном носителе. Документ, который используют в водных перевозках из иностранных портов.
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения |
dm_calc.sd_sales_main_scm.bill_of_lading_in_foreign_port';
 --SD.000049
COMMENT ON COLUMN dm.sales_statement_report.dt_bill_of_lading_in_foreign_port IS 'Дата коносамента в ин.порту |
Дата коносамента в ин. порту, документ, который используют в водных перевозках из иностранных портов.
Он содержит полную информацию о грузе и доказывает, что перевозчик принял на себя ответственность доставить его в порт назначения |
dm_calc.sd_sales_main_scm.dt_bill_of_lading_in_foreign_port';
--SD.000059
COMMENT ON COLUMN dm.sales_statement_report.dt_arrival_in_port_of_discharge IS 'Дата прибытия в порт выгрузки |
POD - port of discharge.
Дата прибытия в порт выгрузки из коносамента. Дата из Коносамента, поля Arrived D.Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder |
dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge';
--SD.000067
COMMENT ON COLUMN dm.sales_statement_report.delivery_basis IS 'Базис поставки |
Базис поставки (Инкотермс 1), это правило поставки Инкотермс. Базис обозначается тремя латинскими буквами, например EXW, CIP, DAP и пр. Инфо берем из клиентского лота, ели его нет то из заявки под план производства |
dm_calc.sd_sales_main_scm.delivery_basis';
--SD.000068
COMMENT ON COLUMN dm.sales_statement_report.delivery_point_name IS 'Пункт доставки по инкотермс |
Пункт доставки по инкотермс (Инкотермс 2), это место передачи груза, это может быть город, аэропорт, морской либо речной порт. Инфо берем из клиентского лота, ели его нет то из заявки под план производства |
dm_calc.sd_sales_main_scm.delivery_point_name';
--SD.000123
COMMENT ON COLUMN dm.sales_statement_report.sales_order IS 'Заказ ЦК |
Это системный номер заказаЦК в отгрузке |
dm_calc.sd_sales_main_scm.sales_order';
--SD.000130
COMMENT ON COLUMN dm.sales_statement_report.dt_arrival_in_port_of_discharge_plan IS 'Дата прибытия в порт выгрузки план |
Плановая дата прибытия в порт выгрузки по коносаменту РФ. Инфо получаем из:
1) Коносамента, поля ETA D. Port;
2) Еслив коносаменте ETA D. Port не заполнено, то из Номинации, указанной в этом коносаменте. В номинацию инфо попадает при помощи: загрузочного файл Expected или автоматической загрузки инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder.
3) Если нет инфо в номинации, то дату берем из Данных портового экспедитора;
4) Если Коносамент еще не создан и «VF: Дата отправления из Порт погрузки» не пустая, то Дата прибытия в порт выгрузки план = «VF: ETA в Порт выгрузки»;
5) Если Коносамент еще не создан и «VF: Дата прибытия в порт погрузки» не пустая, то Дата прибытия в порт выгрузки план = «Expected BL» + «VF: Время в пути до порта выгрузки»;
6) Если «Тип вагона (код)» = мосркой контейнер и по пунктам выше дату не нашли, то Дата прибытия в порт выгрузки план= «Дата Коносамента» + «Норма морского транзита»;
Иначе= «Booking cont» + «Норма морского транзита»;
Иначе= «Expected BL» + «Норма морского транзита»; |
dm_calc.sd_sales_main_scm.dt_arrival_in_port_of_discharge_plan';
 --SD.000145
COMMENT ON COLUMN dm.sales_statement_report.grade_name IS 'Марка по спецификации |
Наименование марки по спецификации. Например у материала AAX0024SLB0148, Марка по спецификации= 1050 |
dm_calc.sd_sales_main_scm.grade_name';
--SD.000151
COMMENT ON COLUMN dm.sales_statement_report.uni IS 'UNI |
Если Причина деления постави = "4- Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон |
dm_calc.sd_sales_main_scm.uni';
--SD.000157
COMMENT ON COLUMN dm.sales_statement_report.dt_arrival_in_second_port_of_discharge_plan IS 'Дата прибытия в порт выгрузки 2 план |
Плановая дата прибытия в порт выгрузки из коносамента в ин. порту. Дата из Коносамента в ин. порту, поля ETA D. Port, если пусто, то из Номинации, указанной в этом коносаменте:
1) Ввод инфо руками в Коносамент;
2) Загрузочный файл Expected;
3) Автоматическая загрузка инфо от Vessel Finder и Searates, причем данные полученные от Searates являются в приоритете и не перезаписываются инфой от Vessel Finder |
dm_calc.sd_sales_main_scm.dt_arrival_in_second_port_of_discharge_plan';
 --SD.000164
COMMENT ON COLUMN dm.sales_statement_report.end_user_name IS 'Конечный потребитель |
Имя контрагента, который является потребителем металла, т.е. будет использовальзовать метал для производства своей продукции, т.е. для собственных нужд.
В одной сделке Потребитель и Конечный потребитель могут быть разные юр.лица, а может быть одно |
dm_calc.sd_sales_main_scm.end_user_name';
 --SD.000167
COMMENT ON COLUMN dm.sales_statement_report.invoice_provisional_number IS 'Provisional invoice |
Инвойс (счет клиенту), он может быть предварительным или окончательным. Предварительный - когда указывают цену, в которой ещё не уверены |
dm_calc.sd_sales_main_scm.invoice_provisional_number';
 --SD.000175
COMMENT ON COLUMN dm.sales_statement_report.dt_storage_start_in_foreign_port IS 'Дата начала хранения ин. склад |
Дата начала хранения металла на удаленном складе, после поступления груза в ин. порт из РФ |
dm_calc.sd_sales_main_scm.dt_storage_start_in_foreign_port';
 --SD.000176
COMMENT ON COLUMN dm.sales_statement_report.dt_storage_end_in_foreign_port IS 'Окончание хранения в ин. порту |
Дата окончания хранения металла на удаленном складе, после поступления груза в ин. порт из РФ |
dm_calc.sd_sales_main_scm.dt_storage_end_in_foreign_port';
 --SD.000177
COMMENT ON COLUMN dm.sales_statement_report.dt_storage_start_in_second_foreign_warehouse IS 'Начало хранения склад 2 |
Дата начала хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт |
dm_calc.sd_sales_main_scm.dt_storage_start_in_second_foreign_warehouse';
 --SD.000178
COMMENT ON COLUMN dm.sales_statement_report.dt_storage_end_in_second_foreign_warehouse IS 'Окончание хранение склад 2 |
Дата окончания хранения металла на удаленном складе, после поступления груза из одного ин. порт в другой ин. порт |
dm_calc.sd_sales_main_scm.dt_storage_end_in_second_foreign_warehouse';
 --SD.000180
COMMENT ON COLUMN dm.sales_statement_report.material_shape_name_full IS 'Форма |
Форма |
dm_calc.sd_sales_main_scm.material_shape_name_full';
 --SD.000338
COMMENT ON COLUMN dm.sales_statement_report.delivery_region_name IS 'Регион поставки по контракту |
Регион поставки по контракту |
dm_calc.sd_sales_main_scm.delivery_region_name';
 --SD.000341
COMMENT ON COLUMN dm.sales_statement_report.country_of_discharge_port_name IS 'Страна POD |
Страна POD |
dm_calc.sd_sales_main_scm.country_of_discharge_port_name';
 --SD.000344
COMMENT ON COLUMN dm.sales_statement_report.dt_prepared_for_realization IS 'Дата готовности к релизу |
Дата готовности к релизу |
dm_calc.sd_sales_main_scm.dt_prepared_for_realization';
 --SD.000492
COMMENT ON COLUMN dm.sales_statement_report.business_location_name IS 'Статус в Supply chain (Business) |
Статус логистического этапа транспортировки/хранения |
dm_calc.sd_sales_main_scm.business_location_sap_precalc_name';
 --SD.000576
COMMENT ON COLUMN dm.sales_statement_report.delivery_country_in_contract_name IS 'Страна поставки по контракту |
Страна поставки по контракту |
dm_calc.sd_sales_main_scm.delivery_country_in_contract_name';
 --SD.000580
COMMENT ON COLUMN dm.sales_statement_report.lot_code IS 'Номер лота |
номер лота |
dm_calc.sd_sales_main_scm.lot_code';
--SD.000603
COMMENT ON COLUMN dm.sales_statement_report.customer_for_scm_report_name IS 'Клиент для отчета Металл в Цепочке Поставок |
Клиент для отчета Металл в Цепочке ПоставокЕсли Конечный потребитель (код) SD.000163 = параметру KUNNRUNS программы /RUSAL/SD2921M_4, то = «UNSOLD»;
Иначе
Определяем рамочный контракт = VBAK-ZUONR по VBAK-VBELN = Контракт в лоте (код) SD.000062
Определяем вид контракта = VBKD-BSARK по VBKD-VBELN = Рамочный контакт
Считать виды контрактов залога и удаленного склада – параметры BSARK_WH, BSARKPWH, BSARK_ZL программы /RUSAL/SD2902M
Если вид контракта находится среди значений этих параметров или «Контракт в лоте (код)» SD.000062 = «пусто», то «Клиент для отчета Металл в Цепочке Поставок» = «Плановый покупатель» SD.000602
Иначе – «Клиент для отчета Металл в Цепочке Поставок» = KNA1- NAME1 + NAME2 + NAME3 + NAME4 по KNA1-KUNNR = «Покупатель в лоте» SD.000064
"Если Конечный потребитель (код) SD.000163 = параметру KUNNRUNS программы /RUSAL/SD2921M_4, то = «UNSOLD»;
Иначе
Определяем рамочный контракт = VBAK-ZUONR по VBAK-VBELN = Контракт в лоте (код) SD.000062
Определяем вид контракта = VBKD-BSARK по VBKD-VBELN = Рамочный контакт
Считать виды контрактов залога и удаленного склада – параметры BSARK_WH, BSARKPWH, BSARK_ZL программы /RUSAL/SD2902M
Если вид контракта находится среди значений этих параметров или «Контракт в лоте (код)» SD.000062 = «пусто», то «Клиент для отчета Металл в Цепочке Поставок» = «Плановый покупатель» SD.000602
Иначе – «Клиент для отчета Металл в Цепочке Поставок» = KNA1- NAME1 + NAME2 + NAME3 + NAME4 по KNA1-KUNNR = «Покупатель в лоте» SD.000064
Если «Клиент для отчета Металл в Цепочке Поставок» не определен (NULL), то принудительно проставить значение  "undefined".
Для витрины Витрина  "Отчет по стокам (плановый и реализованный металл)" и витрины  "Отчет по стокам (плановый и реализованный металл) " значение из инетграционной таблицы если  "Признак План/Факт " SD.000159 =  "P
По ключу ZMK_TRACK_EXP02 - BUYER_TXT
Если «Клиент для отчета Металл в Цепочке Поставок» не определен (NULL), то принудительно проставить значение"
Для данных СГП:
KNA1- NAME1 + NAME2 + NAME3 + NAME4 по KNA1-KUNNR = «Клиент для отчета Металл в Цепочке Поставок (код)» SD.000771"
Для витрины Витрина  "Отчет по стокам (плановый и реализованный металл) " и витрины  "Отчет по стокам (плановый и реализованный металл) " значение из инетграционной таблицы если  "Признак План/Факт " SD.000159 =  "P
По ключу ZMK_TRACK_EXP02 - BUYER_TXT
Для данных СГП:
KNA1- NAME1 + NAME2 + NAME3 + NAME4 по KNA1-KUNNR = «Клиент для отчета Металл в Цепочке Поставок (код)» SD.000771 |
Расчётное';
 --SD.000608
COMMENT ON COLUMN dm.sales_statement_report.vessel_and_voyage_actual_search_name IS 'Судно / номер рейса (факт) |
Судно / номер рейса (факт) |
dm_calc.sd_sales_main_scm.vessel_and_voyage_actual_search_name';
 --SD.000620
COMMENT ON COLUMN dm.sales_statement_report.dt_invoice_provisional IS 'Дата инвойса |
Дата предварительного инвойса |
dm_calc.sd_sales_main_scm.dt_invoice_provisional';
 --SD.000651
COMMENT ON COLUMN dm.sales_statement_report.sales_team_name IS 'Сбытовая команда |
Сбытовая команда |
dm_calc.sd_sales_main_scm.sales_team_name';
--SD.000687
COMMENT ON COLUMN dm.sales_statement_report.dt_quota_yyyymm IS 'Квота |
Согласованный формат Квота для Детальных таблиц.
Смысл поля:
Квота из клиентского лота, если его нет, то Квота из заявки под план производства |
dm_calc.sd_sales_main_scm.dt_quota_yyyymm';
--SD.000720
COMMENT ON COLUMN dm.sales_statement_report.dt_realization IS 'Дата реализации |
Дата реализации |
dm_calc.sd_sales_main_scm.dt_realization';
--SD.000749
COMMENT ON COLUMN dm.sales_statement_report.is_tolling_code IS 'Признак толлинг |
Метка толлингово контракта в поставке "X"
Если VBAK - ABRVW = параметру TOLABRVW программы /RUSAL/SD2902M_3
по VBAK - VBELN = /RUSAL/SHIPDATA - CONTR_ID по /RUSAL/SHIPDATA - IDENT =  "ID_SHIPDATA " SD.000654
Иначе =  "пусто" |
Расчётное';
--SD.000919
COMMENT ON COLUMN dm.sales_statement_report.warehouse_or_responsible_customer_for_storage_name IS 'General storage location |
Для всех витрин
Для внешнего рынка:
А.1 Если SD.000018  "Рынок в отгрузке (код)" = ‘1’ (экспорт внешний рынок) или  "4 " (КУБАЛ):
А.1.1 Если SD.000630 «EXP: Storage location» <> пусто, то:
OIJLOC-LOCNAM, где OIJLOC-LOCID = TVKNT-BEZKZ, где TVKNT-SPRAS =  "E " и TVKNT-BEZEI <>  "@* " и TVKNT-BEZEI = SD.000630 «EXP: Storage location», с группированием по полям: TVKNT-BEZEI и TVKNT-BEZKZ
А.1.2 Иначе:
А.1.2.1 SD.000047  "Группа коносамента в ин.порту" <> пусто, то:
TVKNT-BEZEI, где TVKNT-SPRAS =  "E " и TVKNT-BEZEI <>  "@* " и TVKNT-KNOTE = SD.000054 «Порт выгрузки 2 (код)», с группированием по полям: TVKNT-BEZEI и TVKNT-BEZKZ
А.1.2.2 Иначе:
TVKNT-BEZEI , где TVKNT-SPRAS =  "E " и TVKNT-BEZEI <>  "@*" и TVKNT-KNOTE = SD.000044 «Порт выгрузки (код)», с группированием по полям: TVKNT-BEZEI и TVKNT-BEZKZ
А.1.3 Если значение не определено и SD.000018  "Рынок в отгрузке (код) " =  "4 " (КУБАЛ) и SD.000009  "Направление " <> ‘TUNADAL’, ‘SORAKER’, то:
 "ONWAY"
Для внутреннего рынка:
А.2 Иначе, если SD.000018  "Рынок в отгрузке (код) " =  "2 ", ‘3’ (внутренний рынок РФ и СНГ):
А.2.1 Если SD.000641  "Код страны конечного потребителя " = настроечный параметр LAND1_GP  "Страны таможенного союза " (программа /RUSAL/SD3346M), то:
SD.000603 «Клиент для отчета Металл в Цепочке Поставок»
А.2.2 Иначе, если SD.000342  "Регион POD (код) "= ‘07’ (СНГ), то:
SD.000045 «Порт выгрузки»
А.2.3 Иначе:
пусто
А.3 Если значение не определено, то:
 "UNDEFINED "
для Плановых данных витрины (плановый и реализованный металл):
По умолчанию =  "Scheduled " если  "Признак План/Факт " SD.000159 =  "P "
для Реализованных данных витрины (плановый и реализованный металл):
По умолчанию =  "Realized " если  "Дата реализации " SD.000720 <>  "пусто " |
Расчётное';
--SD.001244
COMMENT ON COLUMN dm.sales_statement_report.statement_data_group_code IS 'Блок данных (statement) |
Поле обозначает блок данных отчета statement. Подразумевает подход к выбору данных и текущее состояние группы. Значения:
• Для Плановые данные - Scheduled.
• Для Факт отгруженный без инвойсов - fs_without_invoice.
• Для Факт отгруженный с инвойсом на внутреннего оператора - fs_with_invoice_int_operator.
• Для Факт отгруженный с инвойсом на внешнего клиента - fs_with_invoice_ext_client.
• Для Факт отгруженный на поставки с возвратом - fs_returned.
• Для Факт отгруженный с инвойсом на внешнего клиента и с финальными/корректирующими инвойсами - fs_with_invoice_ext_client_final.
• Для Закупка от 3х лиц - purchase_third_parties.
• Для Additional services - add_services.
• Для Предоплата - prepayment.
По Признак План/Факт " SD.000159 =  "P " это Scheduled.
Если SD.000372 = 8 - возврат это значение fs_returned.
Признак План/Факт " SD.000159 не равно  "P " и нет инвойса SD.000167 invoice_provisional_number это fs_without_invoice.
Признак План/Факт " SD.000159 не равно  "P ", есть инвойс D.000167 invoice_provisional_number и SD.000036-KUNNR входит в параметр OPERATOR программы /RUSAL/SD4359M SD.001244 Data group = fs_with_invoice_int_operator.
Признак План/Факт " SD.000159 не равно  "P ", есть инвойс D.000167 invoice_provisional_number и SD.000036-KUNNR НЕ входит в параметр OPERATOR программы /RUSAL/SD4359M SD.001244 Data group = fs_with_invoice_ext_client.
По оставшимся значениям логика описана на вкладке обновление данных КХД |
Расчётное';
--SD.001245
COMMENT ON COLUMN dm.sales_statement_report.invoice_group_code IS 'Группа инвойс (statement) |
Номер группы инвойсов для statement. Пример 3000029195По значению SD.001244 Data group, если значение Scheduled, fs_without_invoice, fs_with_invoice_int_operator - значение пусто.
Для значений fs_with_invoice_ext_client = /RUSAL/VBSS_VBSK-SAMMG для /RUSAL/VBSS_VBSK-SMART=  "О " и VBELN = «Продажная поставка».
Для значения fs_returned =/RUSAL/VBSS_VBSK-SAMMG по ограничению SMART = Q (Final Invoice)
Если по SMART = Q значения не найдены, то берем по SMART = К (Корректировка) (кириллица), если значений найдено несколько, то берем минимальное SAMMG.
Для других значений логика описана на вкладке обновление данных КХД |
Расчётное';
--SD.001246
COMMENT ON COLUMN dm.sales_statement_report.dt_report_yyyy IS 'Год отчета (statement) |
Год отчета Statement. Пример 2025Логика описана на вкладке обновление данных КХД
Для значений SD.001244 Data group (statement) = Scheduled, fs_without_invoice, fs_with_invoice_int_operator, fs_with_invoice_ext_client, fs_returned взять значение из Shipment date SD.000010
и Realization date SD.000720 и SD.001362 Payment date, если года разные, то строчки дублируются для каждого года. Год заполняться от соответствующей даты |
Расчётное';
 --SD.001247
COMMENT ON COLUMN dm.sales_statement_report.purchase_invoice_code IS 'Входящий счет (statement) |
Входящий счет, Пример 5108522172. Логика описана на вкладке обновление данных КХД |
Расчётное';
 --SD.001248
COMMENT ON COLUMN dm.sales_statement_report.dt_purchase_invoice_yyyy IS 'Год входящего счета (statement) |
Год входящего счета , Пример 2025Логика описана на вкладке обновление данных КХД |
 Расчётное';
--SD.001249
COMMENT ON COLUMN dm.sales_statement_report.net_weight IS 'Вес для statement |
Вес для StatementScheduled = SD.000032 weight_net.
fs_without_invoice = SD.000032 weight_net.
fs_with_invoice_int_operator= SD.000032 weight_net. fs_with_invoice_ext_client = SD.000032 weight_net.
fs_returned = SD.000032 weight_net. fs_with_invoice_ext_client_final = 0.
purchase_third_parties = для основного счета отрицательное значение SD.000032 weight_net, для доп дебетования по SD.001247 BELNR = RSEG-BELNR и SD.001248 GJAHR = RSEG-GJARH определяем из первой позиции RSEG-TBTKZ = X значение 0.
add_services = VBRP-FKIMG по SD.001250 Фактура для statement и SD.001251 Позиция фактуры для statement.
Prepayment = VBRP-FKIMG по SD.001250 Фактура для statement и SD.001251 Позиция фактуры для statement. |
Расчётное';
--SD.001250
COMMENT ON COLUMN dm.sales_statement_report.statement_invoice_code IS 'Фактура для statement |
№ Фактуры для statement, пример Пример 1282945372Логика для add_services и prepayment на вкладке обновление данных КХД.
Для остальных случаев SD.001245 Invoice group (statement) = VBSK-SAMMG берем VBSK-ZZVBELN |
Расчётное';
--SD.001251
COMMENT ON COLUMN dm.sales_statement_report.statement_invoice_position_code IS 'Позиция фактуры для statement |
№ Позиции фактуры для statement, Пример 10Логика для add_services и prepayment на вкладке обновление данных КХД.
Для SD.001244 = fs_with_invoice_ext_client
Через SD.000002 delivery_number_sales = LIPS-VBELN + SD.000004 batch = LIPS-CHARG определяем LIPS-POSNR.
По LIPS-VBELN = VBAP-ZZLFVBELN и LIPS-POSNR = VBAP-ZZLFPOSNR и VBAP-VBELN = VBSK-ZZVBELN_VA по VBSK-SAMMG = SD.001245 Invoice group (statement). Определяем заказ VBAP-VBELN и VBAP-POSNR.
Далее VBAP-VBELN = VBRP-VGBEL и VBAP-POSNR = VBRP-VGPOS определяем VBRP-POSNR
Для SD.001244 = fs_with_invoice_ext_client_final
По SD.000258 delivery_number_outbound = LIPS-VBELN и SD.000004 batch = LIPS-CHARG определяем LIPS-POSNR.
По LIPS-VBELN = VBRP-VGBEL и LIPS-POSNR = VBRP-VGPOS определяем VBRP-POSNR |
Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.supplier_3rd_party_code IS 'Имя партнера у кого закупаем металл, для строчек закупки третьих лиц. | Имя партнера у кого закупаем металл, для строчек закупки третьих лиц. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.dt_payment IS 'Дата оплаты | Для инвойсов, по которым есть оплата, берется фактическая дата оплаты. Если оплаты нет, то Due date больше текущей даты, тогда Due date. Если Due date меньше и равно текущей даты, то текущая дата. Имя партнера у кого закупаем металл, для строчек закупки третьих лиц. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.dt_payment_week IS 'Неделя оплаты | Неделя оплаты, определяется из даты оплаты. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.dt_payment_mm IS 'Месяц оплаты | Месяц  оплаты, определяется из даты оплаты. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.dt_due_payment IS 'Срок платежа по инвойсу.(дата в которую ожидается платеж) | Срок платежа по инвойсу.(дата в которую ожидается платеж) | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.payment_terms_code IS 'Код услвоия платежа. C379 | Код услвоия платежа. C379 | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.payment_terms_days_quantity IS 'Количество дней из услвоия платежа. Для C379 - 17 дней | Количество дней из услвоия платежа. Для C379 - 17 дней | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.payment_terms_document_name IS 'Документ связанный с условием платежа.Для C379 будет - 20 Prepayment | Документ связанный с условием платежа.Для C379 будет - 20 Prepayment   | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.market_indicator_code IS 'Значение рыночного индикатора, T9 | Значение рыночного индикатора, T9  | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.market_indicator_name IS 'Текст рыночного индикатора, для T9 - Fix | Текст рыночного индикатора, для T9 - Fix  | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.metal_exchange_type_code IS 'Тип биржи. Например LME Cash. | Тип биржи. Например LME Cash.  | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.usd_currency_vat_excluded_amound IS 'Стоимость без НДС. Переведенная в USD. | Стоимость без НДС. Переведенная в USD. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.document_currency_vat_excluded_amound IS 'Стоимость без НДС в валюте документа | Стоимость без НДС в валюте документа | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.usd_currency_vat_included_amound IS 'Стоимость c НДС. Переведенная в USD. | Стоимость c НДС. Переведенная в USD. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.invoice_realization_code IS 'Номер фактуры реализации. | Номер фактуры реализации. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.currency_exchange_rate IS 'Курс валюты | Курс валюты | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.direct_or_overseas_warehouse_delivery_name IS 'Продажа напрямую или через склад | Продажа напрямую или через склад. Значения текст Direct delivery или Warehouse | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.is_trader_name IS 'Trader для партнеров глобальный трейдер, для остальных партнеров пусто | Trader для партнеров глобальный трейдер, для остальных партнеров пусто | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.prepayment_invoice_code IS 'Номер предоплатного счета. | Номер предоплатного счета. | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.sales_market_in_sales_request_code IS 'Значение маркета из заказа.  | Значение маркета из заказа. 1 Экспорт 2 СНГ 3 Вн. рынок для распределения 4 Kubal | Расчётное';
COMMENT ON COLUMN dm.sales_statement_report.statement_calculated_weight IS 'Расчетный вес Statement | Расчетный вес Statement. Там, где есть инвойсы - расчётный вес для инвойса (нетто / брутто). Когда нет инвойса для первички расчёт нетто + катанка, для сплавов нетто. | Расчётное';