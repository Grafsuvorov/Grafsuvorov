select * from adcc_spills()
SELECT c.relname,a.*,pg_catalog.pg_get_expr(ad.adbin, ad.adrelid, true) as def_value,dsc.description,dep.objid
FROM pg_catalog.pg_attribute a
INNER JOIN pg_catalog.pg_class c ON (a.attrelid=c.oid)
LEFT OUTER JOIN pg_catalog.pg_attrdef ad ON (a.attrelid=ad.adrelid AND a.attnum = ad.adnum)
LEFT OUTER JOIN pg_catalog.pg_description dsc ON (c.oid=dsc.objoid AND a.attnum = dsc.objsubid)
LEFT OUTER JOIN pg_depend dep on dep.refobjid = a.attrelid AND dep.deptype = 'i' and dep.refobjsubid = a.attnum and dep.classid = dep.refclassid
WHERE NOT a.attisdropped AND c.relkind not in ('i','I','c') AND c.oid=$1
ORDER BY a.attnum
SET search_path = public,public,"$user"
SET search_path = dds,public,"$user"
SET search_path = dq,public,"$user"
SET search_path = public,public,"$user"
"WITH report_data AS (
SELECT
  _chrep_.dt_report
, _chrep_.dt_shipment
, _chrep_.delivery_region
, _chrep_.delivery_country_in_contract_name
, _chrep_.customer_for_scm_report_name
, _chrep_.china_business_location_name
, _chrep_.dt_invoice_provisional
, _chrep_.material_type as material_aggr_name
, SUM(_chrep_.net_weight_with_wirerod) as net_weight_with_wirerod
, _chrep_.dt_arrival_in_port_of_discharge_plan_or_actual
FROM
userdata.t0023_china_dt_report _chrep_
where 
	EXTRACT(YEAR FROM dt_shipment) = EXTRACT(YEAR FROM dt_report)
GROUP BY
  _chrep_.dt_report
, _chrep_.dt_shipment
, _chrep_.delivery_region 
, _chrep_.delivery_country_in_contract_name
, _chrep_.customer_for_scm_report_name
, _chrep_.china_business_location_name
, _chrep_.dt_invoice_provisional
, _chrep_.material_type
, _chrep_.dt_arrival_in_port_of_discharge_plan_or_actual
)

--select dt_report, dt_shipment, net_weight_with_wirerod from report_data where dt_report = '2025-05-27' 	and material_aggr_name = 'COMMODITY' 
--select * from report_data where dt_report = '2025-05-27' 	and material_aggr_name = 'COMMODITY' 

, real_data as (
SELECT
  _chreal_.dt_realization as dt_report
, _chreal_.dt_shipment
, _chreal_.delivery_region_name as delivery_region
, _chreal_.delivery_country_in_contract_name
, _chreal_.customer_for_scm_report_name
, _chreal_.china_business_location_name
, _chreal_.dt_invoice_provisional
, _chreal_.material_aggr_name
, SUM(_chreal_.net_weight_with_wirerod) as net_weight_with_wirerod
, _chreal_.dt_arrival_in_port_of_discharge_plan_or_actual
FROM
userdata.t0022_china_dt_realised _chreal_
where 
	EXTRACT(YEAR FROM dt_shipment) = EXTRACT(YEAR FROM dt_realization)
GROUP BY
  _chreal_.dt_realization
, _chreal_.dt_shipment
, _chreal_.delivery_region_name 
, _chreal_.delivery_country_in_contract_name
, _chreal_.customer_for_scm_report_name
, _chreal_.china_business_location_name
, _chreal_.dt_invoice_provisional
, _chreal_.material_aggr_name
, _chreal_.dt_arrival_in_port_of_discharge_plan_or_actual
)

--select dt_report, dt_shipment, net_weight_with_wirerod from real_data where dt_report <= '2025-05-27' 	and material_aggr_name = 'COMMODITY' 
/*

select distinct 
 	  dt_report
	, dt_shipment
	, delivery_region
	, delivery_country_in_contract_name
	, customer_for_scm_report_name
	, china_business_location_name
	, dt_invoice_provisional
	, material_aggr_name
	, dt_arrival_in_port_of_discharge_plan_or_actual
from real_data
where dt_report <= '2025-05-27' 	and material_aggr_name = 'COMMODITY' 
*/

/*select 
*
from  real_data as unic_cte
where 	unic_cte.dt_report <= '2025-05-27' 	
	and unic_cte.material_aggr_name = 'COMMODITY'	
	and unic_cte.dt_shipment = '2025-03-14'
	and unic_cte.delivery_region = 'China'
	and unic_cte.delivery_country_in_contract_name = 'China'
	and unic_cte.customer_for_scm_report_name = 'JIANGSU DINGSHENG NEW MATERIALS JOINT-STOCK CO., LTD.'
	and unic_cte.china_business_location_name = 'Realized'
	and unic_cte.dt_invoice_provisional = '2025-05-23'
	--and material_aggr_name = 'COMMODITY'
	and unic_cte.dt_arrival_in_port_of_discharge_plan_or_actual = '2025-03-14'*/

, cte as (
select *, 'rep' as prizn from report_data
union all
select *, 'real'as prizn from real_data
)

--select * from cte where dt_report = '2025-05-27' 	and material_aggr_name = 'COMMODITY' and prizn = 'real'

, unic_cte as (
  select distinct
  	  dt_report
	, dt_shipment
	, delivery_region
	, delivery_country_in_contract_name
	, customer_for_scm_report_name
	, china_business_location_name
	, dt_invoice_provisional
	, material_aggr_name
	, dt_arrival_in_port_of_discharge_plan_or_actual
	from cte )

/*select * 
from unic_cte
where 
		dt_report = '2025-05-27'
	and dt_shipment = '2025-03-14'
	and delivery_region = 'China'
	and delivery_country_in_contract_name = 'China'
	and customer_for_scm_report_name = 'JIANGSU DINGSHENG NEW MATERIALS JOINT-STOCK CO., LTD.'
	and china_business_location_name = 'Realized'
	and dt_invoice_provisional = '2025-05-23'
	and material_aggr_name = 'COMMODITY'
	and dt_arrival_in_port_of_discharge_plan_or_actual = '2025-03-14'*/

--select * from unic_ste where dt_report = '2025-05-27' 	and material_aggr_name = 'COMMODITY' 
--select count(*) from unic_cte where dt_report = '2025-05-27' 	and material_aggr_name = 'COMMODITY' --and 	prizn = 'real'
	
select 	
	  unic_cte.dt_report
	, unic_cte.dt_shipment
	, unic_cte.delivery_region
	, unic_cte.delivery_country_in_contract_name
	, unic_cte.customer_for_scm_report_name
	, unic_cte.china_business_location_name
	, unic_cte.dt_invoice_provisional
	, unic_cte.material_aggr_name
	, unic_cte.dt_arrival_in_port_of_discharge_plan_or_actual
	, rep.net_weight_with_wirerod
	--, net_weight_with_wirerod as net_weight_with_wirerod
	, (select sum(real.net_weight_with_wirerod) from real_data real
		where unic_cte.dt_report <= real.dt_report
		and unic_cte.dt_shipment = real.dt_shipment
		and unic_cte.delivery_region = real.delivery_region
		and unic_cte.delivery_country_in_contract_name = real.delivery_country_in_contract_name
		and unic_cte.customer_for_scm_report_name = real.customer_for_scm_report_name
		and unic_cte.china_business_location_name = real.china_business_location_name
		and unic_cte.dt_invoice_provisional = real.dt_invoice_provisional
		and unic_cte.material_aggr_name = real.material_aggr_name
		and unic_cte.dt_arrival_in_port_of_discharge_plan_or_actual = real.dt_arrival_in_port_of_discharge_plan_or_actual) as net_weight_with_wirerod_1
from unic_cte
left join report_data rep
		on  unic_cte.dt_report = rep.dt_report
		and unic_cte.dt_shipment = rep.dt_shipment
		and unic_cte.delivery_region = rep.delivery_region
		and unic_cte.delivery_country_in_contract_name = rep.delivery_country_in_contract_name
		and unic_cte.customer_for_scm_report_name = rep.customer_for_scm_report_name
		and unic_cte.china_business_location_name = rep.china_business_location_name
		and unic_cte.dt_invoice_provisional = rep.dt_invoice_provisional
		and unic_cte.material_aggr_name = rep.material_aggr_name
		and unic_cte.dt_arrival_in_port_of_discharge_plan_or_actual = rep.dt_arrival_in_port_of_discharge_plan_or_actual
--where unic_cte.dt_report = '2025-05-27' and unic_cte.material_aggr_name = 'COMMODITY'
/*left join real_data real
		on  unic_cte.dt_report = real.dt_report
		and unic_cte.dt_shipment = real.dt_shipment
		and unic_cte.delivery_region = real.delivery_region
		and unic_cte.delivery_country_in_contract_name = real.delivery_country_in_contract_name
		and unic_cte.customer_for_scm_report_name = real.customer_for_scm_report_name
		and unic_cte.china_business_location_name = real.china_business_location_name
		and unic_cte.dt_invoice_provisional = real.dt_invoice_provisional
		and unic_cte.material_aggr_name = real.material_aggr_name
		and unic_cte.dt_arrival_in_port_of_discharge_plan_or_actual = real.dt_arrival_in_port_of_discharge_plan_or_actual*/
		--and real.dt_report <= unic_cte.dt_report
where /*unic_cte.dt_report = '2025-05-27' and */ unic_cte.dt_report = '2025-05-27'	and unic_cte.material_aggr_name = 'COMMODITY' --and unic_cte.dt_report = '2025-05-27'
	--and  unic_cte.dt_report = '2025-05-27'
/*	and unic_cte.dt_shipment = '2025-03-14'
	and unic_cte.delivery_region = 'China'
	and unic_cte.delivery_country_in_contract_name = 'China'
	and unic_cte.customer_for_scm_report_name = 'JIANGSU DINGSHENG NEW MATERIALS JOINT-STOCK CO., LTD.'
	and unic_cte.china_business_location_name = 'Realized'
	and unic_cte.dt_invoice_provisional = '2025-05-23'
	--and material_aggr_name = 'COMMODITY'
	and unic_cte.dt_arrival_in_port_of_discharge_plan_or_actual = '2025-03-14'*/
/*
group by 
	  unic_cte.dt_report
	, unic_cte.dt_shipment
	, unic_cte.delivery_region
	, unic_cte.delivery_country_in_contract_name
	, unic_cte.customer_for_scm_report_name
	, unic_cte.china_business_locatio"


	Gather Motion 8:1  (slice5; segments: 8)  (cost=0.00..2382698.91 rows=191 width=72)
  ->  Sequence  (cost=0.00..2382698.87 rows=24 width=72)
        ->  Shared Scan (share slice:id 5:0)  (cost=0.00..651.17 rows=105543 width=1)
              ->  Materialize  (cost=0.00..651.17 rows=105543 width=1)
                    ->  Redistribute Motion 8:8  (slice4; segments: 8)  (cost=0.00..651.06 rows=105543 width=100)
                          Hash Key: t0023_china_dt_report.china_business_location_name
                          ->  HashAggregate  (cost=0.00..618.03 rows=105543 width=100)
                                Group Key: t0023_china_dt_report.dt_report, t0023_china_dt_report.dt_shipment, t0023_china_dt_report.delivery_region, t0023_china_dt_report.delivery_country_in_contract_name, t0023_china_dt_report.customer_for_scm_report_name, t0023_china_dt_report.china_business_location_name, t0023_china_dt_report.dt_invoice_provisional, t0023_china_dt_report.material_type, t0023_china_dt_report.dt_arrival_in_port_of_discharge_plan_or_actual
                                ->  Seq Scan on t0023_china_dt_report  (cost=0.00..487.48 rows=105543 width=98)
                                      Filter: (date_part('year'::text, (dt_shipment)::timestamp without time zone) = date_part('year'::text, (dt_report)::timestamp without time zone))
        ->  Sequence  (cost=0.00..2382047.70 rows=24 width=72)
              ->  Shared Scan (share slice:id 5:1)  (cost=0.00..433.08 rows=1181 width=1)
                    ->  Materialize  (cost=0.00..433.08 rows=1181 width=1)
                          ->  HashAggregate  (cost=0.00..433.08 rows=1181 width=98)
                                Group Key: t0022_china_dt_realised.dt_realization, t0022_china_dt_realised.dt_shipment, t0022_china_dt_realised.delivery_region_name, t0022_china_dt_realised.delivery_country_in_contract_name, t0022_china_dt_realised.customer_for_scm_report_name, t0022_china_dt_realised.china_business_location_name, t0022_china_dt_realised.dt_invoice_provisional, t0022_china_dt_realised.material_aggr_name, t0022_china_dt_realised.dt_arrival_in_port_of_discharge_plan_or_actual
                                ->  Seq Scan on t0022_china_dt_realised  (cost=0.00..431.62 rows=1181 width=96)
                                      Filter: (date_part('year'::text, (dt_shipment)::timestamp without time zone) = date_part('year'::text, (dt_realization)::timestamp without time zone))
              ->  Result  (cost=0.00..2381614.62 rows=24 width=72)
                    ->  Hash Left Join  (cost=0.00..1356.22 rows=24 width=100)
                          Hash Cond: ((share0_ref3.dt_report = share0_ref2.dt_report) AND (share0_ref3.dt_shipment = share0_ref2.dt_shipment) AND ((share0_ref3.delivery_region)::text = (share0_ref2.delivery_region)::text) AND ((share0_ref3.delivery_country_in_contract_name)::text = (share0_ref2.delivery_country_in_contract_name)::text) AND ((share0_ref3.customer_for_scm_report_name)::text = (share0_ref2.customer_for_scm_report_name)::text) AND ((share0_ref3.china_business_location_name)::text = (share0_ref2.china_business_location_name)::text) AND (share0_ref3.dt_invoice_provisional = share0_ref2.dt_invoice_provisional) AND ((share0_ref3.material_type)::text = (share0_ref2.material_type)::text) AND (share0_ref3.dt_arrival_in_port_of_discharge_plan_or_actual = share0_ref2.dt_arrival_in_port_of_discharge_plan_or_actual))
                          ->  Redistribute Motion 8:8  (slice2; segments: 8)  (cost=0.00..892.73 rows=24 width=92)
                                Hash Key: share0_ref3.china_business_location_name
                                ->  HashAggregate  (cost=0.00..892.72 rows=24 width=92)
                                      Group Key: share0_ref3.dt_report, share0_ref3.dt_shipment, share0_ref3.delivery_region, share0_ref3.delivery_country_in_contract_name, share0_ref3.customer_for_scm_report_name, share0_ref3.china_business_location_name, share0_ref3.dt_invoice_provisional, share0_ref3.material_type, share0_ref3.dt_arrival_in_port_of_discharge_plan_or_actual
                                      ->  Redistribute Motion 8:8  (slice1; segments: 8)  (cost=0.00..892.69 rows=24 width=92)
                                            Hash Key: share0_ref3.dt_report, share0_ref3.dt_shipment, share0_ref3.delivery_region, share0_ref3.delivery_country_in_contract_name, share0_ref3.customer_for_scm_report_name, share0_ref3.china_business_location_name, share0_ref3.dt_invoice_provisional, share0_ref3.material_type, share0_ref3.dt_arrival_in_port_of_discharge_plan_or_actual
                                            ->  Append  (cost=0.00..892.68 rows=24 width=92)
                                                  ->  Result  (cost=0.00..461.35 rows=22 width=92)
                                                        ->  Result  (cost=0.00..461.35 rows=22 width=92)
                                                              Filter: ((share0_ref3.dt_report = '2025-05-27'::date) AND ((share0_ref3.material_type)::text = 'COMMODITY'::text))
                                                              ->  Shared Scan (share slice:id 1:0)  (cost=0.00..454.40 rows=105543 width=92)
                                                  ->  Result  (cost=0.00..431.33 rows=1 width=90)
                                                        ->  Result  (cost=0.00..431.33 rows=1 width=90)
                                                              Filter: ((share1_ref3.dt_realization = '2025-05-27'::date) AND ((share1_ref3.material_aggr_name)::text = 'COMMODITY'::text))
                                                              ->  Shared Scan (share slice:id 1:1)  (cost=0.00..431.26 rows=1181 width=90)
                          ->  Hash  (cost=463.38..463.38 rows=22 width=100)
                                ->  Result  (cost=0.00..463.38 rows=22 width=100)
                                      Filter: ((share0_ref2.dt_report = '2025-05-27'::date) AND ((share0_ref2.material_type)::text = 'COMMODITY'::text))
                                      ->  Shared Scan (share slice:id 5:0)  (cost=0.00..456.44 rows=105543 width=100)
                    SubPlan 1  (slice5; segments: 8)
                      ->  Aggregate  (cost=0.00..538.54 rows=1 width=8)
                            ->  Result  (cost=0.00..538.54 rows=1 width=8)
                                  Filter: ((share0_ref3.dt_report <= share1_ref2.dt_realization) AND (share0_ref3.dt_shipment = share1_ref2.dt_shipment) AND ((share0_ref3.delivery_region)::text = (share1_ref2.delivery_region_name)::text) AND ((share0_ref3.delivery_country_in_contract_name)::text = (share1_ref2.delivery_country_in_contract_name)::text) AND ((share0_ref3.customer_for_scm_report_name)::text = (share1_ref2.customer_for_scm_report_name)::text) AND ((share0_ref3.china_business_location_name)::text = (share1_ref2.china_business_location_name)::text) AND (share0_ref3.dt_invoice_provisional = share1_ref2.dt_invoice_provisional) AND ((share0_ref3.material_type)::text = (share1_ref2.material_aggr_name)::text) AND (share0_ref3.dt_arrival_in_port_of_discharge_plan_or_actual = share1_ref2.dt_arrival_in_port_of_discharge_plan_or_actual))
                                  ->  Materialize  (cost=0.00..432.11 rows=945 width=98)
                                        ->  Broadcast Motion 8:8  (slice3; segments: 8)  (cost=0.00..432.02 rows=945 width=98)
                                              ->  Result  (cost=0.00..431.32 rows=119 width=98)
                                                    Filter: ((share1_ref2.material_aggr_name)::text = 'COMMODITY'::text)
                                                    ->  Shared Scan (share slice:id 3:1)  (cost=0.00..431.28 rows=1181 width=98)
Optimizer: Pivotal Optimizer (GPORCA)
SELECT typinput='array_in'::regproc as is_array, typtype, typname, pg_type.oid   FROM pg_catalog.pg_type   LEFT JOIN (select ns.oid as nspoid, ns.nspname, r.r           from pg_namespace as ns           join ( select s.r, (current_schemas(false))[s.r] as nspname                    from generate_series(1, array_upper(current_schemas(false), 1)) as s(r) ) as r          using ( nspname )        ) as sp     ON sp.nspoid = typnamespace  WHERE pg_type.oid = $1  ORDER BY sp.r, pg_type.oid DESC
SET search_path = public,public,"$user"
SET search_path = public,public,"$user"
SET search_path = public,public,"$user"
SET search_path = public,public,"$user"
SET search_path = public,public,"$user"
SET search_path = public,public,"$user"
SET search_path = public,public,"$user"


default_group	6437	0	0	0	152	00:00:00	{"-1":0.81, "0":0.56, "1":0.56, "2":0.53, "3":0.53, "4":0.63, "5":0.63, "6":0.52, "7":0.52}	{"-1":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "0":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "1":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "2":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "3":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "4":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "5":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "6":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}, "7":{"used":0, "available":0, "quota_used":0, "quota_available":0, "quota_granted":0, "quota_proposed":0, "shared_used":0, "shared_available":0, "shared_granted":0, "shared_proposed":0}}
admin_group	6438	0	0	0	159	00:00:00	{"-1":0.00, "0":0.00, "1":0.00, "2":0.00, "3":0.00, "4":0.00, "5":0.00, "6":0.00, "7":0.00}	{"-1":{"used":0, "available":2714, "quota_used":0, "quota_available":540, "quota_granted":540, "quota_proposed":540, "shared_used":0, "shared_available":2174, "shared_granted":2174, "shared_proposed":2174}, "0":{"used":0, "available":5392, "quota_used":0, "quota_available":1040, "quota_granted":1040, "quota_proposed":1040, "shared_used":0, "shared_available":4352, "shared_granted":4352, "shared_proposed":4352}, "1":{"used":0, "available":5392, "quota_used":0, "quota_available":1040, "quota_granted":1040, "quota_proposed":1040, "shared_used":0, "shared_available":4352, "shared_granted":4352, "shared_proposed":4352}, "2":{"used":0, "available":5424, "quota_used":0, "quota_available":1080, "quota_granted":1080, "quota_proposed":1080, "shared_used":0, "shared_available":4344, "shared_granted":4344, "shared_proposed":4344}, "3":{"used":0, "available":5424, "quota_used":0, "quota_available":1080, "quota_granted":1080, "quota_proposed":1080, "shared_used":0, "shared_available":4344, "shared_granted":4344, "shared_proposed":4344}, "4":{"used":0, "available":5424, "quota_used":0, "quota_available":1080, "quota_granted":1080, "quota_proposed":1080, "shared_used":0, "shared_available":4344, "shared_granted":4344, "shared_proposed":4344}, "5":{"used":0, "available":5424, "quota_used":0, "quota_available":1080, "quota_granted":1080, "quota_proposed":1080, "shared_used":0, "shared_available":4344, "shared_granted":4344, "shared_proposed":4344}, "6":{"used":0, "available":5424, "quota_used":0, "quota_available":1080, "quota_granted":1080, "quota_proposed":1080, "shared_used":0, "shared_available":4344, "shared_granted":4344, "shared_proposed":4344}, "7":{"used":0, "available":5424, "quota_used":0, "quota_available":1080, "quota_granted":1080, "quota_proposed":1080, "shared_used":0, "shared_available":4344, "shared_granted":4344, "shared_proposed":4344}}
etl_group	1392742	1	0	0	58	00:00:00	{"-1":0.01, "0":0.01, "1":0.01, "2":0.01, "3":0.01, "4":0.02, "5":0.03, "6":0.01, "7":0.01}	{"-1":{"used":0, "available":8144, "quota_used":80, "quota_available":1520, "quota_granted":1600, "quota_proposed":1600, "shared_used":0, "shared_available":6544, "shared_granted":6544, "shared_proposed":6544}, "0":{"used":0, "available":16176, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":12976, "shared_granted":12976, "shared_proposed":12976}, "1":{"used":0, "available":16176, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":12976, "shared_granted":12976, "shared_proposed":12976}, "2":{"used":0, "available":16276, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":13076, "shared_granted":13076, "shared_proposed":13076}, "3":{"used":0, "available":16276, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":13076, "shared_granted":13076, "shared_proposed":13076}, "4":{"used":0, "available":16276, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":13076, "shared_granted":13076, "shared_proposed":13076}, "5":{"used":0, "available":16276, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":13076, "shared_granted":13076, "shared_proposed":13076}, "6":{"used":0, "available":16276, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":13076, "shared_granted":13076, "shared_proposed":13076}, "7":{"used":0, "available":16276, "quota_used":160, "quota_available":3040, "quota_granted":3200, "quota_proposed":3200, "shared_used":0, "shared_available":13076, "shared_granted":13076, "shared_proposed":13076}}


32MB
