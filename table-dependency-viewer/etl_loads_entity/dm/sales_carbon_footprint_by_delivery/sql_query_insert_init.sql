insert into dm.sales_carbon_footprint_by_delivery (
sales_delivery_code, 
plant_name, 
dt_shipment, 
weight_net,
weight_net_with_wirerod,
contract_name, lot_delivery_basis_code,
lot_delivery_point_name, 
uni,
invoice_provisional_number, 
customer_code,
customer_name, 
melt_name, melt_weight,
melt_carbon_emission_weight,
delivery_carbon_emission_weight, 
delivery_carbon_emission_per_ton_weight,
bundle_by_delivery_and_melt_total_weight, 
carbon_emission_equivalent_scope1_per_ton_melt_weight, 
carbon_emission_equivalent_scope2_per_ton_melt_weight,
carbon_emission_equivalent_scope3_per_ton_melt_weight, 
carbon_emission_equivalent_scope1_per_ton_delivery_weight, 
carbon_emission_equivalent_scope2_per_ton_delivery_weight, 
carbon_emission_equivalent_scope3_per_ton_delivery_weight,
dt_invoice_provisional, dt_invoice_provisional_mmyyyy, 
invoice_provisional_code, vat_invoice_of_invoice_provisional_code 
)
with carbon_footprint_by_bundle as(
select
melt_code,
melt_name,
sales_delivery_code,
sum("sales_bundle_net_weight") as sum_sales_bundle_net_weight
from dm_calc.carbon_footprint_by_bundle_sd0010 
group by melt_code,
melt_name,
sales_delivery_code),
	carbon_emission_full_scope_weight_cte as(select 
sum(carbon_emission_full_scope_weight::numeric) as carbon_emission_full_scope_weight , 
sales_delivery_code 
from dm_calc.carbon_footprint_by_melt_sd0015
group by sales_delivery_code)
(SELECT 
t0."delivery_number_sales" as sales_delivery_code,
t0."plant_producer_name" as plant_name,
t0."dt_shipment" as dt_shipment,
coalesce (t0."weight_net",0) as weight_net,
coalesce (t0."weight_net_with_wirerod",0) as weight_net_with_wirerod,
t0."contract_name" as contract_name,
t0."lot_delivery_basis_code" as lot_delivery_basis_code,
t0."lot_delivery_point_name" as lot_delivery_point_name,
t0."uni" as uni,
t0."invoice_provisional_number" as invoice_provisional_number,
t0."customer_for_reporting_code" as customer_code,
t0."customer_for_reporting_name" as customer_name,
t1."melt_name" as melt_name, 
(t3."melt_weight"/1000) as melt_weight, 
t3.melt_carbon_emission_weight as melt_carbon_emission_weight,
swc.carbon_emission_full_scope_weight::numeric as delivery_carbon_emission_weight,
(carbon_emission_equivalent_scope1_per_ton_total_weight + carbon_emission_equivalent_scope2_per_ton_total_weight+carbon_emission_equivalent_scope3_per_ton_total_weight)
as delivery_carbon_emission_per_ton_weight,
(t1. sum_sales_bundle_net_weight/1000) as bundle_by_delivery_and_melt_total_weight,
t3.carbon_emission_equivalent_scope1_per_ton_melt_weight as carbon_emission_equivalent_scope1_per_ton_melt_weight,
t3.carbon_emission_equivalent_scope2_per_ton_melt_weight as carbon_emission_equivalent_scope2_per_ton_melt_weight,
t3.carbon_emission_equivalent_scope3_per_ton_melt_weight as carbon_emission_equivalent_scope3_per_ton_melt_weight,
t2.carbon_emission_equivalent_scope1_per_ton_total_weight as carbon_emission_equivalent_scope1_per_ton_delivery_weight,
t2.carbon_emission_equivalent_scope2_per_ton_total_weight as carbon_emission_equivalent_scope2_per_ton_delivery_weight,
t2.carbon_emission_equivalent_scope3_per_ton_total_weight as carbon_emission_equivalent_scope3_per_ton_delivery_weight,
dt_invoice_provisional as dt_invoice_provisional,
dt_invoice_provisional_mmyyyy as dt_invoice_provisional_mmyyyy,
invoice_provisional_code as invoice_provisional_code,
vat_invoice_of_invoice_provisional_code as vat_invoice_of_invoice_provisional_code
from carbon_footprint_by_bundle t1 
left join carbon_emission_full_scope_weight_cte swc on t1.sales_delivery_code=swc.sales_delivery_code
left join dm_calc.sd_sales_main_scm  t0 on t0.delivery_number_sales=t1.sales_delivery_code
left join dds.delivery_document_header t2 on t1.sales_delivery_code=t2.delivery_code
left join dm_calc.carbon_footprint_by_melt_sd0015 t3 on t1.sales_delivery_code=t3.sales_delivery_code and t1.melt_code=t3.melt_code 
);

