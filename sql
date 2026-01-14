SQL Error [42P19]: ERROR: recursive reference to query "forecast_recursive" must not appear within a subquery
  Позиция: 1531

WITH RECURSIVE calendar AS (
    -- календарь: от min даты до today + 365
    SELECT
        generate_series(
            (SELECT min(dt_report)
             FROM ods."KPI_INDICATORS_ACTUAL_REPORT_AD"
             WHERE account_code = 'KPI_ALUM_TEC_08a'),
            now()::date + interval '365 day',
            interval '1 day'
        )::date AS dt_report
),

base_data AS (
    -- исходные данные (факт)
    SELECT
        c.dt_report,
        o.entity_code,
        o.actual
    FROM calendar c
    JOIN ods."KPI_INDICATORS_ACTUAL_REPORT_AD" o
      ON o.dt_report = c.dt_report
     AND o.account_code = 'KPI_ALUM_TEC_08a'
),

seed AS (
    -- стартовая точка: все даты < today считаем "известными"
    SELECT
        dt_report,
        entity_code,
        actual                             AS value,
        actual                             AS forecast_day
    FROM base_data
    WHERE dt_report < now()::date
),

forecast_recursive AS (
    -- === базовый слой ===
    SELECT
        s.dt_report,
        s.entity_code,
        s.value,
        s.forecast_day
    FROM seed s

    UNION ALL

    -- === рекурсивный шаг ===
    SELECT
        next_day.dt_report,
        next_day.entity_code,

        -- value: либо факт, либо прогноз предыдущего дня
        COALESCE(
            next_day.actual,
            prev.forecast_day
        ) AS value,

        -- forecast_day = среднее за 365 дней
        (
            SELECT avg(hist.value)
            FROM forecast_recursive hist
            WHERE hist.entity_code = prev.entity_code
              AND hist.dt_report BETWEEN next_day.dt_report - interval '365 day'
                                      AND next_day.dt_report - interval '1 day'
        ) AS forecast_day

    FROM forecast_recursive prev
    JOIN base_data next_day
      ON next_day.entity_code = prev.entity_code
     AND next_day.dt_report = prev.dt_report + interval '1 day'
)

-- ============================================================
-- Финальный INSERT в dm_calc
-- ============================================================


SELECT
    f.dt_report,
    f.entity_code,
    f.forecast_day,

    -- forecast_ytd = сумма значений за 365 дней
    (
        SELECT sum(hist.value)
        FROM forecast_recursive hist
        WHERE hist.entity_code = f.entity_code
          AND hist.dt_report BETWEEN f.dt_report - interval '364 day'
                                  AND f.dt_report
    ) AS forecast_ytd,

    now() AS calc_dttm
FROM forecast_recursive f
WHERE f.dt_report >= now()::date
ORDER BY f.entity_code, f.dt_report;
