drop table if exists dm_calc.storage_sales_bundles_weight;


create table if not exists dm_calc.storage_sales_bundles_weight (
	sales_bundle_code varchar(10) null,
	plant_producer_delivery_code varchar(30) null,
	plant_producer_delivery_position_code varchar(18) null,
	initial_delivery_code varchar(30) null,
	material_code varchar(54) null,
	dt_shipment date null,
	railcar_code varchar(60) null,
	transport_bill_code varchar(105) null,
	uni varchar(180) null,
	material_shape_code varchar(9) null,
	dt_arrival_to_russian_port date null,
	dt_storage_end_in_release date null,
	transport_type_code varchar(12) null,
	etsng_code varchar(10) null,
	dt_report date null,
	sales_bundle_net_weight numeric(15, 3) null,
	sales_bundle_gross_weight numeric(15, 3) null,
	batch_code varchar(30) null,
	dt_arrival date null,
	receiving_plant_code varchar(4) null,
	sales_delivery_code varchar(30) null,
	transportation_inbound_delivery_code varchar(10) null,
	delivery_for_storage_calculation_code varchar(30) null,
	transportation_inbound_delivery_position_code varchar(6) null,
	delivery_position_for_storage_calculation_code varchar(6) null,
	forwarder_code varchar(10) null,
	storage_cost_calculation_type_name varchar(20) null,
	transport_departure_hub_code varchar(10) null,
	transport_destination_hub_code varchar(10) null,
	transportation_outbound_delivery_code varchar(10) null,
	transportation_outbound_delivery_position_code varchar(6) null,
	is_final_transportation_stage_code varchar(1) null,
	transportation_stage_code varchar(2) null,
	storage_calculation_bundle_quantity int8 null,
	warehouse_code varchar(10) null,
	is_stored_in_russian_port_code varchar(1) null,
	delivery_in_final_release_code varchar(30) null,
	dt_final_release date null,
	bill_of_lading_code varchar(30) null,
	bill_of_lading_number varchar(90) null,
	dt_bill_of_lading date null,
	incoterms_code varchar(9) null,
	storage_cost_special_calculation_type_code varchar(1) null,
	warehouse_storage_area_code varchar(10) null,
	plant_code varchar(4) null,
	unit_balance_code varchar(4) null,
	creditor_in_shipment_instruction_code varchar(10) null,
	dt_storage_start date null,
	dt_shipped_from_warehouse date null,
	dt_storage_end date null,
	storage_duration_total_calendar_days int4 null,
	shipment_instruction_number varchar(30) null,
	dt_for_price_search_in_purchase_contract date null,
	port_of_discharge_code varchar(30) null,
	service_number text null,
	weight_for_1090_umno numeric null,
	weight_for_1090_razdel numeric null,
	remote_warehouse_code varchar(10) null,
	dt_transportation_stage_start_p date null,
	dt_transportation_stage_start_r date null,
	rn varchar(36) null,
	dttm_inserted timestamp not null default now(),
	dttm_updated timestamp not null default now(),
	job_name varchar(60) not null default 'airflow'::character varying,
	deleted_flag bool not null default false
)
with (
	appendonly = true,
	orientation = column,
	compresstype = zstd,
	compresslevel = 3
)
distributed by (sales_bundle_code);
-------------------------------------------------------------------------------------------------

comment on table dm_calc.storage_sales_bundles_weight is 'Веса для витрины хранения металла на внешних складах после отгрузки с АЗ';
comment on column dm_calc.storage_sales_bundles_weight.sales_bundle_code is 'Номер плавки металла (код) | Номер плавки металла (код) | sales_bundle_transport_hub_turnover_sdt0004.sales_bundle_code';
comment on column dm_calc.storage_sales_bundles_weight.plant_producer_delivery_code is 'Поставка завода производителя (код) | Поставка завода производителя (код) | sd_sales_main_scm.delivery_number_of_producer_plant';
comment on column dm_calc.storage_sales_bundles_weight.plant_producer_delivery_position_code is 'Позиция поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе (код) | Позиция поставки завода производителя, по которой формируется цепочка продаж на заводе произвидителе (код) | sd_sales_main_scm.delivery_item_of_plant';
comment on column dm_calc.storage_sales_bundles_weight.initial_delivery_code is 'Исходная (первая) поставка, от которой начинается оформление цепочки продаж (код) | Исходная (первая) поставка, от которой начинается оформление цепочки продаж (код) | sd_sales_main_scm.delivery_number_initial';
comment on column dm_calc.storage_sales_bundles_weight.material_code is 'Номер материала (код) | Номер материала (код) | sd_sales_main_scm.material_code';
comment on column dm_calc.storage_sales_bundles_weight.dt_shipment is 'Дата отгрузки поставки с завода | Дата отгрузки поставки с завода | sd_sales_main_scm.dt_shipment';
comment on column dm_calc.storage_sales_bundles_weight.railcar_code is 'Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя (код) | Номер авто, вагона или контейнера, в случае перевозки металла в контенере, в котором металл едет от Завода производителя (код) | sd_sales_main_scm.railcar';
comment on column dm_calc.storage_sales_bundles_weight.transport_bill_code is 'Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя (код) | Номер жд накладной, CMR, ТТН, по которой металл едет от Завода производителя (код) | sd_sales_main_scm.transport_bill';
comment on column dm_calc.storage_sales_bundles_weight.uni is 'Если Причина деления постави = "4- Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | Если Причина деления постави = "4- Перевеска", то это: Накладная + Дата коносамента + Судно факт + Номер рейса факт, разделенные знаком‘-’;
Иначе данные из Продажной поставки, полей Транспортная накладная + Ид. Транспортировки;
Иначе: Накладная + Вагон | sd_sales_main_scm.uni';
comment on column dm_calc.storage_sales_bundles_weight.material_shape_code is 'Форма (код) | Форма (код) | material_specification.shape_code';
comment on column dm_calc.storage_sales_bundles_weight.dt_arrival_to_russian_port is 'Дата прибытия металла в порт РФ | Дата прибытия металла в порт РФ | sd_sales_main_scm.dt_warehouse';
comment on column dm_calc.storage_sales_bundles_weight.dt_storage_end_in_release is 'Дата окончания хранения металла за счет РУСАЛа | Дата окончания хранения металла за счет РУСАЛа | release.dt_end_of_free_storage';
comment on column dm_calc.storage_sales_bundles_weight.transport_type_code is 'Тип подвижного состава, с которым груз зашел для хранения (код) | Тип подвижного состава, с которым груз зашел для хранения (код) | sd_sales_main_scm.transport_railcar_type_code';
comment on column dm_calc.storage_sales_bundles_weight.etsng_code is 'Код груза ЕТСНГ (код) | Код груза ЕТСНГ (код) | material.etsng_code';
comment on column dm_calc.storage_sales_bundles_weight.dt_report is 'Дата, на которую производится расчет хранения | Дата, на которую производится расчет хранения | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.sales_bundle_net_weight is 'Вес нетто пакета | Вес нетто пакета | sales_bundle.sales_bundle_net_weight';
comment on column dm_calc.storage_sales_bundles_weight.sales_bundle_gross_weight is 'Вес брутто пакета | Вес брутто пакета | sales_bundle.sales_bundle_gross_weight';
comment on column dm_calc.storage_sales_bundles_weight.batch_code is 'Партия (код) | Партия (код) | sd_sales_main_scm.batch';
comment on column dm_calc.storage_sales_bundles_weight.dt_arrival is 'Дата прибытия металла в пункт назначения | Дата прибытия металла в пункт назначения | sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_r';
comment on column dm_calc.storage_sales_bundles_weight.receiving_plant_code is 'Завод продажной поставки (код) | Завод продажной поставки (код) | delivery_document_position.plant_producer_code';
comment on column dm_calc.storage_sales_bundles_weight.sales_delivery_code is 'Если поставка разделена - то разделенная поставка.
Если нет - то Исходная поставка (код) | Если поставка разделена - то разделенная поставка.
Если нет - то Исходная поставка (код) | sd_sales_main_scm.delivery_number_sales';
comment on column dm_calc.storage_sales_bundles_weight.transportation_inbound_delivery_code is 'Техническая поставка транспортировки этапа прибытия ГП на склад (код) | Техническая поставка транспортировки этапа прибытия ГП на склад (код) | sales_bundle_transport_hub_turnover_sdt0004.delivery_code_le_p';
comment on column dm_calc.storage_sales_bundles_weight.delivery_for_storage_calculation_code is 'Поставка, на которой выполняется расчет (код) | Поставка, на которой выполняется расчет (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.transportation_inbound_delivery_position_code is 'Позиция технической поставки транспортировки этапа прибытия ГП на склад (код) | Позиция технической поставки транспортировки этапа прибытия ГП на склад (код) | sales_bundle_transport_hub_turnover_sdt0004.transportation_inbound_delivery_position_code';
comment on column dm_calc.storage_sales_bundles_weight.delivery_position_for_storage_calculation_code is 'Позиция поставки, на которой выполняется расчет (код) | Позиция поставки, на которой выполняется расчет (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.forwarder_code is 'Экспедитор (код) | Экспедитор (код) | sales_document_counterparty_role.supplier_code';
comment on column dm_calc.storage_sales_bundles_weight.storage_cost_calculation_type_name is 'Регион хранения и логика, применяемая для расчета стоимости хранения (наименование) | Регион хранения и логика, применяемая для расчета стоимости хранения (наименование) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.transport_departure_hub_code is 'Начальный узел поставки (код) | Начальный узел поставки (код) | sales_bundle_and_delivery_relationship.transport_route_departure_hub_code';
comment on column dm_calc.storage_sales_bundles_weight.transport_destination_hub_code is 'Конечный узел поставки (код) | Конечный узел поставки (код) | sales_bundle_and_delivery_relationship.transport_route_destination_hub_code';
comment on column dm_calc.storage_sales_bundles_weight.transportation_outbound_delivery_code is 'Техническая поставка транспортировки этапа убытия ГП со склада (код) | Техническая поставка транспортировки этапа убытия ГП со склада (код) | sales_bundle_transport_hub_turnover_sdt0004.delivery_code_le_r';
comment on column dm_calc.storage_sales_bundles_weight.transportation_outbound_delivery_position_code is 'Позиция технической поставки транспортировки этапа убытия ГП со склада (код) | Позиция технической поставки транспортировки этапа убытия ГП со склада (код) | sales_bundle_transport_hub_turnover_sdt0004.transportation_outbound_delivery_position_code';
comment on column dm_calc.storage_sales_bundles_weight.is_final_transportation_stage_code is 'Метка Последний этап (код) | Метка Последний этап (код) | sales_bundle_and_delivery_relationship.is_final_transportation_stage_code';
comment on column dm_calc.storage_sales_bundles_weight.transportation_stage_code is 'Этап перевозки (код) | Этап перевозки (код) | sales_bundle_and_delivery_relationship.transportation_stage_code';
comment on column dm_calc.storage_sales_bundles_weight.storage_calculation_bundle_quantity is 'Количество пакетов в поставке хранения | Количество пакетов в поставке хранения | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.warehouse_code is 'Склад (код) | Склад (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.is_stored_in_russian_port_code is 'Индикатор: хранение осуществляется на терминале в порту РФ | Индикатор: хранение осуществляется на терминале в порту РФ | transport_hub.is_seaport';
comment on column dm_calc.storage_sales_bundles_weight.delivery_in_final_release_code is 'Продажная поставка, которая входит в финальный релиз (код) | Продажная поставка, которая входит в финальный релиз (код) | sd_sales_main_scm.delivery_number_sales';
comment on column dm_calc.storage_sales_bundles_weight.dt_final_release is 'Дата оформления финального релиза | Дата оформления финального релиза | sd_sales_main_scm.dt_final_release';
comment on column dm_calc.storage_sales_bundles_weight.bill_of_lading_code is 'Группа коносамента (код) | Группа коносамента (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.bill_of_lading_number is 'Номер коносамента | Номер коносамента | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.dt_bill_of_lading is 'Дата выпуска коносамента, оформленного в порту РФ/иностранном порту | Дата выпуска коносамента, оформленного в порту РФ/иностранном порту | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.incoterms_code is 'Инкотермс (код) | Инкотермс (код) | sd_sales_main_scm.delivery_basis';
comment on column dm_calc.storage_sales_bundles_weight.storage_cost_special_calculation_type_code is 'Особая логика, применяемая для расчета стоимости хранения конкретным контрагентом (код) | Особая логика, применяемая для расчета стоимости хранения конкретным контрагентом (код) | transportation_storage_calculation_method.calculation_method_code';
comment on column dm_calc.storage_sales_bundles_weight.warehouse_storage_area_code is 'Складская зона (код) | Складская зона (код) | transportation_warehouse_storage_area.warehouse_storage_area_code';
comment on column dm_calc.storage_sales_bundles_weight.plant_code is 'Завод (код) | Завод (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.unit_balance_code is 'Балансовая единица (код) | Балансовая единица (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.creditor_in_shipment_instruction_code is 'Кредитор, который принимает груз на хранение в порту (код) | Кредитор, который принимает груз на хранение в порту (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.dt_storage_start is 'Дата прихода металла на склад | Дата прихода металла на склад | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.dt_shipped_from_warehouse is 'Дата вывоза со склада | Дата вывоза со склада | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.dt_storage_end is 'Дата вывоза металла со склада либо дата окончания хранения металла за счет Русал (берем то, то наступит раньше) | Дата вывоза металла со склада либо дата окончания хранения металла за счет Русал (берем то, то наступит раньше) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.storage_duration_total_calendar_days is 'Количество дней хранения металла всего | Количество дней хранения металла всего | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.shipment_instruction_number is 'Номер инструкции ДСБ | Номер инструкции ДСБ | sales_request_for_proposal_header / sales_contract_header / sales_order_header.shipment_instruction_code';
comment on column dm_calc.storage_sales_bundles_weight.dt_for_price_search_in_purchase_contract is 'Дата, на которую производится поиск договора | Дата, на которую производится поиск договора | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.port_of_discharge_code is 'Для РФ - порт погрузки, для ин. портов - порт выгрузки на дату расчета (первый или второй ин. порт) (код) | Для РФ - порт погрузки, для ин. портов - порт выгрузки на дату расчета (первый или второй ин. порт) (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.service_number is 'Услуга для поиска стоимостного приложения хранения (код) | Услуга для поиска стоимостного приложения хранения (код) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.weight_for_1090_umno is 'Техническое поле для вычисления стоимости хранения (числитель) | Техническое поле для вычисления стоимости хранения (числитель) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.weight_for_1090_razdel is 'Техническое поле для вычисления стоимости хранения (знаменатель) | Техническое поле для вычисления стоимости хранения (знаменатель) | Расчетное поле';
comment on column dm_calc.storage_sales_bundles_weight.remote_warehouse_code is 'Удаленный склад (код) | Удаленный склад (код) | sales_bundle_transport_hub_turnover_sdt0004.knote';
comment on column dm_calc.storage_sales_bundles_weight.dt_transportation_stage_start_p is 'Дата поступления ГП на терминал/склад | Дата поступления ГП на терминал/склад | sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_p';
comment on column dm_calc.storage_sales_bundles_weight.dt_transportation_stage_start_r is 'Дата ухода ГП из терминала/склада | Дата ухода ГП из терминала/склада | sales_bundle_transport_hub_turnover_sdt0004.dt_transportation_stage_start_r';
comment on column dm_calc.storage_sales_bundles_weight.rn is 'Уникальный идентификатор записи (код) | Уникальный идентификатор записи (код) | Расчетное поле';

-------------------------------------------- Первая часть витрины -----------------------------------------------------------------------------------
-- Первая часть скрипта начинается.

truncate table dm_calc.storage_sales_bundles_weight;

create temporary table lake on commit drop as ( -- данные из озера данных. Для джойна с t4 берутся данные 4798 (dds.sales_bundle_and_delivery_relationship)
	select
		ssms.delivery_number_sales, --продажная поставка
		ssms.delivery_number_of_producer_plant as SD_000003,
		ssms.delivery_item_of_plant as SD_000110,
		ssms.delivery_number_initial as SD_000001,
		ssms.material_code as SD_000143,
		ssms.dt_shipment as SD_000010,
		ssms.railcar as SD_000013,
		ssms.transport_bill as SD_000014,
		ssms.uni as SD_000151,
		ssms.port_of_discharge_in_foreign_port_code as SD_000054,
		ssms.port_of_loading_code as SD_000649,
		ssms.port_of_discharge_code as SD_000044,
		ssms.transport_railcar_type_code as SD_000028,
		ssms.bill_of_lading_group_code as SD_000040,
		ssms.bill_of_lading_number as SD_000041,
		ssms.dt_bill_of_lading as SD_000042,
		ssms.dt_final_release as SD_000482,
		ssms.batch as SD_000004, -- SD.000737 Маша сказала брать партию из озера
		ssms.delivery_basis as SD_000067,
		ssms.bill_of_lading_group_code_in_foreign_port as SD_000047,
		ssms.bill_of_lading_in_foreign_port as SD_000048,
		ssms.dt_bill_of_lading_in_foreign_port as SD_000049,
		ssms.dt_warehouse as SD_000024,
		sd4798.sales_bundle_code, -- id_him
		row_number() over(partition by sd4798.sales_bundle_code order by source_system_position_code desc) as rn
	from dm_calc.sd_sales_main_scm as ssms
	join dds.sales_bundle_and_delivery_relationship as sd4798
		on ssms.delivery_number_sales = sd4798.delivery_code
)
distributed by (sales_bundle_code);


create temporary table adrc on commit drop as ( -- убираются дубли для поля склада
select
	address_code,
	min(country_code) as country_code
from
	dict_dds.address
group by
	address_code
	)
distributed replicated;

create temporary table asia on commit drop as ( -- Убираются дубли для поля LE.001064 (логика в зависимости от региона) Для логики Азия
select
	counterparty_code
	from
	dict_dds.transportation_storage_calculation_method
group by
	counterparty_code)
distributed replicated;


create temporary table euro_1 on commit drop as ( -- Убираются дубли для поля LE.001064 (логика в зависимости от региона) Для логики Европа
select
	counterparty_code
from
	dict_dds.transportation_storage_calculation_method
where
	service_code like 'EU%'
group by
	counterparty_code)
distributed replicated;

create temporary table euro_2 on commit drop as ( -- Убираются дубли для поля LE.001064 (логика в зависимости от региона) Для логики Европа
select
	counterparty_code
from
	dict_dds.transportation_storage_calculation_method
group by
	counterparty_code)
distributed replicated;


create temporary table euro_log on commit drop as ( -- Таблица для поля LE.001064 (логика в зависимости от региона) Для логики Европа. Тут хранятся значения настроечного параметра
select
	range_low_value
from
	dict_dds.settings_and_parameters_sap
where
	abap_program_code ilike '/RUSAL/ZLE112m'
	and case_code = 'PERET_FRN'
	and parameter_code = 'S_LIFNRA'
	and range_low_value is not null
group by
	range_low_value)
distributed replicated;

create temporary table svh on commit drop as ( -- Убираются дубли для поля LE.001064 (логика в зависимости от региона) Для логики СВХ. Сейчас нет дублей, но на всякий
select
	counterparty_code
from
	dict_dds.transportation_general_calculation_method
where
	general_calculation_method_code in ('16', '04')
group by
	counterparty_code)
distributed replicated;

create temporary table asia_log on commit drop as ( -- Таблица для поля LE.001064 (логика в зависимости от региона) Для логики Азия. Тут хранятся значения настроечного параметра
select
	range_low_value
from
	dict_dds.settings_and_parameters_sap
where
	abap_program_code ilike '/RUSAL/ZLE112m'
	and case_code = 'PERET_FRN'
	and parameter_code = 'LIFNR_FR'
	and range_low_value is not null
group by
	range_low_value)
distributed replicated;

create temporary table for_LE_001035 on commit drop as ( -- в таблице считается количество пакетов в поставке хранения для поля LE.001035
select
	delivery_code,
	batch_code,
	count(*) as cnt
from
	dds.sales_bundle_and_delivery_relationship
where
	is_deleted_code is null
group by
	delivery_code,
	batch_code)
distributed by (delivery_code);

create temporary table date_for_vitr on commit drop as (
	select
		dt_balance::date as dt_balance
	from generate_series(current_date - '1year'::interval, current_date, '1day'::interval) AS t(dt_balance)
		--generate_series('20241230'::date, '20250131'::date, '1day'::interval) AS t(dt_balance)
)
distributed replicated;
-- Выбор периода для отчета. Сейчас для тестирования данные за 1 месяц

create temporary table dedopo_2 on commit drop as ( -- убираются дубли для выявления номера поставки завода для поля LE.001043
select
	delivery_code,
	sales_document_code
from
	dds.delivery_document_position
where
	sales_document_code is not null
group by
	delivery_code,
	sales_document_code)
distributed by (delivery_code);

create temporary table for_1055 on commit drop as ( -- считается дата окончания хранения для поля LE.001055.
select
	vbss.delivery_code as vbeln,
	min(vbsk.dt_end_of_free_storage) as dt_end_of_free_storage
from
	dds.logistics_document_and_delivery_relationship vbss
left join dds.release as vbsk on
	vbsk.release_code
	= vbss.logistics_document_code
	and vbsk.release_type_code = 'X'
left join dict_dds.settings_and_parameters_sap frel_kod
			on
	vbsk.release_template_code = frel_kod.range_low_value 
where
	1 = 1
	and frel_kod.abap_program_code = '/RUSAL/SD2921M'
	and frel_kod.parameter_code = 'FREL_KOD'
	and frel_kod.range_sign_code = 'I'
	and frel_kod.range_option_code = 'EQ'
	and vbsk.release_code is not null
	and vbsk.dt_end_of_free_storage is not null
group by
	vbss.delivery_code
	)
distributed replicated;
--	stock_det as (
--	select *
--	from dm_view.sales_material_turnover_detailed -- Не использовать эту таблицу. Нужно найти все нужные поля в озере. Если их там нет, то написать Насте и Вместе с Машей добавить их куда-то
--	)



create temporary table base on commit drop as ( -- в таблице собираются начальные поля витрины. за основу берется таблица t4
with forwapd_1 as ( -- убираются дубли для определения поставки хранения (поле LE.001016) и некоторых других полей	
	select transport_hub_code, min(market_region1_code) as market_region1_code from dict_dds.foreign_warehouse_priority_definition
	where market_region1_code in ('04', '03') and (is_terminal_code is not null or is_foreign_warehouse_code is not null or is_temporary_warehouse_code is not null) group by transport_hub_code
	),
	
	forwapd_2 as (
	select transport_hub_code from dict_dds.foreign_warehouse_priority_definition
	where is_russian_port_code is not null
	)
	
	select
		t4.sales_bundle_code as sales_bundle_code, --id_him LE.001000
		lake.SD_000003 as plant_producer_delivery_code,  -- LE.001001
		lake.SD_000110 as plant_producer_delivery_position_code, -- LE.001002
		lake.SD_000001 as initial_delivery_code, -- LE.001003
		lake.SD_000143 as material_code, -- LE.001012
		lake.SD_000010 as dt_shipment, -- LE.001020
		lake.SD_000013 as railcar_code, -- LE.001032
		lake.SD_000014 as transport_bill_code, -- LE.001033
		lake.SD_000151 as uni, -- LE.001034
		maspe.shape_code as material_shape_code, -- LE.001036
		lake.SD_000028 as transport_type_code, -- LE.001050
		mater.etsng_code as etsng_code, -- LE.001066
		sabu.sales_bundle_net_weight / 1000 as sales_bundle_net_weight, -- LE.001018
		sabu.sales_bundle_gross_weight / 1000 as sales_bundle_gross_weight, -- LE.001019
		lake.SD_000004 as batch_code, -- LE.001015
		t4.dt_transportation_stage_start_r as dt_arrival, -- LE.001039 -- Нет поля SD.000530. Сейчас используем SD.000518
			

				
		dedopo_1.plant_producer_code as receiving_plant_code, -- LE.001029
		lake.delivery_number_sales as sales_delivery_code, -- LE.001005
				
		case
			when forwapd_1.transport_hub_code is not null then t4.delivery_code_le_p
		end as transportation_inbound_delivery_code, -- LE.001007
	
		case
			when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then sabadr_03.delivery_code
			when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then sabadr_04.delivery_code
			when forwapd_2.transport_hub_code is not null then lake.delivery_number_sales
		end as delivery_for_storage_calculation_code, -- LE.001016
	
		case
			when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then null
			when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then null
			when forwapd_2.transport_hub_code is not null then '1'
		end as wwgsg_01,
	
		case
			when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then null
			when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then null
			when forwapd_2.transport_hub_code is not null then vbsk.dt_bill_of_lading -- zzlddat
		end as wwgsg_01_date,
	
		t4.transportation_inbound_delivery_position_code as transportation_inbound_delivery_position_code, -- LE.001008
				
		case
			when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then t4.transportation_inbound_delivery_position_code
			when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then t4.transportation_inbound_delivery_position_code		
			else '10'
		end as delivery_position_for_storage_calculation_code, -- LE.001017
	
		coalesce(ascr_1.supplier_code, ascr_2.supplier_code) as forwarder_code, -- LE.001040

		case
			when likp.delivery_type_code <> 'ZLE' and lake.SD_000028 = 'TL04' then 'Логика РФ-контейнеры'
			when likp.delivery_type_code <> 'ZLE' and lake.SD_000028 <> 'TL04' then 'Логика РФ-балк'
			when likp.delivery_type_code = 'ZLE' and asia_log.range_low_value is not null and asia.counterparty_code is null then 'Логика Азия'
			when likp.delivery_type_code = 'ZLE' and euro_1.counterparty_code is not null then 'Логика Европа'
			when likp.delivery_type_code = 'ZLE' and euro_2.counterparty_code is not null and euro_log.range_low_value is not null then 'Логика Европа'
			when likp.delivery_type_code = 'ZLE' and svh.counterparty_code is not null then 'Логика СВХ'
			else 'Логика не определена'
		end as storage_cost_calculation_type_name, -- LE.001064
			
		sbudr_base.transport_route_departure_hub_code as transport_departure_hub_code, -- LE.001021
		sbudr_base.transport_route_destination_hub_code as transport_destination_hub_code, -- LE.001023
		sbudr_base.is_final_transportation_stage_code as SD_000902,
		sbudr_base.transportation_stage_code as SD_000903,
		for_LE_001035.cnt as SD_000905,
		lake.SD_000482,
		lake.SD_000041,
		lake.SD_000042,
		lake.SD_000047,
		lake.SD_000048,
		lake.SD_000054,
		lake.SD_000049,
		lake.SD_000067,
		lake.SD_000649,
		lake.SD_000044,
		lake.SD_000040,
		t4.delivery_code_le_r as SD_000516,
		t4.transportation_outbound_delivery_position_code as SD_000897,
		likp.weight_net as ntgew,
		likp.weight_net_with_wirerod as btgew,
		t4.knote as SD_000420,
		likp.dt_loaded as likp_lddat,
		case
			when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then null
			when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then null
			else lake.SD_000024
		end as dt_arrival_to_russian_port, -- LE.001059
		t4.dt_transportation_stage_start_p,
		coalesce(t4.dt_transportation_stage_start_r, current_date) as dt_transportation_stage_start_r,
		concat(t4.sales_bundle_code, t4.delivery_code, t4.delivery_position_code) as id_for_unique,
		
		coalesce(sabadr_03.dt_transportation_stage_start, sabadr_04.dt_transportation_stage_start) as lddat_4798,
		coalesce(sabadr_03.delivery_code, sabadr_04.delivery_code) as vbeln_4798,
		
		for_1055.dt_end_of_free_storage as dt_storage_end_in_release -- LE.001055


	from
		dm_calc.sales_bundle_transport_hub_turnover_sdt0004 as t4
	left join lake on
		t4.sales_bundle_code = lake.sales_bundle_code
		and lake.rn = 1
	left join dds.bill_of_lading as vbsk on 
		vbsk.bill_of_lading_code = lake.sd_000040
		and vbsk.bill_of_lading_type_code = 'Y'
	left join for_1055 on
		for_1055.vbeln = lake.delivery_number_sales
	left join dict_dds.material as mater on
		mater.material_code = lake.SD_000143
	left join dds.sales_bundle as sabu on
		sabu.sales_bundle_code = t4.sales_bundle_code
	left join forwapd_1 on
		forwapd_1.transport_hub_code = t4.knote
	left join forwapd_2 on forwapd_2.transport_hub_code = t4.knote

	left join dds.sales_bundle_and_delivery_relationship as sabadr_03 on
		sabadr_03.sales_bundle_code = t4.sales_bundle_code
		and sabadr_03.transportation_stage_code in (select range_low_value
	   	   											from dict_dds.settings_and_parameters_sap
	   	   											where abap_program_code = '/RUSAL/SD2973M_2'
													  and parameter_code in ('STAGE_EU')
													  and range_low_value is not null
													group by range_low_value) 
		and sabadr_03.transport_route_destination_hub_code = t4.knote
		and forwapd_1.market_region1_code = '03' 
		and sabadr_03.is_deleted_code is null 
		and sabadr_03.dt_transportation_stage_start <= coalesce(t4.dt_transportation_stage_start_r, current_date) 
		and sabadr_03.dt_transportation_stage_start >= coalesce(t4.dt_transportation_stage_start_p, current_date)


	left join dds.sales_bundle_and_delivery_relationship as sabadr_04 on 
		sabadr_04.sales_bundle_code = t4.sales_bundle_code
	    and sabadr_04.transportation_stage_code in (select range_low_value
	   											from dict_dds.settings_and_parameters_sap
	   											where abap_program_code = '/RUSAL/SD2973M_2'
												  and parameter_code in ('STAGE_A')
												  and range_low_value is not null
												group by range_low_value)
		and sabadr_04.transport_route_destination_hub_code = t4.knote
		and forwapd_1.market_region1_code = '04'
		and sabadr_04.is_deleted_code is null
		and sabadr_04.dt_transportation_stage_start <= coalesce(t4.dt_transportation_stage_start_r, current_date) 
		and sabadr_04.dt_transportation_stage_start >= coalesce(t4.dt_transportation_stage_start_p, current_date)
		

	left join dds.sales_bundle_and_delivery_relationship as sbudr_base on sbudr_base.sales_bundle_code = t4.sales_bundle_code and sbudr_base.delivery_code = t4.delivery_code_le_p
		and sbudr_base.delivery_position_code = t4.transportation_inbound_delivery_position_code
		and sbudr_base.is_deleted_code is null 
	left join dds.delivery_document_position as dedopo_1 on
		dedopo_1.delivery_code = lake.delivery_number_sales
	left join dds.sales_document_counterparty_role as ascr_1 on
		ascr_1.sales_document_code = t4.delivery_code_le_p
		and ascr_1.counterparty_role_code in ('XR')
	left join dds.sales_document_counterparty_role as ascr_2 on
		ascr_2.sales_document_code = t4.delivery_code_le_p
		and ascr_2.counterparty_role_code in ('ZU')
	left join dict_dds.counterparty as country on
		country.counterparty_code = coalesce(ascr_1.supplier_code, ascr_1.supplier_code)
	left join dds.delivery_document_header as likp on
		likp.delivery_code =
		case
			when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then sabadr_03.delivery_code
			when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then sabadr_04.delivery_code
			when forwapd_2.transport_hub_code is not null then lake.delivery_number_sales
		end
	left join asia as asia on
		asia.counterparty_code = coalesce(ascr_1.supplier_code, ascr_2.supplier_code)
	left join euro_1 as euro_1 on
		euro_1.counterparty_code = coalesce(ascr_1.supplier_code, ascr_2.supplier_code)
	left join euro_2 as euro_2 on
		euro_2.counterparty_code = coalesce(ascr_1.supplier_code, ascr_2.supplier_code)
	left join svh as svh on
		svh.counterparty_code = coalesce(ascr_1.supplier_code, ascr_2.supplier_code)
	left join asia_log as asia_log on
		asia_log.range_low_value = coalesce(ascr_1.supplier_code, ascr_2.supplier_code)
	left join euro_log as euro_log on
		euro_log.range_low_value = coalesce(ascr_1.supplier_code, ascr_2.supplier_code)
	left join dict_dds.material_specification as maspe on
		maspe.material_code = lake.SD_000143
	left join for_LE_001035 as for_LE_001035 on
		for_LE_001035.delivery_code = t4.delivery_code_le_p
		and for_LE_001035.batch_code = lake.SD_000004
	where t4.dt_transportation_stage_start_p <= (select max(dt_balance) from date_for_vitr)
	and coalesce(t4.dt_transportation_stage_start_r, current_date) >= (select min(dt_balance) from date_for_vitr)
	and t4.dt_transportation_stage_start_p <> coalesce(t4.dt_transportation_stage_start_r, '22991231'::date)
	and t4.transport_route_destination_hub_code like 'G%'
	and case
		when forwapd_1.market_region1_code = '03' and sabadr_03.delivery_code is not null then sabadr_03.delivery_code
		when forwapd_1.market_region1_code = '04' and sabadr_04.delivery_code is not null then sabadr_04.delivery_code
		when forwapd_2.transport_hub_code is not null then lake.delivery_number_sales
	end is not null 
		-- первая часть ограничений для поля 1016. В логике поля LE.001016 есть пункт про исключение из выборки. Из-за того, что я пытаюсь до последнего не размножать данные на 
		-- даты отчета (поле LE.001069) приходится разделять это исключение.
) distributed by (sales_bundle_code, plant_producer_delivery_code);


create temp table for_1082_1 on commit drop as ( -- Тут хранятся значения настроечного параметра для поля LE.001082
	select range_low_value
	from dict_dds.settings_and_parameters_sap
	where abap_program_code = '/RUSAL/SD4553M'
	  and parameter_code = 'FORMSTEU'
	  and range_low_value is not null
	group by range_low_value
)
distributed replicated;


create temp table for_1082_2 on commit drop as ( -- Тут хранятся значения настроечного параметра для поля LE.001082
	select
		string_agg(range_low_value, ', ') as res,
		1 as rn
	from dict_dds.settings_and_parameters_sap
	where abap_program_code = '/RUSAL/SD4553M'
	  and parameter_code = 'S_USLSTC'
)
distributed replicated;


create temp table for_1082_3 on commit drop as ( -- Тут хранятся значения настроечного параметра для поля LE.001082
	select
		string_agg(range_low_value, ', ') as res,
		1 as rn
	from dict_dds.settings_and_parameters_sap
	where abap_program_code = '/RUSAL/SD4553M'
	  and parameter_code = 'S_USLST'
	  and range_low_value like 'EU%'
)
distributed replicated;


create temp table for_1047_1 on commit drop as ( -- тут для поля LE.001047 где логика РФ определяется склад хранения через оконку
select
	sales_bundle_code,
	transportation_stage_code,
	transport_route_departure_hub_code,
	transport_route_destination_hub_code,
	row_number() over(partition by sales_bundle_code order by transportation_stage_code desc) as rn
from
	dds.sales_bundle_and_delivery_relationship
where
	is_deleted_code is null
	and transportation_stage_code in ('10', '15', '16', '25')
) distributed by (sales_bundle_code);

create temp table trscm on commit drop as ( -- тут убираются дубли для определения особой логики расчета (сейчас только для Европы) (поле LE.001065)
select
	counterparty_code,
	calculation_method_code
from
	dict_dds.transportation_storage_calculation_method
group by
	counterparty_code,
	calculation_method_code) 
distributed replicated;

create temp table sbudr_1 on commit drop as ( -- с помощью оконки определяются партия и стадия для поля LE.001071 Азия, Европа и СВХ
select
	sales_bundle_code,
	delivery_code,
	batch_code,
	transportation_stage_code,
	transport_route_destination_hub_code,
	row_number() over(partition by sales_bundle_code, delivery_code) as rn
from
	dds.sales_bundle_and_delivery_relationship
where
	is_deleted_code is null) 
distributed by (sales_bundle_code);

create temp table zlet43_1 on commit drop as ( -- с помощью оконки берется уникальная запись для поля LE.001071
select
	plant_code,
	counterparty_code,
	unit_balance_of_storage_agreement_code,
	row_number() over(partition by plant_code,
	counterparty_code
order by
	unit_balance_of_storage_agreement_code) as rn
from
	dict_dds.map_trader_to_unit_balance_of_storage_agreement
	) 
distributed replicated;


create temp table ekpa on commit drop as ( -- убираются дубли для поля LE.001092
select
	shipment_instruction_code as objek,
	shipment_instruction_counterparty_code as counterparty_code
	from dds.sales_order_header
	where shipment_instruction_counterparty_code is not null
	group by shipment_instruction_code,
	shipment_instruction_counterparty_code) 
distributed replicated;

create temp table vbak on commit drop as ( -- тут собираются несколько таблиц вместе. Потом заменю на джойн к каждой отдельно
select
	sales_request_for_proposal_code as vbeln,
	shipment_instruction_code as zznoi
from
	dds.sales_request_for_proposal_header
where
	shipment_instruction_code is not null
union all
select
	sales_contract_code as vbeln,
	shipment_instruction_code as zznoi
from
	dds.sales_contract_header
where
	shipment_instruction_code is not null
union all
select
	sales_order_code as vbeln,
	shipment_instruction_code as zznoi
from
	dds.sales_order_header
where
	shipment_instruction_code is not null)
distributed replicated;


create temp table base_1_5 on commit drop as ( -- продолжение собирания витрины. Основывается на base.
	select
		base.sales_bundle_code,
		base.plant_producer_delivery_code,
		base.plant_producer_delivery_position_code,
		base.initial_delivery_code,
		base.material_code,
		base.dt_shipment,
		base.railcar_code,
		base.transport_bill_code,
		base.uni,
		base.material_shape_code,
		base.dt_arrival_to_russian_port,
		base.dt_storage_end_in_release,
		base.transport_type_code,
		base.etsng_code,
		base.sales_bundle_net_weight,
		base.sales_bundle_gross_weight,
		base.batch_code,
		base.dt_arrival,
		base.receiving_plant_code,
		base.sales_delivery_code,
		base.transportation_inbound_delivery_code,
		base.delivery_for_storage_calculation_code,
		base.transportation_inbound_delivery_position_code,
		base.delivery_position_for_storage_calculation_code,
		base.forwarder_code,
		base.storage_cost_calculation_type_name,
		base.transport_departure_hub_code,
		base.transport_destination_hub_code,
		base.SD_000049,
		base.SD_000044,
		base.wwgsg_01_date,
		base.id_for_unique,
		base.lddat_4798,
		base.vbeln_4798,
		base.SD_000054,
		base.wwgsg_01,
		
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000516
		end as transportation_outbound_delivery_code, -- LE.001009
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000897
		end as transportation_outbound_delivery_position_code, -- LE.001010
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000902
		end as is_final_transportation_stage_code, -- LE.001025
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000903
		end as transportation_stage_code, -- LE.001026
		
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000905
		end as storage_calculation_bundle_quantity, -- LE.001035
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
				and for_1047_1.transportation_stage_code = '25' then for_1047_1.transport_route_departure_hub_code
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
				and for_1047_1.transportation_stage_code <> '25' then for_1047_1.transport_route_destination_hub_code
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then for_1047_2.transport_route_destination_hub_code
		end as warehouse_code, -- LE.001047
	
		tr_hub.is_seaport as is_stored_in_russian_port_code, -- LE.001123
		
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.sales_delivery_code
		end as delivery_in_final_release_code, -- LE.001053
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000482
		end as dt_final_release, -- LE.001054
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.SD_000040
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then base.SD_000047
		end as bill_of_lading_code, -- LE.001056
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.SD_000041
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then base.SD_000048
		end as bill_of_lading_number, -- LE.001057
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.SD_000042
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then base.SD_000049
		end as dt_bill_of_lading, -- LE.001058
		
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000067
		end as incoterms_code, -- LE.001062
		
		case
			when base.storage_cost_calculation_type_name in ('Логика Европа') then trscm.calculation_method_code
		end as storage_cost_special_calculation_type_code, -- LE.001065
		
		case
			when base.storage_cost_calculation_type_name in ('Логика Азия') then trwsa.warehouse_storage_area_code
		end as warehouse_storage_area_code, -- LE.001073
				
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк', 'Логика СВХ') then '1121'
			when base.storage_cost_calculation_type_name in ('Логика Европа') then '1521'
			when base.storage_cost_calculation_type_name in ('Логика Азия') then coalesce(zlet43_1.unit_balance_of_storage_agreement_code, zlet43_2.unit_balance_of_storage_agreement_code)
		end as plant_code, -- LE.001078 -- в логике поля LE.001090 это поле используется хардкодом
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк', 'Логика СВХ') then '1120'
			when base.storage_cost_calculation_type_name in ('Логика Европа') then '1520'
			when base.storage_cost_calculation_type_name in ('Логика Азия') then valuar.unit_balance_code
		end as unit_balance_code, -- LE.001077 -- в логике поля LE.001090 это поле используется хардкодом
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then coalesce(ekpa.counterparty_code, vbpa.supplier_code)
		end as creditor_in_shipment_instruction_code, -- LE.001092
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.dt_arrival_to_russian_port
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.likp_lddat
		end as dt_storage_start, -- LE.001070
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.SD_000042
			when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then sbudr_2.dt_transportation_stage_start
		end as dt_shipped_from_warehouse, -- LE.001071

		case
			when base.delivery_for_storage_calculation_code = base.transportation_inbound_delivery_code then null
			else vbak.zznoi
		end as shipment_instruction_number, -- LE.001043
	
		sbudr_2.dt_transportation_stage_start as sbudr_2_dt_transportation_stage_start,
		base.SD_000042,
		base.SD_000649,
		base.SD_000420,
	
		for_1076_1.counterparty_code as for_1076_1_lifnr,
		for_1076_2.counterparty_code as for_1076_2_counterparty_code,
		base.likp_lddat,
		base.dt_transportation_stage_start_p,
		base.dt_transportation_stage_start_r,
		
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.sales_bundle_net_weight
			when base.storage_cost_calculation_type_name in ('Логика Европа', 'Логика Азия', 'Логика СВХ') and zle112t37t3.lifnr is not null then base.sales_bundle_net_weight
			when base.storage_cost_calculation_type_name in ('Логика Европа', 'Логика Азия', 'Логика СВХ') then base.sales_bundle_gross_weight
		end as weight_for_1090_umno,
	
		case
			when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base.ntgew
			when base.storage_cost_calculation_type_name in ('Логика Европа', 'Логика Азия', 'Логика СВХ') and zle112t37t3.lifnr is not null then base.ntgew
			when base.storage_cost_calculation_type_name in ('Логика Европа', 'Логика Азия', 'Логика СВХ') then base.btgew
		end as weight_for_1090_razdel
		
		
----------------------------------- Ниже таблицы ------------------------------------------------------------
	from
		base
	left join dict_dds.tech_zle112t37t3 as zle112t37t3 on
		zle112t37t3.lifnr = base.forwarder_code 
		and zle112t37t3.brutto is null
	

	left join dedopo_2 as dedopo_2 on
		dedopo_2.delivery_code = base.plant_producer_delivery_code
	left join vbak as vbak on
		vbak.vbeln = dedopo_2.sales_document_code

	left join for_1047_1 as for_1047_1 on
		for_1047_1.sales_bundle_code = base.sales_bundle_code
		and for_1047_1.rn = 1
	left join dds.sales_bundle_and_delivery_relationship as for_1047_2 on
		for_1047_2.sales_bundle_code = base.sales_bundle_code
		and for_1047_2.delivery_code = base.delivery_for_storage_calculation_code
		and for_1047_2.is_deleted_code is null
		and base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ')

	left join trscm on
		trscm.counterparty_code = base.forwarder_code
	left join dict_dds.transportation_warehouse_storage_area as trwsa on
		trwsa.plant_code = base.receiving_plant_code
		and trwsa.transport_hub_code = case
										when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
											and for_1047_1.transportation_stage_code = '25' then for_1047_1.transport_route_departure_hub_code
										when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
											and for_1047_1.transportation_stage_code <> '25' then for_1047_1.transport_route_destination_hub_code
										when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then for_1047_2.transport_route_destination_hub_code
									   end
		and trwsa.transportation_stage_code = case
												when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then base.SD_000903
											  end
	left join sbudr_1 on
		sbudr_1.sales_bundle_code = base.sales_bundle_code
		and sbudr_1.delivery_code = base.delivery_for_storage_calculation_code
		and base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ')
		and sbudr_1.rn = 1
	left join dds.sales_bundle_and_delivery_relationship as sbudr_2 on
		sbudr_2.sales_bundle_code = base.sales_bundle_code
		and sbudr_2.batch_code = sbudr_1.batch_code
		and sbudr_2.transportation_stage_code > sbudr_1.transportation_stage_code
		and sbudr_2.transport_route_departure_hub_code = sbudr_1.transport_route_destination_hub_code
		and sbudr_2.dt_transportation_stage_start >= base.likp_lddat
		and sbudr_2.is_deleted_code is null
	-- идут дубли
	left join zlet43_1 on
		zlet43_1.plant_code = base.receiving_plant_code
		and zlet43_1.counterparty_code = base.forwarder_code
		and zlet43_1.rn = 1
	left join dict_dds.map_trader_to_unit_balance_of_storage_agreement as zlet43_2 on
		zlet43_2.plant_code = base.receiving_plant_code
		and zlet43_2.counterparty_code is null
	left join dict_dds.plant_and_subsidiary as pas on
		pas.plant_code = case
								when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк', 'Логика СВХ') then '1121'
								when base.storage_cost_calculation_type_name in ('Логика Европа') then '1521'
								when base.storage_cost_calculation_type_name in ('Логика Азия') then coalesce(zlet43_1.unit_balance_of_storage_agreement_code, zlet43_2.unit_balance_of_storage_agreement_code)
							end
	left join dict_dds.valuation_area as valuar on
		valuar.valuation_area_code = pas.valuation_area_code
	left join ekpa on
		ekpa.objek = case
							when base.delivery_for_storage_calculation_code = base.transportation_inbound_delivery_code then null
							else vbak.zznoi
						end
		and base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')

	left join dds.sales_document_counterparty_role as vbpa on
		vbpa.sales_document_code = case
										when base.delivery_for_storage_calculation_code = base.transportation_inbound_delivery_code then null
										else vbak.zznoi
									  end
		and base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
		and vbpa.counterparty_role_code = case when base.SD_000649 in (
																		select
																			range_low_value
																		from
																			dict_dds.settings_and_parameters_sap
																		where
																			abap_program_code = '/RUSAL/SD4553M'
																			and parameter_code = 'S_PORTZJ'
																			and range_low_value is not null)
												then 'ZJ'
												else 'YP'
											end -- 'ЭФ' = 'YP'
	left join (
			select
				counterparty_code
			from
				dict_dds.tech_additional_transportation_service_calculation_rule
			where
				service_code = 'STO'
				and date_of_rate_determination_rule_code = '3'
			group by
				counterparty_code
				) as for_1076_1 on
		for_1076_1.counterparty_code = coalesce(ekpa.counterparty_code, vbpa.supplier_code)
	left join (
				select
					counterparty_code
				from
					dict_dds.transportation_storage_date_search_method
				where
					storage_date_search_method_code = '1'
				group by
					counterparty_code) as for_1076_2 on
		for_1076_2.counterparty_code = base.forwarder_code
	left join dict_dds.transport_hub as trhu on
		trhu.transport_hub_code = case
										when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
											and for_1047_1.transportation_stage_code = '25' then for_1047_1.transport_route_departure_hub_code
										when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
											and for_1047_1.transportation_stage_code <> '25' then for_1047_1.transport_route_destination_hub_code
										when base.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then for_1047_2.transport_route_destination_hub_code
									end

	left join dict_dds.transport_hub as tr_hub on
		tr_hub.transport_hub_code = case
											when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
												and for_1047_1.transportation_stage_code = '25' then for_1047_1.transport_route_departure_hub_code
											when base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
												and for_1047_1.transportation_stage_code <> '25' then for_1047_1.transport_route_destination_hub_code
										end
		and base.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
)
distributed by (sales_bundle_code);


create temp table base_1_7 on commit drop as ( -- продолжение собирания витрины. основывается на base_1_5. Так делается из-за сложной логики кейсов.
	select
		base_1_5.sales_bundle_code,
		base_1_5.plant_producer_delivery_code,
		base_1_5.plant_producer_delivery_position_code,
		base_1_5.initial_delivery_code,
		base_1_5.material_code,
		base_1_5.dt_shipment,
		base_1_5.railcar_code, 
		base_1_5.transport_bill_code,
		base_1_5.uni,
		base_1_5.material_shape_code,
		base_1_5.dt_arrival_to_russian_port,
		base_1_5.dt_storage_end_in_release,
		base_1_5.transport_type_code,
		base_1_5.etsng_code,
		date_for_vitr.dt_balance as dt_report, -- LE.001069
		base_1_5.sales_bundle_net_weight,
		base_1_5.sales_bundle_gross_weight,
		base_1_5.batch_code,
		base_1_5.dt_arrival,
		base_1_5.receiving_plant_code,
		base_1_5.sales_delivery_code,
		base_1_5.transportation_inbound_delivery_code,
		base_1_5.delivery_for_storage_calculation_code,
		base_1_5.transportation_inbound_delivery_position_code,
		base_1_5.delivery_position_for_storage_calculation_code,
		base_1_5.forwarder_code,
		base_1_5.storage_cost_calculation_type_name,
		base_1_5.transport_departure_hub_code,
		base_1_5.transport_destination_hub_code,
		base_1_5.transportation_outbound_delivery_code,
		base_1_5.transportation_outbound_delivery_position_code,
		base_1_5.is_final_transportation_stage_code,
		base_1_5.transportation_stage_code,
		base_1_5.storage_calculation_bundle_quantity,
		base_1_5.warehouse_code,
		base_1_5.is_stored_in_russian_port_code,
		base_1_5.delivery_in_final_release_code,
		base_1_5.dt_final_release,
		base_1_5.bill_of_lading_code,
		base_1_5.bill_of_lading_number,
		base_1_5.dt_bill_of_lading,
		base_1_5.incoterms_code,
		base_1_5.storage_cost_special_calculation_type_code,
		base_1_5.warehouse_storage_area_code,
		base_1_5.plant_code,
		base_1_5.unit_balance_code,
		base_1_5.creditor_in_shipment_instruction_code,
		base_1_5.dt_storage_start,
		base_1_5.dt_shipped_from_warehouse,
		base_1_5.dt_transportation_stage_start_p,
		
		case
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
				and base_1_5.SD_000042 is not null
				and base_1_5.SD_000042 <= date_for_vitr.dt_balance then base_1_5.SD_000042
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then date_for_vitr.dt_balance
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ')
				and sbudr_2_dt_transportation_stage_start is not null
				and sbudr_2_dt_transportation_stage_start <= date_for_vitr.dt_balance then sbudr_2_dt_transportation_stage_start
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then date_for_vitr.dt_balance
		end as dt_storage_end, -- LE.001072
		
		
		case
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
				and base_1_5.SD_000042 is not null
				and base_1_5.SD_000042 <= date_for_vitr.dt_balance then base_1_5.SD_000042 - base_1_5.dt_arrival_to_russian_port + 1
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then date_for_vitr.dt_balance - base_1_5.dt_arrival_to_russian_port + 1
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ')
				and sbudr_2_dt_transportation_stage_start is not null
				and sbudr_2_dt_transportation_stage_start <= date_for_vitr.dt_balance then sbudr_2_dt_transportation_stage_start - base_1_5.likp_lddat + 1
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ') then date_for_vitr.dt_balance - base_1_5.likp_lddat + 1
		end as storage_duration_total_calendar_days, -- LE.001086
		
		base_1_5.shipment_instruction_number,
			
		case
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
				and base_1_5.for_1076_1_lifnr is not null then base_1_5.dt_arrival_to_russian_port
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк')
				and base_1_5.SD_000042 is not null
				and base_1_5.SD_000042 <= date_for_vitr.dt_balance then base_1_5.SD_000042
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then date_for_vitr.dt_balance
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа')
				and sbudr_2_dt_transportation_stage_start is not null
				and sbudr_2_dt_transportation_stage_start <= date_for_vitr.dt_balance then sbudr_2_dt_transportation_stage_start
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then date_for_vitr.dt_balance
			when base_1_5.storage_cost_calculation_type_name in ('Логика СВХ')
				and for_1076_2_counterparty_code is not null then base_1_5.likp_lddat
			when base_1_5.storage_cost_calculation_type_name in ('Логика СВХ')
				and sbudr_2_dt_transportation_stage_start is not null
				and sbudr_2_dt_transportation_stage_start <= date_for_vitr.dt_balance then sbudr_2_dt_transportation_stage_start
			when base_1_5.storage_cost_calculation_type_name in ('Логика СВХ') then date_for_vitr.dt_balance
		end as dt_for_price_search_in_purchase_contract, -- LE.001076
	
		case
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base_1_5.SD_000649
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа')
				and base_1_5.SD_000049 < date_for_vitr.dt_balance then base_1_5.SD_000054
			when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then base_1_5.SD_000044
		end as port_of_discharge_code, -- LE.001044
	
		case
			when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика Азия', 'Логика СВХ') then 'S49'
			when base_1_5.storage_cost_calculation_type_name = 'Логика РФ-балк'
				and stmatl.storage_method_code = '1' then 'S49/3'
			when base_1_5.storage_cost_calculation_type_name = 'Логика РФ-балк' then 'S49/2'
			when base_1_5.storage_cost_calculation_type_name = 'Логика Европа'
				and for_1082_1.range_low_value is not null then for_1082_2.res
			when base_1_5.storage_cost_calculation_type_name = 'Логика Европа' then for_1082_3.res
		end as service_number,-- LE.001082 -- в логике поля LE.001090 это поле используется хардкодом
	
		base_1_5.weight_for_1090_umno,
		base_1_5.weight_for_1090_razdel,
		base_1_5.SD_000420, base_1_5.id_for_unique,
		row_number() over(partition by base_1_5.id_for_unique, date_for_vitr.dt_balance order by base_1_5.lddat_4798 desc, base_1_5.vbeln_4798 desc) as unique_row
	
----------------------------------- Ниже таблицы ------------------------------------------------------------
	from
		base_1_5
	join date_for_vitr on 
		date_for_vitr.dt_balance between base_1_5.dt_transportation_stage_start_p and base_1_5.dt_transportation_stage_start_r -- Размножение на даты
	left join dict_dds.location_sales as losa on
		base_1_5.storage_cost_calculation_type_name = 'Логика РФ-балк'
		and losa.transport_hub_code = case
										when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base_1_5.SD_000649
										when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') and base_1_5.SD_000049 < date_for_vitr.dt_balance then base_1_5.SD_000054
										when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then base_1_5.SD_000044 
									  end
		and base_1_5.storage_cost_calculation_type_name = 'Логика РФ-балк'
	left join dict_dds.storage_method_at_tsw_location as stmatl on
		base_1_5.storage_cost_calculation_type_name = 'Логика РФ-балк'
		and stmatl.tsw_location_code = losa.location_code
		and stmatl.material_shape_code = case
											when base_1_5.storage_cost_calculation_type_name in ('Логика РФ-контейнеры', 'Логика РФ-балк') then base_1_5.SD_000649
											when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') and base_1_5.SD_000049 < date_for_vitr.dt_balance then base_1_5.SD_000054
											when base_1_5.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа') then base_1_5.SD_000044
										  end
	
	left join for_1082_1 on
		storage_cost_calculation_type_name = 'Логика Европа'
		and for_1082_1.range_low_value = base_1_5.material_shape_code
	left join for_1082_2 on
		storage_cost_calculation_type_name = 'Логика Европа'
		and for_1082_2.rn = 1
	left join for_1082_3 on
		storage_cost_calculation_type_name = 'Логика Европа'
		and for_1082_3.rn = 1
	left join dict_dds.transportation_warehouse_storage_area as trwsa on
		trwsa.plant_code = base_1_5.receiving_plant_code
		and trwsa.transport_hub_code = base_1_5.warehouse_code
		and trwsa.transportation_stage_code = base_1_5.transportation_stage_code
where (base_1_5.wwgsg_01 is null or (base_1_5.wwgsg_01 is not null and coalesce(base_1_5.wwgsg_01_date, '99991231'::date) >= date_for_vitr.dt_balance))
-- второя часть ограничений для поля 1016

and (base_1_5.lddat_4798 <= date_for_vitr.dt_balance or base_1_5.wwgsg_01 is not null)
-- третья часть ограничений для поля 1016
) distributed by (sales_bundle_code);



insert into dm_calc.storage_sales_bundles_weight (
	sales_bundle_code,
	plant_producer_delivery_code,
	plant_producer_delivery_position_code,
	initial_delivery_code,
	material_code,
	dt_shipment,
	railcar_code,
	transport_bill_code,
	uni,
	material_shape_code,
	dt_arrival_to_russian_port,
	dt_storage_end_in_release,
	transport_type_code,
	etsng_code,
	dt_report,
	sales_bundle_net_weight,
	sales_bundle_gross_weight,
	batch_code,
	dt_arrival,
	receiving_plant_code,
	sales_delivery_code,
	transportation_inbound_delivery_code,
	delivery_for_storage_calculation_code,
	transportation_inbound_delivery_position_code,
	delivery_position_for_storage_calculation_code,
	forwarder_code,
	storage_cost_calculation_type_name,
	transport_departure_hub_code,
	transport_destination_hub_code,
	transportation_outbound_delivery_code,
	transportation_outbound_delivery_position_code,
	is_final_transportation_stage_code,
	transportation_stage_code,
	storage_calculation_bundle_quantity,
	warehouse_code,
	is_stored_in_russian_port_code,
	delivery_in_final_release_code,
	dt_final_release,
	bill_of_lading_code,
	bill_of_lading_number,
	dt_bill_of_lading,
	incoterms_code,
	storage_cost_special_calculation_type_code,
	warehouse_storage_area_code,
	plant_code,
	unit_balance_code,
	creditor_in_shipment_instruction_code,
	dt_storage_start,
	dt_shipped_from_warehouse,
	dt_storage_end,
	storage_duration_total_calendar_days,
	shipment_instruction_number,
	dt_for_price_search_in_purchase_contract,
	port_of_discharge_code,
	service_number,
	weight_for_1090_umno,
	weight_for_1090_razdel,
	remote_warehouse_code,
	dt_transportation_stage_start_p,
	dt_transportation_stage_start_r,
	rn
)
select
	base_1_7.sales_bundle_code,
	base_1_7.plant_producer_delivery_code,
	base_1_7.plant_producer_delivery_position_code,
	base_1_7.initial_delivery_code,
	base_1_7.material_code,
	base_1_7.dt_shipment,
	base_1_7.railcar_code,
	base_1_7.transport_bill_code,
	base_1_7.uni,
	base_1_7.material_shape_code,
	base_1_7.dt_arrival_to_russian_port,
	base_1_7.dt_storage_end_in_release,
	base_1_7.transport_type_code,
	base_1_7.etsng_code,
	base_1_7.dt_report,
	base_1_7.sales_bundle_net_weight,
	base_1_7.sales_bundle_gross_weight,
	base_1_7.batch_code,
	base_1_7.dt_arrival,
	base_1_7.receiving_plant_code,
	base_1_7.sales_delivery_code,
	base_1_7.transportation_inbound_delivery_code,
	base_1_7.delivery_for_storage_calculation_code,
	base_1_7.transportation_inbound_delivery_position_code,
	base_1_7.delivery_position_for_storage_calculation_code,
	base_1_7.forwarder_code,
	base_1_7.storage_cost_calculation_type_name,
	base_1_7.transport_departure_hub_code,
	base_1_7.transport_destination_hub_code,
	base_1_7.transportation_outbound_delivery_code,
	base_1_7.transportation_outbound_delivery_position_code,
	base_1_7.is_final_transportation_stage_code,
	base_1_7.transportation_stage_code,
	base_1_7.storage_calculation_bundle_quantity,
	base_1_7.warehouse_code,
	base_1_7.is_stored_in_russian_port_code,
	base_1_7.delivery_in_final_release_code,
	base_1_7.dt_final_release,
	base_1_7.bill_of_lading_code,
	base_1_7.bill_of_lading_number,
	base_1_7.dt_bill_of_lading,
	base_1_7.incoterms_code,
	base_1_7.storage_cost_special_calculation_type_code,
	base_1_7.warehouse_storage_area_code,
	base_1_7.plant_code,
	base_1_7.unit_balance_code,
	base_1_7.creditor_in_shipment_instruction_code,
	base_1_7.dt_storage_start,
	base_1_7.dt_shipped_from_warehouse,
	base_1_7.dt_storage_end,
	base_1_7.storage_duration_total_calendar_days,
	base_1_7.shipment_instruction_number,
	base_1_7.dt_for_price_search_in_purchase_contract,
	base_1_7.port_of_discharge_code,
	base_1_7.service_number,
	base_1_7.weight_for_1090_umno,
	nullif(base_1_7.weight_for_1090_razdel, 0) as weight_for_1090_razdel,
	base_1_7.SD_000420 as remote_warehouse_code, -- LE.001126
	case when base_1_7.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ')
		then base_1_7.dt_transportation_stage_start_p
	end as dt_transportation_stage_start_p, -- LE.001130
	case when base_1_7.storage_cost_calculation_type_name in ('Логика Азия', 'Логика Европа', 'Логика СВХ')
		then base_1_7.dt_arrival
	end as dt_transportation_stage_start_r, -- LE.001131
--	row_number() over() as rn
	base_1_7.id_for_unique || base_1_7.dt_report ::text as rn
from base_1_7
where unique_row = 1;
-- четвертая часть ограничений для поля 1016
	-- Первая часть скрипта заканчивается.
------------------




