--TEP_FG_AL_PRD_ALM_ALLOY
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
		and kiar.account_code = 'TEP_FG_AL_PRD_ALM_ALLOY';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan,
	korr_plan
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN
	from (
		with mas_actual as (
		select
			mepd."DATETRUNC" DT_REPORT,
			map.entity_code,
			sum(round(mepd."ALLOY"/1000,3)) ACTUAL
		from stg."MES_LP_ALSGP_AR" mepd
		join dict_dds.map_kpi_report_account_to_entity map on UPPER(mepd."NAME")=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_ALLOY'
		where
		1=1
		and mepd."DATETRUNC" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
		and mepd."NAME" != 'Kubal'
		group by mepd."DATETRUNC", map.entity_code
		union all select
			mepd."DATETRUNC" DT_REPORT,
			map.entity_code,
			sum(round(mepd."ALLOY"/1000,3)) ACTUAL
		from stg."MES_LP_ALSGP_2MONTH" mepd
		join dict_dds.map_kpi_report_account_to_entity map on UPPER(mepd."NAME")=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_ALLOY'
		where
			1=1
			and mepd."DATETRUNC" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
			and mepd."NAME" != 'Kubal'
		group by mepd."DATETRUNC", map.entity_code
		union all select
			(to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval DT_REPORT,
			map.entity_code,
			round(sum(mepd.vikt::numeric)/1000,3) ACTUAL
		from stg.sapxi_production_aluminium_finish_goods_kubal mepd
		join dict_dds.map_kpi_report_account_to_entity map on UPPER('Kubal')=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
		where (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date >=  DATE_TRUNC('MONTH', now())
			and mepd.prodgrp in ('1','2')
			and mepd.chargenr = mepd.bunt
	  		and mepd.chargenr::numeric > 0
	  		AND coalesce(mepd.fordon,'-') not in ('Vrak','Sparrat','Returskrot')
		group by map.entity_code, (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval
		union all select
			(case when date_part('DAY', now()) <> 1 then (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date else (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval end) DT_REPORT,
			map.entity_code,
			round(sum(mepd.vikt::numeric)/1000,3) ACTUAL
		from stg.sapxi_production_aluminium_finish_goods_kubal mepd
		join dict_dds.map_kpi_report_account_to_entity map on UPPER('Kubal')=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
		where( (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  >=  DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
			and  (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  <  DATE_TRUNC('MONTH', now()))
			and mepd.prodgrp in ('1','2')
			and mepd.chargenr = mepd.bunt
	  		and mepd.chargenr::numeric > 0
	  		AND coalesce(mepd.fordon,'-') not in ('Vrak','Sparrat','Returskrot')
		group by map.entity_code, (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date
	),
	mas_actual_goal as (
		select
			vkgr."DAYNAME" "REPORT_DATE",
			map.entity_code "ENTITY",
			round(vkgr."YEAR_PLAN",5) ACTUAL_GOAL,
			round(vkgr."MONTH_PLAN",5) ACTIVE_PLAN,
			round(vkgr."KORRACT",5) KORR_PLAN
		from stg."V_KPI_FG_AL_HYP" vkgr
		join dict_dds.map_kpi_report_account_to_entity map on vkgr."ENTITY"=map.entity_code and map.account_code = 'TEP_FG_AL_PRD_ALM_ALLOY'
		where
			1=1
			and vkgr."ACCOUNT" = 'TEP_FG_AL_PRD_ALM_ALLOY'
			and vkgr."ENTITY" not in ('BU_ALUM', 'BU_AL_AD')
			and vkgr."DAYNAME" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
			and vkgr."DAYNAME" <= DATE_TRUNC('MONTH', now()) - '1 DAY'::interval
		union all select
			(case when vkgr."ENTITY" = 'BU_AL_KUBAL' then vkgr."DAYNAME"+'1 DAY'::interval else vkgr."DAYNAME" end) "REPORT_DATE",
			map.entity_code "ENTITY",
			round(vkgr."YEAR_PLAN",5) ACTUAL_GOAL,
			round(vkgr."MONTH_PLAN",5) ACTIVE_PLAN,
			round(vkgr."KORRACT",5) KORR_PLAN
		from stg."V_KPI_FG_AL_HYP" vkgr
		join dict_dds.map_kpi_report_account_to_entity map on vkgr."ENTITY"=map.entity_code and map.account_code = 'TEP_FG_AL_PRD_ALM_ALLOY'
		where
			1=1
			and vkgr."ACCOUNT" = 'TEP_FG_AL_PRD_ALM_ALLOY'
			and vkgr."ENTITY" not in ('BU_ALUM', 'BU_AL_AD')
			and vkgr."DAYNAME" >= DATE_TRUNC('MONTH', now())
			and vkgr."DAYNAME" <= (DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval) - '1 DAY'::interval
	)
	select
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		coalesce(ms.ENTITY_CODE, mag."ENTITY") ENTITY_CODE,
		'TEP_FG_AL_PRD_ALM_ALLOY' ACCOUNT_CODE,
		ms.ACTUAL ACTUAL,
		mag.ACTUAL_GOAL,
		mag.ACTIVE_PLAN,
		mag.KORR_PLAN
	from mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	UNION ALL
	SELECT
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'TEP_FG_AL_PRD_ALM_ALLOY' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL,
		sum(mag.ACTIVE_PLAN) ACTIVE_PLAN,
		sum(mag.KORR_PLAN) KORR_PLAN
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	where coalesce(ms.ENTITY_CODE,mag."ENTITY") not in ('BU_AL_BOAZ')
	GROUP BY  coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	UNION ALL
	SELECT
	    coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'TEP_FG_AL_PRD_ALM_ALLOY' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL,
		sum(mag.ACTIVE_PLAN) ACTIVE_PLAN,
		sum(mag.KORR_PLAN) KORR_PLAN
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	GROUP BY  coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	) t1
	;

--TEP_FG_AL_PRD_ALM_TOTAL
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
		and kiar.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL';

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan,
	korr_plan,
	forecast_month
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN,
		t1.forecast_month
	from (
		with mas_actual as (
		select
			mepd."DATETRUNC" DT_REPORT,
			map.entity_code,
			sum(round(mepd."NETTO"/1000,3)) ACTUAL
		from stg."MES_LP_ALSGP_AR" mepd
		join dict_dds.map_kpi_report_account_to_entity map on UPPER(mepd."NAME")=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
		where
		1=1
		and mepd."DATETRUNC" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
		and mepd."NAME" != 'Kubal'
		group by mepd."DATETRUNC", map.entity_code
		union all select
			mepd."DATETRUNC" DT_REPORT,
			map.entity_code,
			sum(round(mepd."NETTO"/1000,3)) ACTUAL
		from stg."MES_LP_ALSGP_2MONTH" mepd
		join dict_dds.map_kpi_report_account_to_entity map on UPPER(mepd."NAME")=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
		where
		1=1
		and mepd."DATETRUNC" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
		and mepd."NAME" != 'Kubal'
		group by mepd."DATETRUNC", map.entity_code
		union all
			select
				(to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval DT_REPORT,
				map.entity_code,
				round(sum(mepd.vikt::numeric)/1000,3) ACTUAL
			from stg.sapxi_production_aluminium_finish_goods_kubal mepd
			join dict_dds.map_kpi_report_account_to_entity map on UPPER('Kubal')=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
			where  (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date >=  DATE_TRUNC('MONTH', now())
				and mepd.prodgrp in ('1','2','4')
				and mepd.chargenr = mepd.bunt
		  		and mepd.chargenr::numeric > 0
		  		AND coalesce(mepd.fordon,'-') not in ('Vrak','Sparrat','Returskrot')
			group by map.entity_code, (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval
		union all
			select
				(case when date_part('DAY', now()) <> 1 then (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date else (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval end) DT_REPORT,
				map.entity_code,
				round(sum(mepd.vikt::numeric)/1000,3) ACTUAL
			from stg.sapxi_production_aluminium_finish_goods_kubal mepd
			join dict_dds.map_kpi_report_account_to_entity map on UPPER('Kubal')=UPPER(map.source_entity_code) and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
			where  (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date >=  DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
				and  (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date <  DATE_TRUNC('MONTH', now())
				and mepd.prodgrp in ('1','2','4')
				and mepd.chargenr = mepd.bunt
		  		and mepd.chargenr::numeric > 0
		  		AND coalesce(mepd.fordon,'-') not in ('Vrak','Sparrat','Returskrot')
			group by map.entity_code, (to_timestamp(datumtid, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date
	),
	mas_actual_goal as (
		select
			(case when map.entity_code = 'BU_AL_KUBAL' and vkgr."DAYNAME">= date_trunc('MONTH', now()) then (vkgr."DAYNAME"+'1 DAY'::interval) else vkgr."DAYNAME" end)::date "REPORT_DATE",
			map.entity_code "ENTITY",
			round(vkgr."YEAR_PLAN",5) ACTUAL_GOAL,
			round(vkgr."MONTH_PLAN",5) ACTIVE_PLAN,
			round(vkgr."KORRACT",5) KORR_PLAN,
			round(vkgr."OPERFACT",5) forecast_month
		from stg."V_KPI_FG_AL_HYP" vkgr
		join dict_dds.map_kpi_report_account_to_entity map on vkgr."ENTITY"=map.entity_code and map.account_code = 'TEP_FG_AL_PRD_ALM_TOTAL'
		where
			1=1
			and vkgr."ACCOUNT" = 'TEP_FG_AL_PRD_ALM_TOTAL'
			and vkgr."ENTITY" not in ('BU_ALUM', 'BU_AL_AD')
			and vkgr."DAYNAME" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
			and vkgr."DAYNAME" <= (DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval) - '1 DAY'::interval
	)
	select
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		coalesce(ms.ENTITY_CODE, mag."ENTITY") ENTITY_CODE,
		'TEP_FG_AL_PRD_ALM_TOTAL' ACCOUNT_CODE,
		ms.ACTUAL ACTUAL,
		mag.ACTUAL_GOAL,
		mag.ACTIVE_PLAN,
		mag.KORR_PLAN,
		mag.forecast_month
	from mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	UNION ALL
	SELECT
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'TEP_FG_AL_PRD_ALM_TOTAL' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL,
		sum(mag.ACTIVE_PLAN) ACTIVE_PLAN,
		sum(mag.KORR_PLAN) KORR_PLAN,
		sum(mag.forecast_month) forecast_month
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	where coalesce(ms.ENTITY_CODE,mag."ENTITY") not in ('BU_AL_BOAZ')
	GROUP BY  coalesce(ms.DT_REPORT,mag."REPORT_DATE")

	UNION ALL
	SELECT
	    coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'TEP_FG_AL_PRD_ALM_TOTAL' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL,
		sum(mag.ACTIVE_PLAN) ACTIVE_PLAN,
		sum(mag.KORR_PLAN) KORR_PLAN,
		sum(mag.forecast_month) forecast_month
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	GROUP BY  coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	) t1
	;


--KPI_AL_QUAL_CLAIM_WAIT
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_CLAIM_WAIT';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (

with mas_day as (
select
(drab."MON01"||drab."MON02"||drab."MON03"||drab."MON04"||drab."MON05"||drab."MON06"||drab."MON07"||drab."MON08"||drab."MON09"||drab."MON10"||drab."MON11"||drab."MON12") day_month
from stg."TFACS" drab
where drab."IDENT" = 'ZB' and drab."JAHR" = date_part('YEAR',TIMESTAMP 'now')::varchar
),
actual_calendar as (
select
c.dt as gs,
(select substring(md.day_month,((c.dt - date_trunc('year',now())::date)+1),1) day_count from mas_day md) dayZ
from dict_dds.calendar c
where c.calendar_year = date_part('YEAR',TIMESTAMP 'now')
order by c.dt asc
),
finday as (
select gs from actual_calendar
where dayz = '0'
order by gs asc
),
mas_value as (
select
kir."ID_DOC" id_claim,
kir."RESPONS_FOR_REVIEW" entity,
kir."STATE_REPORT" state,
kir."DT_START" date_start,
kir."FACT_DT_RESPONS" date_response,
kir."CLOSE_DT" date_close,
kir."DT_START_STOPPING_RESPONSE" date_start_stopping,
--kir."DT_REPORT" DT_REPORT,
kir."DT_START" DT_REPORT,
kir."DT_STOPPING_RESPONS" date_finish_stopping,
dt_mty.gs start_period,
(DATE_TRUNC('MONTH',dt_mty.gs) + '1 MONTH'::INTERVAL - '1 DAY'::interval)::date finish_period
from stg.kpi_indicators_register_of_claims kir
left join (
				select gs::date
				from generate_series(DATE_TRUNC('MONTH', to_date('01.01.2025','dd.mm.yyyy')),now(), interval '1 month')  as gs
				) dt_mty on dt_mty.gs >= DATE_TRUNC('MONTH',kir."DT_START") and dt_mty.gs <= DATE_TRUNC('MONTH',coalesce(kir."CLOSE_DT",now()))
where kir."STATE_REPORT" in ('Признано','На рассм.','Не признано')
order by kir."ID_DOC", dt_mty.gs),
results as (
select
mv.id_claim,
mv.entity,
mv.state,
mv.date_start,
mv.date_response,
mv.date_close,
mv.start_period,
mv.finish_period,
mv.date_start_stopping,
mv.DT_REPORT,
mv.date_finish_stopping,
(

case
when mv.DT_REPORT is not null and mv.date_start_stopping is not null and mv.date_finish_stopping is not null and (mv.date_close between mv.start_period and mv.finish_period)
then ((mv.date_finish_stopping - mv.date_start_stopping + 1) - (
																select count(fd.gs)
																from finday fd
																where fd.gs >= mv.date_start_stopping and fd.gs <=mv.date_finish_stopping
																))
else 0
end
) delta_response,
(

case
when mv.DT_REPORT is not null and mv.date_start is not null and mv.date_response is not null and (mv.date_close between mv.start_period and mv.finish_period)
then ((mv.date_response - mv.date_start + 1) - (
																select count(fd.gs)
																from finday fd
																where fd.gs >= mv.date_start and fd.gs <=mv.date_response
																))
else 0
end
) as response_time
from mas_value mv
),
length_day_response as (
select
r.id_claim,
mkrate.entity_code,
r.state,
r.date_start,
r.date_response,
r.date_close,
r.start_period,
r.finish_period,
r.date_start_stopping,
r.DT_REPORT,
r.date_finish_stopping,
r.delta_response,
(
case
when r.date_start is not null and r.date_close is not null and  (r.date_close between r.start_period and r.finish_period)
then ((r.date_close - r.date_start + 1) - (
											select count(fd.gs)
											from finday fd
											where fd.gs >= r.date_start and fd.gs <=r.date_close
											))-r.delta_response - r.response_time
else null
end
) length_day



from results r
join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.account_code ='KPI_AL_QUAL_CLAIM_WAIT' and r.ENTITY=mkrate.source_entity_code
where (r.date_close between r.start_period and r.finish_period)
),

mas_actual as (
select
s.start_period DT_REPORT,
s.ENTITY_CODE,
round(avg(s.length_day),2) ACTUAL
from length_day_response s
where
	s.date_close is not null
	and (s.date_close <= s.finish_period and s.date_close >= s.start_period)
	--and s.length_day>0
	and s.length_day is not null
group by s.start_period, s.ENTITY_CODE
order by  s.start_period, s.ENTITY_CODE
),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			vkgr."ENTITY",
			round(vkgr."ACTIVE_GOAL",2) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
				and (vkgr."ACCOUNT" = 'KPI_AL_QUAL_CLAIM_WAIT' and vkgr."REPORT_DATE" < '2025-01-01'
				or vkgr."ACCOUNT" = 'KPI_QLT_02' and vkgr."REPORT_DATE" >= '2025-01-01')
				and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')

		union all

		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			'BU_AL_DOK_AD' as "ENTITY",
			round(vkgr."ACTIVE_GOAL",2) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
				and (vkgr."ACCOUNT" = 'KPI_AL_QUAL_CLAIM_WAIT' and vkgr."REPORT_DATE" < '2025-01-01'
				or vkgr."ACCOUNT" = 'KPI_QLT_02' and vkgr."REPORT_DATE" >= '2025-01-01')
				and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
				and vkgr."ENTITY" = 'BU_AL_AD'
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_CLAIM_WAIT' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		s.start_period DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_CLAIM_WAIT' ACCOUNT_CODE,
		round(avg(s.length_day),2) ACTUAL,
		round(avg(mag.ACTUAL_GOAL),2) ACTUAL_GOAL
	FROM length_day_response s
	left join mas_actual_goal mag on mag."ENTITY" = s.ENTITY_CODE and DATE_TRUNC('month', s.start_period) = mag."REPORT_DATE"
		where s.ENTITY_CODE != 'BU_AL_BOAZ' --s.length_day>0 and
		and s.length_day is not null
		group by s.start_period
	UNION ALL
	SELECT
	   s.start_period DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_CLAIM_WAIT' ACCOUNT_CODE,
		round(avg(s.length_day),2) ACTUAL,
		round(avg(mag.ACTUAL_GOAL),2) ACTUAL_GOAL
	FROM length_day_response s
	left join mas_actual_goal mag on mag."ENTITY" = s.ENTITY_CODE and DATE_TRUNC('month', s.start_period) = mag."REPORT_DATE"
		where 1=1 --and s.length_day>0
		and s.length_day is not null
		group by s.start_period
	) t1;

--KPI_AL_QUAL_PRODCHAR_133
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_PRODCHAR_133';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			ent.DT_REPORT,
			coalesce ((CASE
				WHEN ent.ENTITY = 'КрАЗ' THEN 'BU_AL_KRAZ'
                WHEN ent.ENTITY = 'БрАЗ' THEN 'BU_AL_BRAZ'
                WHEN ent.ENTITY = 'САЗ' THEN 'BU_AL_SAZ_TOTAL'
                WHEN ent.ENTITY = 'НкАЗ' THEN 'BU_AL_NKAZ'
                WHEN ent.ENTITY = 'ТАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ТаАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ИркАЗ' THEN 'BU_AL_IRKAZ'
                WHEN ent.ENTITY = 'БоАЗ' THEN 'BU_AL_BOAZ'
                WHEN ent.ENTITY = 'ВгАЗ' THEN 'BU_DNP_VGAZ'
                WHEN ent.ENTITY = 'КАЗ' THEN 'BU_AL_KAZ'
                WHEN ent.ENTITY = 'Кубал' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'КУБАЛ' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'ТАФ' THEN 'BU_AL_TAF'
                ELSE ent.ENTITY END), 'Undefined')	ENTITY_CODE,
                ent.ACTUAL
		from (
		select
			mepd."DT" DT_REPORT,
			mepd."ENTITY_NAME" ENTITY,
			round(cast(mepd."PPK" as numeric),1) ACTUAL
		FROM stg.kpi_aggregation_characteristic_ppk mepd
		where
		1=1
		and mepd."ACCOUNT_NAME" like '%Ppk>=1,33%'
		and mepd."DT" >= date_trunc('YEAR',TIMESTAMP 'now')
		) ent
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			(case  WHEN vkgr."ENTITY" = 'BU_AL_SAZ' THEN 'BU_AL_SAZ_TOTAL' else vkgr."ENTITY" end)  "ENTITY",
			round(vkgr."ACTIVE_GOAL",1) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" = 'KPI_AL_QUAL_PRODCHAR_133'
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_133' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_133' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_133' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	GROUP BY ms.DT_REPORT
	) t1
	;


--KPI_AL_QUAL_PRODCHAR_10
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_PRODCHAR_10';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			ent.DT_REPORT,
			coalesce ((CASE
				WHEN ent.ENTITY = 'КрАЗ' THEN 'BU_AL_KRAZ'
                WHEN ent.ENTITY = 'БрАЗ' THEN 'BU_AL_BRAZ'
                WHEN ent.ENTITY = 'САЗ' THEN 'BU_AL_SAZ_TOTAL'
                WHEN ent.ENTITY = 'НкАЗ' THEN 'BU_AL_NKAZ'
                WHEN ent.ENTITY = 'ТАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ТаАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ИркАЗ' THEN 'BU_AL_IRKAZ'
                WHEN ent.ENTITY = 'БоАЗ' THEN 'BU_AL_BOAZ'
                WHEN ent.ENTITY = 'ВгАЗ' THEN 'BU_DNP_VGAZ'
                WHEN ent.ENTITY = 'КАЗ' THEN 'BU_AL_KAZ'
                WHEN ent.ENTITY = 'Кубал' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'КУБАЛ' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'ТАФ' THEN 'BU_AL_TAF'
                ELSE ent.ENTITY END), 'Undefined')	ENTITY_CODE,
                ent.ACTUAL
		from (
		select
			mepd."DT" DT_REPORT,
			mepd."ENTITY_NAME" ENTITY,
			round(cast(mepd."PPK" as numeric),1) ACTUAL
		FROM stg.kpi_aggregation_characteristic_ppk mepd
		where
		1=1
		and mepd."ACCOUNT_NAME" like '%Ppk<1,0%'
		and mepd."DT" >= date_trunc('YEAR',TIMESTAMP 'now')
		) ent
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			(case  WHEN vkgr."ENTITY" = 'BU_AL_SAZ' THEN 'BU_AL_SAZ_TOTAL' else vkgr."ENTITY" end)  "ENTITY",
			round(vkgr."ACTIVE_GOAL",1) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" = 'KPI_AL_QUAL_PRODCHAR_10'
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_10' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_10' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_10' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	GROUP BY ms.DT_REPORT
	) t1
	;


--KPI_AL_QUAL_PRODCHAR_12
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_PRODCHAR_12';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			ent.DT_REPORT,
			coalesce ((CASE
				WHEN ent.ENTITY = 'КрАЗ' THEN 'BU_AL_KRAZ'
                WHEN ent.ENTITY = 'БрАЗ' THEN 'BU_AL_BRAZ'
                WHEN ent.ENTITY = 'САЗ' THEN 'BU_AL_SAZ_TOTAL'
                WHEN ent.ENTITY = 'НкАЗ' THEN 'BU_AL_NKAZ'
                WHEN ent.ENTITY = 'ТАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ТаАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ИркАЗ' THEN 'BU_AL_IRKAZ'
                WHEN ent.ENTITY = 'БоАЗ' THEN 'BU_AL_BOAZ'
                WHEN ent.ENTITY = 'ВгАЗ' THEN 'BU_DNP_VGAZ'
                WHEN ent.ENTITY = 'КАЗ' THEN 'BU_AL_KAZ'
                WHEN ent.ENTITY = 'Кубал' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'КУБАЛ' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'ТАФ' THEN 'BU_AL_TAF'
                ELSE ent.ENTITY END), 'Undefined')	ENTITY_CODE,
                ent.ACTUAL
		from (
		select
			mepd."DT" DT_REPORT,
			mepd."ENTITY_NAME" ENTITY,
			round(cast(mepd."PPK" as numeric),1) ACTUAL
		FROM stg.kpi_aggregation_characteristic_ppk mepd
		where
		1=1
		and mepd."ACCOUNT_NAME" like '%Ppk от 1,0 до 1,2%'
		and mepd."DT" >= date_trunc('YEAR',TIMESTAMP 'now')
		) ent
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			(case  WHEN vkgr."ENTITY" = 'BU_AL_SAZ' THEN 'BU_AL_SAZ_TOTAL' else vkgr."ENTITY" end)  "ENTITY",
			round(vkgr."ACTIVE_GOAL",1) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" = 'KPI_AL_QUAL_PRODCHAR_12'
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_12' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_12' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_PRODCHAR_12' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	GROUP BY ms.DT_REPORT
	) t1
	;


--KPI_AL_QUAL_PROCESS_PPK_12
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_PROCESS_PPK_12';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			ent.DT_REPORT,
			coalesce ((CASE
				WHEN ent.ENTITY = 'КрАЗ' THEN 'BU_AL_KRAZ'
                WHEN ent.ENTITY = 'БрАЗ' THEN 'BU_AL_BRAZ'
                WHEN ent.ENTITY = 'САЗ' THEN 'BU_AL_SAZ_TOTAL'
                WHEN ent.ENTITY = 'НкАЗ' THEN 'BU_AL_NKAZ'
                WHEN ent.ENTITY = 'ТАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ТаАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ИркАЗ' THEN 'BU_AL_IRKAZ'
                WHEN ent.ENTITY = 'БоАЗ' THEN 'BU_AL_BOAZ'
                WHEN ent.ENTITY = 'ВгАЗ' THEN 'BU_DNP_VGAZ'
                WHEN ent.ENTITY = 'КАЗ' THEN 'BU_AL_KAZ'
                WHEN ent.ENTITY = 'Кубал' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'КУБАЛ' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'ТАФ' THEN 'BU_AL_TAF'
                ELSE ent.ENTITY END), 'Undefined')	ENTITY_CODE,
                ent.ACTUAL
		from (
		select
			mepd."DT" DT_REPORT,
			mepd."ENTITY_NAME" ENTITY,
			round(cast(mepd."PPK" as numeric),1) ACTUAL
		FROM stg.kpi_aggregation_parameters_ppk mepd
		where
		1=1
		and mepd."ACCOUNT_NAME" like '%Ppk более 1,2%'
		and mepd."DT" >= date_trunc('YEAR',TIMESTAMP 'now')
		) ent
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			(case  WHEN vkgr."ENTITY" = 'BU_AL_SAZ' THEN 'BU_AL_SAZ_TOTAL' else vkgr."ENTITY" end)  "ENTITY",
			vkgr."ACTIVE_GOAL" ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" = 'KPI_AL_QUAL_PROCESS_PPK_12'
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_12' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_12' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_12' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	GROUP BY ms.DT_REPORT
	) t1
	;

--KPI_AL_QUAL_PROCESS_PPK_08
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_PROCESS_PPK_08';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			ent.DT_REPORT,
			coalesce ((CASE
				WHEN ent.ENTITY = 'КрАЗ' THEN 'BU_AL_KRAZ'
                WHEN ent.ENTITY = 'БрАЗ' THEN 'BU_AL_BRAZ'
                WHEN ent.ENTITY = 'САЗ' THEN 'BU_AL_SAZ_TOTAL'
                WHEN ent.ENTITY = 'НкАЗ' THEN 'BU_AL_NKAZ'
                WHEN ent.ENTITY = 'ТАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ТаАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ИркАЗ' THEN 'BU_AL_IRKAZ'
                WHEN ent.ENTITY = 'БоАЗ' THEN 'BU_AL_BOAZ'
                WHEN ent.ENTITY = 'ВгАЗ' THEN 'BU_DNP_VGAZ'
                WHEN ent.ENTITY = 'КАЗ' THEN 'BU_AL_KAZ'
                WHEN ent.ENTITY = 'Кубал' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'КУБАЛ' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'ТАФ' THEN 'BU_AL_TAF'
                ELSE ent.ENTITY END), 'Undefined')	ENTITY_CODE,
                ent.ACTUAL
		from (
		select
			mepd."DT" DT_REPORT,
			mepd."ENTITY_NAME" ENTITY,
			round(cast(mepd."PPK" as numeric),1) ACTUAL
		FROM stg.kpi_aggregation_parameters_ppk mepd
		where
		1=1
		and mepd."ACCOUNT_NAME" like '%Ppk от 0,8 до 1,0%'
		and mepd."DT" >= date_trunc('YEAR',TIMESTAMP 'now')
		) ent
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			(case  WHEN vkgr."ENTITY" = 'BU_AL_SAZ' THEN 'BU_AL_SAZ_TOTAL' else vkgr."ENTITY" end)  "ENTITY",
			vkgr."ACTIVE_GOAL" ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" = 'KPI_AL_QUAL_PROCESS_PPK_08'
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_08' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_08' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_08' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	GROUP BY ms.DT_REPORT
	) t1
	;

--KPI_AL_QUAL_PROCESS_PPK_10
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_PROCESS_PPK_10';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			ent.DT_REPORT,
			coalesce ((CASE
				WHEN ent.ENTITY = 'КрАЗ' THEN 'BU_AL_KRAZ'
                WHEN ent.ENTITY = 'БрАЗ' THEN 'BU_AL_BRAZ'
                WHEN ent.ENTITY = 'САЗ' THEN 'BU_AL_SAZ_TOTAL'
                WHEN ent.ENTITY = 'НкАЗ' THEN 'BU_AL_NKAZ'
                WHEN ent.ENTITY = 'ТАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ТаАЗ' THEN 'BU_AL_TAZ'
                WHEN ent.ENTITY = 'ИркАЗ' THEN 'BU_AL_IRKAZ'
                WHEN ent.ENTITY = 'БоАЗ' THEN 'BU_AL_BOAZ'
                WHEN ent.ENTITY = 'ВгАЗ' THEN 'BU_DNP_VGAZ'
                WHEN ent.ENTITY = 'КАЗ' THEN 'BU_AL_KAZ'
                WHEN ent.ENTITY = 'Кубал' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'КУБАЛ' THEN 'BU_AL_KUBAL'
                WHEN ent.ENTITY = 'ТАФ' THEN 'BU_AL_TAF'
                ELSE ent.ENTITY END), 'Undefined')	ENTITY_CODE,
                ent.ACTUAL
		from (
		select
			mepd."DT" DT_REPORT,
			mepd."ENTITY_NAME" ENTITY,
			round(cast(mepd."PPK" as numeric),1) ACTUAL
		FROM stg.kpi_aggregation_parameters_ppk mepd
		where
		1=1
		and mepd."ACCOUNT_NAME" like '%Ppk от 1,0 до 1,2%'
		and mepd."DT" >= date_trunc('YEAR',TIMESTAMP 'now')
		) ent
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			(case  WHEN vkgr."ENTITY" = 'BU_AL_SAZ' THEN 'BU_AL_SAZ_TOTAL' else vkgr."ENTITY" end)  "ENTITY",
			vkgr."ACTIVE_GOAL" ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" = 'KPI_AL_QUAL_PROCESS_PPK_10'
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_10' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_10' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_QUAL_PROCESS_PPK_10' ACCOUNT_CODE,
		avg(ms.ACTUAL) ACTUAL,
		avg(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
	GROUP BY ms.DT_REPORT
	) t1
	;

--KPI_AL_PRD_TOVAL_WH_STOCK
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code = 'KPI_AL_PRD_TOVAL_WH_STOCK';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
	dd.dt_report,
	dd.entity_code,
	dd.ACTUAL
from (
	select
		dt_report,
		mkrate.entity_code,
		SUM(coalesce(dd.total_stock_quantity,0)) ACTUAL
	FROM dm.exp_material_stock_balance_mr_ad dd
	join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.source_entity_code = dd.plant_code and mkrate.account_code = 'KPI_AL_PRD_TOVAL_WH_STOCK'
	WHERE  dd.dt_report >=  DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and dd.dt_report <=  now()
	GROUP by dd.dt_report, mkrate.entity_code
) dd
where dd.actual is not NULL
	),
	mas_actual_goal as (

		select
		c.dt "REPORT_DATE",
		map.entity_code "ENTITY",
		round(sum((cast(vkgr."/BIC/ZIRVALUE"as numeric)) ),1) ACTUAL_GOAL
		from dict_dds.calendar c
		left join stg."/BIC/AZIR_O2300" vkgr on (DATE_TRUNC('MONTH', c.dt) = DATE_TRUNC('MONTH',TO_date(vkgr."CALDAY",'YYYYMMDD')))
		join dict_dds.map_kpi_report_account_to_entity map on vkgr."/BIC/ZIRENTITY" = map.source_entity_code and map.account_code = 'KPI_AL_PRD_TOVAL_WH_STOCK'
		where vkgr."/BIC/ZIRVERS" = 'NORM'
		and TO_date(vkgr."CALDAY",'YYYYMMDD') >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
group by
	c.dt,
	map.entity_code

	)
	select
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		coalesce(ms.ENTITY_CODE, mag."ENTITY") ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_STOCK' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	UNION ALL
	SELECT
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_STOCK' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	UNION ALL
	SELECT
	    coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_STOCK' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	GROUP BY coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	) t1;

--KPI_AL_PRD_TOVAL_SHIPPING
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code = 'KPI_AL_PRD_TOVAL_SHIPPING';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
		select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
		ssfp.dt_shipment as dt_report,
		map.entity_code,
		sum(ssfp.weight_net) as ACTUAL
		from dm.sales_shipment_from_plant ssfp
		join dict_dds.map_kpi_report_account_to_entity map on ssfp.plant_producer_code=map.source_entity_code and map.account_code = 'KPI_AL_PRD_TOVAL_SHIPPING'
		where ssfp.dt_shipment >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		group by ssfp.dt_shipment, map.entity_code
	),
	mas_actual_goal as (
		select
			TO_date(vkgr."CALDAY",'YYYYMMDD') "REPORT_DATE",
			map.entity_code as "ENTITY",
			round(sum((cast(vkgr."/BIC/ZIRVALUE"as numeric)) ),1) ACTUAL_GOAL
			from stg."/BIC/AZIR_O2200" vkgr
			join dict_dds.map_kpi_report_account_to_entity map on vkgr."/BIC/ZIRENTITY"=map.source_entity_code and map.account_code = 'KPI_AL_PRD_TOVAL_SHIPPING'
		where vkgr."/BIC/ZIRVERS" = 'MONTH_PLAN'
		 and vkgr."/BIC/IRCORR"='00004'
	 	and TO_date(vkgr."CALDAY",'YYYYMMDD') >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
	 	group by
			vkgr."CALDAY",
			map.entity_code
	)
	select
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		coalesce(ms.ENTITY_CODE, mag."ENTITY") ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_SHIPPING' ACCOUNT_CODE,
		ms.ACTUAL ACTUAL,
		mag.ACTUAL_GOAL ACTUAL_GOAL
	from mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	UNION ALL
	SELECT
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_SHIPPING' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	UNION ALL
	SELECT
	   coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_SHIPPING' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	GROUP BY coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	) t1
	;

--KPI_AL_QUAL_CLAIM_QTY
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_CLAIM_QTY';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		null ACTUAL_GOAL
	from (
	with mas_value as (
	select
	kir."DT_START" DT_REPORT,
	mkrate.entity_code as ENTITY_CODE,
	count(kir."ID_DOC") ACTUAL
	from stg.kpi_indicators_register_of_claims kir
	join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.account_code = 'KPI_AL_QUAL_CLAIM_QTY' and kir."RESPONS_FOR_REVIEW"=mkrate.source_entity_code
	where kir."STATE_REPORT" in ('Признано','На рассм.','Не признано')
	and kir."DT_START" >= date_trunc('YEAR',TIMESTAMP 'now')
	group by kir."DT_START",mkrate.entity_code
    )

		select
			ms.DT_REPORT,
			ms.ENTITY_CODE,
			'KPI_AL_QUAL_CLAIM_QTY' ACCOUNT_CODE,
			ms.ACTUAL,
			NULL as ACTUAL_GOAL
		from mas_value ms
		UNION ALL
		SELECT
				s.DT_REPORT,
				'BU_AL_AD' ENTITY_CODE,
				'KPI_AL_QUAL_CLAIM_QTY' ACCOUNT_CODE,
				sum(s.ACTUAL) ACTUAL,
				NULL as ACTUAL_GOAL
			from mas_value s
			where s.ENTITY_CODE != 'BU_AL_BOAZ'
			group by s.DT_REPORT
		UNION ALL
		SELECT
		   		s.DT_REPORT,
				'BU_ALUM' ENTITY_CODE,
				'KPI_AL_QUAL_CLAIM_QTY' ACCOUNT_CODE,
				sum(s.ACTUAL) ACTUAL,
				NULL as ACTUAL_GOAL
			from mas_value s
			group by s.DT_REPORT
		) t1
		where t1.dt_report is not null
		;

--KPI_AL_QUAL_CLAIM_REPLY
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'KPI_AL_QUAL_CLAIM_REPLY';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
	with mas_day as (
	select
	(drab."MON01"||drab."MON02"||drab."MON03"||drab."MON04"||drab."MON05"||drab."MON06"||drab."MON07"||drab."MON08"||drab."MON09"||drab."MON10"||drab."MON11"||drab."MON12") day_month
	from stg."TFACS" drab
	where drab."IDENT" = 'ZB' and drab."JAHR" = date_part('YEAR',TIMESTAMP 'now')::varchar
	),
	actual_calendar as (
	select
	c.dt as gs,
	(select substring(md.day_month,((c.dt - date_trunc('year',now())::date)+1),1) day_count from mas_day md) dayZ
	from dict_dds.calendar c
	where c.calendar_year = date_part('YEAR',TIMESTAMP 'now')
	order by c.dt asc
	),
	finday as (
	select gs from actual_calendar
	where dayz = '0'
	order by gs asc
	),
	mas_value as (
	select
	kir."ID_DOC" id_claim,
	kir."RESPONS_FOR_REVIEW" entity,
	kir."STATE_REPORT" state,
	kir."DT_START" date_start,
	kir."FACT_DT_RESPONS" date_response,
	kir."CLOSE_DT" date_close,
	kir."DT_STOPPING_RESPONS" date_start_stopping,
	kir."DT_REPORT" DT_REPORT,
	kir."FINAL_DT_RESPONS" date_finish_stopping,
	dt_mty.gs start_period,
	(DATE_TRUNC('MONTH',dt_mty.gs) + '1 MONTH'::INTERVAL - '1 DAY'::interval)::date finish_period
	from stg.kpi_indicators_register_of_claims kir
	left join (
					select gs::date
					from generate_series(DATE_TRUNC('MONTH', to_date('01.01.2025','dd.mm.yyyy')),now(), interval '1 month')  as gs
					) dt_mty on dt_mty.gs >= DATE_TRUNC('MONTH',kir."DT_START") and dt_mty.gs <= DATE_TRUNC('MONTH',coalesce(kir."FACT_DT_RESPONS",now()))
	where kir."STATE_REPORT" in ('Признано','На рассм.','Не признано')
	order by kir."ID_DOC", dt_mty.gs)
	,
	length_day_response as (
	select
	mv.id_claim,
	mkrate.entity_code,
	mv.state,
	mv.date_start,
	mv.date_response,
	mv.date_close,
	mv.start_period,
	mv.finish_period,
	mv.date_start_stopping,
	mv.DT_REPORT,
	mv.date_finish_stopping,
	(

	case

	when mv.date_start is not null and mv.date_response is not null and (mv.date_response between mv.start_period and mv.finish_period)  --and DATE_TRUNC('MONTH',mv.date_response)>=mv.start_period
	then (((mv.date_response+1) - mv.date_start) - (
													select count(fd.gs)
													from finday fd
													where fd.gs >= mv.date_start and fd.gs <=mv.date_response
													))
	else null
	end
	) date_length_response
	from mas_value mv
	join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.account_code = 'KPI_AL_QUAL_CLAIM_REPLY' and mv.ENTITY=mkrate.source_entity_code
	),
	mas_actual as
	(
	select
	s.start_period DT_REPORT,
	s.ENTITY_CODE,
	round(avg(s.date_length_response),2) ACTUAL
	from length_day_response s
	where s.date_response is not null and s.date_length_response is not null--s.date_length_response>0 --and s.ENTITY_CODE <> 'Undefined' --and s.start_period = to_date('01.07.2024','dd.mm.yyyy') --and s.ENTITY_CODE in ('BU_AL_KUBAL')
	group by s.start_period, s.ENTITY_CODE
	order by  s.start_period, s.ENTITY_CODE
	),
		mas_actual_goal as (
			select
				DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
				vkgr."ENTITY",
				round(vkgr."ACTIVE_GOAL",2) ACTUAL_GOAL
			from stg."V_KPI_GOALS_REPORT" vkgr
			where
				1=1
				and (vkgr."ACCOUNT" = 'KPI_AL_QUAL_CLAIM_REPLY' and vkgr."REPORT_DATE" < '2025-01-01'
				or vkgr."ACCOUNT" = 'KPI_QLT_01' and vkgr."REPORT_DATE" >= '2025-01-01')
				and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')

				union all

			select
				DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
				'BU_AL_DOK_AD' as "ENTITY",
				round(vkgr."ACTIVE_GOAL",2) ACTUAL_GOAL
			from stg."V_KPI_GOALS_REPORT" vkgr
			where
				1=1
				and (vkgr."ACCOUNT" = 'KPI_AL_QUAL_CLAIM_REPLY' and vkgr."REPORT_DATE" < '2025-01-01'
				or vkgr."ACCOUNT" = 'KPI_QLT_01' and vkgr."REPORT_DATE" >= '2025-01-01')
				and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
				and vkgr."ENTITY" = 'BU_AL_AD'
		)
		select
			ms.DT_REPORT,
			ms.ENTITY_CODE,
			'KPI_AL_QUAL_CLAIM_REPLY' ACCOUNT_CODE,
			ms.ACTUAL,
			mag.ACTUAL_GOAL
		from mas_actual ms
		left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE"
		UNION ALL
		SELECT
				s.start_period DT_REPORT,
				'BU_AL_AD' ENTITY_CODE,
				'KPI_AL_QUAL_CLAIM_REPLY' ACCOUNT_CODE,
				round(avg(s.date_length_response),2) ACTUAL,
				round(avg(mag.ACTUAL_GOAL),2) ACTUAL_GOAL
			from length_day_response s
			left join mas_actual_goal mag on mag."ENTITY" = s.ENTITY_CODE and DATE_TRUNC('month', s.start_period) = mag."REPORT_DATE"
			where s.date_response is not null and s.ENTITY_CODE != 'BU_AL_BOAZ'-- and s.date_length_response>0
			and s.date_length_response is not null
			group by s.start_period
		UNION ALL
		SELECT
		   s.start_period DT_REPORT,
				'BU_ALUM' ENTITY_CODE,
				'KPI_AL_QUAL_CLAIM_REPLY' ACCOUNT_CODE,
				round(avg(s.date_length_response),2) ACTUAL,
				round(avg(mag.ACTUAL_GOAL),2) ACTUAL_GOAL
			from length_day_response s
			left join mas_actual_goal mag on mag."ENTITY" = s.ENTITY_CODE and DATE_TRUNC('month', s.start_period) = mag."REPORT_DATE"
			where s.date_response is not null-- and s.date_length_response>0
			and s.date_length_response is not null
			group by s.start_period
		) t1
		where t1.dt_report is not null; --and t1.dt_report = to_date('01.09.2024','dd.mm.yyyy')

	--'SET3.1','SET3.11','SET3.2'
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code in ('SET3.1','SET3.11','SET3.2');

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan
	)
select
		t1."DT_REPORT",
		t1."ENTITY_CODE",
		t1.ACCOUNT_CODE,
		t1."ACTUAL",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN
	from (
		with mas_actual as (
		select
			dt_currency_rate "DT_REPORT",
			'SET3.1' ACCOUNT_CODE,
			'BU_NA' "ENTITY_CODE",
			round(abs(currency_rate),2) "ACTUAL"
		from dict_dds.currency_rates mepd
		where
		currency_rate_type_code = 'M'
		and (currency_from_code = 'USD' and currency_to_code = 'RUB')
		and dt_currency_rate >= date_trunc('YEAR',TIMESTAMP 'now')
	union all select
			dt_currency_rate "DT_REPORT",
			'SET3.11' ACCOUNT_CODE,
			'BU_NA' "ENTITY_CODE",
			round(abs(currency_rate),2) "ACTUAL"
		from dict_dds.currency_rates mepd
		where
			currency_rate_type_code = 'M'
			and 	(currency_from_code = 'CNY' and currency_to_code = 'USD')
			and dt_currency_rate >= date_trunc('YEAR',TIMESTAMP 'now')
		union all select
			dt_currency_rate "DT_REPORT",
			'SET3.2' ACCOUNT_CODE,
			'BU_NA' "ENTITY_CODE",
			round(abs(currency_rate),2) "ACTUAL"
		from dict_dds.currency_rates mepd
		where
			currency_rate_type_code = 'M'
			and (currency_from_code = 'EUR' and currency_to_code = 'USD')
			and dt_currency_rate >= date_trunc('YEAR',TIMESTAMP 'now')
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			vkgr."ACCOUNT",
			vkgr."ENTITY",
			round(vkgr."ACTIVE_GOAL",2) ACTUAL_GOAL,
			round(vkgr."MONTH_PLAN",2) ACTIVE_PLAN
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" in ('SET3.1','SET3.11','SET3.2')
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms."DT_REPORT",
		ms."ENTITY_CODE",
		ms.ACCOUNT_CODE,
		ms."ACTUAL",
		mag.ACTUAL_GOAL,
		mag.ACTIVE_PLAN
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms."ENTITY_CODE" and DATE_TRUNC('month', ms."DT_REPORT") = mag."REPORT_DATE" and mag."ACCOUNT"= ms.ACCOUNT_CODE
	) t1
	;

--'SET1'
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'SET1';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan
	)
		select
		t1."DT_REPORT",
		t1."ENTITY_CODE",
		t1.ACCOUNT_CODE,
		t1."ACTUAL",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN
	from (
		with mas_actual as (
		select
			dt_currency_rate "DT_REPORT",
			'SET1' ACCOUNT_CODE,
			'BU_NA' "ENTITY_CODE",
			round(currency_rate,1) "ACTUAL"
		FROM dict_dds.currency_rates x
		WHERE currency_from_code IN ('ALS') and currency_rate_type_code = 'ALS'
		and dt_currency_rate >= date_trunc('YEAR',TIMESTAMP 'now')
		),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			vkgr."ACCOUNT",
			vkgr."ENTITY",
			round(vkgr."ACTIVE_GOAL",1) ACTUAL_GOAL,
			round(vkgr."MONTH_PLAN",1) ACTIVE_PLAN
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" in ('SET1')
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms."DT_REPORT",
		ms."ENTITY_CODE",
		ms.ACCOUNT_CODE,
		ms."ACTUAL",
		mag.ACTUAL_GOAL,
		mag.ACTIVE_PLAN
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms."ENTITY_CODE" and DATE_TRUNC('month', ms."DT_REPORT") = mag."REPORT_DATE" and mag."ACCOUNT"= ms.ACCOUNT_CODE
	) t1
	;


	--'SET95'
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'SET95';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (
		select
			mepd."QUOTE_DATE" DT_REPORT,
			'BU_NA' ENTITY_CODE,
			round(mepd."VALUE",2) ACTUAL,
			'SET95' ACCOUNT_CODE
		FROM dict_stg."V_DOB_QUOTE_VALUES" mepd
		where
		1=1
		and mepd."QUOTE_ID" = 'FUEL_01'
		and mepd."QUOTE_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	),
	mas_actual_goal as (
		select
			DATE_TRUNC('month',vkgr."REPORT_DATE") "REPORT_DATE",
			vkgr."ACCOUNT",
			vkgr."ENTITY",
			round(vkgr."ACTIVE_GOAL",2) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		where
			1=1
			and vkgr."ACCOUNT" in ('SET95')
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		ms.ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	left join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and DATE_TRUNC('month', ms.DT_REPORT) = mag."REPORT_DATE" and ms.ACCOUNT_CODE = mag."ACCOUNT"
	) t1
	;

	--Убрал ручные маппингм по задаче KPID-409
	--KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code = 'KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		null ACTUAL_GOAL
	from (

with t_main as (
	select
		ssfp.dt_collection,
		coalesce(ssfp.dt_shipment,(date_trunc('day', now()) + '1 day'::interval)::date) as dt_shipment,
		ssfp.plant_producer_code,
		sum(ssfp.weight_net) as weight_net
	from dm.sales_shipment_from_plant ssfp
	where ssfp.dt_collection >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		group by
		ssfp.dt_collection,
		ssfp.dt_shipment,
		ssfp.plant_producer_code
),

mas_actual as (
		select
		dd.dt_report,
		dd.entity_code,
		dd.ACTUAL
	from (
		select
			cal.dt as dt_report,
			mkrate.entity_code as entity_code,
			sum(t_main.weight_net) as actual
		from t_main
		join dict_dds.calendar cal on t_main.dt_collection <= cal.dt and cal.dt < t_main.dt_shipment
		join dict_dds.map_kpi_report_account_to_entity mkrate on t_main.plant_producer_code = mkrate.source_entity_code and mkrate.account_code = 'KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK'
		where cal.dt >= (DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval) and cal.dt <= (date_trunc('day', now()) + '1 day'::interval)::date
			group by
			cal.dt,
			mkrate.entity_code
) dd
where dd.actual is not NULL
	)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK' ACCOUNT_CODE,
		ms.ACTUAL
	from mas_actual ms
	UNION ALL
	SELECT
		ms.DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL
	FROM mas_actual ms
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY ms.DT_REPORT
	UNION ALL
	SELECT
	    ms.DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL
	FROM mas_actual ms
	GROUP BY ms.DT_REPORT
	) t1;



--KPI_AF_PROD_VOLA_ZA, KPI_AF_PROD_VOLA_SP, TEP_PR2.1.5, KPI_AL_PRD_ZA_VOL, KPI_AL_PRD_OA_VOL, KPI_AL_PRD_BAKED_OIL_COKE, SHIPPING_ANODE_MASS, SHIPPING_BAKED_COKE
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and kiar.account_code in ('KPI_AF_PROD_VOLA_ZA','KPI_AF_PROD_VOLA_SP','TEP_PR2.1.5','KPI_AL_PRD_ZA_VOL','KPI_AL_PRD_OA_VOL','KPI_AL_PRD_BAKED_OIL_COKE', 'SHIPPING_ANODE_MASS', 'SHIPPING_BAKED_COKE') ;

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan
	)
	select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		round(t1.ACTUAL_GOAL,3) ACTUAL_GOAL,
		t1.MONTH_PLAN
	from (
				with mas_actual as (
		select
			ent.DT_REPORT,
			ent.ACCOUNT_CODE,
            mkrate.entity_code,
            sum(ent.ACTUAL) ACTUAL,
            sum(ent.ACTUAL_GOAL) ACTUAL_GOAL,
            sum(ent.MONTH_PLAN) MONTH_PLAN
		from ( --KPI_AF_PROD_VOLA_SP, KPI_AL_PRD_ZA_VOL есть данные по ТП, остальное ТП = ОКГ

		--ЗеленыеАноды
		--Отгрузка ЗА
		select
			to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'KPI_AF_PROD_VOLA_ZA' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ТП%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Отгрузка ЗА%)+%(Факт - за сутки|БП - за сутки|ТП - за сутки)%')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'
		union all

		--Производство ЗА

		select
			to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'KPI_AL_PRD_ZA_VOL' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ОКГ%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Производство ЗА%)+%(Факт - за сутки|БП - за сутки|ОКГ)%')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'
		union all

	--ОбожженыеАноды
		--Отгрузка ОА

		select
			to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'KPI_AF_PROD_VOLA_SP' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ТП%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Отгрузка ОА%)+%(Факт - за сутки|БП - за сутки|ТП - за сутки)%')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'
		union all

		--Производство ОА

		select
			to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'KPI_AL_PRD_OA_VOL' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ОКГ%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Производство ОА%)+%(Факт - за сутки|БП - за сутки|ОКГ)%')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'
		union all

	--Анодная масса
		--Отгрузка анодной массы

		select
			to_date(to_char(mepd."timestamp"::timestamp + giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'SHIPPING_ANODE_MASS' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ТП%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Отгрузка анодной массы%)+(Факт - за сутки|ТП - за сутки)')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'
		union all

		--Производства анодной массы

		select
			to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'TEP_PR2.1.5' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ОКГ%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Производство анодной массы%)+%(Факт - за сутки|БП - за сутки|ОКГ)%')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'

	--Прокаленный кокс
		--Отгрузка прокаленного кокса
		union all

		select
			to_date(to_char(mepd."timestamp"::timestamp + giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'SHIPPING_BAKED_COKE' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ТП%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Отгрузка прокаленного кокса%)+(Факт - за сутки|ТП - за сутки)')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'
		union all

		--Производство прокаленного кокса

		select
			to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
			'KPI_AL_PRD_BAKED_OIL_COKE' ACCOUNT_CODE,
			split_part(giz.guid_name,'.',1) ENTITY,
			case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL,
			case when giz.guid_name like '%БП%' then cast(mepd.value as numeric) else 0 end as ACTUAL_GOAL,
			case when giz.guid_name like '%ОКГ%' then cast(mepd.value as numeric) else 0 end as MONTH_PLAN
		from stg.auxiliary_production_anode_zyfra mepd
		join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
		where
		1=1
		and giz.guid_name SIMILAR to ('(%Производство прокаленного кокса%)+(Факт - за сутки|ОКГ)')
		and mepd."timestamp"::timestamp +giz.utc_offset_code >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval
		and mepd.statuscode = '0'

	) ent
	join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.account_code = ent.ACCOUNT_CODE and mkrate.source_entity_code = ent.ENTITY
		group by
			ent.DT_REPORT,
			ent.ACCOUNT_CODE,
            mkrate.entity_code
	),

	mas_actual_goal as (
		select
			c.dt as DT_REPORT,
			vkgr."ACCOUNT" as ACCOUNT_CODE,
			vkgr."ENTITY" as ENTITY_CODE,
			(case when "ACCOUNT" in ('KPI_AL_PRD_BAKED_OIL_COKE','KPI_AL_PRD_ZA_VOL','KPI_AL_PRD_OA_VOL') then (vkgr."ACTIVE_GOAL"*1000)/((DATE_PART('days',DATE_TRUNC('month', vkgr."REPORT_DATE") + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric)
				else vkgr."ACTIVE_GOAL"/((DATE_PART('days',DATE_TRUNC('month', vkgr."REPORT_DATE") + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric)
				end) ACTUAL_GOAL
		from stg."V_KPI_GOALS_REPORT" vkgr
		join dict_dds.calendar c on c.calendar_year = extract(year from vkgr."REPORT_DATE") and c.calendar_month = extract(month from vkgr."REPORT_DATE")
		join dict_dds.map_kpi_report_account_to_entity mkrate on vkgr."ACCOUNT" = mkrate.account_code and vkgr."ENTITY" = mkrate.entity_code
		where
			1=1
			and vkgr."ACCOUNT" in ('TEP_PR2.1.5','KPI_AL_PRD_ZA_VOL','KPI_AL_PRD_OA_VOL','KPI_AL_PRD_BAKED_OIL_COKE')
			and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval and vkgr."REPORT_DATE" < date_trunc('MONTH',TIMESTAMP 'now') + '1 month'::interval
			and vkgr."ENTITY" not in ('BU_AL_AD','BU_ALUM')

		union all

			select --Новый расчет плана по KPI_AF_PROD_VOLA_ZA и KPI_AF_PROD_VOLA_SP
			c.dt as DT_REPORT,
			case when vdkdm.material_group_for_reporting_name = 'Аноды зеленые' then 'KPI_AF_PROD_VOLA_ZA'
				 when vdkdm.material_group_for_reporting_name = 'Анодные блоки' then 'KPI_AF_PROD_VOLA_SP'
			end as ACCOUNT_CODE,
			mkrate.entity_code as ENTITY_CODE,
			sum(bzms.quantity::numeric)
				/((DATE_PART('days',DATE_TRUNC('month',c.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric)
				 as ACTUAL_GOAL --считаю план на 1 день в месяце
		from stg.bip_zbw1689m_srv bzms
		join dict_dds.map_material_sap_to_material_group_hyperion vdkdm on ltrim(bzms.material,'0')=ltrim(vdkdm.material_code,'0')
		join dict_dds.calendar c on c.calendar_year = substring(bzms.fiscper, 1, 4)::numeric and c.calendar_month = substring(bzms.fiscper, 5, 3)::numeric
		join dict_dds.map_kpi_report_account_to_entity mkrate on
			(case when vdkdm.material_group_for_reporting_name = 'Аноды зеленые' then 'KPI_AF_PROD_VOLA_ZA'
				 when vdkdm.material_group_for_reporting_name = 'Анодные блоки' then 'KPI_AF_PROD_VOLA_SP'
			end) = mkrate.account_code and bzms.zsn_make = mkrate.source_entity_code

		where vdkdm.material_group_for_reporting_name in ('Анодные блоки','Аноды зеленые')
			and c.dt >= date_trunc('YEAR',TIMESTAMP 'now') - '1 MONTH'::interval and c.dt< date_trunc('MONTH',TIMESTAMP 'now') + '1 month'::interval
			and mkrate.entity_code not in ('BU_AL_AD','BU_ALUM')
		group by
			c.dt,
			mkrate.entity_code,
			vdkdm.material_group_for_reporting_name
	)


	select
		coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
		coalesce(ms.ENTITY_CODE, mag.ENTITY_CODE) ENTITY_CODE,
		coalesce(ms.ACCOUNT_CODE, mag.ACCOUNT_CODE) ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL,
		ms.MONTH_PLAN
	from mas_actual ms
	full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT and ms.ACCOUNT_CODE = mag.ACCOUNT_CODE

	UNION all

	select
		coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		coalesce(ms.ACCOUNT_CODE, mag.ACCOUNT_CODE) ACCOUNT_CODE,
		sum(ms.ACTUAL),
		sum(mag.ACTUAL_GOAL),
		sum(ms.MONTH_PLAN)
	from mas_actual ms
	full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT and ms.ACCOUNT_CODE = mag.ACCOUNT_CODE
	where coalesce(ms.ENTITY_CODE, mag.ENTITY_CODE) != 'BU_AL_BOAZ'
	group by
	coalesce(ms.DT_REPORT,mag.DT_REPORT),
	coalesce(ms.ACCOUNT_CODE, mag.ACCOUNT_CODE)

	UNION all

	select
		coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		coalesce(ms.ACCOUNT_CODE, mag.ACCOUNT_CODE) ACCOUNT_CODE,
		sum(ms.ACTUAL),
		sum(mag.ACTUAL_GOAL),
		sum(ms.MONTH_PLAN)
	from mas_actual ms
	full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT and ms.ACCOUNT_CODE = mag.ACCOUNT_CODE
	group by
	coalesce(ms.DT_REPORT,mag.DT_REPORT),
	coalesce(ms.ACCOUNT_CODE, mag.ACCOUNT_CODE)
	)t1;

--KPI_PERSONNEL_ATTENDANCE
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
		where
		kiar.dt_report >= date_trunc('YEAR', TIMESTAMP 'now')
		and kiar.account_code = 'KPI_PERSONNEL_ATTENDANCE';

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)

select
		t1."DT_REPORT",
		t1."ENTITY_CODE",
		t1."ACCOUNT_CODE",
		t1."ACTUAL",
		t1."ACTUAL_GOAL"
from
	(
		with max_rec as (
		select
				pa.dt_report,
				pa.plant_code,
				max(record_id) record_id
		from stg.sapxi_1c_personnel_attendance pa
		group by
				pa.dt_report,
				pa.plant_code),

		group_personnel_attendance as (
		select
			dt_report,
			plant_code,
			plant_name,
			record_id,
			sum(actual::numeric) as actual,
			sum(active_goal::numeric) as active_goal
		from stg.sapxi_1c_personnel_attendance
		group by
			dt_report,
			plant_code,
			plant_name,
			record_id
		),

		t_main as (
		select
				pa.dt_report::date as "DT_REPORT",
				mkrate.entity_code as "ENTITY_CODE",
				mkrate.account_code as "ACCOUNT_CODE",
				pa.actual as "ACTUAL",
				pa.active_goal as "ACTUAL_GOAL"
		from group_personnel_attendance pa
		join dict_dds.map_kpi_report_account_to_entity mkrate on pa.plant_code=mkrate.source_entity_code and mkrate.account_code='KPI_PERSONNEL_ATTENDANCE'
		join max_rec on pa.dt_report = max_rec.dt_report and pa.plant_code = max_rec.plant_code and pa.record_id = max_rec.record_id
		where pa.dt_report::date >= date_trunc('YEAR', TIMESTAMP 'now')
		)

		select
			tm."DT_REPORT",
			tm."ENTITY_CODE",
			tm."ACCOUNT_CODE",
			tm."ACTUAL",
			tm."ACTUAL_GOAL"
		from
			t_main tm
		union all

		select
			tm."DT_REPORT" ,
			'BU_ALUM' "ENTITY_CODE",
			tm."ACCOUNT_CODE",
			sum(tm."ACTUAL") "ACTUAL",
			sum(tm."ACTUAL_GOAL") "ACTUAL_GOAL"
		from
			t_main tm
		group by
			tm."DT_REPORT",
			tm."ACCOUNT_CODE"
	) t1;

--Начало KPI_TRM_06,KPI_TRM_05, KPI_TRM_05_B_2, KPI_TRM_05_B_3,KPI_TRM_05_C, KPI_TRM_05_UNDEFINED, KPI_TRM_FIRE_A, KPI_TRM_FIRE_B, KPI_TRM_FIRE_C
	/*
			   Метрика по несчастным случаям.
			   KPI_TRM_05 - Исторический аккаунт. НС по заводам.
			   KPI_TRM_05_B_2 - НС легкая травма по заводам.
			   KPI_TRM_05_B_3 - НС тяжелая травма по заводам.
			   KPI_TRM_05_С - НС микротравма по заводам.
			   KPI_TRM_06 - НС со смертельным исходом по заводам.
			   KPI_TRM_FIRE_A - Количество пожаров по заводам категории A, шт.
			   KPI_TRM_FIRE_B - Количество пожаров по заводам категории B, шт.
			   KPI_TRM_FIRE_C - Количество пожаров по заводам категории C, шт.
			   Данные загружаются из системы Alarm.

	*/
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
		where
		kiar.dt_report >= date_trunc('YEAR', TIMESTAMP 'now')
	and kiar.account_code in ('KPI_TRM_06','KPI_TRM_05','KPI_TRM_05_B_2','KPI_TRM_05_B_3','KPI_TRM_05_C', 'KPI_TRM_05_UNDEFINED', 'KPI_TRM_FIRE_A', 'KPI_TRM_FIRE_B', 'KPI_TRM_FIRE_C');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		null ACTUAL_GOAL,
		null ACTIVE_PLAN,
		null KORR_PLAN

	from (

--Вычисляем максимальный record_identifier_code для каждого accident_code
with max_rec as(
			select
				accident_code,
        		max(record_identifier_code) max_record_identifier
				from dds.accidents
				where
				to_date(dt_accident_local_time, 'DD.MM.YYYY') >= date_trunc('YEAR', TIMESTAMP 'now')
        		and division_name = 'Алюминиевый дивизион'
        		and is_deleted <> '1'
				group by accident_code
),

my_mas_actual as (
			select
				w.dt_report,
				w.entity_code,
				w.account_code,
				w.actual
			from(
--Количество НС
					select
						to_date(alarm.dt_accident_local_time, 'DD.MM.YYYY') as dt_report,
						alarm.plant_code as entity_code,
						alarm.accident_code,
						alarm.record_identifier_code,
						case when alarm.accident_severity_level_code = '1' and alarm.deadly_accident_count >= '1' then 'KPI_TRM_06'
							 when alarm.accident_severity_level_code = '2' and alarm.injure_severity_level_code = '2' then 'KPI_TRM_05_B_2'
							 when alarm.accident_severity_level_code = '2' and alarm.injure_severity_level_code = '3' then 'KPI_TRM_05_B_3'
							 when alarm.accident_severity_level_code = '3' then 'KPI_TRM_05_C'end as account_code,
						case when alarm.deadly_accident_count >= '1' then alarm.deadly_accident_count::numeric else alarm.injured_accident_count::numeric end as actual,
						alarm.accident_full_comment
						from dds.accidents as alarm
					join max_rec on max_rec.accident_code = alarm.accident_code and max_rec.max_record_identifier = alarm.record_identifier_code
						where alarm.accident_type_code='4'

--Кол-во пострадавших, если "accident_severity_level_code" = 'A' and alarm."injured_accident_count"::numeric > '1'
					union all

					select
						to_date(alarm.dt_accident_local_time, 'DD.MM.YYYY') as dt_report,
						alarm.plant_code as entity_code,
						alarm.accident_code,
						alarm.record_identifier_code,
						case when alarm.accident_severity_level_code = '1' and alarm.injured_accident_count::numeric >= '1' then 'KPI_TRM_05_UNDEFINED' end as account_code,
						case when alarm.accident_severity_level_code = '1' and alarm.injured_accident_count::numeric >= '1' then alarm.injured_accident_count::numeric end as actual,
						alarm.accident_full_comment
						from dds.accidents as alarm
					join max_rec on max_rec.accident_code = alarm.accident_code and max_rec.max_record_identifier = alarm.record_identifier_code
						where alarm.accident_type_code='4'

			) w where w.account_code is not null
--Кол-во пожаров
			   union all

			select
					alf.dt_report,
					alf.entity_code,
					alf.account_code,
					count(alf.accident_code)::numeric as actual
			from(
						 select
							to_date(alarm.dt_accident_local_time, 'DD.MM.YYYY') as dt_report,
							alarm.plant_code as entity_code,
							case when alarm.accident_severity_level_code = '1' then 'KPI_TRM_FIRE_A'
								 when alarm.accident_severity_level_code = '2' then 'KPI_TRM_FIRE_B'
								 when alarm.accident_severity_level_code = '3' then 'KPI_TRM_FIRE_C' end as account_code,
							alarm.accident_code,
							alarm.accident_full_comment,
							DENSE_RANK() over (partition by alarm.accident_code order by alarm.record_identifier_code desc) as dr--для одного инцидента может быть несколько записей, нужно брать последнюю
							from dds.accidents as alarm
							where
							to_date(alarm.dt_accident_local_time, 'DD.MM.YYYY')  >= date_trunc('YEAR', TIMESTAMP 'now')
							and alarm.division_name='Алюминиевый дивизион'
							and alarm.accident_type_code='2'
							and alarm.is_deleted<>'1'
							) alf where alf.dr = 1 and  alf.account_code is not null
			group by alf.dt_report, alf.entity_code, alf.account_code

		),
		t_main as
		(
		select
			mma.dt_report as dt_report,
			map.entity_code,
			mma.account_code as account_code,
			mma.actual
		from my_mas_actual mma
		join dict_dds.map_kpi_report_account_to_entity map on mma.entity_code = map.source_entity_code and mma.account_code = map.account_code
		)

		select tm.dt_report,
				tm.entity_code,
				tm.account_code,
				tm.actual
		from t_main tm

		union all

		select tm.dt_report,
				'BU_AL_AD' as entity_code,
				tm.account_code,
				sum(tm.actual) actual
		from t_main tm
		where tm.entity_code not in ('BU_AL_BOAZ', 'BU_AL_RF_SA')
		group by tm.dt_report,tm.account_code
		) t1;
	--Конец KPI_TRM_06,KPI_TRM_05, KPI_TRM_05_B_2, KPI_TRM_05_B_3,KPI_TRM_05_C, KPI_TRM_05_UNDEFINED, KPI_TRM_FIRE_A, KPI_TRM_FIRE_B, KPI_TRM_FIRE_C

	--SET_KEY_RATE, SET_INFLATION
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
		where kiar.account_code in ('SET_KEY_RATE', 'SET_INFLATION');


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with mas_entity as (
		select
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate
		),
		mas_actual as (
			--SET_KEY_RATE
			/*
			   Данные по ключевой ставке, тянутся с сайта ЦБР роботом
			*/
			--Начало
				select
				dt::date DT_REPORT,
				'BU_NA' ENTITY_CODE,
				'SET_KEY_RATE' ACCOUNT_CODE,
				NULL "ZIRPRODCT",
				key_rate::numeric ACTUAL,
				null ACTUAL_GOAL,
				null ACTIVE_PLAN,
				null KORR_PLAN
			from
				stg.macro_key_rate_and_inflation_cbr mkraic
			join mas_entity me on LOWER(me.source_entity_code) = LOWER('BU_NA') and me. ACCOUNT_CODE = 'SET_KEY_RATE'
			--Конец

			--SET_INFLATION
			/*
			   Данные по инфляции, тянутся с сайта ЦБР роботом
			*/
			--Начало
			union all
				select
				dt DT_REPORT,
				'BU_NA' ENTITY_CODE,
				'SET_INFLATION' ACCOUNT_CODE,
				NULL "ZIRPRODCT",
				inflation ACTUAL,
				inflation_goal ACTUAL_GOAL,
				null ACTIVE_PLAN,
				null KORR_PLAN
			from
				stg.macro_key_rate_and_inflation_cbr mkraic
			join mas_entity me on LOWER(me.source_entity_code) = LOWER('BU_NA') and me. ACCOUNT_CODE = 'SET_INFLATION'
			--Конец
	)

	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		ms.ACCOUNT_CODE,
		ms.ACTUAL,
		ms."ZIRPRODCT",
		ms.ACTUAL_GOAL,
		ms.ACTIVE_PLAN::numeric,
		ms.KORR_PLAN::numeric
	from mas_actual ms
	) t1;



--SET2 - LME alloy, USD/т, SET_RAI_CH - Chinese alumina FOB, USD/т.
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
		where kiar.account_code in ('SET2','SET_RAI_CH')
		and kiar.dt_report >= DATE_TRUNC('YEAR', now());

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)

select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
	with mas_actual_goal as (select
							c.dt,
							vkgr."ACCOUNT",
							vkgr."ACTIVE_GOAL"
							from stg."V_KPI_GOALS_REPORT" vkgr
							join dict_dds.calendar c on c.calendar_year = EXTRACT(YEAR FROM vkgr."REPORT_DATE") and c.calendar_month = EXTRACT(MONTH from vkgr."REPORT_DATE")
							where
							vkgr."REPORT_DATE">= DATE_TRUNC('YEAR', now())
							and vkgr."ACCOUNT" in ('SET_RAI_CH','SET2')),

	mas_actual as (
				--SET2 - LME alloy, USD/т, SET_RAI_CH - Chinese alumina FOB, USD/т.
				--Начало
				--SET2
				select
				maaivx.dt_lme_aluminium_alloy as DT_REPORT,
				'BU_NA' as ENTITY_CODE,
				'SET2' as ACCOUNT_CODE,
				NULL "ZIRPRODCT",
				maaivx.lme_aluminium_alloy_price_usd_per_tonn as ACTUAL,
				mag."ACTIVE_GOAL" ACTUAL_GOAL,
				null ACTIVE_PLAN,
				null KORR_PLAN
				from stg.macro_aluminium_alumina_indexes_v2_xlsx maaivx
				join dict_dds.map_kpi_report_account_to_entity me on LOWER(me.source_entity_code) = LOWER('BU_NA') and me.ACCOUNT_CODE = 'SET2'
				join mas_actual_goal mag on mag.dt = maaivx.dt_lme_aluminium_alloy and mag."ACCOUNT" = 'SET2'
				where maaivx.dt_lme_aluminium_alloy >= DATE_TRUNC('YEAR', now())


				union all

				--SET_RAI_CH
				select
				maaivx.dt_chinese_alumina as DT_REPORT,
				'BU_NA' as ENTITY_CODE,
				'SET_RAI_CH' as ACCOUNT_CODE,
				NULL "ZIRPRODCT",
				maaivx.chinese_alumina_fob_price_usd_per_tonn as ACTUAL,
				mag."ACTIVE_GOAL" ACTUAL_GOAL,
				null ACTIVE_PLAN,
				null KORR_PLAN
				from stg.macro_aluminium_alumina_indexes_v2_xlsx maaivx
				join dict_dds.map_kpi_report_account_to_entity me on LOWER(me.source_entity_code) = LOWER('BU_NA') and me.ACCOUNT_CODE = 'SET_RAI_CH'
				join mas_actual_goal mag on mag.dt = maaivx.dt_chinese_alumina and mag."ACCOUNT" = 'SET_RAI_CH'
				where maaivx.dt_chinese_alumina >= DATE_TRUNC('YEAR', now())
				--Конец
	)

	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		ms.ACCOUNT_CODE,
		ms.ACTUAL,
		ms."ZIRPRODCT",
		ms.ACTUAL_GOAL::numeric,
		ms.ACTIVE_PLAN::numeric,
		ms.KORR_PLAN::numeric
	from mas_actual ms
	) t1;

--SET_INDEX_RSV_EUROPE,SET_INDEX_RSV_SIBERIA
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
		where kiar.account_code in ('SET_INDEX_RSV_EUROPE','SET_INDEX_RSV_SIBERIA')
		and kiar.dt_report >= DATE_TRUNC('YEAR', now());


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with mas_entity as (
		select
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate
		),
		mas_actual as (
			/*
			   Данные по индексу РСВ, тянутся с сайта АТС энегро
			   SET_INDEX_RSV_EUROPE
			   SET_INDEX_RSV_SIBERIA

			--Начало
			*/

			select
			to_date(rsv.dat,'dd.mm.yyyy') as DT_REPORT,
			'BU_NA' ENTITY_CODE,
			'SET_INDEX_RSV_EUROPE' as ACCOUNT_CODE,
			NULL "ZIRPRODCT",
			rsv.consumer_price::numeric ACTUAL,
			null ACTUAL_GOAL,
			null ACTIVE_PLAN,
			null KORR_PLAN
			from stg.macro_index_rsv_atsenergo rsv
			join mas_entity me on LOWER(me.source_entity_code) = LOWER('BU_NA') and me.ACCOUNT_CODE='SET_INDEX_RSV_EUROPE'
			where rsv.price_zone_code = '1'
			and to_date(rsv.dat,'dd.mm.yyyy')>= DATE_TRUNC('YEAR', now())

			union all

			select
			to_date(rsv.dat,'dd.mm.yyyy') as DT_REPORT,
			'BU_NA' ENTITY_CODE,
			'SET_INDEX_RSV_SIBERIA' as ACCOUNT_CODE,
			NULL "ZIRPRODCT",
			rsv.consumer_price::numeric ACTUAL,
			null ACTUAL_GOAL,
			null ACTIVE_PLAN,
			null KORR_PLAN
			from stg.macro_index_rsv_atsenergo rsv
			join mas_entity me on LOWER(me.source_entity_code) = LOWER('BU_NA') and me.ACCOUNT_CODE='SET_INDEX_RSV_SIBERIA'
			where rsv.price_zone_code = '2'
			and to_date(rsv.dat,'dd.mm.yyyy')>= DATE_TRUNC('YEAR', now())

			--Конец
	)

	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		ms.ACCOUNT_CODE,
		ms.ACTUAL,
		ms."ZIRPRODCT",
		ms.ACTUAL_GOAL::numeric,
		ms.ACTIVE_PLAN::numeric,
		ms.KORR_PLAN::numeric
	from mas_actual ms
	) t1;

	--TEP_PRD_ALM_REMELT_ALUM Выпуск вторичного алюминия, т.
	--Account в stg."V_KPI_FG_AL_HYP" = TEP_FG_AL_PRD_ALM_REMELT_ALUM
	--Product в stg."V_KPI_FG_AL_HYP" = PRD_ALM_REMELT_ALUM
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now())
		and kiar.account_code = 'TEP_PRD_ALM_REMELT_ALUM';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan,
	korr_plan
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL,
		null as ACTIVE_PLAN,
		t1.KORR_PLAN
	from (
with mas_actual as (
	select
	vmlpm."DATEREPORT" as DT_REPORT,
	map.entity_code as ENTITY_CODE,
	vmlpm."AMOUNT_LO"/1000 as ACTUAL
	from stg."V_MES_LP_PRODUCTION_MELT" vmlpm
	join dict_dds.map_kpi_report_account_to_entity map on vmlpm."SMELTER" = map.source_entity_code and map.account_code = 'TEP_PRD_ALM_REMELT_ALUM'
	where 1=1
	and vmlpm."DATEREPORT">= DATE_TRUNC('YEAR', now())
	),

	mas_actual_goal as (
		select
		hyp."DAYNAME" as DT_REPORT,
		map.entity_code as ENTITY_CODE,
		hyp."GOALS1" as ACTUAL_GOAL, --Цель
		hyp."KORRACT" as KORR_PLAN --ТП 1(2)
		from stg."V_KPI_FG_AL_HYP" hyp
		join dict_dds.map_kpi_report_account_to_entity map on hyp."ENTITY" = map.entity_code and map.account_code = 'TEP_PRD_ALM_REMELT_ALUM'
		where 1=1
		and hyp."ACCOUNT" = 'TEP_FG_AL_PRD_ALM_REMELT_ALUM'
	    and hyp."ENTITY" not in ('BU_ALUM', 'BU_AL_AD')
		and hyp."DAYNAME">= DATE_TRUNC('YEAR', now())
	)

select
coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
coalesce(ms.ENTITY_CODE, mag.ENTITY_CODE) ENTITY_CODE,
'TEP_PRD_ALM_REMELT_ALUM' ACCOUNT_CODE,
ms.ACTUAL,
mag.ACTUAL_GOAL::numeric,
mag.KORR_PLAN::numeric
from mas_actual ms
full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT

union all

select
coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
'BU_AL_AD' ENTITY_CODE,
'TEP_PRD_ALM_REMELT_ALUM' ACCOUNT_CODE,
sum(ms.ACTUAL),
sum(mag.ACTUAL_GOAL::numeric) as ACTUAL_GOAL,
sum(mag.KORR_PLAN::numeric) as KORR_PLAN
from mas_actual ms
full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT
	where coalesce(ms.ENTITY_CODE,mag.ENTITY_CODE) not in ('BU_AL_BOAZ')
GROUP BY  coalesce(ms.DT_REPORT,mag.DT_REPORT)
	) t1;
	--Конец


	--TEP_PRD_ALM_REMELT_SLAG Переплав концентрата и шлака, т.
	--Account в stg."V_KPI_FG_AL_HYP" = TEP_FG_AL_PRD_ALM_REMELT_SLAG
	--Product в stg."V_KPI_FG_AL_HYP" = PRD_ALM_REMELT_SLAG
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now())
		and kiar.account_code = 'TEP_PRD_ALM_REMELT_SLAG';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan,
	korr_plan
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL,
		null as ACTIVE_PLAN,
		t1.KORR_PLAN
	from (
with mas_actual as (
	select
	vmlpm."DATE_TRUNC" as DT_REPORT,
	map.entity_code as ENTITY_CODE,
	vmlpm."AMOUNT"/1000 as ACTUAL
	from stg."V_MES_LP_WASTE_MOVEMENT" vmlpm
	join dict_dds.map_kpi_report_account_to_entity map on vmlpm."SMELTER" = map.source_entity_code and map.account_code = 'TEP_PRD_ALM_REMELT_SLAG'
	where 1=1
	and vmlpm."DATE_TRUNC">= DATE_TRUNC('YEAR', now())
	),

	mas_actual_goal as (
		select
		hyp."DAYNAME" as DT_REPORT,
		map.entity_code as ENTITY_CODE,
		hyp."GOALS1" as ACTUAL_GOAL, --Цель
		hyp."KORRACT" as KORR_PLAN --ТП 1(2)
		from stg."V_KPI_FG_AL_HYP" hyp
		join dict_dds.map_kpi_report_account_to_entity map on hyp."ENTITY" = map.entity_code and map.account_code = 'TEP_PRD_ALM_REMELT_SLAG'
		where 1=1
		and hyp."ACCOUNT" = 'TEP_FG_AL_PRD_ALM_REMELT_SLAG'
	    and hyp."ENTITY" not in ('BU_ALUM', 'BU_AL_AD')
		and hyp."DAYNAME">= DATE_TRUNC('YEAR', now())
	)

select
coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
coalesce(ms.ENTITY_CODE, mag.ENTITY_CODE) ENTITY_CODE,
'TEP_PRD_ALM_REMELT_SLAG' ACCOUNT_CODE,
ms.ACTUAL,
mag.ACTUAL_GOAL::numeric,
mag.KORR_PLAN::numeric
from mas_actual ms
full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT

union all

select
coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
'BU_AL_AD' ENTITY_CODE,
'TEP_PRD_ALM_REMELT_SLAG' ACCOUNT_CODE,
sum(ms.ACTUAL),
sum(mag.ACTUAL_GOAL::numeric) as ACTUAL_GOAL,
sum(mag.KORR_PLAN::numeric) as KORR_PLAN
from mas_actual ms
full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT
	where coalesce(ms.ENTITY_CODE,mag.ENTITY_CODE) not in ('BU_AL_BOAZ')
GROUP BY  coalesce(ms.DT_REPORT,mag.DT_REPORT)
	) t1;
	--Конец

	--TEP_PRD_ALM_SLAG Обогащение шлака, т.
	--Account в stg."V_KPI_FG_AL_HYP"= TEP_FG_AL_PRD_ALM_SLAG
	--Product в stg."V_KPI_FG_AL_HYP"= PRD_ALM_SLAG
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now())
		and kiar.account_code = 'TEP_PRD_ALM_SLAG';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	active_plan,
	korr_plan
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL,
		null as ACTIVE_PLAN,
		t1.KORR_PLAN
	from (
with mas_actual as (
	select
	vmlpm."DATE_TRUNC" as DT_REPORT,
	map.entity_code as ENTITY_CODE,
	vmlpm."AMOUNT"/1000 as ACTUAL
	from stg."MES_LP_SLAG" vmlpm
	join dict_dds.map_kpi_report_account_to_entity map on vmlpm."SMELTER" = map.source_entity_code and map.account_code = 'TEP_PRD_ALM_SLAG'
	where 1=1
	and vmlpm."DATE_TRUNC">= DATE_TRUNC('YEAR', now())
	),

	mas_actual_goal as (
		select
		hyp."DAYNAME" as DT_REPORT,
		map.entity_code as ENTITY_CODE,
		hyp."GOALS1" as ACTUAL_GOAL, --Цель
		hyp."KORRACT" as KORR_PLAN --ТП 1(2)
		from stg."V_KPI_FG_AL_HYP" hyp
		join dict_dds.map_kpi_report_account_to_entity map on hyp."ENTITY" = map.entity_code and map.account_code = 'TEP_PRD_ALM_SLAG'
		where 1=1
		and hyp."ACCOUNT" = 'TEP_FG_AL_PRD_ALM_SLAG'
		and hyp."ENTITY" not in ('BU_ALUM', 'BU_AL_AD')
		and hyp."DAYNAME">= DATE_TRUNC('YEAR', now())
	)

select
coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
coalesce(ms.ENTITY_CODE, mag.ENTITY_CODE) ENTITY_CODE,
'TEP_PRD_ALM_SLAG' ACCOUNT_CODE,
ms.ACTUAL,
mag.ACTUAL_GOAL::numeric,
mag.KORR_PLAN::numeric
from mas_actual ms
full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT
union all
select
coalesce(ms.DT_REPORT,mag.DT_REPORT) DT_REPORT,
'BU_AL_AD' ENTITY_CODE,
'TEP_PRD_ALM_SLAG' ACCOUNT_CODE,
sum(ms.ACTUAL),
sum(mag.ACTUAL_GOAL::numeric) as ACTUAL_GOAL,
sum(mag.KORR_PLAN::numeric) as KORR_PLAN
from mas_actual ms
full join mas_actual_goal mag on mag.ENTITY_CODE = ms.ENTITY_CODE and ms.DT_REPORT = mag.DT_REPORT
	where coalesce(ms.ENTITY_CODE,mag.ENTITY_CODE) not in ('BU_AL_BOAZ')
GROUP BY  coalesce(ms.DT_REPORT,mag.DT_REPORT)
	) t1;
	--Конец



--KPI_ALUM_TEC_08a
--Удаляем и записываем текущий год - 12 месяцев для расчета прогноза простоев. Они считаются за 365 дней
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
		where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval
	and kiar.account_code in ('KPI_ALUM_TEC_08a');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN,
	forecast_month,
	forecast_year,
	downtime_duration_in_minutes_forecast_quantity,
	downtime_duration_in_minutes_forecast_ytd_quantity,
	month_goal,
	year_goal
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN,
		t1.forecast_month,
		t1.forecast_year,
		t1.downtime_duration_in_minutes_forecast_quantity,
		t1.downtime_duration_in_minutes_forecast_ytd_quantity,
		t1.month_goal,
		t1.year_goal

	from (
		with mas_entity as (
		select distinct
		c.dt,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c -- select distinct entity_code from dict_dds.map_kpi_report_account_to_entity where entity_code = 'BU_AL_KUBAL'
		where c.dt >= DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '13 MONTH'::interval
		and mkrate.account_code in ('KPI_ALUM_TEC_08a')
		)
		, mas_actual as (
		--KPI_ALUM_TEC_08a
			--Начало
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				NULL "ZIRPRODCT",
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
					where "NAME1" not in ('BU_AL_KUBAL') -- на источнике нет этого показателя, но если появится, что бы не размножило данные убираем (САЗ, УАЗ, ТаАЗ)

					union all
						-- Отдельный расчет для Кубал без группы Fordon
					select
						'BU_AL_KUBAL' as "NAME1"
							,(case when date_trunc('month',now()) <= t1.oktid::date or (date_part('DAY',now()) = 1 and date_trunc('month',now()) - '1 MONTH'::interval <= t1.oktid::date) then  (t1.oktid::date + INTERVAL '1 day') else t1.oktid::date end)::date AS "PLAN_DATE"
						,round(cast(abs((EXTRACT(EPOCH FROM cast(t1.oktid as timestamp) - cast(t1.feltid as timestamp))/60)) as numeric),2) AS "DATEDIFF_FOR_DATE"
					from stg.sapxi_raw_cubal_downtime t1
					left join
						(
							select * from  stg.sapxi_raw_cubal_downtimeklass where utrgrupp not like ('Fordon')
						) t2
						on t1.plats = t2.plats
						and t1.utrgrupp = t2.utrgrupp
					where 1 = 1
					and t1.utrgrupp not like ('%Fordon%')
					and cast(t1.feltid as date) >= (DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval)::date
					and t2.klass = 'A'
					and t1.feltyp not in ('Väntar före', 'Väntar efter', 'Resursbrist')

					union all
					-- -- Отдельный расчет для Кубал для группы Fordon
					select
						'BU_AL_KUBAL' as "NAME1"
						,(case when date_trunc('month',now()) <= t1.oktid::date or (date_part('DAY',now()) = 1 and date_trunc('month',now()) - '1 MONTH'::interval <= t1.oktid::date) then  (t1.oktid::date + INTERVAL '1 day') else t1.oktid::date end)::date AS "PLAN_DATE"
						,round(cast(abs((EXTRACT(EPOCH FROM cast(t1.oktid as timestamp) - cast(t1.feltid as timestamp))/60)) as numeric),2) AS "DATEDIFF_FOR_DATE"
					from stg.sapxi_raw_cubal_downtime t1
					left join
						(
							select
								case when utrgrupp like ('%Fordon%') then 'Fordon' else utrgrupp end utrgrupp2
								,* from  stg.sapxi_raw_cubal_downtimeklass where utrgrupp like ('%Fordon%')
						) t2
						on t1.plats = t2.plats
						and case when t1.utrgrupp like ('%Fordon%') then 'Fordon' else t1.utrgrupp end = t2.utrgrupp2
						and t1.utrustning = t2.utrustning
					where 1 = 1
					and t1.utrgrupp like ('%Fordon%')
					and cast(t1.feltid as date) >= (DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval)::date
					and t2.klass = 'A'
					and t1.feltyp not in ('Väntar före', 'Väntar efter', 'Resursbrist')

					union all
					-- Отдельный расчет для BU_AL_RF
					select 'BU_AL_RF' as ENTITY,
						to_date(to_char(mepd."timestamp"::timestamp +giz.utc_offset_code,'dd.mm.yyyy'),'dd.mm.yyyy') DT_REPORT,
						case when giz.guid_name like '%Факт%' then cast(mepd.value as numeric) else 0 end as ACTUAL
						from stg.auxiliary_production_anode_zyfra mepd
						join dict_dds.global_identifier_zyfra giz on giz.guid_code = mepd.id
						where 1=1
						and giz.guid_name = 'RF. Внеплановый простой оборудования - Факт - за сутки'
						and mepd."timestamp"::timestamp +giz.utc_offset_code >= (DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval)::date --'2024-01-01' -- 00:00:00.000
				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_08a'
				and me.dt = vtud."PLAN_DATE"
			left join
				(
					select
						"REPORT_DATE", "ENTITY", "ENTITY_NAME", "DIVISION", "ACCOUNT", "ACCOUNT_NAME", "MEASURE", "DETAIL", "VERSION", "PRODUCT", "COUNTERPARTY","DIFFERENCE_TYPE", "ACTUAL", "MONTH_PLAN" , "ACTIVE_GOAL", "DIFFERENCE" , "DIFFERENCE_PERCENTAGE", "DIFFERENCE_MONTH_PLAN",
						"EXECUTION_PERCENTAGE", "EXECUTION_PERCENTAGE_TRUNC", "ACTUAL_YTD" , "MONTH_PLAN_YTD", "ACTIVE_GOAL_YTD", "DIFFERENCE_YTD", "DIFFERENCE_PERCENTAGE_YTD",
						"DIFFERENCE_MONTH_PLAN_YTD","EXECUTION_PERCENTAGE_YTD", "EXECUTION_PERCENTAGE_YTD_TRUNC", "DIFFERENCE_TYPE_MTD", "DIFFERENCE_TYPE_YTD",
						"DIFFERENCE_TYPE_MONTH_PLAN_MTD", "DIFFERENCE_TYPE_MONTH_PLAN_YTD", "RN", "DTTM_INSERTED", "DTTM_UPDATED", "JOB_NAME", "DELETED_FLAG", "IS_ACTUAL"
					from stg."V_KPI_GOALS_REPORT"
					where "ENTITY" not in ('BU_AL_AD', 'BU_AL_RF', 'BU_AL_RF_TOTAL')
					and "ACCOUNT" = 'KPI_ALUM_TEC_08a'
					and "DIVISION" = 'АД'
					union
					select "REPORT_DATE"
					, case when "ENTITY" = 'BU_AL_RF_TOTAL' then 'BU_AL_RF' end as "ENTITY"
					, "ENTITY_NAME", "DIVISION"
					, case when "ACCOUNT" = 'KPI_AL_RF_PRD_02' then 'KPI_ALUM_TEC_08a' end as  "ACCOUNT"
					, "ACCOUNT_NAME", "MEASURE", "DETAIL", "VERSION", "PRODUCT", "COUNTERPARTY","DIFFERENCE_TYPE", "ACTUAL", "MONTH_PLAN" , "ACTIVE_GOAL", "DIFFERENCE" , "DIFFERENCE_PERCENTAGE", "DIFFERENCE_MONTH_PLAN",
						"EXECUTION_PERCENTAGE", "EXECUTION_PERCENTAGE_TRUNC", "ACTUAL_YTD" , "MONTH_PLAN_YTD", "ACTIVE_GOAL_YTD", "DIFFERENCE_YTD", "DIFFERENCE_PERCENTAGE_YTD",
						"DIFFERENCE_MONTH_PLAN_YTD","EXECUTION_PERCENTAGE_YTD", "EXECUTION_PERCENTAGE_YTD_TRUNC", "DIFFERENCE_TYPE_MTD", "DIFFERENCE_TYPE_YTD",
						"DIFFERENCE_TYPE_MONTH_PLAN_MTD", "DIFFERENCE_TYPE_MONTH_PLAN_YTD", "RN", "DTTM_INSERTED", "DTTM_UPDATED", "JOB_NAME", "DELETED_FLAG", "IS_ACTUAL"
					from stg."V_KPI_GOALS_REPORT"
					where "ENTITY" in ('BU_AL_RF_TOTAL')
					and "ACCOUNT" = 'KPI_AL_RF_PRD_02'
					and "DIVISION" = 'АД'
				) vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE") -- select  DATE_TRUNC('month', now())
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			where me.source_entity_code != 'BU_AL_AD'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"

			union all

			select
				me.dt DT_REPORT,
				'BU_AL_AD' ENTITY_CODE,
				me.ACCOUNT_CODE,
				NULL "ZIRPRODCT",
				coalesce(round(sum("DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
				vkgr.ACTUAL_GOAL,
				vkgr.ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
					where "NAME1" not in ('BU_AL_KUBAL', 'BU_AL_RF') -- на источнике нет этого показателя, но если появится, что бы не размножило данные убираем

					union all
					-- Отдельный расчет для Кубал без группы Fordon
					select
						'BU_AL_KUBAL' as "NAME1"
						,(case when date_trunc('month',now()) <= t1.oktid::date or (date_part('DAY',now()) = 1 and date_trunc('month',now()) - '1 MONTH'::interval <= t1.oktid::date) then  (t1.oktid::date + INTERVAL '1 day') else t1.oktid::date end)::date AS "PLAN_DATE"
						,round(cast(abs((EXTRACT(EPOCH FROM cast(t1.oktid as timestamp) - cast(t1.feltid as timestamp))/60)) as numeric),2) AS "DATEDIFF_FOR_DATE"
					from stg.sapxi_raw_cubal_downtime t1
					left join
						(
							select * from  stg.sapxi_raw_cubal_downtimeklass where utrgrupp not like ('Fordon')
						) t2
						on t1.plats = t2.plats
						and t1.utrgrupp = t2.utrgrupp
					where 1 = 1
					and t1.utrgrupp not like ('%Fordon%')
--					and date_part('year', cast(t1.feltid as date)) >= 2024 -- На витрине данные должны быть с начала 24г.
					and cast(t1.feltid as date) >= (DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval)::date
					and t2.klass = 'A'
					and t1.feltyp not in ('Väntar före', 'Väntar efter', 'Resursbrist')

					union all
					-- -- Отдельный расчет для Кубал для группы Fordon
					select
						'BU_AL_KUBAL' as "NAME1"
						,(case when date_trunc('month',now()) <= t1.oktid::date or (date_part('DAY',now()) = 1 and date_trunc('month',now()) - '1 MONTH'::interval <= t1.oktid::date) then  (t1.oktid::date + INTERVAL '1 day') else t1.oktid::date end)::date AS "PLAN_DATE"
						,round(cast(abs((EXTRACT(EPOCH FROM cast(t1.oktid as timestamp) - cast(t1.feltid as timestamp))/60)) as numeric),2) AS "DATEDIFF_FOR_DATE"
					from stg.sapxi_raw_cubal_downtime t1
					left join
						(
							select
								case when utrgrupp like ('%Fordon%') then 'Fordon' else utrgrupp end utrgrupp2
								,* from  stg.sapxi_raw_cubal_downtimeklass where utrgrupp like ('%Fordon%')
						) t2
						on t1.plats = t2.plats
						and case when t1.utrgrupp like ('%Fordon%') then 'Fordon' else t1.utrgrupp end = t2.utrgrupp2
						and t1.utrustning = t2.utrustning
					where 1 = 1
					and t1.utrgrupp like ('%Fordon%')
					and cast(t1.feltid as date) >= (DATE_TRUNC('YEAR', now()) - '12 MONTH'::interval)::date
					and t2.klass = 'A'
					and t1.feltyp not in ('Väntar före', 'Väntar efter', 'Resursbrist')

				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_08a'
				and me.dt = vtud."PLAN_DATE"
			join (
					select
						me.dt DT_REPORT,
						me.ACCOUNT_CODE,
						coalesce( round(sum((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric)),5),0) ACTUAL_GOAL,
			    		coalesce(round(sum((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric)),5),0) ACTIVE_PLAN
			    	from mas_entity me
					left join stg."V_KPI_GOALS_REPORT" vkgr
						on vkgr."ACCOUNT" = me. ACCOUNT_CODE
						and DATE_TRUNC('month',me.dt) = DATE_TRUNC('month',vkgr."REPORT_DATE")
						and me.entity_code = vkgr."ENTITY"
						and vkgr."ENTITY"not in ('BU_AL_AD','BU_AL_BOAZ', 'BU_AL_RF')
					group by me.dt,  me.ACCOUNT_CODE
				) vkgr
				on vkgr.ACCOUNT_CODE = me. ACCOUNT_CODE
				and me.dt = vkgr.DT_REPORT
			where me.entity_code not in ('BU_AL_BOAZ', 'BU_AL_RF')
			group by me.dt, me.ACCOUNT_CODE,vkgr.ACTUAL_GOAL,vkgr.ACTIVE_PLAN
			--Конец
	),
    forecast_all as(
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
	SUM(actual) OVER (
            PARTITION BY ENTITY_CODE
            ORDER BY DT_REPORT
            RANGE BETWEEN INTERVAL '29 days' PRECEDING AND CURRENT row) daily_sum,
    SUM(actual) OVER (
            PARTITION BY ENTITY_CODE, DATE_TRUNC('month', ms.DT_REPORT)
            ORDER BY DT_REPORT
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) month_to_date,
     SUM(actual) OVER (
            PARTITION BY ENTITY_CODE
            ORDER BY DT_REPORT
            RANGE BETWEEN INTERVAL '364 days' PRECEDING AND CURRENT row) yearly_sum,
     SUM(actual) OVER (
            PARTITION BY ENTITY_CODE, DATE_TRUNC('year', ms.DT_REPORT)
            ORDER BY DT_REPORT
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) year_to_date,
 vkgr."ACTIVE_GOAL" month_goal,
 YG.year_goal
     from mas_actual ms
			 left join stg."V_KPI_GOALS_REPORT" vkgr on DATE_TRUNC('month',ms.DT_REPORT) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				    							and ms.ENTITY_CODE = 	(case when "ACCOUNT" = 'KPI_AL_RF_PRD_02' and vkgr."ENTITY" = 'BU_AL_RF_TOTAL'  then 'BU_AL_RF' else vkgr."ENTITY" end) and ms.ENTITY_CODE <> ('BU_AL_AD')
				    							and vkgr."ACCOUNT" in ('KPI_ALUM_TEC_08a', 'KPI_AL_RF_PRD_02')
			left join
				    (
				    select DISTINCT ON (	(case when "ACCOUNT" = 'KPI_AL_RF_PRD_02' and vkgr."ENTITY" = 'BU_AL_RF_TOTAL'  then 'BU_AL_RF' else vkgr."ENTITY" end), DATE_TRUNC('year', vkgr."REPORT_DATE"))
				   	(case when "ACCOUNT" = 'KPI_AL_RF_PRD_02' and vkgr."ENTITY" = 'BU_AL_RF_TOTAL'  then 'BU_AL_RF' else vkgr."ENTITY" end),
				    DATE_TRUNC('year',vkgr."REPORT_DATE") year_date,
				    LAST_VALUE(vkgr."ACTIVE_GOAL_YTD") OVER (
				        PARTITION BY 	(case when "ACCOUNT" = 'KPI_AL_RF_PRD_02' and vkgr."ENTITY" = 'BU_AL_RF_TOTAL'  then 'BU_AL_RF' else vkgr."ENTITY" end), DATE_TRUNC('year', vkgr."REPORT_DATE")
				        ORDER BY vkgr."REPORT_DATE"
				        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
				    ) AS year_goal
				    from stg."V_KPI_GOALS_REPORT" vkgr
				    where vkgr."ACCOUNT"  in  ('KPI_ALUM_TEC_08a', 'KPI_AL_RF_PRD_02')
				    ) YG
				    on DATE_TRUNC('year',ms.DT_REPORT) = YG.year_date
				    and ms.ENTITY_CODE = YG."ENTITY"
	where ms.ENTITY_CODE <> ('BU_AL_AD')
 ),

 forecast_ad as (
select
	fi.DT_REPORT,
	'BU_AL_AD' ENTITY_CODE,
	sum(fi.daily_sum) daily_sum,
	sum(fi.month_to_date) month_to_date,
	sum(fi.yearly_sum) yearly_sum,
	sum(fi.year_to_date) year_to_date,
	sum(fi.month_goal) month_goal,
	sum(fi.year_goal) year_goal
from
	forecast_all fi
where fi.ENTITY_CODE not in ('BU_AL_RF', 'BU_AL_BOAZ')
group by fi.DT_REPORT
 )
	select
		ms.DT_REPORT,
		replace(ms.ENTITY_CODE, 'BU_AL_VGAF','BU_DNP_VGAZ') ENTITY_CODE,
		ms.ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		ms."ZIRPRODCT",
		sum(ms.ACTUAL_GOAL) ACTUAL_GOAL,
		sum(ms.ACTIVE_PLAN::numeric) ACTIVE_PLAN,
		sum(ms.KORR_PLAN::numeric) KORR_PLAN,
		sum(coalesce (fct.daily_sum / 30) * date_part('day',DATE_TRUNC('month', fct.DT_REPORT) + INTERVAL '1 month' - fct.DT_REPORT)::int + fct.month_to_date) forecast_month,
		sum(coalesce (fct.yearly_sum / 365) * date_part('day',DATE_TRUNC('year', fct.DT_REPORT) + INTERVAL '1 year' - fct.DT_REPORT)::int + fct.year_to_date) forecast_year,
		case when ms.DT_REPORT < DATE_TRUNC('day', now()) then sum(coalesce (fct.yearly_sum / 365)) else null end downtime_duration_in_minutes_forecast_quantity,
		case when ms.DT_REPORT < DATE_TRUNC('day', now()) then sum(coalesce (fct.yearly_sum)) + sum(coalesce (fct.yearly_sum / 365)) else null end downtime_duration_in_minutes_forecast_ytd_quantity,
		sum(fct.month_goal) month_goal,
		sum(fct.year_goal) year_goal
	from mas_actual ms
	left join forecast_all fct on fct.DT_REPORT = ms.DT_REPORT
							and fct.ENTITY_CODE = ms.ENTITY_CODE
	where ms.ENTITY_CODE != 'BU_AL_AD'
		group by
		ms.DT_REPORT,
		replace(ms.ENTITY_CODE, 'BU_AL_VGAF','BU_DNP_VGAZ'),
		ms.ACCOUNT_CODE,
		ms."ZIRPRODCT"

	union all

	select

		ms.DT_REPORT,
		ms.ENTITY_CODE,
		ms.ACCOUNT_CODE,
		ms.ACTUAL,
		ms."ZIRPRODCT",
		ms.ACTUAL_GOAL,
		ms.ACTIVE_PLAN::numeric,
		ms.KORR_PLAN::numeric,
		(coalesce (fct.daily_sum / 30) * date_part('day',DATE_TRUNC('month', fct.DT_REPORT) + INTERVAL '1 month' - fct.DT_REPORT)::int + fct.month_to_date) forecast_month,
		(coalesce (fct.yearly_sum / 365) * date_part('day',DATE_TRUNC('year', fct.DT_REPORT) + INTERVAL '1 year' - fct.DT_REPORT)::int + fct.year_to_date) forecast_year,
		case when ms.DT_REPORT < DATE_TRUNC('day', now()) then (coalesce (fct.yearly_sum / 365)) else null end downtime_duration_in_minutes_forecast_quantity,
		case when ms.DT_REPORT < DATE_TRUNC('day', now()) then (coalesce (fct.yearly_sum)) + (coalesce (fct.yearly_sum / 365)) else null end downtime_duration_in_minutes_forecast_ytd_quantity,
		fct.month_goal,
		fct.year_goal
	from mas_actual ms
	join forecast_ad fct on fct.DT_REPORT = ms.DT_REPORT
							and fct.ENTITY_CODE = ms.ENTITY_CODE
	) t1;


-- KPI_FINISH_GOODS_ACCEPTED_ON_FIRST_TRY(Продукция сданная с первого предъявления)
delete
from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where kiar.dt_report >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
	and account_code in ('KPI_FINISH_GOODS_ACCEPTED_ON_FIRST_TRY');


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_mtd,
	actual_ytd,
	actual_goal,
	active_goal_mtd,
	active_goal_ytd
	)
select
		t1.dt_report,
		t1.entity_code,
		t1.account_code,
		t1.actual,
		t1.actual_mtd,
		t1.actual_ytd,
		t1.actual_goal,
		t1. active_goal_mtd,
		t1.active_goal_ytd
from
(
	with inteval as (
	select
	timestamp::date as start_date,
	LEAD((timestamp::date - INTERVAL '1 day')::date,1,now()::date) OVER (ORDER BY timestamp::date) as end_date,
	value
	from stg.auxiliary_production_anode_zyfra where id = '126533ac-ea8d-468b-b6bb-e89d32ee3f1f'
	),

	planing as
	(
	select
	inteval.start_date
	,c.dt
	,inteval.value
	from inteval
	join dict_dds.calendar c on c.dt between inteval.start_date and inteval.end_date
	)

	,data_table as (
		select
		date_trunc,
		smelter,
		sum(amount_sgp) amount_sgp,
		sum(obrazovano) obrazovano,
		sum(amount_sgp_fb) amount_sgp_fb,
		sum(summ_all_reject) summ_all_reject,
		sum(fact_techn_wast_all) fact_techn_wast_all
	from stg.sapxi_production_waste_report spwr
	group by
		date_trunc,
		smelter
	--where date_trunc >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
	)

	,fact as
	(
	select
		date_trunc as "DATE_TRUNC",
		smelter as "NAMESHORT",
		round(SUM(amount_sgp_fb) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) /nullif(SUM(amount_sgp) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) ,0)*100,2)::numeric as "FIRST_BR_CT",
		round(SUM(amount_sgp_fb) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(amount_sgp) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100,2)::numeric as "FIRST_BR_CT_MTD",
		round(SUM(amount_sgp_fb) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(amount_sgp) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100,2)::numeric as "FIRST_BR_CT_YTD"
	from data_table
	)

	,fact_ad as
	( -- расчет АД
		select distinct
			date_trunc "DATE_TRUNC"
			,'АД'::text as "NAMESHORT"
			,round(SUM(amount_sgp_fb) OVER (partition by  date_trunc ORDER BY date_trunc asc) /nullif(SUM(amount_sgp) OVER (partition by  date_trunc ORDER BY date_trunc asc) ,0)*100,2)::numeric as "FIRST_BR_CT"
			,round(SUM(amount_sgp_fb) OVER (partition by  date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(amount_sgp) OVER (partition by  date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100,2)::numeric as "FIRST_BR_CT_MTD"
			,round(SUM(amount_sgp_fb) OVER (partition by  date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(amount_sgp) OVER (partition by  date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100,2)::numeric as "FIRST_BR_CT_YTD"
		from data_table
		where smelter not in ('БоАЗ')
	)

	,fact_all as
	(
		select
			"NAMESHORT"
			,"DATE_TRUNC"
			,"FIRST_BR_CT"
			,"FIRST_BR_CT_MTD"
			,"FIRST_BR_CT_YTD"
		from fact
		union all
		select
			"NAMESHORT"
			,"DATE_TRUNC"
			,"FIRST_BR_CT"
			,"FIRST_BR_CT_MTD"
			,"FIRST_BR_CT_YTD"
		from fact_ad
	)
	,mas_entity as
	(
		select distinct
		c.dt,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c
		where c.dt >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		and mkrate.account_code in ('KPI_FINISH_GOODS_ACCEPTED_ON_FIRST_TRY')
	)

	select
		t0.dt as DT_REPORT
		,t0.ENTITY_CODE
		,t0.ACCOUNT_CODE
		,t1."FIRST_BR_CT" as actual
		,t1."FIRST_BR_CT_MTD" as actual_mtd
		,t1."FIRST_BR_CT_YTD" as actual_ytd
		,NULL as "ZIRPRODCT"
		,t2.value::numeric as actual_goal
		,t2.value::numeric as active_goal_mtd
		,t2.value::numeric as active_goal_ytd
		,null::numeric as ACTIVE_PLAN
		,null::numeric as KORR_PLAN
	from mas_entity as t0
	left join fact_all as t1
		on t0.dt = t1."DATE_TRUNC"
		and t0.entity_name = t1."NAMESHORT"
	left join planing  as t2
		on t1."DATE_TRUNC" = t2.dt
	where 1 = 1
	and t1."FIRST_BR_CT" is not null
) t1;

-- KPI_FINISH_GOODS_MANUFACTURING_DEFECTS (Брак при производстве ТП, %)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD"  kiar
	where kiar.account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS')
	and kiar.dt_report >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval;

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_mtd,
	actual_ytd,
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN,
	active_goal_ytd,
	active_goal_mtd
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_MTD,
		t1.ACTUAL_YTD,
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN,
		t1.active_goal_ytd,
		t1.active_goal_mtd
from
(
	with
	calendar_entity as
	(
	select
		c.dt as dt_report,
		mkrate.entity_code,
		mkrate.account_code,
		mkrate.entity_name
			from dict_dds.map_kpi_report_account_to_entity mkrate
			cross join dict_dds.calendar c
				where account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS')
					and entity_code not in ('BU_AL_AD')
					and c.dt >= DATE_TRUNC('YEAR', now())  - '1 YEAR'::interval  - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
	),
	data_table as (
		select
		date_trunc,
		producttypename,
		clearname,
		smelter,
		amount_sgp,
		obrazovano,
		amount_sgp_fb,
		summ_all_reject,
		fact_techn_wast_all,
		row_number() over (partition by date_trunc,producttypename,clearname,smelter order by dttm_inserted desc) as rn
	from stg.sapxi_production_waste_report spwr
	where date_trunc >= DATE_TRUNC('YEAR', now())  - '1 YEAR'::interval  - '1 MONTH'::interval
	),
	data_table_kubal1 as (
	select
		(to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval as "DATE_TRUNC",
		'KUBAL' as "NAMESHORT",
		sum(mepd.castedweight::numeric/1000) castedweight,
		sum(mepd.scrapweight::numeric)/1000 scrapweight
		from stg.sapxi_reject_product_kubal mepd
		where (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  >=  DATE_TRUNC('MONTH', now())
		and coalesce(mepd.rinse,'-') not in ('X')
		group by (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval
	union all select
		(case when date_part('DAY', now()) <> 1 then (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date else (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval end) as "DATE_TRUNC",
		'KUBAL' as "NAMESHORT",
		sum(mepd.castedweight::numeric/1000) castedweight,
		sum(mepd.scrapweight::numeric)/1000 scrapweight
		from stg.sapxi_reject_product_kubal mepd
		where( (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  >=  DATE_TRUNC('YEAR', now())  - '1 YEAR'::interval  - '1 MONTH'::interval
		and (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  <  DATE_TRUNC('MONTH', now()))
		and coalesce(mepd.rinse,'-') not in ('X')
		group by (case when date_part('DAY', now()) <> 1 then (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date else (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval end)
	),
	fact as (
	select
		mkrate.dt_report as DT_REPORT,
		mkrate.entity_code,
		mkrate.account_code,
		mes."OBRAZOVANO", -- отлито,тн
		mes."REJECT",
		mes."REJECT_CT",
		mes."REJECT_CT_MTD",
		mes."REJECT_CT_YTD"
	from calendar_entity mkrate
	left join (
	select  distinct
		date_trunc as "DATE_TRUNC",
		smelter as "NAMESHORT",
		SUM(obrazovano) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) as "OBRAZOVANO",
		SUM(summ_all_reject) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) as "REJECT",
		(SUM(summ_all_reject) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT",
		(SUM(summ_all_reject) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT_MTD",
		(SUM(summ_all_reject) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT_YTD"
	from data_table
	where rn=1
	union all select  distinct
		"DATE_TRUNC",
		"NAMESHORT",
		SUM(castedweight) OVER (partition by "NAMESHORT", "DATE_TRUNC" ORDER BY "DATE_TRUNC" asc) as "OBRAZOVANO",
		SUM(scrapweight) OVER (partition by "NAMESHORT", "DATE_TRUNC" ORDER BY "DATE_TRUNC" asc) as "REJECT",
		(SUM(scrapweight) OVER (partition by "NAMESHORT", "DATE_TRUNC" ORDER BY "DATE_TRUNC" asc) /nullif(SUM(castedweight) OVER (partition by "NAMESHORT", "DATE_TRUNC" ORDER BY "DATE_TRUNC" asc) ,0)*100)::numeric as "REJECT_CT",
		(SUM(scrapweight) OVER (partition by "NAMESHORT", date_part('month', "DATE_TRUNC"), date_part('year', "DATE_TRUNC") ORDER BY "DATE_TRUNC" asc) /nullif(SUM(castedweight) OVER (partition by "NAMESHORT", date_part('month', "DATE_TRUNC"), date_part('year', "DATE_TRUNC") ORDER BY "DATE_TRUNC" asc) ,0)*100)::numeric as "REJECT_CT_MTD",
		(SUM(scrapweight) OVER (partition by "NAMESHORT", date_part('year', "DATE_TRUNC") ORDER BY "DATE_TRUNC" asc) /nullif(SUM(castedweight) OVER (partition by "NAMESHORT", date_part('year', "DATE_TRUNC") ORDER BY "DATE_TRUNC" asc) ,0)*100)::numeric as "REJECT_CT_YTD"
	from data_table_kubal1
) mes
		on mes."NAMESHORT"=mkrate.entity_name
		and mkrate.dt_report = mes."DATE_TRUNC"
	)
	,
	fact_ad as
	( -- расчет АД
		select distinct
		DT_REPORT,
		'BU_AL_AD'::varchar as entity_code,
		account_code,
		(SUM("REJECT") OVER (partition by account_code, dt_report ORDER BY dt_report asc) /nullif(SUM("OBRAZOVANO") OVER (partition by account_code, dt_report ORDER BY dt_report asc) ,0)*100)::numeric actual,
		(SUM("REJECT") OVER (partition by account_code, date_part('month', dt_report), date_part('year', dt_report) ORDER BY dt_report asc) /nullif(SUM("OBRAZOVANO") OVER (partition by account_code, date_part('month', dt_report), date_part('year', dt_report) ORDER BY dt_report asc) ,0)*100)::numeric actual_mtd,
		(SUM("REJECT") OVER (partition by account_code, date_part('year', dt_report) ORDER BY dt_report asc) /nullif(SUM("OBRAZOVANO") OVER (partition by account_code, date_part('year', dt_report) ORDER BY dt_report asc) ,0)*100)::numeric actual_ytd
		from fact
		where entity_code not in ('BU_AL_BOAZ')
	)
	,
	mas_actual as
	(
		select
			DT_REPORT,
			entity_code,
			account_code,
			"REJECT_CT" as actual,
			"REJECT_CT_MTD" actual_mtd,
			"REJECT_CT_YTD" actual_ytd
		from fact
		union all
		select
			DT_REPORT,
			entity_code,
			account_code,
			actual,
			actual_mtd,
			actual_ytd
		from fact_ad
	)
	,
	--KPID-517
	--KPI_QLT_09_05 - "Справочно: Объём несоответствий за предыдущий год (ввод), тн" Лист ТП
	--KPI_QLT_09_06 - "Справочно: Объём производства за предыдущий год (ввод), тн" Лист ТП
	--KPI_QLT_09 - "Снижение потерь от плохого качества, %" Лист Цель №1
	--%брака = "Справочно: Объём несоответствий за предыдущий год (ввод), тн" / "Справочно: Объём производства за предыдущий год (ввод), тн" * 100* (1 - "Снижение потерь от плохого качества, %"/100)
	mas_actual_goal as (
		select
		(case when QLT."ENTITY" = 'BU_AL_KUBAL' and c.dt >= date_trunc('MONTH',now()) then c.dt + '1 DAY'::interval else c.dt end) as DT_REPORT,
		QLT."ENTITY" as entity_code,    -- select * from stg."V_KPI_GOALS_REPORT" where QLT_05."ACCOUNT" in ('KPI_QLT_09_05')  -- select DATE_TRUNC('YEAR', now())
		QLT."ENTITY_NAME",
		QLT."ACCOUNT" account_code,
		(case when c.dt  < to_date('01.01.2026','dd.mm.yyyy') then QLT.KPI_QLT_09_05/nullif(QLT.KPI_QLT_09_06,0) * 100 * (1-QLT.KPI_QLT_09/100) else KPI_QLT_REJECT_INTERNAL end) as ACTUAL_GOAL
		from
		(select distinct
			"REPORT_DATE",
			"ENTITY" ,
			'KPI_QLT_09_05' "ACCOUNT",
			QLT_05."ENTITY_NAME",
			mkrate.account_code,
			sum("MONTH_PLAN") filter (where "ACCOUNT" in ('KPI_QLT_09_05')) OVER (partition by "REPORT_DATE","ENTITY") KPI_QLT_09_05,
			sum("MONTH_PLAN") filter (where "ACCOUNT" in ('KPI_QLT_09_06')) OVER (partition by "REPORT_DATE","ENTITY") KPI_QLT_09_06,
			sum("ACTIVE_GOAL") filter (where "ACCOUNT" in ('KPI_QLT_09')) OVER (partition by "REPORT_DATE","ENTITY") KPI_QLT_09,
			null::numeric KPI_QLT_REJECT_INTERNAL
		from stg."V_KPI_GOALS_REPORT" QLT_05
		join dict_dds.map_kpi_report_account_to_entity mkrate on QLT_05."ENTITY"=mkrate.entity_code and mkrate.account_code = 'KPI_FINISH_GOODS_MANUFACTURING_DEFECTS'
			where QLT_05."ACCOUNT" in ('KPI_QLT_09_05','KPI_QLT_09_06','KPI_QLT_09')
			and QLT_05."REPORT_DATE" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval and QLT_05."REPORT_DATE"< DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		union all --Новый показатель без формулы с 01.01.2026
		select
			"REPORT_DATE",
			"ENTITY" ,
			"ACCOUNT",
			QLT_05."ENTITY_NAME",
			mkrate.account_code,
			null KPI_QLT_09_05,
			null KPI_QLT_09_06,
			null KPI_QLT_09,
			QLT_05."ACTIVE_GOAL"::numeric KPI_QLT_REJECT_INTERNAL
		from stg."V_KPI_GOALS_REPORT" QLT_05
		join dict_dds.map_kpi_report_account_to_entity mkrate on QLT_05."ENTITY"=mkrate.entity_code and mkrate.account_code = 'KPI_FINISH_GOODS_MANUFACTURING_DEFECTS'
			where QLT_05."ACCOUNT" in ('KPI_QLT_REJECT_INTERNAL')
			and QLT_05."REPORT_DATE" >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval and QLT_05."REPORT_DATE"< DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		) QLT
		join dict_dds.calendar c on c.calendar_year = extract(year from QLT."REPORT_DATE") and c.calendar_month = extract(month from QLT."REPORT_DATE")
)
select
coalesce(ma.DT_REPORT,mag.DT_REPORT) as DT_REPORT,
coalesce(ma.entity_code,mag.entity_code) as entity_code,
coalesce(ma.account_code,mag.account_code) as account_code,
ma.actual,
ma.actual_mtd,
ma.actual_ytd,
mag.ACTUAL_GOAL,
mag.ACTUAL_GOAL as active_goal_ytd,
mag.ACTUAL_GOAL as active_goal_mtd,
null::numeric as ACTIVE_PLAN,
null::numeric as KORR_PLAN
from mas_actual ma
inner join mas_actual_goal mag
	on ma.DT_REPORT=mag.DT_REPORT
	and ma.entity_code=mag.entity_code
where coalesce(ma.DT_REPORT,mag.DT_REPORT) >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
)t1;

----- KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_TN (Брак при производстве ТП, тонн)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where kiar.account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_TN')
	and kiar.dt_report >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval;


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN
from
(
	with data_table as (
		select
		date_trunc,
		producttypename,
		clearname,
		smelter,
		amount_sgp,
		obrazovano,
		amount_sgp_fb,
		summ_all_reject,
		fact_techn_wast_all,
		row_number() over (partition by date_trunc,producttypename,clearname,smelter order by dttm_inserted desc) as rn
	from stg.sapxi_production_waste_report spwr
	where date_trunc >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
	),

	t_main as (
	select
		date_trunc as "DATE_TRUNC",
		smelter as "NAMESHORT",
		sum(obrazovano) as "OBRAZOVANO",
		sum(summ_all_reject) as "REJECT",
		sum(summ_all_reject)/nullif(sum(obrazovano),0)*100 as "REJECT_CT"
	from data_table
	where rn=1
	group by
		date_trunc,
		smelter
	),

	fact as (
	select
		"DATE_TRUNC"
		, "NAMESHORT"
		, "OBRAZOVANO" -- отлито,тн
		,"REJECT"
		,"REJECT_CT"
	from t_main
	union all select
		(to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval as "DATE_TRUNC",
		'KUBAL' as "NAMESHORT",
		round(sum(mepd.castedweight::numeric)/1000,2),
		round(sum(mepd.scrapweight::numeric)/1000,2),
		round(sum(mepd.scrapweight::numeric)/sum(NULLIF(mepd.castedweight::numeric,0))*100, 2)
		from stg.sapxi_reject_product_kubal mepd
		where (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  >=  DATE_TRUNC('MONTH', now())
		and coalesce(mepd.rinse,'-') not in ('X')
		group by (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval
		union all select
		(case when date_part('DAY', now()) <> 1 then (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date else (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval end) as "DATE_TRUNC",
		'KUBAL' as "NAMESHORT",
		round(sum(mepd.castedweight::numeric)/1000,2),
		round(sum(mepd.scrapweight::numeric)/1000,2),
		round(sum(mepd.scrapweight::numeric)/sum(NULLIF(mepd.castedweight::numeric,0))*100, 2)
		from stg.sapxi_reject_product_kubal mepd
		where( (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  >=  DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval
		and  (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date  <  DATE_TRUNC('MONTH', now()))
		and coalesce(mepd.rinse,'-') not in ('X')
		group by (case when date_part('DAY', now()) <> 1 then (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date else (to_timestamp(mepd.caststart, 'yyyy-mm-dd HH24:MI:SS') - '6 HOUR'::interval)::date + '1 DAY'::interval end)
		)
	,fact_ad as
	( -- расчет АД
		select
		'АД' as "NAMESHORT"
		,"DATE_TRUNC"
		,round(sum("REJECT")::numeric, 2) as "REJECT"
		from fact
		where "NAMESHORT" not in ('БоАЗ')
		 group by 1,2
	)
	,fact_all as
	(
		select
			"NAMESHORT"
			,"DATE_TRUNC"
			,"REJECT"
		from fact
		union all
		select
			"NAMESHORT"
			,"DATE_TRUNC"
			,"REJECT"
		from fact_ad
	)
	,mas_entity as
	(
		select distinct
		c.dt,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c
		where c.dt >= DATE_TRUNC('MONTH', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		--where c.dt in (select distinct "DATE_TRUNC" from stg."V_MES_LP_REJECT_PRODUCT")
		and mkrate.account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_TN')
	)
		select
			t0.dt as DT_REPORT
			,t0.ENTITY_CODE
			,t0.ACCOUNT_CODE
			,t1."REJECT" as actual
			,NULL as "ZIRPRODCT"
			,NULL::numeric as ACTUAL_GOAL
			,null::numeric as ACTIVE_PLAN
			,null::numeric as KORR_PLAN
		from mas_entity as t0
		left join fact_all as t1
			on t0.dt = t1."DATE_TRUNC"
			and t0.entity_name = t1."NAMESHORT"
) t1;


----- KPI_DAILY_MAINTENANCE (Выполнение ЕТО, %)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code = 'KPI_DAILY_MAINTENANCE';

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN
from
(
with
fact_0 as
(
	select
		t1."DATE_PLAN"
		,t1."NAME_FACTORY"
		,round(coalesce(sum("COUNT_FACT")/nullif(sum("COUNT_PLAN"),0)*100, 0),0) as FACT
	from stg."V_TORO_ETO_STAT" as t1
	where t1."UCHASTOK" <> 'Отсутствует'
		and t1."TYPE_DIVISION" = 'АД'
		and t1."VID_RABOT" = 'ЕТО'
		and t1."IS_ACTUAL" is true
		and t1."DELETED_FLAG" is false
	group by 1,2
	order by 1,2
)
,fact_ad as
(
	select
		t1."DATE_PLAN"
		,'BU_AL_AD' as "NAME_FACTORY"
		,round(coalesce(sum("COUNT_FACT")/nullif(sum("COUNT_PLAN"),0)*100, 0),0) as FACT
	from stg."V_TORO_ETO_STAT" as t1
	where t1."UCHASTOK" <> 'Отсутствует'
	and t1."TYPE_DIVISION" = 'АД'
	and t1."VID_RABOT" = 'ЕТО'
	and t1."IS_ACTUAL" is true
	and t1."DELETED_FLAG" is false
	and "NAME_FACTORY" <> 'БоАЗ'
	group by 1,2
	order by 1,2
)
, fact_all as
(
	select "DATE_PLAN", "NAME_FACTORY", FACT from fact_0
	union all
	select "DATE_PLAN", "NAME_FACTORY", FACT from fact_ad
)
,mas_entity as
(
	select distinct
	c.dt,
	mkrate.account_code,
	mkrate.entity_code,
	mkrate.entity_name,
	mkrate.source_entity_code,
	mkrate.subsequent_code
	from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c
	where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
	and mkrate.account_code in ('KPI_DAILY_MAINTENANCE')
)
select
	t0.dt as DT_REPORT
	,t0.ENTITY_CODE
	,t0.ACCOUNT_CODE
	,t1.FACT as actual
	,NULL as "ZIRPRODCT"
	,case when t1.FACT is not null then 80::numeric else null::numeric end as ACTUAL_GOAL
	,null::numeric as ACTIVE_PLAN
	,null::numeric as KORR_PLAN
from mas_entity as t0
left join fact_all as t1
	on t0.dt = t1."DATE_PLAN"
	and t0.source_entity_code = t1."NAME_FACTORY"
) t1;


-- KPI_ALUM_TEC_08a_FP (Простои оборудования по литейному производству)

delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_ALUM_TEC_08a_FP');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with dict_type_of_prod2 as
			(
				select
					t1.production_area_code
					,t3.production_area_name as distr
					,t1.plant_code
					,REPLACE(t4.plant_short_name, '*', '') as entity
					,t1.production_activity_type_code
					,t2.production_activity_type_name as direction
				from dict_dds.map_production_area_to_production_activity_type t1
				left join dict_dds.production_activity_type_texts t2
					on t1.production_activity_type_code = t2.production_activity_type_code
				left join dict_dds.production_area_texts t3
					on t1.production_area_code = t3.production_area_code
				left join dict_dds.plant_and_subsidiary t4
					on t1.plant_code = t4.plant_code
				where 1 = 1
				and t1.deleted_flag is false
				and t2.deleted_flag is false
				and t3.deleted_flag is false
				and t4.deleted_flag is false
			)
			, dict_type_of_prod2_alias as
			(
			select
				production_area_code
				,distr
				,REPLACE(plant_code, '6100', '5203') as plant_code
				,REPLACE(entity, 'ИркАЗ', 'ШБРАЗ') as entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2 where entity = 'ИркАЗ'
			)
			,dict_type_of_prod3 as
			(
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2
			union
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2_alias
			)
			,mas_entity_pred as (
		select distinct
			c.dt,
			mkrate.account_code,
			mkrate.entity_code,
			mkrate.entity_name,
			mkrate.source_entity_code,
			mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate
		,dict_dds.calendar c
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		and mkrate.account_code in ('KPI_ALUM_TEC_08a_FP')
		)
		,mas_entity as
		(
			select t1.*, t2.direction, production_area_code--, t2.distr
			from mas_entity_pred t1
			left join (select distinct entity, direction, production_area_code from dict_type_of_prod3) t2
				on t1.source_entity_code = t2.entity
			where direction is not null -- удаляем заводы не вошедшие в выборку справочника из задачи на разделение по направлениям
			and t2.direction = 'Литейное производство' -- KPI_ALUM_TEC_08a_FP
		)
		, mas_actual as (
		--KPI_ALUM_TEC_08a_FP
			--Начало
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				me.direction,
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
						,t1."DIVISION"
						,t1."DIVISION_TXT"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_08a_FP'
				and me.dt = vtud."PLAN_DATE"
				and me.production_area_code = vtud."DIVISION"
			left join stg."V_KPI_GOALS_REPORT" vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE, me.direction, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"
			)
	--- кубал
	,dict_type_of_prod_kubal as
			(
				-- Литейное производство
				select 35 as id, 'GJUTERIET' as Plats, 'Batch Homugnar' as UtrGrupp, null as Utrustning, 'B' as Klass, 'BU_AL_KUBAL' as entity, 'Литейное производство' as direction union all
				select 36, 		 'GJUTERIET',			'Fordon',					'Flaktruck 5325',	 'C', 			'BU_AL_KUBAL', 			'Литейное производство' 				union all
				select 37, 'GJUTERIET',	'Fordon',	'Gaffeltruck 5006',	'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 38, 'GJUTERIET',	'Fordon',	'Gaffeltruck 5034',	'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 39, 'GJUTERIET',	'Fordon',	'Gaffeltruck 5035',	'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 40, 'GJUTERIET',	'Fordon',	'Gaffeltruck 5084',	'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 41, 'GJUTERIET',	'Fordon',	'Lastmaskin 5173',	'C', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 42, 'GJUTERIET',	'Gjutmaskin 1', null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 43, 'GJUTERIET',	'Gjutmaskin 2',	null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 44, 'GJUTERIET',	'Gjutmaskin 3',	null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 45, 'GJUTERIET',	'Hertwich 1',	null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 46, 'GJUTERIET',	'Hertwich 2',	null,			'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 47, 'GJUTERIET',	'Högtravers',	null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 48, 'GJUTERIET',	'Lyftsax',		null,			'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 49, 'GJUTERIET',	'Lågtravers',	null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 50, 'GJUTERIET',	'Profilpress',	null,			'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 51, 'GJUTERIET',	'Sermas',		null,			'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 52, 'GJUTERIET',	'Skimkylare',	null,			'B', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 53, 'GJUTERIET',	'Skimpress',	null,			'A', 'BU_AL_KUBAL', 'Литейное производство' union all
				select 54, 'GJUTERIET',	'Spånpress',	null,			'C', 'BU_AL_KUBAL', 'Литейное производство'

			)
	,mas_entity1 as  -- 'KPI_ALUM_TEC_08a_FP' -- простои литейное производство
		(
			select t1.*
			from mas_entity_pred t1
		)
	, vtud as
		(
					select 	-- не добавил из справочника distr по ним идут дубликаты на дату
						'BU_AL_KUBAL' as "NAME1"
						,(case when date_trunc('month',now()) <= t1.oktid::date or (date_part('DAY',now()) = 1 and date_trunc('month',now()) - '1 MONTH'::interval <= t1.oktid::date) then  (t1.oktid::date + INTERVAL '1 day') else t1.oktid::date end)::date AS "PLAN_DATE"
						,round(cast(abs((EXTRACT(EPOCH FROM cast(t1.oktid as timestamp) - cast(t1.feltid as timestamp))/60)) as numeric),2) AS "DATEDIFF_FOR_DATE"
					from stg.sapxi_raw_cubal_downtime t1
					left join
						(
							select * from  dict_type_of_prod_kubal where utrgrupp not like ('Fordon')
						) t2
						on t1.plats = t2.plats
						and t1.utrgrupp = t2.utrgrupp
					where 1 = 1
					and t1.utrgrupp not like ('%Fordon%')
					and date_part('year', cast(t1.feltid as date)) >= 2024 -- На витрине данные должны быть с начала 24г.
					and t2.klass = 'A'
					and t1.feltyp not in ('Väntar före', 'Väntar efter', 'Resursbrist')

					union all
					 -- Отдельный расчет для Кубал для группы Fordon
					select
						'BU_AL_KUBAL' as "NAME1"
						,(case when date_trunc('month',now()) <= t1.oktid::date or (date_part('DAY',now()) = 1 and date_trunc('month',now()) - '1 MONTH'::interval <= t1.oktid::date) then  (t1.oktid::date + INTERVAL '1 day') else t1.oktid::date end)::date AS "PLAN_DATE"
						,round(cast(abs((EXTRACT(EPOCH FROM cast(t1.oktid as timestamp) - cast(t1.feltid as timestamp))/60)) as numeric),2) AS "DATEDIFF_FOR_DATE"
					from stg.sapxi_raw_cubal_downtime t1
					left join
						(
							select
								case when utrgrupp like ('%Fordon%') then 'Fordon' else utrgrupp end utrgrupp2
								,* from  dict_type_of_prod_kubal where utrgrupp like ('%Fordon%')
						) t2
						on t1.plats = t2.plats
						and case when t1.utrgrupp like ('%Fordon%') then 'Fordon' else t1.utrgrupp end = t2.utrgrupp2
						and t1.utrustning = t2.utrustning
					where 1 = 1
					and t1.utrgrupp like ('%Fordon%')
					and date_part('year', cast(t1.feltid as date)) >= 2024 -- На витрине данные должны быть с начала 24г.
					and t2.klass = 'A'
					and t1.feltyp not in ('Väntar före', 'Väntar efter', 'Resursbrist')
			)
		,mas_actual_kubal as
		(
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN
			from mas_entity1 me
			left join vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_08a_FP'
				and me.dt = vtud."PLAN_DATE"
			left join stg."V_KPI_GOALS_REPORT" vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			where me.entity_code = 'BU_AL_KUBAL'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE
--			, me.direction
			, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"
		)
		,all_entity as
		(
		select
			DT_REPORT,
			ENTITY_CODE,
			ACCOUNT_CODE,
			direction,
			ACTUAL,
			ACTUAL_GOAL,
			ACTIVE_PLAN
		from mas_actual
		union all
		select
			DT_REPORT,
			ENTITY_CODE,
			ACCOUNT_CODE,
			null::text as direction,
			ACTUAL,
			ACTUAL_GOAL,
			ACTIVE_PLAN
		from mas_actual_kubal
		)
		, ad as
		(
		select
			DT_REPORT,
			'BU_AL_AD' ENTITY_CODE,
			ACCOUNT_CODE,
			direction,
			sum(ACTUAL) as ACTUAL,
			sum(ACTUAL_GOAL) as ACTUAL_GOAL,
			sum(ACTIVE_PLAN) as ACTIVE_PLAN
		from all_entity
		where ACCOUNT_CODE not in ('BU_AL_BOAZ')
		group by 1,2,3,4
		)
	select
		ms.DT_REPORT,
		ms.ENTITY_CODE,
		ms.ACCOUNT_CODE,
		ms.ACTUAL,
		null ::numeric as "ZIRPRODCT",
		ms.ACTUAL_GOAL,
		ms.ACTIVE_PLAN::numeric,
		null ::numeric as KORR_PLAN
	from all_entity ms
	union all
	select
		DT_REPORT,
		ENTITY_CODE,
		ACCOUNT_CODE,
		ACTUAL,
		null ::numeric as "ZIRPRODCT",
		ACTUAL_GOAL,
		ACTIVE_PLAN::numeric,
		null ::numeric as KORR_PLAN
	from ad
	) t1;


--KPI_AL_PRD_TOVAL_WH_TOTAL_STOCK - сумма аккаунтов KPI_AL_PRD_TOVAL_WH_STOCK и KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code = 'KPI_AL_PRD_TOVAL_WH_TOTAL_STOCK';

	insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1.ACTUAL_GOAL
	from (
		with mas_actual as (

		select
	dd.dt_report,
	dd.entity_code,
	sum(dd.ACTUAL) ACTUAL
from (
	--скрипт из KPI_AL_PRD_TOVAL_WH_STOCK
		select
		dt_report,
		mkrate.entity_code,
		SUM(coalesce(dd.total_stock_quantity,0)) ACTUAL
	FROM dm.exp_material_stock_balance_mr_ad dd
	join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.source_entity_code = dd.plant_code and mkrate.account_code = 'KPI_AL_PRD_TOVAL_WH_STOCK'
	WHERE  dd.dt_report >=  DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and dd.dt_report <=  now()
	GROUP by dd.dt_report, mkrate.entity_code

	union all

	--скрипт из KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK
		select
			cal.dt as dt_report,
			mkrate.entity_code as entity_code,
			sum(t_main.weight_net) as actual
		from 	(select
				ssfp.dt_collection,
				coalesce(ssfp.dt_shipment,(date_trunc('day', now()) + '1 day'::interval)::date) as dt_shipment,
				ssfp.plant_producer_code,
				sum(ssfp.weight_net) as weight_net
			from dm.sales_shipment_from_plant ssfp
			where ssfp.dt_collection >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
				group by
				ssfp.dt_collection,
				ssfp.dt_shipment,
				ssfp.plant_producer_code) t_main
		join dict_dds.calendar cal on t_main.dt_collection <= cal.dt and cal.dt < t_main.dt_shipment
		join dict_dds.map_kpi_report_account_to_entity mkrate on t_main.plant_producer_code = mkrate.source_entity_code and mkrate.account_code = 'KPI_AL_PRD_TOVAL_WH_WHEELS_STOCK'
		where cal.dt >= (DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval) and cal.dt <= (date_trunc('day', now()) + '1 day'::interval)::date
			group by
			cal.dt,
			mkrate.entity_code

	) dd
where dd.actual is not null
group by dd.dt_report,	dd.entity_code
),
	mas_actual_goal as (
		select
		c.dt "REPORT_DATE",
		map.entity_code "ENTITY",
		round(sum((cast(vkgr."/BIC/ZIRVALUE"as numeric)) ),1) ACTUAL_GOAL
		from dict_dds.calendar c
		left join stg."/BIC/AZIR_O2300" vkgr on (DATE_TRUNC('MONTH', c.dt) = DATE_TRUNC('MONTH',TO_date(vkgr."CALDAY",'YYYYMMDD')))
		join dict_dds.map_kpi_report_account_to_entity map on vkgr."/BIC/ZIRENTITY" = map.source_entity_code and map.account_code = 'KPI_AL_PRD_TOVAL_WH_STOCK'
		where vkgr."/BIC/ZIRVERS" = 'NORM'
		and TO_date(vkgr."CALDAY",'YYYYMMDD') >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
group by
	c.dt,
	map.entity_code

	)
	select
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		coalesce(ms.ENTITY_CODE, mag."ENTITY") ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_TOTAL_STOCK' ACCOUNT_CODE,
		ms.ACTUAL,
		mag.ACTUAL_GOAL
	from mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	UNION ALL
	SELECT
		coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_AL_AD' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_TOTAL_STOCK' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	where ms.ENTITY_CODE != 'BU_AL_BOAZ'
	GROUP BY coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	UNION ALL
	SELECT
	    coalesce(ms.DT_REPORT,mag."REPORT_DATE") DT_REPORT,
		'BU_ALUM' ENTITY_CODE,
		'KPI_AL_PRD_TOVAL_WH_TOTAL_STOCK' ACCOUNT_CODE,
		sum(ms.ACTUAL) ACTUAL,
		sum(mag.ACTUAL_GOAL) ACTUAL_GOAL
	FROM mas_actual ms
	full join mas_actual_goal mag on mag."ENTITY" = ms.ENTITY_CODE and ms.DT_REPORT = mag."REPORT_DATE"
	GROUP BY coalesce(ms.DT_REPORT,mag."REPORT_DATE")
	) t1
	;
--Конец

 --EL_ENRG_VOL_DTL_ELECTR1.99 Объем потреб. э/э, млн кВтч.
 delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiar.account_code = 'EL_ENRG_VOL_DTL_ELECTR1.99';

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal
	)
select
date_trunc('month',vkgr."REPORT_DATE")::date as DT_REPORT,
vkgr."ENTITY" as ENTITY_CODE,
vkgr."ACCOUNT"||'_'||vkgr."DETAIL" as ACCOUNT_CODE,
vkgr."ACTUAL" as ACTUAL,
vkgr."ACTIVE_GOAL" as ACTUAL_GOAL
from stg."V_KPI_GOALS_REPORT" vkgr
join dict_dds.map_kpi_report_account_to_entity mkrate on vkgr."ACCOUNT"||'_'||vkgr."DETAIL" = mkrate.account_code and mkrate.source_entity_code = vkgr."ENTITY" and mkrate.account_code = 'EL_ENRG_VOL_DTL_ELECTR1.99'
where vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
and vkgr."REPORT_DATE" < date_trunc('month',TIMESTAMP 'now') + '1 month'::interval;
--Конец

--EL_ALL_TRF_DTL_ELECTR1.99 Средний тариф, коп./кВтч
 delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiara
	where
		kiara.dt_report >= date_trunc('YEAR',TIMESTAMP 'now')
		and kiara.account_code = 'EL_ALL_TRF_DTL_ELECTR1.99';

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	actual_ytd,
	active_goal_ytd
	)

with actual_mtd_ytd as (
select
date_trunc('month',vkgr."REPORT_DATE")::date as DT_REPORT,
vkgr."ENTITY" as ENTITY_CODE,
vkgr."ACTUAL_YTD" as ACTUAL_YTD,
vkgr."ACTIVE_GOAL_YTD" as ACTIVE_GOAL_YTD
FROM stg."V_KPI_GOALS_REPORT" vkgr
join dict_dds.map_kpi_report_account_to_entity mkrate on mkrate.source_entity_code = vkgr."ENTITY" and mkrate.account_code = 'EL_ALL_TRF_DTL_ELECTR1.99'
where vkgr."ACCOUNT" = 'EL_TAB_TARIFF'
and vkgr."DETAIL" = 'DTL_EL_TAB'
and vkgr."COUNTERPARTY" = 'CPT_EL_TOTAL'
and vkgr."PRODUCT" = 'PRD_CUR_RUB'
and vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
and vkgr."REPORT_DATE" < date_trunc('month',TIMESTAMP 'now') + '1 month'::interval
)

select
date_trunc('month',vkgr."REPORT_DATE")::date as DT_REPORT,
vkgr."ENTITY" as ENTITY_CODE,
vkgr."ACCOUNT"||'_'||vkgr."DETAIL" as ACCOUNT_CODE,
vkgr."ACTUAL" as ACTUAL,
vkgr."ACTIVE_GOAL" as ACTUAL_GOAL,
amy.ACTUAL_YTD,
amy.ACTIVE_GOAL_YTD
from stg."V_KPI_GOALS_REPORT" vkgr
join dict_dds.map_kpi_report_account_to_entity mkrate on vkgr."ACCOUNT"||'_'||vkgr."DETAIL" = mkrate.account_code and mkrate.source_entity_code = vkgr."ENTITY" and mkrate.account_code = 'EL_ALL_TRF_DTL_ELECTR1.99'
left join actual_mtd_ytd amy on date_trunc('month',vkgr."REPORT_DATE") = amy.DT_REPORT and vkgr."ENTITY" = amy.ENTITY_CODE
where vkgr."REPORT_DATE" >= date_trunc('YEAR',TIMESTAMP 'now')
and vkgr."REPORT_DATE" < date_trunc('month',TIMESTAMP 'now') + '1 month'::interval;
--Конец

----- KPI_AL_PRD_TOVAL_WH_LOADING Погрузка ГП на СГП, т
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code = 'KPI_AL_PRD_TOVAL_WH_LOADING';

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN
from
(
with
fact_0 as
(
select t.dt_collection as DT_REPORT
		,t.plant_producer_code
		,sum(weight_net) as fact
from dm_view.sales_shipment_from_plant t -- 66681
where shipment_type_for_reporting_name != 'без отгрузки'
	and loading_point_name like '%СГП%' -- только склады сгп
	and plant_producer_code not in ('1601', '1101') -- Их не нужно брать, это склады временного хранения
	and DELETED_FLAG is false
group by t.dt_collection, t.plant_producer_code
)
,fact_all as
(
	select
		t1.DT_REPORT
		,'BU_ALUM' as plant_producer_code
		,sum(fact) as  FACT
	from fact_0 as t1
	group by 1,2
	union all
	select
		t1.DT_REPORT
		,t1.plant_producer_code
		,t1.FACT
	from fact_0 as t1
)
,mas_entity as
(
	select distinct
	c.dt,
	mkrate.account_code,
	mkrate.entity_code,
	mkrate.entity_name,
	mkrate.source_entity_code,
	mkrate.subsequent_code
	from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c
	where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
	and mkrate.account_code in ('KPI_AL_PRD_TOVAL_WH_LOADING')
)
select
	t0.dt as DT_REPORT
	,t0.ENTITY_CODE
	,t0.ACCOUNT_CODE
	,sum(t1.FACT) as actual
	,NULL as "ZIRPRODCT"
	,null::numeric as ACTUAL_GOAL
	,null::numeric as ACTIVE_PLAN
	,null::numeric as KORR_PLAN
from mas_entity as t0
left join fact_all as t1
	on t0.dt = t1.DT_REPORT
	and t0.source_entity_code = t1.plant_producer_code
group by t0.dt, t0.ENTITY_CODE, t0.ACCOUNT_CODE
) t1;

-- KPI_AL_COUNT_OF_JOBS  Общ. число РМ

delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
where 1 = 1
	and kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
	and kiar.account_code in ('KPI_AL_COUNT_OF_JOBS');



insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN
from
(
	with calendar as
	(
		select
			dt
			, to_char(dt, 'YYYY-MM') as dt_m
			, to_char(dt, 'YYYY') as dt_y
		from dict_dds.calendar
		where 1 = 1
			and dt >= '2024-01-01' and dt <= cast(now() as date)
			and dt < date_trunc('month', current_date)
		order by 1 desc
	)
	,pred as
	(
	select
		factory
		,title
		,max(message_updated) as message_updated
	from stg.sapxi_sharepoint_workspacestandartisation
	where  division = 'АД'
	group by 1, 2
	)
	, fact1 as
	(
	select
		t2.factory
		,t2.title::smallint
		,t2.wp_count::numeric
	from stg.sapxi_sharepoint_workspacestandartisation t2
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_y from calendar) c
		on t2.title = c.dt_y
	)
	,fact_ad as
	( -- расчет АД
		select
		'АД' as factory
		,title
		,sum(wp_count) as wp_count
		from fact1
		 group by 1,2
	)
	,fact_all as
	(
		select
			factory
			,title
			,wp_count
		from fact1
		union all
		select
			factory
			,title
			,wp_count
		from fact_ad
	)
	,mas_entity as
	(
		select distinct
		c.dt,
		c.calendar_year,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c -- select * from dict_dds.calendar
		inner join calendar c2
			on c2.dt_m = to_char(c.dt, 'YYYY-MM')
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval -- для постоянки
--		where  c.dt >= '2022-01-01'::date AND c.dt <= CURRENT_DATE -- для фулл загрузки
			and mkrate.account_code in ('KPI_AL_COUNT_OF_JOBS')   -- select source_entity_code, * from dict_dds.map_kpi_report_account_to_entity
	)
	select
		t0.dt as DT_REPORT
		,t0.ENTITY_CODE
		,t0.ACCOUNT_CODE
		,t1.wp_count as actual
		,NULL as "ZIRPRODCT"
		,NULL::numeric as ACTUAL_GOAL
		,null::numeric as ACTIVE_PLAN
		,null::numeric as KORR_PLAN
	from mas_entity as t0
	left join fact_all as t1
		on t0.calendar_year = t1.title
		and t0.source_entity_code = t1.factory
	where 1 = 1
	and t1.wp_count is not null
) t1;


-- KPI_AL_COUNT_OF_JOBS_TO_BE_STANDARDIZD  Число РМ подл. СРМ
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where 1 = 1
and	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_AL_COUNT_OF_JOBS_TO_BE_STANDARDIZD');


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN
from
(
	with calendar as
	(
		select
			dt
			, to_char(dt, 'YYYY-MM') as dt_m
			, to_char(dt, 'YYYY') as dt_y
		from dict_dds.calendar
		where 1 = 1
			and dt >= '2024-01-01' and dt <= cast(now() as date)
			and dt < date_trunc('month', current_date)
		order by 1 desc
	)
	,pred as
	(
	select
		factory
		,title
		,max(message_updated) as message_updated
	from stg.sapxi_sharepoint_workspacestandartisation
	where  division = 'АД'
	group by 1, 2
	)
	, fact1 as
	(
	select
		t2.factory
		,t2.title::smallint
		,t2.wp_to_standard_count::numeric
	from stg.sapxi_sharepoint_workspacestandartisation t2
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_y from calendar) c
		on t2.title  = c.dt_y
	)
	,fact_ad as
	( -- расчет АД
		select
		'АД' as factory
		,title
		,sum(wp_to_standard_count) as wp_to_standard_count
		from fact1
		 group by 1,2
	)
	,fact_all as
	(
		select
			factory
			,title
			,wp_to_standard_count
		from fact1
		union all
		select
			factory
			,title
			,wp_to_standard_count
		from fact_ad
	)
	,mas_entity as
	(
		select distinct
		c.dt,
		c.calendar_year,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c -- select * from dict_dds.calendar
		inner join calendar c2
			on c2.dt_m = to_char(c.dt, 'YYYY-MM')
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval -- для постоянки
--		where  c.dt >= '2022-01-01'::date AND c.dt <= CURRENT_DATE -- для фулл загрузки
			and mkrate.account_code in ('KPI_AL_COUNT_OF_JOBS_TO_BE_STANDARDIZD')
	)
	select
		t0.dt as DT_REPORT
		,t0.ENTITY_CODE
		,t0.ACCOUNT_CODE
		,t1.wp_to_standard_count as actual
		,NULL as "ZIRPRODCT"
		,NULL::numeric as ACTUAL_GOAL
		,null::numeric as ACTIVE_PLAN
		,null::numeric as KORR_PLAN
	from mas_entity as t0
	left join fact_all as t1
		on t0.calendar_year = t1.title
		and t0.source_entity_code = t1.factory
	where 1 = 1
) t1;



-- KPI_AL_COUNT_STANDARDIZED_WORKPLACES               "2ур-нь, накоп. СРМ"
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where 1 = 1
and	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_AL_COUNT_STANDARDIZED_WORKPLACES');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN,
	actual_htd,
	active_goal_htd,
	actual_ytd,
	active_goal_ytd
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN,
		t1.actual_htd,
		t1.active_goal_htd,
		t1.actual_ytd,
		t1.active_goal_ytd
from
(
	with calendar as
	(
		select
			dt
			, to_char(dt, 'YYYY-MM') as dt_m
			, to_char(dt, 'YYYY') as dt_y
		from dict_dds.calendar
		where 1 = 1
			and dt >= '2024-01-01' and dt <= cast(now() as date)
			and dt < date_trunc('month', current_date)
		order by 1 desc
	)
	,pred as
	(
	select
		factory
		,title
		,max(message_updated) as message_updated
	from stg.sapxi_sharepoint_workspacestandartisation
	where  division = 'АД'
	group by 1, 2
	)
	, fact1 as
	(
	select
		t2.factory
		,t2.title || '-01' AS year_month
		,t2.title::smallint
		,t2.plan1::numeric as active_goal_htd
		,t2.fact1::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-01' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-02' AS year_month
		,t2.title::smallint
		,t2.plan2::numeric as active_goal_htd
		,t2.fact2::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-02' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-03' AS year_month
		,t2.title::smallint
		,t2.plan3::numeric as active_goal_htd
		,t2.fact3::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-03' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-04' AS year_month
		,t2.title::smallint
		,t2.plan4::numeric as active_goal_htd
		,t2.fact4::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-04' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-05' AS year_month
		,t2.title::smallint
		,t2.plan5::numeric as active_goal_htd
		,t2.fact5::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-05' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-06' AS year_month
		,t2.title::smallint
		,t2.plan6::numeric as active_goal_htd
		,t2.fact6::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-06' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-07' AS year_month
		,t2.title::smallint
		,t2.plan7::numeric as active_goal_htd
		,t2.fact7::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-07' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-08' AS year_month
		,t2.title::smallint
		,t2.plan8::numeric as active_goal_htd
		,t2.fact8::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-08' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-09' AS year_month
		,t2.title::smallint
		,t2.plan9::numeric as active_goal_htd
		,t2.fact9::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-09' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-10' AS year_month
		,t2.title::smallint
		,t2.plan10::numeric as active_goal_htd
		,t2.fact10::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-10' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-11' AS year_month
		,t2.title::smallint
		,t2.plan11::numeric as active_goal_htd
		,t2.fact11::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-11' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-12' AS year_month
		,t2.title::smallint
		,t2.plan12::numeric as active_goal_htd
		,t2.fact12::numeric as actual_htd
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select distinct dt_m from calendar) c
		on t2.title || '-12' = c.dt_m
	)
	,fact_ad as
	( -- расчет АД
		select
		'АД' as factory
		,title
		,year_month
		,sum(active_goal_htd) as active_goal_htd
		,sum(actual_htd) as actual_htd
		from fact1
		 group by 1,2,3
	)
	,fact_all as
	(
		select
			factory
			,title
			,year_month
			,active_goal_htd
			,actual_htd
			,CASE
        		WHEN ROW_NUMBER() OVER (PARTITION BY factory ORDER BY year_month) = 1 THEN active_goal_htd
        		ELSE active_goal_htd - LAG(active_goal_htd) OVER (PARTITION BY factory ORDER BY year_month)
    			END AS active_goal
			,CASE
        		WHEN ROW_NUMBER() OVER (PARTITION BY factory ORDER BY year_month) = 1 THEN actual_htd
        		ELSE actual_htd - LAG(actual_htd) OVER (PARTITION BY factory ORDER BY year_month)
    			END AS actual

		from fact1
		union all
		select
			factory
			,title
			,year_month
			,active_goal_htd
			,actual_htd
			,CASE
        		WHEN ROW_NUMBER() OVER (PARTITION BY factory ORDER BY year_month) = 1 THEN active_goal_htd
        		ELSE active_goal_htd - LAG(active_goal_htd) OVER (PARTITION BY factory ORDER BY year_month)
    			END AS active_goal
			,CASE
        		WHEN ROW_NUMBER() OVER (PARTITION BY factory ORDER BY year_month) = 1 THEN active_goal_htd
        		ELSE actual_htd - LAG(actual_htd) OVER (PARTITION BY factory ORDER BY year_month)
    			END AS actual
		from fact_ad
	)
	,fact_all_2 as
	(
		select
			factory
			,title
			,year_month
			,active_goal_htd
			,actual_htd
			,active_goal
			,actual
			,sum(active_goal) over(partition by factory, title order by(year_month) rows between unbounded preceding and current row) as active_goal_ytd
			,sum(actual) over(partition by factory, title order by(year_month) rows between unbounded preceding and current row) as actual_ytd
		from fact_all
	)
	,mas_entity as
	(
		select distinct
		c.dt,
		c.calendar_year,
		to_char(c.dt, 'YYYY-MM') AS year_month,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c -- select * from dict_dds.calendar
		inner join calendar c2
			on c2.dt_m = to_char(c.dt, 'YYYY-MM')
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval -- для постоянки
--		where  c.dt >= '2022-01-01'::date AND c.dt <= CURRENT_DATE -- для фулл загрузки
			and mkrate.account_code in ('KPI_AL_COUNT_STANDARDIZED_WORKPLACES')
	)
	select
		t0.dt as DT_REPORT
		,t0.ENTITY_CODE
		,t0.ACCOUNT_CODE
		,t1.actual as actual
		,NULL as "ZIRPRODCT"
		,t1.active_goal::numeric as ACTUAL_GOAL   -- select * from dict_dds.map_kpi_report_account_to_entity
		,null::numeric as ACTIVE_PLAN
		,null::numeric as KORR_PLAN
		,t1.actual_htd
		,t1.active_goal_htd
		,t1.actual_ytd
		,t1.active_goal_ytd
	from mas_entity as t0
	left join fact_all_2 as t1
		on t0.year_month = t1.year_month
		and t0.source_entity_code = t1.factory
	where 1 = 1
) t1;



-- % СРМ  KPI_AL_PERCENTAGE_OF_JOB_STANDARDIZATION_COMPLETED
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where 1 = 1
and	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_AL_PERCENTAGE_OF_JOB_STANDARDIZATION_COMPLETED');


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN,
	actual_htd,
	active_goal_htd
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN,
		t1.actual_htd,
		t1.active_goal_htd
from
(
	with calendar as
	(
		select
			distinct to_char(dt, 'YYYY-MM') as dt_m
		from dict_dds.calendar
		where 1 = 1
			and dt >= '2024-01-01' and dt <= cast(now() as date)
			and dt < date_trunc('month', current_date)
	)
	,pred as
	(
	select
		factory
		,title
		,max(message_updated) as message_updated
	from stg.sapxi_sharepoint_workspacestandartisation
	where  division = 'АД'
	group by 1, 2
	)
	, fact1 as
	(
	select
		t2.factory
		,t2.title || '-01' AS year_month
		,t2.title::smallint
		,t2.plan1::numeric as active_goal_htd
		,t2.fact1::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-01' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-02' AS year_month
		,t2.title::smallint
		,t2.plan2::numeric as active_goal_htd
		,t2.fact2::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-02' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-03' AS year_month
		,t2.title::smallint
		,t2.plan3::numeric as active_goal_htd
		,t2.fact3::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-03' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-04' AS year_month
		,t2.title::smallint
		,t2.plan4::numeric as active_goal_htd
		,t2.fact4::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-04' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-05' AS year_month
		,t2.title::smallint
		,t2.plan5::numeric as active_goal_htd
		,t2.fact5::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-05' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-06' AS year_month
		,t2.title::smallint
		,t2.plan6::numeric as active_goal_htd
		,t2.fact6::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-06' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-07' AS year_month
		,t2.title::smallint
		,t2.plan7::numeric as active_goal_htd
		,t2.fact7::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-07' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-08' AS year_month
		,t2.title::smallint
		,t2.plan8::numeric as active_goal_htd
		,t2.fact8::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-08' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-09' AS year_month
		,t2.title::smallint
		,t2.plan9::numeric as active_goal_htd
		,t2.fact9::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-09' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-10' AS year_month
		,t2.title::smallint
		,t2.plan10::numeric as active_goal_htd
		,t2.fact10::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-10' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-11' AS year_month
		,t2.title::smallint
		,t2.plan11::numeric as active_goal_htd
		,t2.fact11::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-11' = c.dt_m

	union all

	select
		t2.factory
		,t2.title || '-12' AS year_month
		,t2.title::smallint
		,t2.plan12::numeric as active_goal_htd
		,t2.fact12::numeric as actual_htd
		,t2.wp_to_standard_count::numeric as wp_to_standard_count
	from stg.sapxi_sharepoint_workspacestandartisation t2 	-- select * from stg.sapxi_sharepoint_workspacestandartisation
	inner join pred t1
		on t1.factory = t2.factory
		and t1.title = t2.title
		and t1.message_updated = t2.message_updated
	inner join (select dt_m from calendar) c
		on t2.title || '-12' = c.dt_m
	)
	,fact_ad as
	( -- расчет АД
		select
		'АД' as factory
		,title
		,year_month
		,sum(active_goal_htd) as active_goal_htd
		,sum(actual_htd) as actual_htd
		,sum(wp_to_standard_count) as wp_to_standard_count
		from fact1
		 group by 1,2,3
	)
	,fact_all as
	(
		select
			factory
			,title
			,year_month
			,coalesce(active_goal_htd/nullif(wp_to_standard_count, 0), 0) * 100 as active_goal
			,coalesce(actual_htd/nullif(wp_to_standard_count, 0), 0) * 100 as actual
		from fact1
		union all
		select
			factory
			,title
			,year_month
			,coalesce(active_goal_htd/nullif(wp_to_standard_count, 0), 0) * 100 as active_goal
			,coalesce(actual_htd/nullif(wp_to_standard_count, 0), 0) * 100 as actual
		from fact_ad
	)
	,mas_entity as
	(
		select distinct
		c.dt,
		c.calendar_year,
		to_char(c.dt, 'YYYY-MM') AS year_month,
		mkrate.account_code,
		mkrate.entity_code,
		mkrate.entity_name,
		mkrate.source_entity_code,
		mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate, dict_dds.calendar c -- select * from dict_dds.calendar
		inner join calendar c2
			on c2.dt_m = to_char(c.dt, 'YYYY-MM')
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval -- для постоянки
--		where  c.dt >= '2022-01-01'::date AND c.dt <= CURRENT_DATE -- для фулл загрузки
			and mkrate.account_code in ('KPI_AL_PERCENTAGE_OF_JOB_STANDARDIZATION_COMPLETED')
	)
	select
		t0.dt as DT_REPORT
		,t0.ENTITY_CODE
		,t0.ACCOUNT_CODE
		,t1.actual as actual
		,NULL as "ZIRPRODCT"
		,t1.active_goal::numeric as ACTUAL_GOAL
		,null::numeric as ACTIVE_PLAN
		,null::numeric as KORR_PLAN
		,null::numeric as actual_htd
		,null::numeric as active_goal_htd
	from mas_entity as t0
	left join fact_all as t1
		on t0.year_month = t1.year_month
		and t0.source_entity_code = t1.factory
	where 1 = 1
) t1;

-- KPI_ALUM_TEC_08a_CC простои оборудования по производству прокаленный кокс

	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_ALUM_TEC_08a_CC');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with dict_type_of_prod2 as
			(
				select
					t1.production_area_code
					,t3.production_area_name as distr
					,t1.plant_code
					,REPLACE(t4.plant_short_name, '*', '') as entity
					,t1.production_activity_type_code
					,t2.production_activity_type_name as direction
				from dict_dds.map_production_area_to_production_activity_type t1 -- select * from dict_dds.map_production_area_to_production_activity_type
				left join dict_dds.production_activity_type_texts t2
					on t1.production_activity_type_code = t2.production_activity_type_code
				left join dict_dds.production_area_texts t3
					on t1.production_area_code = t3.production_area_code
				left join dict_dds.plant_and_subsidiary t4 -- select * from dict_dds.plant_and_subsidiary where plant_short_name like '%ШБРАЗ%' or  plant_short_name like '%ИркАЗ%' -- 6100 ИРКАЗ   -- select * from dict_dds.plant_and_subsidiary
					on t1.plant_code = t4.plant_code
				where 1 = 1
				and t1.deleted_flag is false
				and t2.deleted_flag is false
				and t3.deleted_flag is false
				and t4.deleted_flag is false
			)
			, dict_type_of_prod2_alias as
			(
			select
				production_area_code
				,distr
				,REPLACE(plant_code, '6100', '5203') as plant_code
				,REPLACE(entity, 'ИркАЗ', 'ШБРАЗ') as entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2 where entity = 'ИркАЗ'
			)
			,dict_type_of_prod3 as -- lВ отчетности завод ИРКАЗ а из САП приходит ШБРАЗ, хотя в участках написан завод ИРКАЗ, здесь оставляю и тот и тот для 1 участка, на случай, если вдруг из САП начнет приходить ИКРАЗ вместо ШБРАЗ
			(
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2
			union
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2_alias
			)
			,mas_entity_pred as (
		select distinct
			c.dt,
			mkrate.account_code,
			mkrate.entity_code,
			mkrate.entity_name,
			mkrate.source_entity_code,
			mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate --
		,dict_dds.calendar c
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		and mkrate.account_code in ('KPI_ALUM_TEC_08a_CC')
		)

		,mas_entity2 as
		(
			select t1.*, t2.direction, t2.production_area_code
			from mas_entity_pred t1
			left join (select distinct entity, direction, production_area_code from dict_type_of_prod3) t2
				on t1.source_entity_code = t2.entity
			where direction is not null
			and t2.direction = 'Прокаленный кокс по заводам'
		)
		,mas_actual2 as (
			--Начало
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				me.direction,
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity2 me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
						,t1."DIVISION"
						,t1."DIVISION_TXT"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_08a_CC'
				and me.dt = vtud."PLAN_DATE"
				and me.production_area_code = vtud."DIVISION"
			left join stg."V_KPI_GOALS_REPORT" vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE, me.direction, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"
		)
		, ad as (
				select
			DT_REPORT,
			'BU_AL_AD' ENTITY_CODE,
			ACCOUNT_CODE,
			direction,
			sum(ACTUAL) as ACTUAL,
			sum(ACTUAL_GOAL) as ACTUAL_GOAL,
			sum(ACTIVE_PLAN) as ACTIVE_PLAN
		from mas_actual2
		where entity_code not in ('BU_AL_BOAZ')
		group by 1,2,3,4
		)

			select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			 from mas_actual2
			 union all
			 select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			  from ad
) t1;

--KPI_AL_PERS_AV_QTY,KPI_ILLNESS_QUANTITY,KPI_ILLNESS_PERCENTAGE
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 month'::interval
		and kiar.account_code in ('KPI_AL_PERS_AV_QTY','KPI_ILLNESS_QUANTITY','KPI_ILLNESS_PERCENTAGE');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_goal,
	actual_mtd,
	actual_ytd
	)

	select
	t.dt_report,
	t.entity_code,
	t.account_code,
	t.actual,
	t.actual_goal,
	t.actual_mtd,
	t.actual_ytd
	from (
with max_rec as (
		select
				pa.dt_report,
				pa.plant_code,
				max(record_id) record_id
		from stg.sapxi_1c_personnel_attendance pa
		where pa.dt_report::date >= date_trunc('YEAR', TIMESTAMP 'now') - '1 year'::interval
		group by
				pa.dt_report,
				pa.plant_code),

		group_personnel_attendance as (
		select
			dt_report,
			plant_code,
			plant_name,
			record_id,
			sum(actual::numeric) as actual,
			sum(active_goal::numeric) as active_goal,
			sum(sick_leaves::numeric) as sick_leaves,
			sum(headcount::numeric) as headcount
		from stg.sapxi_1c_personnel_attendance
		where dt_report::date >= date_trunc('YEAR', TIMESTAMP 'now') - '1 year'::interval
		group by
			dt_report,
			plant_code,
			plant_name,
			record_id
		),

		KPI_ILLNESS_QUANTITY as ( --Больничные листы, шт
		select
				pa.dt_report::date as "DT_REPORT",
				mkrate.entity_code as "ENTITY_CODE",
				mkrate.account_code as "ACCOUNT_CODE",
				pa.sick_leaves::numeric as "ACTUAL",
				(sum(sick_leaves::numeric) over (partition by mkrate.entity_code,date_trunc('month',pa.dt_report::date) order by pa.dt_report::date)/extract (day from pa.dt_report::date))::numeric as actual_mtd,
				(sum(sick_leaves::numeric) over (partition by mkrate.entity_code,date_trunc('year',pa.dt_report::date) order by pa.dt_report::date)/((pa.dt_report::date - date_trunc('year',pa.dt_report::date)::date)::numeric+1))::numeric as actual_ytd
		from group_personnel_attendance pa
		join dict_dds.map_kpi_report_account_to_entity mkrate on pa.plant_code=mkrate.source_entity_code and mkrate.account_code='KPI_ILLNESS_QUANTITY' --Больничные листы, шт		KPI_ILLNESS_QUANTITY
		join max_rec on pa.dt_report = max_rec.dt_report and pa.plant_code = max_rec.plant_code and pa.record_id = max_rec.record_id
		where pa.dt_report::date >= date_trunc('YEAR', TIMESTAMP 'now') - '1 year'::interval
		),

		KPI_AL_PERS_AV_QTY as ( --Списочная численность, чел
		select
				pa.dt_report::date as "DT_REPORT",
				mkrate.entity_code as "ENTITY_CODE",
				mkrate.account_code as "ACCOUNT_CODE",
				pa.headcount::numeric as "ACTUAL",
				(sum(headcount::numeric) over (partition by mkrate.entity_code,date_trunc('month',pa.dt_report::date) order by pa.dt_report::date)/extract(day from pa.dt_report::date))::numeric as actual_mtd,
				(sum(headcount::numeric) over (partition by mkrate.entity_code,date_trunc('year',pa.dt_report::date) order by pa.dt_report::date)/((pa.dt_report::date - date_trunc('year',pa.dt_report::date)::date)::numeric+1))::numeric as actual_ytd
		from group_personnel_attendance pa
		join dict_dds.map_kpi_report_account_to_entity mkrate on pa.plant_code=mkrate.source_entity_code and mkrate.account_code='KPI_AL_PERS_AV_QTY' --Списочная численность, чел		KPI_AL_PERS_AV_QTY
		join max_rec on pa.dt_report = max_rec.dt_report and pa.plant_code = max_rec.plant_code and pa.record_id = max_rec.record_id
		where pa.dt_report::date >= date_trunc('YEAR', TIMESTAMP 'now') - '1 year'::interval
		),

		zyfra as ( --Цифра. План для % заболеваемости
		select
		apaz.timestamp::date as beg_date,
		LEAD(apaz.timestamp::date, 1, (date_trunc('month',now()) + '1 month'::interval)::date) OVER (PARTITION BY apaz.id ORDER BY apaz.timestamp::date) as end_date,
		apaz.value
		from stg.auxiliary_production_anode_zyfra apaz
		where apaz.id = '228b74a2-d12b-4ecc-b0e2-564501d2cb03'
		),

		mas_actual_goal as (
			select
			c.dt,
			zyf.beg_date,
			zyf.end_date,
			zyf.value::numeric
			from zyfra zyf
			join dict_dds.calendar c on zyf.beg_date<=c.dt and c.dt<zyf.end_date
		)

		--Списочная численность, чел, KPI_AL_PERS_AV_QTY
		select
			"DT_REPORT" as dt_report,
			"ENTITY_CODE" as entity_code,
			"ACCOUNT_CODE" as account_code,
			"ACTUAL" as actual,
			round(actual_mtd,1) as actual_mtd,
			round(actual_ytd,1) as actual_ytd,
			null as actual_goal
		from KPI_AL_PERS_AV_QTY
		where "DT_REPORT" >= date_trunc('YEAR', TIMESTAMP 'now') - '1 month'::interval

		union all

		select
			"DT_REPORT",
			'BU_ALUM' as "ENTITY_CODE",
			"ACCOUNT_CODE",
			sum("ACTUAL") as "ACTUAL",
			round(sum(actual_mtd),1) as actual_mtd,
			round(sum(actual_ytd),1) as actual_ytd,
			null as actual_gaol
		from KPI_AL_PERS_AV_QTY
		where "DT_REPORT" >= date_trunc('YEAR', TIMESTAMP 'now') - '1 month'::interval
		group by
			"DT_REPORT",
			"ACCOUNT_CODE"
		----Конец Списочная численность, чел, KPI_AL_PERS_AV_QTY----------------------------------------------------------

		union all

		--Больничные листы, шт, KPI_ILLNESS_QUANTITY
		select
			"DT_REPORT",
			"ENTITY_CODE",
			"ACCOUNT_CODE",
			"ACTUAL",
			round(actual_mtd,1),
			round(actual_ytd,1),
			null as actual_gaol
		from KPI_ILLNESS_QUANTITY
		where "DT_REPORT" >= date_trunc('YEAR', TIMESTAMP 'now') - '1 month'::interval

		union all

		select
			"DT_REPORT",
			'BU_ALUM' as "ENTITY_CODE",
			"ACCOUNT_CODE",
			sum("ACTUAL") as "ACTUAL",
			round(sum(actual_mtd),1) as actual_mtd,
			round(sum(actual_ytd),1) as actual_ytd,
			null as actual_gaol
		from KPI_ILLNESS_QUANTITY
		where "DT_REPORT" >= date_trunc('YEAR', TIMESTAMP 'now') - '1 month'::interval
		group by
			"DT_REPORT",
			"ACCOUNT_CODE"
		----Конец Больничные листы, шт, KPI_ILLNESS_QUANTITY----------------------------------------------------------

		union all

		--Факт заболеваемости, %, KPI_ILLNESS_PERCENTAGE
		select
			pers_av."DT_REPORT",
			pers_av."ENTITY_CODE",
			'KPI_ILLNESS_PERCENTAGE' as "ACCOUNT_CODE",
			round(illness_qua."ACTUAL"/pers_av."ACTUAL"*100,1) as"ACTUAL",
			round(illness_qua.actual_mtd/pers_av.actual_mtd*100,1) as actual_mtd,
			round(illness_qua.actual_ytd/pers_av.actual_ytd*100,1) as actual_ytd,
			mag.value as actual_gaol
		from KPI_AL_PERS_AV_QTY as pers_av
		join KPI_ILLNESS_QUANTITY illness_qua on pers_av."DT_REPORT" = illness_qua."DT_REPORT" and pers_av."ENTITY_CODE" = illness_qua."ENTITY_CODE"
		left join mas_actual_goal mag on pers_av."DT_REPORT" = mag.dt
		where pers_av."DT_REPORT" >= date_trunc('YEAR', TIMESTAMP 'now') - '1 month'::interval

		union all

		select
			pers_av."DT_REPORT",
			'BU_ALUM' as "ENTITY_CODE",
			'KPI_ILLNESS_PERCENTAGE' as "ACCOUNT_CODE",--pers_av."ACCOUNT_CODE",
			round(sum(illness_qua."ACTUAL")/sum(pers_av."ACTUAL")*100,1) as"ACTUAL",
			round(sum(illness_qua.actual_mtd)/sum(pers_av.actual_mtd)*100,1) as actual_mtd,
			round(sum(illness_qua.actual_ytd)/sum(pers_av.actual_ytd)*100,1) as actual_ytd,
			mag.value as actual_gaol
		from KPI_AL_PERS_AV_QTY as pers_av
		join KPI_ILLNESS_QUANTITY illness_qua on pers_av."DT_REPORT" = illness_qua."DT_REPORT" and pers_av."ENTITY_CODE" = illness_qua."ENTITY_CODE"
		left join mas_actual_goal mag on pers_av."DT_REPORT" = mag.dt
		where pers_av."DT_REPORT" >= date_trunc('YEAR', TIMESTAMP 'now') - '1 month'::interval
		group by
			pers_av."DT_REPORT",
			mag.value
		----Конец Факт заболеваемости, %, KPI_ILLNESS_PERCENTAGE----------------------------------------------------------
)t;



-- KPI_ALUM_TEC_08a_GA простои оборудования по зеленым анодам
	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		and kiar.account_code in ('KPI_ALUM_TEC_08a_GA');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with dict_type_of_prod2 as
			(
				select
					t1.production_area_code
					,t3.production_area_name as distr
					,t1.plant_code
					,REPLACE(t4.plant_short_name, '*', '') as entity
					,t1.production_activity_type_code
					,t2.production_activity_type_name as direction
				from dict_dds.map_production_area_to_production_activity_type t1
				left join dict_dds.production_activity_type_texts t2
					on t1.production_activity_type_code = t2.production_activity_type_code
				left join dict_dds.production_area_texts t3
					on t1.production_area_code = t3.production_area_code
				left join dict_dds.plant_and_subsidiary t4
					on t1.plant_code = t4.plant_code
				where 1 = 1
				and t1.deleted_flag is false
				and t2.deleted_flag is false
				and t3.deleted_flag is false
				and t4.deleted_flag is false
			)
			, dict_type_of_prod2_alias as
			(
			select
				production_area_code
				,distr
				,REPLACE(plant_code, '6100', '5203') as plant_code
				,REPLACE(entity, 'ИркАЗ', 'ШБРАЗ') as entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2 where entity = 'ИркАЗ'
			)
			,dict_type_of_prod3 as
			(
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2
			union
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2_alias
			)
			,mas_entity_pred as (
		select distinct
			c.dt,
			mkrate.account_code,
			mkrate.entity_code,
			mkrate.entity_name,
			mkrate.source_entity_code,
			mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate --
		,dict_dds.calendar c
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		and mkrate.account_code in ('KPI_ALUM_TEC_08a_GA')
		)
		,mas_entity2 as
		(
			select t1.*, t2.direction, t2.production_area_code
			from mas_entity_pred t1
			left join (select distinct entity, direction, production_area_code from dict_type_of_prod3) t2
				on t1.source_entity_code = t2.entity
			where direction is not null
			and t2.direction = 'Зеленые аноды по заводам'
		)
		,mas_actual2 as (
			--Начало
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				me.direction,
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity2 me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
						,t1."DIVISION"
						,t1."DIVISION_TXT"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_08a_GA'
				and me.dt = vtud."PLAN_DATE"
				and me.production_area_code = vtud."DIVISION"
			left join stg."V_KPI_GOALS_REPORT" vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE, me.direction, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"
		)
		, ad as (
				select
			DT_REPORT,
			'BU_AL_AD' ENTITY_CODE,
			ACCOUNT_CODE,
			direction,
			sum(ACTUAL) as ACTUAL,
			sum(ACTUAL_GOAL) as ACTUAL_GOAL,
			sum(ACTIVE_PLAN) as ACTIVE_PLAN
		from mas_actual2
		where entity_code not in ('BU_AL_BOAZ')
		group by 1,2,3,4
		)

			select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			 from mas_actual2
			 union all
			 select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			  from ad
) t1;



-- KPI_ALUM_TEC_DOWNTIME_ANODE_MASS простои оборудования по зеленым анодам

	delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_ALUM_TEC_DOWNTIME_ANODE_MASS');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with dict_type_of_prod2 as
			(
				select
					t1.production_area_code
					,t3.production_area_name as distr
					,t1.plant_code
					,REPLACE(t4.plant_short_name, '*', '') as entity
					,t1.production_activity_type_code
					,t2.production_activity_type_name as direction
				from dict_dds.map_production_area_to_production_activity_type t1
				left join dict_dds.production_activity_type_texts t2
					on t1.production_activity_type_code = t2.production_activity_type_code
				left join dict_dds.production_area_texts t3
					on t1.production_area_code = t3.production_area_code
				left join dict_dds.plant_and_subsidiary t4
					on t1.plant_code = t4.plant_code
				where 1 = 1
				and t1.deleted_flag is false
				and t2.deleted_flag is false
				and t3.deleted_flag is false
				and t4.deleted_flag is false
			)
			, dict_type_of_prod2_alias as
			(
			select
				production_area_code
				,distr
				,REPLACE(plant_code, '6100', '5203') as plant_code
				,REPLACE(entity, 'ИркАЗ', 'ШБРАЗ') as entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2 where entity = 'ИркАЗ'
			)
			,dict_type_of_prod3 as
			(
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2
			union
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2_alias
			)
			,mas_entity_pred as (
		select distinct
			c.dt,
			mkrate.account_code,
			mkrate.entity_code,
			mkrate.entity_name,
			mkrate.source_entity_code,
			mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate
		,dict_dds.calendar c
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		and mkrate.account_code in ('KPI_ALUM_TEC_DOWNTIME_ANODE_MASS')
		)
		,mas_entity2 as
		(
			select t1.*, t2.direction, t2.production_area_code
			from mas_entity_pred t1
			left join (select distinct entity, direction, production_area_code from dict_type_of_prod3) t2
				on t1.source_entity_code = t2.entity
			where direction is not null
			and t2.direction = 'Пр-во анодной массы по заводам'
		)
		,mas_actual2 as (
			--Начало
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				me.direction,
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity2 me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
						,t1."DIVISION"
						,t1."DIVISION_TXT"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_DOWNTIME_ANODE_MASS'
				and me.dt = vtud."PLAN_DATE"
				and me.production_area_code = vtud."DIVISION"
			left join stg."V_KPI_GOALS_REPORT" vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE, me.direction, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"
		)
		, ad as (
				select
			DT_REPORT,
			'BU_AL_AD' ENTITY_CODE,
			ACCOUNT_CODE,
			direction,
			sum(ACTUAL) as ACTUAL,
			sum(ACTUAL_GOAL) as ACTUAL_GOAL,
			sum(ACTIVE_PLAN) as ACTIVE_PLAN
		from mas_actual2
		where entity_code not in ('BU_AL_BOAZ')
		group by 1,2,3,4
		)

			select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			 from mas_actual2
			 union all
			 select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			  from ad
) t1;


-- KPI_ALUM_TEC_DOWNTIME_ANODE_BAKED простои Обоженные аноды по заводам
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
	kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
and kiar.account_code in ('KPI_ALUM_TEC_DOWNTIME_ANODE_BAKED');

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	"ZIRPRODCT",
	actual_goal,
	ACTIVE_PLAN,
	KORR_PLAN
	)
select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.ACTUAL,
		t1."ZIRPRODCT",
		t1.ACTUAL_GOAL,
		t1.ACTIVE_PLAN,
		t1.KORR_PLAN

	from (
		with dict_type_of_prod2 as
			(
				select
					t1.production_area_code
					,t3.production_area_name as distr
					,t1.plant_code
					,REPLACE(t4.plant_short_name, '*', '') as entity
					,t1.production_activity_type_code
					,t2.production_activity_type_name as direction
				from dict_dds.map_production_area_to_production_activity_type t1
				left join dict_dds.production_activity_type_texts t2
					on t1.production_activity_type_code = t2.production_activity_type_code
				left join dict_dds.production_area_texts t3
					on t1.production_area_code = t3.production_area_code
				left join dict_dds.plant_and_subsidiary t4
					on t1.plant_code = t4.plant_code
				where 1 = 1
				and t1.deleted_flag is false
				and t2.deleted_flag is false
				and t3.deleted_flag is false
				and t4.deleted_flag is false
			)
			, dict_type_of_prod2_alias as
			(
			select
				production_area_code
				,distr
				,case
					when plant_code = '6100' then '5203'
					when plant_code = '5511' then '5301'
				end as plant_code
				,case
					when entity = 'ИркАЗ' then 'ШБРАЗ'
					when entity = 'ХАЗ' then 'САЗ'
				end as entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2 where entity in ('ИркАЗ', 'ХАЗ')
			)
			,dict_type_of_prod3 as
			(
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2
			union
			select
				production_area_code
				,distr
				,plant_code
				,entity
				,production_activity_type_code
				,direction
			from dict_type_of_prod2_alias
			)
			,mas_entity_pred as (
		select distinct
			c.dt,
			mkrate.account_code,
			mkrate.entity_code,
			mkrate.entity_name,
			mkrate.source_entity_code,
			mkrate.subsequent_code
		from dict_dds.map_kpi_report_account_to_entity mkrate --
		,dict_dds.calendar c
		where c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
		and mkrate.account_code in ('KPI_ALUM_TEC_DOWNTIME_ANODE_BAKED')
		)
		,mas_entity2 as
		(
			select t1.*, t2.direction, t2.production_area_code
			from mas_entity_pred t1
			left join (select distinct entity, direction, production_area_code from dict_type_of_prod3) t2
				on t1.source_entity_code = t2.entity
			where direction is not null
			and t2.direction = 'Обоженные аноды по заводам'
		)
		,mas_actual2 as (
			--Начало
			select
				me.dt DT_REPORT,
				me.entity_code ENTITY_CODE,
				me.ACCOUNT_CODE,
				me.direction,
				coalesce(round(sum(vtud."DATEDIFF_FOR_DATE")/60,5),0) ACTUAL,
			 	coalesce(round((vkgr."ACTIVE_GOAL")/((DATE_PART('days',DATE_TRUNC('month',me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTUAL_GOAL,
			  	coalesce(round((vkgr."MONTH_PLAN")/((DATE_PART('days',DATE_TRUNC('month', me.dt) + '1 MONTH'::INTERVAL - '1 DAY'::INTERVAL))::numeric),5),0) ACTIVE_PLAN,
			    NULL KORR_PLAN
			from mas_entity2 me
			left join
				(
					select
						t1."NAME1"
						,t1."PLAN_DATE"
						,t1."DATEDIFF_FOR_DATE"
						,t1."DIVISION"
						,t1."DIVISION_TXT"
					from stg."V_TORO2_UNPLANNED_DWNT" t1
				) vtud
				on LOWER(me.source_entity_code) = LOWER(vtud."NAME1")
				and me.ACCOUNT_CODE = 'KPI_ALUM_TEC_DOWNTIME_ANODE_BAKED'
				and me.dt = vtud."PLAN_DATE"
				and me.production_area_code = vtud."DIVISION"
			left join stg."V_KPI_GOALS_REPORT" vkgr
				on vkgr."ACCOUNT" = me. ACCOUNT_CODE
				and DATE_TRUNC('month',me.dt ) = DATE_TRUNC('month',vkgr."REPORT_DATE")
				and me.entity_code = vkgr."ENTITY"
				and vkgr."ENTITY" != 'BU_AL_AD'
			group by me.dt, me.entity_code, me.ACCOUNT_CODE, me.direction, vkgr."ACTIVE_GOAL", vkgr."MONTH_PLAN"
		)
		, ad as (
				select
			DT_REPORT,
			'BU_AL_AD' ENTITY_CODE,
			ACCOUNT_CODE,
			direction,
			sum(ACTUAL) as ACTUAL,
			sum(ACTUAL_GOAL) as ACTUAL_GOAL,
			sum(ACTIVE_PLAN) as ACTIVE_PLAN
		from mas_actual2
		where entity_code not in ('BU_AL_BOAZ')
		group by 1,2,3,4
		)

			select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			 from mas_actual2
			 union all
			 select DT_REPORT,
				ENTITY_CODE,
				ACCOUNT_CODE,
				direction,
				null::numeric as "ZIRPRODCT",
				ACTUAL,
			 	ACTUAL_GOAL,
			  	ACTIVE_PLAN,
			  	null::numeric as KORR_PLAN
			  from ad
) t1;

--KPI_QLT_13 (Тех. отходы, %)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD"  kiara
	where kiara.account_code in ('KPI_QLT_13')
	and kiara.dt_report >= DATE_TRUNC('YEAR', now());

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_mtd,
	actual_ytd,
	actual_goal,
	active_goal_ytd,
	active_goal_mtd
	)

select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.actual,
		t1.actual_mtd,
		t1.actual_ytd,
		null::numeric as actual_goal,
		null::numeric as active_goal_ytd,
		null::numeric as active_goal_mtd
from
(

	with mas_entity as (

	select
		 c.dt,
		 mkrate.account_code,
		 mkrate.entity_code,
		 mkrate.source_entity_code

	from dict_dds.map_kpi_report_account_to_entity mkrate
	cross join dict_dds.calendar c
	where mkrate.account_code = 'KPI_QLT_13'
		and mkrate.entity_code <> 'BU_AL_AD'
		and c.dt >= date_trunc('year', now()) and c.dt < date_trunc('month', now()) + interval '1 month'

	),

	group_table as (
	select
		date_trunc,
		smelter,
		sum(fact_techn_wast_all) as fact_techn_wast_all,
		sum(obrazovano) as obrazovano
	from stg.sapxi_production_waste_report spwr
	where date_trunc >= DATE_TRUNC('year', now())
	group by
		date_trunc,
		smelter
	),


	t_main as (
	select
	date_trunc,
	smelter,
	fact_techn_wast_all,
	obrazovano,
	sum(fact_techn_wast_all) over (partition by date_trunc('month',date_trunc),smelter order by date_trunc asc) fact_techn_wast_all_mtd,
	sum(fact_techn_wast_all) over (partition by date_trunc('year',date_trunc),smelter order by date_trunc asc) fact_techn_wast_all_ytd,
	sum(obrazovano) over (partition by date_trunc('month',date_trunc),smelter order by date_trunc asc) obrazovano_mtd,
	sum(obrazovano) over (partition by date_trunc('year',date_trunc),smelter order by date_trunc asc) obrazovano_ytd
	from group_table
	)

	select
		ms.dt as DT_REPORT,
		ms.entity_code as ENTITY_CODE,
		ms.account_code as ACCOUNT_CODE,
		tm.fact_techn_wast_all/nullif(tm.obrazovano,0)*100 as actual,
		tm.fact_techn_wast_all_mtd/nullif(tm.obrazovano_mtd,0)*100 as actual_mtd,
		tm.fact_techn_wast_all_ytd/nullif(tm.obrazovano_ytd,0)*100 as actual_ytd

	from mas_entity ms
	left join t_main tm on ms.source_entity_code = tm.smelter and ms.dt = tm.date_trunc

	union all

	select
		ms.dt,
		'BU_AL_AD',
		ms.account_code,
		sum(tm.fact_techn_wast_all)/nullif(sum(tm.obrazovano),0)*100 as actual,
		sum(tm.fact_techn_wast_all_mtd)/nullif(sum(tm.obrazovano_mtd),0)*100 as actual_mtd,
		sum(tm.fact_techn_wast_all_ytd)/nullif(sum(tm.obrazovano_ytd),0)*100 as actual_ytd

	from mas_entity ms
	left join t_main tm on ms.source_entity_code = tm.smelter and ms.dt = tm.date_trunc
	group by
		ms.dt,
		ms.account_code
)t1;

--KPI_QLT_13_TN (Тех. отходы, тн)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD"  kiara
	where kiara.account_code in ('KPI_QLT_13_TN')
	and kiara.dt_report >= DATE_TRUNC('YEAR', now());

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual
	)

select
		t1.DT_REPORT,
		t1.ENTITY_CODE,
		t1.ACCOUNT_CODE,
		t1.actual

from
(

	with mas_entity as (

	select
		 c.dt,
		 mkrate.account_code,
		 mkrate.entity_code,
		 mkrate.source_entity_code

	from dict_dds.map_kpi_report_account_to_entity mkrate
	cross join dict_dds.calendar c
	where mkrate.account_code = 'KPI_QLT_13_TN'
		and mkrate.entity_code <> 'BU_AL_AD'
		and c.dt >= date_trunc('year', now()) and c.dt < date_trunc('month', now()) + interval '1 month'

	)

	select
		ms.dt as DT_REPORT,
		ms.entity_code as ENTITY_CODE,
		ms.account_code as ACCOUNT_CODE,
		sum(spwr.fact_techn_wast_all) as actual

	from mas_entity ms
	left join stg.sapxi_production_waste_report spwr on ms.source_entity_code = spwr.smelter and ms.dt = spwr.date_trunc
	group by
		ms.dt,
		ms.entity_code,
		ms.account_code

	union all

		select
		ms.dt as DT_REPORT,
		'BU_AL_AD' as ENTITY_CODE,
		ms.account_code as ACCOUNT_CODE,
		sum(spwr.fact_techn_wast_all) as actual

	from mas_entity ms
	left join stg.sapxi_production_waste_report spwr on ms.source_entity_code = spwr.smelter and ms.dt = spwr.date_trunc
	group by
		ms.dt,
		ms.account_code
)t1;


--KPI_KAIZEN_CREATED, KPI_KAIZEN_IMPLEMENTED
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.account_code in ('KPI_KAIZEN_CREATED','KPI_KAIZEN_IMPLEMENTED');
insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual
	)
	select
	t.dt_report,
	t.entity_code,
	t.account_code,
	t.actual
	from (
--Количество поданных KPI_KAIZEN_CREATED и реализованных KPI_KAIZEN_IMPLEMENTED	кайзенов
with kci as (
	select
		kr.dt_report,
		mkrate.entity_code,
		kr.account_code,
		kr.actual,
		(sum(kr.actual::numeric) over (partition by mkrate.entity_code,kr.account_code,date_trunc('month',kr.dt_report::date) order by kr.dt_report::date))::numeric as actual_mtd,
		(sum(kr.actual::numeric) over (partition by mkrate.entity_code,kr.account_code,date_trunc('year',kr.dt_report::date) order by kr.dt_report::date))::numeric as actual_ytd
	from (select
				k.dt_report,
				k.kaizen_counterparty_rims_code,
				CASE
						WHEN k.kaizen_state_code = '4' THEN 'KPI_KAIZEN_CREATED'
						WHEN k.kaizen_state_code = '5' THEN 'KPI_KAIZEN_IMPLEMENTED' END
				  as "account_code",
				kaizen_quantity as "actual"
		  from dm.exp_production_ad_kaizens as k ) as kr
	join dict_dds.map_kpi_report_account_to_entity mkrate on kr.kaizen_counterparty_rims_code=mkrate.source_entity_code and mkrate.account_code=kr.account_code
	)

	    select
			dt_report,
			entity_code,
			account_code,
			actual
			from kci
		union all
		select
			dt_report,
			'BU_ALUM' as "entity_code",
			account_code,
			sum(actual) as "actual"
		from kci
		group by dt_report, account_code
	) t;
----Конец Количество поданных KPI_KAIZEN_CREATED и реализованных KPI_KAIZEN_IMPLEMENTED	кайзенов--------

--KPI_KAIZEN_PERSONNEL_INVOLVED_QUANTITY, KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where
		kiar.account_code in ('KPI_KAIZEN_PERSONNEL_INVOLVED_QUANTITY', 'KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE');
insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_mtd,
	actual_ytd,
	active_goal_mtd,
	active_goal_ytd
	)
select
		t.dt_report,
		t.entity_code,
		t.account_code,
		t.actual,
		t.actual_mtd,
		t.actual_ytd,
		t.active_goal_mtd,
		t.active_goal_ytd
	from (
--Количество персонала в кайзен-деятельности, KPI_KAIZEN_PERSONNEL_INVOLVED_QUANTITY
WITH kpiq AS (
select
	datent.dt_report,
	datent.entity_code,
	datent.account_code,
	k.kaizen_employee_involved_quantity as "actual",
    (SUM(k.kaizen_employee_involved_quantity::numeric) OVER (PARTITION BY datent.entity_code, DATE_TRUNC('month', datent.dt_report::date) ORDER BY datent.dt_report::date))::numeric AS actual_mtd,
    (SUM(k.kaizen_employee_involved_quantity::numeric) OVER (PARTITION BY datent.entity_code, DATE_TRUNC('year', datent.dt_report::date) ORDER BY datent.dt_report::date))::numeric AS actual_ytd
from
(select c.dt as "dt_report",
	   m.entity_code,
	   m.source_entity_code,
	   m.account_code
	   --m.entity_name
from dict_dds.map_kpi_report_account_to_entity m,
     dict_dds.calendar c
where m.account_code = 'KPI_KAIZEN_PERSONNEL_INVOLVED_QUANTITY' and  m.entity_code <> 'BU_ALUM' --исключаем АД из исходных данных кайзенов 05.02.26
 and c.dt >= DATE_TRUNC('YEAR', to_date('01.01.2024','dd.mm.yyyy')) and c.dt <= TIMESTAMP 'now') datent --DATE_TRUNC('YEAR', TIMESTAMP 'now') 05.02.26
  left join dm.exp_production_ad_kaizen_employee_involve AS k on datent.source_entity_code = k.kaizen_counterparty_rims_code and datent.dt_report = k.dt_report
  ),
--Списочная численность, чел KPI_AL_PERS_AV_QTY
group_personnel_attendance as (
		select
			dt_report,
			plant_code,
			plant_name,
			record_id,
			sum(headcount::numeric) as headcount
		from stg.sapxi_1c_personnel_attendance
		group by
			dt_report,
			plant_code,
			plant_name,
			record_id
		),

apaq AS (
    SELECT
        pa.dt_report::date AS "dt_report",
        mkrate.entity_code AS "entity_code",
        mkrate.account_code AS "account_code",
        pa.headcount::numeric AS "actual",
        ROUND((SUM(headcount::numeric) OVER (PARTITION BY mkrate.entity_code, DATE_TRUNC('month', pa.dt_report::date) ORDER BY pa.dt_report::date) / EXTRACT(day FROM pa.dt_report::date))::numeric, 1) AS "actual_mtd",
        ROUND((SUM(headcount::numeric) OVER (PARTITION BY mkrate.entity_code, DATE_TRUNC('year', pa.dt_report::date) ORDER BY pa.dt_report::date) / ((pa.dt_report::date - DATE_TRUNC('year', pa.dt_report::date)::date)::numeric + 1))::numeric, 1) AS "actual_ytd"
    FROM group_personnel_attendance pa
    JOIN dict_dds.map_kpi_report_account_to_entity mkrate ON pa.plant_code = mkrate.source_entity_code AND mkrate.account_code = 'KPI_AL_PERS_AV_QTY' -- Списочная численность, чел KPI_AL_PERS_AV_QTY
    JOIN (
        SELECT
            pa.dt_report,
            pa.plant_code,
            MAX(record_id) record_id
        FROM stg.sapxi_1c_personnel_attendance pa
        WHERE pa.dt_report::date >= DATE_TRUNC('YEAR', to_date('01.01.2024','dd.mm.yyyy'))::date
        GROUP BY pa.dt_report, pa.plant_code
    ) AS max_rec ON pa.dt_report = max_rec.dt_report AND pa.plant_code = max_rec.plant_code AND pa.record_id = max_rec.record_id
    --WHERE pa.dt_report::date >= DATE_TRUNC('YEAR', to_date('01.01.2024','dd.mm.yyyy'))::date--TIMESTAMP 'now'- '2 year'::interval)
),
--Вовлеченность персонала в кайзен-деятельность, Цель, % KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE
kpir AS (
    SELECT
        zyfra_goal.dt_report,
        mkrate.entity_code,
        zyfra_goal.account_code,
        zyfra_goal.active_goal_mtd,
        zyfra_goal.active_goal_ytd
    FROM (
-- Цель из цифры
     SELECT
            c.dt AS "dt_report",
            'KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE' AS "account_code",
            zyfra.active_goal_mtd,
            zyfra.active_goal_ytd
            from (
            select extract (month from zyf.beg_date) as "begin_month",
            	   extract (year from zyf.beg_date) as "begin_year",
				   zyf.value as "active_goal_mtd",
			       --sum(zyf.value) OVER (order by zyf.beg_date::date) as "active_goal_ytd", --05.02.26
			       sum(zyf.value) OVER (partition by (DATE_TRUNC('year', zyf.beg_date)) order by (DATE_TRUNC('month', zyf.beg_date)::date)) as "active_goal_ytd" --05.02.26
			  from
			       (select distinct DATE_TRUNC('month', c.dt::date)::date as beg_date,
			               h.value
			          from (
				            SELECT apaz.timestamp::date AS beg_date,
				                   LEAD(apaz.timestamp::date, 1, (DATE_TRUNC('month', NOW()) + '1 month'::interval)::date) OVER (PARTITION BY apaz.id ORDER BY apaz.timestamp::date) AS end_date,
				                   apaz.value::numeric
				              FROM stg.auxiliary_production_anode_zyfra apaz
				             WHERE apaz.id = 'd8819c9f-5b12-4643-b910-90b72141778c'
				             ) h
				        JOIN dict_dds.calendar c ON h.beg_date <= c.dt AND c.dt < h.end_date
			        ) AS zyf
			    ) as zyfra
			   join dict_dds.calendar c ON zyfra.begin_month = extract (month from c.dt) AND zyfra.begin_year = extract (year from c.dt)
    ) AS zyfra_goal
    JOIN dict_dds.map_kpi_report_account_to_entity mkrate ON mkrate.account_code = zyfra_goal.account_code
    where mkrate.entity_code <> 'BU_ALUM' --исключаем АД из данных zyfra 05.02.26
)
--Количество персонала в кайзен-деятельности, KPI_KAIZEN_PERSONNEL_INVOLVED_QUANTITY
SELECT
    dt_report,
    entity_code,
    account_code,
    actual,
    actual_mtd,--05.02.26
    actual_ytd,--05.02.26
    NULL::numeric AS "active_goal_mtd",
    NULL::numeric AS "active_goal_ytd"
FROM kpiq
UNION all
SELECT
    dt_report,
    'BU_ALUM' as "entity_code",
    account_code,
    sum(actual) as "actual",
	sum(actual_mtd) as "actual_mtd", --05.02.26
	sum(actual_ytd) as "actual_ytd", --05.02.26
    NULL::numeric AS "active_goal_mtd",
    NULL::numeric AS "active_goal_ytd"
FROM kpiq
group by dt_report, account_code
UNION all
--Вовлеченность персонала в кайзен-деятельность, % KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE
SELECT
    kpiq.dt_report,--05.02.26
    kpiq.entity_code,--05.02.26
    'KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE' AS "account_code",--kaizen_pers.account_code,--05.02.26
    NULL::numeric AS "actual",
    ROUND(kpiq.actual_mtd / pers_av.actual_mtd * 100, 2) AS "actual_mtd",--05.02.26
    ROUND(kpiq.actual_ytd / pers_av.actual_ytd * 100, 2) AS "actual_ytd",--05.02.26
    kaizen_pers.active_goal_mtd,--05.02.26
    kaizen_pers.active_goal_ytd--05.02.26
FROM kpiq
left JOIN kpir AS kaizen_pers ON kpiq.dt_report = kaizen_pers.dt_report AND kpiq.entity_code = kaizen_pers.entity_code--05.02.26
left JOIN apaq AS pers_av ON kpiq.dt_report = pers_av.dt_report AND kpiq.entity_code = pers_av.entity_code--05.02.26
UNION all
SELECT
    kpiq.dt_report,--05.02.26
    'BU_ALUM' as "entity_code",
    'KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE' AS "account_code",--kaizen_pers.account_code,--05.02.26
    NULL::numeric AS "actual",
    ROUND(SUM(kpiq.actual_mtd) / SUM(pers_av.actual_mtd) * 100, 2) AS "actual_mtd",--05.02.26
    ROUND(SUM(kpiq.actual_ytd) / SUM(pers_av.actual_ytd) * 100, 2) AS "actual_ytd",--05.02.26
	avg(kaizen_pers.active_goal_mtd) as "active_goal_mtd",--05.02.26
    avg(kaizen_pers.active_goal_ytd) as "active_goal_ytd"--05.02.26
FROM kpiq
left JOIN kpir AS kaizen_pers ON kpiq.dt_report = kaizen_pers.dt_report AND kpiq.entity_code = kaizen_pers.entity_code
left JOIN apaq AS pers_av ON kpiq.dt_report = pers_av.dt_report AND kpiq.entity_code = pers_av.entity_code
group by kpiq.dt_report, kaizen_pers.account_code
)t;
----Конец KPI_KAIZEN_PERSONNEL_INVOLVED_QUANTITY, KPI_KAIZEN_PERSONNEL_INVOLVED_PERCENTAGE-------------------------------------

--- KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_B (% брака при производстве опытных партий группы Б)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where kiar.account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_B')
	and kiar.dt_report >= to_date('01.01.2025','dd.mm.yyyy'); --DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval ;

insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual,
	actual_mtd,
	actual_ytd
	)

select
		t1.dt_report,
		t1.entity_code,
		t1.account_code,
		t1.actual,
		t1.actual_mtd,
		t1.actual_ytd
from
(
with calendar_entity as
	(
	select
		c.dt as dt_report,
		mkrate.entity_code,
		mkrate.account_code,
		mkrate.entity_name
			from dict_dds.map_kpi_report_account_to_entity mkrate
			cross join dict_dds.calendar c
				where account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_B')
					and c.dt >= to_date('01.01.2025','dd.mm.yyyy') and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval -- DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
	),

	group_table_smelter as (
		select
		spwr.date_trunc,
		spwr.smelter,
		sum(spwr.obrazovano) as obrazovano,
		sum(spwr.reject_category_b) as reject_category_b
		from stg.sapxi_production_waste_report spwr
		where spwr.date_trunc >= to_date('01.01.2025','dd.mm.yyyy') --DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		group by
		spwr.date_trunc,
		spwr.smelter
	),

	group_table_ad as (
		select
		spwr.date_trunc,
		'АД'::text as smelter,
		sum(spwr.obrazovano) as obrazovano,
		sum(spwr.reject_category_b) as reject_category_b
		from stg.sapxi_production_waste_report spwr
		where spwr.date_trunc >= to_date('01.01.2025','dd.mm.yyyy') --DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		group by
		spwr.date_trunc
	),

	fact as (
	select
		date_trunc as date_trunc,
		smelter as nameshort,
		SUM(obrazovano) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) as "OBRAZOVANO",
		SUM(reject_category_b) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) as "REJECT",
		(SUM(reject_category_b) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT",
		(SUM(reject_category_b) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT_MTD",
		(SUM(reject_category_b) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT_YTD"
	from group_table_smelter

	union all

	select
		date_trunc as date_trunc,
		smelter as nameshort,
		SUM(obrazovano) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) as "OBRAZOVANO",
		SUM(reject_category_b) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) as "REJECT",
		(SUM(reject_category_b) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_trunc ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT",
		(SUM(reject_category_b) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_part('month', date_trunc), date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT_MTD",
		(SUM(reject_category_b) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) /nullif(SUM(obrazovano) OVER (partition by smelter, date_part('year', date_trunc) ORDER BY date_trunc asc) ,0)*100)::numeric as "REJECT_CT_YTD"
	from group_table_ad
	)


	select
		ce.dt_report,
		ce.entity_code,
		ce.account_code,
		f."OBRAZOVANO" as obrazovano,
		f."REJECT" as reject_category_b,
		f."REJECT_CT" as actual,
		f."REJECT_CT_MTD" as actual_mtd,
		f."REJECT_CT_YTD" as actual_ytd
	from calendar_entity ce
	left join fact f on ce.dt_report = f.date_trunc and ce.entity_name = f.nameshort
)t1;

--- KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_TN_B (Брак при производстве опытных партий группы Б, тн.)
delete from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" kiar
	where kiar.account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_TN_B')
	and kiar.dt_report >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval ;


insert into ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
	(
	dt_report,
	entity_code,
	account_code,
	actual
	)
select
	t1.dt_report,
	t1.entity_code,
	t1.account_code,
	t1.actual
from

(
with calendar_entity as
	(
	select
		c.dt as dt_report,
		mkrate.entity_code,
		mkrate.account_code,
		mkrate.entity_name
			from dict_dds.map_kpi_report_account_to_entity mkrate
			cross join dict_dds.calendar c
				where account_code in ('KPI_FINISH_GOODS_MANUFACTURING_DEFECTS_TN_B')
					and c.dt >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval and c.dt < DATE_TRUNC('MONTH', now()) + '1 MONTH'::interval
	),

	group_table as (
		select
		spwr.date_trunc,
		spwr.smelter,
		sum(spwr.obrazovano) as obrazovano,
		sum(spwr.reject_category_b) as reject_category_b
		from stg.sapxi_production_waste_report spwr
		where spwr.date_trunc >= DATE_TRUNC('YEAR', now()) - '1 MONTH'::interval
		group by
		spwr.date_trunc,
		spwr.smelter
	),

	fact as (

	select
		date_trunc,
		smelter,
		obrazovano,
		reject_category_b
	from group_table

	union all

	select
		date_trunc,
		'АД'::text as smelter,
		sum(obrazovano),
		sum(reject_category_b)
	from group_table
	group by date_trunc
	)

	select
		ce.dt_report,
		ce.entity_code,
		ce.account_code,
		f.obrazovano as obrazovano,
		f.reject_category_b as actual
	from calendar_entity ce
	left join fact f on ce.dt_report = f.date_trunc and ce.entity_name = f.smelter
)t1;

select tech_etl.downtime_forecast_calc();

----Конец----------------