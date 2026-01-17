with key_cs as
(
select
		ods.cast_sched."PLANTNAME" as plant_name,
		ods.cast_sched."PLANTID" as plant_code,
		ods.cast_sched."CHNAME" as casting_department_name,
		ods.cast_sched."CHID" as casting_department_code,
		ods.cast_sched."CUNAME" as casting_unit_name,
		ods.cast_sched."CUID" as casting_unit_code,
		ods.cast_sched."ORDERID" as sales_request_code,
		ods.cast_sched."ORDERTYPEFORDWH" as sales_request_type_code,
		ods.cast_sched."FIRSTTRACK_DT" as dt_casting_plan_start,
		ods.cast_sched."LASTTRACK_DT" as dt_casting_plan_end,
		ods.cast_sched."FIRSTTRACKPLANTOSGP_DT" as dt_warehouse_acceptance_plan_start,
		ods.cast_sched."LASTTRACKPLANTOSGP_DT" as dt_warehouse_acceptance_plan_end,
		ods.cast_sched."REQUIREDTONNAGE" as sales_request_raw_metal_total_weight,
		ods.cast_sched."REQUIREDMONTHTONNAGE" as sales_request_raw_metal_current_month_weight,
		ods.cast_sched."INCTONNAGEPLAN" as accepted_plan_weight,
		ods.cast_sched."CUORDERTYPENAME" as data_type_name,
		ods.cast_sched."PRODUCTID" as shape_for_reporting_name,
		ods.cast_sched."PERIOD" as dt_report,
		(LPAD(ods.cast_sched."VERSION", 2, '0')) as version_code,
		('400'||sd2882m."market"||sd2882m."reg_perio"||rpad (sd2882m."matkl",9 ,' ')||sd2882m."numvr"||sd2882m."numlinevr") AS key,
		ods.cast_sched."LOAD_DT" as load_dt
		from ods.cast_sched
			left join ods."/rusal/sd2882m_ral" as sd2882m
				on	ods.cast_sched."PLANTID"=sd2882m."werks"
				and sd2882m."zakaz_kl"=ods.cast_sched."ORDERID"
				and sd2882m."reg_perio"=CONCAT(DATE_PART('year', ods.cast_sched."PERIOD"::DATE),LPAD(DATE_PART('month', ods.cast_sched."PERIOD"::DATE)::TEXT, 2, 0::TEXT))
				and sd2882m."numvr"= LPAD(ods.cast_sched."VERSION", 2, '0')
)  

, cdpos_cs as
(
select
		cdpos.objectid,
		cdpos.changenr,
		cdpos.value_new as sales_request_status_code
	from 
	(
	select 
		key_cs.key,
		count (key_cs.key)
		from key_cs
		group by (key_cs.key)
	) as key_cs2
		left join ods.cdpos_ral as cdpos
		on cdpos.objectid=key_cs2.key and cdpos.objectclas='/RUSAL/SD2882M' and cdpos.tabname='/RUSAL/SD2882M' and cdpos.fname='STATUS_CURR'
		where key_cs2.key is not null and cdpos.objectid is not null
)

,hdr_pos as
(
select
	cdpos_cs.objectid,
	cdpos_cs.changenr,
	cdpos_cs.sales_request_status_code,
	cdhdr_ral.username,
	to_timestamp(cdhdr_ral.udate||' '||cdhdr_ral.utime, 'YYYY-MM-DD HH24:MI:SS') as dt_set
	from cdpos_cs left join ods.cdhdr_ral as cdhdr_ral
							on cdpos_cs.objectid=cdhdr_ral.objectid and cdpos_cs.changenr=cdhdr_ral.changenr
) 

,cdhdr_cs as 
(
select 
hdr_pos.objectid,
max (EXTRACT(EPOCH from hdr_pos.dt_set))
from hdr_pos
group by (hdr_pos.objectid)
) 

,cdhdr_ttl as 
(
select
	cdhdr_cs.objectid,
	hdr_pos.sales_request_status_code,
	hdr_pos.username as status_updated_by,
	hdr_pos.dt_set as dt_status_updated
	from cdhdr_cs left join hdr_pos on cdhdr_cs.objectid=hdr_pos.objectid and cdhdr_cs.max=EXTRACT(EPOCH from hdr_pos.dt_set)
)

,total_tbl as 
(
select
		key_cs.plant_name,
		key_cs.plant_code,
		key_cs.casting_department_name,
		key_cs.casting_department_code,
		key_cs.casting_unit_name,
		key_cs.casting_unit_code,
		key_cs.sales_request_code,
		key_cs.sales_request_type_code,
		key_cs.dt_casting_plan_start,
		key_cs.dt_casting_plan_end,
		key_cs.dt_warehouse_acceptance_plan_start,
		key_cs.dt_warehouse_acceptance_plan_end,
		key_cs.sales_request_raw_metal_total_weight,
		key_cs.sales_request_raw_metal_current_month_weight,
		key_cs.accepted_plan_weight,
		key_cs.data_type_name,
		key_cs.shape_for_reporting_name,
		key_cs.dt_report,
		key_cs.version_code,
		cdhdr_ttl.sales_request_status_code,
		cdhdr_ttl.status_updated_by,
		cdhdr_ttl.dt_status_updated,
		key_cs.load_dt
		from key_cs left join cdhdr_ttl on key_cs.key=cdhdr_ttl.objectid
)

insert into dm_calc.production_aluminium_casting_schedule
(
	plant_name,
	plant_code,
	casting_department_name,
	casting_department_code,
	casting_unit_name,
	casting_unit_code,
	sales_request_code,
	sales_request_type_code,
	dt_casting_plan_start,
	dt_casting_plan_end,
	dt_warehouse_acceptance_plan_start,
	dt_warehouse_acceptance_plan_end,
	sales_request_raw_metal_total_weight,
	sales_request_raw_metal_current_month_weight,
	accepted_plan_weight,
	data_type_name,
	shape_for_reporting_name,
	dt_report,
	version_code,
	sales_request_status_code,
	status_updated_by,
	dt_status_updated,
	load_dt
)
select
	total_tbl.plant_name,
	total_tbl.plant_code,
	total_tbl.casting_department_name,
	total_tbl.casting_department_code,
	total_tbl.casting_unit_name,
	total_tbl.casting_unit_code,
	total_tbl.sales_request_code,
	total_tbl.sales_request_type_code,
	total_tbl.dt_casting_plan_start,
	total_tbl.dt_casting_plan_end,
	total_tbl.dt_warehouse_acceptance_plan_start,
	total_tbl.dt_warehouse_acceptance_plan_end,
	total_tbl.sales_request_raw_metal_total_weight,
	total_tbl.sales_request_raw_metal_current_month_weight,
	total_tbl.accepted_plan_weight,
	total_tbl.data_type_name,
	total_tbl.shape_for_reporting_name,
	total_tbl.dt_report::date,
	total_tbl.version_code,
	total_tbl.sales_request_status_code,
	total_tbl.status_updated_by,
	total_tbl.dt_status_updated,
	total_tbl.load_dt
from total_tbl;