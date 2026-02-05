Gather Motion 8:1  (slice1; segments: 8)  (cost=0.00..281970.64 rows=725490245 width=87) (actual time=8924.343..85417.351 rows=7196772 loops=1)
  ->  HashAggregate  (cost=0.00..106976.95 rows=90686281 width=87) (actual time=80027.992..83771.913 rows=2389254 loops=1)
        Group Key: tmp_periods.dt, tmp_periods.is_second_friday, tmp_arap_with_reval.unit_balance_code, tmp_arap_with_reval.fiscal_year, tmp_arap_with_reval.accounting_document_code, tmp_arap_with_reval.position_line_item
        Extra Text: (seg3)   2389254 groups total in 32 batches; 1 overflows; 2389512 spill groups.
(seg3)   Hash chain length 4.5 avg, 17 max, using 549047 of 557056 buckets; total 10 expansions.

        ->  Hash Join  (cost=0.00..31954.82 rows=90686281 width=75) (actual time=1.537..49535.856 rows=28570289 loops=1)
              Hash Cond: ((tmp_arap_with_reval.unit_balance_code)::text = (tmp_periods.unit_balance_code)::text)
              Join Filter: (((tmp_arap_with_reval.dt_clearing IS NULL) OR (tmp_arap_with_reval.dt_clearing > tmp_periods.dt)) AND (tmp_periods.dt >= tmp_arap_with_reval.dt_posting))
              Extra Text: (seg0)   Hash chain length 36.0 avg, 36 max, using 9 of 262144 buckets.
              Extra Text: (seg3)   Hash chain length 36.0 avg, 36 max, using 8 of 262144 buckets.
              ->  Seq Scan on tmp_arap_with_reval  (cost=0.00..1061.58 rows=10615760 width=78) (actual time=0.044..1652.023 rows=19626991 loops=1)
              ->  Hash  (cost=431.01..431.01 rows=275 width=10) (actual time=0.117..0.117 rows=324 loops=1)
                    ->  Seq Scan on tmp_periods  (cost=0.00..431.01 rows=275 width=10) (actual time=0.057..0.074 rows=324 loops=1)
Planning time: 102.638 ms
  (slice0)    Executor memory: 291K bytes.
* (slice1)    Executor memory: 83247K bytes avg x 8 workers, 83255K bytes max (seg1).  Work_mem: 63389K bytes max, 795201K bytes wanted.
Memory used:  126976kB
Memory wanted:  1590800kB
Optimizer: Pivotal Optimizer (GPORCA)
Execution time: 85642.437 ms

DROP TABLE IF EXISTS tmp_opening_keys;
CREATE TEMP TABLE tmp_opening_keys as
explain analyze
SELECT
    p.dt,
    p.is_second_friday,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,

    MAX(o.document_currency_amount) AS document_currency_amount,
    MAX(o.local_currency_amount) AS local_currency_amount,
    MAX(o.second_local_currency_amount) AS second_local_currency_amount,
    MAX(o.valuation_difference_second_local_currency_amount_s) AS valuation_difference_second_local_currency_amount,
    MAX(o.usd_amount) AS usd_amount,

    SUM(
        CASE
            WHEN o.dt_posting_rev IS NULL OR o.dt_posting_rev <= p.dt
            THEN o.exchange_diff_local_currency_amount
        END
    ) AS exchange_diff_local_currency_amount,

    SUM(
        CASE
            WHEN o.dt_posting_rev IS NULL OR o.dt_posting_rev <= p.dt
            THEN o.exchange_diff_second_local_currency_amount
        END
    ) AS exchange_diff_second_local_currency_amount

FROM tmp_arap_with_reval o
JOIN tmp_periods p
  ON p.unit_balance_code = o.unit_balance_code
WHERE
    (o.dt_clearing IS NULL OR o.dt_clearing > p.dt)
    AND p.dt >= o.dt_posting
GROUP BY
    p.dt,
    p.is_second_friday,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item
DISTRIBUTED BY (unit_balance_code);
