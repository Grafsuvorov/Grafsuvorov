WITH
pp AS (
  SELECT
      kalnr,
      bdatj,
      poper,
      to_date(bdatj || substr(poper,2,2) || '01', 'YYYYMMDD') AS dt_valid_from,
      umkumo, abkumo, zukumo, lbkum
  FROM ods.ckmlpp_ral
  WHERE untper = '000'
),

-- Эквивалент LEAD(dt_valid_from) OVER (PARTITION BY kalnr ORDER BY dt_valid_from)
pp_next AS (
  SELECT
      p.kalnr,
      p.dt_valid_from,
      MIN(p2.dt_valid_from) AS dt_next_valid_from
  FROM pp p
  LEFT JOIN pp p2
         ON p2.kalnr = p.kalnr
        AND p2.dt_valid_from > p.dt_valid_from
  GROUP BY p.kalnr, p.dt_valid_from
),

-- Единственный проход по CKMLCR с предрасчётом границ месяца
cr AS (
  SELECT
      kalnr,
      bdatj,
      poper,
      to_date(bdatj || substr(poper,2,2) || '01', 'YYYYMMDD')                    AS dt_start,
      (to_date(bdatj || substr(poper,2,2) || '01', 'YYYYMMDD') + INTERVAL '1 mon')::date AS dt_next,
      stprs, peinh, pvprs, abprd_o, abprd_mo, vprsv, salk3
  FROM ods.ckmlcr_ral
  WHERE untper='000' AND curtp='10'
),

-- Ранняя агрегация MLCD (сужаем объём до джоинов)
mlcd_agg AS (
  SELECT
      kalnr,
      bdatj,
      poper,
      SUM(salk3)  AS salk3,
      SUM(estprd) AS estprd,
      SUM(mstprd) AS mstprd
  FROM ods.mlcd_ral
  WHERE curtp='10' AND categ IN ('ZU','VP','PC')
  GROUP BY 1,2,3
),

-- 2) Финальный набор к upsert’у
src AS (
  SELECT
      p.kalnr                                 AS calculation_code,
      p.dt_valid_from                         AS dt_valid_from,
      COALESCE(n.dt_next_valid_from - INTERVAL '1 day', DATE '2299-12-31') AS dt_valid_to,

      c_curr.vprsv                            AS price_valuation_type_code,
      c_curr.stprs                            AS standard_price_amount,
      c_curr.peinh                            AS price_unit_code,
      c_curr.pvprs                            AS moving_average_price_amount,

      /* rule3 */
      CASE WHEN (p.umkumo + p.abkumo + p.zukumo) = 0 THEN 0
           ELSE TRUNC(
                  CAST(ROUND(
                        (c_curr.stprs / NULLIF(c_curr.peinh,0)) * (p.umkumo + p.abkumo)
                      + c_curr.abprd_o + c_curr.abprd_mo
                      + COALESCE(m.salk3 + m.estprd + m.mstprd,0)
                  ,2) AS NUMERIC(40,20))
                  / NULLIF((p.umkumo + p.abkumo + p.zukumo),0), 15)
      END                                        AS average_weighted_stock_price_rule3_amount,

      /* rule2_prev_date: берем строку, где dt_next = dt_valid_from */
      CASE WHEN (p.abkumo + p.umkumo + p.zukumo) <> 0
           THEN TRUNC(
                  CAST(COALESCE(c_prev.salk3,0)
                     + COALESCE(m.salk3 + m.estprd + m.mstprd,0)
                  AS NUMERIC(40,20))
                  / NULLIF((p.abkumo + p.umkumo + p.zukumo),0), 15)
           ELSE 0
      END                                        AS average_weighted_stock_price_rule2_prev_date_amount,

      /* rule2_next_date: остаток текущего периода */
      CASE WHEN p.lbkum <> 0
           THEN TRUNC(CAST(c_curr.salk3 AS NUMERIC(40,20)) / NULLIF(p.lbkum,0), 15)
           ELSE 0
      END                                        AS average_weighted_stock_price_rule2_next_date_amount,

      h.price_rule_code                         AS price_rule_code,

      CURRENT_TIMESTAMP                         AS dttm_inserted,
      CURRENT_TIMESTAMP                         AS dttm_updated,
      'airflow'                                 AS job_name,
      FALSE                                     AS deleted_flag
  FROM pp p
  LEFT JOIN pp_next n
         ON n.kalnr = p.kalnr
        AND n.dt_valid_from = p.dt_valid_from

  LEFT JOIN cr c_curr
         ON  c_curr.kalnr = p.kalnr
         AND c_curr.bdatj = p.bdatj
         AND c_curr.poper = p.poper

  LEFT JOIN cr c_prev
         ON  c_prev.kalnr = p.kalnr
         AND c_prev.dt_next = p.dt_valid_from

  LEFT JOIN mlcd_agg m
         ON  m.kalnr = p.kalnr
         AND m.bdatj = p.bdatj
         AND m.poper = p.poper

  LEFT JOIN dds.material_ledger_header h
         ON  h.calculation_code = p.kalnr
)
