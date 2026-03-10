drop view if exists dm_view.purchase_contract_limits_and_current_balances;

create or replace view dm_view.purchase_contract_limits_and_current_balances as
select *
from dm.purchase_contract_limits_and_current_balances
where 1=1
  and deleted_flag = false;

comment on view dm_view.purchase_contract_limits_and_current_balances is 'Контракты на закупку: текущий баланс и остатки';
comment on column dm_view.purchase_contract_limits_and_current_balances.purchase_contract_code is 'Контракт на закупку (код) | Контракт на закупку (код) | dds.purchase_contract_header.purchase_contract_code';
comment on column dm_view.purchase_contract_limits_and_current_balances.dt_purchase_contract_valid_from is 'Начальный срок действия | Начальный срок действия | dds.purchase_contract_header.dt_valid_from';
comment on column dm_view.purchase_contract_limits_and_current_balances.dt_purchase_contract_valid_to is 'Конечный срок действия | Конечный срок действия | dds.purchase_contract_header.dt_valid_to';
comment on column dm_view.purchase_contract_limits_and_current_balances.purchase_contract_document_currency_amount is 'Сумма с НДС, которую можно потратить по договору на все акты и ТАПы | Сумма с НДС, которую можно потратить по договору на все акты и ТАПы | dds.purchase_contract_header.total_purchase_contract_cost_document_currency_amount';
comment on column dm_view.purchase_contract_limits_and_current_balances.purchase_contract_available_limit_doc_currency_amount is 'Остаток суммы по договору | Остаток суммы по договору | dds.purchase_contract_header.purchase_contract_available_limit_doc_currency_amount';