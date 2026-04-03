insert into dds.purchase_contract_header
select 
	ekko."ebeln" as purchase_contract_code,
	ekko."bsart" as purchase_document_subtype_code,
	ekko."bstyp" as purchase_document_type_code,
	ekko."zzcomercialloan" as supplier_claim_rate,
	ekko."adrnr" as address_code,
	ekko."zzvbeln" as agency_contract_code,
	ekko."unsez" as appendix_number,
	ekko."zzbvtyp" as bank_account_system_code,
	ekko."zzbizp" as budget_type_code,
	ekko."kalsm" as calculation_scheme_code,
	ekko."knumv" as condition_document_reference_code,
	ekko."zzdogkr" as contract_supervisor_name,
	ekko."zzcostr" as cost_region_code,
	ekko."ernam" as created_by,
	ekko."waers" as currency_code,
	ekko."zzkurs" as currency_translation_term_code,
	ekko."aedat" as dt_created,
	ekko."zzdtots1" as dt_deferred_payment1,
	ekko."zzdtots2" as dt_deferred_payment2,
	ekko."zzdtots3" as dt_deferred_payment3,
	ekko."zzdtots4" as dt_deferred_payment4,
	ekko."bedat" as dt_purchase_contract,
	pdx."bedat" as dt_purchase_contract_paydox,
	ekko."zzquota" as dt_quota_yyyymm,
	ekko."kdatb" as dt_valid_from,
	ekko."kdate" as dt_valid_to,
	ekko."zzedo" as edm_applicable_code,
	ekko."verkf" as external_contract_number_part1,
	ekko."telf1" as external_contract_number_part2,
	ekko."zzsegrep" as hfm_reporting_segment_code,
	ekko."inco1" as incoterms_code,
	ekko."zzknote" as incoterms_location_code,
	ekko."inco2" as incoterms_location_text,
	ekko."zzpenaltyrefrate" as is_penalty_charge_linked_to_central_bank_base_rate_code,
	ekko."frgrl" as is_released_code,
	ekko."zurdog" as legal_agreement_number,
	ekko."zzkondm" as material_price_group_code,
	ekko."zzonepenalty1" as one_time_penalty_charge_amount,
	ekko."zzonepenalty" as one_time_penalty_charge_rate,
	ekko."zzppskd" as ownership_transfer_term_code,
	ekko."zzpaydox" as paydox_contract_type_code,
	pdx."docidint" as paydox_document_code,
	pdx."name" as paydox_document_name,
	pdx."paydox_status" as paydox_document_status_code,
	pdx."bsart_pd" as paydox_document_type_code,
	-- Для документов LE берется pdx.url для остальных (документы ММ) берется dms_phio2file.filename
	case when ekko.bsart in ('ZDAT', 'ZDC', 'ZDE', 'ZDF', 'ZDL', 'ZDP', 'ZDPR', 'ZDS', 'ZDT', 'ZDTL', 'ZDVK')
		then pdx."url" 
		else dms_phio2file.filename end as paydox_document_url,
	ekko."zznumpr" as paydox_protocol_registration_number,
	-- Для документов LE берется pdx.docid для остальных (документы ММ) берется ekko.zzihrez
	case when ekko.bsart in ('ZDAT', 'ZDC', 'ZDE', 'ZDF', 'ZDL', 'ZDP', 'ZDPR', 'ZDS', 'ZDT', 'ZDTL', 'ZDVK') 
		then pdx.docid 
		else ekko.zzihrez end as paydox_registration_number,
	ekko."zzernam" as paydox_responsible_person_code,
	pdx."oe" as paydox_unit_balance_code,
	ekko."zzbanfn" as payment_and_liability_plan_request_code,
	ekko."zzpaymentrule" as payment_date_calculation_rule_code,
	ekko."zzsum" as penalty_charge_calculation_terms_code,
	ekko."zzpenalty" as penalty_charge_for_delay_rate,
	ekko."zznomore" as penalty_charge_maximum_limit_rate,
	ekko."zzport" as port_code,
	doglim."ktwrt_balance" as purchase_contract_available_limit_doc_currency_amount,
	ekko."zztempid" as purchase_contract_draft_code,
	ekko."description" as purchase_contract_name,
	ekko."ihrez" as purchase_contract_registration_number,
	ekko."zzniokrtxt" as purchase_contract_research_and_development_niokr_name,
	ekko."ekgrp" as purchase_group_code,
	ekko."ekorg" as purchase_organization_code,
	ekko."zzzhdtarif" as railway_tariff_calculation_method_code,
	ekko."frgke" as release_stage_code,
	ekko."frgzu" as release_status_code,
	ekko."frgsx" as release_strategy_code,
	ekko."frggr" as release_strategy_group_code,
	ekko."zzrcode" as rent_type_code,
	ekko."zzresp" as responsibility_center_code,
	ekko."zzvbeln_zx" as storage_agreement_code,
	ekko."lifnr" as supplier_code,
	ekko."zztariff" as tariff_dob_responsibility_code,
	ekko."zzknanf_term" as terminal_code,
	ekko."zterm" as terms_of_payment_code,
	ekko."zzebeln" as tolling_contract_code,
	ekko."ktwrt" as total_purchase_contract_cost_document_currency_amount,
	ekko."zzmwskz" as transportation_total_cost_vat_code,
	ekko."zztzr" as transportation_total_cost_vat_excluded_amount,
	ekko."zzunidoc" as unified_purchase_contract_code,
	ekko."zzunidoc_s" as unified_purchase_contract_name,
	ekko."bukrs" as unit_balance_code,
	ekko."memory" as is_purchase_contract_draft_code
from ods."ekko_ral" as ekko
	left join ods."/rusal/dtl_pdx_h_ral" as pdx 
		on pdx.ebeln = ekko.ebeln
	left join ods.zle_dog_limit_ral as doglim 
		on doglim.ebeln = ekko.ebeln
	left join ods.dms_doc2loio_ral as dms_doc2loio 
		on dms_doc2loio.doknr = ekko.zzunidoc 
		and dms_doc2loio.dokar = 'ZMM' 
		and dms_doc2loio.dokvr = '00' 
		and dms_doc2loio.doktl = '000'
	left join ods.dms_ph_cd1_ral as dms_ph_cd1 
		on dms_ph_cd1.loio_id = dms_doc2loio.lo_objid
	left join ods.dms_phio2file_ral as dms_phio2file 
		on dms_phio2file.file_id = dms_ph_cd1.prop08
where ekko.bstyp = 'K';
