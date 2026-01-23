C:\Users\SuvorovND\AppData\Local\Programs\Python\Python39\lib\site-packages\pydantic\_internal\_fields.py:198: UserWarning: Field name "schema" in "DependencyItem" shadows an attribute in parent "BaseModel"
  warnings.warn(
Reg
META COUNT: 2348
META SAMPLE: ['dds.accounting_balance', 'dds.accounting_document_clearing_relations', 'dds.accounting_document_partner_mirror_relation', 'dds.accounting_document_position_correspondence', 'dds.accounting_documents', 'dds.account
ing_documents_texts', 'dds.accounting_turnover_counterparty', 'dds.adjustment_request_position', 'dds.advance_payment_requirements_by_purchase_orders', 'dds.aldor_edm_document', 'dds.aldor_scan_copy_link_to_multiple_sap_document
', 'dds.aldor_scan_copy_link_to_single_sap_document', 'dds.bank_statement_documents', 'dds.bank_statement_position_clearing_record', 'dds.bill_of_lading', 'dds.controlling_documents_to_cost_centers', 'dds.controlling_documents_t
o_orders', 'dds.controlling_documents_to_wbs_elements', 'dds.controlling_object_distribution_settlement_rules', 'dds.customs_declaration_header', 'dds.customs_declaration_position', 'dds.delivery_document_header', 'dds.delivery_document_position', 'dds.delivery_initial', 'dds.delivery_number_deleted', 'dds.delivery_plant', 'dds.earmarked_funds_documents', 'dds.financial_loan_terms', 'dds.fixed_asset_depreciation', 'dds.fixed_asset_operations']
❌ BROKEN DEP: dds.accounting_documents depends on stg.ral_zbw1595m_odata_srv BUT META NOT FOUND
❌ BROKEN DEP: dm.production_cost_plan depends on ods./rusal/povs BUT META NOT FOUND
❌ BROKEN DEP: stg.asugdc_arrived_cargo depends on api.dag_api_asugdc_load BUT META NOT FOUND
❌ BROKEN DEP: stg.asugdc_dislocation_cargo depends on api.dag_api_asugdc_load BUT META NOT FOUND
❌ BROKEN DEP: dict_dds.dict_dkp depends on dict_stg.getsubdivisions BUT META NOT FOUND
❌ BROKEN DEP: dict_dds.dict_dkp depends on dict_stg.getcollaborators BUT META NOT FOUND
❌ BROKEN DEP: dict_dds.dict_dkp depends on dict_stg.getpositions BUT META NOT FOUND
❌ BROKEN DEP: dict_stg.counterparty_structure_1c_mdm_prod depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: dict_stg.counterparty_structure_1c_mdm_prod depends on landing.counterparty_structure_1c_mdm_prod_sapxi_out BUT META NOT FOUND
❌ BROKEN DEP: dict_stg.counterparty_structure_1c_mdm_prod depends on landing.back_up_input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: dict_stg.map_forecast_transportation_scenario_to_business_location depends on stg.map_forecast_transportation_scenario_to_business_location BUT META NOT FOUND
❌ BROKEN DEP: dict_stg.sok_counterparty_parameters depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.paydox_credit_limits depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: dm_calc.transportation_service_invoice_header depends on dds.transportation_service_invoice_and_accounting_document BUT META NOT FOUND
❌ BROKEN DEP: ods.map_transportation_raw_container_import_tracking_keys depends on stg.zmk_track_imp BUT META NOT FOUND
❌ BROKEN DEP: dm.sales_storage_registration_vs_storage_movement depends on dds.foreign_warehouse_priority_definition BUT META NOT FOUND
❌ BROKEN DEP: dm.material_raw_stock_balance_for_purchase_planning depends on ods.reservation_document_header BUT META NOT FOUND
❌ BROKEN DEP: dm.material_raw_stock_balance_for_purchase_planning depends on ods.reservation_document_position BUT META NOT FOUND
❌ BROKEN DEP: stg.si_balancesofnoncoreassets_ao depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.si_restructuringofnoncoreassets_ao depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: dm.kpi_indicators_daily_gd depends on ods.alumina_production_xls BUT META NOT FOUND
❌ BROKEN DEP: dm_calc.kpi_raw_warehouse_stock depends on ods.kpi_acsapxi_raw_purchase_planningcount_list BUT META NOT FOUND
❌ BROKEN DEP: ods.cast_sched depends on stg.cast_sched BUT META NOT FOUND
❌ BROKEN DEP: ods.kpi_indicators_actual_report_ad depends on stg.bip_zbw1689m_srv BUT META NOT FOUND
❌ BROKEN DEP: stg.alarm_accidents depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.auxiliary_production_anode_zyfra depends on api.dag_load_api_kraz BUT META NOT FOUND
❌ BROKEN DEP: stg.kpi_aggregation_characteristic_ppk depends on landing.kpi_aggregation_characteristic_ppk BUT META NOT FOUND
❌ BROKEN DEP: stg.macro_index_rsv_atsenergo depends on api.dag_load_api_atsenergo BUT META NOT FOUND
❌ BROKEN DEP: stg.mes_lp_reject_product depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_1c_personnel_attendance depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_production_aluminium_finish_goods_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtime depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtimeklass depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_demand_plannig depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_material_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_purchase_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_reject_product_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_sharepoint_workspacestandartisation depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_web_kaizen depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.stock_on_wheels_asugdc depends on api.dag_asugdc_cargo_in_wheels BUT META NOT FOUND
❌ BROKEN DEP: dm.kpi_indicators_daily_gd depends on ods.alumina_production_xls BUT META NOT FOUND
❌ BROKEN DEP: dm_calc.kpi_raw_warehouse_stock depends on ods.kpi_acsapxi_raw_purchase_planningcount_list BUT META NOT FOUND
❌ BROKEN DEP: ods.kpi_indicators_actual_report_ad depends on stg.bip_zbw1689m_srv BUT META NOT FOUND
❌ BROKEN DEP: stg.alarm_accidents depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.auxiliary_production_anode_zyfra depends on api.dag_load_api_kraz BUT META NOT FOUND
❌ BROKEN DEP: stg.kpi_aggregation_characteristic_ppk depends on landing.kpi_aggregation_characteristic_ppk BUT META NOT FOUND
❌ BROKEN DEP: stg.macro_index_rsv_atsenergo depends on api.dag_load_api_atsenergo BUT META NOT FOUND
❌ BROKEN DEP: stg.mes_lp_reject_product depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_1c_personnel_attendance depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_production_aluminium_finish_goods_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtime depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtimeklass depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_demand_plannig depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_material_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_purchase_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_reject_product_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_sharepoint_workspacestandartisation depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.stock_on_wheels_asugdc depends on api.dag_asugdc_cargo_in_wheels BUT META NOT FOUND
❌ BROKEN DEP: dm.kpi_indicators_daily_gd depends on ods.alumina_production_xls BUT META NOT FOUND
❌ BROKEN DEP: dm_calc.kpi_raw_warehouse_stock depends on ods.kpi_acsapxi_raw_purchase_planningcount_list BUT META NOT FOUND
❌ BROKEN DEP: ods.kpi_indicators_actual_report_ad depends on stg.bip_zbw1689m_srv BUT META NOT FOUND
❌ BROKEN DEP: stg.alarm_accidents depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.auxiliary_production_anode_zyfra depends on api.dag_load_api_kraz BUT META NOT FOUND
❌ BROKEN DEP: stg.kpi_aggregation_characteristic_ppk depends on landing.kpi_aggregation_characteristic_ppk BUT META NOT FOUND
❌ BROKEN DEP: stg.macro_index_rsv_atsenergo depends on api.dag_load_api_atsenergo BUT META NOT FOUND
❌ BROKEN DEP: stg.mes_lp_reject_product depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_1c_personnel_attendance depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_production_aluminium_finish_goods_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtime depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtimeklass depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_demand_plannig depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_material_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_purchase_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_reject_product_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_sharepoint_workspacestandartisation depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_web_kaizen depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.stock_on_wheels_asugdc depends on api.dag_asugdc_cargo_in_wheels BUT META NOT FOUND
❌ BROKEN DEP: dm.kpi_indicators_daily_gd depends on ods.alumina_production_xls BUT META NOT FOUND
❌ BROKEN DEP: dm_calc.kpi_raw_warehouse_stock depends on ods.kpi_acsapxi_raw_purchase_planningcount_list BUT META NOT FOUND
❌ BROKEN DEP: ods.kpi_indicators_actual_report_ad depends on stg.bip_zbw1689m_srv BUT META NOT FOUND
❌ BROKEN DEP: stg.alarm_accidents depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.auxiliary_production_anode_zyfra depends on api.dag_load_api_kraz BUT META NOT FOUND
❌ BROKEN DEP: stg.kpi_aggregation_characteristic_ppk depends on landing.kpi_aggregation_characteristic_ppk BUT META NOT FOUND
❌ BROKEN DEP: stg.macro_index_rsv_atsenergo depends on api.dag_load_api_atsenergo BUT META NOT FOUND
❌ BROKEN DEP: stg.mes_lp_reject_product depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_1c_personnel_attendance depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_production_aluminium_finish_goods_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtime depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_cubal_downtimeklass depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_demand_plannig depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_material_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_raw_purchase_planning depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_reject_product_kubal depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_sharepoint_workspacestandartisation depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.stock_on_wheels_asugdc depends on api.dag_asugdc_cargo_in_wheels BUT META NOT FOUND
❌ BROKEN DEP: ods.accounting_documents depends on stg.ral_zbw1595m_odata_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.accounting_document_position_correspondence depends on stg.ral_zbw1592m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.controlling_documents_to_cost_centers depends on stg.ral_zbw1690m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.controlling_documents_to_orders depends on stg.ral_zbw1687m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.controlling_documents_to_wbs_elements depends on stg.ral_zbw1556m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.investment_expenses depends on stg.bip_zbw1642m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.settlement_documents_from_project_to_receiver depends on stg.ral_zbw1728m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.tax_accruals_and_payments_aggregated depends on stg.bip_zbw1699m_srv BUT META NOT FOUND
❌ BROKEN DEP: ods.texts_from_sap_fm_read_text depends on stg.ral_zbw1583m_srv BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_web_kaizens depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_web_kaizen_authors depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_web_kaizen_performers depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
❌ BROKEN DEP: stg.sapxi_web_kaizen_states depends on landing.input_data_from_sapxi_in BUT META NOT FOUND
Traceback (most recent call last):
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\schedule_advisor.py", line 330, in <module>
    main()
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\schedule_advisor.py", line 276, in main
    duration_by_id = load_durations(args.days, engine)
  File "C:\Users\SuvorovND\GIT\table-dependency-viewer\api\schedule_advisor.py", line 82, in load_durations
    rows = engine.execute(
AttributeError: 'Engine' object has no attribute 'execute'
