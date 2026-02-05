DROP TABLE IF EXISTS tmp_arap_doc_level;
CREATE TEMP TABLE tmp_arap_doc_level AS
SELECT
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,
    o.dt_posting,
    o.dt_clearing,

    MAX(o.document_currency_amount) AS document_currency_amount,
    MAX(o.local_currency_amount) AS local_currency_amount,
    MAX(o.second_local_currency_amount) AS second_local_currency_amount,
    MAX(o.valuation_difference_second_local_currency_amount_s) AS valuation_difference_second_local_currency_amount,
    MAX(o.usd_amount) AS usd_amount,

    SUM(o.exchange_diff_local_currency_amount) AS exchange_diff_local_currency_amount,
    SUM(o.exchange_diff_second_local_currency_amount) AS exchange_diff_second_local_currency_amount,

    MIN(o.dt_posting_rev) AS min_dt_posting_rev
FROM tmp_arap_with_reval o
GROUP BY
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,
    o.dt_posting,
    o.dt_clearing
DISTRIBUTED BY (unit_balance_code);
👉 ты убираешь миллионы строк до календаря
✅ ШАГ 2: календарь применять к уже схлопнутым данным
🔧 Новый tmp_opening_keys
DROP TABLE IF EXISTS tmp_opening_keys;
CREATE TEMP TABLE tmp_opening_keys AS
SELECT
    p.dt,
    p.is_second_friday,
    o.unit_balance_code,
    o.fiscal_year,
    o.accounting_document_code,
    o.position_line_item,

    o.document_currency_amount,
    o.local_currency_amount,
    o.second_local_currency_amount,
    o.valuation_difference_second_local_currency_amount,
    o.usd_amount,

    CASE
        WHEN o.min_dt_posting_rev IS NULL OR o.min_dt_posting_rev <= p.dt
        THEN o.exchange_diff_local_currency_amount
    END AS exchange_diff_local_currency_amount,

    CASE
        WHEN o.min_dt_posting_rev IS NULL OR o.min_dt_posting_rev <= p.dt
        THEN o.exchange_diff_second_local_currency_amount
    END AS exchange_diff_second_local_currency_amount

FROM tmp_arap_doc_level o
JOIN tmp_periods p
  ON p.unit_balance_code = o.unit_balance_code
WHERE
    (o.dt_clearing IS NULL OR o.dt_clearing > p.dt)
    AND p.dt >= o.dt_posting
DISTRIBUTED BY (unit_balance_code);
