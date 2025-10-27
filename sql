WITH
/* 1) Базовая «месячная» картотека — как у тебя было */
pp_base AS (
  SELECT
    (kalnr)::text AS kalnr_text,
    bdatj::text   AS bdatj,
    poper::text   AS poper,
    to_date(bdatj||substr(poper,2,2)||'01','YYYYMMDD')                 AS dt_valid_from,
    /* эти поля нужны дальше для правил */
    umkumo, abkumo, zukumo, lbkum
  FROM userdata.ckmlpp_ral
  WHERE untper='000'
),

/* 2) Строим «сквозные» интервалы точно как в v2:
      следующий_старт - 1 день; для последнего — 2299-12-31 */
pp AS (
  SELECT
    kalnr_text, bdatj, poper, dt_valid_from,
    umkumo, abkumo, zukumo, lbkum,
    CASE
      WHEN LEAD(dt_valid_from) OVER (PARTITION BY kalnr_text ORDER BY dt_valid_from) IS NULL
        THEN DATE '2299-12-31'
      ELSE (LEAD(dt_valid_from) OVER (PARTITION BY kalnr_text ORDER BY dt_valid_from) - INTERVAL '1 day')::date
    END AS dt_valid_to
  FROM pp_base
),

/* 3) CKMLCR — без изменений: текущий и «предыдущий» через dt_next=dt_valid_from */
cr AS (
  SELECT
    (kalnr)::text AS kalnr_text,
    bdatj::text   AS bdatj,
    poper::text   AS poper,
    to_date(bdatj||substr(poper,2,2)||'01','YYYYMMDD')                         AS dt_start,
    (to_date(bdatj||substr(poper,2,2)||'01','YYYYMMDD') + INTERVAL '1 month')::date AS dt_next,
    stprs, peinh, pvprs, abprd_o, abprd_mo, vprsv, salk3
  FROM userdata.ckmlcr_ral
  WHERE untper='000' AND curtp='10'
),

/* 4) MLCD агрегации — без изменений */
mlcd_agg AS (
  SELECT
    (kalnr)::text AS kalnr_text,
    bdatj::text   AS bdatj,
    poper::text   AS poper,
    SUM(salk3)  AS salk3,
    SUM(estprd) AS estprd,
    SUM(mstprd) AS mstprd
  FROM userdata.mlcd_ral
  WHERE curtp='10' AND categ IN ('ZU','VP','PC')
  GROUP BY 1,2,3
)

SELECT
  p.kalnr_text                  AS calculation_code,
  p.dt_valid_from,
  p.dt_valid_to,                     -- << теперь как в v2

  c_curr.vprsv                  AS price_valuation_type_code,
  c_curr.stprs                  AS standard_price_amount,
  c_curr.peinh                  AS price_unit_code,
  c_curr.pvprs                  AS moving_average_price_amount,

  /* rule3 — без изменений */
  CASE WHEN (p.umkumo + p.abkumo + p.zukumo)=0 THEN 0
       ELSE TRUNC(
              CAST(ROUND(
                    (c_curr.stprs / NULLIF(c_curr.peinh,0)) * (p.umkumo + p.abkumo)
                  + c_curr.abprd_o + c_curr.abprd_mo
                  + COALESCE(m.salk3 + m.estprd + m.mstprd,0)
              ,2) AS NUMERIC(40,20))
              / NULLIF((p.umkumo + p.abkumo + p.zukumo),0), 15)
  END AS average_weighted_stock_price_rule3_amount,

  /* rule2_prev_date — ИДЕНТИЧНО v2: без COALESCE на c_prev.salk3 */
  CASE WHEN (p.abkumo + p.umkumo + p.zukumo)<>0
       THEN TRUNC(
              CAST(
                c_prev.salk3
                + COALESCE(m.salk3 + m.estprd + m.mstprd,0)
              AS NUMERIC(40,20))
              / NULLIF((p.abkumo + p.umkumo + p.zukumo),0), 15)
       ELSE 0
  END AS average_weighted_stock_price_rule2_prev_date_amount,

  /* rule2_next_date — без изменений */
  CASE WHEN p.lbkum<>0
       THEN TRUNC(CAST(c_curr.salk3 AS NUMERIC(40,20)) / NULLIF(p.lbkum,0), 15)
       ELSE 0
  END AS average_weighted_stock_price_rule2_next_date_amount,

  h.price_rule_code
FROM pp p
LEFT JOIN cr c_curr
  ON  c_curr.kalnr_text = p.kalnr_text
  AND c_curr.bdatj      = p.bdatj
  AND c_curr.poper      = p.poper
LEFT JOIN cr c_prev
  ON  c_prev.kalnr_text = p.kalnr_text
  AND c_prev.dt_next    = p.dt_valid_from
LEFT JOIN mlcd_agg m
  ON  m.kalnr_text = p.kalnr_text
  AND m.bdatj      = p.bdatj
  AND m.poper      = p.poper
LEFT JOIN dds.material_ledger_header h
  ON  h.calculation_code = p.kalnr_text
;
