@Suvorov Nikita Никита, это не план, как можно спланировать простой оборудования? :) У завода есть 2000 единиц оборудования, которые по факту текущего года ломаются или перестают работать по какой то причине, по ним каждый месяц считается средняя на следующий год, но это не план сколько надо сломать оборудования, это прогноз сколько может сломаться, а факт как карта ляжет когда тот день наступит. :) Более того у самого простоя есть цель, но она из хайпериона и нужна я сравнения с фактическими простоями в отчётном периоде. Надеюсь погрузил в этот процесс.


-- DROP FUNCTION tech_etl.downtime_forecast_calc();

CREATE OR REPLACE FUNCTION tech_etl.downtime_forecast_calc()
	RETURNS int4
	LANGUAGE plpgsql
	VOLATILE
AS $$
	







declare
	result int4 := 0;
	forecast RECORD;
	forecasted_raws CURSOR FOR
		select dt_report, entity_code from ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
		where account_code = 'KPI_ALUM_TEC_08a'
		and dt_report >= now()::date
		order by dt_report, entity_code asc;

begin
	FOR forecast IN forecasted_raws LOOP
		UPDATE ods."KPI_INDICATORS_ACTUAL_REPORT_AD" a
        SET
           downtime_duration_in_minutes_forecast_quantity = (select avg(case when b.dt_report < now()::date 
																			then actual
																			else downtime_duration_in_minutes_forecast_quantity end)
																from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" b
															  where b.dt_report between a.dt_report - interval '365 days' and a.dt_report - interval '1 day'
																and a.entity_code = b.entity_code
																and account_code = 'KPI_ALUM_TEC_08a'),
		downtime_duration_in_minutes_forecast_ytd_quantity =  (select avg(case when dt_report < now()::date 
																			then actual
																			else downtime_duration_in_minutes_forecast_quantity end) 
																		+ sum(case when b.dt_report < now()::date
																			then actual
																			else downtime_duration_in_minutes_forecast_quantity end)
															   from ods."KPI_INDICATORS_ACTUAL_REPORT_AD" b
															  where b.dt_report between a.dt_report - interval '365 days' and a.dt_report - interval '1 day'
																and a.entity_code = b.entity_code
																and account_code = 'KPI_ALUM_TEC_08a')
		where forecast.dt_report = a.dt_report 
		  and forecast.entity_code = a.entity_code
		  and a.account_code = 'KPI_ALUM_TEC_08a'
		   ;

	END LOOP;
	RETURN result;
EXCEPTION
	WHEN others THEN
		RAISE notice 'Error: %', sqlerrm;
		RAISE;
END;








$$
EXECUTE ON ANY;
