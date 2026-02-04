-- ============================================================
-- STEP 0. Параметры периода (чтобы не дублировать константы)
-- ============================================================
WITH params AS (
  SELECT
    DATE '2025-12-31' AS dt_from,
    DATE '2026-02-28' AS dt_to
)
SELECT 1;

-- ============================================================
-- STEP 1. База: один раз читаем accounting_receivables_and_payables
-- (то, что в плане называется accounting_receivables_and_payables_1)
-- ============================================================
DROP TABLE IF EXISTS tmp_wrk_arap_base;
CREATE TEMP TABLE tmp_wrk_arap_base
AS
SELECT
    a.unit_balance_code,
    a.fiscal_year,
    a.accounting_document_code,
    a.position_line_item,

    a.dt_posting,
    a.dt_clearing,
    a.document_currency_code,

    a.fiscal_year_of_relevant_invoice,
    a.invoice_document_code,
    a.position_number_of_relevant_invoice,

    a.general_ledger_account_code,
    a.debit_or_credit,

    -- + все нужные поля дальше
    a.*
FROM accounting_receivables_and_payables a
WHERE
    a.document_currency_code IS NOT NULL
    AND a.unit_balance_code !~ '^[A-Za-z]'
    AND NOT a.deleted_flag
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_arap_base;

-- ============================================================
-- STEP 2. Подмешиваем revaluation (в плане это hash left join к accounting_exchange_rate...)
-- Важно: делаем агрегацию заранее и раздачу по ключу ссылки
-- ============================================================
DROP TABLE IF EXISTS tmp_wrk_reval_ref;
CREATE TEMP TABLE tmp_wrk_reval_ref
AS
SELECT
    r.unit_balance_code,
    r.reference_document_fiscal_year,
    r.reference_document_code,
    r.reference_document_position_line_item,
    MAX(r.dt_posting) AS max_reval_dt_posting
FROM accounting_exchange_rate_revaluation_with_document_reference r
WHERE NOT r.deleted_flag
GROUP BY
    r.unit_balance_code,
    r.reference_document_fiscal_year,
    r.reference_document_code,
    r.reference_document_position_line_item
DISTRIBUTED BY (unit_balance_code, reference_document_fiscal_year, reference_document_code, reference_document_position_line_item);

ANALYZE tmp_wrk_reval_ref;

DROP TABLE IF EXISTS tmp_wrk_arap_enriched;
CREATE TEMP TABLE tmp_wrk_arap_enriched
AS
SELECT
    b.*,
    rr.max_reval_dt_posting
FROM tmp_wrk_arap_base b
LEFT JOIN tmp_wrk_reval_ref rr
  ON  b.unit_balance_code = rr.unit_balance_code
  AND b.fiscal_year = rr.reference_document_fiscal_year
  AND b.accounting_document_code = rr.reference_document_code
  AND b.position_line_item = rr.reference_document_position_line_item
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_arap_enriched;

-- ============================================================
-- STEP 3. Исключение INACTBUK (в плане settings_and_parameters_sap + фильтр range_low_value IS NULL)
-- По плану: "Filter: (settings_and_parameters_sap.range_low_value IS NULL)" => т.е. исключаем совпавшие unit_balance_code
-- ============================================================
DROP TABLE IF EXISTS tmp_wrk_inactbuk;
CREATE TEMP TABLE tmp_wrk_inactbuk
AS
SELECT DISTINCT s.range_low_value::text AS unit_balance_code
FROM settings_and_parameters_sap s
WHERE
  s.abap_program_code = '/RUSAL/FI_KHD'
  AND s.parameter_code = 'INACTBUK'
  AND s.range_low_value IS NOT NULL
DISTRIBUTED REPLICATED;

ANALYZE tmp_wrk_inactbuk;

DROP TABLE IF EXISTS tmp_wrk_arap_active;
CREATE TEMP TABLE tmp_wrk_arap_active
AS
SELECT e.*
FROM tmp_wrk_arap_enriched e
LEFT JOIN tmp_wrk_inactbuk i
  ON e.unit_balance_code::text = i.unit_balance_code
WHERE i.unit_balance_code IS NULL
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_arap_active;

-- ============================================================
-- STEP 4. Period expansion (в плане: join с operating_periods_for_account_debt по unit_balance_code
-- и фильтр: dt между dt_posting и coalesce(dt_clearing, '2299-12-31')
-- Важно: ограничиваем operating_periods сразу по диапазону params
-- ============================================================
DROP TABLE IF EXISTS tmp_wrk_periods;
CREATE TEMP TABLE tmp_wrk_periods
AS
SELECT p.*
FROM operating_periods_for_account_debt p
JOIN (SELECT DATE '2025-12-31' AS dt_from, DATE '2026-02-28' AS dt_to) prm ON 1=1
WHERE
  NOT p.deleted_flag
  AND p.dt BETWEEN prm.dt_from AND prm.dt_to
DISTRIBUTED BY (unit_balance_code);

ANALYZE tmp_wrk_periods;

DROP TABLE IF EXISTS tmp_wrk_arap_periods;
CREATE TEMP TABLE tmp_wrk_arap_periods
AS
SELECT
  pr.dt,
  pr.is_second_friday,
  a.*
FROM tmp_wrk_arap_active a
JOIN tmp_wrk_periods pr
  ON a.unit_balance_code = pr.unit_balance_code
WHERE
  pr.dt >= a.dt_posting
  AND pr.dt < COALESCE(a.dt_clearing, DATE '2299-12-31')  -- TODO verify strictness > or >= as in original
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_arap_periods;

-- ============================================================
-- STEP 5. Присоединение "релевантного инвойса" (в плане: Hash Left Join с accounting_receivables_and_payables_2 + deleted_flag)
-- Важно: вместо третьего Seq Scan по исходной таблице — используем уже base (или отдельную thin-таблицу ключей)
-- ============================================================
DROP TABLE IF EXISTS tmp_wrk_invoice_ref;
CREATE TEMP TABLE tmp_wrk_invoice_ref
AS
SELECT
  unit_balance_code,
  fiscal_year,
  accounting_document_code,
  position_line_item,
  deleted_flag
  -- + любые нужные поля из "инвойса"
FROM accounting_receivables_and_payables
-- если инвойсная часть тоже огромная — можно тоже фильтровать/сужать
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_invoice_ref;

DROP TABLE IF EXISTS tmp_wrk_joined_invoice;
CREATE TEMP TABLE tmp_wrk_joined_invoice
AS
SELECT
  p.*,
  inv.deleted_flag AS inv_deleted_flag
  -- + inv.<fields>
FROM tmp_wrk_arap_periods p
LEFT JOIN tmp_wrk_invoice_ref inv
  ON  p.unit_balance_code = inv.unit_balance_code
  AND p.fiscal_year_of_relevant_invoice = inv.fiscal_year
  AND p.invoice_document_code = inv.accounting_document_code
  AND p.position_number_of_relevant_invoice = inv.position_line_item
WHERE
  (NOT inv.deleted_flag) OR inv.deleted_flag IS NULL
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_joined_invoice;

-- ============================================================
-- STEP 6. Anti-join / исключения
-- В плане: Hash Anti Join, где справа ~308k ключей
-- Делай ключи исключений отдельной маленькой таблицей (не на 1.3 млрд строк!)
-- ============================================================
DROP TABLE IF EXISTS tmp_wrk_exclude_keys;
CREATE TEMP TABLE tmp_wrk_exclude_keys
AS
SELECT DISTINCT
  x.dt,
  x.unit_balance_code,
  x.fiscal_year,
  x.accounting_document_code,
  x.position_line_item,
  x.document_currency_code,
  x.general_ledger_account_code,
  x.debit_or_credit
FROM tmp_wrk_joined_invoice x
WHERE
  x.invoice_document_code IS NULL
  AND x.dt BETWEEN DATE '2025-12-31' AND DATE '2026-02-28'
  -- + остальные условия как в плане (GL/doc_curr/debit_credit is null и т.п.)
DISTRIBUTED BY (dt, unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE tmp_wrk_exclude_keys;

-- ============================================================
-- STEP 7. Финальный SELECT без Gather Motion:
-- Важно: либо писать в таблицу с нормальным DISTRIBUTED BY,
-- либо если это просто SELECT в клиент — тогда Gather неизбежен (но хотя бы итог будет малым).
-- ============================================================
DROP TABLE IF EXISTS final_result_tmp;
CREATE TEMP TABLE final_result_tmp
AS
SELECT
  j.*
FROM tmp_wrk_joined_invoice j
WHERE NOT EXISTS (
  SELECT 1
  FROM tmp_wrk_exclude_keys e
  WHERE
    e.dt = j.dt
    AND e.unit_balance_code = j.unit_balance_code
    AND e.fiscal_year = j.fiscal_year
    AND e.accounting_document_code = j.accounting_document_code
    AND e.position_line_item = j.position_line_item
    AND e.document_currency_code = j.document_currency_code
    AND e.general_ledger_account_code = j.general_ledger_account_code
    AND e.debit_or_credit = j.debit_or_credit
)
DISTRIBUTED BY (unit_balance_code, fiscal_year, accounting_document_code, position_line_item);

ANALYZE final_result_tmp;

SELECT * FROM final_result_tmp;
