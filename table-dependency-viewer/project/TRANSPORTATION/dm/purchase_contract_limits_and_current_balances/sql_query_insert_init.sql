insert into dm.purchase_contract_limits_and_current_balances
select
	pch.purchase_contract_code,
	pch.dt_valid_from as dt_purchase_contract_valid_from,
	pch.dt_valid_to as dt_purchase_contract_valid_to,
	pch.total_purchase_contract_cost_document_currency_amount as purchase_contract_document_currency_amount,
	coalesce(pch.purchase_contract_available_limit_doc_currency_amount, 0) as purchase_contract_available_limit_doc_currency_amount
from dds.purchase_contract_header as pch
join (select distinct purchase_contract_code
	  from dm.transportation_services_purchase_price_agreement ) as tsp 
	on pch.purchase_contract_code = tsp.purchase_contract_code
;