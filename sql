CREATE OR REPLACE FUNCTION dm_calc.calc_downtime_forecast_365_fast()
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    r_entity RECORD;
    r_day RECORD;

    window_sum     numeric;
    forecast_day   numeric;
    forecast_ytd   numeric;
    prev_value     numeric;

    values_365     numeric[];  -- скользящее окно
    idx            int := 1;
BEGIN
    -- очищаем текущий расчёт (по желанию)
    DELETE FROM dm_calc.pr_equipment_downtime_forecast_365
    WHERE calc_dttm::date = now()::date;

    -- цикл по entity
    FOR r_entity IN
        SELECT DISTINCT entity_code
        FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
        WHERE account_code = 'KPI_ALUM_TEC_08a'
    LOOP
        values_365 := ARRAY[]::numeric[];

        -- 1️⃣ берём последние 365 фактических значений
        FOR r_day IN
            SELECT actual
            FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
            WHERE account_code = 'KPI_ALUM_TEC_08a'
              AND entity_code = r_entity.entity_code
              AND dt_report < now()::date
            ORDER BY dt_report DESC
            LIMIT 365
        LOOP
            values_365 := array_prepend(r_day.actual, values_365);
        END LOOP;

        -- если данных меньше 365 — пропускаем entity
        IF array_length(values_365, 1) < 365 THEN
            CONTINUE;
        END IF;

        -- начальная сумма окна
        SELECT sum(v) INTO window_sum
        FROM unnest(values_365) v;

        forecast_ytd := window_sum;

        -- 2️⃣ идём по дням вперёд
        FOR r_day IN
            SELECT
                dt_report,
                actual
            FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
            WHERE account_code = 'KPI_ALUM_TEC_08a'
              AND entity_code = r_entity.entity_code
              AND dt_report >= now()::date
              AND dt_report <= now()::date + interval '365 day'
            ORDER BY dt_report
        LOOP
            -- прогноз дня
            forecast_day := window_sum / 365;

            -- если факт есть — он подменит прогноз
            IF r_day.actual IS NOT NULL THEN
                prev_value := r_day.actual;
            ELSE
                prev_value := forecast_day;
            END IF;

            -- сдвигаем окно
            window_sum :=
                window_sum
                - values_365[1]
                + prev_value;

            values_365[1:364] := values_365[2:365];
            values_365[365] := prev_value;

            forecast_ytd := forecast_ytd + prev_value;

            -- insert
            INSERT INTO dm_calc.pr_equipment_downtime_forecast_365 (
                dt_report,
                entity_code,
                forecast_day,
                forecast_ytd,
                calc_dttm
            )
            VALUES (
                r_day.dt_report,
                r_entity.entity_code,
                forecast_day,
                forecast_ytd,
                now()
            );
        END LOOP;
    END LOOP;
END;
$$;
CREATE TABLE IF NOT EXISTS dm_calc.pr_equipment_downtime_forecast_365 (
    dt_report       date,
    entity_code     text,
    forecast_day    numeric,
    forecast_ytd    numeric,
    calc_dttm       timestamp
)
DISTRIBUTED BY (entity_code);
