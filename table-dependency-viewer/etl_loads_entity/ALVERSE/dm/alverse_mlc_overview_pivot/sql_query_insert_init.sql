create temporary table sales_alverse_mlc on commit drop
as (
select sales_order_in_shipment as sales_request_code,
string_agg(distinct customer_name, '; ' order by customer_name) as customer_name,
string_agg(distinct contract_name, '; ' order by contract_name) as contract_name,
string_agg(distinct delivery_basis, '; ' order by delivery_basis) as delivery_basis,
string_agg(distinct delivery_point_name, '; ' order by delivery_point_name) as delivery_point_name,
string_agg(distinct end_user_name, '; ' order by end_user_name) as end_user_name,
string_agg(distinct frame_contract_code, '; ' order by frame_contract_code) as frame_contract_code,
string_agg(distinct delivery_region_name, '; ' order by delivery_region_name) as delivery_region_name,
string_agg(distinct country_of_end_user_name, '; ' order by country_of_end_user_name) as country_of_end_user_name,
string_agg(distinct material_shape_name_full, '; ' order by material_shape_name_full) as material_shape_name_full,
string_agg(distinct plant_producer_name, '; ' order by plant_producer_name) as plant_producer_name,
string_agg(distinct material_aggr_name, '; ' order by material_aggr_name) as material_aggr_name,
string_agg(distinct dimensions_unit, '; ' order by dimensions_unit) as dimensions_unit,
string_agg(distinct material_specification_name, '; ' order by material_specification_name) as material_specification_name,
string_agg(distinct grade_name, '; ' order by grade_name) as grade_name,
string_agg(distinct shipment_period_preferred, '; ' order by shipment_period_preferred) as shipment_period_preferred,
string_agg(distinct quantity_shipped::text, '; ' order by quantity_shipped::text) as quantity_shipped,
string_agg(distinct quantity_ordered::text, '; ' order by quantity_ordered::text) as quantity_ordered,
string_agg(distinct port_of_loading_name, '; ' order by port_of_loading_name) as port_of_loading_name,
string_agg(distinct forwarder_name, '; ' order by forwarder_name) as forwarder_name,
string_agg(distinct transport_railcar_type_name, '; ' order by transport_railcar_type_name) as transport_railcar_type_name,
string_agg(distinct consignee_name, '; ' order by consignee_name) as consignee_name,
string_agg(distinct destination_station_in_shipment_name, '; ' order by destination_station_in_shipment_name) as destination_station_in_shipment_name,
string_agg(distinct vessel_and_voyage_actual_search_name, '; ' order by vessel_and_voyage_actual_search_name) as vessel_and_voyage_actual_search_name,
string_agg(distinct invoice_provisional_number, '; ' order by invoice_provisional_number) as invoice_provisional_number,
string_agg(distinct invoice_final_number, '; ' order by invoice_final_number) as invoice_final_number,
string_agg(distinct weight_gross::text, '; ' order by weight_gross::text) as weight_gross,
string_agg(distinct weight_net::text, '; ' order by weight_net::text) as weight_net,
string_agg(distinct weight_net_with_wirerod::text, '; ' order by weight_net_with_wirerod::text) as weight_net_with_wirerod,
string_agg(distinct weight_strip::text, '; ' order by weight_strip::text) as weight_strip,
string_agg(distinct dt_collection::text, '; ' order by dt_collection::text) as dt_collection
FROM dm.sales_alverse_mlc
where sales_order_in_shipment in (select sales_request_code from dm.production_aluminium_casting_schedule where deleted_flag = False)
and sales_order_in_shipment in (select sales_order_in_shipment from dm.accounts_receivaible_sales_alverse where deleted_flag = False)
and deleted_flag = False
group by sales_order_in_shipment
) distributed by (sales_request_code);


create temporary table production_aluminium_casting_schedule on commit drop
as (
select sales_request_code as sales_request_code,
string_agg(distinct plant_name, '; ' order by plant_name) as plant_name,
string_agg(distinct casting_unit_name, '; ' order by casting_unit_name) as casting_unit_name,
string_agg(distinct casting_department_name, '; ' order by casting_department_name) as casting_department_name,
string_agg(distinct dt_casting_plan_start::text, '; ' order by dt_casting_plan_start::text) as dt_casting_plan_start,
string_agg(distinct dt_casting_plan_end::text, '; ' order by dt_casting_plan_end::text) as dt_casting_plan_end,
string_agg(distinct dt_warehouse_acceptance_plan_start::text, '; ' order by dt_warehouse_acceptance_plan_start::text) as dt_warehouse_acceptance_plan_start,
string_agg(distinct dt_warehouse_acceptance_plan_end::text, '; ' order by dt_warehouse_acceptance_plan_end::text) as dt_warehouse_acceptance_plan_end,
string_agg(distinct accepted_plan_weight::text, '; ' order by accepted_plan_weight::text) as accepted_plan_weight
FROM dm.production_aluminium_casting_schedule
where sales_request_code in (select sales_order_in_shipment from dm.sales_alverse_mlc where deleted_flag = False)
and sales_request_code in (select sales_order_in_shipment from dm.accounts_receivaible_sales_alverse where deleted_flag = False)
and deleted_flag = False
group by sales_request_code
) distributed by (sales_request_code);

create temporary table accounts_receivaible_sales_alverse on commit drop
as (
select sales_order_in_shipment as sales_request_code,
string_agg(distinct dt_report::text, '; ' order by dt_report::text) as dt_report,
string_agg(distinct dt_posting::text, '; ' order by dt_posting::text) as dt_posting,
string_agg(distinct dt_overdue::text, '; ' order by dt_overdue::text) as dt_overdue,
string_agg(distinct dt_clearing::text, '; ' order by dt_clearing::text) as dt_clearing,
string_agg(distinct unit_balance_name, '; ' order by unit_balance_name) as unit_balance_name,
string_agg(distinct counterparty_full_name, '; ' order by counterparty_full_name) as counterparty_full_name,
string_agg(distinct external_contract_number, '; ' order by external_contract_number) as external_contract_number,
string_agg(distinct terms_of_payment_name, '; ' order by terms_of_payment_name) as terms_of_payment_name,
string_agg(distinct responsibility_center_name, '; ' order by responsibility_center_name) as responsibility_center_name,
string_agg(distinct contract_supervisor_name, '; ' order by contract_supervisor_name) as contract_supervisor_name,
string_agg(distinct debt_balance_subposition_document_currency_amount::text, '; ' order by debt_balance_subposition_document_currency_amount::text) as debt_balance_subposition_document_currency_amount,
string_agg(distinct document_currency_code, '; ' order by document_currency_code) as document_currency_code
FROM dm.accounts_receivaible_sales_alverse
where sales_order_in_shipment in (select sales_order_in_shipment from dm.sales_alverse_mlc where deleted_flag = False)
and sales_order_in_shipment in (select sales_request_code from dm.production_aluminium_casting_schedule where deleted_flag = False)
and deleted_flag = False
group by sales_order_in_shipment
) distributed by (sales_request_code);




insert into dm.alverse_mlc_overview_pivot (
	sales_request_code,
	dwh_excel_column_code,
	dwh_table_column_name,
	dwh_table_column_code,
	alverse_business_group_name,
	alverse_business_group_code,
	alverse_business_subgroup_name,
	alverse_business_subgroup_code,
	alverse_concatenated_by_sales_request_field_values_name
)

select
	sales_request_code,
	'SD.000037' as dwh_excel_column_code,
	'Покупатель' as dwh_table_column_name,
	'customer_name' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'Заключили контракт' as alverse_business_subgroup_name,
	'1' as alverse_business_subgroup_code,
	customer_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000038' as dwh_excel_column_code,
	'Контракт' as dwh_table_column_name,
	'contract_name' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'Заключили контракт' as alverse_business_subgroup_name,
	'3' as alverse_business_subgroup_code,
	contract_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000067' as dwh_excel_column_code,
	'Базис поставки' as dwh_table_column_name,
	'delivery_basis' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'География контракта' as alverse_business_subgroup_name,
	'5' as alverse_business_subgroup_code,
	delivery_basis
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000068' as dwh_excel_column_code,
	'Пункт доставки по инкотермс' as dwh_table_column_name,
	'delivery_point_name' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'География контракта' as alverse_business_subgroup_name,
	'6' as alverse_business_subgroup_code,
	delivery_point_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000164' as dwh_excel_column_code,
	'Потребитель' as dwh_table_column_name,
	'end_user_name' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'Заключили контракт' as alverse_business_subgroup_name,
	'2' as alverse_business_subgroup_code,
	end_user_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000246' as dwh_excel_column_code,
	'Рамочный контракт (код)' as dwh_table_column_name,
	'frame_contract_code' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'Заключили контракт' as alverse_business_subgroup_name,
	'4' as alverse_business_subgroup_code,
	frame_contract_code
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000338' as dwh_excel_column_code,
	'Регион поставки по контракту' as dwh_table_column_name,
	'delivery_region_name' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'География контракта' as alverse_business_subgroup_name,
	'7' as alverse_business_subgroup_code,
	delivery_region_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000601' as dwh_excel_column_code,
	'Страна конечного потребителя' as dwh_table_column_name,
	'country_of_end_user_name' as dwh_table_column_code,
	'Контракт' as alverse_business_group_name,
	'1' as alverse_business_group_code,
	'География контракта' as alverse_business_subgroup_name,
	'8' as alverse_business_subgroup_code,
	country_of_end_user_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000180' as dwh_excel_column_code,
	'Форма' as dwh_table_column_name,
	'material_shape_name_full' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Материал заказа' as alverse_business_subgroup_name,
	'2' as alverse_business_subgroup_code,
	material_shape_name_full
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000007' as dwh_excel_column_code,
	'Завод' as dwh_table_column_name,
	'plant_producer_name' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Материал заказа' as alverse_business_subgroup_name,
	'1' as alverse_business_subgroup_code,
	plant_producer_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000016' as dwh_excel_column_code,
	'Материал' as dwh_table_column_name,
	'material_aggr_name' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Материал заказа' as alverse_business_subgroup_name,
	'4' as alverse_business_subgroup_code,
	material_aggr_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000079' as dwh_excel_column_code,
	'Размер единицы готовой продукции' as dwh_table_column_name,
	'dimensions_unit' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Материал заказа' as alverse_business_subgroup_name,
	'5' as alverse_business_subgroup_code,
	dimensions_unit
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000089' as dwh_excel_column_code,
	'Спецификация' as dwh_table_column_name,
	'material_specification_name' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Материал заказа' as alverse_business_subgroup_name,
	'6' as alverse_business_subgroup_code,
	material_specification_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000145' as dwh_excel_column_code,
	'Марка' as dwh_table_column_name,
	'grade_name' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Материал заказа' as alverse_business_subgroup_name,
	'3' as alverse_business_subgroup_code,
	grade_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000150' as dwh_excel_column_code,
	'Желаемый период отгрузки' as dwh_table_column_name,
	'shipment_period_preferred' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Желаемые сроки отгрузки по заявкам' as alverse_business_subgroup_name,
	'9' as alverse_business_subgroup_code,
	shipment_period_preferred
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000165' as dwh_excel_column_code,
	'Отгруженное количество' as dwh_table_column_name,
	'quantity_shipped' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Количество заказа' as alverse_business_subgroup_name,
	'8' as alverse_business_subgroup_code,
	quantity_shipped
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000166' as dwh_excel_column_code,
	'Запланированное количество' as dwh_table_column_name,
	'quantity_ordered' as dwh_table_column_code,
	'Заказ' as alverse_business_group_name,
	'2' as alverse_business_group_code,
	'Количество заказа' as alverse_business_subgroup_name,
	'7' as alverse_business_subgroup_code,
	quantity_ordered
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.001192' as dwh_excel_column_code,
	'Завод' as dwh_table_column_name,
	'plant_name' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Место производства' as alverse_business_subgroup_name,
	'1' as alverse_business_subgroup_code,
	plant_name
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001193' as dwh_excel_column_code,
	'ЛА' as dwh_table_column_name,
	'casting_unit_name' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Место производства' as alverse_business_subgroup_name,
	'2' as alverse_business_subgroup_code,
	casting_unit_name
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001194' as dwh_excel_column_code,
	'ЛО' as dwh_table_column_name,
	'casting_department_name' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Место производства' as alverse_business_subgroup_name,
	'3' as alverse_business_subgroup_code,
	casting_department_name
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001195' as dwh_excel_column_code,
	'Дата начала первой ходки' as dwh_table_column_name,
	'dt_casting_plan_start' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Плановые даты производства' as alverse_business_subgroup_name,
	'4' as alverse_business_subgroup_code,
	dt_casting_plan_start
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001196' as dwh_excel_column_code,
	'Дата окончания последней ходки' as dwh_table_column_name,
	'dt_casting_plan_end' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Плановые даты производства' as alverse_business_subgroup_name,
	'5' as alverse_business_subgroup_code,
	dt_casting_plan_end
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001197' as dwh_excel_column_code,
	'Дата передачи на СГП первой ходки' as dwh_table_column_name,
	'dt_warehouse_acceptance_plan_start' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Плановые даты производства' as alverse_business_subgroup_name,
	'6' as alverse_business_subgroup_code,
	dt_warehouse_acceptance_plan_start
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001198' as dwh_excel_column_code,
	'Дата передачи на СГП последней ходки' as dwh_table_column_name,
	'dt_warehouse_acceptance_plan_end' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Плановые даты производства' as alverse_business_subgroup_name,
	'7' as alverse_business_subgroup_code,
	dt_warehouse_acceptance_plan_end
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.001199' as dwh_excel_column_code,
	'Принято в план' as dwh_table_column_name,
	'accepted_plan_weight' as dwh_table_column_code,
	'Производство/План' as alverse_business_group_name,
	'3' as alverse_business_group_code,
	'Запланированное кол-во' as alverse_business_subgroup_name,
	'8' as alverse_business_subgroup_code,
	accepted_plan_weight
from
	production_aluminium_casting_schedule
union all
select
	sales_request_code,
	'SD.000009' as dwh_excel_column_code,
	'Направление' as dwh_table_column_name,
	'port_of_loading_name' as dwh_table_column_code,
	'Логистика' as alverse_business_group_name,
	'4' as alverse_business_group_code,
	'Экспедитор, грузополучатель, виды транспорта' as alverse_business_subgroup_name,
	'1' as alverse_business_subgroup_code,
	port_of_loading_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000021' as dwh_excel_column_code,
	'Экспедитор' as dwh_table_column_name,
	'forwarder_name' as dwh_table_column_code,
	'Логистика' as alverse_business_group_name,
	'4' as alverse_business_group_code,
	'Экспедитор, грузополучатель, виды транспорта' as alverse_business_subgroup_name,
	'2' as alverse_business_subgroup_code,
	forwarder_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000029' as dwh_excel_column_code,
	'Тип вагона' as dwh_table_column_name,
	'transport_railcar_type_name' as dwh_table_column_code,
	'Логистика' as alverse_business_group_name,
	'4' as alverse_business_group_code,
	'Экспедитор, грузополучатель, виды транспорта' as alverse_business_subgroup_name,
	'3' as alverse_business_subgroup_code,
	transport_railcar_type_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000081' as dwh_excel_column_code,
	'Грузополучатель' as dwh_table_column_name,
	'consignee_name' as dwh_table_column_code,
	'Логистика' as alverse_business_group_name,
	'4' as alverse_business_group_code,
	'Экспедитор, грузополучатель, виды транспорта' as alverse_business_subgroup_name,
	'4' as alverse_business_subgroup_code,
	consignee_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000113' as dwh_excel_column_code,
	'Станция назначения в отгрузке' as dwh_table_column_name,
	'destination_station_in_shipment_name' as dwh_table_column_code,
	'Логистика' as alverse_business_group_name,
	'4' as alverse_business_group_code,
	'Экспедитор, грузополучатель, виды транспорта' as alverse_business_subgroup_name,
	'5' as alverse_business_subgroup_code,
	destination_station_in_shipment_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000608' as dwh_excel_column_code,
	'Судно / номер рейса (факт)' as dwh_table_column_name,
	'vessel_and_voyage_actual_search_name' as dwh_table_column_code,
	'Логистика' as alverse_business_group_name,
	'4' as alverse_business_group_code,
	'Экспедитор, грузополучатель, виды транспорта' as alverse_business_subgroup_name,
	'6' as alverse_business_subgroup_code,
	vessel_and_voyage_actual_search_name
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.001200' as dwh_excel_column_code,
	'Период, на конец которого рассчитано сальдо' as dwh_table_column_name,
	'dt_report' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Бух.инфо (отчет.дата, счет)' as alverse_business_subgroup_name,
	'1' as alverse_business_subgroup_code,
	dt_report
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001201' as dwh_excel_column_code,
	'Дата проводки бухдокумента' as dwh_table_column_name,
	'dt_posting' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Общие данные инвойса' as alverse_business_subgroup_name,
	'2' as alverse_business_subgroup_code,
	dt_posting
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001202' as dwh_excel_column_code,
	'Дата просрочки' as dwh_table_column_name,
	'dt_overdue' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Сроки ДЗ' as alverse_business_subgroup_name,
	'3' as alverse_business_subgroup_code,
	dt_overdue
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001203' as dwh_excel_column_code,
	'Дата выравнивания' as dwh_table_column_name,
	'dt_clearing' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Сроки ДЗ' as alverse_business_subgroup_name,
	'4' as alverse_business_subgroup_code,
	dt_clearing
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001204' as dwh_excel_column_code,
	'Название БЕ' as dwh_table_column_name,
	'unit_balance_name' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Стороны контракта по ДЗ' as alverse_business_subgroup_name,
	'5' as alverse_business_subgroup_code,
	unit_balance_name
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001205' as dwh_excel_column_code,
	'Название кредитора' as dwh_table_column_name,
	'counterparty_full_name' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Стороны контракта по ДЗ' as alverse_business_subgroup_name,
	'6' as alverse_business_subgroup_code,
	counterparty_full_name
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001206' as dwh_excel_column_code,
	'Внешний номер договора' as dwh_table_column_name,
	'external_contract_number' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Стороны контракта по ДЗ' as alverse_business_subgroup_name,
	'7' as alverse_business_subgroup_code,
	external_contract_number
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001207' as dwh_excel_column_code,
	'Наименование условия платежа' as dwh_table_column_name,
	'terms_of_payment_name' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Стороны контракта по ДЗ' as alverse_business_subgroup_name,
	'8' as alverse_business_subgroup_code,
	terms_of_payment_name
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001208' as dwh_excel_column_code,
	'Название ЦО' as dwh_table_column_name,
	'responsibility_center_name' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Ответственное подразделение' as alverse_business_subgroup_name,
	'9' as alverse_business_subgroup_code,
	responsibility_center_name
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001209' as dwh_excel_column_code,
	'Куратор (ФИО)' as dwh_table_column_name,
	'contract_supervisor_name' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Ответственное подразделение' as alverse_business_subgroup_name,
	'10' as alverse_business_subgroup_code,
	contract_supervisor_name
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001210' as dwh_excel_column_code,
	'Остаток КЗ ВД' as dwh_table_column_name,
	'debt_balance_subposition_document_currency_amount' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Сумма задолженности' as alverse_business_subgroup_name,
	'11' as alverse_business_subgroup_code,
	debt_balance_subposition_document_currency_amount
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.001211' as dwh_excel_column_code,
	'Валюта бухдокумента' as dwh_table_column_name,
	'document_currency_code' as dwh_table_column_code,
	'Дебиторка' as alverse_business_group_name,
	'5' as alverse_business_group_code,
	'Общие данные инвойса' as alverse_business_subgroup_name,
	'12' as alverse_business_subgroup_code,
	document_currency_code
from
	accounts_receivaible_sales_alverse
union all
select
	sales_request_code,
	'SD.000167' as dwh_excel_column_code,
	'Provisional invoice' as dwh_table_column_name,
	'invoice_provisional_number' as dwh_table_column_code,
	'Реализация' as alverse_business_group_name,
	'6' as alverse_business_group_code,
	'Инвойс' as alverse_business_subgroup_name,
	'1' as alverse_business_subgroup_code,
	invoice_provisional_number
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000170' as dwh_excel_column_code,
	'Final Invoice' as dwh_table_column_name,
	'invoice_final_number' as dwh_table_column_code,
	'Реализация' as alverse_business_group_name,
	'6' as alverse_business_group_code,
	'Инвойс' as alverse_business_subgroup_name,
	'2' as alverse_business_subgroup_code,
	invoice_final_number
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000005' as dwh_excel_column_code,
	'Заказ ЦК в отгрузке' as dwh_table_column_name,
	'sales_order_in_shipment' as dwh_table_column_code,
	null as alverse_business_group_name,
	'99' as alverse_business_group_code,
	null as alverse_business_subgroup_name,
	'99' as alverse_business_subgroup_code,
	sales_request_code
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000031' as dwh_excel_column_code,
	'Вес брутто' as dwh_table_column_name,
	'weight_gross' as dwh_table_column_code,
	null as alverse_business_group_name,
	'99' as alverse_business_group_code,
	null as alverse_business_subgroup_name,
	'99' as alverse_business_subgroup_code,
	weight_gross
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000032' as dwh_excel_column_code,
	'Вес нетто' as dwh_table_column_name,
	'weight_net' as dwh_table_column_code,
	null as alverse_business_group_name,
	'99' as alverse_business_group_code,
	null as alverse_business_subgroup_name,
	'99' as alverse_business_subgroup_code,
	weight_net
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000033' as dwh_excel_column_code,
	'Вес Н&K' as dwh_table_column_name,
	'weight_net_with_wirerod' as dwh_table_column_code,
	null as alverse_business_group_name,
	'99' as alverse_business_group_code,
	null as alverse_business_subgroup_name,
	'99' as alverse_business_subgroup_code,
	weight_net_with_wirerod
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000090' as dwh_excel_column_code,
	'Вес ленты' as dwh_table_column_name,
	'weight_strip' as dwh_table_column_code,
	null as alverse_business_group_name,
	'99' as alverse_business_group_code,
	null as alverse_business_subgroup_name,
	'99' as alverse_business_subgroup_code,
	weight_strip
from
	sales_alverse_mlc
union all
select
	sales_request_code,
	'SD.000112' as dwh_excel_column_code,
	'Дата комплектования' as dwh_table_column_name,
	'dt_collection' as dwh_table_column_code,
	null as alverse_business_group_name,
	'99' as alverse_business_group_code,
	null as alverse_business_subgroup_name,
	'99' as alverse_business_subgroup_code,
	dt_collection
from
	sales_alverse_mlc;
