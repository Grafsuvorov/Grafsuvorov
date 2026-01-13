
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
