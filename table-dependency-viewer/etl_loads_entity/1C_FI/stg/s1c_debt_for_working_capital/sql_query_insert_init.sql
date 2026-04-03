BEGIN;

CREATE TEMPORARY TABLE entrys_1c_wc ON COMMIT DROP AS 
with hed as (
select 
	uuid
	, dt_insert
	, (xpath('Header/Sender/text()', document_xml))[1]::varchar as sender
	, (xpath('Header/Receiver/text()', document_xml))[1]::varchar as receiver
	, ((xpath('Header/CreatedDateTime/text()', document_xml))[1]::varchar)::timestamp as create_date_time 
	, document_xml
	from landing."INPUT_DATA_FROM_SAPXI_IN"
	where 
		flow_id = 'SI_WorkingCapital_AI' --372 23c
				and uuid not in (select uuid from stg.s1c_debt_for_working_capital)
)
, items as (
select
	uuid
	, dt_insert
	, sender
	, receiver
	, create_date_time
	, (unnest(xpath('Body/Item', document_xml))) AS item_document_xml
from hed
)
select
uuid
, dt_insert
, sender
, receiver
, create_date_time
, item_document_xml
, ((xpath('//Item/dtRp/text()', item_document_xml))[1]::varchar)::date as dt_report
, (xpath('//Item/dbCd/text()', item_document_xml))[1]::varchar as database_code_1c
, (xpath('//Item/dbName/text()', item_document_xml))[1]::varchar as database_name_1c
, (xpath('//Item/unitMd/text()', item_document_xml))[1]::varchar as unit_balance_mdm_code_1c
, (xpath('//Item/tz/text()', item_document_xml))[1]::varchar as timezone_1c
from items
DISTRIBUTED BY (unit_balance_mdm_code_1c);


insert into stg.s1c_debt_for_working_capital 
with entrys as (
select
uuid
, dt_insert
, sender
, receiver
, create_date_time
, dt_report
, database_code_1c
, database_name_1c
, unit_balance_mdm_code_1c
, timezone_1c
, (unnest(xpath('//Item/entry', item_document_xml))) AS item_document_xml
from entrys_1c_wc)
select 
sender
, receiver
, create_date_time
, dt_report
, database_code_1c
, database_name_1c
, unit_balance_mdm_code_1c
, (xpath('//entry/id/text()', item_document_xml))[1]::varchar as posting_uid_code_1c
, (xpath('//entry/invNum/text()', item_document_xml))[1]::varchar as invoice_registration_number
, (xpath('//entry/ctrpRole/text()', item_document_xml))[1]::varchar as counterparty_role_name
, (xpath('//entry/dcName/text()', item_document_xml))[1]::varchar as debit_or_credit_name
, (xpath('//entry/docDesc/text()', item_document_xml))[1]::varchar as accounting_document_descriprion_text
, (xpath('//entry/docNum/text()', item_document_xml))[1]::varchar as document_1с_code
, (xpath('//entry/respCntr/text()', item_document_xml))[1]::varchar as responsibility_center_hfm_code
, (xpath('//entry/regEndUsr/text()', item_document_xml))[1]::varchar as region_of_end_user_code
, (xpath('//entry/cntEndUsr/text()', item_document_xml))[1]::varchar as country_of_end_user_code
, (xpath('//entry/ctrpMd/text()', item_document_xml))[1]::varchar as counterparty_mdm_code
, ((xpath('//entry/ctrpTurnov/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as counterparty_annual_turnover_amount -- cast
, (xpath('//entry/fgGrName/text()', item_document_xml))[1]::varchar as finish_goods_group_name
, (xpath('//entry/ctNum/text()', item_document_xml))[1]::varchar as contract_number
, (xpath('//entry/pdUrl/text()', item_document_xml))[1]::varchar as paydox_document_url -- не нашёл тег все нулы
, (xpath('//entry/ctType/text()', item_document_xml))[1]::varchar as contract_type_name
, ((xpath('//entry/ctAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as contract_amount
, (xpath('//entry/ctCurCd/text()', item_document_xml))[1]::varchar as contract_currency_code
, ((xpath('//entry/dtCtStart/text()', item_document_xml))[1]::varchar)::date as dt_contract_start
, ((xpath('//entry/dtCtEnd/text()', item_document_xml))[1]::varchar)::date as dt_contract_end
, (xpath('//entry/payTerm/text()', item_document_xml))[1]::varchar as terms_of_payment_name
, ((xpath('//entry/dtOverdue/text()', item_document_xml))[1]::varchar)::date as dt_overdue
, (xpath('//entry/covTypeName/text()', item_document_xml))[1]::varchar as debt_coverage_type_name
, ((xpath('//entry/covAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as coverage_amount
, (xpath('//entry/covCurCd/text()', item_document_xml))[1]::varchar as coverage_currency_code
, ((xpath('//entry/dtDebt/text()', item_document_xml))[1]::varchar)::date as dt_debt
, (xpath('//entry/docCurCd/text()', item_document_xml))[1]::varchar as document_currency_code
, ((xpath('//entry/dbDocCurAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_balance_document_currency_amount
, ((xpath('//entry/dbRubAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_balance_rub_currency_amount
, ((xpath('//entry/dbUsdAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_balance_usd_currency_amount
, ((xpath('//entry/odDocCurAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_overdue_document_currency_amount
, ((xpath('//entry/odRubAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_overdue_rub_currency_amount
, ((xpath('//entry/odUsdAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_overdue_usd_currency_amount
, (xpath('//entry/bankRecName/text()', item_document_xml))[1]::varchar as bank_receiver_name
, (xpath('//entry/recClmUrl/text()', item_document_xml))[1]::varchar as receivable_claim_paydox_url
, ((xpath('//entry/dtRecClm/text()', item_document_xml))[1]::varchar)::date as dt_receivable_claim
, ((xpath('//entry/dtLawCrt/text()', item_document_xml))[1]::varchar)::date as dt_claim_send_to_law_court
, (xpath('//entry/ctrSupName/text()', item_document_xml))[1]::varchar as contract_supervisor_name
, (xpath('//entry/ctrSupId/text()', item_document_xml))[1]::varchar as contract_supervisor_ad_login_code
, (xpath('//entry/glAccCd/text()', item_document_xml))[1]::varchar as general_ledger_account_code
, (xpath('//entry/glAccName/text()', item_document_xml))[1]::varchar as general_ledger_account_name
, ((xpath('//entry/dtCtReg/text()', item_document_xml))[1]::varchar)::date as dt_contract_registration
, ((xpath('//entry/docCurAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as document_currency_amount
, (xpath('//entry/ctrSup1c/text()', item_document_xml))[1]::varchar as contract_supervisor_employee_1c_number
, (xpath('//entry/ctrSupSap/text()', item_document_xml))[1]::varchar as contract_supervisor_employee_sap_number
, (xpath('//entry/smCode/text()', item_document_xml))[1]::varchar as sales_market_code
, (xpath('//entry/smName/text()', item_document_xml))[1]::varchar as sales_market_name
, ((xpath('//entry/badDbAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as bad_debt_provision_amount
, (xpath('//entry/badDbCurCd/text()', item_document_xml))[1]::varchar as bad_debt_provision_currency_code
, ((xpath('//entry/crLimRubAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as credit_limit_rub_currency_amount
, ((xpath('//entry/dtCrLimEnd/text()', item_document_xml))[1]::varchar)::date as dt_credit_limit_valid_to
, (xpath('//entry/crUrlPd/text()', item_document_xml))[1]::varchar as paydox_credit_limit_url
, ((xpath('//entry/insAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as insured_amount
, (xpath('//entry/insCurCd/text()', item_document_xml))[1]::varchar as insurance_currency_code
, ((xpath('//entry/dtInsEnd/text()', item_document_xml))[1]::varchar)::date as dt_insurance_valid_to
, (xpath('//entry/insCoMd/text()', item_document_xml))[1]::varchar as insurance_company_mdm_code
, ((xpath('//entry/bgAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as bank_guarantee_amount
, (xpath('//entry/bgCurCd/text()', item_document_xml))[1]::varchar as bank_guarantee_currency_code
, ((xpath('//entry/dtBgEnd/text()', item_document_xml))[1]::varchar)::date as dt_bank_guarantee_valid_to
, (xpath('//entry/bgMd/text()', item_document_xml))[1]::varchar as bank_guarantee_mdm_code
, ((xpath('//entry/thpgAmt/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as third_party_guarantee_amount
, (xpath('//entry/thpgCurCd/text()', item_document_xml))[1]::varchar as third_party_guarantee_currency_code
, ((xpath('//entry/dtThpgEnd/text()', item_document_xml))[1]::varchar)::date as dt_third_party_guarantee_valid_to
, (xpath('//entry/thpgMd/text()', item_document_xml))[1]::varchar as third_party_guarantee_mdm_code
, ((xpath('//entry/dbDfRub/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_balance_exchange_diff_rub_amount
, ((xpath('//entry/dbDfUsd/text()', item_document_xml))[1]::varchar)::decimal(20, 6) as debt_balance_exchange_diff_usd_amount
, uuid
, dt_insert
from entrys
;

COMMIT; 