insert into dm_calc.raw_materials_arrival (
	material_code,
	batch_code,
	plant_code,
	transport_bill_code,
	railcar_code,
	transport_bill_and_railcar_code,
	supplier_code,
	producer_code,
	business_scheme_type_code,
	dt_arrival_by_accounting,
	dt_discharge,
	dt_posting,
	warehouse_code,
	railway_track_at_plant_number,
	purchase_contract_code,
	bill_of_lading_number,
	weight_net
)
with cte as (
	select
		rrd.matnr as material_code,
		rrd.charg as batch_code,
		rrd.werks as plant_code,
		likp.transport_bill_code as transport_bill_code,
		likp.vehicle_code as railcar_code,
		likp.transport_bill_code||'-'||likp.vehicle_code as transport_bill_and_railcar_code,
		rrd.mblnr,
		count(rrd.mblnr) over (partition by likp.transport_bill_code, likp.vehicle_code) as rwn1,
		case when ekkont.ebeln is not null then ekkont.lifnr else ekko.lifnr end as supplier_code,
		case when mpdtp.purchase_document_code is not null then mpdtp.producer_code else ekpo.mfrnr end as producer_code,
		ekpo.bwtar as business_scheme_type_code,
		coalesce(mch1.fvdt3, rrd.fvdt3) as dt_arrival_by_accounting,
		mch1.fvdt6 as dt_discharge,
		mseg.dt_posting as dt_posting,					--mseg.budat_mkpf,
		mseg.warehouse_code as warehouse_code,			--mseg.lgort,
		rrd.path as railway_track_at_plant_number,
		rrd.ebeln as purchase_contract_code,
		rrd.conosnum as bill_of_lading_number,
		case when rrh.n_netto_v > 0 then rrh.n_netto_v else rrh.n_netto_n end as weight_net
	from ods."/rul/rw_docs_ral" as rrd
		left join ods."/rul/rw_head_ral" as rrh
			on rrh.matnr = rrd.matnr and
		   	   rrh.charg = rrd.charg and
		   	   rrh.werks = rrd.werks
		left join dds.delivery_document_header as likp
			on likp.delivery_code = rrd.belnr
		left join ods.mch1_ral as mch1
			on mch1.charg = rrd.charg and
		   	   mch1.matnr = rrd.matnr
		left join (
			select
	    		mseg.material_movement_document_code,
				mseg.material_movement_document_year,
				mseg.material_movement_document_position_code,
				mseg.warehouse_code,
				mseg.dt_posting,
				min(mseg.material_movement_document_position_code) over (partition by mseg.material_movement_document_code, mseg.material_movement_document_year) as rwn
			from (
				select distinct rrd.mblnr, rrd.mjahr 
		       	from ods."/rul/rw_docs_ral" as rrd 
		    ) as t1
			join dds.material_movement_document as mseg
				on mseg.material_movement_document_code = t1.mblnr and 
			   	   mseg.material_movement_document_year = t1.mjahr 
		) as mseg		
			on mseg.material_movement_document_code = rrd.mblnr and
		   	   mseg.material_movement_document_year = rrd.mjahr and
		   	   mseg.material_movement_document_position_code = mseg.rwn
		left join ods."/rusal/ekkont_ral" as ekkont
			on ekkont.ebeln = rrd.ebeln 
		left join dict_dds.map_purchase_document_to_producer as mpdtp
			on mpdtp.purchase_document_code = rrd.ebeln and 
		   	   mpdtp.purchase_document_position_code = rrd.ebelp and 
		   	   mpdtp.dt_valid_to >= rrd.fvdt3 and 
		   	   mpdtp.dt_valid_from <= rrd.fvdt3
		left join ods.ekko_ral as ekko
			on ekko.ebeln = rrd.ebeln
		/*left join dds.purchase_agreement_header as ekko_agm	
			on ekko_agm.purchase_agreement_code = rrd.ebeln
		left join dds.purchase_order_header as ekko_ord
			on ekko_ord.purchase_order_code = rrd.ebeln*/
		left join ods.ekpo_ral as ekpo
			on ekpo.ebeln = rrd.ebeln and 
		   	   ekpo.ebelp = rrd.ebelp
		/*left join dds.purchase_agreement_position as ekpo_agm	
			on ekpo_agm.purchase_agreement_code = rrd.ebeln and
			   ekpo_agm.position_line_item_code = rrd.ebelp
		left join dds.purchase_order_position as ekpo_ord	
			on ekpo_agm.purchase_order_code = rrd.ebeln and
			   ekpo_agm.position_line_item_code = rrd.ebelp*/
	where likp.vehicle_code is not null
		and likp.transport_bill_code is not null
		and coalesce(mch1.fvdt3, rrd.fvdt3) >= '2020-01-01'
		and rrd.werks in ('5101', '5201', '5203', '5301', '5302', '5401', '5601', '5701', '6300', '6400', '6800', '7201', 'F591')
)
select
	material_code,
	batch_code,
	plant_code,
	transport_bill_code,
	railcar_code,
	transport_bill_and_railcar_code,
	supplier_code,
	producer_code,
	business_scheme_type_code,
	dt_arrival_by_accounting,
	dt_discharge,
	dt_posting,
	warehouse_code,
	railway_track_at_plant_number,
	purchase_contract_code,
	bill_of_lading_number,
	weight_net 	 
from cte
where (mblnr is not null)
   or (mblnr is null and rwn1 = 0)
;