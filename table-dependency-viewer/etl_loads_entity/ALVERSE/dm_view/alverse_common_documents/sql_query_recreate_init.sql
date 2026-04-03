drop view if exists dm_view.alverse_common_documents;

create or replace view dm_view.alverse_common_documents
as 
select 
    sa.sales_order_in_shipment as sales_order_in_shipment,
	sa.plant_producer_name as plant_producer_name,
	sa.customer_name as customer_name,
	sa.contract_name as contract_name,
	sa.invoice_provisional_number as invoice_provisional_number,
	sa.frame_contract_code as frame_contract_code,
	ar.dt_posting as dt_posting,
	ar.realization_invoice_code as realization_invoice_code,
	ar.accounting_document_code as accounting_document_code
from dm.sales_alverse_mlc sa
	join dm.production_aluminium_casting_schedule pac
		on sa.sales_order_in_shipment = pac.sales_request_code
	join dm.accounts_receivaible_sales_alverse ar
        on sa.sales_order_in_shipment = ar.sales_order_in_shipment
group by 
	sa.sales_order_in_shipment,
	sa.plant_producer_name,
	sa.customer_name,
	sa.contract_name,
	sa.invoice_provisional_number,
	sa.frame_contract_code,
	ar.dt_posting,
	ar.realization_invoice_code,
	ar.accounting_document_code;